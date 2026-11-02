// =============================================================================
// flp_item_pkg.sv
// -----------------------------------------------------------------------------
// FPU sequence item package for UVM verification.
// Adds do_compare / do_copy to support the fetch-style in-order FIFO
// scoreboard (cloned-actual vs cloned-expected comparison). Results are
// compared bit-exactly: IEEE 754 / RISC-V F results are correctly rounded,
// so any tolerance would hide real rounding errors.
// =============================================================================
package flp_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class flp_item extends uvm_sequence_item;

        `uvm_object_utils(flp_item)

        function new (string name = "flp_item");
            super.new(name);
        endfunction: new

        rand logic                            rst;
        rand logic                            valid;
        rand logic [FINAL_FLP_WIDTH-1:0]      InA;
        rand logic [FINAL_FLP_WIDTH-1:0]      InB;
        rand round_mode_t                     round_mode;
        rand fpu_operation_t                  operation;
        rand fpr_t                            RdF;
        rand logic                            RegWrite;
        rand move_operation_t                 MoveOperation;

        logic                                 busy;
        logic                                 done;
        logic                                 Overflow;
        logic                                 Underflow;
        logic                                 NaN;
        logic                                 Inf;
        logic                                 Zero;
        logic                                 InvalidDiv;
        logic [FINAL_FLP_WIDTH-1:0]           Result;
        fpr_t                                 RdFOut;
        logic                                 RegWriteOut;
        move_operation_t                      MoveOperationOut;


        constraint LowResetProb { rst   dist {0:=5,1:=1000}; }
        constraint ValidInputs  { valid dist {0:=5,1:=1000}; }

        virtual function string convert2str();
            return $sformatf("Inputs: rst = %0d | valid = %0d | InA = %f/%0h | InB = %f/%0h | round = %s | op = %s | RdF = %s | RegW = %0d | Mv = %s
            Outputs: busy = %0d | done = %0d | Overflow = %0d | Underflow = %0d | NaN = %0d | Inf = %0d | Zero = %0d | InvalidDiv = %0d | Result = %f/%0h | RdFOut = %s | RegWriteOut = %0d | MoveOperationOut = %s",
            rst,valid,$bitstoshortreal(InA),InA,$bitstoshortreal(InB),InB,
            round_mode.name(),operation.name(),RdF.name(),RegWrite,MoveOperation.name(),
            busy,done,Overflow,Underflow,NaN,Inf,Zero,InvalidDiv,$bitstoshortreal(Result),Result,RdFOut.name(),RegWriteOut,MoveOperationOut.name());
        endfunction: convert2str

        virtual function string getbusystatus();
            return $sformatf("busy=%0d done=%0d", busy, done);
        endfunction: getbusystatus

        virtual function string getoutputs();
            return $sformatf("Overflow=%0d Underflow=%0d NaN=%0d Inf=%0d Zero=%0d InvalidDiv=%0d Result=%0h RdFOut=%s RegWriteOut=%0d MoveOperationOut=%s",
                Overflow, Underflow, NaN, Inf, Zero, InvalidDiv, Result, RdFOut.name(), RegWriteOut, MoveOperationOut.name());
        endfunction: getoutputs

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            flp_item other;
            bit ok;
            bit super_ok;
            bit result_err;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a flp_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            // RISC-V F requires correctly rounded results: bit-exact compare.
            result_err = (this.Result !== other.Result);
            ok = super_ok
                && !result_err
                && (this.Overflow         === other.Overflow)
                && (this.Underflow        === other.Underflow)
                && (this.NaN              === other.NaN)
                && (this.Inf              === other.Inf)
                && (this.Zero             === other.Zero)
                && (this.InvalidDiv       === other.InvalidDiv)
                && (this.RdFOut           === other.RdFOut)
                && (this.RegWriteOut      === other.RegWriteOut)
                && (this.MoveOperationOut === other.MoveOperationOut);
            if(result_err)
                `uvm_info("Result Mismatch",$sformatf("Epected : %0f/%0h Actual : %0f/%0h",$bitstoshortreal(other.Result),other.Result,$bitstoshortreal(this.Result),this.Result), UVM_LOW)
            if(this.Overflow !== other.Overflow)
                `uvm_info("Overflow Mismatch",$sformatf("Expected: %0d Actual: %0d", other.Overflow, this.Overflow), UVM_LOW)
            if(this.Underflow !== other.Underflow)
                `uvm_info("Underflow Mismatch",$sformatf("Expected: %0d Actual: %0d", other.Underflow, this.Underflow), UVM_LOW)
            if(this.NaN !== other.NaN)
                `uvm_info("NaN Mismatch",$sformatf("Expected: %0d Actual: %0d", other.NaN, this.NaN), UVM_LOW)
            if(this.Inf !== other.Inf)
                `uvm_info("Inf Mismatch",$sformatf("Expected: %0d Actual: %0d", other.Inf, this.Inf), UVM_LOW)
            if(this.Zero !== other.Zero)
                `uvm_info("Zero Mismatch",$sformatf("Expected: %0d Actual: %0d", other.Zero, this.Zero), UVM_LOW)
            if(this.InvalidDiv !== other.InvalidDiv)
                `uvm_info("InvalidDiv Mismatch",$sformatf("Expected: %0d Actual: %0d", other.InvalidDiv, this.InvalidDiv), UVM_LOW)
            if(this.RdFOut !== other.RdFOut)
                `uvm_info("RdFOut Mismatch",$sformatf("Expected: %s Actual: %s", other.RdFOut.name(), this.RdFOut.name()), UVM_LOW)
            if(this.RegWriteOut !== other.RegWriteOut)
                `uvm_info("RegWriteOut Mismatch",$sformatf("Expected: %0b Actual: %0b", other.RegWriteOut, this.RegWriteOut), UVM_LOW)
            if(this.MoveOperationOut !== other.MoveOperationOut)
                `uvm_info("MoveOperationOut Mismatch",$sformatf("Expected: %s Actual: %s", other.MoveOperationOut.name(), this.MoveOperationOut.name()), UVM_LOW)
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            flp_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not a flp_item")
                return;
            end
            super.do_copy(rhs);
            this.rst = other.rst;
            this.valid = other.valid;
            this.InA = other.InA;
            this.InB = other.InB;
            this.round_mode = other.round_mode;
            this.operation = other.operation;
            this.RdF = other.RdF;
            this.RegWrite = other.RegWrite;
            this.MoveOperation = other.MoveOperation;

            this.busy = other.busy;
            this.done = other.done;
            this.Overflow = other.Overflow;
            this.Underflow = other.Underflow;
            this.NaN = other.NaN;
            this.Inf = other.Inf;
            this.Zero = other.Zero;
            this.InvalidDiv = other.InvalidDiv;
            this.Result = other.Result;
            this.RdFOut = other.RdFOut;
            this.RegWriteOut = other.RegWriteOut;
            this.MoveOperationOut = other.MoveOperationOut;
        endfunction:do_copy

        virtual function void copy_outputs (uvm_object rhs);
            flp_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_outputs","rhs is not a flp_item")
                return;
            end
            this.busy = other.busy;
            this.done = other.done;
            this.Overflow = other.Overflow;
            this.Underflow = other.Underflow;
            this.NaN = other.NaN;
            this.Inf = other.Inf;
            this.Zero = other.Zero;
            this.InvalidDiv = other.InvalidDiv;
            this.Result = other.Result;
            this.RdFOut = other.RdFOut;
            this.RegWriteOut = other.RegWriteOut;
            this.MoveOperationOut = other.MoveOperationOut;
        endfunction:copy_outputs

        virtual function void copy_inputs (uvm_object rhs);
            flp_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not a flp_item")
                return;
            end
            this.rst = other.rst;
            this.valid = other.valid;
            this.InA = other.InA;
            this.InB = other.InB;
            this.round_mode = other.round_mode;
            this.operation = other.operation;
            this.RdF = other.RdF;
            this.RegWrite = other.RegWrite;
            this.MoveOperation = other.MoveOperation;
        endfunction:copy_inputs

    endclass: flp_item
endpackage:flp_item_pkg
