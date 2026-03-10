package mem_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_seq extends uvm_sequence #(mem_item);

        //Register the class to the factory
        `uvm_object_utils(mem_seq)

        //Overriding the constructor with the child class
        function new (string name = "mem_seq");
            super.new(name);
        endfunction: new

        mem_item item;

        //Overriding the body task
        virtual task body();

            item = mem_item::type_id::create("item");
            repeat(10000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: mem_seq

endpackage: mem_seq_pkg