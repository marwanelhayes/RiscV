# RISC-V 5-Stage Pipeline Commenting Style

This document describes the commenting conventions used throughout this RV32I processor architecture.

## File Header

Every module file begins with a standardized header block:

```systemverilog
// =============================================================================
// filename.sv
// -----------------------------------------------------------------------------
// Brief description of module purpose.
//
// Responsibilities:
//   - List of key responsibilities (bullet format)
//   - Each on its own line
//
// Interface section (if applicable):
//   - Signal descriptions grouped by function
//   - e.g., D-cache interface, Branch control, etc.
//
// Instantiates:
//   - Sub-modules instantiated within
// =============================================================================
```

**Key characteristics:**
- Uses `// =============================================================================` (40+ characters) as top/bottom border
- Uses `// -----------------------------------------------------------------------------` (40+ characters) as sub-separator
- Filename follows immediately after the border
- Multi-line description with blank lines separating sections

## Section Headers

### Major Sections

```systemverilog
// ─── Section Name ───────────────────────────────────────────────────────────────
```

- Uses Unicode box-drawing character `─` (U+2500)
- Three dashes `───` after the text
- Extends to column ~80 with padding dashes

### Subsection Headers

```systemverilog
// ── Subsection Name ─────────────────────────────────────────────────────────────
```

- Two dashes `──` after the text
- Used for port groupings within module ports

### Class/Structure Separators (UVM)

```systemverilog
// =========================================================================
// ClassName: description
// =========================================================================
```

- Used in UVM testbench packages
- 40+ equals signs for visual separation

## Port Grouping Comments

Module ports are grouped by functionality using subsection headers:

```systemverilog
(
    // ── Group Name ─────────────────────────────────────────────────────────────
    input  logic        signal_a,
    input  logic [31:0] signal_b,

    // ── Another Group ──────────────────────────────────────────────────────────
    output logic        result,
    output logic [31:0] data_out
);
```

**Examples from codebase:**
- `// ── Branch / jump redirect from EX stage ─────────────────────────────────`
- `// ── Pipeline control from hazard unit ────────────────────────────────────`
- `// ── I-cache interface ─────────────────────────────────────────────────────`
- `// ── EX/MEM register inputs ───────────────────────────────────────────────`

## Internal Signal Grouping

Internal wires and registers are grouped by pipeline stage connections:

```systemverilog
// ─── Internal wires – pipeline stage connections ──────────────────────────────

// IF/ID
logic [31:0] InstrD;
logic [31:0] PCD, PC4D;

// ID/EX
logic        RegWriteE, MemWriteE, MemReadE;
wb_sel_t     WBSelE;
...
```

**Pattern:**
- Use `// IF/ID`, `// ID/EX`, `// EX/MEM`, `// MEM/WB` as group labels
- Group related signals together
- Use blank lines between groups

## Inline Comments

Used within code blocks to explain specific operations:

```systemverilog
// Branch/jump redirect
PC_reg <= PCTargetE;

// advance only on cache hit
PC_reg <= PC4F;

// rs2 value (forwarded) for stores
WriteDataM <= SrcBFwd;
```

**Guidelines:**
- Keep comments concise (1-2 phrases)
- Place on same line as the code they describe
- Use past tense for actions (e.g., "assigned", "latched")
- Capitalize first letter

## Module Instantiation Comments

Label each module instance with a section header:

```systemverilog
// ─── fetch_stage ─────────────────────────────────────────────────────────────
fetch_stage #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH)
) IF_STAGE (
    .clk        (clk),
    ...
);
```

## Signal Naming Conventions

Comments often reference signal naming patterns:
- **Pipeline stage suffix**: `F` (Fetch), `D` (Decode), `E` (Execute), `M` (Memory), `W` (Writeback)
- **Control signals**: ending in `_e` (enable), `_sel` (selector), `_op` (operation)
- **Interface prefixes**: `i_` (instruction), `d_` (data), `m_` (master AXI)

## Reset and Default Value Comments

In `always_ff` blocks, document reset values and default states:

```systemverilog
always_ff @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        RegWriteM <= 1'b0;    // clear on reset
        MemWriteM <= 1'b0;
        MemReadM  <= 1'b0;
    end
    else
    begin
        RegWriteM <= RegWriteE;
        ...
    end
end
```

## Case Statement Comments

Document each case in decision logic:

```systemverilog
case (opcode)
    // ── R-type ───────────────────────────────────────────────────────────────
    OP_R_TYPE: ...

    // ── Load ────────────────────────────────────────────────────────────────
    OP_LOAD: ...

    // ── Branch ───────────────────────────────────────────────────────────────
    OP_BRANCH: ...
endcase
```

## Conditional Logic Comments

Explain conditions in procedural blocks:

```systemverilog
// Only advance the pipeline register on cache hit or non-memory instruction
else if (DHitM || !(MemReadM | MemWriteM))
```

```systemverilog
// else: cache miss – hold registers frozen (DCacheMiss stalls pipeline)
```

## Special Notations

### Cache Interface Notes

Document cache hit/miss behavior:

```verilog
// I-cache hit this cycle (input; 0 → pipeline stalls via ICacheMiss)
input  logic IHitF,
```

### Protocol Notes

```verilog
// JALR: (rs1 + imm) & ~1  (clear LSB per spec)
```

### Alignment Constraints

```verilog
constraint c_align{ PCTargetE[1:0] == 2'b00; }  // word-aligned
```

## Testbench-Specific Patterns

### Sequence Item Comments

```verilog
class fetch_seq_item extends uvm_sequence_item;
    // ─── Virtual interface handle type ────────────────────────────────────────

    rand logic        rst_n;
    rand logic        PCSrcE;
    ...
endclass
```

### Class Description Comments

```verilog
// =========================================================================
// fetch_driver: apply stimulus to DUT through virtual interface
// =========================================================================
class fetch_driver extends uvm_driver #(fetch_seq_item);
```

## Summary of Commenting Principles

1. **Consistency**: Same patterns used everywhere (header format, section dividers)
2. **Hierarchy**: Clear visual distinction between major sections, subsections, and inline comments
3. **Purpose-first**: Header explains what the module does before diving into implementation
4. **Signal grouping**: Related signals grouped and labeled by pipeline stage or function
5. **Brevity**: Inline comments are short, typically one phrase
6. **Visual separation**: Unicode box-drawing characters create clear visual structure
7. **Interface documentation**: External interfaces (caches, hazards, AXI) clearly documented

## Files Following This Style

- `riscv_design/*.sv` - All pipeline stage modules
- `riscv_verif/*_tb_pkg.sv` - UVM testbench packages
- `riscv_verif/*_tb_top.sv` - Testbench top modules
- `riscv_verif/*_if.sv` - Interface definitions