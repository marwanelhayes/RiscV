package execute_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class execute_config #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_object;

        //Register the class into the factory
        `uvm_object_param_utils(execute_config #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "execute_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual execute_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;

    endclass:execute_config


endpackage:execute_config_pkg