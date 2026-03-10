package writeback_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import writeback_item_pkg::*;

    class writeback_seq extends uvm_sequence #(writeback_item);

        //Register the class to the factory
        `uvm_object_utils(writeback_seq)

        //Overriding the constructor with the child class
        function new (string name = "writeback_seq");
            super.new(name);
        endfunction: new

        writeback_item item;

        //Overriding the body task
        virtual task body();

            item = writeback_item::type_id::create("item");
            repeat(10000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: writeback_seq

endpackage: writeback_seq_pkg