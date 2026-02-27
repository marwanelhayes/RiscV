import shared_pkg::*;
module risc_data_memory 
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] a1,
    input signed [DATA_WIDTH-1:0] Wdata,
    input load_store_t sel,
    input we,
    output logic signed [DATA_WIDTH-1:0] RDdata
);
    localparam int MEM_DATA_WIDTH = (DATA_WIDTH/4);

    logic signed [MEM_DATA_WIDTH-1:0] ReadData1,ReadData2,ReadData3,ReadData4;
    logic we1,we2,we3,we4;

    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM1 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[MEM_DATA_WIDTH-1:0]),
        .we(we1),
        .RDdata(ReadData1)
    );

    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM2 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[2*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH]),
        .we(we2),
        .RDdata(ReadData2)
    );

    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM3 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[3*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH]),
        .we(we3),
        .RDdata(ReadData3)
    );

    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM4 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[4*MEM_DATA_WIDTH-1:3*MEM_DATA_WIDTH]),
        .we(we4),
        .RDdata(ReadData4)
    );

    always_comb
    begin
        RDdata = {DATA_WIDTH{1'b0}};
        case(sel)
            W: RDdata = {ReadData4,ReadData3,ReadData2,ReadData1};
            HW:     begin
                        if(a1[1])
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData4,ReadData3};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{ReadData4[MEM_DATA_WIDTH-1]}};
                        end
                        else
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData2,ReadData1};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{ReadData2[MEM_DATA_WIDTH-1]}};
                        end
                    end
            HWU:    begin
                        if(a1[1])
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData4,ReadData3};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{1'b0}};
                        end
                        else
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData2,ReadData1};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{1'b0}};
                        end
                    end
            B:     begin
                        case(a1[1:0])
                            2'b00:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData1;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{ReadData1[MEM_DATA_WIDTH-1]}}; 
                                    end
                            2'b01:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData2;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{ReadData2[MEM_DATA_WIDTH-1]}}; 
                                    end
                            2'b10:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData3;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{ReadData3[MEM_DATA_WIDTH-1]}}; 
                                    end
                            2'b11:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData4;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{ReadData4[MEM_DATA_WIDTH-1]}}; 
                                    end
                        endcase
                    end
            BU:    begin
                        case(a1[1:0])
                            2'b00:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData1;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{1'b0}}; 
                                    end
                            2'b01:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData2;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{1'b0}}; 
                                    end
                            2'b10:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData3;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{1'b0}}; 
                                    end
                            2'b11:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData4;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = {3*MEM_DATA_WIDTH{1'b0}}; 
                                    end
                        endcase
                    end
        endcase
    end

    always_comb
    begin
        we1 = 0;
        we2 = 0;
        we3 = 0;
        we4 = 0;
        if(we)
        begin
            case(sel)
                W: begin
                        we1 = 1;
                        we2 = 1;
                        we3 = 1; 
                        we4 = 1;
                    end
                HW: begin
                        if(a1[1])
                        begin
                            we3 = 1;
                            we4 = 1;
                        end
                        else
                        begin
                            we1 = 1;
                            we2 = 1;
                        end
                    end
                B: begin
                        case(a1[1:0])
                            2'b00:  we1 = 1;
                            2'b01:  we2 = 1;
                            2'b10:  we3 = 1;
                            2'b11:  we4 = 1;
                        endcase
                    end
            endcase
        end
    end


endmodule