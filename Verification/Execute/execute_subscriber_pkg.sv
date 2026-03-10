package execute_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import execute_item_pkg::*;

    class execute_subscriber extends uvm_subscriber #(execute_item);

        //Register the class to the factory
        `uvm_component_param_utils(execute_subscriber)


        execute_item sub_item;

        covergroup cvr_grp();
            ALUOutM: coverpoint sub_item.ALUOutM iff(!sub_item.rst);
            WriteDataM: coverpoint sub_item.WriteDataM iff(!sub_item.rst);
            ALUControlE: coverpoint sub_item.ALUControlE iff(!sub_item.rst);
            Rs1E: coverpoint sub_item.Rs1E iff(!sub_item.rst);
            RdM: coverpoint sub_item.RdM iff(!sub_item.rst);
            funct3E: coverpoint sub_item.funct3E iff(!sub_item.rst);
            RegWriteM: coverpoint sub_item.RegWriteM iff(!sub_item.rst);
            MemWriteM: coverpoint sub_item.MemWriteM iff(!sub_item.rst);
            BranchE: coverpoint sub_item.BranchE iff(!sub_item.rst);
            PCSrcE: coverpoint sub_item.PCSrcE iff(!sub_item.rst);
            ForwardAE: coverpoint sub_item.ForwardAE iff(!sub_item.rst);
            ForwardBE: coverpoint sub_item.ForwardBE iff(!sub_item.rst);
            RD1E: coverpoint sub_item.RD1E iff(!sub_item.rst);
            RD2E: coverpoint sub_item.RD2E iff(!sub_item.rst);
            MRetE: coverpoint sub_item.MRetE iff(!sub_item.rst);
            EcallE: coverpoint sub_item.EcallE iff(!sub_item.rst);
            EbreakE: coverpoint sub_item.EbreakE iff(!sub_item.rst);
            IllegaleInstructionE: coverpoint sub_item.IllegaleInstructionE iff(!sub_item.rst);
            TimerInterrupt: coverpoint sub_item.TimerInterrupt iff(!sub_item.rst);
            SoftwareInterrupt: coverpoint sub_item.SoftwareInterrupt iff(!sub_item.rst);
            ExternalInterrupt: coverpoint sub_item.ExternalInterrupt iff(!sub_item.rst);
            ResultW: coverpoint sub_item.ResultW iff(!sub_item.rst);
            SignImmE: coverpoint sub_item.SignImmE iff(!sub_item.rst);
            RegWriteE: coverpoint sub_item.RegWriteE iff(!sub_item.rst);
            ALUSrcE: coverpoint sub_item.ALUSrcE iff(!sub_item.rst);
            MemWriteE: coverpoint sub_item.MemWriteE iff(!sub_item.rst);
            PCPlus4E: coverpoint sub_item.PCPlus4E iff(!sub_item.rst);
            JumpE: coverpoint sub_item.JumpE iff(!sub_item.rst);
            CsrOutM: coverpoint sub_item.CsrOutM iff(!sub_item.rst);
            PCPlus4M: coverpoint sub_item.PCPlus4M iff(!sub_item.rst);
            SelectorM: coverpoint sub_item.SelectorM iff(!sub_item.rst);
            CsrAccessE: coverpoint sub_item.CsrAccessE iff(!sub_item.rst);
            CsrOperationE: coverpoint sub_item.CsrOperationE iff(!sub_item.rst);
            CsrIndexE: coverpoint sub_item.CsrIndexE iff(!sub_item.rst);
            SelectorE: coverpoint sub_item.SelectorE iff(!sub_item.rst);
            TrapIsSet: coverpoint sub_item.TrapIsSet iff(!sub_item.rst);
            CsrOutPC: coverpoint sub_item.CsrOutPC iff(!sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "execute_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:execute_subscriber

endpackage: execute_subscriber_pkg
