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

        // A random IEEE corner value: signed zeros, infinities, quiet and
        // signaling NaNs, subnormals, extreme normals, small integers
        function logic [FINAL_FLP_WIDTH-1:0] corner_value();
            logic s;
            s = $urandom_range(0, 1);
            case($urandom_range(0, 9))
                0: return {s, 31'h0};                                   // +-0
                1: return {s, 8'hFF, 23'h0};                            // +-inf
                2: return {s, 8'hFF, 1'b1, 22'($urandom)};              // quiet NaN
                3: return {s, 8'hFF, 1'b0, 22'($urandom | 1)};          // signaling NaN
                4: return {s, 8'h00, 23'($urandom | 1)};                // subnormal
                5: return {s, 8'h01, 23'($urandom)};                    // smallest normals
                6: return {s, 8'hFE, 23'($urandom)};                    // largest normals
                7: return {s, 8'd127 + 8'($urandom_range(0, 30)), 23'h0}; // small powers of two
                8: return {s, 8'd150, 23'($urandom_range(0, 7))};       // integers near 2^23
                default: return {s, 8'($urandom_range(100, 160)), 23'($urandom)};
            endcase
        endfunction:corner_value

        //Overriding the body task
        virtual task body();

            int unsigned items = 1_000_000;
            void'($value$plusargs("FLP_ITEMS=%d", items));   // shorter runs for debugging
            item = flp_item::type_id::create("item");
            repeat(items)
            begin: main_sequence
                start_item(item);
                    assert(item.randomize());
                    // Uniform random bits rarely hit the IEEE corner cases, so a
                    // share of the operands is drawn from them on purpose.
                    if($urandom_range(0, 99) < 30) item.InA = corner_value();
                    if($urandom_range(0, 99) < 30) item.InB = corner_value();
                    if($urandom_range(0, 99) < 10) item.InB = item.InA ^ $urandom_range(0, 3);   // near-equal
                    // Binade edge (D33): a power of two minus/plus a much smaller
                    // operand (exponent gap 20..30). An effective subtraction then
                    // renormalises one bit left, so the aligned guard/round bits decide
                    // the rounding.
                    if($urandom_range(0, 99) < 5)
                    begin
                        int unsigned e = $urandom_range(40, 220);
                        item.InA = {1'($urandom), 8'(e), 23'h0};
                        item.InB = {1'($urandom), 8'(e - $urandom_range(20, 30)), 23'($urandom)};
                        if($urandom_range(0, 1)) {item.InA, item.InB} = {item.InB, item.InA};
                    end
                    `uvm_info("SEQ",item.convert2str(),UVM_DEBUG)
                finish_item(item);
            end: main_sequence

        endtask: body
        
    endclass: flp_seq

endpackage: flp_seq_pkg