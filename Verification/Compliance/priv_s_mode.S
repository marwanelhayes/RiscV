# Directed B4 test: S-mode CSRs and their reset/WARL behaviour, medeleg/mideleg, trap
# delegation (S handler vs M handler, SPP/SPIE/SIE/sepc/scause/stval), SRET (to S, to U,
# TSR, MPRV), scounteren/mcounteren counter gates, WFI in S, software SSIP/STIP/SEIP through
# mip/sip, the S/M interrupt arbitration matrix, vectored stvec/mtvec. Ends with a store to
# tohost: 1 = pass, (n << 1) | 1 = check n failed (n counts the checks in source order).
# The M handler (mtrap) records mcause/mstatus/mtval in s1/s2/s3 and s5 = 1; the S handler
# (strap) records scause/sstatus/stval/sepc in s1/s2/s3/s4 and s5 = 2. Sync traps skip the
# instruction; ECALL from U/S (non-delegated) and any trap with s7 != 0 return to M. An
# interrupt clears the software mip bits (M) or its sie bits (S) so it is taken once. No
# interrupt line is driven in this test.

#define MPP   0x1800
#define MPRV  0x20000
#define TW    0x200000
#define TSR   0x400000
#define SPP   0x100
#define SIE   0x2
#define MIE   0x8
#define MPIE  0x80
#define SOFT  0x222

#define N li t3, ((__COUNTER__) << 1) | 1
# run the instructions, expect cause (0 = no trap)
#define TRAPS(cause, ...) li s1, 0; __VA_ARGS__; N; li t0, cause; bne s1, t0, fail
# the last trap was taken by handler h (1 = M, 2 = S)
#define HAND(h) N; li t0, h; bne s5, t0, fail
#define EQ(a, b) N; bne a, b, fail
# CSR write then read back
#define WR(csr, w, r) li t0, w; csrw csr, t0; csrr t0, csr; li t1, r; EQ(t0, t1)
# (s2 & mask) == v
#define S2(mask, v) li t0, mask; and t0, s2, t0; li t1, v; EQ(t0, t1)
# MRET to the next instruction in S / U (MPIE = 0: MIE = 0 there)
#define TO_S jal ra, to_s
#define TO_U jal ra, to_u
# an illegal word that the M handler answers by returning to M
#define BACK_M li s7, 1; .word 0
#define CLEAN csrw mie, zero; li t0, SOFT; csrc mip, t0; csrw mideleg, zero; csrw medeleg, zero; \
              li t0, TW | TSR | SPP | SIE | MIE | MPIE; csrc mstatus, t0
# interrupt matrix row: bit, cause, delegated, mode (0 M, 1 S, 2 U), SIE, MIE, handler that takes it (0 none)
#define ROW(bit, cause, dl, mode, sie, mi, h) .half bit; .byte cause, dl, mode, sie, mi, h
#define GROUP(bit, cause) \
    ROW(bit, cause, 1, 1, 1, 0, 2); ROW(bit, cause, 1, 1, 0, 0, 0); ROW(bit, cause, 1, 2, 0, 0, 2); \
    ROW(bit, cause, 1, 0, 1, 1, 0); ROW(bit, cause, 1, 0, 1, 0, 0); ROW(bit, cause, 0, 1, 0, 0, 1); \
    ROW(bit, cause, 0, 0, 0, 0, 0); ROW(bit, cause, 0, 0, 0, 1, 1); ROW(bit, cause, 0, 2, 0, 0, 1)

    .section .text.init, "ax", @progbits
    .globl _start
_start:
    la t0, mtrap
    csrw mtvec, t0

    # Reset values (FS = Off: sstatus shows only UXL on RV64)
#if __riscv_xlen == 64
    li t1, 0x200000000
#else
    li t1, 0
#endif
    csrr t0, sstatus
    EQ(t0, t1)
    csrr t0, medeleg
    EQ(t0, zero)
    csrr t0, mideleg
    EQ(t0, zero)
    csrr t0, stvec
    EQ(t0, zero)
    csrr t0, satp
    EQ(t0, zero)

    # WARL: medeleg keeps bits 0-9 and 19, mideleg SSIP/STIP/SEIP, scounteren 2:0, stvec bit 1 clear
    WR(medeleg, -1, 0x803FF)
    WR(mideleg, -1, 0x222)
    WR(scounteren, -1, 7)
    WR(stvec, -1, -3)
    WR(satp, -1, 0)
    WR(senvcfg, -1, 0)
#if __riscv_xlen == 32
    WR(medelegh, -1, 0)
#endif
    WR(sepc, -1, -4)           # sepc drops bits 1:0
    csrw medeleg, zero
    csrw mideleg, zero
    csrw scounteren, zero
    csrw stvec, zero
    csrw sepc, zero

    # sstatus is a view: SIE, SPIE, SPP, FS, SD (+UXL); a write leaves the M fields alone
    li t0, -1
    csrw sstatus, t0
    csrr t0, sstatus
#if __riscv_xlen == 64
    li t1, 0x8000000200006122
#else
    li t1, 0x80006122
#endif
    EQ(t0, t1)
    csrr t0, mstatus
    li t1, MPP | MIE | MPIE | TW | TSR
    and t0, t0, t1
    EQ(t0, zero)
    csrw sstatus, zero

    # mie/sie: sie shows (and writes) only the delegated bits
    li t0, -1
    csrw mie, t0
    csrr t0, sie
    EQ(t0, zero)
    csrwi mideleg, 2
    csrr t0, sie
    li t1, 2
    EQ(t0, t1)
    csrw mie, zero
    li t0, -1
    csrw sie, t0
    csrr t0, mie
    EQ(t0, t1)
    li t0, 0x222
    csrw mideleg, t0
    csrw sie, t0
    csrr t1, mie
    EQ(t1, t0)
    csrw mideleg, zero
    csrw sie, zero             # nothing delegated: no change
    csrr t1, mie
    EQ(t1, t0)
    csrr t1, sie
    EQ(t1, zero)
    csrw mie, zero

    # mip/sip: software bits SSIP, STIP, SEIP; sip writes SSIP only, and only if delegated
    li t0, SOFT
    csrs mip, t0
    csrr t1, mip
    EQ(t1, t0)
    csrr t1, sip
    EQ(t1, zero)
    csrw mideleg, t0
    csrr t1, sip
    EQ(t1, t0)
    csrc sip, t0
    csrr t1, mip
    li t0, 0x220
    EQ(t1, t0)
    csrw mideleg, zero
    csrs sip, SIE
    csrr t1, mip
    EQ(t1, t0)
    csrwi mideleg, 2
    csrs sip, SIE
    csrr t1, mip
    li t0, 0x222
    EQ(t1, t0)
    CLEAN

    # Delegated traps: illegal (2), breakpoint (3), misaligned load (4), ECALL from U (8)
    la t0, strap
    csrw stvec, t0
    li t0, 0x11C
    csrw medeleg, t0
    csrs mstatus, SIE
    TO_S
    TRAPS(2, 8: csrr t0, mscratch)
    HAND(2)
    S2(0x122, 0x120)           # SIE <- 0, SPIE <- 1, SPP <- S
    EQ(s3, zero)
    la t0, 8b
    EQ(s4, t0)
    TRAPS(4, la t0, dat; addi t0, t0, 1; lw t1, 0(t0))
    HAND(2)
    la t1, dat
    addi t1, t1, 1
    EQ(s3, t1)
    TRAPS(3, ebreak)
    HAND(2)
    # not delegated: store misaligned (6) and ECALL from S (9) go to M with MPP = S
    TRAPS(6, la t0, dat; addi t0, t0, 1; sw t1, 0(t0))
    HAND(1)
    la t1, dat
    addi t1, t1, 1
    EQ(s3, t1)
    TRAPS(9, ecall)
    HAND(1)
    S2(MPP, 0x800)
    # U: delegated illegal and ECALL land in S with SPP = U; the S handler resumes S after the ECALL
    csrs mstatus, SIE
    TO_U
    TRAPS(2, csrr t0, mstatus)
    HAND(2)
    S2(0x122, 0x20)            # SIE <- 0, SPIE <- 1, SPP = U
    TRAPS(8, ecall)
    HAND(2)
    S2(SPP, 0)
    TRAPS(9, ecall)            # back in S, not U
    HAND(1)
    # M traps ignore medeleg
    li t0, -1
    csrw medeleg, t0
    TRAPS(11, ecall)
    HAND(1)
    TRAPS(2, .word 0)
    HAND(1)
    # delegated ECALL from S (medeleg[9]) lands in S
    li t0, 0x200
    csrw medeleg, t0
    TO_S
    TRAPS(9, ecall)
    HAND(2)
    S2(SPP, SPP)
    BACK_M
    CLEAN

    # SRET: S -> S (SIE <- SPIE, SPIE <- 1, SPP <- 0), S -> U, in U it traps
    TO_S
    li t0, SPP | 0x20
    csrs sstatus, t0
    csrc sstatus, SIE
    la t0, 2f
    csrw sepc, t0
    sret
2:  csrr t1, sstatus
    li t0, 0x122
    and t1, t1, t0
    li t0, 0x22
    EQ(t1, t0)
    li t0, 0x20
    csrc sstatus, t0
    la t0, 3f
    csrw sepc, t0
    sret
3:  TRAPS(8, ecall)        # in U
    HAND(1)
    TO_U
    TRAPS(2, sret)
    HAND(1)
    ecall
    # TSR: SRET in S traps, in M it works and clears MPRV and SPP
    li t0, TSR
    csrs mstatus, t0
    csrr t1, mstatus
    and t1, t1, t0
    EQ(t1, t0)
    TO_S
    TRAPS(2, sret)
    HAND(1)
    ecall
    li t0, MPRV | SPP
    csrs mstatus, t0
    la t0, 4f
    csrw sepc, t0
    sret
4:  TRAPS(9, ecall)
    S2(MPRV | SPP, 0)
    CLEAN

    # Counter gate: S needs mcounteren, U needs mcounteren and scounteren
    csrwi mcounteren, 7
    csrwi scounteren, 0
    TO_S
    TRAPS(0, rdcycle a0; rdtime a0; rdinstret a0)
    ecall
    TO_U
    TRAPS(2, rdcycle a0)
    TRAPS(2, rdtime a0)
    TRAPS(2, rdinstret a0)
    ecall
    csrwi mcounteren, 0
    csrwi scounteren, 7
    TO_S
    TRAPS(2, rdcycle a0)
    TRAPS(2, rdinstret a0)
    ecall
    TO_U
    TRAPS(2, rdtime a0)
    ecall
    csrwi mcounteren, 7
    csrwi scounteren, 5
    TO_U
    TRAPS(0, rdcycle a0; rdinstret a0)
    TRAPS(2, rdtime a0)
#if __riscv_xlen == 32
    TRAPS(0, rdcycleh a0; rdinstreth a0)
    TRAPS(2, rdtimeh a0)
#endif
    TRAPS(2, csrr a0, sstatus)       # S CSR in U
    ecall
    csrw mcounteren, zero
    csrw scounteren, zero

    # WFI: legal in S (TW = 0; wakes on a pending enabled bit with SIE = 0), traps with TW = 1
    csrwi mideleg, 2
    csrwi mie, 2
    csrwi mip, 2
    TO_S
    TRAPS(0, wfi)
    ecall
    CLEAN
    li t0, TW
    csrs mstatus, t0
    TO_S
    TRAPS(2, wfi)
    HAND(1)
    ecall
    CLEAN

    # Interrupt matrix (itab, in .data)
    la s8, itab
    la s9, itab_end
iloop:
    lhu a0, 0(s8)           # bit
    lbu a6, 2(s8)           # cause
    lbu a1, 3(s8)           # delegated
    lbu a2, 4(s8)           # mode
    lbu a3, 5(s8)           # SIE
    lbu a4, 6(s8)           # MIE
    lbu a5, 7(s8)           # handler
    li s1, 0
    li s5, 0
    csrw mie, a0
    neg a1, a1
    and a1, a1, a0
    csrw mideleg, a1
    slli a3, a3, 1
    slli a4, a4, 3
    or a3, a3, a4
    csrs mstatus, a3
    csrs mip, a0            # an M-routed bit with MIE = 1 in M is taken here
    beqz a2, imode
    addi t0, a2, -1
    beqz t0, imode_s
    TO_U
    j imode
imode_s:
    TO_S
imode:
    nop
    la t0, itab
    sub t3, s8, t0
    srli t3, t3, 3
    addi t3, t3, 100
    slli t3, t3, 1
    ori t3, t3, 1
    beqz a5, inone
    srli t0, s1, __riscv_xlen - 1
    li t1, 1
    bne t0, t1, fail
    slli t0, s1, 1
    srli t0, t0, 1
    bne t0, a6, fail
    bne s5, a5, fail
    j inext
inone:
    bnez s5, fail
inext:
    ecall
    CLEAN
    addi s8, s8, 8
    bne s8, s9, iloop

    # Delegated SSIP in S with SIE = 0 is taken once SIE is set; sstatus at entry: SIE 0, SPIE 1, SPP S
    csrwi mideleg, 2
    csrwi mie, 2
    csrwi mip, 2
    TO_S
    TRAPS(0, nop)
    csrs sstatus, SIE
    nop
    HAND(2)
    S2(0x122, 0x120)
    ecall
    CLEAN

    # A M-routed STIP beats a delegated SEIP
    li t0, 0x200
    csrw mideleg, t0
    li t0, 0x220
    csrw mie, t0
    csrs mstatus, SIE
    csrs mip, t0
    li s1, 0
    li s5, 0
    TO_S
    nop
    HAND(1)
    slli t0, s1, 1
    srli t0, t0, 1
    li t1, 5
    EQ(t0, t1)
    ecall
    CLEAN

    # Vectored stvec (interrupts at base + 4 * cause, exceptions at the base) and mtvec
    la t0, svec
    addi t0, t0, 3             # mode bit 1 is cleared: vectored
    csrw stvec, t0
    csrr t1, stvec
    addi t0, t0, -2
    EQ(t1, t0)
    li t0, 0x20
    csrw mie, t0
    csrw mideleg, t0
    csrs mstatus, SIE
    csrs mip, t0
    li t0, 4
    csrw medeleg, t0
    li s6, 0
    TO_S
    nop
    la t0, svec
    addi t0, t0, 24            # slot 5 (+4: jal links the next address)
    EQ(s6, t0)
    li s6, 0
    TRAPS(2, .word 0)
    la t0, svec
    addi t0, t0, 4
    EQ(s6, t0)
    ecall
    CLEAN
    la t0, strap
    csrw stvec, t0
    la t0, mvec
    addi t0, t0, 1
    csrw mtvec, t0
    li t0, 2
    csrw mie, t0
    csrs mip, t0
    li s6, 0
    TO_S
    nop
    la t0, mvec
    addi t0, t0, 8             # slot 1
    EQ(s6, t0)
    ecall
    CLEAN
    la t0, mtrap
    csrw mtvec, t0

    li t3, 1
fail:
    la t0, tohost
    sw t3, 0(t0)
1:  j 1b

to_s:
    li t0, MPP | MPIE
    csrc mstatus, t0
    li t0, 0x800
    csrs mstatus, t0
    j to_m
to_u:
    li t0, MPP | MPIE
    csrc mstatus, t0
to_m:
    csrw mepc, ra
    mret

mtrap:
    csrr s1, mcause
    csrr s2, mstatus
    csrr s3, mtval
    li s5, 1
    bltz s1, mirq
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    li t0, 8
    beq s1, t0, mback
    li t0, 9
    beq s1, t0, mback
    beqz s7, 1f
    li s7, 0
mback:
    li t0, MPP
    csrs mstatus, t0
1:  mret
mirq:
    li t0, SOFT
    csrc mip, t0
    mret

strap:
    csrr s1, scause
    csrr s2, sstatus
    csrr s3, stval
    csrr s4, sepc
    li s5, 2
    bltz s1, sirq
    addi t0, s4, 4
    csrw sepc, t0
    li t0, 8
    bne s1, t0, 1f
    li t0, SPP
    csrs sstatus, t0
1:  sret
sirq:
    li t0, SOFT
    csrc sie, t0
    sret

    .balign 4
svec:
    .rept 6
    jal s6, strap
    .endr
mvec:
    .rept 2
    jal s6, mtrap
    .endr

    .section .tohost, "aw", @progbits
    .globl tohost
    .balign 8
tohost:
    .8byte 0
    .data
    .balign 8
dat:
    .8byte 0, 0
itab:
    GROUP(0x2, 1)
    GROUP(0x20, 5)
    GROUP(0x200, 9)
itab_end:
