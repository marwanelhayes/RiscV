package writeback_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class writeback_config #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 10) extends uvm_object;

        //Register the class into the factory
        `uvm_object_param_utils(writeback_config #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "writeback_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual writeback_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;

    endclass:writeback_config


endpackage:writeback_config_pkg