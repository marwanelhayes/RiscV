package writeback_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class writeback_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(writeback_config)

        //Override the constructor function
        function new (string name = "writeback_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual writeback_interface vif;

    endclass:writeback_config


endpackage:writeback_config_pkg