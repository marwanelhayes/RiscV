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
//   - MEM store (a new store in EX/MEM): address, size and data must match the
//     oldest store the ISS performed.
//   - WB write (a new instruction in MEM/WB): rd/value and frd/value must match
//     the oldest register write the ISS performed.
//
// The program ends at a self-loop (JAL x0, 0); the checker then triggers the
// global "ISS_DONE" uvm_event. risc_test drains the pipeline and triggers
// "ISS_FINAL", on which the checker verifies that every expected write was
// seen (still inside the UVM run phase, so the errors are counted).
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;
import riscv_iss_pkg::*;

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

    riscv_iss    iss;
    wr_t         gpr_q[$], fpr_q[$];
    st_t         st_q[$];
    iss_commit_t hist[$];                 // last commits, for error context
    bit          m_new, w_new;            // EX/MEM, MEM/WB loaded at the last edge
    bit          check_trap_csrs;         // a trap was taken at the last edge
    bit          done;
    int unsigned commits, traps, interrupts, errors;
    uvm_event    done_ev, final_ev;

    initial
    begin
        iss = new();
        iss.load_image(INSTR_MEM_PATH);
        done_ev  = uvm_event_pool::get_global("ISS_DONE");
        final_ev = uvm_event_pool::get_global("ISS_FINAL");
        final_ev.wait_trigger();
        if(gpr_q.size() || st_q.size() || fpr_q.size())
            `uvm_error("ISS_CHK", $sformatf("expected writes never seen: %0d integer, %0d FP, %0d stores",
                                            gpr_q.size(), fpr_q.size(), st_q.size()))
        if(commits == 0)
            `uvm_error("ISS_CHK", "no instruction was committed")
        if(!done)
            `uvm_error("ISS_CHK", "the program never reached its end (self-loop)")
        `uvm_info("ISS_CHK", $sformatf("summary: %0d commits, %0d traps, %0d interrupts, %0d mismatches",
                                       commits, traps, interrupts, errors), UVM_LOW)
    end

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

    always @(negedge clk or negedge rst)
    begin
        if(!rst)
        begin
            iss.reset();
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

            // ── MEM: store of the instruction that entered EX/MEM ──────────────
            if(m_new && ValidM && MemWriteM)
            begin
                int size;
                logic [XL-1:0] mask;
                size = 1 << funct3M[1:0];
                mask = (size == XL/8) ? '1 : ((XL'(1) << (8*size)) - 1);
                if(st_q.size() == 0)
                begin
                    if(!done) fail($sformatf("DUT stores to %h but the ISS expected no store", ALUOutM));
                end
                else
                begin
                    st_t e;
                    e = st_q.pop_front();
                    if((e.addr !== ALUOutM) || (e.size != size) || (e.data !== (WriteDataM & mask)))
                        fail($sformatf("store mismatch (pc %h): DUT [%h] size %0d data %h, ISS [%h] size %0d data %h",
                                       e.pc, ALUOutM, size, WriteDataM & mask, e.addr, e.size, e.data));
                end
            end

            // ── EX: commit point ───────────────────────────────────────────────
            if(ValidE && !StallE && !done)
            begin
                iss_commit_t r;
                logic [XL-1:0] dut_pc, dut_next;
                dut_pc = PCPlus4E - XL'(4);
                r = iss.step(ExternalInterrupt, TimerInterrupt, SoftwareInterrupt, CsrReadE);
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

                if(!r.trap && (r.insn == SELF_LOOP))
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
