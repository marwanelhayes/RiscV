package decode_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class decode_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_param_utils(decode_config)

        //Override the constructor function
        function new (string name = "decode_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual decode_interface vif;

    endclass:decode_config


endpackage:decode_config_pkg