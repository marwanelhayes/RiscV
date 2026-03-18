package csr_driver_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import csr_item_pkg::*;

    class csr_driver extends uvm_driver #(csr_item);
        
        `uvm_component_utils(csr_driver)

        virtual csr_interface vif;
        csr_item drv_item;
        
        function new (string name = "csr_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction: new

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

    endclass:csr_driver

endpackage:csr_driver_pkg
