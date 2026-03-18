import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface csr_wr
(
    input clk,
    input logic rst,
    input csr_t CsrOperation,
    input gpr_t Rs,
    input traps_t Traps,
    input logic mret,
    input logic [FINAL_ADDR_WIDTH-1:0] PC,
    input logic [FINAL_ADDR_WIDTH-1:0] Address,
    input logic CsrAccess,
    input logic [FINAL_DATA_WIDTH-1:0] CsrIn,
    input logic TimerInterrupt,
    input logic ExternalInterrupt,
    input logic SoftwareInterrupt,
    input csr_index_t CsrIndex,

    input logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC,
    input logic [FINAL_DATA_WIDTH-1:0] CsrOut,
    input logic TrapIsSet,
    input round_mode_t RoundingMode
);

    csr_interface csr_intf
    (
        .clk(clk)
    );

    always_comb
    begin
        csr_intf.rst = rst;
        csr_intf.CsrOperation = CsrOperation;
        csr_intf.Rs = Rs;
        csr_intf.Traps = Traps;
        csr_intf.mret = mret;
        csr_intf.PC = PC;
        csr_intf.Address = Address;
        csr_intf.CsrAccess = CsrAccess;
        csr_intf.CsrIn = CsrIn;
        csr_intf.TimerInterrupt = TimerInterrupt;
        csr_intf.ExternalInterrupt = ExternalInterrupt;
        csr_intf.SoftwareInterrupt = SoftwareInterrupt;
        csr_intf.CsrIndex = CsrIndex;

        csr_intf.CsrOutPC = CsrOutPC;
        csr_intf.CsrOut = CsrOut;
        csr_intf.TrapIsSet = TrapIsSet;
        csr_intf.RoundingMode = RoundingMode;
    end

    initial
    begin
        uvm_config_db #(virtual csr_interface)::set(null,"","CSR_INTF",csr_intf);
    end

endinterface
