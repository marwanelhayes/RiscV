import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface flp_wr
(
    input clk,
    input logic rst,
    input logic valid,
    input logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] InA,
    input logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] InB,
    input fpr_t RdF,
    input logic RegWrite,
    input round_mode_t round_mode,
    input fpu_operation_t operation,
    input move_operation_t MoveOperation,

    input logic busy,
    input logic done,
    input logic Overflow,
    input logic Underflow,
    input logic NaN,
    input logic Inf,
    input logic Zero,
    input logic InvalidDiv,
    input logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] Result,
    input fpr_t RdFOut,
    input logic RegWriteOut,
    input move_operation_t MoveOperationOut
);

    flp_interface flp_intf
    (
        .clk(clk)
    );

    always_comb
    begin
        flp_intf.rst = rst;
        flp_intf.valid = valid;
        flp_intf.InA = InA;
        flp_intf.InB = InB;
        flp_intf.RdF = RdF;
        flp_intf.RegWrite = RegWrite;
        flp_intf.round_mode = round_mode;
        flp_intf.operation = operation;
        flp_intf.MoveOperation = MoveOperation;

        flp_intf.busy = busy;
        flp_intf.done = done;
        flp_intf.Overflow = Overflow;
        flp_intf.Underflow = Underflow;
        flp_intf.NaN = NaN;
        flp_intf.Inf = Inf;
        flp_intf.Zero = Zero;
        flp_intf.InvalidDiv = InvalidDiv;
        flp_intf.Result = Result;
        flp_intf.RdFOut = RdFOut;
        flp_intf.RegWriteOut = RegWriteOut;
        flp_intf.MoveOperationOut = MoveOperationOut;
    end

    initial
    begin
        uvm_config_db #(virtual flp_interface)::set(null,"","FLP_INTF",flp_intf);
    end

endinterface
