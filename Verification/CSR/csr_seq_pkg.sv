// =============================================================================
// csr_seq_pkg.sv
// -----------------------------------------------------------------------------
// CSR file sequences.
//
// csr_seq: 20000 items, random in cycles of directed setup, S/U-resident and free phases.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package csr_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_seq: 20000 CSR file items
    // =========================================================================
    class csr_seq extends base_seq #(csr_item);

        `uvm_object_utils(csr_seq)

        function new (string name = "csr_seq");
            super.new(name);
            num_items = 20000;
        endfunction:new

        // A 80-item cycle: 7 directed items put the core in S or U with random enables
        // (trap to M, mstatus.MPP/MIE/SIE, mie, mideleg, mip, mcounteren, MRET), then 49 "calm"
        // items (mostly no trap-raising input, only CSRs that S and U may access) keep it there so the
        // mode x enable x delegation x wake-source bins of the predictor coverage are crossed;
        // the other 24 items are unconstrained.
        int unsigned count;
        virtual function bit randomize_item ();
            int unsigned phase = count % 80;
            bit to_u = (count++ / 80) % 2;       // odd cycles enter U, even cycles S
            if(phase >= 56)
                return item.randomize();
            if(phase == 0)
                return item.randomize() with { rst == 1; Commit == 1; Traps == EcallMOrMachineExternalInterrupt; };
            if(phase < 7)
            begin
                csr_index_t idx = (phase == 1) ? mstatus : (phase == 2) ? mie : (phase == 3) ? mideleg :
                                  (phase == 4) ? mip : (phase == 5) ? mcounteren : mstatus;
                if(phase == 6)
                    return item.randomize() with { rst == 1; Commit == 1; Traps == NoTraps; mret == 1; };
                return item.randomize() with { rst == 1; Commit == 1; Traps == NoTraps; CsrAccess == 1; raw_csr == 0;
                                               CsrOperation == csrrw; CsrIndex == idx;
                                               (phase == 1) -> CsrIn[12:11] == (to_u ? 2'b00 : 2'b01); };
            end
            if($urandom_range(0, 4) == 0)       // one in five: a trap from S/U (to S or M)
                return item.randomize() with { rst == 1; Traps != NoTraps; };
            if($urandom_range(0, 5) == 0)       // one in six: WFI (the wake source comes from the lines and mie)
                return item.randomize() with { rst == 1; Traps == NoTraps; Wfi == 1; };
            return item.randomize() with {
                rst == 1;
                Traps == NoTraps;
                to_u -> CsrIndex inside {fflags, frm, fcsr, cycle, instret, time_csr, cycleh, instreth, timeh_csr};
                !to_u -> CsrIndex inside {fflags, frm, fcsr, sstatus, sie, stvec, scounteren, sscratch, sepc, scause, stval, sip,
                                          cycle, instret, time_csr, cycleh, instreth, timeh_csr};
            };
        endfunction:randomize_item

    endclass:csr_seq

endpackage:csr_seq_pkg
