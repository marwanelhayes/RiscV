// UVM RAL model for the instruction ROM used by fetch_top.
package fetch_reg_block_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class fetch_reg_block extends uvm_reg_block;
        `uvm_object_utils(fetch_reg_block)

        localparam int DEPTH = 2**(FINAL_ADDR_WIDTH-$clog2(FINAL_DATA_WIDTH/8));   // DATA_WIDTH words
        uvm_mem instruction_memory;

        function new(string name = "fetch_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            configure(null);
            default_map = create_map("default_map", 0, FINAL_DATA_WIDTH/8,
                                     UVM_LITTLE_ENDIAN);
            instruction_memory = new("instruction_memory", DEPTH,
                                     FINAL_DATA_WIDTH, "RO", UVM_NO_COVERAGE);
            instruction_memory.configure(this, "mem");
            default_map.add_mem(instruction_memory, '0, "RO");
            add_hdl_path("fetch_top.InstrMem");
        endfunction
    endclass

endpackage:fetch_reg_block_pkg
