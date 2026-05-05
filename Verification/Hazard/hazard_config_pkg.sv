package hazard_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class hazard_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(hazard_config)

        //Override the constructor function
        function new (string name = "hazard_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual hazard_interface vif;

    endclass:hazard_config


endpackage:hazard_config_pkg