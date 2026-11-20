    .section .text.init, "ax", @progbits
    .globl _start
_start:
    li a1, 1
    li a2, 1
    li t3, 3
    jal ra, patched_next
    bne a0, a1, fail
    li t3, 5
    jal ra, patched_other
    bne a0, a1, fail

    lw t1, replacement
    la t0, patched_next
    sw t1, 0(t0)
    la t0, patched_other
    sw t1, 0(t0)

    # Before FENCE.I either encoding is legal: a1 and a2 produce the same result.
    li t3, 7
    jal ra, patched_next
    bne a0, a1, fail
    li a2, 2
    li t3, 9
    la ra, resume

    # Exercise refetch at PC+4 in the same cache line, including the ignored fields.
    .balign 32
    .word 0xabc4950f                 # fence.i with imm=0xabc, rs1=x9, rd=x10
patched_next:
    mv a0, a1
    ret
resume:
    bne a0, a2, fail
    li t3, 11
    jal ra, patched_other
    bne a0, a2, fail
    li t3, 1
fail:
    la t0, tohost
    sw t3, 0(t0)
1:  j 1b

    # A second cache line must also be written back and invalidated.
    .balign 32
patched_other:
    mv a0, a1
    ret
replacement:
    mv a0, a2

    .section .tohost, "aw", @progbits
    .globl tohost
    .balign 8
tohost:
    .8byte 0
