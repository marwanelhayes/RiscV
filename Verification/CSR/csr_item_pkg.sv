// =============================================================================
// csr_item_pkg.sv
// -----------------------------------------------------------------------------
// CSR sequence item package for UVM verification.
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
        rand csr_t                        CsrOperation;
        rand gpr_t                        Rs;
        rand traps_t                      Traps;
        rand logic                        mret;
        rand logic [FINAL_ADDR_WIDTH-1:0] PC;
        rand logic [FINAL_ADDR_WIDTH-1:0] Address;
        rand logic                        CsrAccess;
        rand logic [FINAL_DATA_WIDTH-1:0] CsrIn;
        rand logic                        TimerInterrupt;
        rand logic                        ExternalInterrupt;
        rand logic                        SoftwareInterrupt;
        rand csr_index_t                  CsrIndex;

        logic [FINAL_ADDR_WIDTH-1:0]      CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0]      CsrOut;
        logic                             TrapIsSet;
        round_mode_t                      RoundingMode;

        constraint LowResetProb
        {
            rst dist {0:=5,1:=400};
        }

        constraint ValidCsrOperation
        {
            if(CsrAccess)
                CsrOperation inside {csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci};
        }

        constraint DirectedTraffic
        {
            if(Traps != NoTraps)
            {
                CsrAccess == 1'b0;
                mret == 1'b0;
            }
            if(mret)
                CsrAccess == 1'b0;
        }

        constraint WritableCsrSelection
        {
            if(CsrAccess)
                !(CsrIndex inside {misa,mvendorid,mip});
        }

        constraint InterruptDistribution
        {
            TimerInterrupt dist {0:=8,1:=1};
            ExternalInterrupt dist {0:=8,1:=1};
            SoftwareInterrupt dist {0:=8,1:=1};
        }

        constraint FrmSelection
        {
            if(CsrAccess && (CsrIndex == frm || CsrIndex == fcsr))
                CsrIn[2:0] inside {0,1,2,3,4,7};
        }

        virtual function string convert2str();
            return $sformatf("\tInputs: rst = %0d | CsrOp = %s | Rs = %s | Traps = %s | mret = %0d | PC = %0h | Addr = %0h |CsrAccess = %0d | CsrIn = %0h | TI = %0d | EI = %0d | SI = %0d | CsrIdx = %s 
            Outputs: CsrOutPC = %0h | CsrOut = %0h | TrapIsSet = %0d | RoundingMode = %s",
            rst,CsrOperation.name(),Rs.name(),Traps.name(),mret,PC,Address,CsrAccess,CsrIn,TimerInterrupt,ExternalInterrupt,SoftwareInterrupt,CsrIndex.name(),
            CsrOutPC,CsrOut,TrapIsSet,RoundingMode.name());
        endfunction: convert2str

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            csr_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a csr_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.CsrOutPC     === other.CsrOutPC)
                && (this.CsrOut       === other.CsrOut)
                && (this.TrapIsSet    === other.TrapIsSet)
                && (this.RoundingMode === other.RoundingMode);
            
            if(this.CsrOutPC !== other.CsrOutPC)
                `uvm_info("CsrOutPC Mismatch", $sformatf("Expected: %0h Actual: %0h", this.CsrOutPC, other.CsrOutPC), UVM_LOW)
            if(this.CsrOut !== other.CsrOut)
                `uvm_info("CsrOut Mismatch", $sformatf("Expected: %0h Actual: %0h", this.CsrOut, other.CsrOut), UVM_LOW)
            if(this.TrapIsSet !== other.TrapIsSet)
                `uvm_info("TrapIsSet Mismatch", $sformatf("Expected: %0d Actual: %0d", this.TrapIsSet, other.TrapIsSet), UVM_LOW)
            if(this.RoundingMode !== other.RoundingMode)
                `uvm_info("RoundingMode Mismatch", $sformatf("Expected: %s Actual: %s", this.RoundingMode.name(), other.RoundingMode.name()), UVM_LOW)
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            csr_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not a csr_item")
                return;
            end
            super.do_copy(rhs);
            this.rst               = other.rst;
            this.CsrOperation      = other.CsrOperation;
            this.Rs                = other.Rs;
            this.Traps             = other.Traps;
            this.mret              = other.mret;
            this.PC                = other.PC;
            this.Address           = other.Address;
            this.CsrAccess         = other.CsrAccess;
            this.CsrIn             = other.CsrIn;
            this.TimerInterrupt    = other.TimerInterrupt;
            this.ExternalInterrupt = other.ExternalInterrupt;
            this.SoftwareInterrupt = other.SoftwareInterrupt;
            this.CsrIndex          = other.CsrIndex;

            this.CsrOutPC          = other.CsrOutPC;
            this.CsrOut            = other.CsrOut;
            this.TrapIsSet         = other.TrapIsSet;
            this.RoundingMode      = other.RoundingMode;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            csr_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not a csr_item")
                return;
            end
            this.rst               = other.rst;
            this.CsrOperation      = other.CsrOperation;
            this.Rs                = other.Rs;
            this.Traps             = other.Traps;
            this.mret              = other.mret;
            this.PC                = other.PC;
            this.Address           = other.Address;
            this.CsrAccess         = other.CsrAccess;
            this.CsrIn             = other.CsrIn;
            this.TimerInterrupt    = other.TimerInterrupt;
            this.ExternalInterrupt = other.ExternalInterrupt;
            this.SoftwareInterrupt = other.SoftwareInterrupt;
            this.CsrIndex          = other.CsrIndex;
        endfunction:copy_inputs
    endclass: csr_item
endpackage:csr_item_pkg
