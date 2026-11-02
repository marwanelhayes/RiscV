// =============================================================================
// opcode_decoder.sv
// -----------------------------------------------------------------------------
// Opcode decoder for RISC-V processor.
//
// Responsibilities:
//   - Decode opcode field to generate control signals
//   - Identify instruction type (R, I, S, B, U, J)
//   - Generate ALU sub-operation code
//   - Handle special instructions (CSR, FPU, jumps, branches)
// =============================================================================
import shared_pkg::*;

module opcode_decoder 
#(
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int DATA_WIDTH = 32           // XLEN: RV64-only opcodes are illegal at 32
)
(
    // ─── Instruction input ───────────────────────────────────────────────────
    input opcode_t opcode,           // Opcode field
    input [2:0] funct3,              // Function field 3 (size / variant)
    input csr_t CsrOperation,        // CSR operation type

    // ─── Control signal outputs ───────────────────────────────────────────────
    output logic [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl,  // ALU operation
    output logic Jump,              // Jump instruction flag
    output logic Jalr,              // Jump target comes from rs1 (JALR)
    output logic Branch,            // Branch instruction flag
    output logic Immediate,         // I-type immediate present flag
    output logic Upper,             // U-type immediate present flag (LUI/AUIPC)
    output logic Auipc,             // Operand A is the PC (AUIPC)
    output logic MemWrite,          // Memory write enable
    output logic MemRead,           // Memory read enable (loads)
    output selector_t Selector,     // Write-back data select
    output logic ALUSrc,            // ALU operand B select
    output logic CsrAccess,         // CSR access enable
    output logic RegWrite,          // Register write enable
    output logic Store,             // Store instruction flag
    output logic WordOp,            // RV64 32-bit operation (OP-IMM-32 / OP-32)
    output logic MMode,             // Machine mode flag
    output logic IllegaleInstruction,  // Illegal instruction flag
    output logic FPU                // FPU instruction flag
);

    localparam bit IS_RV64 = (DATA_WIDTH == 64);

    // ─── Main opcode decoding logic ──────────────────────────────────────────
    always_comb
    begin
        // Default values (NOP-like state)
        ALUControl = 2'b11;    // Default to ADD operation
        Jump = 1'b0;
        Jalr = 1'b0;
        Branch = 1'b0;
        Immediate = 1'b0;
        Upper = 1'b0;
        Auipc = 1'b0;
        MemWrite = 1'b0;
        MemRead = 1'b0;
        Selector = ALUToReg;
        ALUSrc = 1'b0;
        RegWrite = 1'b0;
        Store = 1'b0;
        WordOp = 1'b0;
        CsrAccess = 1'b0;
        MMode = 1'b0;
        FPU = 1'b0;
        IllegaleInstruction = 1'b1;    // Assume illegal until proven valid

        case(opcode)
            // ── R-type: Register-register operations ─────────────────────────
            R_TYPE: 
            begin
                ALUControl = 2'b10;
                RegWrite = 1'b1;
                Selector = ALUToReg;
                IllegaleInstruction = 1'b0;    // funct7 checked by the ALU decoder
            end
            // ── Load: Load from memory ────────────────────────────────────────
            LOAD: 
            begin
                Selector = MemToReg;
                Immediate = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                MemRead = 1'b1;
                case(load_store_t'(funct3))
                    B, HW, W, BU, HWU:  IllegaleInstruction = 1'b0;
                    D, WU:              IllegaleInstruction = !IS_RV64;
                    default:            IllegaleInstruction = 1'b1;
                endcase
            end
            // ── S-type: Store to memory ───────────────────────────────────────
            S_TYPE: 
            begin
                MemWrite = 1'b1;
                ALUSrc = 1'b1;
                Store = 1'b1;
                case(load_store_t'(funct3))
                    B, HW, W:   IllegaleInstruction = 1'b0;
                    D:          IllegaleInstruction = !IS_RV64;
                    default:    IllegaleInstruction = 1'b1;
                endcase
            end
            // ── B-type: Branch operations ─────────────────────────────────────
            B_TYPE: 
            begin
                ALUControl = 2'b00;
                Branch = 1'b1;
                IllegaleInstruction = (funct3 == 3'b010) || (funct3 == 3'b011);
            end
            // ── I-type: Immediate operations ──────────────────────────────────
            I_TYPE: 
            begin
                ALUControl = 2'b01;
                Immediate = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                IllegaleInstruction = 1'b0;    // Shift encodings checked by the ALU decoder
            end
            // ── OP-IMM-32: RV64 word immediate operations ─────────────────────
            OP_IMM_32: 
            begin
                ALUControl = 2'b01;
                Immediate = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                WordOp = 1'b1;
                IllegaleInstruction = !IS_RV64;
            end
            // ── OP-32: RV64 word register operations ──────────────────────────
            OP_32: 
            begin
                ALUControl = 2'b10;
                RegWrite = 1'b1;
                WordOp = 1'b1;
                IllegaleInstruction = !IS_RV64;
            end
            // ── LUI / AUIPC: Upper immediate ──────────────────────────────────
            LUI: 
            begin
                Upper = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                IllegaleInstruction = 1'b0;
            end
            AUIPC: 
            begin
                Upper = 1'b1;
                Auipc = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                IllegaleInstruction = 1'b0;
            end
            // ── JAL: Jump and Link ────────────────────────────────────────────
            JAL: 
            begin
                Jump = 1'b1;
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                Selector = PCToReg;
                IllegaleInstruction = 1'b0;
            end
            // ── JALR: Jump and Link Register ──────────────────────────────────
            JALR: 
            begin
                Jump = 1'b1;
                Jalr = 1'b1;
                ALUSrc = 1'b1;
                Immediate = 1'b1;
                RegWrite = 1'b1;
                Selector = PCToReg;
                IllegaleInstruction = (funct3 != 3'b000);
            end
            // ── MISC-MEM: FENCE is a NOP on a single in-order hart ────────────
            MISC_MEM: 
            begin
                IllegaleInstruction = (funct3 != 3'b000);    // FENCE.I needs Zifencei
            end
            // ── CSR: Control and Status Registers ─────────────────────────────
            CSR: 
            begin
                if(CsrOperation == system) 
                begin
                    MMode = 1'b1;    // ECALL, EBREAK, MRET, WFI (checked in decode)
                    IllegaleInstruction = 1'b0;
                end
                else if(funct3 != 3'b100)
                begin
                    CsrAccess = 1'b1;
                    RegWrite = 1'b1;
                    Selector = CSRToReg;
                    IllegaleInstruction = 1'b0;
                end
            end
            // ── Floating-Point operations ──────────────────────────────────────
            FLOATING_PT:
            begin
                IllegaleInstruction = 1'b0;    // Encoding checked by the FPU decoder
                FPU = 1'b1;
            end
        endcase
    end
endmodule
