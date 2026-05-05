---
type: community
cohesion: 0.22
members: 9
---

# ISA Definitions & Parameters

**Cohesion:** 0.22 - loosely connected
**Members:** 9 nodes

## Members
- [[CLK_PERIOD = 10]] - document - README.md
- [[FINAL_ADDR_WIDTH = 22]] - document - README.md
- [[FINAL_DATA_WIDTH = 32]] - document - README.md
- [[FINAL_PRECISION = SINGLE]] - document - README.md
- [[M-extension - Integer MultiplyDivide]] - document - README.md
- [[RV32 - 32-bit Integer Base]] - document - README.md
- [[Single-precision Floating Point]] - document - README.md
- [[sample_binary.txt - Sample output]] - document - Python/sample_output/sample_binary.txt
- [[shared_pkg.sv - ISA and register enums]] - code - Design/shared_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/ISA_Definitions_&_Parameters
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_DecodeExecuteFPU Design]]

## Top bridge nodes
- [[shared_pkg.sv - ISA and register enums]] - degree 8, connects to 1 community