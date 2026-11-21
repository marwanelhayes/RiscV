// =============================================================================
// riscv_iss_pkg.sv
// -----------------------------------------------------------------------------
// Instruction-set simulator (ISA golden model) for the full-core checker.
//
// Written from the RISC-V specifications, NOT from the RTL, so a wrong design
// choice in the RTL shows up as a mismatch instead of being copied into the
// model:
//   - Unprivileged: RV32I / RV64I (incl. the RV64-only W/LD/SD/LWU forms),
//     M, A (Zalrsc + Zaamo, .W and RV64 .D), Zicsr, the F subset the FPU
//     implements, FENCE and Zifencei
//   - Privileged: M, S and U modes (B3, B4) - mstatus/mie/mip/mtvec/mepc/
//     mcause/mtval, mcounteren, menvcfg(h), the S CSRs (sstatus/sie/sip are
//     views), medeleg/mideleg trap delegation, MRET, SRET, WFI (NOP), ECALL
//     from U/S/M, CSR privilege and counter checks, synchronous exceptions
//     and interrupts (M group first, then the S-delegated group)
//
// Implementation choices the specs leave open are modelled the way the core
// documents them (shared memory truncated to ADDR_WIDTH, misaligned
// load/store traps, mtval = 0 except for address faults, WARL legalisation of
// mtvec/mepc, mstatus.MPP holds U, S or M (10 -> U) and resets to U,
// mstatus.FS real (resets Off, FP register or fcsr write sets Dirty), no mcountinhibit, menvcfg(h)/senvcfg/satp read zero
// (no MMU: SUM/MXR/TVM read 0), no scontext, the CSR set of B1.6, B3.1 and
// B4.1).
// A extension choices: the reservation set is the exact LR address, every SC
// clears it, traps and MRET do not (Spike's policy); a misaligned LR raises
// a load-address-misaligned, a misaligned SC/AMO a store/AMO-address-
// misaligned exception (both allowed by Zalrsc/Zaamo; Spike does the same).
//
// Non-deterministic state (mcycle and its aliases) is not predicted: the
// checker hands the DUT's read value to step(), which uses it. time/timeh
// read the TB's mtime, also an input of step().
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
    localparam logic [63:0] MSTATUS_UXL64   = 64'h2_0000_0000;  // UXL = 2 (RV64 only)
    localparam logic [63:0] MSTATUS_SXL64   = 64'h8_0000_0000;  // SXL = 2 (RV64 only)
    localparam logic [63:0] SSTATUS_MASK64  = IS_RV64 ? 64'h8000_0002_0000_6122 : 64'h8000_6122;

    typedef logic [XLEN-1:0] xlen_t;

    // ── Result of one step (one committed instruction or one taken trap) ─────
    typedef struct {
        xlen_t       pc;            // PC of the instruction
        logic [31:0] insn;          // Instruction bits
        bit          trap;          // Exception or interrupt taken instead
        bit          to_s;          // The trap was taken in S-mode (delegated)
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
        logic [1:0]  priv;          // current privilege mode (0 = U, 1 = S, 3 = M)
        bit          mstatus_mie, mstatus_mpie;
        logic [1:0]  mstatus_mpp;   // U (00), S (01) or M (11)
        bit          mstatus_mprv, mstatus_tw;
        bit          mstatus_sie, mstatus_spie, mstatus_spp, mstatus_tsr;
        logic [2:0]  mcounteren;    // IR, TM, CY
        logic [2:0]  scounteren;    // IR, TM, CY
        bit          mie_meie, mie_mtie, mie_msie, mie_seie, mie_stie, mie_ssie;
        bit          mip_ssip, mip_stip, mip_seip_sw;   // software-writable mip bits
        logic [2:0]  mideleg;       // SEI, STI, SSI
        logic [19:0] medeleg;
        xlen_t       mtvec, mscratch, mepc, mcause, mtval;
        xlen_t       stvec, sscratch, sepc, scause, stval;
        bit          last_trap_to_s;     // the last take_trap went to S
        logic [63:0] minstret;
        bit [1:0]    mstatus_fs;    // 0 Off, 1 Initial, 2 Clean, 3 Dirty
        logic [4:0]  fflags;
        logic [2:0]  frm;
        bit          res_valid;     // LR/SC reservation
        xlen_t       res_addr;

        // Unified instruction and data memory.
        logic [7:0]  dmem [int];    // byte address -> byte (absent = 0)
        logic [7:0]  dmem_init [int]; // data image restored on every reset (load_data)

        // ── Inputs of the current step ──────────────────────────────────────
        bit          irq_ext, irq_tmr, irq_sw, irq_sext;
        xlen_t       dut_csr_rdata;  // DUT read value for unpredictable CSRs
        logic [63:0] mtime;          // TB mtime (time/timeh)

        function new();
            reset();
        endfunction

        function void reset();
            pc = '0;
            foreach (x[i]) x[i] = '0;
            foreach (f[i]) f[i] = '0;
            priv = 2'b11;
            mstatus_mie = 0; mstatus_mpie = 0;
            mstatus_mpp = 2'b00; mstatus_mprv = 0; mstatus_tw = 0; mcounteren = '0;
            mstatus_sie = 0; mstatus_spie = 0; mstatus_spp = 0; mstatus_tsr = 0; scounteren = '0;
            mie_meie = 0; mie_mtie = 0; mie_msie = 0; mie_seie = 0; mie_stie = 0; mie_ssie = 0;
            mip_ssip = 0; mip_stip = 0; mip_seip_sw = 0; mideleg = '0; medeleg = '0;
            mtvec = '0; mscratch = '0; mepc = '0; mcause = '0; mtval = '0;
            stvec = '0; sscratch = '0; sepc = '0; scause = '0; stval = '0;
            last_trap_to_s = 0;
            minstret = '0; fflags = '0; frm = '0; mstatus_fs = 2'b00;
            res_valid = 0; res_addr = '0;
            dmem = dmem_init;
        endfunction

        // Program image: one 32-bit instruction per line, binary ($readmemb)
        function void load_image(string path);
            int fd, n;
            string line;
            dmem_init.delete();
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
                    for(int i = 0; i < 4; i++) dmem_init[4*n+i] = w[8*i +: 8];
                    n++;
                end
                else
                    void'($fgets(line, fd));
            end
            $fclose(fd);
            dmem = dmem_init;
        endfunction

        // Initial data memory: one XLEN-bit little-endian word per line, hex
        // ($readmemh, as loaded into the TB data memory); word i starts at byte i*XLEN/8
        function void load_data(string path);
            int fd, n;
            xlen_t w;
            fd = $fopen(path, "r");
            if(fd == 0)
            begin
                $error("riscv_iss: cannot open %s", path);
                return;
            end
            n = 0;
            while($fscanf(fd, "%h", w) == 1)
            begin
                for(int i = 0; i < XLEN/8; i++)
                    dmem_init[n*(XLEN/8) + i] = w[8*i +: 8];
                n++;
            end
            $fclose(fd);
            dmem = dmem_init;
        endfunction

        // ── Memory helpers ──────────────────────────────────────────────────
        function automatic int paddr(xlen_t a);
            return int'(a[PADDR_W-1:0]);
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

        function automatic logic [31:0] fetch(xlen_t a);
            return 32'(load(a, 4));
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

        // ── CSRs (the set documented in B1.6 and B3.1) ──────────────────────
        function automatic xlen_t mstatus_value();
            xlen_t v = '0;
            v[3]  = mstatus_mie;
            v[7]  = mstatus_mpie;
            v[12:11] = mstatus_mpp;
            v[14:13] = mstatus_fs;
            v[1]  = mstatus_sie;
            v[5]  = mstatus_spie;
            v[8]  = mstatus_spp;
            v[17] = mstatus_mprv;
            v[21] = mstatus_tw;
            v[22] = mstatus_tsr;
            v[XLEN-1] = (mstatus_fs == 2'b11);   // SD
            if(IS_RV64) v = v | MSTATUS_UXL64[XLEN-1:0] | MSTATUS_SXL64[XLEN-1:0];
            return v;
        endfunction

        // mideleg spread to the mip/mie bit positions
        function automatic xlen_t deleg_mask();
            xlen_t m = '0;
            m[9] = mideleg[2]; m[5] = mideleg[1]; m[1] = mideleg[0];
            return m;
        endfunction

        function automatic xlen_t mie_value();
            xlen_t v = '0;
            v[11] = mie_meie; v[7] = mie_mtie; v[3] = mie_msie;
            v[9] = mie_seie;  v[5] = mie_stie; v[1] = mie_ssie;
            return v;
        endfunction

        // mip as read: M bits are the lines, SEIP is the software bit OR the line
        function automatic xlen_t mip_value();
            xlen_t v = '0;
            v[11] = irq_ext; v[7] = irq_tmr; v[3] = irq_sw;
            v[9] = mip_seip_sw | irq_sext; v[5] = mip_stip; v[1] = mip_ssip;
            return v;
        endfunction

        // Returns 0 if the CSR does not exist or is not accessible in the
        // current mode (privilege field csr[9:8], mcounteren gate in U)
        function automatic bit csr_read(logic [11:0] a, output xlen_t v);
            v = '0;
            if(a[9:8] > priv) return 0;
            if(a inside {12'h001, 12'h002, 12'h003} && mstatus_fs == 2'b00) return 0;   // FS Off
            // mcounteren gates S and U, scounteren gates U as well
            for(int i = 0; i < 3; i++)
                if((a inside {12'hC00 + 12'(i), 12'hC80 + 12'(i)}) &&
                   (((priv != 2'b11) && !mcounteren[i]) || ((priv == 2'b00) && !scounteren[i])))
                    return 0;
            case(a)
                12'h001: v = xlen_t'(fflags);
                12'h002: v = xlen_t'(frm);
                12'h003: v = xlen_t'({frm, fflags});
                12'h300: v = mstatus_value();
                12'h301: v = {(IS_RV64 ? 2'd2 : 2'd1), {(XLEN-2){1'b0}}} |
                             (xlen_t'(1) << 8) | (xlen_t'(1) << 12) | (xlen_t'(1) << 5) |  // I, M, F
                             (xlen_t'(1) << 18) | (xlen_t'(1) << 20) | xlen_t'(1);          // S, U, A
                12'h302: v = xlen_t'(medeleg);
                12'h303: v = deleg_mask();
                12'h304: v = mie_value();
                12'h100: v = mstatus_value() & xlen_t'(SSTATUS_MASK64);
                12'h104: v = mie_value() & deleg_mask();
                12'h105: v = stvec;
                12'h106: v = xlen_t'(scounteren);
                12'h10A, 12'h180: v = '0;                                                   // senvcfg, satp
                12'h140: v = sscratch;
                12'h141: v = sepc;
                12'h142: v = scause;
                12'h143: v = stval;
                12'h144: v = mip_value() & deleg_mask();
                12'h312: begin if(IS_RV64) return 0; v = '0; end                          // medelegh
                12'h305: v = mtvec;
                12'h306: v = xlen_t'(mcounteren);
                12'h30A: v = '0;                                                            // menvcfg
                12'h31A: begin if(IS_RV64) return 0; v = '0; end                          // menvcfgh
                12'h340: v = mscratch;
                12'h341: v = mepc;
                12'h342: v = mcause;
                12'h343: v = mtval;
                12'h344: v = mip_value();
                12'h310: begin if(IS_RV64) return 0; v = '0; end                          // mstatush
                12'hB00, 12'hC00: v = dut_csr_rdata;                                        // mcycle / cycle
                12'hB80, 12'hC80: begin if(IS_RV64) return 0; v = dut_csr_rdata; end        // mcycleh / cycleh
                12'hC01: v = mtime[XLEN-1:0];                                               // time
                12'hC81: begin if(IS_RV64) return 0; v = xlen_t'(mtime[63:32]); end         // timeh
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
                12'h001: begin fflags = v[4:0]; mstatus_fs = 2'b11; end
                12'h002: begin frm = v[2:0]; mstatus_fs = 2'b11; end
                12'h003: begin {frm, fflags} = v[7:0]; mstatus_fs = 2'b11; end
                12'h300: begin
                    mstatus_mie = v[3]; mstatus_mpie = v[7];
                    mstatus_mpp = (v[12:11] == 2'b10) ? 2'b00 : v[12:11];   // WARL: H -> U
                    mstatus_mprv = v[17]; mstatus_tw = v[21]; mstatus_fs = v[14:13];
                    mstatus_sie = v[1]; mstatus_spie = v[5]; mstatus_spp = v[8]; mstatus_tsr = v[22];
                end
                12'h100: begin mstatus_sie = v[1]; mstatus_spie = v[5]; mstatus_spp = v[8]; mstatus_fs = v[14:13]; end
                12'h302: medeleg = v[19:0] & 20'h8_03FF;
                12'h303: mideleg = {v[9], v[5], v[1]};
                12'h304: begin
                    mie_meie = v[11]; mie_mtie = v[7]; mie_msie = v[3];
                    mie_seie = v[9]; mie_stie = v[5]; mie_ssie = v[1];
                end
                12'h104: begin                                   // only the delegated bits change
                    if(mideleg[2]) mie_seie = v[9];
                    if(mideleg[1]) mie_stie = v[5];
                    if(mideleg[0]) mie_ssie = v[1];
                end
                12'h344: begin mip_seip_sw = v[9]; mip_stip = v[5]; mip_ssip = v[1]; end
                12'h144: if(mideleg[0]) mip_ssip = v[1];         // SSIP only
                12'h105: stvec = {v[XLEN-1:2], 1'b0, v[0]};
                12'h106: scounteren = v[2:0];
                12'h140: sscratch = v;
                12'h141: sepc = {v[XLEN-1:2], 2'b00};
                12'h142: scause = v;
                12'h143: stval = v;
                12'h305: mtvec = {v[XLEN-1:2], 1'b0, v[0]};      // WARL: modes 0/1 only
                12'h306: mcounteren = v[2:0];
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
        // Delegated to S by mideleg/medeleg, never from M
        function automatic bit trap_to_s(bit intr, int code);
            xlen_t dm = deleg_mask();
            return (priv != 2'b11) && (intr ? dm[code] : ((code < 20) && medeleg[code]));
        endfunction

        function automatic void take_trap(ref iss_commit_t r, input bit intr,
                                          input int code, input xlen_t tv);
            r.trap = 1;
            r.interrupt = intr;
            r.cause = intr ? ((xlen_t'(1) << (XLEN-1)) | xlen_t'(code)) : xlen_t'(code);
            r.tval = intr ? '0 : tv;
            r.rd_we = 0; r.frd_we = 0; r.st_we = 0;
            // Delegated to S unless taken from M
            r.to_s = trap_to_s(intr, code);
            last_trap_to_s = r.to_s;
            if(r.to_s)
            begin
                sepc = {pc[XLEN-1:2], 2'b00};
                scause = r.cause;
                stval = r.tval;
                mstatus_spie = mstatus_sie;
                mstatus_sie = 0;
                mstatus_spp = (priv == 2'b01);
                priv = 2'b01;
                if(intr && (stvec[1:0] == 2'b01))
                    r.next_pc = {stvec[XLEN-1:2], 2'b00} + xlen_t'(4 * code);
                else
                    r.next_pc = {stvec[XLEN-1:2], 2'b00};
            end
            else
            begin
                mepc = {pc[XLEN-1:2], 2'b00};
                mcause = r.cause;
                mtval = r.tval;
                mstatus_mpie = mstatus_mie;
                mstatus_mie = 0;
                mstatus_mpp = priv;
                priv = 2'b11;
                if(intr && (mtvec[1:0] == 2'b01))
                    r.next_pc = {mtvec[XLEN-1:2], 2'b00} + xlen_t'(4 * code);
                else
                    r.next_pc = {mtvec[XLEN-1:2], 2'b00};
            end
            pc = r.next_pc;
        endfunction

        // ── Privilege rules (also used by the CSR and execute predictors) ────
        // Interrupt taken before the next instruction, or -1 for none. The M-routed
        // group goes first (always enabled below M), then the S-delegated group
        // (enabled in U, in S with SIE, never in M). Order in a group: MEI MSI MTI SEI SSI STI.
        function automatic int irq_code(bit ext, bit tmr, bit sw, bit sline = 0);
            xlen_t pend, sel;
            bit    en_m, en_s;
            irq_ext = ext; irq_tmr = tmr; irq_sw = sw; irq_sext = sline;
            pend = mip_value() & mie_value();
            en_m = mstatus_mie || (priv != 2'b11);
            en_s = (priv == 2'b00) || ((priv == 2'b01) && mstatus_sie);
            sel = pend & ~deleg_mask() & {XLEN{en_m}};
            if(sel == 0) sel = pend & deleg_mask() & {XLEN{en_s}};
            if(sel[11]) return 11;
            if(sel[3])  return 3;
            if(sel[7])  return 7;
            if(sel[9])  return 9;
            if(sel[1])  return 1;
            if(sel[5])  return 5;
            return -1;
        endfunction

        function automatic int ecall_code();
            return (priv == 2'b00) ? 8 : (priv == 2'b01) ? 9 : 11;
        endfunction

        // MRET outside M, SRET in U or in S with TSR, WFI below M with TW = 1 or in U
        function automatic bit sys_illegal(bit mret, bit sret, bit wfi);
            return (mret && (priv != 2'b11)) ||
                   (sret && ((priv == 2'b00) || ((priv == 2'b01) && mstatus_tsr))) ||
                   (wfi && (priv != 2'b11) && (mstatus_tw || (priv == 2'b00)));
        endfunction

        // SRET state change (the caller jumps to sepc)
        function automatic void do_sret();
            priv = mstatus_spp ? 2'b01 : 2'b00;
            mstatus_sie = mstatus_spie;
            mstatus_spie = 1;
            mstatus_spp = 0;
            mstatus_mprv = 0;
        endfunction

        // MRET state change (the caller jumps to mepc)
        function automatic void do_mret();
            mstatus_mie = mstatus_mpie;
            mstatus_mpie = 1;
            priv = mstatus_mpp;
            if(mstatus_mpp != 2'b11) mstatus_mprv = 0;
            mstatus_mpp = 2'b00;
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
        function automatic iss_commit_t step(bit ext, bit tmr, bit sw, xlen_t csr_rdata, logic [63:0] mtime, bit sline = 0);
            iss_commit_t r;
            logic [31:0] in;
            logic [6:0]  op, f7;
            logic [2:0]  f3;
            int          rd, rs1, rs2;
            xlen_t       a, b, immI, immS, immB, immU, immJ, res, addr, t, old;
            bit          illegal, minstret_written, write_csr, csr_ok;
            int          shamt, size, irq;
            logic [11:0] csr;

            irq_ext = ext; irq_tmr = tmr; irq_sw = sw; irq_sext = sline;
            dut_csr_rdata = csr_rdata;
            this.mtime = mtime;

            r = '{default:0};
            r.pc = pc;
            in = fetch(pc);
            r.insn = in;
            r.next_pc = pc + 4;
            minstret_written = 0;

            // ── Interrupts are taken before the instruction executes ─────────
            irq = irq_code(ext, tmr, sw, sline);
            if(irq >= 0)
            begin
                take_trap(r, 1, irq, '0);
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
                7'b0101111: begin                                                   // AMO (A extension)
                    if(!amo_execute(in, r, res))
                        illegal = 1;
                    else if(r.trap)
                        return r;
                end
                7'b0001111: begin                                                   // FENCE / FENCE.I (coherent ISS memory)
                    if(!(f3 inside {3'b000, 3'b001})) illegal = 1;
                end
                7'b1110011: begin                                                   // SYSTEM
                    csr = in[31:20];
                    if(f3 == 3'b000)
                    begin
                        if(in[19:7] != 0) illegal = 1;
                        else if(in[31:20] == 12'h000) begin take_trap(r, 0, ecall_code(), '0); return r; end
                        else if(in[31:20] == 12'h001) begin take_trap(r, 0, 3, '0); return r; end
                        else if(in[31:20] == 12'h302)
                        begin                                                       // MRET
                            if(sys_illegal(1, 0, 0)) illegal = 1;
                            else begin do_mret(); r.next_pc = mepc; end
                        end
                        else if(in[31:20] == 12'h102)
                        begin                                                       // SRET
                            if(sys_illegal(0, 1, 0)) illegal = 1;
                            else begin do_sret(); r.next_pc = sepc; end
                        end
                        else if(in[31:20] == 12'h105)                               // WFI = NOP
                            illegal = sys_illegal(0, 0, 1);
                        else illegal = 1;
                    end
                    else if(f3 == 3'b100) illegal = 1;
                    else
                    begin
                        xlen_t src, old_w;
                        csr_ok = csr_read(csr, old);
                        old_w = old;
                        if(csr == 12'h344) old_w[9] = mip_seip_sw;               // mip RMW base: software SEIP
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
                                    2'b10: minstret_written = csr_write(csr, old_w | src);
                                    2'b11: minstret_written = csr_write(csr, old_w & ~src);
                                endcase
                        end
                    end
                end
                7'b1010011: begin                                                   // OP-FP (single)
                    illegal = (mstatus_fs == 2'b00) || !fp_execute(in, r, res);   // FS Off
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

        // ── A extension: LR / SC / AMO*. Returns 0 for an illegal encoding;
        //    a misaligned address takes the trap in r (r.trap = 1) ───────────
        function automatic bit amo_execute(logic [31:0] in, ref iss_commit_t r, ref xlen_t res);
            logic [4:0]  f5;
            logic [2:0]  f3;
            int          rs1, rs2, size;
            xlen_t       addr, src, mval, wval;

            f5 = in[31:27]; f3 = in[14:12];
            rs1 = in[19:15]; rs2 = in[24:20];
            if(f3 == 3'b010)                size = 4;
            else if(f3 == 3'b011 && IS_RV64) size = 8;
            else return 0;
            if(!(f5 inside {5'b00000, 5'b00001, 5'b00010, 5'b00011, 5'b00100, 5'b01000,
                            5'b01100, 5'b10000, 5'b10100, 5'b11000, 5'b11100}))
                return 0;
            if(f5 == 5'b00010 && rs2 != 0) return 0;                  // LR: rs2 must be x0

            addr = x[rs1];
            if((addr & xlen_t'(size - 1)) != 0)
            begin
                take_trap(r, 0, (f5 == 5'b00010) ? 4 : 6, addr);       // LR: load, SC/AMO: store
                return 1;
            end

            src = x[rs2];
            mval = load(addr, size);
            if(size == 4) begin mval = sext(mval, 32); src = sext(src, 32); end
            r.rd_we = 1;
            case(f5)
                5'b00010: begin                                       // LR
                    res = mval;
                    res_valid = 1;
                    res_addr = addr;
                    return 1;
                end
                5'b00011: begin                                       // SC
                    res = (res_valid && (res_addr == addr)) ? '0 : xlen_t'(1);
                    if(res == 0)
                    begin
                        r.st_we = 1; r.st_addr = addr; r.st_size = size;
                        r.st_data = (size == XLEN/8) ? src : (src & ((xlen_t'(1) << (8*size)) - 1));
                        store(addr, size, src);
                    end
                    res_valid = 0;
                    return 1;
                end
                5'b00001: wval = src;                                 // AMOSWAP
                5'b00000: wval = mval + src;                          // AMOADD
                5'b00100: wval = mval ^ src;                          // AMOXOR
                5'b01100: wval = mval & src;                          // AMOAND
                5'b01000: wval = mval | src;                          // AMOOR
                5'b10000: wval = ($signed(mval) < $signed(src)) ? mval : src;   // AMOMIN
                5'b10100: wval = ($signed(mval) > $signed(src)) ? mval : src;   // AMOMAX
                5'b11000: wval = (size == 4) ? ((mval[31:0] < src[31:0]) ? mval : src)
                                             : ((mval < src) ? mval : src);    // AMOMINU
                default:  wval = (size == 4) ? ((mval[31:0] > src[31:0]) ? mval : src)
                                             : ((mval > src) ? mval : src);    // AMOMAXU
            endcase
            res = mval;
            r.st_we = 1; r.st_addr = addr; r.st_size = size;
            r.st_data = (size == XLEN/8) ? wval : (wval & ((xlen_t'(1) << (8*size)) - 1));
            store(addr, size, wval);
            return 1;
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
                mstatus_fs = 2'b11;
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
