// =============================================================================
// csr_config_pkg.sv
// -----------------------------------------------------------------------------
// CSR file environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package csr_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // csr_config: agent mode and csr_interface handle
    // =========================================================================
    class csr_config extends base_config #(virtual csr_interface);

        `uvm_object_utils(csr_config)

        function new (string name = "csr_config");
            super.new(name);
        endfunction:new

    endclass:csr_config

endpackage:csr_config_pkg
