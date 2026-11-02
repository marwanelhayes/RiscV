// RAL backdoor checks for the AXI-visible backing data RAM.
package mem_ral_checker_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_reg_block_pkg::*;

    class mem_ral_checker extends uvm_component;
        `uvm_component_utils(mem_ral_checker)

        mem_reg_block reg_block;
        virtual axi_interface #(FINAL_DATA_WIDTH, FINAL_ADDR_WIDTH,
                                CACHE_AXI_SIZE) vif;

        logic [FINAL_ADDR_WIDTH-1:0] write_addr;
        logic [7:0]                  write_len;
        logic [CACHE_AXI_SIZE-1:0]   write_size;
        axi_burst_t                  write_burst;
        logic [FINAL_ADDR_WIDTH-1:0] wrap_base;
        bit                          write_active;
        int                          success;
        int                          fail;

        function new(string name = "mem_ral_checker", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(mem_reg_block)::get(this, "", "REG_BLOCK", reg_block))
                `uvm_fatal("DMEM_RAL", "checker could not receive register block")
            if(!uvm_config_db #(virtual axi_interface #(FINAL_DATA_WIDTH,
                    FINAL_ADDR_WIDTH, CACHE_AXI_SIZE))::get(this, "", "AXI_INTF", vif))
                `uvm_fatal("DMEM_RAL", "checker could not receive AXI interface")
        endfunction

        task check_initial_image();
            uvm_reg_data_t actual;
            uvm_status_e status;

            @(posedge vif.clk);
            for(int i = 0; i < mem_reg_block::DEPTH; i++) begin
                reg_block.data_memory.peek(status, i, actual);
                if((status != UVM_IS_OK) || (actual[FINAL_DATA_WIDTH-1:0] !== '0)) begin
                    fail++;
                    `uvm_error("DMEM_RAL", $sformatf(
                        "reset word %0d is 0x%08h, expected zero",
                        i, actual[FINAL_DATA_WIDTH-1:0]))
                end
            end
        endtask

        task check_write_beat();
            logic [FINAL_ADDR_WIDTH-1:0] beat_addr;
            logic [FINAL_DATA_WIDTH-1:0] beat_data;
            logic [(FINAL_DATA_WIDTH/8)-1:0] beat_strb;
            uvm_reg_data_t prior;
            uvm_reg_data_t after;
            uvm_reg_data_t expected;
            uvm_status_e status;
            int unsigned bytes;

            beat_addr = write_addr;
            beat_data = vif.MWData;
            beat_strb = vif.MWStrb;
            reg_block.data_memory.peek(status, beat_addr[FINAL_ADDR_WIDTH-1:2], prior);
            if(status != UVM_IS_OK) begin
                fail++;
                `uvm_error("DMEM_RAL", "pre-write backdoor peek failed")
                return;
            end

            expected = prior;
            foreach(beat_strb[i])
                if(beat_strb[i])
                    expected[8*i +: 8] = beat_data[8*i +: 8];

            bytes = 1 << int'(write_size);
            case(write_burst)
                FIXED: ;
                INCR:  write_addr = write_addr + bytes;
                WRAP: begin
                    write_addr = write_addr + bytes;
                    if(write_addr >= wrap_base + (bytes * (int'(write_len) + 1)))
                        write_addr = wrap_base;
                end
                default: ;
            endcase

            @(negedge vif.clk);
            reg_block.data_memory.peek(status, beat_addr[FINAL_ADDR_WIDTH-1:2], after);
            if((status != UVM_IS_OK) ||
               (after[FINAL_DATA_WIDTH-1:0] !== expected[FINAL_DATA_WIDTH-1:0])) begin
                fail++;
                `uvm_error("DMEM_RAL", $sformatf(
                    "AXI write mismatch at 0x%0h: RAM=0x%08h expected=0x%08h",
                    beat_addr, after[FINAL_DATA_WIDTH-1:0],
                    expected[FINAL_DATA_WIDTH-1:0]))
            end
            else
                success++;
        endtask

        virtual task run_phase(uvm_phase phase);
            int unsigned transfer_bytes;
            bit          beat_last;
            forever begin
                @(posedge vif.clk);
                if(!vif.rst) begin
                    write_active = 1'b0;
                    write_addr   = '0;
                end
                else begin
                    if(vif.MAWValid && vif.MAWReady) begin
                        write_addr   = vif.MAWAddr;
                        write_len    = vif.MAWLen;
                        write_size   = vif.MAWSize;
                        write_burst  = vif.MAWBurst;
                        transfer_bytes = 1 << int'(vif.MAWSize);
                        wrap_base = (vif.MAWAddr /
                            (transfer_bytes * (int'(vif.MAWLen) + 1))) *
                            (transfer_bytes * (int'(vif.MAWLen) + 1));
                        write_active = 1'b1;
                    end

                    if(vif.MWValid && vif.MWReady) begin
                        if(!write_active) begin
                            fail++;
                            `uvm_error("DMEM_RAL", "write data accepted prior a write address")
                        end
                        else begin
                            // Latch WLAST at the handshake: check_write_beat()
                            // waits to negedge, when WLAST may already belong
                            // to the next beat.
                            beat_last = vif.MWLast;
                            check_write_beat();
                            if(beat_last)
                                write_active = 1'b0;
                        end
                    end
                end
            end
        endtask

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("DMEM_RAL", $sformatf("backdoor write checks: success=%0d fail=%0d",
                success, fail), UVM_LOW)
        endfunction
    endclass

endpackage:mem_ral_checker_pkg
