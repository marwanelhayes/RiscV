package csr_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_item_pkg::*;

    class csr_seq extends uvm_sequence #(csr_item);

        `uvm_object_utils(csr_seq)

        function new (string name = "csr_seq");
            super.new(name);
        endfunction: new

        csr_item item;

        virtual task body();

            item = csr_item::type_id::create("item");
            repeat(10000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: csr_seq

endpackage: csr_seq_pkg
