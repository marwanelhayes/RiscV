package csr_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class csr_config extends uvm_object;

        `uvm_object_utils(csr_config)

        function new (string name = "csr_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual csr_interface vif;

    endclass:csr_config

endpackage:csr_config_pkg
