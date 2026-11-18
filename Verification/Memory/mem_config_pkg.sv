// =============================================================================
// mem_config_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package mem_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // mem_config: agent mode and mem_interface handle
    // =========================================================================
    class mem_config extends base_config #(virtual mem_interface);

        `uvm_object_utils(mem_config)

        function new (string name = "mem_config");
            super.new(name);
        endfunction:new

    endclass:mem_config

endpackage:mem_config_pkg
