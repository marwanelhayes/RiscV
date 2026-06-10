// =============================================================================
// flp_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the FPU.
//
// Implements the emit-before-update sequential reference pattern so its output
// transaction is published in lockstep with the registered DUT outputs the
// monitor sampled this cycle. The transaction received from the monitor is
// already aligned to the FPU's done pulse (intf2mon waits for done), so for
// each incoming item the predictor:
//   1. Emits the previously-computed shadow values that match the current
//      registered DUT outputs.
//   2. Recomputes the reference and updates the shadow for the next cycle.
//
// Combinational status flags (NaN / Inf / Zero / Overflow / Underflow /
// InvalidDiv) follow the same shadow path because the DUT registers them
// alongside Result.
// =============================================================================
package flp_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import flp_item_pkg::*;

    // ── DPI-C reference model (implemented in dpi/fpu_ref.c, Python-backed) ──
    // Only used when the predictor runs in DPI mode (+FLP_DPI). In SystemVerilog
    // mode these are never called, so the shared library does not need to be
    // loaded. Build the library with:  cd Verification/FPU/dpi && make
    import "DPI-C" context function void fpu_ref_init();
    import "DPI-C" context function void fpu_ref_shutdown();
    import "DPI-C" context function void fpu_ref_compute(
        input  int        operation,
        input  int        round_mode,
        input  int        InA_bits,
        input  int        InB_bits,
        output int        Result_bits,
        output byte       Overflow,
        output byte       Underflow,
        output byte       NaN,
        output byte       Inf,
        output byte       Zero,
        output byte       InvalidDiv
    );

    class flp_predictor extends uvm_subscriber #(flp_item);

        `uvm_component_utils(flp_predictor)

        function new (string name = "flp_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(flp_item) exp_port;
        flp_item exp, exp_clone;

        // Reference-model selector. 0 = SystemVerilog tasks (default), 1 = DPI-C
        // Python golden. Set by the +FLP_DPI plusarg or a config_db override.
        bit use_dpi = 1'b0;

        // ── Shadow registers (emit-before-update) ────────────────────────────
        logic                            q_Overflow;
        logic                            q_Underflow;
        logic                            q_NaN;
        logic                            q_Inf;
        logic                            q_Zero;
        logic                            q_InvalidDiv;
        logic [FINAL_FLP_WIDTH-1:0]      q_Result;
        fpr_t                            q_RdFOut;
        logic                            q_RegWriteOut;
        move_operation_t                 q_MoveOperationOut;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = flp_item::type_id::create("exp");
            // Select the reference model: +FLP_DPI -> Python golden via DPI-C,
            // otherwise the built-in SystemVerilog tasks. A config_db boolean
            // ("USE_DPI") can also force it on/off programmatically.
            if($test$plusargs("FLP_DPI"))
                use_dpi = 1'b1;
            void'(uvm_config_db #(bit)::get(this,"","USE_DPI",use_dpi));
            if(use_dpi)
            begin
                `uvm_info("FLP_PRED","Reference model: DPI-C Python golden (fpu_golden.py)",UVM_LOW)
                fpu_ref_init();
            end
            else
                `uvm_info("FLP_PRED","Reference model: SystemVerilog tasks",UVM_LOW)
            reset_shadow();
        endfunction:build_phase

        virtual function void final_phase (uvm_phase phase);
            super.final_phase(phase);
            if(use_dpi) fpu_ref_shutdown();
        endfunction:final_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
        endtask:reset_phase

        function void reset_shadow();
            q_Overflow         = 1'b0;
            q_Underflow        = 1'b0;
            q_NaN              = 1'b0;
            q_Inf              = 1'b0;
            q_Zero             = 1'b0;
            q_InvalidDiv       = 1'b0;
            q_Result           = '0;
            q_RdFOut           = f0;
            q_RegWriteOut      = 1'b0;
            q_MoveOperationOut = FPUToFPU;
        endfunction:reset_shadow

        // ── Helpers ─────────────────────────────────────────────────────────
        function automatic logic [3:0] classify_value(
            input logic [FINAL_FLP_EXP_BITS-1:0]  exp_bits,
            input logic [FINAL_FLP_FRAC_BITS-1:0] frac_bits
        );
            logic [3:0] c;
            c[0] = (exp_bits == 0) && (frac_bits == 0);
            c[1] = (exp_bits == {FINAL_FLP_EXP_BITS{1'b1}}) && (frac_bits == 0);
            c[2] = (exp_bits == {FINAL_FLP_EXP_BITS{1'b1}}) && (frac_bits != 0);
            c[3] = (exp_bits == 0) && (frac_bits != 0);
            return c;
        endfunction:classify_value

        function automatic int fcvt_float_to_int(
            input real         val,
            input round_mode_t mode,
            input logic        is_unsigned
        );
            real  floor_val, diff;
            int   rounded;
            logic is_nan;
            is_nan    = (val != val);
            floor_val = $floor(val);
            diff      = val - floor_val;
            if(is_nan) rounded = 0;
            else
            begin
                case(mode)
                    RNE: begin
                        if(diff < 0.5)       rounded = int'(floor_val);
                        else if(diff > 0.5)  rounded = int'(floor_val + 1.0);
                        else begin
                            rounded = int'(floor_val);
                            if(rounded % 2 != 0) rounded += 1;
                        end
                    end
                    RTZ: rounded = (val >= 0.0) ? int'(floor_val) : int'($ceil(val));
                    RDN: rounded = int'(floor_val);
                    RUP: rounded = int'($ceil(val));
                    RMM: begin
                        if(diff < 0.5)       rounded = int'(floor_val);
                        else if(diff > 0.5)  rounded = int'(floor_val + 1.0);
                        else if(val >= 0.0)  rounded = int'(floor_val + 1.0);
                        else                 rounded = int'(floor_val);
                    end
                    default: begin
                        if(diff < 0.5)      rounded = int'(floor_val);
                        else if(diff > 0.5) rounded = int'(floor_val + 1.0);
                        else begin
                            rounded = int'(floor_val);
                            if(rounded % 2 != 0) rounded += 1;
                        end
                    end
                endcase
            end
            if(is_unsigned)
            begin
                if(is_nan)                                       fcvt_float_to_int = 32'h7FFFFFFF;
                else if(val >= 4294967295.0 ||
                        rounded >= 64'h00000000FFFFFFFF)         fcvt_float_to_int = 32'h7FFFFFFF;
                else if(val <= 0.0 || rounded <= 0)              fcvt_float_to_int = 32'h00000000;
                else                                             fcvt_float_to_int = rounded;
            end
            else
            begin
                if(is_nan)                                       fcvt_float_to_int = 32'h7FFFFFFF;
                else if(val >=  2147483647.0 ||
                        rounded >=  64'sd2147483647)             fcvt_float_to_int = 32'h7FFFFFFF;
                else if(val <= -2147483648.0 ||
                        rounded <= -64'sd2147483648)             fcvt_float_to_int = 32'h80000000;
                else                                             fcvt_float_to_int = rounded;
            end
        endfunction:fcvt_float_to_int

        function automatic int fclass_s(input shortreal rval);
            int bits = $shortrealtobits(rval);
            bit sign = bits[FINAL_FLP_WIDTH-1];
            int exp_bits  = bits[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS];
            int frac_bits = bits[FINAL_FLP_FRAC_BITS-1:0];
            int c = 0;
            if(exp_bits == 8'hFF) begin
                if(frac_bits == 0)                              c = sign ? (1<<0) : (1<<7);
                else if(frac_bits[FINAL_FLP_FRAC_BITS-1] == 0)  c = (1<<8);
                else                                            c = (1<<9);
            end
            else if(exp_bits == 0) begin
                if(frac_bits == 0) c = sign ? (1<<3) : (1<<4);
                else               c = sign ? (1<<2) : (1<<5);
            end
            else                   c = sign ? (1<<1) : (1<<6);
            return c;
        endfunction:fclass_s

        function automatic logic [FINAL_FLP_WIDTH-1:0] int_to_float_bits(
            input logic signed [FINAL_DATA_WIDTH-1:0] int_in,
            input logic                               sign_or_unsign,
            input round_mode_t                        round
        );
            logic                              sign;
            logic [FINAL_DATA_WIDTH-1:0]       abs_val;
            logic [FINAL_FLP_EXP_BITS-1:0]     exponent;
            logic [FINAL_FLP_FRAC_BITS:0]      mantissa;
            int                                msb_index;
            logic signed [1:0]                 round_up_down;

            sign      = int_in[FINAL_DATA_WIDTH-1];
            abs_val   = sign ? -int_in : int_in;
            mantissa  = '0;
            msb_index = 0;
            exponent  = '0;
            if(abs_val == 0)
            begin
                int_to_float_bits = {sign, {FINAL_FLP_EXP_BITS{1'b0}}, {FINAL_FLP_FRAC_BITS{1'b0}}};
            end
            else
            begin
                for(int i = 0; i < FINAL_DATA_WIDTH; i++)
                    if(abs_val[i]) msb_index = i;
                exponent = msb_index + FINAL_FLP_BIAS;
                abs_val  = (abs_val << (FINAL_DATA_WIDTH - 1 - msb_index));
                mantissa = abs_val[FINAL_DATA_WIDTH-2 -: FINAL_FLP_FRAC_BITS];
                round_up_down = '0;
                case(round)
                    RNE:     round_up_down = mantissa[0];
                    RTZ:     round_up_down = '0;
                    RDN:     round_up_down = sign  ? 2'b11 : 2'b00;
                    RUP:     round_up_down = !sign ? 2'b01 : 2'b00;
                    RMM:     round_up_down = 2'b01;
                    default: round_up_down = mantissa[0];
                endcase
                mantissa = mantissa + round_up_down;
                if(mantissa == (1 << FINAL_FLP_FRAC_BITS))
                begin
                    mantissa = '0;
                    exponent++;
                end
                int_to_float_bits = {sign & sign_or_unsign, exponent, mantissa[FINAL_FLP_FRAC_BITS-1:0]};
            end
        endfunction:int_to_float_bits

        // ── Compute next-cycle expected values from a transaction ────────────
        function automatic void compute(
            input  flp_item t,
            output logic                            n_Overflow,
            output logic                            n_Underflow,
            output logic                            n_NaN,
            output logic                            n_Inf,
            output logic                            n_Zero,
            output logic                            n_InvalidDiv,
            output logic [FINAL_FLP_WIDTH-1:0]      n_Result,
            output fpr_t                            n_RdFOut,
            output logic                            n_RegWriteOut,
            output move_operation_t                 n_MoveOperationOut
        );
            logic [FINAL_FLP_WIDTH-1:0] InA, InB;
            shortreal                   InA_real, InB_real, Result_real;
            logic [3:0]                 c, rc;
            logic                       a_zero, a_inf, a_nan;
            logic                       b_zero, b_inf, b_nan;
            InA          = t.InA;
            InB          = t.InB;
            InA_real     = $bitstoshortreal(InA);
            InB_real     = $bitstoshortreal(InB);
            Result_real  = 0.0;
            c = classify_value(InA[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                               InA[FINAL_FLP_FRAC_BITS-1:0]);
            a_zero = c[0]; a_inf = c[1]; a_nan = c[2];
            c = classify_value(InB[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                               InB[FINAL_FLP_FRAC_BITS-1:0]);
            b_zero = c[0]; b_inf = c[1]; b_nan = c[2];

            n_Overflow         = 1'b0;
            n_Underflow        = 1'b0;
            n_NaN              = 1'b0;
            n_Inf              = 1'b0;
            n_Zero             = 1'b0;
            n_InvalidDiv       = 1'b0;
            n_Result           = '0;
            n_RdFOut           = t.RdF;
            n_RegWriteOut      = t.RegWrite;
            n_MoveOperationOut = t.MoveOperation;

            case(t.operation)
                FADD_S: begin
                    Result_real  = InA_real + InB_real;
                    n_Result     = $shortrealtobits(Result_real);
                    rc = classify_value(n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                                        n_Result[FINAL_FLP_FRAC_BITS-1:0]);
                    n_NaN  = rc[2]; n_Inf = rc[1]; n_Zero = rc[0]; n_Overflow = n_Inf;
                    n_Underflow = (n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) &&
                                  (n_Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !a_zero && !b_zero;
                    if(n_NaN) n_Result = {1'b0,{FINAL_FLP_EXP_BITS{1'b1}},{1'b1,{(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                end
                FSUB_S: begin
                    Result_real  = InA_real - InB_real;
                    n_Result     = $shortrealtobits(Result_real);
                    rc = classify_value(n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                                        n_Result[FINAL_FLP_FRAC_BITS-1:0]);
                    n_NaN = rc[2]; n_Inf = rc[1]; n_Zero = rc[0]; n_Overflow = n_Inf;
                    n_Underflow = (InA !== InB) &&
                                  (n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) &&
                                  (n_Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !a_zero && !b_zero;
                    if(n_NaN) n_Result = {1'b0,{FINAL_FLP_EXP_BITS{1'b1}},{1'b1,{(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                end
                FMUL_S: begin
                    Result_real  = InA_real * InB_real;
                    n_Result     = $shortrealtobits(Result_real);
                    rc = classify_value(n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                                        n_Result[FINAL_FLP_FRAC_BITS-1:0]);
                    n_NaN  = rc[2]; n_Inf = rc[1]; n_Zero = rc[0];
                    n_Overflow  = n_Inf && !a_inf && !b_inf;
                    n_Underflow = (n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) &&
                                  (n_Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !a_zero && !b_zero;
                    if(n_NaN) n_Result = {1'b0,{FINAL_FLP_EXP_BITS{1'b1}},{1'b1,{(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                end
                FDIV_S: begin
                    if((a_nan || b_nan) || (a_inf && b_inf) || (a_zero && b_zero)) begin
                        n_Result     = {1'b0,{FINAL_FLP_EXP_BITS{1'b1}},{1'b1,{(FINAL_FLP_FRAC_BITS-1){1'b0}}}};
                        n_NaN        = 1'b1;
                        n_InvalidDiv = (b_zero && !a_zero && !a_inf && !a_nan) ? 1'b0 : 1'b1;
                    end
                    else if(!a_nan && !a_inf && !a_zero && b_zero) begin
                        n_Result     = {InA[FINAL_FLP_WIDTH-1]^InB[FINAL_FLP_WIDTH-1],
                                        {FINAL_FLP_EXP_BITS{1'b1}},{FINAL_FLP_FRAC_BITS{1'b0}}};
                        n_Inf        = 1'b1;
                        n_InvalidDiv = 1'b0;
                    end
                    else begin
                        Result_real  = InA_real / InB_real;
                        n_Result     = $shortrealtobits(Result_real);
                        rc = classify_value(n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                                            n_Result[FINAL_FLP_FRAC_BITS-1:0]);
                        n_NaN  = rc[2]; n_Inf = rc[1]; n_Zero = rc[0];
                        n_Underflow = (n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS] == 0) &&
                                      (n_Result[FINAL_FLP_FRAC_BITS-1:0] == 0) && !a_zero;
                        n_Overflow   = n_Inf;
                        n_InvalidDiv = b_zero;
                    end
                end
                FSQRT_S: begin
                    if(InA[FINAL_FLP_WIDTH-1]) begin
                        n_Result = 32'h7fc00000;
                        n_NaN    = 1'b1;
                    end
                    else if(a_nan || a_inf || a_zero) begin
                        n_Result = InA;
                        n_NaN    = a_nan; n_Inf = a_inf; n_Zero = a_zero;
                    end
                    else begin
                        Result_real = $sqrt(InA_real);
                        n_Result    = $shortrealtobits(Result_real);
                        rc = classify_value(n_Result[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS],
                                            n_Result[FINAL_FLP_FRAC_BITS-1:0]);
                        n_NaN = rc[2]; n_Inf = rc[1]; n_Zero = rc[0];
                    end
                end
                FSGNJ_S:   n_Result = {InB[FINAL_DATA_WIDTH-1],            InA[FINAL_DATA_WIDTH-2:0]};
                FSGNJN_S:  n_Result = {~InB[FINAL_DATA_WIDTH-1],           InA[FINAL_DATA_WIDTH-2:0]};
                FSGNJX_S:  n_Result = {InB[FINAL_DATA_WIDTH-1]^InA[FINAL_DATA_WIDTH-1], InA[FINAL_DATA_WIDTH-2:0]};
                FMIN_S:    n_Result = (InA_real <  InB_real) ? InA : InB;
                FMAX_S:    n_Result = (InA_real >  InB_real) ? InA : InB;
                FCVT_W_S:  n_Result = fcvt_float_to_int(InA_real, t.round_mode, 1'b0);
                FCVT_WU_S: n_Result = fcvt_float_to_int(InA_real, t.round_mode, 1'b1);
                FMV_X_S:   n_Result = InA;
                FEQ_S:     n_Result = (InA_real == InB_real) ? 32'd1 : 32'd0;
                FLT_S:     n_Result = (InA_real <  InB_real) ? 32'd1 : 32'd0;
                FLE_S:     n_Result = (InA_real <= InB_real) ? 32'd1 : 32'd0;
                FCLASS_S: begin
                    n_Result = fclass_s($bitstoshortreal(InA));
                    n_Zero = a_zero; n_Inf = a_inf; n_NaN = a_nan;
                end
                FCVT_S_W:  n_Result = int_to_float_bits($signed(InA), 1'b1, t.round_mode);
                FCVT_S_WU: n_Result = int_to_float_bits($signed(InA), 1'b0, t.round_mode);
                FMV_S_X:   n_Result = InA;
                default:   n_Result = '0;
            endcase
        endfunction:compute

        // ── DPI-C reference: identical output set, computed by fpu_golden.py ──
        // The register/move plumbing (RdFOut/RegWriteOut/MoveOperationOut) is a
        // straight passthrough exactly as in the SystemVerilog path; only the
        // numeric Result and status flags come from the Python golden model.
        function automatic void compute_dpi(
            input  flp_item t,
            output logic                            n_Overflow,
            output logic                            n_Underflow,
            output logic                            n_NaN,
            output logic                            n_Inf,
            output logic                            n_Zero,
            output logic                            n_InvalidDiv,
            output logic [FINAL_FLP_WIDTH-1:0]      n_Result,
            output fpr_t                            n_RdFOut,
            output logic                            n_RegWriteOut,
            output move_operation_t                 n_MoveOperationOut
        );
            int  d_Result_bits;
            byte d_Overflow, d_Underflow, d_NaN, d_Inf, d_Zero, d_InvalidDiv;
            fpu_ref_compute(
                int'(t.operation),
                int'(t.round_mode),
                int'(t.InA),
                int'(t.InB),
                d_Result_bits,
                d_Overflow, d_Underflow, d_NaN, d_Inf, d_Zero, d_InvalidDiv
            );
            n_Result           = d_Result_bits[FINAL_FLP_WIDTH-1:0];
            n_Overflow         = d_Overflow[0];
            n_Underflow        = d_Underflow[0];
            n_NaN              = d_NaN[0];
            n_Inf              = d_Inf[0];
            n_Zero             = d_Zero[0];
            n_InvalidDiv       = d_InvalidDiv[0];
            n_RdFOut           = t.RdF;
            n_RegWriteOut      = t.RegWrite;
            n_MoveOperationOut = t.MoveOperation;
        endfunction:compute_dpi

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (flp_item t);
            logic                            n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero, n_InvalidDiv;
            logic [FINAL_FLP_WIDTH-1:0]      n_Result;
            fpr_t                            n_RdFOut;
            logic                            n_RegWriteOut;
            move_operation_t                 n_MoveOperationOut;


            if(!t.rst)
            begin
                exp.Overflow         = 1'b0;
                exp.Underflow        = 1'b0;
                exp.NaN              = 1'b0;
                exp.Inf              = 1'b0;
                exp.Zero             = 1'b0;
                exp.InvalidDiv       = 1'b0;
                exp.Result           = '0;
                exp.RdFOut           = f0;
                exp.RegWriteOut      = 1'b0;
                exp.MoveOperationOut = FPUToFPU;
                exp.copy_inputs(t);
            end
            else if(!t.valid)
            begin
                exp.Overflow         = q_Overflow;
                exp.Underflow        = q_Underflow;
                exp.NaN              = q_NaN;
                exp.Inf              = q_Inf;
                exp.Zero             = q_Zero;
                exp.InvalidDiv       = q_InvalidDiv;
                exp.Result           = q_Result;
                exp.RdFOut           = q_RdFOut;
                exp.RegWriteOut      = q_RegWriteOut;
                exp.MoveOperationOut = q_MoveOperationOut;
            end
            else
            begin
                if(use_dpi)
                    compute_dpi(t, n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero,
                                n_InvalidDiv, n_Result, n_RdFOut, n_RegWriteOut, n_MoveOperationOut);
                else
                    compute(t, n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero,
                            n_InvalidDiv, n_Result, n_RdFOut, n_RegWriteOut, n_MoveOperationOut);
                exp.Overflow         = n_Overflow;
                exp.Underflow        = n_Underflow;
                exp.NaN              = n_NaN;
                exp.Inf              = n_Inf;
                exp.Zero             = n_Zero;
                exp.InvalidDiv       = n_InvalidDiv;
                exp.Result           = n_Result;
                exp.RdFOut           = n_RdFOut;
                exp.RegWriteOut      = n_RegWriteOut;
                exp.MoveOperationOut = n_MoveOperationOut;
                exp.copy_inputs(t);
            end
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("CLONE FAILED","Failed to clone expected item in predictor!")
            else
                exp_port.write(exp_clone);

            if(!t.rst)
            begin 
                reset_shadow();
            end
            else if(t.valid && t.done)
            begin
                q_Overflow         = exp.Overflow;
                q_Underflow        = exp.Underflow;
                q_NaN              = exp.NaN;
                q_Inf              = exp.Inf;
                q_Zero             = exp.Zero;
                q_InvalidDiv       = exp.InvalidDiv;
                q_Result           = exp.Result;
                q_RdFOut           = exp.RdFOut;
                q_RegWriteOut      = exp.RegWriteOut;
                q_MoveOperationOut = exp.MoveOperationOut;
            end
        endfunction:write

    endclass:flp_predictor

endpackage: flp_predictor_pkg
