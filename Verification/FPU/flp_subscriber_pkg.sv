package flp_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import flp_item_pkg::*;

    class flp_subscriber extends uvm_subscriber #(flp_item);

        //Register the class to the factory
        `uvm_component_param_utils(flp_subscriber)


        flp_item sub_item;

        covergroup cvr_grp();
            rst_cp: coverpoint sub_item.rst;
            valid_cp: coverpoint sub_item.valid iff(!sub_item.rst);
            in_a_cp: coverpoint sub_item.InA iff(!sub_item.rst);
            in_b_cp: coverpoint sub_item.InB iff(!sub_item.rst);
            round_mode_cp: coverpoint sub_item.round_mode iff(!sub_item.rst);
            operation_cp: coverpoint sub_item.operation iff(!sub_item.rst);
            busy_cp: coverpoint sub_item.busy iff(!sub_item.rst);
            done_cp: coverpoint sub_item.done iff(!sub_item.rst);
            overflow_cp: coverpoint sub_item.Overflow iff(!sub_item.rst);
            underflow_cp: coverpoint sub_item.Underflow iff(!sub_item.rst);
            nan_cp: coverpoint sub_item.NaN iff(!sub_item.rst);
            inf_cp: coverpoint sub_item.Inf iff(!sub_item.rst);
            zero_cp: coverpoint sub_item.Zero iff(!sub_item.rst);
            invalid_div_cp: coverpoint sub_item.InvalidDiv iff(!sub_item.rst);
            result_cp: coverpoint sub_item.Result iff(!sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "flp_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:flp_subscriber

endpackage: flp_subscriber_pkg
