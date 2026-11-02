// Backdoor RAL check that the instruction ROM matches its source image.
package fetch_mem_checker_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import fetch_reg_block_pkg::*;

    class fetch_mem_checker extends uvm_component;
        `uvm_component_utils(fetch_mem_checker)

        fetch_reg_block         reg_block;
        virtual fetch_interface vif;

        function new(string name = "fetch_mem_checker", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(fetch_reg_block)::get(this, "", "REG_BLOCK", reg_block))
                `uvm_fatal("IMEM_RAL", "checker could not receive register block")
            if(!uvm_config_db #(virtual fetch_interface)::get(this, "", "INTF", vif))
                `uvm_fatal("IMEM_RAL", "checker could not receive interface")
        endfunction

        // The image holds one 32-bit instruction per line; a DATA_WIDTH ROM
        // word packs DATA_WIDTH/32 consecutive instructions (lowest address in
        // the low half). Words past the end of the image must be zero.
        task check_image();
            localparam int PER_WORD = FINAL_DATA_WIDTH / INSTR_WIDTH;
            int fd;
            int failures;
            logic [INSTR_WIDTH-1:0] image [$];
            logic [INSTR_WIDTH-1:0] line;
            logic [FINAL_DATA_WIDTH-1:0] expected;
            uvm_reg_data_t actual;
            uvm_status_e status;
            @(posedge vif.clk);
            failures = 0;
            fd = $fopen(INSTR_MEM_PATH, "r");
            if(fd == 0)
                `uvm_fatal("IMEM_RAL", $sformatf("cannot open %s", INSTR_MEM_PATH))
            while($fscanf(fd, "%b", line) == 1)
                image.push_back(line);
            for(int i = 0; i < fetch_reg_block::DEPTH; i++) begin
                expected = '0;
                for(int k = 0; k < PER_WORD; k++)
                    if(PER_WORD*i + k < image.size())
                        expected[INSTR_WIDTH*k +: INSTR_WIDTH] = image[PER_WORD*i + k];
                reg_block.instruction_memory.peek(status, i, actual);
                if((status != UVM_IS_OK) || (actual[FINAL_DATA_WIDTH-1:0] !== expected)) begin
                    failures++;
                    `uvm_error("IMEM_RAL", $sformatf(
                        "word %0d mismatch: ROM=0x%0h image=0x%0h",
                        i, actual[FINAL_DATA_WIDTH-1:0], expected))
                end
            end
            $fclose(fd);

            if(failures == 0)
                `uvm_info("IMEM_RAL", "instruction ROM matches source image", UVM_LOW)
        endtask
    endclass

endpackage:fetch_mem_checker_pkg
