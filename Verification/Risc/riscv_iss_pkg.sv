// =============================================================================
// riscv_iss_pkg.sv
// -----------------------------------------------------------------------------
// Instruction-set simulator (ISA golden model) for the full-core checker.
//
// Written from the RISC-V specifications, NOT from the RTL, so a wrong design
// choice in the RTL shows up as a mismatch instead of being copied into the
// model:
//   - Unprivileged: RV32I / RV64I (incl. the RV64-only W/LD/SD/LWU forms),
//     M, Zicsr, the F subset the FPU implements, FENCE (NOP)
//   - Privileged: M-mode only - mstatus/mie/mip/mtvec/mepc/mcause/mtval,
//     MRET, WFI (NOP), synchronous exceptions and M-mode interrupts
//
// Implementation choices the specs leave open are modelled the way the core
// documents them (Harvard memories truncated to ADDR_WIDTH, misaligned
// load/store traps, mtval = 0 except for address faults, WARL legalisation of
// mtvec/mepc, mstatus.MPP = M, mstatus.FS = Dirty, the CSR set of B1.6).
//
// Non-deterministic state (mcycle and its aliases) is not predicted: the
// checker hands the DUT's read value to step(), which uses it.
//
// Known core gaps tracked in the plan (B9.1) are modelled as gaps so they do
// not hide other errors: FP operations do not accrue fflags.
// =============================================================================
package riscv_iss_pkg;

    import shared_pkg::*;
    import flp_ref_pkg::*;

    localparam int  XLEN    = FINAL_DATA_WIDTH;
    localparam bit  IS_RV64 = (XLEN == 64);
    localparam int  PADDR_W = FINAL_ADDR_WIDTH;
    localparam logic [31:0] MVENDORID_VALUE = 32'h48_41_4E_4F;

    typedef logic [XLEN-1:0] xlen_t;

    // ── Result of one step (one committed instruction or one taken trap) ─────
    typedef struct {
        xlen_t       pc;            // PC of the instruction
        logic [31:0] insn;          // Instruction bits
        bit          trap;          // Exception or interrupt taken instead
        bit          interrupt;     // The trap is an interrupt
        xlen_t       cause;         // mcause written
        xlen_t       tval;          // mtval written
        bit          rd_we;         // Integer register written
        int          rd;            // Integer destination
        xlen_t       rd_val;        // Integer result
        bit          frd_we;        // FP register written
        int          frd;           // FP destination
        logic [31:0] frd_val;       // FP result
        bit          st_we;         // Store performed
        xlen_t       st_addr;       // Store address (virtual = physical here)
        int          st_size;       // Store size in bytes
        xlen_t       st_data;       // Store data (low st_size bytes)
        xlen_t       next_pc;       // PC of the next instruction
    } iss_commit_t;

    class riscv_iss;

        // ── Architectural state ──────────────────────────────────────────────
        xlen_t       pc;
        xlen_t       x [32];
        logic [31:0] f [32];
        bit          mstatus_mie, mstatus_mpie;
        bit          mie_meie, mie_mtie, mie_msie;
        xlen_t       mtvec, mscratch, mepc, mcause, mtval;
        logic [63:0] minstret;
        logic [4:0]  fflags;
        logic [2:0]  frm;

        // ── Memories (Harvard, as in the core) ──────────────────────────────
        logic [31:0] imem [int];    // word index -> instruction
        logic [7:0]  dmem [int];    // byte address -> byte (absent = 0)

        // ── Inputs of the current step ──────────────────────────────────────
        bit          irq_ext, irq_tmr, irq_sw;
        xlen_t       dut_csr_rdata;  // DUT read value for unpredictable CSRs

        function new();
            reset();
        endfunction

        function void reset();
            pc = '0;
            foreach (x[i]) x[i] = '0;
            foreach (f[i]) f[i] = '0;
            mstatus_mie = 0; mstatus_mpie = 0;
            mie_meie = 0; mie_mtie = 0; mie_msie = 0;
            mtvec = '0; mscratch = '0; mepc = '0; mcause = '0; mtval = '0;
            minstret = '0; fflags = '0; frm = '0;
            dmem.delete();
        endfunction

        // Program image: one 32-bit instruction per line, binary ($readmemb)
        function void load_image(string path);
            int fd, n;
            string line;
            imem.delete();
            fd = $fopen(path, "r");
            if(fd == 0)
            begin
                $error("riscv_iss: cannot open %s", path);
                return;
            end
            n = 0;
            while(!$feof(fd))
            begin
                logic [31:0] w;
                if($fscanf(fd, "%b\n", w) == 1)
                begin
                    imem[n] = w;
                    n++;
                end
                else
                    void'($fgets(line, fd));
            end
            $fclose(fd);
        endfunction

        // ── Memory helpers ──────────────────────────────────────────────────
        function automatic int paddr(xlen_t a);
            return int'(a[PADDR_W-1:0]);
        endfunction

        function automatic logic [31:0] fetch(xlen_t a);
            int w = paddr(a) >> 2;
            return imem.exists(w) ? imem[w] : 32'h0;
        endfunction

        function automatic xlen_t load(xlen_t a, int size);
            xlen_t v = '0;
            for(int i = 0; i < size; i++)
            begin
                int b = paddr(a + xlen_t'(i));
                v[8*i +: 8] = dmem.exists(b) ? dmem[b] : 8'h0;
            end
            return v;
        endfunction

        function automatic void store(xlen_t a, int size, xlen_t v);
            for(int i = 0; i < size; i++)
                dmem[paddr(a + xlen_t'(i))] = v[8*i +: 8];
        endfunction

        // ── Bit helpers ─────────────────────────────────────────────────────
        function automatic xlen_t sext32(logic [31:0] v);
            return xlen_t'(signed'(v));
        endfunction

        function automatic xlen_t sext(xlen_t v, int bits);
            xlen_t m = xlen_t'(1) << (bits - 1);
            v = v & ((xlen_t'(1) << bits) - 1);
            return (v ^ m) - m;
        endfunction

        // ── CSRs (M-mode, the set documented in B1.6) ───────────────────────
        function automatic xlen_t mstatus_value();
            xlen_t v = '0;
            v[3]  = mstatus_mie;
            v[7]  = mstatus_mpie;
            v[12:11] = 2'b11;          // MPP = M (M-only hart)
            v[14:13] = 2'b11;          // FS = Dirty (FPU always on)
            v[XLEN-1] = 1'b1;          // SD
            return v;
        endfunction

        // Returns 0 if the CSR does not exist
        function automatic bit csr_read(logic [11:0] a, output xlen_t v);
            v = '0;
            case(a)
                12'h001: v = xlen_t'(fflags);
                12'h002: v = xlen_t'(frm);
                12'h003: v = xlen_t'({frm, fflags});
                12'h300: v = mstatus_value();
                12'h301: v = {(IS_RV64 ? 2'd2 : 2'd1), {(XLEN-2){1'b0}}} |
                             (xlen_t'(1) << 8) | (xlen_t'(1) << 12) | (xlen_t'(1) << 5);   // I, M, F
                12'h302, 12'h303: v = '0;                                                   // medeleg/mideleg RO 0
                12'h304: begin v[11] = mie_meie; v[7] = mie_mtie; v[3] = mie_msie; end
                12'h305: v = mtvec;
                12'h340: v = mscratch;
                12'h341: v = mepc;
                12'h342: v = mcause;
                12'h343: v = mtval;
                12'h344: begin v[11] = irq_ext; v[7] = irq_tmr; v[3] = irq_sw; end
                12'h310: begin if(IS_RV64) return 0; v = '0; end                          // mstatush
                12'hB00, 12'hC00: v = dut_csr_rdata;                                        // mcycle / cycle
                12'hB80, 12'hC80: begin if(IS_RV64) return 0; v = dut_csr_rdata; end        // mcycleh / cycleh
                12'hB02, 12'hC02: v = minstret[XLEN-1:0];                                   // minstret / instret
                12'hB82, 12'hC82: begin if(IS_RV64) return 0; v = xlen_t'(minstret[63:32]); end
                12'hF11: v = xlen_t'(MVENDORID_VALUE);
                12'hF12, 12'hF13, 12'hF14: v = '0;                                          // marchid/mimpid/mhartid
                default: begin
                    if((a >= 12'hB03 && a <= 12'hB1F) || (a >= 12'h323 && a <= 12'h33F) ||
                       (!IS_RV64 && a >= 12'hB83 && a <= 12'hB9F))
                        v = '0;                                                            // mhpm* read zero
                    else
                        return 0;
                end
            endcase
            return 1;
        endfunction

        // Write side effects. Returns 1 if minstret was written.
        function automatic bit csr_write(logic [11:0] a, xlen_t v);
            case(a)
                12'h001: fflags = v[4:0];
                12'h002: frm = v[2:0];
                12'h003: {frm, fflags} = v[7:0];
                12'h300: begin mstatus_mie = v[3]; mstatus_mpie = v[7]; end
                12'h304: begin mie_meie = v[11]; mie_mtie = v[7]; mie_msie = v[3]; end
                12'h305: mtvec = {v[XLEN-1:2], 1'b0, v[0]};      // WARL: modes 0/1 only
                12'h340: mscratch = v;
                12'h341: mepc = {v[XLEN-1:2], 2'b00};            // IALIGN = 32
                12'h342: mcause = v;
                12'h343: mtval = v;
                12'hB02: begin minstret[XLEN-1:0] = v; return 1; end
                12'hB82: begin if(!IS_RV64) minstret[63:32] = v[31:0]; return 1; end
                default: ;                                       // RO or WARL-fixed
            endcase
            return 0;
        endfunction

        // ── Trap entry ──────────────────────────────────────────────────────
        function automatic void take_trap(ref iss_commit_t r, input bit intr,
                                          input int code, input xlen_t tv);
            r.trap = 1;
            r.interrupt = intr;
            r.cause = intr ? ((xlen_t'(1) << (XLEN-1)) | xlen_t'(code)) : xlen_t'(code);
            r.tval = intr ? '0 : tv;
            r.rd_we = 0; r.frd_we = 0; r.st_we = 0;
            mepc = {pc[XLEN-1:2], 2'b00};
            mcause = r.cause;
            mtval = r.tval;
            mstatus_mpie = mstatus_mie;
            mstatus_mie = 0;
            if(intr && (mtvec[1:0] == 2'b01))
                r.next_pc = {mtvec[XLEN-1:2], 2'b00} + xlen_t'(4 * code);
            else
                r.next_pc = {mtvec[XLEN-1:2], 2'b00};
            pc = r.next_pc;
        endfunction

        // ── FP helper ───────────────────────────────────────────────────────
        function automatic logic [31:0] fp_op(fpu_operation_t op, round_mode_t rm,
                                              logic [31:0] a, logic [31:0] b);
            logic ov, un, nan, inf, zr, inv;
            logic [31:0] res;
            flp_ref_compute(op, rm, a, b, ov, un, nan, inf, zr, inv, res);
            return res;
        endfunction

        // ── Execute one instruction (or take a pending interrupt) ────────────
        function automatic iss_commit_t step(bit ext, bit tmr, bit sw, xlen_t csr_rdata);
            iss_commit_t r;
            logic [31:0] in;
            logic [6:0]  op, f7;
            logic [2:0]  f3;
            int          rd, rs1, rs2;
            xlen_t       a, b, immI, immS, immB, immU, immJ, res, addr, t, old;
            bit          illegal, minstret_written, write_csr, csr_ok;
            int          shamt, size;
            logic [11:0] csr;

            irq_ext = ext; irq_tmr = tmr; irq_sw = sw;
            dut_csr_rdata = csr_rdata;

            r = '{default:0};
            r.pc = pc;
            in = fetch(pc);
            r.insn = in;
            r.next_pc = pc + 4;
            minstret_written = 0;

            // ── Interrupts are taken before the instruction executes ─────────
            if(mstatus_mie && ((mie_meie && ext) || (mie_msie && sw) || (mie_mtie && tmr)))
            begin
                if(mie_meie && ext)       take_trap(r, 1, 11, '0);
                else if(mie_msie && sw)   take_trap(r, 1, 3, '0);
                else                      take_trap(r, 1, 7, '0);
                return r;
            end

            op = in[6:0]; f3 = in[14:12]; f7 = in[31:25];
            rd = in[11:7]; rs1 = in[19:15]; rs2 = in[24:20];
            a = x[rs1]; b = x[rs2];
            immI = sext(xlen_t'(in[31:20]), 12);
            immS = sext(xlen_t'({in[31:25], in[11:7]}), 12);
            immB = sext(xlen_t'({in[31], in[7], in[30:25], in[11:8], 1'b0}), 13);
            immU = sext32({in[31:12], 12'b0});
            immJ = sext(xlen_t'({in[31], in[19:12], in[20], in[30:21], 1'b0}), 21);
            illegal = 0;
            res = '0;

            case(op)
                7'b0110111: begin r.rd_we = 1; res = immU; end                      // LUI
                7'b0010111: begin r.rd_we = 1; res = pc + immU; end                 // AUIPC
                7'b1101111: begin                                                   // JAL
                    t = pc + immJ;
                    if(t[1]) begin take_trap(r, 0, 0, t); return r; end
                    r.rd_we = 1; res = pc + 4; r.next_pc = t;
                end
                7'b1100111: begin                                                   // JALR
                    if(f3 != 0) illegal = 1;
                    else begin
                        t = (a + immI) & ~xlen_t'(1);
                        if(t[1]) begin take_trap(r, 0, 0, t); return r; end
                        r.rd_we = 1; res = pc + 4; r.next_pc = t;
                    end
                end
                7'b1100011: begin                                                   // Branches
                    bit taken;
                    taken = 0;
                    case(f3)
                        3'b000: taken = (a == b);
                        3'b001: taken = (a != b);
                        3'b100: taken = ($signed(a) <  $signed(b));
                        3'b101: taken = ($signed(a) >= $signed(b));
                        3'b110: taken = (a <  b);
                        3'b111: taken = (a >= b);
                        default: illegal = 1;
                    endcase
                    if(!illegal && taken)
                    begin
                        t = pc + immB;
                        if(t[1]) begin take_trap(r, 0, 0, t); return r; end
                        r.next_pc = t;
                    end
                end
                7'b0000011: begin                                                   // Loads
                    addr = a + immI;
                    size = 1;
                    case(f3)
                        3'b000, 3'b100: size = 1;
                        3'b001, 3'b101: size = 2;
                        3'b010:         size = 4;
                        3'b110:         begin size = 4; if(!IS_RV64) illegal = 1; end
                        3'b011:         begin size = 8; if(!IS_RV64) illegal = 1; end
                        default:        illegal = 1;
                    endcase
                    if(!illegal)
                    begin
                        if((addr & xlen_t'(size - 1)) != 0) begin take_trap(r, 0, 4, addr); return r; end
                        res = load(addr, size);
                        if(f3 == 3'b000)      res = sext(res, 8);
                        else if(f3 == 3'b001) res = sext(res, 16);
                        else if(f3 == 3'b010) res = sext(res, 32);
                        r.rd_we = 1;
                    end
                end
                7'b0100011: begin                                                   // Stores
                    addr = a + immS;
                    size = 1;
                    case(f3)
                        3'b000: size = 1;
                        3'b001: size = 2;
                        3'b010: size = 4;
                        3'b011: begin size = 8; if(!IS_RV64) illegal = 1; end
                        default: illegal = 1;
                    endcase
                    if(!illegal)
                    begin
                        if((addr & xlen_t'(size - 1)) != 0) begin take_trap(r, 0, 6, addr); return r; end
                        r.st_we = 1; r.st_addr = addr; r.st_size = size;
                        r.st_data = (size == XLEN/8) ? b : (b & ((xlen_t'(1) << (8*size)) - 1));
                        store(addr, size, b);
                    end
                end
                7'b0010011: begin                                                   // OP-IMM
                    r.rd_we = 1;
                    shamt = IS_RV64 ? int'(in[25:20]) : int'(in[24:20]);
                    case(f3)
                        3'b000: res = a + immI;
                        3'b010: res = ($signed(a) < $signed(immI)) ? 1 : 0;
                        3'b011: res = (a < immI) ? 1 : 0;
                        3'b100: res = a ^ immI;
                        3'b110: res = a | immI;
                        3'b111: res = a & immI;
                        3'b001: begin
                            if(IS_RV64 ? (in[31:26] != 0) : (in[31:25] != 0)) illegal = 1;
                            res = a << shamt;
                        end
                        3'b101: begin
                            if(IS_RV64 ? (in[31:26] == 6'b000000) : (in[31:25] == 7'b0000000))
                                res = a >> shamt;
                            else if(IS_RV64 ? (in[31:26] == 6'b010000) : (in[31:25] == 7'b0100000))
                                res = xlen_t'($signed(a) >>> shamt);
                            else illegal = 1;
                        end
                    endcase
                end
                7'b0110011: begin                                                   // OP
                    r.rd_we = 1;
                    if(f7 == 7'b0000000)
                        case(f3)
                            3'b000: res = a + b;
                            3'b001: res = a << b[$clog2(XLEN)-1:0];
                            3'b010: res = ($signed(a) < $signed(b)) ? 1 : 0;
                            3'b011: res = (a < b) ? 1 : 0;
                            3'b100: res = a ^ b;
                            3'b101: res = a >> b[$clog2(XLEN)-1:0];
                            3'b110: res = a | b;
                            3'b111: res = a & b;
                        endcase
                    else if(f7 == 7'b0100000)
                        case(f3)
                            3'b000: res = a - b;
                            3'b101: res = xlen_t'($signed(a) >>> b[$clog2(XLEN)-1:0]);
                            default: illegal = 1;
                        endcase
                    else if(f7 == 7'b0000001)
                        res = mul_div(f3, a, b);
                    else illegal = 1;
                end
                7'b0011011: begin                                                   // OP-IMM-32 (RV64)
                    r.rd_we = 1;
                    if(!IS_RV64) illegal = 1;
                    else case(f3)
                        3'b000: res = sext32(32'(a + immI));
                        3'b001: begin
                            if(in[31:25] != 0) illegal = 1;
                            res = sext32(32'(a) << in[24:20]);
                        end
                        3'b101: begin
                            if(in[31:25] == 7'b0000000)      res = sext32(32'(a) >> in[24:20]);
                            else if(in[31:25] == 7'b0100000) res = sext32(32'($signed(32'(a)) >>> in[24:20]));
                            else illegal = 1;
                        end
                        default: illegal = 1;
                    endcase
                end
                7'b0111011: begin                                                   // OP-32 (RV64)
                    r.rd_we = 1;
                    if(!IS_RV64) illegal = 1;
                    else if(f7 == 7'b0000000)
                        case(f3)
                            3'b000: res = sext32(32'(a + b));
                            3'b001: res = sext32(32'(a) << b[4:0]);
                            3'b101: res = sext32(32'(a) >> b[4:0]);
                            default: illegal = 1;
                        endcase
                    else if(f7 == 7'b0100000)
                        case(f3)
                            3'b000: res = sext32(32'(a - b));
                            3'b101: res = sext32(32'($signed(32'(a)) >>> b[4:0]));
                            default: illegal = 1;
                        endcase
                    else if(f7 == 7'b0000001)
                        case(f3)
                            3'b000: res = sext32(32'(a * b));
                            3'b100, 3'b101, 3'b110, 3'b111: res = mul_div_w(f3, a[31:0], b[31:0]);
                            default: illegal = 1;
                        endcase
                    else illegal = 1;
                end
                7'b0001111: begin                                                   // FENCE (FENCE.I not claimed)
                    if(f3 != 3'b000) illegal = 1;
                end
                7'b1110011: begin                                                   // SYSTEM
                    csr = in[31:20];
                    if(f3 == 3'b000)
                    begin
                        if(in[19:7] != 0) illegal = 1;
                        else if(in[31:20] == 12'h000) begin take_trap(r, 0, 11, '0); return r; end
                        else if(in[31:20] == 12'h001) begin take_trap(r, 0, 3, '0); return r; end
                        else if(in[31:20] == 12'h302)
                        begin                                                       // MRET
                            mstatus_mie = mstatus_mpie;
                            mstatus_mpie = 1;
                            r.next_pc = mepc;
                        end
                        else if(in[31:20] == 12'h105) ;                             // WFI = NOP
                        else illegal = 1;
                    end
                    else if(f3 == 3'b100) illegal = 1;
                    else
                    begin
                        xlen_t src;
                        csr_ok = csr_read(csr, old);
                        src = f3[2] ? xlen_t'(rs1) : a;
                        write_csr = (f3[1:0] == 2'b01) || (rs1 != 0);
                        if(!csr_ok) illegal = 1;
                        else if(write_csr && (csr[11:10] == 2'b11)) illegal = 1;    // read-only space
                        else
                        begin
                            r.rd_we = 1; res = old;
                            if(write_csr)
                                case(f3[1:0])
                                    2'b01: minstret_written = csr_write(csr, src);
                                    2'b10: minstret_written = csr_write(csr, old | src);
                                    2'b11: minstret_written = csr_write(csr, old & ~src);
                                endcase
                        end
                    end
                end
                7'b1010011: begin                                                   // OP-FP (single)
                    illegal = !fp_execute(in, r, res);
                end
                default: illegal = 1;
            endcase

            if(illegal)
            begin
                take_trap(r, 0, 2, '0);
                return r;
            end

            if(r.rd_we)
            begin
                r.rd = rd;
                r.rd_val = (rd == 0) ? '0 : res;
                if(rd != 0) x[rd] = res;
                else r.rd_we = 0;
            end
            if(!minstret_written)
                minstret = minstret + 1;
            pc = r.next_pc;
            return r;
        endfunction

        // ── M extension (XLEN) ──────────────────────────────────────────────
        function automatic xlen_t mul_div(logic [2:0] f3, xlen_t a, xlen_t b);
            logic signed [2*XLEN-1:0] p;
            xlen_t most_neg = xlen_t'(1) << (XLEN-1);
            case(f3)
                3'b000: return a * b;
                3'b001: begin p = $signed({{XLEN{a[XLEN-1]}}, a}) * $signed({{XLEN{b[XLEN-1]}}, b}); return p[2*XLEN-1:XLEN]; end
                3'b010: begin p = $signed({{XLEN{a[XLEN-1]}}, a}) * $signed({{XLEN{1'b0}}, b});      return p[2*XLEN-1:XLEN]; end
                3'b011: begin p = {{XLEN{1'b0}}, a} * {{XLEN{1'b0}}, b};                               return p[2*XLEN-1:XLEN]; end
                3'b100: begin
                    if(b == 0) return '1;
                    if(a == most_neg && b == '1) return most_neg;
                    return xlen_t'($signed(a) / $signed(b));
                end
                3'b101: return (b == 0) ? '1 : a / b;
                3'b110: begin
                    if(b == 0) return a;
                    if(a == most_neg && b == '1) return '0;
                    return xlen_t'($signed(a) % $signed(b));
                end
                3'b111: return (b == 0) ? a : a % b;
            endcase
            return '0;
        endfunction

        // ── RV64M word divide/remainder ────────────────────────────────────
        function automatic xlen_t mul_div_w(logic [2:0] f3, logic [31:0] a, logic [31:0] b);
            case(f3)
                3'b100: begin
                    if(b == 0) return '1;
                    if(a == 32'h8000_0000 && b == 32'hFFFF_FFFF) return sext32(a);
                    return sext32(32'($signed(a) / $signed(b)));
                end
                3'b101: return (b == 0) ? '1 : sext32(a / b);
                3'b110: begin
                    if(b == 0) return sext32(a);
                    if(a == 32'h8000_0000 && b == 32'hFFFF_FFFF) return '0;
                    return sext32(32'($signed(a) % $signed(b)));
                end
                3'b111: return (b == 0) ? sext32(a) : sext32(a % b);
            endcase
            return '0;
        endfunction

        // ── OP-FP: returns 0 for an illegal encoding ────────────────────────
        function automatic bit fp_execute(logic [31:0] in, ref iss_commit_t r, ref xlen_t res);
            logic [6:0]  f7;
            logic [2:0]  f3;
            int          rd, rs1, rs2;
            logic [31:0] fa, fb, v;
            round_mode_t rm;
            bit          uses_rm, to_fp;
            fpu_operation_t fop;

            f7 = in[31:25]; f3 = in[14:12];
            rd = in[11:7]; rs1 = in[19:15]; rs2 = in[24:20];
            fa = f[rs1]; fb = f[rs2];
            uses_rm = 0; to_fp = 0; fop = NOOPERATION;
            case(f7)
                7'b0000000: begin fop = FADD_S; uses_rm = 1; to_fp = 1; end
                7'b0000100: begin fop = FSUB_S; uses_rm = 1; to_fp = 1; end
                7'b0001000: begin fop = FMUL_S; uses_rm = 1; to_fp = 1; end
                7'b0001100: begin fop = FDIV_S; uses_rm = 1; to_fp = 1; end
                7'b0101100: begin if(rs2 != 0) return 0; fop = FSQRT_S; uses_rm = 1; to_fp = 1; end
                7'b0010000: begin
                    to_fp = 1;
                    case(f3) 3'b000: fop = FSGNJ_S; 3'b001: fop = FSGNJN_S; 3'b010: fop = FSGNJX_S; default: return 0; endcase
                end
                7'b0010100: begin
                    to_fp = 1;
                    case(f3) 3'b000: fop = FMIN_S; 3'b001: fop = FMAX_S; default: return 0; endcase
                end
                7'b1100000: begin
                    uses_rm = 1;
                    case(rs2) 0: fop = FCVT_W_S; 1: fop = FCVT_WU_S; default: return 0; endcase
                end
                7'b1110000: begin
                    if(rs2 != 0) return 0;
                    case(f3) 3'b000: fop = FMV_X_S; 3'b001: fop = FCLASS_S; default: return 0; endcase
                end
                7'b1010000: begin
                    case(f3) 3'b010: fop = FEQ_S; 3'b001: fop = FLT_S; 3'b000: fop = FLE_S; default: return 0; endcase
                end
                7'b1101000: begin
                    uses_rm = 1; to_fp = 1;
                    case(rs2) 0: fop = FCVT_S_W; 1: fop = FCVT_S_WU; default: return 0; endcase
                    fa = x[rs1][31:0];
                end
                7'b1111000: begin
                    if(rs2 != 0 || f3 != 0) return 0;
                    to_fp = 1; fop = FMV_S_X;
                    fa = x[rs1][31:0];
                end
                default: return 0;
            endcase

            rm = round_mode_t'(f3);
            if(uses_rm)
            begin
                if(f3 == 3'b101 || f3 == 3'b110) return 0;     // reserved rm
                if(f3 == 3'b111) rm = round_mode_t'(frm);       // DYN
            end
            v = fp_op(fop, rm, fa, fb);
            if(to_fp)
            begin
                r.frd_we = 1; r.frd = rd; r.frd_val = v;
                f[rd] = v;
            end
            else
            begin
                r.rd_we = 1;
                res = sext32(v);
            end
            return 1;
        endfunction

    endclass:riscv_iss

endpackage:riscv_iss_pkg
