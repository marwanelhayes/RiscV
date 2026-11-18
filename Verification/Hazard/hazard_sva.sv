// =============================================================================
// hazard_sva.sv
// -----------------------------------------------------------------------------
// Hazard-unit assertions, bound by module type (hazard_top, risc_top):
//   bind hazard_unit hazard_sva HazardSva (.*);
// The unit is combinational (no clock), so these are deferred final checks.
// Stalls must form a chain (a younger stage never moves while an older one
// waits), and a stage that advances behind a stalled one must get a bubble,
// otherwise an instruction is duplicated.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module hazard_sva (
    input logic StallF, StallD, StallE, StallM, StallW, FlushE, FlushM,
    input logic FPUValidE, FPUDoneE, ICacheHit, DCacheHit
);
    always_comb
        if (!$isunknown({StallF, StallD, StallE, StallM, StallW, FlushE, FlushM, FPUValidE, FPUDoneE, ICacheHit, DCacheHit}))
        begin
            a_chain: assert final (StallF == StallD && (StallE -> StallD) && (StallM -> StallE) && StallW == StallM)
                else uvm_report_error("SVA_HAZARD", "stall chain broken");
            a_bubble_e: assert final ((StallD && !StallE) -> FlushE)
                else uvm_report_error("SVA_HAZARD", "D held while E advances without a bubble in ID/EX");
            a_bubble_m: assert final ((StallE && !StallM) -> FlushM)
                else uvm_report_error("SVA_HAZARD", "E held while M advances without a bubble in EX/MEM");
            a_fpu_wait: assert final ((FPUValidE && !FPUDoneE) -> StallE)
                else uvm_report_error("SVA_HAZARD", "FP instruction left EX before done");
            a_miss_freeze: assert final ((!ICacheHit || !DCacheHit) -> StallW)
                else uvm_report_error("SVA_HAZARD", "cache miss did not freeze the pipeline");

            // Covers: an immediate cover of "a -> b" would count every cycle
            // (it is true whenever a is false), so each one covers a && b,
            // the case where the assertion above actually checked something.
            a_chain_cover:       cover final (StallD && StallE && StallM && StallW);
            a_bubble_e_cover:    cover final (StallD && !StallE && FlushE);
            a_bubble_m_cover:    cover final (StallE && !StallM && FlushM);
            a_fpu_wait_cover:    cover final (FPUValidE && !FPUDoneE && StallE);
            a_miss_freeze_cover: cover final ((!ICacheHit || !DCacheHit) && StallW);
        end
endmodule
