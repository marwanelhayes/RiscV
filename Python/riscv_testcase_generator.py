#   ======================= A RISCV RANDOM TEST CASES GENERATOR ======================    #
#   Generates a random RISC-V program in the standard encoding (RV32 or RV64: I, M,      #
#   the implemented F subset, Zicsr, M-mode traps). The full-core testbench runs it      #
#   against the ISA golden model (Verification/Risc/riscv_iss_pkg.sv), so the program    #
#   needs no expected values of its own.                                                 #
#                           Authored by Amr Mohamed                                       #
#
# Program layout
#   0x000    : JAL x0, start
#   0x004    : trap handler - skips the trapping instruction for exceptions,
#              returns to the interrupted one for interrupts, then MRET
#   start    : prologue - mtvec <- 0x004, data base pointer, random GPR/FPR
#              values, frm, optional interrupt enables
#   body     : random instructions and small templates (forward branches/jumps,
#              JALR, counted loops, loads/stores around the data base pointer,
#              ECALL/EBREAK, illegal encodings and misaligned accesses that trap)
#   end      : JAL x0, 0 (self-loop; the testbench stops when it commits)
#
# Outputs (next to this script unless --out-dir is given):
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
HANDLER_REGS = (28, 29, 30)
RESERVED = {0, BASE_REG, LOOP_REG, JALR_REG, *HANDLER_REGS}
FREE_GPRS = [r for r in range(1, 32) if r not in RESERVED]

DATA_BASE = 0x400   # data accesses stay inside [0x200, 0x5ff] of the data memory
HANDLER_ADDR = 0x4

# CSR groups (addresses)
RW_CSRS = [0x340, 0x343, 0x342, 0x341, 0x300, 0x304, 0x001, 0xB00, 0xB02,
           0x301, 0x344, 0x302, 0x303, 0xB03, 0xB1F, 0x323, 0x33F]
RW_CSRS_RV32 = [0xB80, 0xB82, 0x310, 0xB83]
READ_ONLY_CSRS = [0xC00, 0xC02, 0xF11, 0xF12, 0xF13, 0xF14]
READ_ONLY_CSRS_RV32 = [0xC80, 0xC82]
UNKNOWN_CSRS = [0x7C0, 0x5C0, 0x180, 0x100, 0x3A0, 0x7B0, 0x306, 0xB20]


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


def j_type(imm, rd):
    v = imm & 0x1FFFFF
    return (bits(v >> 20, 1) + bits(v >> 1, 10) + bits(v >> 11, 1) + bits(v >> 12, 8) +
            bits(rd, 5) + '1101111')


OP_IMM, OP, OP_IMM_32, OP_32 = 0b0010011, 0b0110011, 0b0011011, 0b0111011
LOAD, STORE, JALR_OP = 0b0000011, 0b0100011, 0b1100111
LUI_OP, AUIPC_OP, SYSTEM, MISC_MEM, OP_FP = 0b0110111, 0b0010111, 0b1110011, 0b0001111, 0b1010011

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
        offset = random.randrange(-512, 512, size)
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
        elif roll < 0.65:
            self.p.emit(i_type(0x0FF, 0, 0, 0, MISC_MEM), 'FENCE')
        elif roll < 0.75:
            self.p.emit(i_type(0x105, 0, 0, 0, SYSTEM), 'WFI')
        else:
            rd = self.reg()
            illegal = [
                ('0' * 32, 'ILLEGAL (all zero)'),
                (r_type(0b0000010, self.src(), self.src(), 0, rd, OP), 'ILLEGAL (R-type funct7)'),
                (b_type(8, 0, 0, 2), 'ILLEGAL (branch funct3 010)'),
                (i_type(0, BASE_REG, 7, rd, LOAD), 'ILLEGAL (load funct3 111)'),
                (s_type(0, 0, BASE_REG, 4, STORE), 'ILLEGAL (store funct3 100)'),
                (i_type(0, 0, 1, 0, JALR_OP), 'ILLEGAL (JALR funct3)'),
                (i_type(0, 0, 1, 0, MISC_MEM), 'ILLEGAL (FENCE.I, Zifencei not claimed)'),
                (i_type(0x7FF, 0, 0, 0, SYSTEM), 'ILLEGAL (SYSTEM imm)'),
                (i_type(0x300, 0, 4, rd, SYSTEM), 'ILLEGAL (SYSTEM funct3 100)'),
                (r_type(0b1111111, 0, 0, 0, 0, OP_FP), 'ILLEGAL (FP funct7)'),
                (r_type(0b0000000, 1, 2, 5, 3, OP_FP), 'ILLEGAL (FP reserved rm)'),
                (i_type(0x020 if self.xlen == 32 else 0x800, self.src(), 1, rd, OP_IMM),
                 'ILLEGAL (shift-immediate encoding)'),
            ]
            if self.xlen == 32:
                illegal += [(r_type(0, self.src(), self.src(), 0, rd, OP_32), 'OP-32 (illegal on RV32)'),
                            (i_type(0, BASE_REG, 3, rd, LOAD), 'LD (illegal on RV32)')]
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
        p.emit(b_type(12, 0, 29, BRANCHES['BLT']), 'BLT x29, x0, +12  (interrupt: return to it)')
        p.emit(i_type(4, 30, 0, 30, OP_IMM), 'ADDI x30, x30, 4')
        p.emit(i_type(0x341, 30, 1, 0, SYSTEM), 'CSRRW x0, mepc, x30')
        p.emit(i_type(0x302, 0, 0, 0, SYSTEM), 'MRET')
        # prologue
        p.label('start')
        p.emit(i_type(0x305, HANDLER_ADDR, 5, 0, SYSTEM), 'CSRRWI x0, mtvec, {}'.format(HANDLER_ADDR))
        self.li(BASE_REG, DATA_BASE)
        for r in FREE_GPRS:
            if random.random() < 0.7:
                self.li(r, self.interesting())
        for fr in range(32):
            if random.random() < 0.5:
                rs = random.choice(FREE_GPRS)
                p.emit(r_type(0b1111000, 0, rs, 0, fr, OP_FP), 'FMV.W.X f{}, x{}'.format(fr, rs))
        frm = random.randint(0, 4)
        p.emit(i_type(0x002, frm, 5, 0, SYSTEM), 'CSRRWI x0, frm, {}'.format(frm))
        if self.interrupts:
            self.li(28, (1 << 11) | (1 << 7) | (1 << 3))
            p.emit(i_type(0x304, 28, 2, 0, SYSTEM), 'CSRRS x0, mie, x28')
            p.emit(i_type(0x300, 8, 6, 0, SYSTEM), 'CSRRSI x0, mstatus, 8')
        # body
        emitted = 0
        while emitted < self.count:
            budget = self.count - emitted
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
            if n == 0:
                self.emit_simple()
                n = 1
            emitted += n
        # end: self-loop
        p.emit(j_type(0, 0), 'JAL x0, 0  (end of program)')
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
    parser.add_argument('--out-dir', default=os.path.dirname(os.path.abspath(__file__)))
    args = parser.parse_args()
    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    random.seed(seed)
    words = Generator(args.xlen, args.count, not args.no_interrupts, not args.no_fp).generate()
    if len(words) > 1000:
        raise SystemExit('program too large for the 4 KiB instruction memory: {} words'.format(len(words)))
    write_outputs(words, args.out_dir, args.xlen)
    print('xlen={} seed={} words={}'.format(args.xlen, seed, len(words)))


if __name__ == '__main__':
    main()
