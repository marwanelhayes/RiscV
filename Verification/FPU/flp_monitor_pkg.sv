// =============================================================================
// flp_monitor_pkg.sv
// -----------------------------------------------------------------------------
// FPU monitor: pairs each operation with its result.
//
// The FPU is multi-cycle, so the operands (valid) and the result (rising edge
// of done) are seen in different cycles. Operands are queued when valid is
// seen; the oldest queued operation gets the outputs on each done edge and is
// published. A reset item is published at once and clears the queue.
//
// Port, sampling item and vif come from tb_base_pkg::base_monitor; run_phase
// is replaced by the decoupled valid/done pairing above.
// =============================================================================
package flp_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_item_pkg::*;

    // =========================================================================
    // flp_monitor: publish one item per completed FPU operation
    // =========================================================================
    class flp_monitor extends base_monitor #(flp_item, virtual flp_interface);

        `uvm_component_utils(flp_monitor)

        function new (string name = "flp_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_item decoupled_item, decoupled_item_clone;
        flp_item monitor_queue[$];
        bit done_prev;      // done is held high while the consumer stalls (hold)

        virtual task run_phase (uvm_phase phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                if(vif.checkifrst(mon_item))
                begin
                    if(!$cast(cloned_item, mon_item.clone()))
                        `uvm_fatal(get_type_name(),"Failed to clone the monitor item")
                    monitor_queue.delete();
                    done_prev = 0;
                    mon_port.write(cloned_item);
                end
                else
                begin
                    if(vif.checkifvalid(mon_item))
                    begin
                        if(!$cast(cloned_item, mon_item.clone()))
                            `uvm_fatal(get_type_name(),"Failed to clone the monitor item")
                        monitor_queue.push_back(cloned_item);
                        `uvm_info(get_type_name(), {$sformatf("Valid item received and stored in queue. Queue size: %0d", monitor_queue.size()), cloned_item.convert2str()}, UVM_HIGH)
                    end
                    // One completion per operation: the rising edge of done
                    if(vif.checkifdone(mon_item) && !done_prev)
                    begin
                        if(monitor_queue.size() == 0)
                            `uvm_fatal(get_type_name(),"Monitor queue is empty when a done item is received - possible missing valid item - Major Design Flaw")
                        decoupled_item = monitor_queue.pop_front();
                        decoupled_item.copy_outputs(mon_item);
                        if(!$cast(decoupled_item_clone, decoupled_item.clone()))
                            `uvm_fatal(get_type_name(),"Failed to clone the decoupled item")
                        `uvm_info(get_type_name(), {$sformatf("Done item received and stored in queue. Queue size: %0d", monitor_queue.size()), decoupled_item_clone.convert2str(),decoupled_item_clone.getoutputs()}, UVM_HIGH)
                        mon_port.write(decoupled_item_clone);
                    end
                    done_prev = vif.checkifdone(mon_item);
                end
            end:monitoring
        endtask:run_phase
    endclass:flp_monitor
endpackage:flp_monitor_pkg
