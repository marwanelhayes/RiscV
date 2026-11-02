// UVM RAL model for the backing data RAM used by mem_top.
package mem_reg_block_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class mem_reg_block extends uvm_reg_block;
        `uvm_object_utils(mem_reg_block)

        localparam int DEPTH = 2**(FINAL_ADDR_WIDTH-2);
        uvm_mem data_memory;

        function new(string name = "mem_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            configure(null);
            default_map = create_map("default_map", 0, FINAL_DATA_WIDTH/8,
                                     UVM_LITTLE_ENDIAN);
            data_memory = new("data_memory", DEPTH, FINAL_DATA_WIDTH,
                              "RW", UVM_NO_COVERAGE);
            data_memory.configure(this, "mem");
            default_map.add_mem(data_memory, '0, "RW");
            add_hdl_path("mem_top.DataMem");
        endfunction
    endclass

endpackage:mem_reg_block_pkg
