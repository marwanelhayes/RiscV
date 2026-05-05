package mem_driver_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_item_pkg::*;

    class mem_driver extends uvm_driver #(mem_item);
        
        //Register the class to the factory
        `uvm_component_utils(mem_driver)

        virtual mem_interface vif;
        mem_item drv_item;
        
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