package flp_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import flp_item_pkg::*;

    class flp_seq extends uvm_sequence #(flp_item);

        //Register the class to the factory
        `uvm_object_utils(flp_seq)

        //Overriding the constructor with the child class
        function new (string name = "flp_seq");
            super.new(name);
        endfunction: new

        flp_item item;

        //Overriding the body task
        virtual task body();

            item = flp_item::type_id::create("item");
            repeat(1_000_000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: flp_seq

endpackage: flp_seq_pkg