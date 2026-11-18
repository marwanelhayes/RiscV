// =============================================================================
// non_restoring_divider.sv
// -----------------------------------------------------------------------------
// Iterative non-restoring divider for the integer DIV/DIVU/REM/REMU (+W) ops.
//
// Responsibilities:
//   - Latch the operands on start (when idle), as magnitudes for a signed op
//   - Retire two quotient bits per cycle: WIDTH/2 busy cycles, then done
//   - Restore the remainder and apply the result signs on the outputs
//   - Keep done and the result while hold is high (the consumer is stalled)
//
// Divide by zero (quotient all ones, remainder = dividend) and signed
// overflow (quotient = dividend, remainder 0) fall out of the iteration.
// =============================================================================
module non_restoring_divider
#(
    parameter int WIDTH = 32
)
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input  logic clk,
    input  logic rst,

    // ─── Handshake ────────────────────────────────────────────────────────────
    input  logic start,                    // Divide waiting in EX (taken when idle)
    input  logic hold,                     // Consumer stalled: keep done and the result
    output logic done,                     // Result valid until the consumer advances

    // ─── Operands ─────────────────────────────────────────────────────────────
    input  logic sign,                     // Signed division
    input  logic [WIDTH-1:0] dividend,
    input  logic [WIDTH-1:0] divisor,

    // ─── Results ──────────────────────────────────────────────────────────────
    output logic [WIDTH-1:0] quotient,
    output logic [WIDTH-1:0] remainder
);

    localparam int STEPS = WIDTH / 2;      // Cycles of two quotient bits each

    // ─── Internal registers – iteration state ─────────────────────────────────
    logic signed [WIDTH:0] A;              // Partial remainder
    logic [WIDTH-1:0] Q;                   // Dividend bits, then quotient bits
    logic [WIDTH-1:0] M;                   // Divisor magnitude
    logic [$clog2(STEPS+1)-1:0] Count;     // Busy cycles left
    logic busy;
    logic NegQ, NegR;                      // Negate quotient / remainder

    // ─── Internal wires ───────────────────────────────────────────────────────
    logic signed [WIDTH:0] ANext, R;
    logic [WIDTH-1:0] QNext;

    // Two non-restoring steps
    always_comb
    begin
        ANext = A;
        QNext = Q;
        for(int i = 0; i < 2; i++)
        begin
            if(ANext[WIDTH])
                ANext = {ANext[WIDTH-1:0], QNext[WIDTH-1]} + {1'b0, M};
            else
                ANext = {ANext[WIDTH-1:0], QNext[WIDTH-1]} - {1'b0, M};
            QNext = {QNext[WIDTH-2:0], ~ANext[WIDTH]};
        end
    end

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            A <= '0;
            Q <= '0;
            M <= '0;
            Count <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            NegQ <= 1'b0;
            NegR <= 1'b0;
        end
        else if(busy)
        begin
            A <= ANext;
            Q <= QNext;
            Count <= Count - 1'b1;
            if(Count == 1)
            begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
        else if(done)
        begin
            if(!hold)
                done <= 1'b0;              // Result consumed
        end
        else if(start)
        begin
            A <= '0;
            Q <= (sign && dividend[WIDTH-1]) ? -dividend : dividend;
            M <= (sign && divisor[WIDTH-1]) ? -divisor : divisor;
            NegQ <= sign && (dividend[WIDTH-1] ^ divisor[WIDTH-1]) && (divisor != '0);
            NegR <= sign && dividend[WIDTH-1];
            Count <= STEPS;
            busy <= 1'b1;
        end
    end

    // ─── Results ──────────────────────────────────────────────────────────────
    always_comb
    begin
        R = A[WIDTH] ? (A + {1'b0, M}) : A;   // Final restoration
        quotient = NegQ ? -Q : Q;
        remainder = NegR ? -R[WIDTH-1:0] : R[WIDTH-1:0];
    end

endmodule
