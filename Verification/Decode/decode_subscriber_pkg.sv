package decode_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import decode_item_pkg::*;

    class decode_subscriber extends uvm_subscriber #(decode_item);

        //Register the class to the factory
        `uvm_component_utils(decode_subscriber)


        decode_item sub_item;

        covergroup cvr_grp();
            ProgramCounter: coverpoint sub_item.PCPlus4D iff(!sub_item.rst);
            Instruction: coverpoint sub_item.InstructionD iff(!sub_item.rst);
            RdW: coverpoint sub_item.RdW iff(!sub_item.rst);
            ResultW: coverpoint sub_item.ResultW iff(!sub_item.rst);
            Rs1E: coverpoint sub_item.Rs1E iff(!sub_item.rst);
            Rs2E: coverpoint sub_item.Rs2E iff(!sub_item.rst);
            Rs1D: coverpoint sub_item.Rs1D iff(!sub_item.rst);
            Rs2D: coverpoint sub_item.Rs2D iff(!sub_item.rst);
            RdE: coverpoint sub_item.RdE iff(!sub_item.rst);
            ALUControlE: coverpoint sub_item.ALUControlE iff(!sub_item.rst);
            RD1E: coverpoint sub_item.RD1E iff(!sub_item.rst);
            RD2E: coverpoint sub_item.RD2E iff(!sub_item.rst);
            SignImmE: coverpoint sub_item.SignImmE iff(!sub_item.rst);
            PCBranchE: coverpoint sub_item.PCBranchE iff(!sub_item.rst);
            funct3E: coverpoint sub_item.funct3E iff(!sub_item.rst);
            RegWriteE: coverpoint sub_item.RegWriteE iff(!sub_item.rst);
            SelectorE: coverpoint sub_item.SelectorE iff(!sub_item.rst);
            MemWriteE: coverpoint sub_item.MemWriteE iff(!sub_item.rst);
            BranchE: coverpoint sub_item.BranchE iff(!sub_item.rst);
            ALUSrcE: coverpoint sub_item.ALUSrcE iff(!sub_item.rst);
            JumpE: coverpoint sub_item.JumpE iff(!sub_item.rst);
            PCPlus4E: coverpoint sub_item.PCPlus4E iff(!sub_item.rst);
            CsrAccessE: coverpoint sub_item.CsrAccessE iff(!sub_item.rst);
            CsrIndexE: coverpoint sub_item.CsrIndexE iff(!sub_item.rst);
            CsrOperationE: coverpoint sub_item.CsrOperationE iff(!sub_item.rst);
            EcallE: coverpoint sub_item.EcallE iff(!sub_item.rst);
            EbreakE: coverpoint sub_item.EbreakE iff(!sub_item.rst);
            MRetE: coverpoint sub_item.MRetE iff(!sub_item.rst);
            IllegaleInstructionE: coverpoint sub_item.IllegaleInstructionE iff(!sub_item.rst);
            RdFE: coverpoint sub_item.RdFE iff(!sub_item.rst);
            RD1FE: coverpoint sub_item.RD1FE iff(!sub_item.rst);
            RD2FE: coverpoint sub_item.RD2FE iff(!sub_item.rst);
            FPUControlE: coverpoint sub_item.FPUControlE iff(!sub_item.rst);
            RoundModeE: coverpoint sub_item.RoundModeE iff(!sub_item.rst);
            FPURegWriteE: coverpoint sub_item.FPURegWriteE iff(!sub_item.rst);
            MoveOperationE: coverpoint sub_item.MoveOperationE iff(!sub_item.rst);
            Rs1FE: coverpoint sub_item.Rs1FE iff(!sub_item.rst);
            Rs2FE: coverpoint sub_item.Rs2FE iff(!sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "decode_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:decode_subscriber

endpackage: decode_subscriber_pkg
