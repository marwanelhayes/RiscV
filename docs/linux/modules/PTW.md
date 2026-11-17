# `ptw.sv` — hardware page-table walker

Spec basis: Priv "Virtual Address Translation Process" (see
[MMU_SV32_SV39](../MMU_SV32_SV39.md) §5). Plan block B5.2.
Back to [index](../README.md).

## 1. Purpose

On a TLB miss, walk the page table rooted at `satp.PPN`, produce a leaf (refill)
or a fault, and hand the result to the requesting TLB. One walker shared by
I-TLB and D-TLB (D has priority; a single in-order hart never has both
outstanding in a way that deadlocks, because a D miss freezes F too).

## 2. Ports

```
input  logic                   clk, rst,
// requests
input  logic                   ReqI, ReqD,
input  logic [DATA_WIDTH-1:0]  VAddrI, VAddrD,
input  logic                   ReqDIsStore,            // for the Svade D check
// configuration from csr_file
input  logic [DATA_WIDTH-1:0]  Satp,
// memory port: muxed onto the D-cache CPU port
output logic                   PtwMemReq,
output logic [PADDR_W-1:0]     PtwMemAddr,             // PTE physical address
input  logic [DATA_WIDTH-1:0]  PtwMemRData,
input  logic                   PtwMemDone,
input  logic                   PtwMemAccessFault,      // PMP/PMA/bus on the PTE read
// results
output logic                   RefillI, RefillD,       // to TLBs
output logic [VPN_W-1:0]       RefillVPN,
output logic [PPN_W-1:0]       RefillPPN,
output logic [LEVEL_W-1:0]     RefillLevel,
output logic [6:0]             RefillFlags,
output logic                   WalkFaultI, WalkFaultD, // page fault
output logic                   WalkAccFaultI, WalkAccFaultD,
output logic                   PTWBusy                 // stall request to hazard_unit
```

On RV64 with `DATA_WIDTH = 64`, a PTE is one D-cache word. On RV32 it is one 32-bit
word. PTEs are read with width PTESIZE — never split.

## 3. State machine (style of `axi_state_t` in `shared_pkg.sv`)

```
PTW_IDLE   -> PTW_REQ   : latch VA, a = satp.ppn<<12, i = LEVELS-1
PTW_REQ    -> PTW_WAIT  : PtwMemReq, addr = a + vpn[i]*PTESIZE
PTW_WAIT   -> PTW_EVAL  : PtwMemDone (access fault -> PTW_FAULT_ACC)
PTW_EVAL   : invalid / reserved bits / R=0&W=1  -> PTW_FAULT_PG
             pointer (R=X=0): i==0 -> PTW_FAULT_PG, else a = pte.ppn<<12, i--, -> PTW_REQ
             leaf: misaligned superpage -> PTW_FAULT_PG
                   else -> PTW_REFILL (permission/A/D checks happen at lookup, §TLB.5)
PTW_REFILL -> PTW_IDLE
PTW_FAULT_* -> PTW_IDLE : pulse WalkFault*/WalkAccFault*
```

Design choices (all spec-legal, all minimise logic):

| Choice | Why legal |
|---|---|
| Svade only: walker never writes PTEs | RVA20S64 mandates Svade; spec step 9 option |
| Permission/A/D checks at TLB lookup, not in the walker | the leaf is cached with its raw bits; a fault is still raised for the original access |
| No caching of non-leaf PTEs | caching is optional |
| Walk through the D-cache | PTE reads "may be held in a read-only, incoherent address-translation cache" — reading through the data cache is the *coherent* case, so SFENCE.VMA ordering is satisfied for free |
| PA width cap: PTE PPN bits above the implemented PA width non-zero → access fault | out-of-range PA is an access fault (PMA) |

## 4. Integration

- Mux in `memory_stage` in front of the D-cache CPU port: when `PTWBusy` the port is
  driven by the PTW (read, full word, cacheable). The pipeline is frozen during a
  walk (any D miss already freezes everything), so no arbitration with an in-flight
  load is needed.
- PMP check on every PTE address with effective mode S ("The effective privilege
  mode for implicit page-table accesses is S", machine.adoc).
- `satp` write / SFENCE.VMA while a walk is in flight cannot happen (they serialize
  and the pipeline is frozen during walks).

## 5. Verification hooks

- Unit env with a sparse memory model holding random page tables and a *spec
  function* walker written in SV from §5 of the MMU spec (one function, not a cycle
  model). Compare `{fault type, PPN, level, flags}` per request.
- Inject access faults on random PTE reads.
- Coverage: depth reached × fault reason (each of: V=0, R0W1, reserved bits,
  pointer at level 0, misaligned superpage, access fault) × requester (I/D).
- System level: `riscv-tests -v-` and riscv-dv page-table randomisation.
