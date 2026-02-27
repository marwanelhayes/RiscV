package execute_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_seq #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_sequence #(execute_item #(DATA_WIDTH,ADDR_WIDTH));

        //Register the class to the factory
        `uvm_object_param_utils(execute_seq #(DATA_WIDTH,ADDR_WIDTH))

        //Overriding the constructor with the child class
        function new (string name = "execute_seq");
            super.new(name);
        endfunction: new

        execute_item #(DATA_WIDTH,ADDR_WIDTH) item;

        //Overriding the body task
        virtual task body();

            item = execute_item #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("item");
            repeat(10000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: execute_seq

endpackage: execute_seq_pkg