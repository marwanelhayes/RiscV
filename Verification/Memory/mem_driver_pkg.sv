package mem_driver_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_item_pkg::*;

    class mem_driver #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH =32) extends uvm_driver #(mem_item #(DATA_WIDTH,ADDR_WIDTH));
        
        //Register the class to the factory
        `uvm_component_param_utils( mem_driver #(DATA_WIDTH,ADDR_WIDTH))

        virtual mem_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;
        mem_item #(DATA_WIDTH,ADDR_WIDTH) drv_item;
        
        //Overriding the constructor with the child class
        function new (string name = "mem_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction: new

        //Run phase
        virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            vif.initialize();
            forever
            begin:drive
                seq_item_port.get_next_item(drv_item);
                    vif.drv2intf(drv_item);
                    `uvm_info("DRV",drv_item.convert2str(),UVM_DEBUG)
                seq_item_port.item_done();
            end:drive
        endtask: run_phase

    endclass:mem_driver

endpackage: mem_driver_pkg