package flp_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class flp_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(flp_config)

        //Override the constructor function
        function new (string name = "flp_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual flp_interface vif;

    endclass:flp_config


endpackage:flp_config_pkg