package csr_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class csr_item extends uvm_sequence_item;
        
        `uvm_object_utils(csr_item)

        function new (string name = "csr_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand csr_t CsrOperation;
        rand gpr_t Rs;
        rand traps_t Traps;
        rand logic mret;
        rand logic [FINAL_ADDR_WIDTH-1:0] PC;
        rand logic [FINAL_ADDR_WIDTH-1:0] Address;
        rand logic CsrAccess;
        rand logic [FINAL_DATA_WIDTH-1:0] CsrIn;
        rand logic TimerInterrupt;
        rand logic ExternalInterrupt;
        rand logic SoftwareInterrupt;
        rand csr_index_t CsrIndex;

        logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0] CsrOut;
        logic TrapIsSet;
        round_mode_t RoundingMode;

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
            return $sformatf("The inputs of the transaction are rst = %0d , CsrOperation = %s , Rs = %s , Traps = %s , mret = %0d , PC = %0h , Address = %0h , CsrAccess = %0d , CsrIn = %0h , TimerInterrupt = %0d , ExternalInterrupt = %0d , SoftwareInterrupt = %0d , CsrIndex = %s",rst,CsrOperation.name(),Rs.name(),Traps.name(),mret,PC,Address,CsrAccess,CsrIn,TimerInterrupt,ExternalInterrupt,SoftwareInterrupt,CsrIndex.name());
        endfunction: convert2str

    endclass: csr_item

endpackage:csr_item_pkg
