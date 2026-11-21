# `plic.sv` — platform-level interrupt controller

Spec: RISC-V PLIC specification
([riscv-plic.adoc](https://github.com/riscv/riscv-plic-spec/blob/master/riscv-plic.adoc)).
Plan block B7.6. Back to [index](../README.md).

## 1. Purpose and priority

Route device interrupts (here: UART, ID 10 as on QEMU `virt`) to two contexts:
context 0 = hart 0 M-mode → `MExtIrq` (`mip.MEIP`), context 1 = hart 0 S-mode →
`SExtIrq` (`mip.SEIP`).

**Not needed for the first shell.** The 8250 driver falls back to polling when the
DT UART node has no `interrupts` property (PLAN_B B7.6 note). Build it after the
first boot, keep the DT honest in the meantime.

## 2. Register map (offsets from base `0x0C00_0000`)

| Offset | Register | Notes |
|---|---|---|
| `0x000000` | source 0 priority | reserved — "An interrupt ID of 0 is reserved to mean 'no interrupt'" |
| `0x000004 + 4·(id−1)` | source *id* priority | "The priority value 0 is reserved to mean 'never interrupt'"; ties broken by lowest ID |
| `0x001000` | pending bits 0–31 | read-only (set by gateways) |
| `0x002000` | enable bits, context 0 | one bit per source |
| `0x002080` | enable bits, context 1 | stride `0x80` per context |
| `0x200000` | threshold, context 0 | "mask all PLIC interrupts of a priority less than or equal to threshold" |
| `0x200004` | claim/complete, context 0 | read = claim, write = complete |
| `0x201000` / `0x201004` | threshold / claim-complete, context 1 | stride `0x1000` |

Minimal sizing: `NSOURCES = 31` (one enable/pending word; DT `riscv,ndev = <31>`),
priority width 3 bits (WARL, upper bits read 0), 2 contexts.

## 3. Behaviour

- **Gateway** (level-sensitive, per source): when the device line is high and the
  source is not "in flight", set its pending bit. After a claim the gateway forwards
  nothing more for that source until the matching complete ("The gateway will only
  forward additional interrupts to the PLIC core after receiving the completion
  message").
- **Notification**: context *c* asserts its EIP line iff some source is pending ∧
  enabled for *c* ∧ priority > threshold(*c*).
- **Claim** (read): returns the ID of the highest-priority pending enabled source
  for that context — "not affected by the setting of the priority threshold" — and
  atomically clears its pending bit; 0 if none.
- **Complete** (write ID): releases the gateway. "If the completion ID does not
  match an interrupt source that is currently enabled for the target, the completion
  is silently ignored."
- Claim reads have a side effect → the region must be **uncached** (and never
  speculatively read — automatic on this in-order blocking core).

## 4. Ports

AXI4 slave (same port list as `Design/risc_data_memory.sv`), plus:

```
parameter int NSOURCES = 31;
input  logic [NSOURCES:1] IrqSources,   // level-sensitive device lines (UART = bit 10)
output logic              MExtIrq,      // context 0
output logic              SExtIrq       // context 1
```

## 5. Integration

- `MExtIrq` → `mip.MEIP`; `SExtIrq` OR-ed with the software-writable SEIP bit →
  `mip.SEIP` ([PRIV_ARCH](../PRIV_ARCH.md) §2.3).
- DT: `compatible = "riscv,plic0"`, `interrupts-extended = <&cpu0_intc 11>,
  <&cpu0_intc 9>`, `riscv,ndev = <31>`; OpenSBI's irqchip driver matches
  `riscv,plic0` (`fdt_irqchip_plic.c`,
  [OpenSBI](https://github.com/riscv-software-src/opensbi/tree/master/lib/utils/irqchip)).
  Linux selects `SIFIVE_PLIC` unconditionally on RISC-V
  ([Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig)).

## 6. Verification hooks

- `Verification/Plic/` env with RAL (frontdoor) and a reference model written from
  §3 (pending/claim/complete state per source and per context).
- Sequences: two sources same priority (lowest ID wins), claim with nothing pending
  (returns 0), complete with a wrong ID (ignored), threshold = max (no EIP but claim
  still works), level held across complete (re-pends).
- SVA: EIP ⇔ (∃ pending ∧ enabled ∧ prio > threshold).
