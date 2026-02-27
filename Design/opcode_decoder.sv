import shared_pkg::*;
module opcode_decoder 
#
(
    parameter int ALU_SUB_CONTROL_WIDTH = 2
)
(
    input opcode_t opcode,
    input csr_t CsrOperation,
    output logic [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl,
    output logic Jump,
    output logic Branch,
    output logic Immediate,
    output logic MemWrite,
    output selector_t Selector,
    output logic ALUSrc,
    output logic CsrAccess,
    output logic RegWrite,
    output logic Store ,
    output logic MMode , 
    output logic IllegaleInstruction,
    output logic FPU
);

    always_comb
    begin
        ALUControl = 'b11; //2'b11 is the default value for the add instruction
        Jump = 0;
        Branch = 0;
        Immediate = 0;
        MemWrite = 0;
        Selector = ALUToReg;
        ALUSrc = 0;
        RegWrite = 0;
        Store = 0;
        CsrAccess = 0;
        MMode = 0;
        FPU = 0;
        IllegaleInstruction = 1;
        case(opcode)
            R_TYPE: 
            begin  //R-type
                ALUControl = 2'b10;
                RegWrite = 1;
                Selector = ALUToReg;
                IllegaleInstruction = 0;
            end
            LOAD: 
            begin //Load Word
                Selector = MemToReg;
                Immediate = 1;
                ALUSrc = 1;
                RegWrite = 1;
                IllegaleInstruction = 0;
            end
            S_TYPE: 
            begin  //Store Word
                MemWrite = 1;
                ALUSrc = 1;
                Store = 1;
                IllegaleInstruction = 0;
            end
            B_TYPE: 
            begin //Branch
                ALUControl = 2'b00;
                Branch = 1;
                IllegaleInstruction = 0;
            end
            I_TYPE: 
            begin  //Immediate
                ALUControl = 2'b01;
                Immediate = 1'b1;
                ALUSrc = 1;
                RegWrite = 1;
                IllegaleInstruction = 0;
            end
            JAL: 
            begin //Jump
                Jump = 1;
                ALUSrc = 1;
                RegWrite = 1;
                Selector = PCToReg;
                IllegaleInstruction = 0;
            end
            JALR: 
            begin //Jump and Link Register
                Jump = 1;
                ALUSrc = 1;
                Immediate = 1'b1;
                RegWrite = 1;
                Selector = PCToReg;
                IllegaleInstruction = 0;
            end
            CSR: 
            begin //Control and Status Register
                IllegaleInstruction = 0;
                if(CsrOperation == system) //system instructions are not supported except for ecall, ebreak and mret
                begin
                    MMode = 1;
                end
                else
                begin
                    CsrAccess = 1;
                    RegWrite = 1;
                    Selector = CSRToReg; //CSR operations use a different selector
                end
            end
            FLOATING_PT:
            begin //Floating Point operations
                IllegaleInstruction = 0;
                FPU = 1;
            end
        endcase
        
    end
endmodule
