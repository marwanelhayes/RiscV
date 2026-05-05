// =============================================================================
// fetch_config_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage configuration package for UVM verification.
// =============================================================================
package fetch_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class fetch_config extends uvm_object;

        //Register the class into the factory
        `uvm_object_utils(fetch_config)

        //Override the constructor function
        function new (string name = "fetch_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        virtual fetch_interface vif;

    endclass:fetch_config


endpackage:fetch_config_pkg