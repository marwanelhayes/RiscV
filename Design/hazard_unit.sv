import shared_pkg::*;

module hazard_unit 
(
    input   gpr_t Rs1E,
    input   gpr_t Rs2E,
    input   gpr_t RdE,
    input   gpr_t Rs1D, 
    input   gpr_t Rs2D, 
    input   gpr_t RdM,
    input   gpr_t RdW,
    input   logic RegWriteM,
    input   logic RegWriteW,
    input   selector_t SelectorE,
    input   logic PCSrcE,
    input   logic TrapIsSet,
    input   move_operation_t MoveOperationE,
    input   fpr_t RdFM,
    input   fpr_t RdFW,
    input   fpr_t Rs1FE,
    input   fpr_t Rs2FE,
    input   logic FPURegWriteM,
    input   logic FPURegWriteW,
    input   logic FPUValidE,
    input   logic FPUBusyM,
    
    output  logic [2:0] ForwardAE,
    output  logic [2:0] ForwardBE,
    output  logic StallD,
    output  logic StallF,
    output  logic FlushE,
    output  logic FlushD,
    output  logic [1:0] ForwardFloatingAE,
    output  logic [1:0] ForwardFloatingBE 
);
    logic LWStall,FPUStall;

    //Stall
    always_comb 
    begin
        LWStall = 1'b0;
        //Load word hazard
        if (SelectorE == MemToReg && ((RdE == Rs1D) || (RdE == Rs2D))) 
        begin
            LWStall = 1'b1;
        end
    end

    always_comb
    begin
        FPUStall = 1'b0;
        //FPU hazard
        if (FPUValidE && FPUBusyM)
        begin
            FPUStall = 1'b1;
        end
    end

    //Forward for source register
    always_comb
    begin
        ForwardAE = 3'b000; 
        if (RegWriteW && (RdW != zero) && (RdW == Rs1E) && (MoveOperationE != FPUToReg)) 
        begin
            ForwardAE = 3'b001;
        end
        else if (RegWriteM && (RdM != zero) && (RdM == Rs1E) && (MoveOperationE != FPUToReg)) 
        begin
            ForwardAE = 3'b010;
        end
        else if(RegWriteW && (RdW != zero) && (RdW == Rs1E) && (MoveOperationE == FPUToReg))
        begin
            ForwardAE = 3'b011;
        end
        else if (RegWriteM && (RdM != zero) && (RdM == Rs1E) && (MoveOperationE == FPUToReg)) 
        begin
            ForwardAE = 3'b100;
        end 
    end

    //Forward for target register
    always_comb
    begin
        ForwardBE = 3'b000;
        if (RegWriteW && (RdW != zero) && (RdW == Rs2E) && (MoveOperationE != FPUToReg)) 
        begin
            ForwardBE = 3'b001;
        end
        else if (RegWriteM && (RdM != zero) && (RdM == Rs2E) && (MoveOperationE != FPUToReg)) 
        begin
            ForwardBE = 3'b010;
        end
        else if(RegWriteW && (RdW != zero) && (RdW == Rs2E) && (MoveOperationE == FPUToReg))
        begin
            ForwardBE = 3'b011;
        end
        else if (RegWriteM && (RdM != zero) && (RdM == Rs2E) && (MoveOperationE == FPUToReg)) 
        begin
            ForwardBE = 3'b100;
        end  
    end

    always_comb
    begin
        ForwardFloatingAE = 2'b00;
        if (FPURegWriteW && (RdFW != f0) && (RdFW == Rs1FE)) 
        begin
            ForwardFloatingAE = 2'b01;
        end
        else if (FPURegWriteM && (RdFM != f0) && (RdFM == Rs1FE)) 
        begin
            ForwardFloatingAE = 2'b10;
        end 
    end

    always_comb
    begin
        ForwardFloatingBE = 2'b00;
        if (FPURegWriteW && (RdFW != f0) && (RdFW == Rs2FE)) 
        begin
            ForwardFloatingBE = 2'b01;
        end
        else if (FPURegWriteM && (RdFM != f0) && (RdFM == Rs2FE)) 
        begin
            ForwardFloatingBE = 2'b10;
        end 
    end
        
    assign StallD = LWStall || FPUStall;
    assign StallF = LWStall || FPUStall;
    assign FlushD = PCSrcE  || TrapIsSet;
    assign FlushE = LWStall || PCSrcE || TrapIsSet;
endmodule