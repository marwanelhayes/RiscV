package flp_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import flp_item_pkg::*;

    class flp_scoreboard extends uvm_scoreboard;

        logic Overflow;
        logic Underflow;
        logic NaN;
        logic Inf;
        logic Zero;
        logic InvalidDiv;
        logic [FINAL_FLP_WIDTH-1:0] Result;
        fpr_t RdFOut;
        logic RegWriteOut;
        move_operation_t MoveOperationOut;

        logic [FINAL_FLP_WIDTH-1:0] InA;
        logic [FINAL_FLP_WIDTH-1:0] InB;
        shortreal InA_real;
        shortreal InB_real;
        shortreal Result_real;
        int success, fail;
        int error;

        `uvm_component_utils(flp_scoreboard)

        function new (string name = "flp_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_item sc_item;
        uvm_analysis_imp #(flp_item , flp_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function automatic logic [3:0] classify_value(
            input logic [FINAL_FLP_EXP_BITS-1:0] exp,
            input logic [FINAL_FLP_FRAC_BITS-1:0] frac
        );
            logic [3:0] classification;
            classification[0] = (exp == 0) && (frac == 0);
            classification[1] = (exp == {FINAL_FLP_EXP_BITS{1'b1}}) && (frac == 0);
            classification[2] = (exp == {FINAL_FLP_EXP_BITS{1'b1}}) && (frac != 0);
            classification[3] = (exp == 0) && (frac != 0);
            return classification;
        endfunction: classify_value

        function automatic int fcvt_float_to_int(
            input real val,
            input round_mode_t mode,
            input logic is_unsigned
        );
            real floor_val;
            real diff;
            int rounded;
            logic is_nan;

            is_nan = (val != val);
            floor_val = $floor(val);
            diff = val - floor_val;

            if (is_nan)
            begin
                rounded = 0;
            end
            else
            begin
                case (mode)
                    RNE:
                    begin
                        if (diff < 0.5)
                            rounded = int'(floor_val);
                        else if (diff > 0.5)
                            rounded = int'(floor_val + 1.0);
                        else
                        begin
                            rounded = int'(floor_val);
                            if (rounded % 2 != 0)
                                rounded += 1;
                        end
                    end
                    RTZ:
                    begin
                        if (val >= 0.0)
                            rounded = int'(floor_val);
                        else
                            rounded = int'($ceil(val));
                    end
                    RDN: rounded = int'(floor_val);
                    RUP: rounded = int'($ceil(val));
                    RMM:
                    begin
                        if (diff < 0.5)
                            rounded = int'(floor_val);
                        else if (diff > 0.5)
                            rounded = int'(floor_val + 1.0);
                        else if (val >= 0.0)
                            rounded = int'(floor_val + 1.0);
                        else
                            rounded = int'(floor_val);
                    end
                    default:
                    begin
                        if (diff < 0.5)
                            rounded = int'(floor_val);
                        else if (diff > 0.5)
                            rounded = int'(floor_val + 1.0);
                        else
                        begin
                            rounded = int'(floor_val);
                            if (rounded % 2 != 0)
                                rounded += 1;
                        end
                    end
                endcase
            end

            if (is_unsigned)
            begin
                if (is_nan)
                    fcvt_float_to_int = 32'h7FFFFFFF;
                else if (val >= 4294967295.0 || rounded >= 64'h00000000FFFFFFFF)
                    fcvt_float_to_int = 32'h7FFFFFFF;
                else if (val <= 0.0 || rounded <= 0)
                    fcvt_float_to_int = 32'h00000000;
                else
                    fcvt_float_to_int = rounded;
            end
            else
            begin
                if (is_nan)
                    fcvt_float_to_int = 32'h7FFFFFFF;
                else if (val >= 2147483647.0 || rounded >= 64'sd2147483647)
                    fcvt_float_to_int = 32'h7FFFFFFF;
                else if (val <= -2147483648.0 || rounded <= -64'sd2147483648)
                    fcvt_float_to_int = 32'h80000000;
                else
                    fcvt_float_to_int = rounded;
            end
        endfunction:fcvt_float_to_int

        function automatic int fclass_s(input shortreal rval);
            int bits = $shortrealtobits(rval);
            bit sign = bits[FINAL_FLP_WIDTH-1];
            int exp  = bits[FINAL_FLP_WIDTH-2-:FINAL_FLP_EXP_BITS];
            int frac = bits[FINAL_FLP_FRAC_BITS-1:0];
            int class_bits = 0;

            if (exp == 8'hFF)
            begin
                if (frac == 0)
                    class_bits = sign ? (1 << 0) : (1 << 7);
                else if (frac[FINAL_FLP_FRAC_BITS-1] == 0)
                    class_bits = (1 << 8);
                else
                    class_bits = (1 << 9);
            end
            else if (exp == 0)
            begin
                if (frac == 0)
                    class_bits = sign ? (1 << 3) : (1 << 4);
                else
                    class_bits = sign ? (1 << 2) : (1 << 5);
            end
            else
            begin
                class_bits = sign ? (1 << 1) : (1 << 6);
            end

            return class_bits;
        endfunction:fclass_s

         function void compare_ints_5_percent(int a, int b);
            int diff;
            int max_val;
            int abs_a, abs_b;

            error = 1'b0;
            
            // 1. Get absolute values of a and b
            abs_a = (a < 0) ? -a : a;
            abs_b = (b < 0) ? -b : b;
            
            // 2. Calculate the absolute difference
            diff = (a > b) ? (a - b) : (b - a);
            if(diff == 0)
                return; // They are exactly equal, no error
            
            // 3. Find the maximum absolute value to act as our baseline
            max_val = (abs_a > abs_b) ? abs_a : abs_b;
            
            // 4. Compare using integer math (diff * 100 <= max_val * 5)
            // Using 100 and 5 scales the math so we don't need real numbers
            if(!((diff * 100) <= (max_val * 5)))         
            begin
                error = 1'b1;
            end
        endfunction:compare_ints_5_percent

        function void compare_shortreal_rel_error(shortreal a, shortreal b, shortreal tol);
            shortreal diff, denom, rel_err , epsilon;
            logic is_zero_a, is_zero_b;
            logic is_inf_a, is_inf_b;
            logic is_nan_a, is_nan_b;
            logic [FINAL_DATA_WIDTH-1:0] a_bits, b_bits;
            a_bits = $shortrealtobits(a);
            b_bits = $shortrealtobits(b);
            is_zero_a = (a_bits[30:0] == 0);
            is_zero_b = (b_bits[30:0] == 0);
            is_inf_a = (a_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (a_bits[FINAL_FLP_FRAC_BITS-1:0] == 0);
            is_inf_b = (b_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (b_bits[FINAL_FLP_FRAC_BITS-1:0] == 0);
            is_nan_a = (a_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (a_bits[FINAL_FLP_FRAC_BITS-1:0] != 0);
            is_nan_b = (b_bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 8'hFF) && (b_bits[FINAL_FLP_FRAC_BITS-1:0] != 0);
            diff   = a - b;
            diff   = (diff < 0.0) ? -diff : diff; // abs(diff)
            denom  = (b < 0.0) ? -b : b; // abs(b)
            epsilon = 1e-3;
            error = 1'b0;
            if(is_nan_a || is_nan_b)
            begin
                if(a_bits != b_bits)
                begin
                    error = 1'b1;
                    return;
                end
                else
                begin
                    error = 1'b0;
                    return;
                end
            end
            else if(is_inf_a || is_inf_b)
            begin
                if(a_bits != b_bits)
                begin
                    error = 1'b1;
                    return;
                end
                else
                begin
                    error = 1'b0;
                    return;
                end
            end
            else if(is_zero_a || is_zero_b)
            begin
                if(a_bits != b_bits)
                begin
                    error = 1'b1;
                    return;
                end
                else
                begin
                    error = 1'b0;
                    return;
                end
            end
            else if((denom <= epsilon) && (denom >= -epsilon))
            begin 
                rel_err = diff;
            end
            else
            begin
                rel_err = diff / denom;
            end
            if(rel_err > tol) 
            begin
                error = 1'b1;
            end 
        endfunction

        function automatic logic [FINAL_FLP_WIDTH-1:0] int_to_float_bits(
            input logic signed [FINAL_DATA_WIDTH-1:0] int_in,
            input logic sign_or_unsign,
            input round_mode_t round
        );
            logic sign;
            logic [FINAL_DATA_WIDTH-1:0] abs_val;
            logic [FINAL_FLP_EXP_BITS-1:0] exponent;
            logic [FINAL_FLP_FRAC_BITS:0] mantissa;
            int msb_index;
            logic signed [1:0] round_up_down;

            sign = int_in[FINAL_DATA_WIDTH-1];
            abs_val = sign ? -int_in : int_in;
            mantissa = '0;
            msb_index = 0;
            exponent = '0;

            if (abs_val == 0)
            begin
                int_to_float_bits = {sign, {FINAL_FLP_EXP_BITS{1'b0}}, {FINAL_FLP_FRAC_BITS{1'b0}}};
            end
            else
            begin
                for (int i = 0; i < FINAL_DATA_WIDTH; i++)
                begin
                    if (abs_val[i])
                        msb_index = i;
                end

                exponent = msb_index + FINAL_FLP_BIAS;
                abs_val = (abs_val << (FINAL_DATA_WIDTH - 1 - msb_index));
                mantissa = abs_val[FINAL_DATA_WIDTH-2 -: FINAL_FLP_FRAC_BITS];

                round_up_down = '0;
                case(round)
                    RNE: round_up_down = mantissa[0];
                    RTZ: round_up_down = '0;
                    RDN: round_up_down = sign ? 2'b11 : 2'b00;
                    RUP: round_up_down = !sign ? 2'b01 : 2'b00;
                    RMM: round_up_down = 2'b01;
                    default: round_up_down = mantissa[0];
                endcase

                mantissa = mantissa + round_up_down;
                if (mantissa == (1 << FINAL_FLP_FRAC_BITS))
                begin
                    mantissa = '0;
                    exponent++;
                end

                int_to_float_bits = {sign & sign_or_unsign, exponent, mantissa[FINAL_FLP_FRAC_BITS-1:0]};
            end
        endfunction:int_to_float_bits

        function void ref_model();
            logic [3:0] classification;
            logic [3:0] result_classification;
            logic in_a_nan, in_b_nan;
            logic in_a_inf, in_b_inf;
            logic in_a_zero, in_b_zero;
            if(!sc_item.rst)
            begin
                Overflow = 1'b0;
                Underflow = 1'b0;
                NaN = 1'b0;
                Inf = 1'b0;
                Zero = 1'b0;
                InvalidDiv = 1'b0;
                Result = '0;
                InA = '0;
                InB = '0;
                InA_real = 0.0;
                InB_real = 0.0;
                Result_real = 0.0;
                RdFOut = f0;
                RegWriteOut = 1'b0;
                MoveOperationOut = FPUToFPU;
            end
            else
            begin
                
                InA = sc_item.InA;
                InB = sc_item.InB;
                InA_real = $bitstoshortreal(InA);
                InB_real = $bitstoshortreal(InB);
                Result_real = 0.0;

                classification = classify_value(InA[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], InA[FINAL_FLP_FRAC_BITS-1:0]);
                in_a_zero = classification[0];
                in_a_inf = classification[1];
                in_a_nan = classification[2];
                classification = classify_value(InB[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], InB[FINAL_FLP_FRAC_BITS-1:0]);
                in_b_zero = classification[0];
                in_b_inf = classification[1];
                in_b_nan = classification[2];
                RegWriteOut = 1'b0;
                MoveOperationOut = FPUToFPU;
                RdFOut = f0;
                Overflow = 1'b0;
                Underflow = 1'b0;
                NaN = 1'b0;
                Inf = 1'b0;
                Zero = 1'b0;
                InvalidDiv = 1'b0;
                Result = '0;

                if(sc_item.valid && sc_item.done && sc_item.rst)
                begin
                    Overflow = 1'b0;
                    Underflow = 1'b0;
                    NaN = 1'b0;
                    Inf = 1'b0;
                    Zero = 1'b0;
                    InvalidDiv = 1'b0;
                    RegWriteOut = sc_item.RegWrite;
                    MoveOperationOut = sc_item.MoveOperation;
                    RdFOut = sc_item.RdF;
                    
                    case(sc_item.operation)
                        FADD_S:
                        begin
                            Result_real = InA_real + InB_real;
                            Result = $shortrealtobits(Result_real);
                            result_classification = classify_value(Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], Result[FINAL_FLP_FRAC_BITS-1:0]);
                            NaN = result_classification[2];
                            Inf = result_classification[1];
                            Zero = result_classification[0];
                            Overflow = Inf;
                            Underflow = (Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) && (Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !in_a_zero && !in_b_zero;
                            if(NaN)
                            begin
                                Result = {1'b0, {FINAL_FLP_EXP_BITS{1'b1}}, {1'b1, {(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                                Result_real = $bitstoshortreal(Result);
                            end
                        end
                        FSUB_S:
                        begin
                            Result_real = InA_real - InB_real;
                            Result = $shortrealtobits(Result_real);
                            result_classification = classify_value(Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], Result[FINAL_FLP_FRAC_BITS-1:0]);
                            NaN = result_classification[2];
                            Inf = result_classification[1];
                            Zero = result_classification[0];
                            Overflow = Inf;
                            if(InA === InB)
                            begin
                                Underflow = 1'b0;
                            end
                            else
                            begin
                                Underflow = (Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) && (Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !in_a_zero && !in_b_zero;
                            end
                            if(NaN)
                            begin
                                Result = {1'b0, {FINAL_FLP_EXP_BITS{1'b1}}, {1'b1, {(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                                Result_real = $bitstoshortreal(Result);
                            end
                        end
                        FMUL_S:
                        begin
                            Result_real = InA_real * InB_real;
                            Result = $shortrealtobits(Result_real);
                            result_classification = classify_value(Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], Result[FINAL_FLP_FRAC_BITS-1:0]);
                            NaN = result_classification[2];
                            Inf = result_classification[1];
                            Zero = result_classification[0];
                            Overflow = Inf && !in_a_inf && !in_b_inf;
                            Underflow = (Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) && (Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !in_a_zero && !in_b_zero;
                            if(NaN)
                            begin
                                Result = {1'b0, {FINAL_FLP_EXP_BITS{1'b1}}, {1'b1, {(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                                Result_real = $bitstoshortreal(Result);
                            end
                        end
                        FDIV_S:
                        begin
                            if ((in_a_nan || in_b_nan) || (in_a_inf && in_b_inf) || (in_a_zero && in_b_zero))
                            begin
                                Result = {1'b0, {FINAL_FLP_EXP_BITS{1'b1}}, {1'b1, {(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                                NaN = 1'b1;
                                InvalidDiv = in_b_zero && !in_a_zero && !in_a_inf && !in_a_nan ? 1'b0 : 1'b1;
                            end
                            else if (!in_a_nan && !in_a_inf && !in_a_zero && in_b_zero)
                            begin
                                Result = {InA[FINAL_FLP_WIDTH-1] ^ InB[FINAL_FLP_WIDTH-1], {FINAL_FLP_EXP_BITS{1'b1}}, {FINAL_FLP_FRAC_BITS{1'b0}}};
                                Inf = 1'b1;
                                InvalidDiv = 1'b0;
                            end
                            else
                            begin
                                Result_real = InA_real / InB_real;
                                Result = $shortrealtobits(Result_real);
                                result_classification = classify_value(Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], Result[FINAL_FLP_FRAC_BITS-1:0]);
                                NaN = result_classification[2];
                                Inf = result_classification[1];
                                Zero = result_classification[0];
                                Underflow = (Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) && (Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !in_a_zero;
                                Overflow = Inf;
                                InvalidDiv = in_b_zero;
                            end
                        end
                        FSQRT_S:
                        begin
                            if (InA[FINAL_FLP_WIDTH-1])
                            begin
                                Result = 32'h7fc00000;
                                NaN = 1'b1;
                            end
                            else if (in_a_nan || in_a_inf || in_a_zero)
                            begin
                                Result = InA;
                                NaN = in_a_nan;
                                Inf = in_a_inf;
                                Zero = in_a_zero;
                            end
                            else
                            begin
                                Result_real = $sqrt(InA_real);
                                Result = $shortrealtobits(Result_real);
                                result_classification = classify_value(Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS], Result[FINAL_FLP_FRAC_BITS-1:0]);
                                NaN = result_classification[2];
                                Inf = result_classification[1];
                                Zero = result_classification[0];
                            end
                        end
                        FSGNJ_S: Result = {InB[FINAL_DATA_WIDTH-1], InA[FINAL_DATA_WIDTH-2:0]};
                        FSGNJN_S: Result = {~InB[FINAL_DATA_WIDTH-1], InA[FINAL_DATA_WIDTH-2:0]};
                        FSGNJX_S: Result = {InB[FINAL_DATA_WIDTH-1] ^ InA[FINAL_DATA_WIDTH-1], InA[FINAL_DATA_WIDTH-2:0]};
                        FMIN_S: Result = (InA_real < InB_real) ? InA : InB;
                        FMAX_S: Result = (InA_real > InB_real) ? InA : InB;
                        FCVT_W_S: Result = fcvt_float_to_int(InA_real, sc_item.round_mode, 1'b0);
                        FCVT_WU_S: Result = fcvt_float_to_int(InA_real, sc_item.round_mode, 1'b1);
                        FMV_X_S: Result = InA;
                        FEQ_S: Result = (InA_real == InB_real) ? 32'd1 : 32'd0;
                        FLT_S: Result = (InA_real < InB_real) ? 32'd1 : 32'd0;
                        FLE_S: Result = (InA_real <= InB_real) ? 32'd1 : 32'd0;
                        FCLASS_S:
                        begin
                            Result = fclass_s(InA_real);
                            Zero = in_a_zero;
                            Inf = in_a_inf;
                            NaN = in_a_nan;
                        end
                        FCVT_S_W: Result = int_to_float_bits($signed(InA), 1'b1, sc_item.round_mode);
                        FCVT_S_WU: Result = int_to_float_bits($signed(InA), 1'b0, sc_item.round_mode);
                        FMV_S_X: Result = InA;
                        default: Result = '0;
                    endcase
                end

                error = 1'b0;
                if((sc_item.operation == FCVT_W_S) || (sc_item.operation == FCVT_WU_S))
                begin
                    compare_ints_5_percent(sc_item.Result, Result);
                end
                else
                begin
                    compare_shortreal_rel_error($bitstoshortreal(sc_item.Result), $bitstoshortreal(Result), 5e-2);
                end
            end
        endfunction:ref_model

        function void check_output ();
            if (
                error ||
                Overflow != sc_item.Overflow ||
                Underflow != sc_item.Underflow ||
                NaN != sc_item.NaN ||
                Inf != sc_item.Inf ||
                Zero != sc_item.Zero ||
                InvalidDiv != sc_item.InvalidDiv ||
                MoveOperationOut != sc_item.MoveOperationOut ||
                RegWriteOut != sc_item.RegWriteOut ||
                RdFOut != sc_item.RdFOut
            )
            begin
                $display("//////////////////////Error occured in the FPU scoreboard//////////////////////");
                `uvm_info("SCB", sc_item.convert2str(), UVM_MEDIUM)

                if (error) 
                begin
                    `uvm_info("SCB", "Output value differs from reference model beyond acceptable tolerance.", UVM_MEDIUM)
                    `uvm_info("SCB", $sformatf("Expected Result = %f/%0h -- Actual Result = %f/%0h", $bitstoshortreal(Result), Result, $bitstoshortreal(sc_item.Result), sc_item.Result), UVM_MEDIUM)
                    fail++;
                end
                if (Overflow != sc_item.Overflow)
                begin
                    `uvm_info("SCB", $sformatf("Actual output Overflow = %0h -- Expected Overflow = %0h", sc_item.Overflow, Overflow), UVM_MEDIUM)
                    fail++;
                end
                if (Underflow != sc_item.Underflow)
                begin
                    `uvm_info("SCB", $sformatf("Actual output Underflow = %0h -- Expected Underflow = %0h", sc_item.Underflow, Underflow), UVM_MEDIUM)
                    fail++;
                end
                if (NaN != sc_item.NaN)
                begin
                    `uvm_info("SCB", $sformatf("Actual output NaN = %0h -- Expected NaN = %0h", sc_item.NaN, NaN), UVM_MEDIUM)
                    fail++;
                end
                if (Inf != sc_item.Inf)
                begin
                    `uvm_info("SCB", $sformatf("Actual output Inf = %0h -- Expected Inf = %0h", sc_item.Inf, Inf), UVM_MEDIUM)
                    fail++;
                end
                if (Zero != sc_item.Zero)
                begin
                    `uvm_info("SCB", $sformatf("Actual output Zero = %0h -- Expected Zero = %0h", sc_item.Zero, Zero), UVM_MEDIUM)
                    fail++;
                end
                if (InvalidDiv != sc_item.InvalidDiv)
                begin
                    `uvm_info("SCB", $sformatf("Actual output InvalidDiv = %0h -- Expected InvalidDiv = %0h", sc_item.InvalidDiv, InvalidDiv), UVM_MEDIUM)
                    fail++;
                end
                if(RdFOut != sc_item.RdFOut)
                begin
                    `uvm_info("SCB", $sformatf("Actual output RdFOut = %s -- Expected RdFOut = %s", sc_item.RdFOut.name(), RdFOut.name()), UVM_MEDIUM)
                    fail++;
                end
                if(RegWriteOut != sc_item.RegWriteOut)
                begin
                    `uvm_info("SCB", $sformatf("Actual output RegWriteOut = %0h -- Expected RegWriteOut = %0h", sc_item.RegWriteOut, RegWriteOut), UVM_MEDIUM)
                    fail++;
                end
                if(MoveOperationOut != sc_item.MoveOperationOut)
                begin
                    `uvm_info("SCB", $sformatf("Actual output MoveOperationOut = %s -- Expected MoveOperationOut = %s", sc_item.MoveOperationOut.name(), MoveOperationOut.name()), UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (flp_item item);
            sc_item = item;
            ref_model();
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","FPU Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction

    endclass:flp_scoreboard

endpackage:flp_scoreboard_pkg
