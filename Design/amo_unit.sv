// =============================================================================
// amo_unit.sv
// -----------------------------------------------------------------------------
// Combinational read-modify-write ALU of the A extension (Zaamo).
//
// Responsibilities:
//   - Compute the value an AMO* writes back to memory from the old memory
//     value and rs2: SWAP, ADD, XOR, AND, OR, MIN, MAX, MINU, MAXU
//   - .W on RV64: both operands are taken as sign-extended 32-bit values, so
//     the signed and unsigned compares order the 32-bit values correctly and
//     the low 32 bits of the result are the stored word
// =============================================================================
import shared_pkg::*;

module amo_unit
#(
    parameter int DATA_WIDTH = 32       // XLEN, passed down from memory_stage
)
(
    // ── Operation ───────────────────────────────────────────────────────────────
    input  amo_op_t               AmoOp,     // AMO* operation (funct5)
    input  logic                  IsWord,    // .W (32-bit) access

    // ── Operands ────────────────────────────────────────────────────────────────
    input  logic [DATA_WIDTH-1:0] OldData,   // Memory value (sign-extended for .W)
    input  logic [DATA_WIDTH-1:0] SrcData,   // rs2

    // ── Result ──────────────────────────────────────────────────────────────────
    output logic [DATA_WIDTH-1:0] NewData    // Value written to memory
);

    // ─── Internal wires – conditioned operands ─────────────────────────────────
    logic [DATA_WIDTH-1:0] A, B;

    always_comb
    begin
        A = OldData;
        B = SrcData;
        NewData = B;  // Default to SWAP (or if AmoOp is invalid)
        if(IsWord)
            B = DATA_WIDTH'(signed'(SrcData[31:0]));  // Sign-extend rs2 for .W
        case(AmoOp)
            AMO_ADD:  NewData = A + B;
            AMO_XOR:  NewData = A ^ B;
            AMO_AND:  NewData = A & B;
            AMO_OR:   NewData = A | B;
            AMO_MIN:  NewData = ($signed(A) < $signed(B)) ? A : B;
            AMO_MAX:  NewData = ($signed(A) > $signed(B)) ? A : B;
            AMO_MINU: NewData = (A < B) ? A : B;
            AMO_MAXU: NewData = (A > B) ? A : B;
            default:  NewData = B;                  // AMO_SWAP
        endcase
    end

endmodule
