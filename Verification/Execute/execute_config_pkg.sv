package execute_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class execute_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(execute_config)

        //Override the constructor function
        function new (string name = "execute_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual execute_interface vif;

    endclass:execute_config


endpackage:execute_config_pkg