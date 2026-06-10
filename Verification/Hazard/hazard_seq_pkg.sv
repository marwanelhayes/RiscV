package hazard_seq_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import hazard_item_pkg::*;

    class hazard_seq extends uvm_sequence #(hazard_item);

        //Register the class to the factory
        `uvm_object_utils(hazard_seq)

        //Overriding the constructor with the child class
        function new (string name = "hazard_seq");
            super.new(name);
        endfunction: new

        hazard_item item;

        //Overriding the body task
        virtual task body();

            item = hazard_item::type_id::create("item");
            repeat(10000)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: hazard_seq

    // ── Directed forwarding sequence ─────────────────────────────────────────
    // Biases all source/destination registers into a tiny shared set so that
    // RdW/RdM frequently match Rs1E/Rs2E. Randomising RegWrite*/MoveOperation/
    // FPURegWrite* then drives every ForwardAE x ForwardBE combination (WB/MEM,
    // integer/FPU) which the uniform-random sequence hits only rarely.
    class hazard_directed_seq extends uvm_sequence #(hazard_item);

        `uvm_object_utils(hazard_directed_seq)

        function new (string name = "hazard_directed_seq");
            super.new(name);
        endfunction: new

        hazard_item item;

        virtual task body();
            item = hazard_item::type_id::create("item");
            repeat(20000)
            begin: directed_sequence
                start_item(item);
                    assert(item.randomize() with {
                        Rs1E  inside {ra, sp, gp};
                        Rs2E  inside {ra, sp, gp};
                        RdM   inside {ra, sp, gp};
                        RdW   inside {ra, sp, gp};
                        Rs1FE inside {f1, f2, f3};
                        Rs2FE inside {f1, f2, f3};
                        RdFM  inside {f1, f2, f3};
                        RdFW  inside {f1, f2, f3};
                    });
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: directed_sequence
        endtask: body

    endclass: hazard_directed_seq

endpackage: hazard_seq_pkg