package flp_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import flp_item_pkg::*;

    class flp_monitor extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_utils(flp_monitor)

        //Override the constructor function
        function new (string name = "flp_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(flp_item) mon_port;
        flp_item mon_item, cloned_item , decoupled_item , decoupled_item_clone;
        flp_item monitor_queue[$];
        virtual flp_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = flp_item::type_id::create("mon_item");
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                if(vif.checkifrst(mon_item))
                begin
                    if(!$cast(cloned_item, mon_item.clone()))
                        `uvm_fatal("CLONE_FAIL","Failed to clone the monitor item")
                    monitor_queue.delete();
                    mon_port.write(cloned_item);
                end
                else
                begin
                    if(vif.checkifvalid(mon_item))
                    begin
                        if(!$cast(cloned_item, mon_item.clone()))
                            `uvm_fatal("CLONE_FAIL","Failed to clone the monitor item")
                        monitor_queue.push_back(cloned_item);
                        `uvm_info("MON", {$sformatf("Valid item received and stored in queue. Queue size: %0d", monitor_queue.size()), cloned_item.convert2str()}, UVM_HIGH)
                    end
                    if(vif.checkifdone(mon_item))
                    begin
                        if(monitor_queue.size() == 0)
                            `uvm_fatal("QUEUE_UNDERFLOW","Monitor queue is empty when a done item is received - possible missing valid item - Major Design Flaw")
                        decoupled_item = monitor_queue.pop_front();
                        decoupled_item.copy_outputs(mon_item);
                        if(!$cast(decoupled_item_clone, decoupled_item.clone()))
                            `uvm_fatal("CLONE_FAIL","Failed to clone the decoupled item")
                        `uvm_info("MON", {$sformatf("Done item received and stored in queue. Queue size: %0d", monitor_queue.size()), decoupled_item_clone.convert2str(),decoupled_item_clone.getoutputs()}, UVM_HIGH)
                        mon_port.write(decoupled_item_clone);
                    end
                end
            end:monitoring
        endtask:run_phase
    endclass:flp_monitor
endpackage: flp_monitor_pkg