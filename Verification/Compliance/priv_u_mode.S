# Directed B3 test: misa/mstatus reset values, mstatus WARL fields,
# mcounteren/menvcfg, MRET to U (clears MPRV) and to M (keeps it), and the
# U-mode checks (privilege, per-bit counter gate, read-only CSRs, menvcfg,
# MRET/SRET/WFI, ECALL causes). Ends with a store to
# tohost: 1 = pass, (n << 1) | 1 = check n failed.
# The handler records mcause in s1 and mstatus at entry in s2, skips the
# trapping instruction and returns to the trapping mode; ECALL from U returns
# to M. The checks never execute WFI with TW = 0 (no interrupt would wake it).

#define MPP   0x1800
#define MPRV  0x20000
#define TW    0x200000

# check n: run the instructions, expect mcause (0 = no trap)
#define TRAPS(n, cause, ...) li t3, ((n) << 1) | 1; li s1, 0; __VA_ARGS__; li t0, cause; bne s1, t0, fail
# check n: a == b
#define EQ(n, a, b) li t3, ((n) << 1) | 1; bne a, b, fail
# MRET to the next instruction in U-mode
#define TO_U li t0, MPP; csrc mstatus, t0; la t0, 1f; csrw mepc, t0; mret; 1:

    .section .text.init, "ax", @progbits
    .globl _start
_start:
    la t0, trap
    csrw mtvec, t0

    # Reset values
#if __riscv_xlen == 64
    li t1, 0x8000000000101121
    li t2, 0x8000000200006000
#else
    li t1, 0x40101121
    li t2, 0x80006000
#endif
    csrr t0, misa
    EQ(2, t0, t1)
    csrr t0, mstatus
    EQ(3, t0, t2)

    # MPP: 00/01/10/11 read back 00/00/00/11
    li t4, MPP
    .irp v, 0, 1, 2, 3
    csrc mstatus, t4
    li t1, \v << 11
    csrs mstatus, t1
    csrr t0, mstatus
    and t0, t0, t4
    li t1, (\v / 3) * MPP
    EQ(4 + \v, t0, t1)
    .endr

    # MPRV and TW are writable
    li t4, MPRV | TW
    csrs mstatus, t4
    csrr t0, mstatus
    and t0, t0, t4
    EQ(8, t0, t4)
    csrc mstatus, t4
    csrr t0, mstatus
    and t0, t0, t4
    EQ(9, t0, zero)

    # mcounteren keeps bits 2:0, menvcfg(h) read zero
    li t0, -1
    csrw mcounteren, t0
    csrr t0, mcounteren
    li t1, 7
    EQ(10, t0, t1)
    li t0, -1
    csrw menvcfg, t0
    csrr t0, menvcfg
    EQ(11, t0, zero)
#if __riscv_xlen == 32
    li t0, -1
    csrw menvcfgh, t0
    csrr t0, menvcfgh
    EQ(12, t0, zero)
#endif

    # MRET to U clears MPRV; ECALL from U gives 8 with MPP = U and returns to M
    li t0, MPRV
    csrs mstatus, t0
    TO_U
    TRAPS(13, 8, ecall)
    li t4, MPP
    and t0, s2, t4
    EQ(14, t0, zero)
    csrr t0, mstatus
    li t4, MPRV
    and t0, t0, t4
    EQ(15, t0, zero)

    # U-mode with mcounteren = 0: every counter traps
    csrw mcounteren, zero
    TO_U
    TRAPS(16, 2, rdcycle a0)
    TRAPS(17, 2, rdtime a0)
    TRAPS(18, 2, rdinstret a0)
#if __riscv_xlen == 32
    TRAPS(19, 2, rdcycleh a0)
    TRAPS(20, 2, rdtimeh a0)
    TRAPS(21, 2, rdinstreth a0)
#endif
    TRAPS(22, 8, ecall)

    # U-mode with mcounteren = 7: counters work, M CSRs, writes to counters,
    # MRET, SRET and WFI with TW = 1 trap, fflags works
    csrwi mcounteren, 7
    li t0, TW
    csrs mstatus, t0
    TO_U
    TRAPS(23, 0, rdcycle a0)
    TRAPS(24, 0, rdtime a0)
    TRAPS(25, 0, rdinstret a0)
#if __riscv_xlen == 32
    TRAPS(26, 0, rdcycleh a0)
    TRAPS(27, 0, rdtimeh a0)
    TRAPS(28, 0, rdinstreth a0)
#endif
    TRAPS(29, 2, csrr a0, mstatus)
    TRAPS(30, 2, csrw mscratch, a0)
    TRAPS(31, 2, csrr a0, mcounteren)
    TRAPS(32, 0, csrwi fflags, 1; csrr a0, fflags)
    li t1, 1
    EQ(33, a0, t1)
    TRAPS(34, 2, csrw cycle, zero)
    TRAPS(35, 2, mret)
    TRAPS(36, 2, sret)
    TRAPS(37, 2, wfi)
    TRAPS(38, 8, ecall)

    # ECALL from M gives 11 with MPP = M
    li t0, TW
    csrc mstatus, t0
    TRAPS(39, 11, ecall)
    li t4, MPP
    and t0, s2, t4
    EQ(40, t0, t4)

    # mcounteren = TM: only time works in U; menvcfg traps in U
    csrwi mcounteren, 2
    TO_U
    TRAPS(41, 2, rdcycle a0)
    TRAPS(42, 0, rdtime a0)
    TRAPS(43, 2, rdinstret a0)
#if __riscv_xlen == 32
    TRAPS(44, 2, rdcycleh a0)
    TRAPS(45, 0, rdtimeh a0)
    TRAPS(46, 2, rdinstreth a0)
#endif
    TRAPS(47, 2, csrr a0, menvcfg)
    TRAPS(48, 8, ecall)

    # mcounteren = CY | IR: time traps in U, cycle and instret work
    csrwi mcounteren, 5
    TO_U
    TRAPS(49, 0, rdcycle a0)
    TRAPS(50, 2, rdtime a0)
    TRAPS(51, 0, rdinstret a0)
#if __riscv_xlen == 32
    TRAPS(52, 0, rdcycleh a0)
    TRAPS(53, 2, rdtimeh a0)
    TRAPS(54, 0, rdinstreth a0)
#endif
    TRAPS(55, 8, ecall)

    # mcounteren = 0 does not gate M
    csrw mcounteren, zero
    TRAPS(56, 0, rdcycle a0; rdtime a0; rdinstret a0)
#if __riscv_xlen == 32
    TRAPS(57, 0, rdcycleh a0; rdtimeh a0; rdinstreth a0)
#endif

    # MRET with MPP = M keeps MPRV
    li t4, MPRV
    li t0, MPP | MPRV
    csrs mstatus, t0
    la t0, 2f
    csrw mepc, t0
    mret
2:  csrr t0, mstatus
    and t0, t0, t4
    EQ(58, t0, t4)
    csrc mstatus, t4

    li t3, 1
fail:
    la t0, tohost
    sw t3, 0(t0)
1:  j 1b

trap:
    csrr s1, mcause
    csrr s2, mstatus
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    li t0, 8
    bne s1, t0, 1f
    li t0, MPP
    csrs mstatus, t0
1:  mret

    .section .tohost, "aw", @progbits
    .globl tohost
    .balign 8
tohost:
    .8byte 0
