// =============================================================================
// commit_checker.sv
// -----------------------------------------------------------------------------
// Full-core architectural checker: lock-steps the ISA golden model
// (riscv_iss_pkg) with the core and reports the first divergences.
//
// Bound into riscv_processor from risc_top. Every signal is sampled at the
// falling edge, when the cycle's combinational values are settled and before
// the next rising edge latches them.
//
// Events compared:
//   - EX commit (ValidE && !StallE): the ISS steps once. PC, trap/no-trap and
//     the next PC (or trap vector) must match; one cycle after a trap the
//     DUT's mepc/mcause/mtval must equal the ISS's.
//   - MEM store (a new store in EX/MEM): PC, address, size and data must
//     match the oldest store the ISS performed. An SC / AMO* is checked when
//     its D-cache write completes instead (AtomicStoreM): its data is only
//     known then, and a failed SC writes nothing.
//   - WB write (a new instruction in MEM/WB): rd/value and frd/value must match
//     the oldest register write the ISS performed.
//
// The program ends at a self-loop (JAL x0, 0); the checker then triggers the
// global "ISS_DONE" uvm_event.
//
// Compliance programs (riscv-tests, see Verification/Compliance) also have a
// data image (dmem.hex, preloaded into the ISS here and into the TB data memory
// by risc_top) and a tohost address (tohost.txt). Their end is the first store
// to tohost: 1 means the test passed, any other value v means test case v>>1
// failed. risc_test drains the pipeline and triggers
// "ISS_FINAL", on which the checker verifies that every expected write was
// seen (still inside the UVM run phase, so the errors are counted).
//
// With +SPIKE (and -sv_lib Verification/Risc/spike/libspike_dpi), Spike is
// stepped next to the ISS on every commit with the same inputs and the two
// commit records must be identical. The DUT is already checked against the
// ISS, so a Spike-only mismatch means the ISS and the RTL share a misreading
// of the spec (see spike/spike_dpi.cc for the core profile Spike runs with).
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;
import riscv_iss_pkg::*;
import tb_base_pkg::*;

module commit_checker
(
    input logic                        clk,
    input logic                        rst,

    // ── Interrupt lines ───────────────────────────────────────────────────────
    input logic                        ExternalInterrupt,
    input logic                        TimerInterrupt,
    input logic                        SoftwareInterrupt,

    // ── EX stage (commit point) ───────────────────────────────────────────────
    input logic                        ValidE,
    input logic                        StallE,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4E,
    input logic                        PCSrcE,
    input logic [FINAL_DATA_WIDTH-1:0] PCTargetE,
    input logic                        TrapIsSet,
    input logic                        TrapTakenE,
    input logic [FINAL_DATA_WIDTH-1:0] CsrOutPC,
    input logic [FINAL_DATA_WIDTH-1:0] CsrReadE,
    input logic [FINAL_DATA_WIDTH-1:0] MepcE,
    input logic [FINAL_DATA_WIDTH-1:0] McauseE,
    input logic [FINAL_DATA_WIDTH-1:0] MtvalE,

    // ── MEM stage (stores) ────────────────────────────────────────────────────
    input logic                        ValidM,
    input logic                        StallM,
    input logic                        MemWriteM,
    input logic [FINAL_DATA_WIDTH-1:0] ALUOutM,
    input logic [2:0]                  funct3M,
    input logic [FINAL_DATA_WIDTH-1:0] WriteDataM,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4M,
    input logic                        AmoM,
    input logic                        AtomicStoreM,         // SC / AMO* cache write completes
    input logic [FINAL_DATA_WIDTH-1:0] AtomicStoreDataM,     // its data (before lane replication)

    // ── WB stage (register writes) ───────────────────────────────────────────
    input logic                        ValidW,
    input logic                        StallW,
    input logic                        RegWriteW,
    input gpr_t                        RdW,
    input logic [FINAL_DATA_WIDTH-1:0] ResultW,
    input logic                        FPURegWriteW,
    input fpr_t                        RdFW,
    input logic [FINAL_FLP_WIDTH-1:0]  FPUOutW
);

    localparam int XL = FINAL_DATA_WIDTH;
    localparam logic [31:0] SELF_LOOP = 32'h0000_006F;      // JAL x0, 0

    typedef struct { int rd; logic [XL-1:0] val; xlen_t pc; } wr_t;
    typedef struct { xlen_t addr; int size; xlen_t data; xlen_t pc; } st_t;

    // ── Spike lock-step (Verification/Risc/spike/spike_dpi.cc) ─────────────────
    import "DPI-C" function int  spike_init(int xlen, string image, int unsigned mvendorid);
    import "DPI-C" function void spike_reset();
    import "DPI-C" function void spike_step(input bit ext, input bit tmr, input bit sw,
        input longint unsigned csr_rdata,
        output longint unsigned pc, output int unsigned insn, output bit trap, output bit interrupt,
        output longint unsigned cause, output longint unsigned tval,
        output bit rd_we, output int rd, output longint unsigned rd_val,
        output bit frd_we, output int frd, output int unsigned frd_val,
        output bit st_we, output longint unsigned st_addr, output int st_size,
        output longint unsigned st_data, output longint unsigned next_pc);

    localparam int SPIKE_MAX_ERRORS = 10;   // the models diverge after the first mismatch

    bit          use_spike;               // +SPIKE given
    bit          spike_on;                // still comparing
    int unsigned spike_commits, spike_errors;

    riscv_iss    iss;
    wr_t         gpr_q[$], fpr_q[$];
    st_t         st_q[$];
    iss_commit_t hist[$];                 // last commits, for error context
    bit          m_new, w_new;            // EX/MEM, MEM/WB loaded at the last edge
    bit          check_trap_csrs;         // a trap was taken at the last edge
    bit          done;
    bit          tohost_on;               // compliance program: end on a store to tohost
    xlen_t       tohost_addr, tohost_val;
    int unsigned commits, traps, interrupts, errors;
    uvm_event    done_ev, final_ev;

    initial
    begin
        iss = new();
        iss.load_image(program_file("binary1.txt"));
        if(file_exists(program_file("dmem.hex")))
            iss.load_data(program_file("dmem.hex"));
        if(file_exists(program_file("tohost.txt")))
        begin
            int fd;
            fd = $fopen(program_file("tohost.txt"), "r");
            tohost_on = ($fscanf(fd, "%h", tohost_addr) == 1);
            $fclose(fd);
        end
        done_ev  = uvm_event_pool::get_global("ISS_DONE");
        final_ev = uvm_event_pool::get_global("ISS_FINAL");
        use_spike = $test$plusargs("SPIKE");
        if(use_spike)
        begin
            if(spike_init(XL, program_file("binary1.txt"), MVENDORID_VALUE) != 0)
                `uvm_fatal("SPIKE_CHK", "spike_init failed")
            spike_reset();
            spike_on = 1;
        end
        final_ev.wait_trigger();
        if(gpr_q.size() || st_q.size() || fpr_q.size())
            `uvm_error("ISS_CHK", $sformatf("expected writes never seen: %0d integer, %0d FP, %0d stores",
                                            gpr_q.size(), fpr_q.size(), st_q.size()))
        if(commits == 0)
            `uvm_error("ISS_CHK", "no instruction was committed")
        if(!done)
            `uvm_error("ISS_CHK", tohost_on ? "the program never wrote tohost" : "the program never reached its end (self-loop)")
        else if(tohost_on)
        begin
            if(tohost_val == 1)
                `uvm_info("COMPLIANCE", "PASS: the test wrote tohost = 1", UVM_LOW)
            else
                `uvm_error("COMPLIANCE", $sformatf("FAIL: test case %0d failed (tohost = %h)", tohost_val >> 1, tohost_val))
        end
        `uvm_info("ISS_CHK", $sformatf("summary: %0d commits, %0d traps, %0d interrupts, %0d mismatches",
                                       commits, traps, interrupts, errors), UVM_LOW)
        if(use_spike)
        begin
            if(spike_commits == 0)
                `uvm_error("SPIKE_CHK", "no commit was compared against Spike")
            `uvm_info("SPIKE_CHK", $sformatf("summary: %0d commits compared with Spike, %0d mismatches%s",
                                             spike_commits, spike_errors, spike_on ? "" : " (comparison stopped)"), UVM_LOW)
        end
    end

    function automatic bit file_exists(string path);
        int fd = $fopen(path, "r");
        if(fd != 0) $fclose(fd);
        return fd != 0;
    endfunction

    function automatic string fmt(iss_commit_t c);
        return $sformatf("pc=%h insn=%h trap=%0d cause=%h rd_we=%0d x%0d=%h frd_we=%0d f%0d=%h st=%0d next=%h",
                         c.pc, c.insn, c.trap, c.cause, c.rd_we, c.rd, c.rd_val,
                         c.frd_we, c.frd, c.frd_val, c.st_we, c.next_pc);
    endfunction

    function automatic void fail(string what);
        string ctx = "";
        errors++;
        foreach (hist[i]) ctx = {ctx, "\n    ", fmt(hist[i])};
        `uvm_error("ISS_CHK", $sformatf("%s\n  last ISS commits (oldest first):%s", what, ctx))
    endfunction

    // Step Spike with the inputs the ISS just used and compare the two records
    function automatic void spike_check(iss_commit_t r, bit ext, bit tmr, bit sw, logic [XL-1:0] csr_rdata);
        iss_commit_t s;
        longint unsigned pc, cause, tval, rd_val, st_addr, st_data, next_pc;
        int unsigned     insn, frd_val;
        bit              trap, intr, rd_we, frd_we, st_we;
        int              rd, frd, st_size;
        logic [XL-1:0]   st_mask;
        string           diff;

        spike_step(ext, tmr, sw, 64'(csr_rdata), pc, insn, trap, intr, cause, tval,
                   rd_we, rd, rd_val, frd_we, frd, frd_val, st_we, st_addr, st_size, st_data, next_pc);
        spike_commits++;
        s = '{default:0};
        s.pc = xlen_t'(pc); s.insn = insn; s.trap = trap; s.interrupt = intr;
        s.cause = xlen_t'(cause); s.tval = xlen_t'(tval);
        s.rd_we = rd_we; s.rd = rd; s.rd_val = xlen_t'(rd_val);
        s.frd_we = frd_we; s.frd = frd; s.frd_val = frd_val;
        s.st_we = st_we; s.st_addr = xlen_t'(st_addr); s.st_size = st_size; s.st_data = xlen_t'(st_data);
        s.next_pc = xlen_t'(next_pc);

        diff = "";
        if((s.pc !== r.pc) || (s.insn !== r.insn))       diff = {diff, " pc/insn"};
        if(s.trap != r.trap)                              diff = {diff, " trap"};
        else if(r.trap)
        begin
            if((s.cause !== r.cause) || (s.interrupt != r.interrupt)) diff = {diff, " cause"};
            if(s.tval !== r.tval)                         diff = {diff, " tval"};
        end
        else
        begin
            if((r.rd_we && r.rd != 0) != s.rd_we)         diff = {diff, " rd_we"};
            else if(s.rd_we && ((s.rd != r.rd) || (s.rd_val !== r.rd_val))) diff = {diff, " rd"};
            if(s.frd_we != r.frd_we)                      diff = {diff, " frd_we"};
            else if(s.frd_we && ((s.frd != r.frd) || (s.frd_val !== r.frd_val))) diff = {diff, " frd"};
            if(s.st_we != r.st_we)                        diff = {diff, " st_we"};
            else if(s.st_we)
            begin
                st_mask = (s.st_size >= XL/8) ? '1 : ((XL'(1) << (8*s.st_size)) - 1);
                if((s.st_addr !== r.st_addr) || (s.st_size != r.st_size) ||
                   ((s.st_data & st_mask) !== (r.st_data & st_mask)))
                    diff = {diff, " store"};
            end
        end
        if(s.next_pc !== r.next_pc)                       diff = {diff, " next_pc"};

        if(diff != "")
        begin
            spike_errors++;
            `uvm_error("SPIKE_CHK", $sformatf("ISS and Spike disagree on%s\n    ISS  : %s\n    Spike: %s",
                                              diff, fmt(r), fmt(s)))
            if(spike_errors == SPIKE_MAX_ERRORS)
            begin
                spike_on = 0;
                `uvm_info("SPIKE_CHK", $sformatf("Spike comparison stopped after %0d mismatches", spike_errors), UVM_LOW)
            end
        end
    endfunction

    always @(negedge clk or negedge rst)
    begin
        if(!rst)
        begin
            iss.reset();
            if(use_spike) spike_reset();
            gpr_q.delete(); fpr_q.delete(); st_q.delete(); hist.delete();
            m_new = 0; w_new = 0; check_trap_csrs = 0;
        end
        else
        begin
            // After the program end only writes of instructions the ISS already
            // committed are checked; anything later (e.g. an interrupt taken on
            // the final self-loop) is outside the program.

            // ── Trap CSRs one cycle after a trap ───────────────────────────────
            if(check_trap_csrs)
            begin
                if((MepcE !== iss.mepc) || (McauseE !== iss.mcause) || (MtvalE !== iss.mtval))
                    fail($sformatf("trap CSRs: DUT mepc=%h mcause=%h mtval=%h, ISS mepc=%h mcause=%h mtval=%h",
                                   MepcE, McauseE, MtvalE, iss.mepc, iss.mcause, iss.mtval));
                check_trap_csrs = 0;
            end

            // ── WB: register writes of the instruction that entered MEM/WB ─────
            if(w_new && ValidW)
            begin
                if(RegWriteW && (RdW != zero))
                begin
                    if(gpr_q.size() == 0)
                    begin
                        if(!done) fail($sformatf("DUT writes x%0d=%h but the ISS expected no integer write", RdW, ResultW));
                    end
                    else
                    begin
                        wr_t e;
                        e = gpr_q.pop_front();
                        if((e.rd != int'(RdW)) || (e.val !== ResultW))
                            fail($sformatf("integer write mismatch (pc %h): DUT x%0d=%h ISS x%0d=%h",
                                           e.pc, RdW, ResultW, e.rd, e.val));
                    end
                end
                if(FPURegWriteW)
                begin
                    if(fpr_q.size() == 0)
                    begin
                        if(!done) fail($sformatf("DUT writes f%0d=%h but the ISS expected no FP write", RdFW, FPUOutW));
                    end
                    else
                    begin
                        wr_t e;
                        e = fpr_q.pop_front();
                        if((e.rd != int'(RdFW)) || (e.val[FINAL_FLP_WIDTH-1:0] !== FPUOutW))
                            fail($sformatf("FP write mismatch (pc %h): DUT f%0d=%h ISS f%0d=%h",
                                           e.pc, RdFW, FPUOutW, e.rd, e.val[FINAL_FLP_WIDTH-1:0]));
                    end
                end
            end

            // ── MEM: store of the instruction that entered EX/MEM, or the
            //    completed cache write of an SC / AMO* ─────────────────────────
            if((m_new && ValidM && MemWriteM && !AmoM) || AtomicStoreM)
            begin
                int size;
                logic [XL-1:0] mask, data, pc;
                size = 1 << funct3M[1:0];
                mask = (size == XL/8) ? '1 : ((XL'(1) << (8*size)) - 1);
                data = (AmoM ? AtomicStoreDataM : WriteDataM) & mask;
                pc = PCPlus4M - XL'(4);
                if(st_q.size() == 0)
                begin
                    if(!done) fail($sformatf("DUT stores to %h (pc %h) but the ISS expected no store", ALUOutM, pc));
                end
                else
                begin
                    st_t e;
                    e = st_q.pop_front();
                    if((e.pc !== pc) || (e.addr !== ALUOutM) || (e.size != size) || (e.data !== data))
                        fail($sformatf("store mismatch: DUT pc %h [%h] size %0d data %h, ISS pc %h [%h] size %0d data %h",
                                       pc, ALUOutM, size, data, e.pc, e.addr, e.size, e.data));
                end
            end

            // ── EX: commit point ───────────────────────────────────────────────
            if(ValidE && !StallE && !done)
            begin
                iss_commit_t r;
                logic [XL-1:0] dut_pc, dut_next;
                dut_pc = PCPlus4E - XL'(4);
                r = iss.step(ExternalInterrupt, TimerInterrupt, SoftwareInterrupt, CsrReadE);
                if(spike_on) spike_check(r, ExternalInterrupt, TimerInterrupt, SoftwareInterrupt, CsrReadE);
                commits++;
                hist.push_back(r);
                if(hist.size() > 10) void'(hist.pop_front());

                if(r.pc !== dut_pc)
                    fail($sformatf("PC mismatch: DUT executes %h, ISS executes %h", dut_pc, r.pc));
                else if(r.trap != TrapTakenE)
                    fail($sformatf("trap mismatch at pc %h: DUT trap=%0d ISS trap=%0d (ISS cause %h)",
                                   r.pc, TrapTakenE, r.trap, r.cause));
                else if(r.trap)
                begin
                    traps++;
                    if(r.interrupt) interrupts++;
                    check_trap_csrs = 1;
                    if(CsrOutPC !== r.next_pc)
                        fail($sformatf("trap vector mismatch at pc %h: DUT %h ISS %h", r.pc, CsrOutPC, r.next_pc));
                end
                else
                begin
                    dut_next = TrapIsSet ? CsrOutPC : (PCSrcE ? PCTargetE : PCPlus4E);
                    if(dut_next !== r.next_pc)
                        fail($sformatf("next-PC mismatch at pc %h: DUT %h ISS %h", r.pc, dut_next, r.next_pc));
                end

                if(r.rd_we)  gpr_q.push_back('{r.rd, r.rd_val, r.pc});
                if(r.frd_we) fpr_q.push_back('{r.frd, XL'(r.frd_val), r.pc});
                if(r.st_we)  st_q.push_back('{r.st_addr, r.st_size, r.st_data, r.pc});

                if(tohost_on && !r.trap && r.st_we && (r.st_addr == tohost_addr))
                begin
                    done = 1;
                    tohost_val = r.st_data;
                    `uvm_info("ISS_CHK", $sformatf("tohost = %h written at pc %h: %0d commits, %0d traps",
                                                   r.st_data, r.pc, commits, traps), UVM_LOW)
                    done_ev.trigger();
                end
                else if(!tohost_on && !r.trap && (r.insn == SELF_LOOP))
                begin
                    done = 1;
                    `uvm_info("ISS_CHK", $sformatf("program end reached at pc %h: %0d commits, %0d traps (%0d interrupts)",
                                                   r.pc, commits, traps, interrupts), UVM_LOW)
                    done_ev.trigger();
                end
            end
            m_new = !StallM;
            w_new = !StallW;
        end
    end

endmodule
