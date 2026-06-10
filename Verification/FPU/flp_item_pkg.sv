// =============================================================================
// flp_item_pkg.sv
// -----------------------------------------------------------------------------
// FPU sequence item package for UVM verification.
// Adds do_compare / do_copy to support the fetch-style in-order FIFO
// scoreboard (cloned-actual vs cloned-expected comparison).
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

        virtual function bit compare_ints_5_percent(int a, int b);
            int diff, max_val, abs_a, abs_b;
            bit err;
            err     = 1'b0;
            abs_a   = (a < 0) ? -a : a;
            abs_b   = (b < 0) ? -b : b;
            diff    = (a > b) ? (a - b) : (b - a);
            if(diff == 0) return err;
            max_val = (abs_a > abs_b) ? abs_a : abs_b;
            if(!((diff * 100) <= (max_val * 5))) err = 1'b1;
            return err;
        endfunction:compare_ints_5_percent

        virtual function bit compare_shortreal_rel_error(shortreal a, shortreal b, shortreal tol);
            shortreal diff, denom, rel_err, epsilon;
            logic     is_zero_a, is_zero_b, is_inf_a, is_inf_b, is_nan_a, is_nan_b;
            logic [FINAL_DATA_WIDTH-1:0] a_bits, b_bits;
            bit err;
            a_bits    = $shortrealtobits(a);
            b_bits    = $shortrealtobits(b);
            is_zero_a = (a_bits[FINAL_DATA_WIDTH-2:0] == 0);
            is_zero_b = (b_bits[FINAL_DATA_WIDTH-2:0] == 0);
            is_inf_a  = (a_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (a_bits[FINAL_FLP_FRAC_BITS-1:0] == 0);
            is_inf_b  = (b_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (b_bits[FINAL_FLP_FRAC_BITS-1:0] == 0);
            is_nan_a  = (a_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (a_bits[FINAL_FLP_FRAC_BITS-1:0] != 0);
            is_nan_b  = (b_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (b_bits[FINAL_FLP_FRAC_BITS-1:0] != 0);
            diff      = (a - b);
            diff      = (diff < 0.0) ? -diff : diff;
            denom     = (b < 0.0) ? -b : b;
            epsilon   = 1e-3;
            err       = 1'b0;
            if(is_nan_a || is_nan_b || is_inf_a || is_inf_b || is_zero_a || is_zero_b)
            begin
                if(a_bits !== b_bits) err = 1'b1;
                return err;
            end
            else if(denom <= epsilon) rel_err = diff;
            else                      rel_err = diff / denom;
            if(rel_err > tol) err = 1'b1;
            return err;
        endfunction:compare_shortreal_rel_error

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
            if((this.operation == FCVT_W_S) || (this.operation == FCVT_WU_S))
                result_err = compare_ints_5_percent(this.Result, other.Result);
            else
                result_err = compare_shortreal_rel_error($bitstoshortreal(this.Result),
                                                         $bitstoshortreal(other.Result), 5e-2);
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
