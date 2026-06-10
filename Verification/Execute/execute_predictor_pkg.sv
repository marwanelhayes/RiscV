// =============================================================================
// execute_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Execute stage.
//
// DUT decoupling:
//   - *M outputs (ALUOutM, WriteDataM, RdM, RegWriteM, SelectorM, MemWriteM,
//     funct3M, PCPlus4M) are registered in the EX/MEM pipeline register -
//     shadow them and use emit-before-update so the expected transaction
//     lines up with the registered DUT outputs the monitor sampled this
//     cycle.
//   - PCSrcE is combinational (always_comb on BranchE, JumpE, and the ALU
//     branch_true derived from SrcA / SrcB) - emit from the current cycle's
//     forwarded operands. PCSrcE has no shadow.
//   - Asynchronous active-low rst forces *M to reset defaults immediately,
//     so when t.rst == 0 the shadow is flushed and reset defaults are
//     emitted in the SAME cycle.
//
// Forwarding sources:
//   The EX-stage forwarding muxes consume ALUOutM and FPUOutM which are the
//   REGISTERED outputs the monitor sampled this cycle (t.ALUOutM /
//   t.FPUOutM). Reading them straight off t keeps the forwarding compute in
//   lockstep with the DUT - no extra "past" register is needed because the
//   pipeline register itself is the cycle-delay.
// =============================================================================
package execute_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_predictor extends uvm_subscriber #(execute_item);

        `uvm_component_utils(execute_predictor)

        function new (string name = "execute_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(execute_item) exp_port;
        // MCOW (Manual Copy On Write): persistent expected item reused every
        // cycle, plus a published clone and a scratch next-state item.
        execute_item exp, exp_clone, shadow_inputs;

        localparam int LOG_WIDTH = $clog2(FINAL_DATA_WIDTH);

        // ── EX/MEM pipeline-register shadows ─────────────────────────────────
        logic signed [FINAL_DATA_WIDTH-1:0] q_ALUOutM;
        logic signed [FINAL_DATA_WIDTH-1:0] q_WriteDataM;
        gpr_t                               q_RdM;
        logic                               q_RegWriteM;
        logic [FINAL_ADDR_WIDTH-1:0]        q_PCPlus4M;
        selector_t                          q_SelectorM;
        logic [2:0]                         q_funct3M;
        logic                               q_MemWriteM;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port  = new("exp_port",this);
            exp       = execute_item::type_id::create("exp");
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
        endtask:reset_phase

        function void reset_shadow();
            q_ALUOutM    = '0;
            q_WriteDataM = '0;
            q_RdM        = zero;
            q_RegWriteM  = 1'b0;
            q_PCPlus4M   = '0;
            q_SelectorM  = ALUToReg;
            q_funct3M    = '0;
            q_MemWriteM  = 1'b0;
        endfunction:reset_shadow

        // ── Forwarding mux helpers ───────────────────────────────────────────
        // M1 / M2 in the DUT - selects between RD*E, ResultW, ALUOutM (reg
        // out feeding back), FPUOutW, FPUOutM. ALUOutM / FPUOutM read off t
        // because the DUT's same-cycle forwarding sees the registered values
        // the monitor sampled.
        function automatic logic signed [FINAL_DATA_WIDTH-1:0] forward_a(execute_item t);
            case(t.ForwardAE)
                3'b000:  forward_a = t.RD1E;
                3'b001:  forward_a = t.ResultW;
                3'b010:  forward_a = t.ALUOutM;
                3'b011:  forward_a = t.FPUOutW;
                3'b100:  forward_a = t.FPUOutM;
                default: forward_a = '0;
            endcase
        endfunction:forward_a

        function automatic logic signed [FINAL_DATA_WIDTH-1:0] forward_b(execute_item t);
            case(t.ForwardBE)
                3'b000:  forward_b = t.RD2E;
                3'b001:  forward_b = t.ResultW;
                3'b010:  forward_b = t.ALUOutM;
                3'b011:  forward_b = t.FPUOutW;
                3'b100:  forward_b = t.FPUOutM;
                default: forward_b = '0;
            endcase
        endfunction:forward_b

        // ── ALU (matches risc_alu opcode table) ──────────────────────────────
        function automatic logic signed [FINAL_DATA_WIDTH-1:0] alu_compute(
            input alu_operation_t                 op,
            input logic signed [FINAL_DATA_WIDTH-1:0] SrcA,
            input logic signed [FINAL_DATA_WIDTH-1:0] SrcB
        );
            logic signed [2*FINAL_DATA_WIDTH-1:0] mul_out;
            logic signed [FINAL_DATA_WIDTH-1:0]   div_out, rem_out;
            mul_out = '0; div_out = '0; rem_out = '0;
            case(op)
                MUL:    mul_out = $signed(SrcA) * $signed(SrcB);
                MULH:   mul_out = $signed(SrcA) * $signed(SrcB);
                MULHSU: mul_out = {{FINAL_DATA_WIDTH{SrcA[FINAL_DATA_WIDTH-1]}}, SrcA}* {{FINAL_DATA_WIDTH{1'b0}}, SrcB};
                MULHU:  mul_out = $unsigned(SrcA) * $unsigned(SrcB);
                DIV: begin
                    if(SrcB == 0)                                                 
                        div_out = -1;
                    else if((SrcA == -(1 << (FINAL_DATA_WIDTH-1))) && (SrcB == -1)) 
                        div_out = SrcA;
                    else                                                          
                        div_out = $signed(SrcA) / $signed(SrcB);
                end
                DIVU: begin
                    if(SrcB == 0) 
                        div_out = -1;
                    else          
                        div_out = $unsigned(SrcA) / $unsigned(SrcB);
                end
                REM: begin
                    if(SrcB == 0)                                                 
                        rem_out = SrcA;
                    else if((SrcA == -(1 << (FINAL_DATA_WIDTH-1))) && (SrcB == -1)) 
                        rem_out = 0;
                    else                                                          
                        rem_out = $signed(SrcA) % $signed(SrcB);
                end
                REMU: begin
                    if(SrcB == 0) 
                        rem_out = SrcA;
                    else          
                        rem_out = $unsigned(SrcA) % $unsigned(SrcB);
                end
            endcase
            case(op)
                ADD:     alu_compute = SrcA + SrcB;
                SUB:     alu_compute = SrcA - SrcB;
                AND:     alu_compute = SrcA & SrcB;
                OR:      alu_compute = SrcA | SrcB;
                XOR:     alu_compute = SrcA ^ SrcB;
                SLT:     alu_compute = $signed(SrcA)   < $signed(SrcB);
                SLTU:    alu_compute = $unsigned(SrcA) < $unsigned(SrcB);
                SLL:     alu_compute = $unsigned(SrcA) << $unsigned(SrcB[LOG_WIDTH-1:0]);
                SRL:     alu_compute = $unsigned(SrcA) >> $unsigned(SrcB[LOG_WIDTH-1:0]);
                SRA:     alu_compute = $signed(SrcA)  >>> $unsigned(SrcB[LOG_WIDTH-1:0]);
                MUL:     alu_compute = mul_out[FINAL_DATA_WIDTH-1:0];
                MULH:    alu_compute = mul_out[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                MULHSU:  alu_compute = $signed(mul_out[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                MULHU:   alu_compute = $unsigned(mul_out[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                DIV:     alu_compute = div_out;
                REM:     alu_compute = rem_out;
                DIVU:    alu_compute = $unsigned(div_out);
                REMU:    alu_compute = rem_out;
                default: alu_compute = '0;
            endcase
        endfunction:alu_compute

        function automatic logic branch_true_fn(
            input logic [2:0]                         f3,
            input logic signed [FINAL_DATA_WIDTH-1:0] SrcA,
            input logic signed [FINAL_DATA_WIDTH-1:0] SrcB
        );
            branch_true_fn = 1'b0;
            case(branch_t'(f3))
                BEQ:  if(SrcA == SrcB)                       branch_true_fn = 1'b1;
                BNE:  if(SrcA != SrcB)                       branch_true_fn = 1'b1;
                BLT:  if($signed(SrcA)   <  $signed(SrcB))   branch_true_fn = 1'b1;
                BGE:  if($signed(SrcA)   >= $signed(SrcB))   branch_true_fn = 1'b1;
                BLTU: if($unsigned(SrcA) <  $unsigned(SrcB)) branch_true_fn = 1'b1;
                BGEU: if($unsigned(SrcA) >= $unsigned(SrcB)) branch_true_fn = 1'b1;
            endcase
        endfunction:branch_true_fn

        // ── Compute next-cycle *M shadow from current EX-stage inputs ────────
        function void compute_next(execute_item t);
            logic signed [FINAL_DATA_WIDTH-1:0] SrcA, SrcB, IntermediateB;
            SrcA          = forward_a(t);
            IntermediateB = forward_b(t);
            q_WriteDataM  = IntermediateB;
            SrcB          = (t.ALUSrcE) ? t.SignImmE : IntermediateB;
            q_ALUOutM     = alu_compute(t.ALUControlE, SrcA, SrcB);
            q_RdM         = t.RdE;
            q_RegWriteM   = t.RegWriteE;
            q_PCPlus4M    = t.PCPlus4E;
            q_SelectorM   = t.SelectorE;
            q_funct3M     = t.funct3E;
            q_MemWriteM   = t.MemWriteE;
        endfunction:compute_next

        function void emit_shadow(execute_item exp);
            exp.ALUOutM    = q_ALUOutM;
            exp.WriteDataM = q_WriteDataM;
            exp.RdM        = q_RdM;
            exp.RegWriteM  = q_RegWriteM;
            exp.PCPlus4M   = q_PCPlus4M;
            exp.SelectorM  = q_SelectorM;
            exp.funct3M    = q_funct3M;
            exp.MemWriteM  = q_MemWriteM;
        endfunction:emit_shadow

        // Combinational PCSrcE - matches the always_comb that drives PCSrcE
        // out of the EX stage same cycle (no register on the path).
        function automatic logic pcsrce_compute(execute_item t);
            logic signed [FINAL_DATA_WIDTH-1:0] SrcA, SrcB, IntermediateB;
            SrcA          = forward_a(t);
            IntermediateB = forward_b(t);
            SrcB          = (t.ALUSrcE) ? t.SignImmE : IntermediateB;
            pcsrce_compute = (t.BranchE & branch_true_fn(t.funct3E, SrcA, SrcB)) | t.JumpE;
        endfunction:pcsrce_compute

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (execute_item t);

            // Async active-low rst clears registered *M immediately.
            if(!t.rst)
            begin
                reset_shadow();
            end
            
            exp.PCSrcE = pcsrce_compute(t);

            // Emit the shadow values DUT registered at the most recent
            // posedge (= current monitored *M outputs).
            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);
            emit_shadow(exp);

            // Clone before publishing so the FIFO never holds the mutating exp.
            if(!$cast(exp_clone, exp))
                `uvm_fatal("EXEC_PRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // Update shadow with this cycle's EX compute - that value will
            // be latched into *M at the next posedge and emitted theq_
            if(t.rst)
            begin
                compute_next(t);
            end

            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal("EXEC_PRED", "Failed to copy inputs to shadow - check for non-cloneable fields")
        endfunction:write

    endclass:execute_predictor

endpackage:execute_predictor_pkg
