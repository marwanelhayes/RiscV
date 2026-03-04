package execute_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "C:/Ain_shams/RiscV/Design/csr_defs.sv"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_scoreboard #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_scoreboard;

        logic signed [DATA_WIDTH-1:0] ALUOutM;
        logic signed [DATA_WIDTH-1:0] WriteDataM;
        gpr_t RdM;
        logic PCSrcE;
        logic RegWriteM;
        logic [ADDR_WIDTH-1:0] PCPlus4M;
        selector_t SelectorM;
        logic [2:0] funct3M;
        logic [DATA_WIDTH-1:0] CsrOutM;
        logic MemWriteM;
        logic TrapIsSet;
        logic [ADDR_WIDTH-1:0] CsrOutPC;
        logic signed [DATA_WIDTH-1:0] ALUOutE;
        fpr_t RdFM;
        logic OverflowM;
        logic UnderflowM;
        logic NaNM;
        logic InfM;
        logic ZeroM;
        logic InvalidDivM;
        logic [DATA_WIDTH-1:0] FPUOutM;
        logic FPURegWriteM;
        move_operation_t MoveOperationM;

        logic signed [2*DATA_WIDTH-1:0] MulOutput;
        logic signed [DATA_WIDTH-1:0] DivOutput;
        logic signed [DATA_WIDTH-1:0] RemOutput;


        traps_t Traps;

        logic signed [DATA_WIDTH-1:0] IntermediateB , SrcA,SrcB;
        logic [DATA_WIDTH-1:0] SrcBU;

        logic branch_true;
        logic [DATA_WIDTH-1:0] CSRFile [4096];

        logic signed [DATA_WIDTH-1:0] ALUOutM_past;
        logic [DATA_WIDTH-1:0] FPUOutM_past, FPUInA, FPUInB;
        shortreal FPUInA_real, FPUInB_real, FPUOut_real;
        real FPUOut_real_double;
        bit threshold_exceeded;
        int success,fail;
        logic FPUAIsSubnormal, FPUBIsSubnormal;
        logic FPUInAIsNaN, FPUInBIsNaN;
        logic FPUInAIsInf, FPUInBIsInf;
        logic FPUInAIsZero, FPUInBIsZero;
        logic Subnormal;

        localparam int EXP_BITS = (DATA_WIDTH == 32) ? 8 : 11;
        localparam int FRAC_BITS = (DATA_WIDTH == 32) ? 23 : 52;

        //Register the class to the factory
        `uvm_component_param_utils(execute_scoreboard #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "execute_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_item #(DATA_WIDTH,ADDR_WIDTH) sc_item;
        uvm_analysis_imp #(execute_item #(DATA_WIDTH,ADDR_WIDTH) , execute_scoreboard #(DATA_WIDTH,ADDR_WIDTH)) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function automatic logic [3:0] classify_value(
        input logic [EXP_BITS-1:0] exp,
        input logic [FRAC_BITS-1:0] frac
        );
            logic [3:0] classification;
            classification[0] = (exp == 0) && (frac == 0);                              // is_zero
            classification[1] = (exp == {EXP_BITS{1'b1}}) && (frac == 0);              // is_infinity
            classification[2] = (exp == {EXP_BITS{1'b1}}) && (frac != 0);              // is_nan
            classification[3] = (exp == 0) && (frac != 0);                             // is_subnormal
            return classification;
        endfunction: classify_value

        
        function automatic shortreal apply_rounding
        (
            input real val,
            input round_mode_t mode
        );
        case (mode)
            RNE: return shortreal'($rtoi(val + 0.5)); // nearest-even approx
            RTZ: return shortreal'($rtoi(val));       // truncate toward zero
            RDN: return shortreal'($floor(val));      // toward -∞
            RUP: return shortreal'($ceil(val));       // toward +∞
            RMM: begin
                real absval = (val >= 0) ? val : -val;
                int rounded = $rtoi(absval + 0.5);
                return shortreal'((val >= 0) ? rounded : -rounded);
            end
            DYN: return shortreal'(val); // simulator default
            default: return shortreal'(val);
        endcase
        endfunction:apply_rounding

        function automatic int fcvt_float_to_int(
            input real val,
            input round_mode_t mode,
            input logic is_unsigned  // 1 for FCVT.WU.S, 0 for FCVT.W.S
        );
            real floor_val;
            real diff;
            int rounded;
            logic is_nan;

            // 1. Detect NaN (IEEE-754 property: NaN != NaN)
            is_nan = (val != val);

            // 2. Isolate integer floor and fractional difference
            floor_val = $floor(val);
            diff = val - floor_val;
            //$display("Val: %0f, Floor: %0f, Diff: %0f", val, floor_val, diff);

            // 3. Apply exact rounding to a safe 64-bit intermediate
            if (is_nan) 
            begin
                rounded = 0; // Value doesn't matter, handled by clamping
            end 
            else 
            begin
                case (mode)
                    RNE: 
                    begin // Nearest, ties to Even
                        if (diff < 0.5) 
                            rounded = int'(floor_val);
                        else if (diff > 0.5) 
                            rounded = int'(floor_val + 1.0);
                        else 
                        begin
                            rounded = int'(floor_val);
                            if (rounded % 2 != 0) 
                                rounded += 1; 
                        end
                    end
                    RTZ: begin // Towards Zero
                        if (val >= 0.0) 
                            rounded = int'(floor_val);
                        else 
                            rounded = int'($ceil(val));
                    end
                    RDN: rounded = int'(floor_val); // Towards -∞
                    RUP: rounded = int'($ceil(val)); // Towards +∞
                    RMM: begin // Nearest, ties to Max Magnitude
                        if (diff < 0.5) rounded = int'(floor_val);
                        else if (diff > 0.5) rounded = int'(floor_val + 1.0);
                        else begin
                            if (val >= 0.0) rounded = int'(floor_val + 1.0);
                            else rounded = int'(floor_val);
                        end
                    end
                    default: begin  
                        if (diff < 0.5) rounded = int'(floor_val);
                        else if (diff > 0.5) rounded = int'(floor_val + 1.0);
                        else 
                        begin
                            rounded = int'(floor_val);
                            if (rounded % 2 != 0) rounded += 1; 
                        end
                    end
                endcase
            end

            // 4. Apply strict RISC-V boundary clamping
            if (is_unsigned) 
            begin 
                // --- FCVT.WU.S (Unsigned) Limits ---
                if (is_nan) 
                    fcvt_float_to_int = 32'h7FFFFFFF;
                else if (val >= 4294967295.0 || rounded >= 64'h00000000FFFFFFFF) 
                    fcvt_float_to_int =  32'h7FFFFFFF; // Max Positive
                else if (val <= 0.0 || rounded <= 0) 
                    fcvt_float_to_int =  32'h00000000;                             // Negative clamp to 0
                else 
                    fcvt_float_to_int =  rounded;
            end 
            else 
            begin 
                // --- FCVT.W.S (Signed) Limits ---
                if (is_nan) 
                    fcvt_float_to_int =  32'h7FFFFFFF;
                else if (val >= 2147483647.0 || rounded >= 64'sd2147483647) 
                    fcvt_float_to_int =  32'h7FFFFFFF;       // Max Positive
                else if (val <= -2147483648.0 || rounded <= -64'sd2147483648) 
                    fcvt_float_to_int =  32'h80000000;      // Max Negative
                else 
                    fcvt_float_to_int =  rounded;
            end
            $display("Input: %f, Rounded: %d, Output: %h @%0t", val, rounded, fcvt_float_to_int,$time);
        endfunction:fcvt_float_to_int


        function automatic bit compare_with_threshold
        (
            input shortreal a,
            input shortreal b
        );
            shortreal diff;
            shortreal threshold;
            shortreal abs_a;
            shortreal rel_err;

            threshold = 0.05 ; // 5% relative error threshold

            // Absolute difference
            if(a > b)
                diff = a - b;
            else
                diff = b - a;
            if(a >= 0)
                abs_a = a;
            else
                abs_a = -a;
            if(abs_a == 0) 
            begin
                // If reference value is zero, use absolute difference as is
                return (diff > 0.00001);
            end
            else
            begin
                rel_err = shortreal'(diff / abs_a);
                return (rel_err > threshold);
            end
        endfunction

        function void compare_shortreal_rel_error(shortreal a, shortreal b, shortreal tol);
            shortreal diff, denom, rel_err , epsilon;
            diff   = a - b;
            diff   = (diff < 0.0) ? -diff : diff; // abs(diff)
            denom  = (b < 0.0) ? -b : b; // abs(b)
            epsilon = 1e-3;
            //$display("The denominator is %f", denom);
            if((denom <= epsilon) && (denom >= -epsilon))
            begin 
                rel_err = diff;
            end
            else
            begin
                rel_err = diff / denom;
            end
            //$display("Relative error: %f", rel_err);
            if(rel_err > tol) 
            begin
                $display("Values %f and %f differ by relative error %f (tolerance %f) @%t , Operation: %s, FPUInputA = %f, FPUInputB = %f", a, b, rel_err, tol, $time,sc_item.FPUControlE.name(),FPUInA_real,FPUInB_real);
                fail++;
            end 
        endfunction

        function void compare_ints_5_percent(int a, int b);
            int diff;
            int max_val;
            int abs_a, abs_b;
            
            // 1. Get absolute values of a and b
            abs_a = (a < 0) ? -a : a;
            abs_b = (b < 0) ? -b : b;
            
            // 2. Calculate the absolute difference
            diff = (a > b) ? (a - b) : (b - a);
            
            // 3. Find the maximum absolute value to act as our baseline
            max_val = (abs_a > abs_b) ? abs_a : abs_b;
            
            // 4. Compare using integer math (diff * 100 <= max_val * 5)
            // Using 100 and 5 scales the math so we don't need real numbers
            if(!((diff * 100) <= (max_val * 5)))         
            begin
                real rel_err = (max_val == 0) ? 0 : (diff * 1.0 / max_val);
                $display("Values %0d and %0d differ by relative error %f @%0t , Operation: %s,round = %s FPUInputA = %f, FPUInputB = %f", a, b, rel_err, $time,sc_item.FPUControlE.name(),sc_item.RoundModeE.name(),FPUInA_real,FPUInB_real);
                fail++;
            end
        endfunction:compare_ints_5_percent

        function automatic int fclass_s(input shortreal rval);

            // Extract IEEE-754 fields
            int bits = $shortrealtobits(rval);
            bit sign = bits[31];
            int exp  = bits[30:23];
            int frac = bits[22:0];

            // Classification result (bitmask)
            int class_bits = 0;

            if (exp == 8'hFF) 
            begin
                if (frac == 0) 
                begin
                    // Infinity
                    class_bits = sign ? (1 << 0) : (1 << 7);
                end 
                else 
                begin
                    // NaN: signaling vs quiet
                    if (frac[22] == 0)
                        class_bits = (1 << 8); // signaling NaN
                    else
                        class_bits = (1 << 9); // quiet NaN
                end
            end 
            else if (exp == 0) 
            begin
                if (frac == 0) 
                begin
                    // Zero
                    class_bits = sign ? (1 << 3) : (1 << 4);
                end 
                else 
                begin
                    // Subnormal
                    class_bits = sign ? (1 << 2) : (1 << 5);
                end
            end 
            else 
            begin
                // Normal finite number
                class_bits = sign ? (1 << 1) : (1 << 6);
            end

            return class_bits;
        endfunction:fclass_s

        function void CheckForTrap ;
            if(|sc_item.PCPlus4E[1:0])
            begin
                Traps = InstructionAddressMisalignedOrUserSoftwareInterrupt;
            end
            else if(sc_item.EbreakE | sc_item.EcallE | sc_item.IllegaleInstructionE)
            begin
                Traps = IllegalInstructionOrHypervisorSoftwareInterrupt;
            end
            else if(sc_item.SelectorE == MemToReg)
            begin
                if((load_store_t'(sc_item.funct3E) == W) && (|ALUOutE[1:0]))
                begin
                    Traps = LoadAddressMisalignedOrUserSoftwareInterrupt;
                end
                else if(((load_store_t'(sc_item.funct3E) == HW) | (load_store_t'(sc_item.funct3E) == HWU)) && (ALUOutE == 2'b11))
                begin
                    Traps = LoadAddressMisalignedOrUserSoftwareInterrupt;
                end
            end
            else if(sc_item.MemWriteE)
            begin
                if((load_store_t'(sc_item.funct3E) == W) && (|ALUOutE[1:0]))
                begin
                    Traps = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
                end
                else if((ALUOutE == 2'b11) && (load_store_t'(sc_item.funct3E) == HW))
                begin
                    Traps = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
                end
            end
        endfunction:CheckForTrap 

        function void UpdateCsr(input logic [DATA_WIDTH-1:0] X);
            if(sc_item.CsrIndexE == mstatus)
                CSRFile[sc_item.CsrIndexE] <= X & `mstatus_mask;
            else if(sc_item.CsrIndexE == mtvec)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mepc)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mscratch)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mie)
                CSRFile[sc_item.CsrIndexE] <= X & `mie_mask;
            else if(sc_item.CsrIndexE == mip)
                CSRFile[sc_item.CsrIndexE] <= X & `mpie_mask;
            else if(sc_item.CsrIndexE == mcause)
                CSRFile[sc_item.CsrIndexE] <= CSRFile[sc_item.CsrIndexE];
            else if (sc_item.CsrIndexE == fflags)
            begin
                CSRFile[sc_item.CsrIndexE][4:0] <= X;
                CSRFile[fcsr][4:0] <= X;
            end
            else if( sc_item.CsrIndexE == frm)
            begin
                CSRFile[sc_item.CsrIndexE][2:0] <= X;
                CSRFile[fcsr][7:5] <= X;
            end
            else if( sc_item.CsrIndexE == fcsr)
            begin
                CSRFile[sc_item.CsrIndexE][7:0] <= X;
            end
            else if(sc_item.CsrIndexE != misa || sc_item.CsrIndexE != mvendorid)
                CSRFile[sc_item.CsrIndexE] <= X;
        endfunction:UpdateCsr

        function void CSRInterruptOperation ();
            if(
                (sc_item.TimerInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`MT_PIE]) ||
                (sc_item.ExternalInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`ME_PIE]) ||
                (sc_item.SoftwareInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`MS_PIE])
              )
            begin:InterruptHandling
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mepc] = sc_item.PCPlus4E;
                TrapIsSet = 1'b1;
                if(sc_item.TimerInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , StoreAddressFaultOrMachineTimerInterrupt };
                    CsrOutPC = CSRFile[mtvec] + 4 * `MT_PIE;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(sc_item.ExternalInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , EcallMOrMachineExternalInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `ME_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(sc_item.SoftwareInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , BreakpointOrMachineSoftwareInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `MS_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                end
            end:InterruptHandling
        endfunction:CSRInterruptOperation

        function void CSROperation ();
            if
            (
                CSRFile[mstatus][`MIE] && 
                (
                    (CSRFile[mip][`MS_PIE] & CSRFile[mie][`MS_PIE])
                    || (CSRFile[mip][`MT_PIE] & CSRFile[mie][`MT_PIE])
                    || (CSRFile[mip][`ME_PIE] & CSRFile[mie][`ME_PIE])
                )
            )
            begin:InterruptPending
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mepc] = sc_item.PCPlus4E;
                TrapIsSet = 1'b1;
                if(CSRFile[mip][`MT_PIE] & CSRFile[mie][`MT_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , StoreAddressFaultOrMachineTimerInterrupt };
                    CsrOutPC = CSRFile[mtvec] + 4 * `MT_PIE;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(CSRFile[mip][`ME_PIE] & CSRFile[mie][`ME_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , EcallMOrMachineExternalInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `ME_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(CSRFile[mip][`MS_PIE] & CSRFile[mie][`MS_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , BreakpointOrMachineSoftwareInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `MS_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                end
            end:InterruptPending
            else if(|int'(Traps))
            begin:TrapHandling
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CSRFile[mcause] = {20'b0 , Traps};
                CSRFile[mepc] = sc_item.PCPlus4E;
                CsrOutPC = CSRFile[mtvec];
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mbadaddr] = ALUOutE[ADDR_WIDTH-1:0];
                TrapIsSet = 1'b1;
            end:TrapHandling
            else if(sc_item.MRetE)
            begin:ReturnFunction
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CSRFile[mstatus][`MIE] = CSRFile[mstatus][`MPIE];
                CSRFile[mstatus][`MPIE] = 1'b1;
                CsrOutPC = CSRFile[mepc];
                TrapIsSet = 1'b0;
                if(CSRFile[mstatus][`MPIE])
                begin:Delete_Pending
                    if(CSRFile[mcause] == {20'b0, EcallMOrMachineExternalInterrupt})
                    begin
                        CSRFile[mip][`ME_PIE] = 1'b0;
                    end
                    else if(CSRFile[mcause] == {20'b0, BreakpointOrMachineSoftwareInterrupt})
                    begin
                        CSRFile[mip][`MS_PIE] = 1'b0;
                    end
                    else if(CSRFile[mcause] == {20'b0, StoreAddressFaultOrMachineTimerInterrupt})
                    begin
                        CSRFile[mip][`MT_PIE] = 1'b0;
                    end
                end:Delete_Pending
            end:ReturnFunction
            else if(sc_item.CsrAccessE)
            begin:CSR_Access
                TrapIsSet = 1'b0;
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CsrOutM = CSRFile[sc_item.CsrIndexE];
                case(sc_item.CsrOperationE)
                    csrrw: 
                    begin
                        UpdateCsr($signed(sc_item.RD1E));
                    end
                    csrrs: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] | $unsigned(sc_item.RD1E));
                    end
                    csrrc: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] & ~$unsigned(sc_item.RD1E));
                    end
                    csrrwi: 
                    begin
                        UpdateCsr({27'b0, $unsigned(sc_item.RD1E)});
                    end
                    csrrsi: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] | {27'b0, $unsigned(sc_item.Rs1E)});
                    end
                    csrrci: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] & ~{27'b0, $unsigned(sc_item.Rs1E)});
                    end
                endcase
            end:CSR_Access
            else
            begin:Normal
                TrapIsSet = 1'b0;
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
            end:Normal
        endfunction:CSROperation

        function void ref_model ();
            case(sc_item.ALUControlE)
                ADD : ALUOutE = SrcA + SrcB;
                SUB : ALUOutE = SrcA - SrcB;
                AND : ALUOutE = SrcA & SrcB;
                OR : ALUOutE = SrcA | SrcB;
                XOR : ALUOutE = SrcA ^ SrcB;
                SLT : ALUOutE = $signed(SrcA) < $signed(SrcB);
                SLTU : ALUOutE = $unsigned(SrcA) < $unsigned(SrcB);
                SLL : ALUOutE = SrcA << SrcB;
                SRL : ALUOutE = SrcA >> SrcB;
                SRA : ALUOutE = $signed(SrcA) >>> SrcB;
                MUL : ALUOutE = MulOutput[DATA_WIDTH-1:0];
                MULH : ALUOutE = MulOutput[2*DATA_WIDTH-1:DATA_WIDTH];
                MULHSU : ALUOutE = MulOutput[2*DATA_WIDTH-1:DATA_WIDTH];
                MULHU : ALUOutE = $unsigned(MulOutput[2*DATA_WIDTH-1:DATA_WIDTH]);
                DIV : ALUOutE = DivOutput;
                REM : ALUOutE = RemOutput;
                DIVU : ALUOutE = DivOutput;
                REMU : ALUOutE = RemOutput;
                default : ALUOutE = 'b0;
            endcase

            CheckForTrap();

            foreach(CSRFile[i]) 
            begin
                if
                (
                    i != mstatus &&
                    i != misa &&
                    i != medeleg &&
                    i != mideleg &&
                    i != mie &&
                    i != mtvec &&
                    i != mscratch &&
                    i != mepc &&
                    i != mcause &&
                    i != mbadaddr &&
                    i != mip &&
                    i != mcycle &&
                    i != mhartid &&
                    i != mvendorid &&
                    i != fflags &&
                    i != frm &&
                    i != fcsr
                )
                CSRFile[i] = 0;
            end

            if(!sc_item.rst)
            begin
                ALUOutM = 'b0;
                WriteDataM = 'b0;
                RdM = zero;
                PCSrcE = 'b0;
                RegWriteM = 'b0;
                funct3M = 'b0;
                MemWriteM = 'b0;
                branch_true = 1'b0;
                ALUOutM_past = 'b0;
                PCPlus4M = 'b0;
                SelectorM = ALUToReg;
                CsrOutM = 'b0;
                TrapIsSet = 'b0;
                CsrOutPC = 'b0;
                CSRFile[mstatus] = 0;
                CSRFile[misa] = 32'h40_00_01_00;
                CSRFile[medeleg] = 0;
                CSRFile[mideleg] = 0;
                CSRFile[mie] = 0;
                CSRFile[mtvec] = 0;
                CSRFile[mscratch] = 0;
                CSRFile[mepc] = 0;
                CSRFile[mcause] = 0;
                CSRFile[mbadaddr] = 0;
                CSRFile[mip] = 0;
                CSRFile[mcycle] = 0;
                CSRFile[mhartid] = 0;
                CSRFile[mvendorid] = 32'h48_41_4E_4F;
                CSRFile[fflags] = 0;
                CSRFile[frm] = 0;
                CSRFile[fcsr] = 0;
                FPUOutM_past = 'b0;
                RdFM = f0;
                OverflowM = 1'b0;
                UnderflowM = 1'b0;
                NaNM = 1'b0;
                InfM = 1'b0;
                ZeroM = 1'b0;
                InvalidDivM = 1'b0;
                FPUOutM = 'b0;
                FPURegWriteM = 1'b0;
                MoveOperationM = FPUToFPU;
            end
            else
            begin:NotReset
                RdM = sc_item.RdE;
                RegWriteM = sc_item.RegWriteE;
                funct3M = sc_item.funct3E;
                MemWriteM = sc_item.MemWriteE;
                branch_true = 1'b0;
                PCSrcE = 'b0;
                PCPlus4M = sc_item.PCPlus4E;
                SelectorM = sc_item.SelectorE;
                RdFM = sc_item.RdFE;
                FPURegWriteM = sc_item.FPURegWriteE;
                MoveOperationM = sc_item.MoveOperationE;
                OverflowM = 1'b0;
                UnderflowM = 1'b0;
                NaNM = 1'b0;
                InfM = 1'b0;
                ZeroM = 1'b0;
                InvalidDivM = 1'b0;
                //FPUOutM = 'b0;

                CSROperation();

                case(sc_item.ForwardAE)
                    3'b000 : SrcA = sc_item.RD1E;
                    3'b001 : SrcA = sc_item.ResultW;
                    3'b010 : SrcA = ALUOutM_past;
                    3'b011 : SrcA = sc_item.FPUOutW;
                    3'b100 : SrcA = FPUOutM_past;
                    default : SrcA = 'b0;
                endcase

                case(sc_item.ForwardBE)
                    3'b000 : IntermediateB = sc_item.RD2E;
                    3'b001 : IntermediateB = sc_item.ResultW;
                    3'b010 : IntermediateB = ALUOutM_past;
                    3'b011 : IntermediateB = sc_item.FPUOutW;
                    3'b100 : IntermediateB = FPUOutM_past;
                    default : IntermediateB = 'b0;
                endcase

                case (sc_item.ForwardFloatingAE)
                    2'b00 : FPUInA = sc_item.RD1FE;
                    2'b01 : FPUInA = sc_item.FPUOutW;
                    2'b10 : FPUInA = FPUOutM_past;
                    default : FPUInA = 'b0;
                endcase
                
                case (sc_item.ForwardFloatingBE)
                    2'b00 : FPUInB = sc_item.RD2FE;
                    2'b01 : FPUInB = sc_item.FPUOutW;
                    2'b10 : FPUInB = FPUOutM_past;
                    default : FPUInB = 'b0;
                endcase

                FPUInA_real = $bitstoshortreal(FPUInA);
                FPUInB_real = $bitstoshortreal(FPUInB);

                {FPUAIsSubnormal, FPUInAIsNaN, FPUInAIsInf, FPUInAIsZero} = classify_value(FPUInA[30:23], FPUInA[22:0]);
                {FPUBIsSubnormal, FPUInBIsNaN, FPUInBIsInf, FPUInBIsZero} = classify_value(FPUInB[30:23], FPUInB[22:0]);

                case (sc_item.FPUControlE)
                    FADD_S:
                    begin
                        FPUOut_real = FPUInA_real + FPUInB_real;
                        FPUOutM = $shortrealtobits(FPUOut_real);
                        {Subnormal, NaNM, InfM, ZeroM} = classify_value(FPUOutM[30:23], FPUOutM[22:0]);
                    end
                    FSUB_S:
                    begin
                        FPUOut_real = FPUInA_real - FPUInB_real;
                        FPUOutM = $shortrealtobits(FPUOut_real);
                        {Subnormal, NaNM, InfM, ZeroM} = classify_value(FPUOutM[30:23], FPUOutM[22:0]);
                    end
                    FMUL_S:
                    begin
                        if(FPUInAIsNaN || FPUInBIsNaN || ((FPUInAIsInf || FPUInBIsInf) && (FPUInAIsZero || FPUInBIsZero)))
                        begin
                            FPUOutM ={1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            NaNM = 1'b1;
                        end
                        else if ((FPUInAIsInf || FPUInBIsInf))
                        begin
                            FPUOutM = {FPUInA[31] ^ FPUInB[31], {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            InfM = 1'b1;
                        end
                        else if(FPUInAIsZero || FPUInBIsZero)
                        begin
                            FPUOutM = {FPUInA[31] ^ FPUInB[31], {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            ZeroM = 1'b1;
                        end
                        else
                        begin
                            FPUOut_real = shortreal'(real'(real'(FPUInA_real) * real'(FPUInB_real)));
                            FPUOutM = $shortrealtobits(FPUOut_real);
                            {Subnormal, NaNM, InfM, ZeroM} = classify_value(FPUOutM[30:23], FPUOutM[22:0]);
                            if((FPUOutM[30:23] == 0) && (FPUOutM[22:0] == 0)) // Check for underflow
                            begin
                                UnderflowM = 1'b1;
                                ZeroM = 1'b1;
                            end
                            if(Subnormal == 1'b1)
                            begin
                                UnderflowM = 1'b1;
                            end
                            if((FPUOutM[30:23] == {8{1'b1}}) && (FPUOutM[22:0] == {23{1'b0}})) // Check for overflow
                            begin
                                OverflowM = 1'b1;
                            end
                        end
                    end
                    FDIV_S:
                    begin
                        if(FPUInAIsNaN || FPUInBIsNaN)
                        begin
                            FPUOutM ={1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            NaNM = 1'b1;
                        end
                        else if ((FPUInAIsInf || FPUInBIsInf) && (FPUInAIsZero || FPUInBIsZero))
                        begin
                            FPUOutM ={1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            NaNM = 1'b1;
                        end
                        else if(!FPUInAIsNaN && !FPUInAIsInf && !FPUInAIsZero && FPUInBIsZero)
                        begin
                            FPUOutM = {FPUInA[31] ^ FPUInB[31], {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
                            FPUOut_real = $bitstoshortreal(FPUOutM);
                            InfM = 1'b1;
                        end
                        else
                        begin
                            FPUOut_real = FPUInA_real / FPUInB_real;
                            FPUOutM = $shortrealtobits(FPUOut_real);
                            {Subnormal, NaNM, InfM, ZeroM} = classify_value(FPUOutM[30:23], FPUOutM[22:0]);
                            if(((FPUOutM[30:23] == 0) && (FPUOutM[22:0] == 0))) // Check for underflow
                            begin
                                UnderflowM = 1'b1;
                            end
                        end
                    end
                    FSQRT_S :
                    begin
                        FPUOut_real = $sqrt(FPUInA_real);
                        FPUOutM = $shortrealtobits(FPUOut_real);
                        {Subnormal, NaNM, InfM, ZeroM} = classify_value(FPUOutM[30:23], FPUOutM[22:0]);
                    end
                    FSGNJ_S:
                    begin
                        FPUOutM = {FPUInB[DATA_WIDTH-1], FPUInA[DATA_WIDTH-2:0]};
                    end
                    FSGNJX_S:
                    begin
                        FPUOutM = {FPUInB[DATA_WIDTH-1] ^ FPUInA[DATA_WIDTH-1], FPUInA[DATA_WIDTH-2:0]};
                    end
                    FSGNJN_S:
                    begin
                        FPUOutM = {~FPUInB[DATA_WIDTH-1], FPUInA[DATA_WIDTH-2:0]};
                    end
                    FMIN_S:
                    begin
                        if(FPUInA_real < FPUInB_real)
                            FPUOutM = FPUInA;
                        else
                            FPUOutM = FPUInB;
                    end
                    FMAX_S:
                    begin
                        if(FPUInA_real > FPUInB_real)
                            FPUOutM = FPUInA;
                        else
                            FPUOutM = FPUInB;
                    end
                    FCVT_W_S:
                    begin
                        //FPUOutM = $signed(int'(FPUInA_real));
                        FPUOutM = fcvt_float_to_int(FPUInA_real,sc_item.RoundModeE, 1'b0);
                        FPUOut_real = $bitstoshortreal(FPUOutM);
                    end
                    FCVT_WU_S:
                    begin
                        //if(FPUInA_real < 0)
                        //    FPUOutM = 'b0;
                        //else
                        //    FPUOutM = $signed(int'(FPUInA_real));
                        FPUOutM = fcvt_float_to_int(FPUInA_real,sc_item.RoundModeE, 1'b1);
                        FPUOut_real = $bitstoshortreal(FPUOutM);
                    end
                    FMV_X_S:
                    begin
                        FPUOutM = FPUInA;
                    end
                    FEQ_S:
                    begin
                        FPUOutM = (FPUInA_real == FPUInB_real) ? 32'b1 : 32'b0;
                    end
                    FLT_S:
                    begin
                        FPUOutM = (FPUInA_real < FPUInB_real) ? 32'b1 : 32'b0;
                    end
                    FLE_S:
                    begin
                        FPUOutM = (FPUInA_real <= FPUInB_real) ? 32'b1 : 32'b0;
                    end
                    FCVT_S_W:
                    begin
                        FPUOut_real = shortreal'(SrcA);
                        FPUOutM = $shortrealtobits(FPUOut_real);
                    end
                    FCVT_S_WU:
                    begin
                        if(SrcA < 0)
                            FPUOut_real = shortreal'(-SrcA);
                        else
                            FPUOut_real = shortreal'(SrcA);
                        FPUOutM = $shortrealtobits(FPUOut_real);
                    end
                    FMV_S_X:
                    begin
                        FPUOutM = SrcA;
                    end
                    FCLASS_S:
                    begin
                        FPUOutM = fclass_s(FPUInA_real);
                        ZeroM = FPUInAIsZero;
                        InfM = FPUInAIsInf;
                        NaNM = FPUInAIsNaN;
                    end
                    NOOPERATION:
                    begin
                        FPUOutM = 'b0;
                    end
                endcase

                //threshold_exceeded = compare_with_threshold(FPUOut_real, shortreal'(sc_item.FPUOutM));

                WriteDataM = IntermediateB;

                case(sc_item.ALUSrcE)
                    1'b0 : SrcB = IntermediateB;
                    1'b1 : SrcB = sc_item.SignImmE;
                endcase

                SrcBU = SrcB;
                case(sc_item.ALUControlE)
                    MUL : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULH : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULHSU : MulOutput = {{DATA_WIDTH{SrcA[DATA_WIDTH-1]}},SrcA} * {{DATA_WIDTH{1'b0}},SrcB};
                    MULHU : MulOutput = $unsigned(SrcA) * $unsigned(SrcB);
                    DIV : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else if((SrcA == -2**(DATA_WIDTH-1)) && (SrcB == -1))
                            DivOutput = SrcA;
                        else
                            DivOutput = ($signed(SrcA) / $signed(SrcB));
                    end
                    DIVU : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else
                            DivOutput = ($unsigned(SrcA) / $unsigned(SrcB));
                    end
                    REM : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else if((SrcA == -2**(DATA_WIDTH-1)) && (SrcB == -1))
                            RemOutput = 0;
                        else
                            RemOutput = $signed(SrcA) % $signed(SrcB);
                    end
                    REMU : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else
                            RemOutput = $unsigned(SrcA) % $unsigned(SrcB);
                    end
                endcase

                case(sc_item.ALUControlE)
                    ADD : ALUOutM = SrcA + SrcB;
                    SUB : ALUOutM = SrcA - SrcB;
                    AND : ALUOutM = SrcA & SrcB;
                    OR : ALUOutM = SrcA | SrcB;
                    XOR : ALUOutM = SrcA ^ SrcB;
                    SLT : ALUOutM = $signed(SrcA) < $signed(SrcB);
                    SLTU : ALUOutM = $unsigned(SrcA) < $unsigned(SrcB);
                    SLL : ALUOutM = SrcA << SrcB;
                    SRL : ALUOutM = SrcA >> SrcB;
                    SRA : ALUOutM = $signed(SrcA) >>> SrcB;
                    MUL : ALUOutM = MulOutput[DATA_WIDTH-1:0];
                    MULH : ALUOutM = MulOutput[2*DATA_WIDTH-1:DATA_WIDTH];
                    MULHSU : ALUOutM = $signed(MulOutput[2*DATA_WIDTH-1:DATA_WIDTH]);
                    MULHU : ALUOutM = $unsigned(MulOutput[2*DATA_WIDTH-1:DATA_WIDTH]);
                    DIV : ALUOutM = DivOutput;
                    REM : ALUOutM = RemOutput;
                    DIVU : ALUOutM = $unsigned(DivOutput);
                    REMU : ALUOutM = RemOutput;
                endcase

                case(branch_t'(sc_item.funct3E))
                    BEQ : begin
                                if(SrcA == SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BNE : begin
                                if(SrcA != SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BLT : begin
                                if($signed(SrcA) < $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGE : begin
                                if($signed(SrcA) >= $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BLTU : begin
                                if($unsigned(SrcA) < $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGEU : begin
                                if($unsigned(SrcA) >= $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                endcase

                PCSrcE = (sc_item.BranchE & branch_true) || sc_item.JumpE;
                ALUOutM_past = sc_item.ALUOutM;
                FPUOutM_past = sc_item.FPUOutM;
                CSRInterruptOperation();
                check_output();
            end:NotReset
        endfunction:ref_model

        function void check_output ();
            if (
                ALUOutM[DATA_WIDTH-1:0] != sc_item.ALUOutM || 
                WriteDataM != sc_item.WriteDataM || 
                RdM != sc_item.RdM || 
                PCSrcE != sc_item.PCSrcE ||
                RegWriteM != sc_item.RegWriteM || 
                funct3M != sc_item.funct3M || 
                MemWriteM != sc_item.MemWriteM ||
                CsrOutM != sc_item.CsrOutM ||
                PCPlus4M != sc_item.PCPlus4M ||
                SelectorM != sc_item.SelectorM ||
                TrapIsSet != sc_item.TrapIsSet ||
                CsrOutPC != sc_item.CsrOutPC ||
                FPUOutM != sc_item.FPUOutM ||
                FPURegWriteM != sc_item.FPURegWriteM ||
                MoveOperationM != sc_item.MoveOperationM ||
                OverflowM != sc_item.OverflowM ||
                UnderflowM != sc_item.UnderflowM ||
                NaNM != sc_item.NaNM ||
                InfM != sc_item.InfM ||
                ZeroM != sc_item.ZeroM ||
                InvalidDivM != sc_item.InvalidDivM ||
                RdFM != sc_item.RdFM
                ) 
            begin
                `uvm_info("SCB",{sc_item.convert2str,$sformatf(" and the past ALUOutM = %0d",ALUOutM_past)},UVM_HIGH)
                if (ALUOutM[DATA_WIDTH-1:0] != sc_item.ALUOutM) begin
                    `uvm_info("SCB", $sformatf("Actual output ALUOutM = %0d -- ALUOutM = %0d", sc_item.ALUOutM, ALUOutM[DATA_WIDTH-1:0]), UVM_MEDIUM)
                    $display("SrcA = %0d , SrcB = %0d , MultiplyOut = %0d",SrcA,SrcB,MulOutput);
                    fail++;
                end
                if (WriteDataM != sc_item.WriteDataM) begin
                    `uvm_info("SCB", $sformatf("Actual output WriteDataM = %0h -- WriteDataM = %0h", sc_item.WriteDataM, WriteDataM), UVM_MEDIUM)
                    fail++;
                end
                if (RdM != sc_item.RdM) begin
                    `uvm_info("SCB", $sformatf("Actual output RdM = %s -- RdM = %s", sc_item.RdM.name, RdM.name), UVM_MEDIUM)
                    fail++;
                end
                if (PCSrcE != sc_item.PCSrcE) begin
                    `uvm_info("SCB", $sformatf("Actual output PCSrcE = %0h -- PCSrcE = %0h", sc_item.PCSrcE, PCSrcE), UVM_MEDIUM)
                    fail++;
                end
                if (RegWriteM != sc_item.RegWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output RegWriteM = %0h -- RegWriteM = %0h", sc_item.RegWriteM, RegWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (funct3M != sc_item.funct3M) begin
                    `uvm_info("SCB", $sformatf("Actual output funct3M = %0h -- funct3M = %0h", sc_item.funct3M, funct3M), UVM_MEDIUM)
                    fail++;
                end
                if (MemWriteM != sc_item.MemWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output MemWriteM = %0h -- MemWriteM = %0h", sc_item.MemWriteM, MemWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (CsrOutM != sc_item.CsrOutM) begin
                    `uvm_info("SCB", $sformatf("Actual output CsrOutM = %0h -- CsrOutM = %0h", sc_item.CsrOutM, CsrOutM), UVM_MEDIUM)
                    fail++;
                end
                if (PCPlus4M != sc_item.PCPlus4M) begin
                    `uvm_info("SCB", $sformatf("Actual output PCPlus4M = %0h -- PCPlus4M = %0h", sc_item.PCPlus4M, PCPlus4M), UVM_MEDIUM)
                    fail++;
                end
                if (SelectorM != sc_item.SelectorM) begin
                    `uvm_info("SCB", $sformatf("Actual output SelectorM = %0h -- SelectorM = %0h", sc_item.SelectorM, SelectorM), UVM_MEDIUM)
                    fail++;
                end
                if (TrapIsSet != sc_item.TrapIsSet) begin
                    `uvm_info("SCB", $sformatf("Actual output TrapIsSet = %0h -- TrapIsSet = %0h ", sc_item.TrapIsSet, TrapIsSet), UVM_MEDIUM)
                    fail++;
                    `uvm_info("SCB",sc_item.convert2str(),UVM_MEDIUM)
                end
                if (CsrOutPC != sc_item.CsrOutPC) begin
                    `uvm_info("SCB", $sformatf("Actual output CsrOutPC = %0h -- CsrOutPC = %0h", sc_item.CsrOutPC, CsrOutPC), UVM_MEDIUM)
                    fail++;
                end
                if (FPUOutM != sc_item.FPUOutM) 
                begin
                    if((sc_item.FPUControlE == FCVT_W_S) || (sc_item.FPUControlE == FCVT_WU_S))
                    begin
                        compare_ints_5_percent(sc_item.FPUOutM, FPUOutM);
                    end
                    else
                    begin
                        compare_shortreal_rel_error($bitstoshortreal(sc_item.FPUOutM), $bitstoshortreal(FPUOutM), 5e-2);
                    end
                end
                if (FPURegWriteM != sc_item.FPURegWriteM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output FPURegWriteM = %0h -- FPURegWriteM = %0h , operation = %s", sc_item.FPURegWriteM, FPURegWriteM, sc_item.FPUControlE.name()), UVM_MEDIUM)
                    fail++;
                end
                if (MoveOperationM != sc_item.MoveOperationM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output MoveOperationM = %s -- MoveOperationM = %s", sc_item.MoveOperationM.name(), MoveOperationM.name()), UVM_MEDIUM)
                    fail++;
                end
                if (OverflowM != sc_item.OverflowM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output OverflowM = %0h -- OverflowM = %0h , operation = %s", sc_item.OverflowM, OverflowM,sc_item.FPUControlE.name()), UVM_MEDIUM)
                    fail++;
                end
                if (UnderflowM != sc_item.UnderflowM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output UnderflowM = %0h -- UnderflowM = %0h , operation = %s , FPUOutM = %f , %0h", sc_item.UnderflowM, UnderflowM,sc_item.FPUControlE.name(), $bitstoshortreal(FPUOutM),FPUOutM), UVM_MEDIUM)
                    fail++;
                end
                if (NaNM != sc_item.NaNM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output NaNM = %0h -- NaNM = %0h, operation = %s", sc_item.NaNM, NaNM,sc_item.FPUControlE.name()), UVM_MEDIUM)
                    fail++;
                end
                if (InfM != sc_item.InfM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output InfM = %0h -- InfM = %0h, operation = %s", sc_item.InfM, InfM,sc_item.FPUControlE.name()), UVM_MEDIUM)
                    fail++;
                end
                if (ZeroM != sc_item.ZeroM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output ZeroM = %0h -- ZeroM = %0h, operation = %s", sc_item.ZeroM, ZeroM,sc_item.FPUControlE.name()), UVM_MEDIUM)
                    fail++;
                end
                if (RdFM != sc_item.RdFM) 
                begin
                    `uvm_info("SCB", $sformatf("Actual output RdFM = %s -- RdFM = %s", sc_item.RdFM.name, RdFM.name), UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (execute_item #(DATA_WIDTH,ADDR_WIDTH) item);
            sc_item = item;
            ref_model();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","sc_itemoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:execute_scoreboard

endpackage:execute_scoreboard_pkg
