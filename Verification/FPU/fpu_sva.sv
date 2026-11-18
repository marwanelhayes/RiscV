// =============================================================================
// fpu_sva.sv
// -----------------------------------------------------------------------------
// risc_fpu handshake timing assertions, bound by module type (flp_top,
// execute_top, risc_top):
//   bind risc_fpu fpu_sva #(.WIDTH(WIDTH)) FpuSva (.*);
// accept -> busy until the unit completes -> done (busy low) the next cycle;
// done and Result hold while hold (= StallE) is high, then done drops; Result
// never changes outside a completion or a release.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module fpu_sva #(parameter int WIDTH = 32) (
    input logic clk, rst,
    input logic hold, busy, done, req_accept, req_complete,
    input logic [WIDTH-1:0] Result
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_accept: assert property (req_accept |=> busy && !done)
        else uvm_report_error("SVA_FPU", "accepted request did not start (busy low or done high)");
    a_accept_cover: cover property (req_accept |=> busy && !done);
    a_busy: assert property (busy && !req_complete |=> busy && !done)
        else uvm_report_error("SVA_FPU", "busy dropped / done rose before the unit completed");
    a_busy_cover: cover property (busy && !req_complete |=> busy && !done);
    a_complete: assert property (req_complete |=> done && !busy)
        else uvm_report_error("SVA_FPU", "completion did not raise done the next cycle");
    a_complete_cover: cover property (req_complete |=> done && !busy);
    a_exclusive: assert property (!(busy && done))
        else uvm_report_error("SVA_FPU", "busy and done both high");
    a_exclusive_cover: cover property (!(busy && done));
    a_hold: assert property (done && hold |=> done && $stable(Result))
        else uvm_report_error("SVA_FPU", "done/Result lost while the consumer is stalled");
    a_hold_cover: cover property (done && hold |=> done && $stable(Result));
    a_release: assert property (done && !hold |=> !done)
        else uvm_report_error("SVA_FPU", "done held after the consumer took the result");
    a_release_cover: cover property (done && !hold |=> !done);
    a_result_stable: assert property (!req_complete && !(done && !hold) |=> $stable(Result))
        else uvm_report_error("SVA_FPU", "Result changed outside a completion/release");
    a_result_stable_cover: cover property (!req_complete && !(done && !hold) |=> $stable(Result));
    a_known: assert property (!$isunknown({busy, done}))
        else uvm_report_error("SVA_FPU", "X on busy/done");
    a_known_cover: cover property (!$isunknown({busy, done}));
endmodule
