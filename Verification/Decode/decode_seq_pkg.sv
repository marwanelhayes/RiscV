package decode_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_item_pkg::*;

    class decode_seq extends uvm_sequence #(decode_item);

        //Register the class to the factory
        `uvm_object_utils(decode_seq)

        //Overriding the constructor with the child class
        function new (string name = "decode_seq");
            super.new(name);
        endfunction: new

        decode_item item;

        //Overriding the body task
        virtual task body();

            item = decode_item::type_id::create("item");
            repeat(100000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: decode_seq

endpackage: decode_seq_pkg