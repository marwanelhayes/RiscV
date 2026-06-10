package flp_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import flp_item_pkg::*;
    import shared_pkg::*;

    // IEEE-754 single-precision operand class (decoded from exponent/fraction).
    typedef enum logic [2:0] {FP_ZERO, FP_DENORM, FP_NORMAL, FP_INF, FP_NAN} fp_class_t;

    class flp_subscriber extends uvm_subscriber #(flp_item);

        //Register the class to the factory
        `uvm_component_param_utils(flp_subscriber)


        flp_item sub_item;
        fp_class_t ina_class;
        fp_class_t inb_class;

        // Classify a single-precision value by its exponent/fraction fields.
        function automatic fp_class_t classify(input logic [FINAL_FLP_WIDTH-1:0] v);
            logic [FINAL_FLP_EXP_BITS-1:0]  exp;
            logic [FINAL_FLP_FRAC_BITS-1:0] frac;
            exp  = v[FINAL_FLP_WIDTH-2 -: FINAL_FLP_EXP_BITS];
            frac = v[FINAL_FLP_FRAC_BITS-1:0];
            if(exp == 0)                  classify = (frac == 0) ? FP_ZERO : FP_DENORM;
            else if(&exp)                 classify = (frac == 0) ? FP_INF  : FP_NAN;
            else                          classify = FP_NORMAL;
        endfunction

        // ── Functional coverage model ────────────────────────────────────────
        // Samples while out of reset. Covers operation, rounding, the operand
        // IEEE classes and the status-flag outputs.
        covergroup cvr_grp();

            valid_cg: coverpoint sub_item.valid iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            operation_cg: coverpoint sub_item.operation iff(sub_item.rst)
            {
                bins op[] = {FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S, FSGNJ_S, FSGNJN_S,
                             FSGNJX_S, FMIN_S, FMAX_S, FCVT_W_S, FCVT_WU_S, FMV_X_S,
                             FEQ_S, FLT_S, FLE_S, FCLASS_S, FCVT_S_W, FCVT_S_WU,
                             FMV_S_X, NOOPERATION};
            }

            round_mode_cg: coverpoint sub_item.round_mode iff(sub_item.rst)
            {
                bins rne = {RNE};
                bins rtz = {RTZ};
                bins rdn = {RDN};
                bins rup = {RUP};
                bins rmm = {RMM};
                bins dyn = {DYN};
            }

            MoveOperation_cg: coverpoint sub_item.MoveOperation iff(sub_item.rst)
            {
                bins fpu_to_reg = {FPUToReg};
                bins reg_to_fpu = {RegToFPU};
                bins fpu_to_fpu = {FPUToFPU};
            }

            RegWrite_cg: coverpoint sub_item.RegWrite iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            // Operand IEEE classes.
            InA_class_cg: coverpoint ina_class iff(sub_item.rst)
            {
                bins zero    = {FP_ZERO};
                bins denorm  = {FP_DENORM};
                bins normal  = {FP_NORMAL};
                bins inf     = {FP_INF};
                bins nan     = {FP_NAN};
            }
            InB_class_cg: coverpoint inb_class iff(sub_item.rst)
            {
                bins zero    = {FP_ZERO};
                bins denorm  = {FP_DENORM};
                bins normal  = {FP_NORMAL};
                bins inf     = {FP_INF};
                bins nan     = {FP_NAN};
            }

            // Status / handshake outputs.
            busy_cg: coverpoint sub_item.busy iff(sub_item.rst)             { bins lo = {0}; bins hi = {1}; }
            done_cg: coverpoint sub_item.done iff(sub_item.rst)             { bins lo = {0}; bins hi = {1}; }
            Overflow_cg: coverpoint sub_item.Overflow iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            Underflow_cg: coverpoint sub_item.Underflow iff(sub_item.rst)   { bins lo = {0}; bins hi = {1}; }
            NaN_cg: coverpoint sub_item.NaN iff(sub_item.rst)               { bins lo = {0}; bins hi = {1}; }
            Inf_cg: coverpoint sub_item.Inf iff(sub_item.rst)              { bins lo = {0}; bins hi = {1}; }
            Zero_cg: coverpoint sub_item.Zero iff(sub_item.rst)            { bins lo = {0}; bins hi = {1}; }
            InvalidDiv_cg: coverpoint sub_item.InvalidDiv iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            // ── Crosses ──────────────────────────────────────────────────────
            operation_x_round_cx: cross operation_cg, round_mode_cg;
            InA_x_InB_class_cx:   cross InA_class_cg, InB_class_cg;

        endgroup:cvr_grp

        function new (string name = "flp_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item  = t;
            ina_class = classify(t.InA);
            inb_class = classify(t.InB);
            cvr_grp.sample();
        endfunction

    endclass:flp_subscriber

endpackage: flp_subscriber_pkg
