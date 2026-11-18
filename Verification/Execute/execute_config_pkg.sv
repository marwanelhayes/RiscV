// =============================================================================
// execute_config_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package execute_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // execute_config: agent mode and execute_interface handle
    // =========================================================================
    class execute_config extends base_config #(virtual execute_interface);

        `uvm_object_utils(execute_config)

        function new (string name = "execute_config");
            super.new(name);
        endfunction:new

    endclass:execute_config

endpackage:execute_config_pkg
