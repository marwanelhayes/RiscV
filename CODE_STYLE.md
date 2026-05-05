# RiscV Code Style Guide

## Overview

This document captures the coding style used in the RiscV project, distinguishing between **synthesizable design code** and **non-synthesizable verification code**.

---

## Design Code (Verification/)

### Synthesizable Constructs

| Construct | Usage |
|-----------|-------|
| `module` | Top-level hardware blocks |
| `interface` | Clocking blocks and signal bundling |
| `package` | Shared types, enums, parameters |
| `always_ff` | Sequential logic (flip-flops) |
| `always_comb` | Combinational logic |
| `logic` / `bit` | Scalar types |
| `struct` | Grouped signals |
| `typedef enum` | State machines, operation types |

### Code Style

```systemverilog
import shared_pkg::*;

module execute_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) (
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] RD1E,
    output logic signed [DATA_WIDTH-1:0] ALUOutM,
    output gpr_t RdM
);

    logic signed [DATA_WIDTH:0] ALUOutE;
    logic branch_true;

    risc_alu #(.DATA_WIDTH(DATA_WIDTH)) ALU
    (
        .SrcA(SrcAE),
        .SrcB(SrcBE),
        .alu_control(ALUControlE),
        .Y(ALUOutE),
        .branch_true(branch_true)
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            RegWriteM <= 0;
            SelectorM <= ALUToReg;
        end
        else
        begin
            RegWriteM <= RegWriteE;
            SelectorM <= SelectorE;
        end
    end

    always_comb
    begin
        PCSrcE = (BranchE & branch_true) | JumpE;
    end

endmodule
```

### Key Patterns

- **Explicit port connections**: `.port_name(signal)`
- **Parameterized modules**: `#(parameter int WIDTH = 32)`
- **Reset handling**: `if (!rst)` or `if (rst_n == 1'b0)`
- **State machine encoding**: `typedef enum logic [2:0]`
- **Hierarchical instantiation**: Module within module

---

## Verification Code (Verification/)

### Non-Synthesizable Constructs

| Construct | Usage |
|-----------|-------|
| `uvm_sequence_item` | Transaction objects |
| `uvm_sequence` | Stimulus generation |
| `uvm_driver` | DUT stimulus application |
| `uvm_monitor` | DUT output sampling |
| `uvm_scoreboard` | Result comparison |
| `uvm_env` | Test environment |
| `rand` | Randomization |
| `constraint` | Randomization bounds |

### Code Style

```systemverilog
package fetch_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class fetch_item extends uvm_sequence_item;

        `uvm_object_utils(fetch_item)

        function new(string name = "fetch_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCF;

        constraint LowResetProb {
            rst dist {0:=5, 1:=200};
        }

        virtual function string convert2str();
            return $sformatf("rst=%0d PCF=%0d", rst, PCF);
        endfunction: convert2str

    endclass: fetch_item

endpackage: fetch_item_pkg
```

### Key Patterns

- **UVM macros**: `` `uvm_component_utils``, `` `uvm_object_utils``
- **Factory registration**: `type_id::create()`
- **Phases**: `build_phase`, `connect_phase`, `run_phase`, `report_phase`
- **Analysis ports**: `uvm_analysis_port #(T)`, `uvm_analysis_imp #(T)`
- **Sequencing**: `get_next_item()`, `item_done()`

---

## Type Definitions (shared_pkg.sv)

### Enums for Operations

```systemverilog
typedef enum logic [4:0] 
{ 
    ADD  = 0,
    SUB  = 1,
    AND  = 2,
    OR   = 3,
    MUL  = 10,
    DIV  = 14
} alu_operation_t;

typedef enum logic [2:0] 
{ 
    BEQ  = 3'b000,
    BNE  = 3'b001,
    BLT  = 3'b100,
    BGE  = 3'b101
} branch_t;

typedef enum logic [2:0]
{
    INIT    = 3'b000,
    IDLE    = 3'b001,
    SPLIT   = 3'b010,
    ALIGN   = 3'b011,
    DONE    = 3'b101
} state_t;
```

---

## Binding Verification to Design

```systemverilog
`ifdef VERIF
    bind FPU flp_wr FPU_bind (.*);
    bind CSR csr_wr CSR_bind (.*);
`endif
```

---

## Summary

| Aspect | Design | Verification |
|--------|--------|--------------|
| Target | Hardware (synthesizable) | Simulation (not synthesizable) |
| Coding | Structural, explicit | UVM-based, classes |
| Timing | Clock-driven | Phase-driven |
| Randomization | None | Constraints |
| Logging | N/A | `` `uvm_info`` |