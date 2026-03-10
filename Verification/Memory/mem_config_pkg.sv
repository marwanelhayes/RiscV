package mem_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class mem_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(mem_config)

        //Override the constructor function
        function new (string name = "mem_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual mem_interface vif;

    endclass:mem_config


endpackage:mem_config_pkg