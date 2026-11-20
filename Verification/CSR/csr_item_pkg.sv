// =============================================================================
// csr_item_pkg.sv
// -----------------------------------------------------------------------------
// CSR sequence item package for UVM verification.
//
// Stimulus covers every implemented CSR, a few unknown addresses (illegal),
// all six CSR operations, synchronous exceptions, MRET, WFI and the interrupt
// lines, with Commit (the EX instruction advances) mostly high. MTime is a
// new random 64-bit value every cycle. MRET with the reset MPP (U) enters
// U-mode; any trap returns to M, so both modes are exercised.
// =============================================================================
package csr_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class csr_item extends uvm_sequence_item;

        `uvm_object_utils(csr_item)

        function new (string name = "csr_item");
            super.new(name);
        endfunction: new

        rand logic                        rst;
        rand csr_t                         CsrOperation;
        rand gpr_t                         Rs;
        rand traps_t                       Traps;
        rand logic                         mret;
        rand logic [FINAL_DATA_WIDTH-1:0]  PC;
        rand logic [FINAL_DATA_WIDTH-1:0]  Address;
        rand logic                         CsrAccess;
        rand logic [FINAL_DATA_WIDTH-1:0]  CsrIn;
        rand logic                         Commit;
        rand logic                         Wfi;
        rand logic [63:0]                  MTime;
        rand logic                         TimerInterrupt;
        rand logic                         ExternalInterrupt;
        rand logic                         SoftwareInterrupt;
        rand csr_index_t                   CsrIndex;
        logic [FINAL_DATA_WIDTH-1:0]       CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0]       CsrOut;
        logic                              TrapIsSet;
        logic                              TrapTaken;
        round_mode_t                       RoundingMode;
        priv_mode_t                        PrivMode;
        logic                              WfiStall;

        bit chk_csrout = 1;     // CsrOut is predictable (not a cycle-counter read)

        constraint LowResetProb { rst dist {0:=5,1:=400}; }
        constraint CommitProb   { Commit dist {0:=15,1:=85}; }
        constraint ValidCsrOperation
        {
            if(CsrAccess)
                CsrOperation inside {csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci};
        }
        // One instruction is either a CSR access, an MRET, a WFI or a trapping one
        constraint DirectedTraffic
        {
            Traps dist {NoTraps := 80, [InstructionAddressMisalignedOrUserSoftwareInterrupt:EcallMOrMachineExternalInterrupt] :/ 20};
            $countones(Traps) <= 1;
            if(Traps != NoTraps)
            {
                CsrAccess == 1'b0;
                mret == 1'b0;
                Wfi == 1'b0;
            }
            if(mret)
                CsrAccess == 1'b0;
            if(Wfi)
            {
                CsrAccess == 1'b0;
                mret == 1'b0;
            }
            mret dist {0:=92, 1:=8};
            Wfi dist {0:=95, 1:=5};
            CsrAccess dist {0:=40, 1:=60};
        }
        constraint CsrSelection
        {
            CsrIndex dist {
                [fflags:fcsr] :/ 6, mstatus := 8, misa := 2, medeleg := 1, mideleg := 1, mie := 6, mtvec := 6,
                mscratch := 6, mepc := 6, mcause := 6, mtval := 6, mip := 3, mstatush := 1, mcycle := 2,
                minstret := 4, mcycleh := 1, minstreth := 3, cycle := 2, instret := 3, cycleh := 1, instreth := 1,
                mcounteren := 6, menvcfg := 1, menvcfgh := 1, time_csr := 3, timeh_csr := 2,
                mvendorid := 1, marchid := 1, mimpid := 1, mhartid := 1
            };
        }
        // A rand enum only takes its named values, so CSR numbers csr_index_t
        // does not name (mhpm*, mcountinhibit, unknown, S/H-level) are drawn
        // as raw numbers and cast in post_randomize.
        rand bit          raw_csr;
        rand logic [11:0] raw_index;
        constraint RawCsr
        {
            raw_csr dist {0:=88, 1:=12};
            raw_index inside {12'hB03, 12'hB1F, 12'h323, 12'h320, 12'h7C0, 12'h180, 12'h100, 12'h200};
        }
        function void post_randomize();
            if(raw_csr) CsrIndex = csr_index_t'(raw_index);
        endfunction
        constraint InterruptDistribution
        {
            TimerInterrupt dist {0:=8,1:=1};
            ExternalInterrupt dist {0:=8,1:=1};
            SoftwareInterrupt dist {0:=8,1:=1};
        }
        constraint Alignment { PC[1:0] == 2'b00; }

        virtual function string convert2str();
            return $sformatf("\tInputs: rst = %0d | Commit = %0d | CsrOp = %s | Rs = %s | Traps = %s | mret = %0d | PC = %0h | Addr = %0h | CsrAccess = %0d | CsrIn = %0h | Wfi = %0d | MTime = %0h | TI = %0d | EI = %0d | SI = %0d | CsrIdx = %s
            Outputs: CsrOutPC = %0h | CsrOut = %0h | TrapIsSet = %0d | TrapTaken = %0d | RoundingMode = %s | PrivMode = %s | WfiStall = %0d",
            rst,Commit,CsrOperation.name(),Rs.name(),Traps.name(),mret,PC,Address,CsrAccess,CsrIn,Wfi,MTime,TimerInterrupt,ExternalInterrupt,SoftwareInterrupt,CsrIndex.name(),
            CsrOutPC,CsrOut,TrapIsSet,TrapTaken,RoundingMode.name(),PrivMode.name(),WfiStall);
        endfunction: convert2str

        function bit chk(string name, logic [63:0] act, logic [63:0] exp);
            if(act !== exp)
            begin
                `uvm_info({name, " Mismatch"}, $sformatf("Expected: %0h Actual: %0h", exp, act), UVM_LOW)
                return 1'b0;
            end
            return 1'b1;
        endfunction:chk

        // this = actual, rhs = expected
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            csr_item e;
            bit ok;
            if(!$cast(e, rhs))
            begin
                `uvm_fatal(get_type_name(), "rhs is not a csr_item")
                return 1'b0;
            end
            ok = super.do_compare(rhs, comparer);
            ok &= chk("TrapIsSet", TrapIsSet, e.TrapIsSet) & chk("TrapTaken", TrapTaken, e.TrapTaken);
            ok &= chk("RoundingMode", RoundingMode, e.RoundingMode);
            ok &= chk("PrivMode", PrivMode, e.PrivMode) & chk("WfiStall", WfiStall, e.WfiStall);
            if(e.TrapIsSet) ok &= chk("CsrOutPC", CsrOutPC, e.CsrOutPC);
            if(e.chk_csrout) ok &= chk("CsrOut", CsrOut, e.CsrOut);
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            csr_item o;
            if(!$cast(o, rhs))
            begin
                `uvm_fatal(get_type_name(), "rhs is not a csr_item")
                return;
            end
            super.do_copy(rhs);
            copy_inputs(rhs);
            this.CsrOutPC = o.CsrOutPC;
            this.CsrOut = o.CsrOut;
            this.TrapIsSet = o.TrapIsSet;
            this.TrapTaken = o.TrapTaken;
            this.RoundingMode = o.RoundingMode;
            this.PrivMode = o.PrivMode;
            this.WfiStall = o.WfiStall;
            this.chk_csrout = o.chk_csrout;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            csr_item o;
            if(!$cast(o, rhs))
            begin
                `uvm_fatal(get_type_name(), "rhs is not a csr_item")
                return;
            end
            this.rst = o.rst;
            this.CsrOperation = o.CsrOperation;
            this.Rs = o.Rs;
            this.Traps = o.Traps;
            this.mret = o.mret;
            this.PC = o.PC;
            this.Address = o.Address;
            this.CsrAccess = o.CsrAccess;
            this.CsrIn = o.CsrIn;
            this.Commit = o.Commit;
            this.Wfi = o.Wfi;
            this.MTime = o.MTime;
            this.TimerInterrupt = o.TimerInterrupt;
            this.ExternalInterrupt = o.ExternalInterrupt;
            this.SoftwareInterrupt = o.SoftwareInterrupt;
            this.CsrIndex = o.CsrIndex;
        endfunction:copy_inputs

    endclass: csr_item

endpackage:csr_item_pkg
