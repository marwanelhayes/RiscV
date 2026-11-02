// =============================================================================
// alu_decoder.sv
// -----------------------------------------------------------------------------
// ALU operation decoder for RISC-V processor.
//
// Responsibilities:
//   - Decode funct3 and funct7 fields to generate ALU operation
//   - Handle base ISA operations (ADD, SUB, shifts, logical, compare)
//   - Handle M extension (multiply/divide operations)
// =============================================================================
import shared_pkg::*;

module alu_decoder
#(
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int DATA_WIDTH = 32           // XLEN: decides the legal shift amounts
)
(
    // ─── Instruction fields ───────────────────────────────────────────────────
    input [2:0] funct3,                     // Function field 3
    input [6:0] funct7,                      // Function field 7 (imm[11:5] for I-type)
    input [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl,  // Sub-operation code from opcode decoder
    input WordOp,                            // RV64 OP-IMM-32 / OP-32 instruction

    // ─── Output ───────────────────────────────────────────────────────────────
    output alu_operation_t ALUControlD,     // Detailed ALU operation
    output logic Illegal                    // Reserved funct3/funct7 encoding
);

    localparam bit IS_RV64 = (DATA_WIDTH == 64);

    // ─── Internal wires ───────────────────────────────────────────────────────
    logic Unsign;                            // Unsigned operation flag
    logic [6:0] ShiftFunct7;                 // imm[11:5] without shamt[5] on RV64

    // ─── Unsigned operation detection ────────────────────────────────────────
    always_comb
    begin
        Unsign = funct3[2] & funct3[1];     // funct3[2:1] = 2'b11 indicates unsigned
        // On RV64, imm[5] (= funct7[0]) of SLLI/SRLI/SRAI is shamt[5]
        ShiftFunct7 = (IS_RV64 && !WordOp) ? {funct7[6:1], 1'b0} : funct7;
    end

    // ─── ALU operation decoding ───────────────────────────────────────────────
    always_comb
    begin
        ALUControlD = ADD;    // Default operation
        Illegal = 1'b0;
        case(ALUControl)
            // ── Branch-type operations ───────────────────────────────────────
            2'b00: begin
                        if(Unsign)
                            ALUControlD = SLTU;    // BLTU
                        else
                            ALUControlD = SUB;    // BGE, BGT
                    end
            // ── Immediate-type operations ───────────────────────────────────
            2'b01: begin
                        case(funct3)
                            3'b000: ALUControlD = ADD;     // ADDI / ADDIW
                            3'b001: begin                  // SLLI / SLLIW
                                        ALUControlD = SLL;
                                        Illegal = (ShiftFunct7 != 7'b000_0000);
                                    end
                            3'b101: begin                  // SRLI / SRAI (+W)
                                        if(ShiftFunct7 == 7'b000_0000)
                                            ALUControlD = SRL;
                                        else if(ShiftFunct7 == 7'b010_0000)
                                            ALUControlD = SRA;
                                        else
                                            Illegal = 1'b1;
                                    end
                            3'b010: ALUControlD = SLT;     // SLTI
                            3'b011: ALUControlD = SLTU;    // SLTIU
                            3'b100: ALUControlD = XOR;     // XORI
                            3'b110: ALUControlD = OR;      // ORI
                            3'b111: ALUControlD = AND;     // ANDI
                        endcase
                        // OP-IMM-32 only has ADDIW, SLLIW, SRLIW, SRAIW
                        if(WordOp && (funct3 != 3'b000) && (funct3 != 3'b001) && (funct3 != 3'b101))
                            Illegal = 1'b1;
                    end
            // ── R-type operations ────────────────────────────────────────────
            2'b10: begin
                        // Standard RV32I operations
                        if(funct7 == 7'b000_0000)
                        begin
                            case(funct3)
                                3'b000: ALUControlD = ADD;     // ADD / ADDW
                                3'b001: ALUControlD = SLL;     // SLL / SLLW
                                3'b010: ALUControlD = SLT;     // SLT
                                3'b011: ALUControlD = SLTU;    // SLTU
                                3'b100: ALUControlD = XOR;     // XOR
                                3'b101: ALUControlD = SRL;     // SRL / SRLW
                                3'b110: ALUControlD = OR;      // OR
                                3'b111: ALUControlD = AND;     // AND
                            endcase
                            if(WordOp && (funct3 != 3'b000) && (funct3 != 3'b001) && (funct3 != 3'b101))
                                Illegal = 1'b1;
                        end
                        // funct7 = 0100000: SUB, SRA (and SUBW, SRAW)
                        else if(funct7 == 7'b010_0000)
                        begin
                            case(funct3)
                                3'b000: ALUControlD = SUB;     // SUB
                                3'b101: ALUControlD = SRA;     // SRA
                                default: Illegal = 1'b1;
                            endcase
                        end
                        // M extension (multiply/divide)
                        else if(funct7 == 7'b000_0001)
                        begin
                            case(funct3)
                                3'b000: ALUControlD = MUL;     // MUL / MULW
                                3'b001: ALUControlD = MULH;    // MULH
                                3'b010: ALUControlD = MULHSU;  // MULHSU
                                3'b011: ALUControlD = MULHU;   // MULHU
                                3'b100: ALUControlD = DIV;     // DIV / DIVW
                                3'b101: ALUControlD = DIVU;    // DIVU / DIVUW
                                3'b110: ALUControlD = REM;     // REM / REMW
                                3'b111: ALUControlD = REMU;    // REMU / REMUW
                            endcase
                            // OP-32 has no MULH* forms
                            if(WordOp && (funct3 inside {3'b001, 3'b010, 3'b011}))
                                Illegal = 1'b1;
                        end
                        else
                        begin
                            Illegal = 1'b1;
                        end
                    end
            default: ALUControlD = ADD;
        endcase
    end
endmodule
