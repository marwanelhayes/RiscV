// =============================================================================
// risc_data_memory.sv
// -----------------------------------------------------------------------------
// Data memory (RAM) for RISC-V processor.
//
// Responsibilities:
//   - Provide byte/halfword/word read and write access
//   - Support unaligned load/store with hardware assist
//   - Handle byte-enable masking for partial writes
//   - Implement byte-lane architecture for efficient memory access
//
// Instantiates:
//   - data_memory: four byte-lane memory instances
// =============================================================================
import shared_pkg::*;

module risc_data_memory 
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ─── Memory interface ─────────────────────────────────────────────────────
    input [ADDR_WIDTH-1:0] a1,              // Byte address
    input signed [DATA_WIDTH-1:0] Wdata,    // Write data
    input load_store_t sel,                // Size select (B/HW/W/BU/HWU)
    input we,                               // Write enable

    // ─── Read data output ───────────────────────────────────────────────────
    output logic signed [DATA_WIDTH-1:0] RDdata
);
    // ─── Internal parameters ─────────────────────────────────────────────────
    localparam int MEM_DATA_WIDTH = (DATA_WIDTH/4);    // 8 bits per byte lane

    // ─── Internal wires – byte lane read data ───────────────────────────────
    logic signed [MEM_DATA_WIDTH-1:0] ReadData1;    // Byte lane 0
    logic signed [MEM_DATA_WIDTH-1:0] ReadData2;    // Byte lane 1
    logic signed [MEM_DATA_WIDTH-1:0] ReadData3;    // Byte lane 2
    logic signed [MEM_DATA_WIDTH-1:0] ReadData4;    // Byte lane 3

    // ─── Internal wires – byte write enables ────────────────────────────────
    logic we1, we2, we3, we4;    // Individual byte lane write enables

    // ─── risc_data_memory: byte lane 0 (bits 7:0) ─────────────────────────
    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM1 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),                           // Word-aligned address
        .Wdata(Wdata[MEM_DATA_WIDTH-1:0]),                 // Byte 0
        .we(we1),
        .RDdata(ReadData1)
    );

    // ─── risc_data_memory: byte lane 1 (bits 15:8) ─────────────────────────
    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM2 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[2*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH]),  // Byte 1
        .we(we2),
        .RDdata(ReadData2)
    );

    // ─── risc_data_memory: byte lane 2 (bits 23:16) ───────────────────────
    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM3 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[3*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH]), // Byte 2
        .we(we3),
        .RDdata(ReadData3)
    );

    // ─── risc_data_memory: byte lane 3 (bits 31:24) ───────────────────────
    data_memory #(.DATA_WIDTH(MEM_DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH - 2)) DM4 
    (
        .clk(clk),
        .rst(rst),
        .a1(a1[ADDR_WIDTH-1:2]),
        .Wdata(Wdata[4*MEM_DATA_WIDTH-1:3*MEM_DATA_WIDTH]), // Byte 3
        .we(we4),
        .RDdata(ReadData4)
    );

    // ─── Read data selection based on size ───────────────────────────────────
    always_comb
    begin
        RDdata = '0;
        case(sel)
            // ── Word (32-bit) load ─────────────────────────────────────────
            W: RDdata = {ReadData4,ReadData3,ReadData2,ReadData1};
            // ── Halfword signed load ───────────────────────────────────────
            HW:     begin
                        if(a1[1])    // Unaligned: address[1]=1
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData4,ReadData3};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{ReadData4[MEM_DATA_WIDTH-1]}};
                        end
                        else         // Aligned: address[1]=0
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData2,ReadData1};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = {2*MEM_DATA_WIDTH{ReadData2[MEM_DATA_WIDTH-1]}};
                        end
                    end
            // ── Halfword unsigned load ──────────────────────────────────────
            HWU:    begin
                        if(a1[1])
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData4,ReadData3};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = '0;
                        end
                        else
                        begin
                            RDdata[2*MEM_DATA_WIDTH-1:0] = {ReadData2,ReadData1};
                            RDdata[4*MEM_DATA_WIDTH-1:2*MEM_DATA_WIDTH] = '0;
                        end
                    end
            // ── Byte signed load ────────────────────────────────────────────
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
            // ── Byte unsigned load ───────────────────────────────────────────
            BU:    begin
                        case(a1[1:0])
                            2'b00:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData1;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = '0; 
                                    end
                            2'b01:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData2;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = '0; 
                                    end
                            2'b10:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData3;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = '0; 
                                    end
                            2'b11:  begin
                                        RDdata[MEM_DATA_WIDTH-1:0] = ReadData4;
                                        RDdata[4*MEM_DATA_WIDTH-1:MEM_DATA_WIDTH] = '0; 
                                    end
                        endcase
                    end
        endcase
    end

    // ─── Write enable generation for byte lanes ─────────────────────────────
    always_comb
    begin
        we1 = 1'b0;
        we2 = 1'b0;
        we3 = 1'b0;
        we4 = 1'b0;
        if(we)
        begin
            case(sel)
                // ── Word store: enable all byte lanes ─────────────────────
                W: begin
                        we1 = 1'b1;
                        we2 = 1'b1;
                        we3 = 1'b1; 
                        we4 = 1'b1;
                    end
                // ── Halfword store: select based on address ───────────────
                HW: begin
                        if(a1[1])
                        begin
                            we3 = 1'b1;
                            we4 = 1'b1;
                        end
                        else
                        begin
                            we1 = 1'b1;
                            we2 = 1'b1;
                        end
                    end
                // ── Byte store: select single byte lane ───────────────────
                B: begin
                        case(a1[1:0])
                            2'b00:  we1 = 1'b1;
                            2'b01:  we2 = 1'b1;
                            2'b10:  we3 = 1'b1;
                            2'b11:  we4 = 1'b1;
                        endcase
                    end
            endcase
        end
    end

endmodule