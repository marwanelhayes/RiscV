package mem_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class mem_config #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 10) extends uvm_object;

        //Register the class into the factory
        `uvm_object_param_utils(mem_config #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "mem_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual mem_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;

    endclass:mem_config


endpackage:mem_config_pkg