#   ======================= A RISCV RANDOM TEST CASES GENERATOR ======================    #
#   Generates a random RISC-V program in the standard encoding (RV32 or RV64: I, M, A,   #
#   the implemented F subset, Zicsr, M/S/U-mode traps). The full-core testbench runs it    #
#   against the ISA golden model (Verification/Risc/riscv_iss_pkg.sv), so the program    #
#   needs no expected values of its own.                                                 #
#                           Authored by Amr Mohamed                                       #
#
# Program layout
#   0x000    : JAL x0, start
#   0x004    : trap handler - skips the trapping instruction for exceptions,
#              returns to the interrupted one for interrupts (clearing the
#              software mip bits), then MRET; an ECALL from U or S (mcause 8/9)
#              clears medeleg and returns to M, every other trap to the mode
#              it came from
#   stab     : S handler (stvec target; vectored slots all jump to it) - sepc += 4 for
#              exceptions, SPP <- S for ECALL from U, SIE bit cleared for interrupts, SRET
#   start    : prologue - mtvec <- 0x004, stvec <- stab, data base pointer, random GPR/FPR
#              values, FS = Initial, frm, optional interrupt enables
#   body     : random instructions and small templates (forward branches/jumps,
#              JALR, counted loops, loads/stores around the data base pointer,
#              atomics (AMO*, LR/SC pairs, lone SCs) through the AMO address register,
#              ECALL/EBREAK, illegal encodings and misaligned accesses that trap,
#              mstatus MPP/MPRV/TW writes, WFI after enabling a wake source (MIE 0 or 1),
#              U-mode windows: MRET to U, user code (counter reads under a
#              random mcounteren, M-CSR accesses, MRET/SRET/WFI), ECALL back;
#              S-mode windows: random medeleg/mideleg/stvec mode/mie/mip, MPP = S,
#              MRET to S, S code (S CSRs, counter reads, SRET, WFI, traps), ECALL back;
#              FS = Off windows: FP instructions and fcsr accesses that must trap)
#   end      : JAL x0, 0 (self-loop; the testbench stops when it commits)
#
# Outputs (in Program/Dump/ unless --out-dir is given):
#   binary1.txt       one 32-bit instruction per line ($readmemb format)
#   hex1.v            little-endian bytes ($readmemh format)
#   assembly1.s       address / hex / assembly listing
#   program_info.txt  number of instruction words
#
# Usage: python3 riscv_testcase_generator.py [--xlen 32|64] [--count N] [--seed S]
#                                            [--no-interrupts] [--no-fp] [--out-dir DIR]

import argparse
import os
import random

# Registers reserved for the templates and the trap handler
BASE_REG = 27      # data base pointer (never overwritten by random code)
LOOP_REG = 26      # loop counter
JALR_REG = 25      # JALR target scratch
AMO_REG = 24       # atomic address (atomics have no offset)
HANDLER_REGS = (28, 29, 30)
S_HANDLER_REGS = (22, 23)     # the S handler can be preempted by the M handler, so it has its own
RESERVED = {0, BASE_REG, LOOP_REG, JALR_REG, AMO_REG, *HANDLER_REGS, *S_HANDLER_REGS}
FREE_GPRS = [r for r in range(1, 32) if r not in RESERVED]

MEM_BYTES = 4096
HANDLER_ADDR = 0x4

# CSR groups (addresses)
S_CSRS = [0x100, 0x104, 0x106, 0x10A, 0x140, 0x141, 0x142, 0x143, 0x144, 0x180]
RW_CSRS = [0x340, 0x343, 0x342, 0x341, 0x300, 0x304, 0x001, 0xB00, 0xB02,
           0x301, 0x344, 0x302, 0x303, 0xB03, 0xB1F, 0x323, 0x33F, 0x306, 0x30A,
           0x105] + S_CSRS
RW_CSRS_RV32 = [0xB80, 0xB82, 0x310, 0xB83, 0x31A, 0x312]
READ_ONLY_FORM = (0x105, 0x302, 0x303)    # stvec/medeleg/mideleg are written only by the S window (a stray
                                          # value would send a trap to a wild address or loop the handler)
READ_ONLY_CSRS = [0xC00, 0xC01, 0xC02, 0xF11, 0xF12, 0xF13, 0xF14]
READ_ONLY_CSRS_RV32 = [0xC80, 0xC81, 0xC82]
UNKNOWN_CSRS = [0x7C0, 0x5C0, 0x5A8, 0x3A0, 0x7B0, 0x320, 0xB20]
M_CSRS = [c for c in RW_CSRS + READ_ONLY_CSRS if (c >> 8) & 3 == 3]     # illegal in U
M_CSRS_RV32 = [c for c in RW_CSRS_RV32 if (c >> 8) & 3 == 3]
MSTATUS_MPP = 0x1800
MSTATUS_FS = 0x6000
TSR = 0x400000
MEDELEG_MASK = 0x000803FF & ~(1 << 9)    # S ECALL is never delegated: the window always ends in M


def bits(value, width):
    return format(value & ((1 << width) - 1), '0{}b'.format(width))


class Program:
    def __init__(self):
        self.words = []          # list of [binary string, assembly]
        self.fixups = []         # (index, build(offset) -> (bin, asm), label)
        self.labels = {}

    def emit(self, binary, asm):
        assert len(binary) == 32 and set(binary) <= {'0', '1'}, (binary, asm)
        self.words.append([binary, asm])

    def emit_fixup(self, label, build):
        self.fixups.append((len(self.words), build, label))
        self.words.append(None)

    def label(self, name):
        self.labels[name] = len(self.words)

    def resolve(self):
        for index, build, label in self.fixups:
            offset = 4 * (self.labels[label] - index)
            self.words[index] = list(build(offset))


# ── Encoders ──────────────────────────────────────────────────────────────────
def r_type(f7, rs2, rs1, f3, rd, op):
    return bits(f7, 7) + bits(rs2, 5) + bits(rs1, 5) + bits(f3, 3) + bits(rd, 5) + bits(op, 7)


def i_type(imm, rs1, f3, rd, op):
    return bits(imm, 12) + bits(rs1, 5) + bits(f3, 3) + bits(rd, 5) + bits(op, 7)


def s_type(imm, rs2, rs1, f3, op):
    v = imm & 0xFFF
    return bits(v >> 5, 7) + bits(rs2, 5) + bits(rs1, 5) + bits(f3, 3) + bits(v, 5) + bits(op, 7)


def b_type(imm, rs2, rs1, f3):
    v = imm & 0x1FFF
    return (bits(v >> 12, 1) + bits(v >> 5, 6) + bits(rs2, 5) + bits(rs1, 5) + bits(f3, 3) +
            bits(v >> 1, 4) + bits(v >> 11, 1) + '1100011')


def u_type(imm20, rd, op):
    return bits(imm20, 20) + bits(rd, 5) + bits(op, 7)


def amo_type(f5, rs2, rs1, f3, rd, aq=0, rl=0):
    return r_type((f5 << 2) | (aq << 1) | rl, rs2, rs1, f3, rd, AMO_OP)


def j_type(imm, rd):
    v = imm & 0x1FFFFF
    return (bits(v >> 20, 1) + bits(v >> 1, 10) + bits(v >> 11, 1) + bits(v >> 12, 8) +
            bits(rd, 5) + '1101111')


OP_IMM, OP, OP_IMM_32, OP_32 = 0b0010011, 0b0110011, 0b0011011, 0b0111011
LOAD, STORE, JALR_OP = 0b0000011, 0b0100011, 0b1100111
LUI_OP, AUIPC_OP, SYSTEM, MISC_MEM, OP_FP = 0b0110111, 0b0010111, 0b1110011, 0b0001111, 0b1010011
AMO_OP = 0b0101111

R_OPS = {'ADD': (0, 0), 'SUB': (0x20, 0), 'SLL': (0, 1), 'SLT': (0, 2), 'SLTU': (0, 3), 'XOR': (0, 4),
         'SRL': (0, 5), 'SRA': (0x20, 5), 'OR': (0, 6), 'AND': (0, 7),
         'MUL': (1, 0), 'MULH': (1, 1), 'MULHSU': (1, 2), 'MULHU': (1, 3),
         'DIV': (1, 4), 'DIVU': (1, 5), 'REM': (1, 6), 'REMU': (1, 7)}
W_OPS = {'ADDW': (0, 0), 'SUBW': (0x20, 0), 'SLLW': (0, 1), 'SRLW': (0, 5), 'SRAW': (0x20, 5),
         'MULW': (1, 0), 'DIVW': (1, 4), 'DIVUW': (1, 5), 'REMW': (1, 6), 'REMUW': (1, 7)}
I_OPS = {'ADDI': 0, 'SLTI': 2, 'SLTIU': 3, 'XORI': 4, 'ORI': 6, 'ANDI': 7}
BRANCHES = {'BEQ': 0, 'BNE': 1, 'BLT': 4, 'BGE': 5, 'BLTU': 6, 'BGEU': 7}
LOADS = {'LB': (0, 1), 'LH': (1, 2), 'LW': (2, 4), 'LBU': (4, 1), 'LHU': (5, 2)}
STORES = {'SB': (0, 1), 'SH': (1, 2), 'SW': (2, 4)}
LOADS64 = {'LD': (3, 8), 'LWU': (6, 4)}
STORES64 = {'SD': (3, 8)}
CSR_OPS = {'CSRRW': 1, 'CSRRS': 2, 'CSRRC': 3, 'CSRRWI': 5, 'CSRRSI': 6, 'CSRRCI': 7}
FP_ARITH = {'FADD.S': 0b0000000, 'FSUB.S': 0b0000100, 'FMUL.S': 0b0001000, 'FDIV.S': 0b0001100}
FP_SGNJ = {'FSGNJ.S': 0, 'FSGNJN.S': 1, 'FSGNJX.S': 2}
FP_MINMAX = {'FMIN.S': 0, 'FMAX.S': 1}
FP_CMP = {'FEQ.S': 2, 'FLT.S': 1, 'FLE.S': 0}
ROUND_MODES = [0, 1, 2, 3, 4, 7]   # 7 = DYN (frm only ever holds 0..4)
AMO_OPS = {'AMOADD': 0b00000, 'AMOSWAP': 0b00001, 'AMOXOR': 0b00100, 'AMOOR': 0b01000, 'AMOAND': 0b01100,
           'AMOMIN': 0b10000, 'AMOMAX': 0b10100, 'AMOMINU': 0b11000, 'AMOMAXU': 0b11100}
LR_F5, SC_F5 = 0b00010, 0b00011


class Generator:
    def __init__(self, xlen, count, interrupts, fp=True):
        self.p = Program()
        self.xlen = xlen
        self.count = count
        self.interrupts = interrupts
        self.fp = fp
        self.in_loop = False
        self.stored = []         # (offset, size) of earlier stores, reused by loads

    # ── helpers ───────────────────────────────────────────────────────────────
    def reg(self):
        return random.choice(FREE_GPRS)

    def src(self):
        # Mostly registers in use, sometimes x0 or the base pointer (read only)
        return random.choice(FREE_GPRS + [0, BASE_REG])

    def li(self, rd, value):
        """Load a sign-extended 32-bit constant with LUI + ADDI."""
        value &= 0xFFFFFFFF
        lo = value & 0xFFF
        if lo & 0x800:
            lo -= 0x1000
        hi = ((value - lo) >> 12) & 0xFFFFF
        self.p.emit(u_type(hi, rd, LUI_OP), 'LUI x{}, 0x{:x}'.format(rd, hi))
        self.p.emit(i_type(lo, rd, 0, rd, OP_IMM), 'ADDI x{}, x{}, {}'.format(rd, rd, lo))

    def interesting(self):
        return random.choice([0, 1, -1, 0x7FFFFFFF, -0x80000000, 0xFFFF, 0x8000, 0x7F, 0x80,
                              random.getrandbits(32), random.getrandbits(32), random.randint(-64, 64),
                              # IEEE single corner patterns (FMV.W.X puts them in FP registers)
                              0x7FC00000, 0x7FA00001, 0xFF800000, 0x7F800000, 0x80000000,
                              0x00000001, 0x807FFFFF, 0x3F800000, 0xBF800000, 0x4B000000])

    # ── instruction emitters ─────────────────────────────────────────────────
    def emit_alu(self):
        kind = random.random()
        if kind < 0.02:
            f7 = random.choice([0b0000010, 0b0000100, 0b0100001, 0b1000000, 0b0010000])
            rd, rs1, rs2 = self.reg(), self.src(), self.src()
            self.p.emit(r_type(f7, rs2, rs1, random.randint(0, 7), rd, OP),
                        'ILLEGAL (R-type funct7 {:07b})'.format(f7))
        elif kind < 0.35:
            name = random.choice(list(R_OPS))
            f7, f3 = R_OPS[name]
            rd, rs1, rs2 = self.reg(), self.src(), self.src()
            self.p.emit(r_type(f7, rs2, rs1, f3, rd, OP), '{} x{}, x{}, x{}'.format(name, rd, rs1, rs2))
        elif kind < 0.60:
            name = random.choice(list(I_OPS))
            rd, rs1, imm = self.reg(), self.src(), random.randint(-2048, 2047)
            self.p.emit(i_type(imm, rs1, I_OPS[name], rd, OP_IMM), '{} x{}, x{}, {}'.format(name, rd, rs1, imm))
        elif kind < 0.75:
            name = random.choice(['SLLI', 'SRLI', 'SRAI'])
            rd, rs1 = self.reg(), self.src()
            shamt = random.randint(0, self.xlen - 1)
            hi = 0x400 if name == 'SRAI' else 0
            f3 = 1 if name == 'SLLI' else 5
            self.p.emit(i_type(hi | shamt, rs1, f3, rd, OP_IMM), '{} x{}, x{}, {}'.format(name, rd, rs1, shamt))
        elif kind < 0.85 or self.xlen == 32:
            name = random.choice(['LUI', 'AUIPC'])
            rd, imm = self.reg(), random.getrandbits(20)
            op = LUI_OP if name == 'LUI' else AUIPC_OP
            self.p.emit(u_type(imm, rd, op), '{} x{}, 0x{:x}'.format(name, rd, imm))
        elif random.random() < 0.5:
            name = random.choice(list(W_OPS))
            f7, f3 = W_OPS[name]
            rd, rs1, rs2 = self.reg(), self.src(), self.src()
            self.p.emit(r_type(f7, rs2, rs1, f3, rd, OP_32), '{} x{}, x{}, x{}'.format(name, rd, rs1, rs2))
        else:
            name = random.choice(['ADDIW', 'SLLIW', 'SRLIW', 'SRAIW'])
            rd, rs1 = self.reg(), self.src()
            if name == 'ADDIW':
                imm = random.randint(-2048, 2047)
                self.p.emit(i_type(imm, rs1, 0, rd, OP_IMM_32), 'ADDIW x{}, x{}, {}'.format(rd, rs1, imm))
            else:
                shamt = random.randint(0, 31)
                hi = 0x400 if name == 'SRAIW' else 0
                f3 = 1 if name == 'SLLIW' else 5
                self.p.emit(i_type(hi | shamt, rs1, f3, rd, OP_IMM_32),
                            '{} x{}, x{}, {}'.format(name, rd, rs1, shamt))

    def emit_mem(self, allow_traps=True):
        loads = dict(LOADS, **(LOADS64 if self.xlen == 64 else {}))
        stores = dict(STORES, **(STORES64 if self.xlen == 64 else {}))
        is_store = random.random() < 0.5
        name = random.choice(list(stores if is_store else loads))
        f3, size = (stores if is_store else loads)[name]
        offset = random.randrange(-self.data_bytes, 0, size)
        if not is_store and self.stored and random.random() < 0.7:
            # Read back (part of) an earlier store so sub-word extraction is visible
            base, ssize = random.choice(self.stored)
            if size <= ssize:
                offset = base + size * random.randrange(ssize // size)
            else:
                offset = base - (base % size)
        if is_store:
            self.stored.append((offset, size))
        if allow_traps and size > 1 and random.random() < 0.05:
            offset += random.randint(1, size - 1)          # misaligned: traps
        if is_store:
            rs2 = self.src()
            self.p.emit(s_type(offset, rs2, BASE_REG, f3, STORE),
                        '{} x{}, {}(x{})'.format(name, rs2, offset, BASE_REG))
        else:
            rd = self.reg()
            self.p.emit(i_type(offset, BASE_REG, f3, rd, LOAD),
                        '{} x{}, {}(x{})'.format(name, rd, offset, BASE_REG))

    def emit_atomic(self, budget, allow_traps=True):
        """ADDI x24 = base + offset, then an AMO*, an LR ... SC pair or a lone SC."""
        if budget < 4:
            return 0
        size = 8 if (self.xlen == 64 and random.random() < 0.4) else 4
        f3, sfx = (3, '.D') if size == 8 else (2, '.W')
        offset = random.randrange(-self.data_bytes, 0, size)
        if self.stored and random.random() < 0.5:
            base, _ = random.choice(self.stored)
            offset = base - (base % size)              # hit data written earlier
        misaligned = allow_traps and random.random() < 0.05
        if misaligned:
            offset += random.randint(1, size - 1)      # traps (load/store-misaligned)
        else:
            self.stored.append((offset, size))
        p = self.p
        p.emit(i_type(offset, BASE_REG, 0, AMO_REG, OP_IMM), 'ADDI x{}, x{}, {}'.format(AMO_REG, BASE_REG, offset))
        n = 1
        aq, rl = random.getrandbits(1), random.getrandbits(1)
        roll = random.random()
        if roll < 0.6:
            name = random.choice(list(AMO_OPS))
            rd, rs2 = self.reg(), self.src()
            p.emit(amo_type(AMO_OPS[name], rs2, AMO_REG, f3, rd, aq, rl),
                   '{}{} x{}, x{}, (x{})'.format(name, sfx, rd, rs2, AMO_REG))
            return n + 1
        if roll < 0.9:
            rd = self.reg()
            p.emit(amo_type(LR_F5, 0, AMO_REG, f3, rd, aq, rl), 'LR{} x{}, (x{})'.format(sfx, rd, AMO_REG))
            n += 1
            for _ in range(random.randint(0, 2)):      # constrained LR/SC loop body
                self.emit_alu()
                n += 1
            if random.random() < 0.2:                  # SC to another address: fails
                p.emit(i_type(size, AMO_REG, 0, AMO_REG, OP_IMM), 'ADDI x{}, x{}, {}'.format(AMO_REG, AMO_REG, size))
                n += 1
        rd, rs2 = self.reg(), self.src()
        p.emit(amo_type(SC_F5, rs2, AMO_REG, f3, rd, aq, rl), 'SC{} x{}, x{}, (x{})'.format(sfx, rd, rs2, AMO_REG))
        return n + 1

    def emit_csr(self):
        rd = self.reg()
        name = random.choice(list(CSR_OPS))
        f3 = CSR_OPS[name]
        roll = random.random()
        if roll < 0.60:
            csr = random.choice(RW_CSRS + (RW_CSRS_RV32 if self.xlen == 32 else []))
        elif roll < 0.80:
            csr = random.choice(READ_ONLY_CSRS + (READ_ONLY_CSRS_RV32 if self.xlen == 32 else []))
        elif roll < 0.90:
            # frm/fcsr: only forms that keep frm a valid rounding mode (0..4)
            csr = random.choice([0x002, 0x003])
            name, f3 = random.choice([('CSRRWI', 5), ('CSRRS', 2), ('CSRRCI', 7)] +
                                     ([('CSRRSI', 6)] if csr == 0x003 else []))
            uimm = random.randint(0, 4) if (csr == 0x002 and f3 == 5) else random.randint(0, 31)
            rs1 = 0 if f3 == 2 else uimm
            self.p.emit(i_type(csr, rs1, f3, rd, SYSTEM), '{} x{}, 0x{:x}, {}'.format(name, rd, csr, rs1))
            return
        else:
            csr = random.choice(UNKNOWN_CSRS + (READ_ONLY_CSRS_RV32 + RW_CSRS_RV32 if self.xlen == 64 else []))
        rs1 = random.randint(0, 31) if f3 >= 5 else random.choice([0, self.src()])
        if csr in READ_ONLY_FORM:
            name, f3, rs1 = 'CSRRS', 2, 0
        self.p.emit(i_type(csr, rs1, f3, rd, SYSTEM), '{} x{}, 0x{:x}, {}'.format(name, rd, csr, rs1))
        if random.random() < 0.5:
            other = self.reg()
            self.p.emit(r_type(0, rd, rd, 0, other, OP), 'ADD x{}, x{}, x{}  (uses the CSR value)'.format(other, rd, rd))

    def emit_fp(self):
        roll = random.random()
        fd, fs1, fs2 = random.randint(0, 31), random.randint(0, 31), random.randint(0, 31)
        rm = random.choice(ROUND_MODES)
        if roll < 0.30:
            name = random.choice(list(FP_ARITH))
            self.p.emit(r_type(FP_ARITH[name], fs2, fs1, rm, fd, OP_FP),
                        '{} f{}, f{}, f{}, rm={}'.format(name, fd, fs1, fs2, rm))
        elif roll < 0.35:
            self.p.emit(r_type(0b0101100, 0, fs1, rm, fd, OP_FP), 'FSQRT.S f{}, f{}, rm={}'.format(fd, fs1, rm))
        elif roll < 0.45:
            name = random.choice(list(FP_SGNJ))
            self.p.emit(r_type(0b0010000, fs2, fs1, FP_SGNJ[name], fd, OP_FP),
                        '{} f{}, f{}, f{}'.format(name, fd, fs1, fs2))
        elif roll < 0.52:
            name = random.choice(list(FP_MINMAX))
            self.p.emit(r_type(0b0010100, fs2, fs1, FP_MINMAX[name], fd, OP_FP),
                        '{} f{}, f{}, f{}'.format(name, fd, fs1, fs2))
        elif roll < 0.62:
            name = random.choice(list(FP_CMP))
            rd = self.reg()
            self.p.emit(r_type(0b1010000, fs2, fs1, FP_CMP[name], rd, OP_FP),
                        '{} x{}, f{}, f{}'.format(name, rd, fs1, fs2))
        elif roll < 0.70:
            rd, unsigned = self.reg(), random.randint(0, 1)
            self.p.emit(r_type(0b1100000, unsigned, fs1, rm, rd, OP_FP),
                        'FCVT.W{}.S x{}, f{}, rm={}'.format('U' if unsigned else '', rd, fs1, rm))
        elif roll < 0.78:
            rs1, unsigned = self.src(), random.randint(0, 1)
            self.p.emit(r_type(0b1101000, unsigned, rs1, rm, fd, OP_FP),
                        'FCVT.S.W{} f{}, x{}, rm={}'.format('U' if unsigned else '', fd, rs1, rm))
        elif roll < 0.86:
            rd = self.reg()
            self.p.emit(r_type(0b1110000, 0, fs1, 0, rd, OP_FP), 'FMV.X.W x{}, f{}'.format(rd, fs1))
        elif roll < 0.92:
            rd = self.reg()
            self.p.emit(r_type(0b1110000, 0, fs1, 1, rd, OP_FP), 'FCLASS.S x{}, f{}'.format(rd, fs1))
        else:
            rs1 = self.src()
            self.p.emit(r_type(0b1111000, 0, rs1, 0, fd, OP_FP), 'FMV.W.X f{}, x{}'.format(fd, rs1))

    def emit_system(self):
        roll = random.random()
        if roll < 0.30:
            self.p.emit(i_type(0, 0, 0, 0, SYSTEM), 'ECALL')
        elif roll < 0.50:
            self.p.emit(i_type(1, 0, 0, 0, SYSTEM), 'EBREAK')
        elif roll < 0.58:
            self.p.emit(i_type(0, 0, 1, 0, MISC_MEM), 'FENCE.I')
        elif roll < 0.65:
            self.p.emit(i_type(0x0FF, 0, 0, 0, MISC_MEM), 'FENCE')
        elif roll < 0.75 and self.interrupts:
            self.emit_wfi()
        elif roll < 0.75:
            self.p.emit(i_type(0x0FF, 0, 0, 0, MISC_MEM), 'FENCE')
        else:
            rd = self.reg()
            illegal = [
                ('0' * 32, 'ILLEGAL (all zero)'),
                (r_type(0b0000010, self.src(), self.src(), 0, rd, OP), 'ILLEGAL (R-type funct7)'),
                (b_type(8, 0, 0, 2), 'ILLEGAL (branch funct3 010)'),
                (i_type(0, BASE_REG, 7, rd, LOAD), 'ILLEGAL (load funct3 111)'),
                (s_type(0, 0, BASE_REG, 4, STORE), 'ILLEGAL (store funct3 100)'),
                (i_type(0, 0, 1, 0, JALR_OP), 'ILLEGAL (JALR funct3)'),
                (i_type(0, 0, 7, 0, MISC_MEM), 'ILLEGAL (MISC-MEM funct3 111)'),
                (amo_type(0b00101, self.src(), BASE_REG, 2, rd), 'ILLEGAL (AMO funct5 00101)'),
                (amo_type(LR_F5, random.randint(1, 31), BASE_REG, 2, rd), 'ILLEGAL (LR.W rs2 != x0)'),
                (amo_type(AMO_OPS['AMOADD'], self.src(), BASE_REG, 0, rd), 'ILLEGAL (AMO funct3 000)'),
                (i_type(0x7FF, 0, 0, 0, SYSTEM), 'ILLEGAL (SYSTEM imm)'),
                (i_type(0x300, 0, 4, rd, SYSTEM), 'ILLEGAL (SYSTEM funct3 100)'),
                (r_type(0b1111111, 0, 0, 0, 0, OP_FP), 'ILLEGAL (FP funct7)'),
                (r_type(0b0000000, 1, 2, 5, 3, OP_FP), 'ILLEGAL (FP reserved rm)'),
                (i_type(0x020 if self.xlen == 32 else 0x800, self.src(), 1, rd, OP_IMM),
                 'ILLEGAL (shift-immediate encoding)'),
            ]
            if self.xlen == 32:
                illegal += [(r_type(0, self.src(), self.src(), 0, rd, OP_32), 'OP-32 (illegal on RV32)'),
                            (i_type(0, BASE_REG, 3, rd, LOAD), 'LD (illegal on RV32)'),
                            (amo_type(AMO_OPS['AMOADD'], self.src(), BASE_REG, 3, rd), 'AMOADD.D (illegal on RV32)')]
            self.p.emit(*random.choice(illegal))

    # ── templates ─────────────────────────────────────────────────────────────
    def emit_forward_branch(self, budget):
        name = random.choice(list(BRANCHES))
        skip = random.randint(0, min(4, budget))
        target = 'fwd{}'.format(len(self.p.words))
        rs1, rs2 = self.src(), self.src()
        self.p.emit_fixup(target, lambda off, n=name, a=rs1, b=rs2:
                          (b_type(off, b, a, BRANCHES[n]), '{} x{}, x{}, {:+d}'.format(n, a, b, off)))
        for _ in range(skip):
            self.emit_simple()
        self.p.label(target)
        return skip + 1

    def emit_forward_jal(self, budget):
        skip = random.randint(0, min(3, budget))
        target = 'jal{}'.format(len(self.p.words))
        rd = random.choice(FREE_GPRS + [0])
        self.p.emit_fixup(target, lambda off, d=rd: (j_type(off, d), 'JAL x{}, {:+d}'.format(d, off)))
        for _ in range(skip):
            self.emit_simple()
        self.p.label(target)
        return skip + 1

    def emit_jalr(self, budget):
        """AUIPC + JALR forward, occasionally to a misaligned target (traps)."""
        skip = random.randint(0, min(3, budget))
        extra = 2 if random.random() < 0.1 else random.choice([0, 1])    # bit 0 is cleared by JALR
        rd = random.choice(FREE_GPRS + [0])
        target = 'jalr{}'.format(len(self.p.words))
        self.p.emit(u_type(0, JALR_REG, AUIPC_OP), 'AUIPC x{}, 0'.format(JALR_REG))
        self.p.emit_fixup(target, lambda off, d=rd, e=extra:
                          (i_type(off + 4 + e, JALR_REG, 0, d, JALR_OP),
                           'JALR x{}, {}(x{})'.format(d, off + 4 + e, JALR_REG)))
        for _ in range(skip):
            self.emit_simple()
        self.p.label(target)
        return skip + 2

    def emit_wfi(self):
        """WFI after enabling a wake source, optionally with MIE = 0 and a producer/consumer around it."""
        start = len(self.p.words)
        # WFI sleeps until mip & mie != 0: enable MSIE first (software pulses wake it).
        # With MIE = 0 the wake takes no trap, so the held consumer commits with the
        # operand refreshed from its producer (an MIE = 1 wake re-executes it).
        mie_off = random.random() < 0.5
        if mie_off:
            self.p.emit(i_type(0x300, 8, 7, 0, SYSTEM), 'CSRRCI x0, mstatus, 8  (WFI with MIE = 0)')
        self.p.emit(i_type(0x304, 8, 6, 0, SYSTEM), 'CSRRSI x0, mie, 8')
        rd = self.reg() if random.random() < 0.8 else 0
        if rd:
            imm = random.randint(1, 2047)
            self.p.emit(i_type(imm, rd, 0, rd, OP_IMM), 'ADDI x{}, x{}, {}  (producer before WFI)'.format(rd, rd, imm))
        self.p.emit(i_type(0x105, 0, 0, 0, SYSTEM), 'WFI')
        if rd:
            other = self.reg()
            self.p.emit(r_type(0, rd, rd, 0, other, OP), 'ADD x{}, x{}, x{}  (held behind WFI)'.format(other, rd, rd))
        if mie_off:
            self.p.emit(i_type(0x300, 8, 6, 0, SYSTEM), 'CSRRSI x0, mstatus, 8')
        return len(self.p.words) - start

    def emit_mstatus(self):
        """mstatus write with MPP 00/01/10/11 (WARL: only 11 stays M), random MPRV/TW, read back."""
        mpp = random.randint(0, 3)
        value = (mpp << 11) | (random.getrandbits(1) << 17) | (random.getrandbits(1) << 21) | \
                (random.getrandbits(1) << 7) | (8 if self.interrupts else 0)
        value |= random.choice([0, 1, 1, 2, 2, 3, 3, 3, 3, 3]) << 13     # FS: Off in 10 % of the writes
        self.li(28, value)
        rd = self.reg()
        self.p.emit(i_type(0x300, 28, 1, rd, SYSTEM), 'CSRRW x{}, mstatus, x28  (MPP={:02b})'.format(rd, mpp))
        rd = self.reg()
        self.p.emit(i_type(0x300, 0, 2, rd, SYSTEM), 'CSRRS x{}, mstatus, x0'.format(rd))
        return 4

    def emit_user(self):
        """One U-mode instruction: no ECALL (it would leave U early)."""
        roll = random.random()
        if roll < 0.25:
            csr = random.choice([0xC00, 0xC01, 0xC02] + ([0xC80, 0xC81, 0xC82] if self.xlen == 32 else []))
            rd = self.reg()
            self.p.emit(i_type(csr, 0, 2, rd, SYSTEM), 'CSRRS x{}, 0x{:x}, x0  (counter read in U)'.format(rd, csr))
        elif roll < 0.45:
            csr = random.choice(M_CSRS + (M_CSRS_RV32 if self.xlen == 32 else []))
            rd = self.reg()
            self.p.emit(i_type(csr, 0, 2, rd, SYSTEM), 'CSRRS x{}, 0x{:x}, x0  (M CSR in U: illegal)'.format(rd, csr))
        elif roll < 0.55:
            self.emit_csr()            # M CSRs and writes to counters trap, fflags/frm/fcsr work
        elif roll < 0.62:
            options = [(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET (illegal in U)'),
                       (i_type(0x102, 0, 0, 0, SYSTEM), 'SRET (illegal in U)'),
                       (i_type(1, 0, 0, 0, SYSTEM), 'EBREAK')]
            if self.interrupts:        # mie.MSIE was set before MRET to U
                options.append((i_type(0x105, 0, 0, 0, SYSTEM), 'WFI (illegal in U if TW = 1)'))
            self.p.emit(*random.choice(options))
        elif roll < 0.75:
            self.emit_mem()
        elif roll < 0.88 and self.fp:
            self.emit_fp()
        else:
            self.emit_alu()

    def emit_user_window(self, budget):
        """MRET to U-mode, user code, ECALL back to M (the handler sets MPP = M on mcause 8)."""
        if budget < 16:
            return 0
        p = self.p
        start = len(p.words)
        p.emit(i_type(0x300, 8, 7, 0, SYSTEM), 'CSRRCI x0, mstatus, 8  (no interrupt while mepc/MPP are set)')
        if self.interrupts:
            p.emit(i_type(0x304, 8, 6, 0, SYSTEM), 'CSRRSI x0, mie, 8  (wake source for WFI in U)')
        cen = random.randint(0, 7)
        p.emit(i_type(0x306, cen, 5, 0, SYSTEM), 'CSRRWI x0, mcounteren, {}'.format(cen))
        mpie = random.choice([0, 0x80])    # MPIE = 0: MIE = 0 in U (M interrupts are still taken)
        self.li(28, MSTATUS_MPP | mpie)
        p.emit(i_type(0x300, 28, 3, 0, SYSTEM), 'CSRRC x0, mstatus, x28  (MPP = U{})'.format(', MPIE = 0' if mpie else ''))
        p.emit(u_type(0, 28, AUIPC_OP), 'AUIPC x28, 0')
        p.emit(i_type(16, 28, 0, 28, OP_IMM), 'ADDI x28, x28, 16')
        p.emit(i_type(0x341, 28, 1, 0, SYSTEM), 'CSRRW x0, mepc, x28')
        p.emit(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET  (to U)')
        for _ in range(random.randint(2, min(8, (budget - 12) // 2))):
            self.emit_user()
        p.emit(i_type(0, 0, 0, 0, SYSTEM), 'ECALL  (back to M)')
        if self.interrupts:
            p.emit(i_type(0x300, 8, 6, 0, SYSTEM), 'CSRRSI x0, mstatus, 8')
        return len(p.words) - start

    def emit_super(self):
        """One S-mode instruction (the window may SRET into U, then the same code runs there)."""
        roll = random.random()
        rd = self.reg()
        if roll < 0.15:
            csr = random.choice([0xC00, 0xC01, 0xC02] + ([0xC80, 0xC81, 0xC82] if self.xlen == 32 else []))
            self.p.emit(i_type(csr, 0, 2, rd, SYSTEM), 'CSRRS x{}, 0x{:x}, x0  (counter read in S)'.format(rd, csr))
        elif roll < 0.40:
            csr = random.choice(S_CSRS + [0x105])
            name = random.choice(list(CSR_OPS))
            f3 = CSR_OPS[name]
            rs1 = random.randint(0, 31) if f3 >= 5 else random.choice([0, self.src()])
            if csr == 0x105:
                name, f3, rs1 = 'CSRRS', 2, 0
            self.p.emit(i_type(csr, rs1, f3, rd, SYSTEM), '{} x{}, 0x{:x}, {}  (S CSR)'.format(name, rd, csr, rs1))
        elif roll < 0.45:
            p = self.p     # SRET to the next instruction, in U or S as SPP says (illegal if TSR)
            p.emit(u_type(0, 28, AUIPC_OP), 'AUIPC x28, 0')
            p.emit(i_type(16, 28, 0, 28, OP_IMM), 'ADDI x28, x28, 16')
            p.emit(i_type(0x141, 28, 1, 0, SYSTEM), 'CSRRW x0, sepc, x28')
            p.emit(i_type(0x102, 0, 0, 0, SYSTEM), 'SRET')
        elif roll < 0.50 and self.interrupts:
            self.p.emit(i_type(0x105, 0, 0, 0, SYSTEM), 'WFI  (mie.MSIE is the wake source)')
        elif roll < 0.60:
            self.emit_mem()
        elif roll < 0.70:
            self.emit_alu()
        else:
            self.emit_simple()

    def emit_s_window(self, budget):
        """Random delegation/enables/stvec mode, MRET to S, S code, ECALL back to M (the M handler clears medeleg)."""
        if budget < 80:
            return 0
        p = self.p
        start = len(p.words)
        def put(csr, value, f3=1, note=''):    # x28 = value; CSRR{W,S,C} csr, x28
            self.li(28, value)
            p.emit(i_type(csr, 28, f3, 0, SYSTEM), '{} x0, 0x{:x}, x28  {}'.format({1: 'CSRRW', 2: 'CSRRS', 3: 'CSRRC'}[f3], csr, note))
        def read(csr):
            rd = self.reg()
            p.emit(i_type(csr, 0, 2, rd, SYSTEM), 'CSRRS x{}, 0x{:x}, x0'.format(rd, csr))
        def subset(mask, prob):
            return sum(b for b in (1 << i for i in range(32)) if mask & b and random.random() < prob)
        p.emit(i_type(0x300, 8, 7, 0, SYSTEM), 'CSRRCI x0, mstatus, 8  (no interrupt while mepc/MPP are set)')
        if self.interrupts:
            p.emit(i_type(0x304, 8, 6, 0, SYSTEM), 'CSRRSI x0, mie, 8  (wake source for WFI in S)')
        # Random legal delegation plus junk in the bits that must read back 0 (S ECALL stays undelegated)
        medeleg = subset(MEDELEG_MASK, random.choice([0, 0.3, 0.7])) | (random.getrandbits(32) & 0xFFF7FC00 if random.random() < 0.3 else 0)
        put(0x302, medeleg, note='(medeleg)')
        read(0x302)
        mideleg = subset(0x222, random.choice([0, 0.5, 1])) | (random.getrandbits(32) & ~0x222 if random.random() < 0.2 else 0)
        put(0x303, mideleg, note='(mideleg)')
        read(0x303)
        if self.interrupts:
            put(0x304, subset(0x222, random.choice([0.3, 0.7, 1])), 2, '(mie S bits)')
            if random.random() < 0.5:
                put(0x344, subset(0x222, 0.5), 2, '(mip software bits)')
        read(0x104)
        read(0x144)
        p.emit(i_type(0x306, random.randint(0, 7), 5, 0, SYSTEM), 'CSRRWI x0, mcounteren, ..')
        p.emit(i_type(0x106, random.randint(0, 7), 5, 0, SYSTEM), 'CSRRWI x0, scounteren, ..')
        mode = random.randint(0, 3)       # bit 1 is WARL: 2 -> direct, 3 -> vectored
        put(0x105, 4 * p.labels['stab'] | mode, note='(stvec, mode {})'.format(mode))
        read(0x105)
        put(0x300, MSTATUS_MPP | TSR | 0x100 | 0x22 | 0x80, 3, '(MPP/TSR/SPP/SIE/SPIE/MPIE cleared)')
        set_bits = 0x800 | (0x2 if random.random() < 0.8 else 0) | (0x20 if random.random() < 0.5 else 0) | \
                   (0x100 if random.random() < 0.3 else 0) | \
                   (0x80 if random.random() < 0.5 else 0)
        if not medeleg and not mideleg & 0x222 and random.random() < 0.5:
            set_bits |= TSR     # SRET traps in S, so the S handler (which ends in SRET) must never run
        put(0x300, set_bits, 2, '(MPP = S)')
        p.emit(u_type(0, 28, AUIPC_OP), 'AUIPC x28, 0')
        p.emit(i_type(16, 28, 0, 28, OP_IMM), 'ADDI x28, x28, 16')
        p.emit(i_type(0x341, 28, 1, 0, SYSTEM), 'CSRRW x0, mepc, x28')
        p.emit(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET  (to S)')
        for _ in range(random.randint(3, min(10, (budget - 62) // 6))):
            self.emit_super()
        p.emit(i_type(0, 0, 0, 0, SYSTEM), 'ECALL  (back to M; from U if SRET left S and medeleg[8] is set)')
        p.emit(i_type(0, 0, 0, 0, SYSTEM), 'ECALL  (second ECALL: the S handler resumes in S)')
        put(0x300, TSR, 3, '(TSR cleared)')
        if self.interrupts:
            p.emit(i_type(0x300, 8, 6, 0, SYSTEM), 'CSRRSI x0, mstatus, 8')
        return len(p.words) - start

    def emit_fs_off(self):
        """FS = Off: FP instructions and fflags/frm/fcsr accesses trap; FS = Initial afterwards."""
        p = self.p
        start = len(p.words)
        self.li(28, MSTATUS_FS)
        p.emit(i_type(0x300, 28, 3, 0, SYSTEM), 'CSRRC x0, mstatus, x28  (FS = Off)')
        for _ in range(random.randint(1, 3)):
            if random.random() < 0.7:
                self.emit_fp()
            else:
                csr, rd = random.choice([0x001, 0x002, 0x003]), self.reg()
                p.emit(i_type(csr, 0, 2, rd, SYSTEM), 'CSRRS x{}, 0x{:x}, x0  (FP CSR with FS = Off)'.format(rd, csr))
        self.li(28, 1 << 13)
        p.emit(i_type(0x300, 28, 2, 0, SYSTEM), 'CSRRS x0, mstatus, x28  (FS = Initial)')
        return len(p.words) - start

    def emit_loop(self, budget):
        if self.in_loop or budget < 6:
            return 0
        self.in_loop = True
        iterations = random.randint(1, 4)
        self.p.emit(i_type(iterations, 0, 0, LOOP_REG, OP_IMM), 'ADDI x{}, x0, {}'.format(LOOP_REG, iterations))
        start = len(self.p.words)
        body = random.randint(1, min(5, budget - 4))
        for _ in range(body):
            self.emit_simple(allow_traps=False)
        self.p.emit(i_type(-1, LOOP_REG, 0, LOOP_REG, OP_IMM), 'ADDI x{}, x{}, -1'.format(LOOP_REG, LOOP_REG))
        off = 4 * (start - len(self.p.words))
        self.p.emit(b_type(off, 0, LOOP_REG, BRANCHES['BNE']), 'BNE x{}, x0, {:+d}'.format(LOOP_REG, off))
        self.in_loop = False
        self.stored = []         # (offset, size) of earlier stores, reused by loads
        return body + 3

    def emit_simple(self, allow_traps=True):
        roll = random.random()
        if roll < 0.45:
            self.emit_alu()
        elif roll < 0.65:
            self.emit_mem(allow_traps)
        elif roll < 0.80:
            self.emit_fp() if self.fp else self.emit_alu()
        elif roll < 0.88 and allow_traps:
            self.emit_csr()
        elif allow_traps:
            self.emit_system()
        else:
            self.emit_alu()

    # ── whole program ─────────────────────────────────────────────────────────
    def generate(self):
        p = self.p
        p.emit_fixup('start', lambda off: (j_type(off, 0), 'JAL x0, start'))
        # trap handler at HANDLER_ADDR: skip a faulting instruction, return to
        # an interrupted one
        p.emit(i_type(0x342, 0, 2, 29, SYSTEM), 'CSRRS x29, mcause, x0')
        p.emit(i_type(0x341, 0, 2, 30, SYSTEM), 'CSRRS x30, mepc, x0')
        p.emit(b_type(44, 0, 29, BRANCHES['BLT']), 'BLT x29, x0, +44  (interrupt: clear software mip, return to it)')
        p.emit(i_type(4, 30, 0, 30, OP_IMM), 'ADDI x30, x30, 4')
        p.emit(i_type(0x341, 30, 1, 0, SYSTEM), 'CSRRW x0, mepc, x30')
        p.emit(i_type(-8, 29, 0, 30, OP_IMM), 'ADDI x30, x29, -8')
        p.emit(i_type(2, 30, 3, 30, OP_IMM), 'SLTIU x30, x30, 2  (ECALL from U or S)')
        p.emit(b_type(20, 0, 30, BRANCHES['BEQ']), 'BEQ x30, x0, +20  (not an ECALL from U/S)')
        self.li(30, MSTATUS_MPP)
        p.emit(i_type(0x300, 30, 2, 0, SYSTEM), 'CSRRS x0, mstatus, x30  (ECALL from U/S: return to M)')
        p.emit(i_type(0x302, 0, 1, 0, SYSTEM), 'CSRRW x0, medeleg, x0')
        p.emit(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET')
        self.li(30, 0x222)
        p.emit(i_type(0x344, 30, 3, 0, SYSTEM), 'CSRRC x0, mip, x30  (software SSIP/STIP/SEIP would fire again)')
        p.emit(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET')
        # S handler: every vector slot jumps to the one body (S_HANDLER_REGS, never touched by the M handler)
        p.label('stab')
        for _ in range(10):
            p.emit_fixup('smain', lambda off: (j_type(off, 0), 'JAL x0, smain  ({:+d})'.format(off)))
        p.label('smain')
        p.emit(i_type(0x142, 0, 2, 22, SYSTEM), 'CSRRS x22, scause, x0')
        p.emit(i_type(0x141, 0, 2, 23, SYSTEM), 'CSRRS x23, sepc, x0')
        p.emit(b_type(32, 0, 22, BRANCHES['BLT']), 'BLT x22, x0, +32  (interrupt: disable it, return to it)')
        p.emit(i_type(4, 23, 0, 23, OP_IMM), 'ADDI x23, x23, 4')
        p.emit(i_type(0x141, 23, 1, 0, SYSTEM), 'CSRRW x0, sepc, x23')
        p.emit(i_type(-8, 22, 0, 23, OP_IMM), 'ADDI x23, x22, -8')
        p.emit(b_type(12, 0, 23, BRANCHES['BNE']), 'BNE x23, x0, +12  (not an ECALL from U)')
        p.emit(i_type(0x100, 0, 0, 23, OP_IMM), 'ADDI x23, x0, 0x100')
        p.emit(i_type(0x100, 23, 2, 0, SYSTEM), 'CSRRS x0, sstatus, x23  (ECALL from U: resume in S)')
        p.emit(i_type(0x102, 0, 0, 0, SYSTEM), 'SRET')
        p.emit(i_type(0x222, 0, 0, 23, OP_IMM), 'ADDI x23, x0, 0x222')
        p.emit(i_type(0x104, 23, 3, 0, SYSTEM), 'CSRRC x0, sie, x23')
        p.emit(i_type(0x102, 0, 0, 0, SYSTEM), 'SRET')
        # prologue
        p.label('start')
        p.emit(i_type(0x305, HANDLER_ADDR, 5, 0, SYSTEM), 'CSRRWI x0, mtvec, {}'.format(HANDLER_ADDR))
        self.li(BASE_REG, MEM_BYTES)    # negative offsets access data at the top of RAM
        for r in FREE_GPRS:
            if random.random() < 0.7:
                self.li(r, self.interesting())
        self.li(28, 1 << 13)
        p.emit(i_type(0x300, 28, 2, 0, SYSTEM), 'CSRRS x0, mstatus, x28  (FS = Initial: FP code needs FS != Off)')
        for fr in range(32):
            if random.random() < 0.5:
                rs = random.choice(FREE_GPRS)
                p.emit(r_type(0b1111000, 0, rs, 0, fr, OP_FP), 'FMV.W.X f{}, x{}'.format(fr, rs))
        self.li(28, 4 * p.labels['stab'])
        p.emit(i_type(0x105, 28, 1, 0, SYSTEM), 'CSRRW x0, stvec, x28')
        frm = random.randint(0, 4)
        p.emit(i_type(0x002, frm, 5, 0, SYSTEM), 'CSRRWI x0, frm, {}'.format(frm))
        if self.interrupts:
            self.li(28, (1 << 11) | (1 << 7) | (1 << 3))
            p.emit(i_type(0x304, 28, 2, 0, SYSTEM), 'CSRRS x0, mie, x28')
            p.emit(i_type(0x300, 8, 6, 0, SYSTEM), 'CSRRSI x0, mstatus, 8')
        # Reserve as much of the top KiB as fits above this program, including
        # the last control-flow template and exit. Align for doublewords.
        self.data_bytes = min(1024, (MEM_BYTES - 4 * (len(p.words) + self.count + 8)) & ~7)
        if self.data_bytes < 8:
            raise SystemExit('program leaves no space for data in the shared 4 KiB RAM')
        # body
        body_end = len(p.words) + self.count
        while len(p.words) < body_end:
            budget = body_end - len(p.words)
            roll = random.random()
            n = 0
            if roll < 0.10:
                n = self.emit_forward_branch(budget)
            elif roll < 0.15:
                n = self.emit_forward_jal(budget)
            elif roll < 0.20:
                n = self.emit_jalr(budget)
            elif roll < 0.25:
                n = self.emit_loop(budget)
            elif roll < 0.33:
                n = self.emit_atomic(budget)
            elif roll < 0.38:
                n = self.emit_user_window(budget)
            elif roll < 0.43:
                n = self.emit_s_window(budget)
            elif roll < 0.45:
                n = self.emit_mstatus()
            elif roll < 0.47:
                n = self.emit_fs_off()
            elif roll < 0.50 and self.interrupts:
                n = self.emit_wfi()
            if n == 0:
                self.emit_simple()
        # end: self-loop
        p.emit(j_type(0, 0), 'JAL x0, 0  (end of program)')
        assert len(p.words) * 4 <= MEM_BYTES - self.data_bytes
        p.resolve()
        return p.words


def write_outputs(words, out_dir, xlen):
    with open(os.path.join(out_dir, 'binary1.txt'), 'w') as f:
        for w in words:
            f.write(w[0] + '\n')
    with open(os.path.join(out_dir, 'assembly1.s'), 'w') as f:
        f.write('test1.elf:     file format elf{}-littleriscv\n\n\n'.format(xlen))
        f.write('Disassembly of section .text:\n\n00000000 <main>:\n')
        for i, w in enumerate(words):
            f.write('{:x}:\t\t{:08x}\t{}\n'.format(4 * i, int(w[0], 2), w[1]))
    with open(os.path.join(out_dir, 'hex1.v'), 'w') as f:
        f.write('@00000000\n')
        for i, w in enumerate(words):
            v = int(w[0], 2)
            if i % 4 == 0 and i != 0:
                f.write('\n')
            f.write(' '.join('{:02x}'.format((v >> (8 * b)) & 0xFF) for b in range(4)) + ' ')
    with open(os.path.join(out_dir, 'program_info.txt'), 'w') as f:
        f.write('{}\n'.format(len(words)))


def main():
    parser = argparse.ArgumentParser(description='Random RISC-V program generator')
    parser.add_argument('--xlen', type=int, choices=(32, 64), default=32)
    parser.add_argument('--count', type=int, default=300, help='body instructions')
    parser.add_argument('--seed', type=int, default=None)
    parser.add_argument('--no-interrupts', action='store_true', help='leave mie/mstatus.MIE clear')
    parser.add_argument('--no-fp', action='store_true', help='no floating-point instructions in the body')
    parser.add_argument('--out-dir', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Dump'))
    args = parser.parse_args()
    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    random.seed(seed)
    words = Generator(args.xlen, args.count, not args.no_interrupts, not args.no_fp).generate()
    if len(words) > 1000:
        raise SystemExit('program too large for the shared 4 KiB RAM: {} words'.format(len(words)))
    write_outputs(words, args.out_dir, args.xlen)
    print('xlen={} seed={} words={}'.format(args.xlen, seed, len(words)))


if __name__ == '__main__':
    main()
