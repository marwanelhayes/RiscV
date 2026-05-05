package hazard_driver_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import hazard_item_pkg::*;

    class hazard_driver extends uvm_driver #(hazard_item);
        
        //Register the class to the factory
        `uvm_component_utils(hazard_driver)

        virtual hazard_interface vif;
        hazard_item drv_item;
        
        //Overriding the constructor with the child class
        function new (string name = "hazard_driver", uvm_component parent = null);
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

    endclass:hazard_driver

endpackage: hazard_driver_pkg