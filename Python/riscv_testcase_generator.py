#   ======================= A RISCV RANDOM TEST CASES GENERATOR ======================    #
#   Program takes as input number of test cases to produce, number of instructions, and   #
#   number of registers to use. Generates the instructions in binary, hex, and assembly.  #
#                           Authored by Amr Mohamed                                       #

import random
import numpy as np
import re


# Function to reverse a dictionary keys with values
def reverse_dict_with_iterable(dictionary):
    rev = {}
    for key, value in dictionary.items():
        for item in value:
            rev[item] = key
    return rev


# Instructions classified into types
TYPES_TO_INSTRUCTION = dict(U_TYPE={'LUI', 'AUIPC'}, UJ_TYPE={'JAL'},
                            SB_TYPE={'BEQ', 'BNE', 'BLT', 'BGE', 'BLTU', 'BGEU'},
                            I_TYPE={'JALR', 'LB', 'LH', 'LW', 'LBU', 'LHU', 'ADDI', 'SLTI', 'SLTIU', 'XORI', 'ORI',
                                    'ANDI', 'SLLI', 'SRLI',
                                    'SRAI'}, S_TYPE={'SB', 'SH', 'SW'},
                            R_TYPE={'ADD', 'SUB', 'SLL', 'SLT', 'SLTU', 'XOR', 'SRL', 'SRA', 'OR', 'AND', 'MUL', 'MULH',
                                    'MULHSU', 'MULHU', 'DIV', 'DIVU', 'REM', 'REMU'},
                            CSR_TYPE={'CSRRW', 'CSRRS', 'CSRRC', 'CSRRWI', 'CSRRSI', 'CSRRCI'},
                            F_TYPE={'FADD.S', 'FSUB.S', 'FMUL.S', 'FDIV.S', 'FSQRT.S',
                                    'FSGNJ.S', 'FSGNJN.S', 'FSGNJX.S', 'FMIN.S', 'FMAX.S',
                                    'FCVT.W.S', 'FCVT.WU.S', 'FMV.X.W', 'FEQ.S', 'FLT.S', 'FLE.S', 'FCLASS.S',
                                    'FCVT.S.W', 'FCVT.S.WU', 'FMV.W.X'})
# Opcodes of all instructions
OPCODES = dict(LUI='0110111', AUIPC='0010111', JAL='1101111', JALR='1100111', BEQ='1100011', BNE='1100011',
               BLT='1100011', BGE='1100011', BLTU='1100011', BGEU='1100011', LB='0000011', LH='0000011', LW='0000011',
               LBU='0000011', LHU='0000011', SB='0100011', SH='0100011', SW='0100011', ADDI='0010011', SLTI='0010011',
               SLTIU='0010011', XORI='0010011', ORI='0010011', ANDI='0010011', SLLI='0010011', SRLI='0010011',
               SRAI='0010011', ADD='0110011', SUB='0110011', SLL='0110011', SLT='0110011', SLTU='0110011',
               XOR='0110011', SRL='0110011', SRA='0110011', OR='0110011', AND='0110011', MUL='0110011', MULH='0110011',
               MULHSU='0110011', MULHU='0110011', DIV='0110011', DIVU='0110011', REM='0110011', REMU='0110011',
               CSRRW='1110011', CSRRS='1110011', CSRRC='1110011',
               CSRRWI='1110011', CSRRSI='1110011', CSRRCI='1110011',
               **{name: '1010011' for name in {'FADD.S', 'FSUB.S', 'FMUL.S', 'FDIV.S', 'FSQRT.S',
                                               'FSGNJ.S', 'FSGNJN.S', 'FSGNJX.S', 'FMIN.S', 'FMAX.S',
                                               'FCVT.W.S', 'FCVT.WU.S', 'FMV.X.W', 'FEQ.S', 'FLT.S', 'FLE.S', 'FCLASS.S',
                                               'FCVT.S.W', 'FCVT.S.WU', 'FMV.W.X'}})

# Function codes of all instructions that need one
FUNCT_CODES = dict(JALR='000', BEQ='000', BNE='001', BLT='100', BGE='101', BLTU='110', BGEU='111', LB='000', LH='001',
                   LW='010', LBU='100', LHU='101', SB='000', SH='001', SW='010', ADDI='000', SLTI='010', SLTIU='011',
                   XORI='100', ORI='110', ANDI='111', SLLI='001', SRLI='101', SRAI='101', ADD='000', SUB='000',
                   SLL='001', SLT='010', SLTU='011', XOR='100', SRL='101', SRA='101', OR='110', AND='111', MUL='000',
                   MULH='001', MULHSU='010', MULHU='011', DIV='100', DIVU='101', REM='110', REMU='111',
                   CSRRW='001', CSRRS='010', CSRRC='011',CSRRWI='101', CSRRSI='110', CSRRCI='111'
)

CSR_SET = [
    (0x001, 'fflags'), (0x002, 'frm'), (0x003, 'fcsr'),
    (0x300, 'mstatus'), (0x301, 'misa'), (0x302, 'medeleg'), (0x303, 'mideleg'), (0x304, 'mie'), (0x305, 'mtvec'),
    (0x340, 'mscratch'), (0x341, 'mepc'), (0x342, 'mcause'), (0x343, 'mbadaddr'), (0x344, 'mip'),
    (0xC00, 'mcycle'), (0xF14, 'mhartid'), (0xF11, 'mvendorid')
]


LOAD_INSTRUCTION_NAMES = {'LB', 'LH', 'LW', 'LBU', 'LHU'}

STORE_INSTRUCTION_NAMES = {'SB', 'SH', 'SW'}

SHIFT_IMMEDIATE_INSTRUCTION_NAMES = {'SLLI', 'SRLI', 'SRAI'}

M_EXTENSION_NAMES = {'MUL', 'MULH', 'MULHSU', 'MULHU', 'DIV', 'DIVU', 'REM', 'REMU'}

CSR_EXTENSION_NAMES = {'CSRRW', 'CSRRS', 'CSRRC', 'CSRRWI', 'CSRRSI', 'CSRRCI'}

# Reversing the instructions table to correlate each instruction with its type directly
INSTRUCTION_TO_TYPE = reverse_dict_with_iterable(TYPES_TO_INSTRUCTION)

TEST_CASES_NUMBER = 0


def validate_binary_instruction(binary_instruction):
    if len(binary_instruction) != 32:
        raise ValueError(
            f"Instruction width overflow: expected 32 bits, got {len(binary_instruction)} bits "
            f"for {binary_instruction}"
        )

    if set(binary_instruction) - {'0', '1'}:
        raise ValueError(f"Instruction contains non-binary characters: {binary_instruction}")

    return binary_instruction


def choose_aligned_immediate(max_value, excluded=None):
    max_value -= max_value % 2

    if max_value < 0:
        raise ValueError(f"Immediate upper bound must be non-negative, got {max_value}")

    slot_count = (max_value // 2) + 1
    excluded_slot = None

    if excluded is not None and excluded % 2 == 0 and 0 <= excluded <= max_value:
        excluded_slot = excluded // 2
        if slot_count == 1:
            raise ValueError("No encodable aligned immediate is available")
        slot_count -= 1

    slot = random.randrange(slot_count)

    if excluded_slot is not None and slot >= excluded_slot:
        slot += 1

    return slot * 2


# Converting a 32 bit binary string instruction to a hexadecimal one
def convert_to_hex(binary_instruction):
    binary_instruction = validate_binary_instruction(binary_instruction)
    return format(int(binary_instruction, 2), '08x')


# Appending Instruction in corresponding lists
def add_instructions(binary, assembly):
    binary = validate_binary_instruction(binary)
    Instructions_list_binary.append(binary)
    instructions_list_assembly.append(assembly)
    instructions_list_hex.append(convert_to_hex(binary))


# Function to generate an R-Type instruction
def generate_r(name):
    # print('Generating R')
    opcode_instruction = OPCODES[name]
    func_instruction = FUNCT_CODES[name]

    # Choosing func7 code
    if name == 'SUB' or name == 'SRA':
        func7_instruction = '0100000'
    elif name in M_EXTENSION_NAMES:
        func7_instruction = '0000001'
    else:
        func7_instruction = '0000000'

    rs1_decimal = random.choice(REGISTERS_TO_USE)
    rs1_binary = "{0:05b}".format(rs1_decimal)
    rs2_decimal = random.choice(REGISTERS_TO_USE)
    rs2_binary = "{0:05b}".format(rs2_decimal)
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_binary = "{0:05b}".format(rd_decimal)

    instruction_binary = func7_instruction + rs2_binary + rs1_binary + func_instruction + rd_binary + opcode_instruction
    instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", x" + str(rs1_decimal) + ", x" + str(
        rs2_decimal)

    add_instructions(instruction_binary, instruction_assembly)


# Function to generate an I-Type instruction
def generate_i(name):
    # print('Generating I')
    opcode_instruction = OPCODES[name]
    func_instruction = FUNCT_CODES[name]
    rs1_decimal = random.choice(REGISTERS_TO_USE)
    rs1_binary = "{0:05b}".format(rs1_decimal)
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_binary = "{0:05b}".format(rd_decimal)

    # Special cases for shift and load instructions
    if name in SHIFT_IMMEDIATE_INSTRUCTION_NAMES:
        if name == 'SRAI':
            imm = '0100000'
        else:
            imm = '0000000'

        shamt_decimal = np.random.randint(0, 32)
        shamt_binary = "{0:05b}".format(shamt_decimal)
        instruction_binary = imm + shamt_binary + rs1_binary + func_instruction + rd_binary + opcode_instruction
        instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", x" + str(rs1_decimal) + ", " + str(
            shamt_decimal)
    elif name in LOAD_INSTRUCTION_NAMES:
        rs1_decimal = 0
        rs1_binary = "{0:05b}".format(rs1_decimal)
        imm_decimal = random.choice(STORED_MEMORY_LOCATIONS)  # Choose from stored in locations
        imm_binary = "{0:012b}".format(imm_decimal)
        instruction_binary = imm_binary + rs1_binary + func_instruction + rd_binary + opcode_instruction
        instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", " + str(imm_decimal) + "(x" \
            + str(rs1_decimal) + ")"
    else:
        imm_decimal = np.random.randint(0, 4095)
        imm_binary = "{0:012b}".format(imm_decimal)
        instruction_binary = imm_binary + rs1_binary + func_instruction + rd_binary + opcode_instruction
        instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", x" + str(rs1_decimal) + ", " + str(
            imm_decimal)

    add_instructions(instruction_binary, instruction_assembly)


# Function to generate an S-Type instruction
def generate_s(name):
    # print('Generating S')
    opcode_instruction = OPCODES[name]
    func_instruction = FUNCT_CODES[name]
    rs1_decimal = 0
    rs1_binary = "{0:05b}".format(rs1_decimal)
    rs2_decimal = random.choice(REGISTERS_TO_USE)
    rs2_binary = "{0:05b}".format(rs2_decimal)
    imm_decimal = 2 * np.random.randint(0, 2047)
    imm_binary = "{0:012b}".format(imm_decimal)

    # Add address to locations to load from list
    STORED_MEMORY_LOCATIONS.append(imm_decimal)

    instruction_binary = imm_binary[0:7] + rs2_binary + rs1_binary + func_instruction + imm_binary[
                                                                                         7:] + opcode_instruction
    instruction_assembly = format(name, '10s') + "\tx" + str(rs2_decimal) + ", " + str(imm_decimal) + "(x" \
        + str(rs1_decimal) + ")"
    add_instructions(instruction_binary, instruction_assembly)


# Function to generate an SB-Type instruction
def generate_sb(name):
    # print('Generating SB')
    opcode_instruction = OPCODES[name]
    func_instruction = FUNCT_CODES[name]
    rs1_decimal = random.choice(REGISTERS_TO_USE)
    rs1_binary = "{0:05b}".format(rs1_decimal)
    rs2_decimal = random.choice(REGISTERS_TO_USE)
    rs2_binary = "{0:05b}".format(rs2_decimal)

    max_branch_immediate = min(max(2, (Instructions_Number * 4) - 2), 4094)
    imm_decimal = choose_aligned_immediate(max_branch_immediate, excluded=INSTRUCTION_CURRENT * 4)

    imm_binary = "{0:012b}".format(imm_decimal)
    instruction_binary = imm_binary[0] + imm_binary[2:8] + rs2_binary + rs1_binary + func_instruction + \
        imm_binary[8:] + imm_binary[1] + opcode_instruction
    instruction_assembly = format(name, '10s') + "\tx" + str(rs1_decimal) + ", x" + str(rs2_decimal) + ", " + str(
        imm_decimal)

    add_instructions(instruction_binary, instruction_assembly)


# Function to generate a U-Type instruction
def generate_u(name):
    # print('Generating U')
    opcode_instruction = OPCODES[name]
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_binary = "{0:05b}".format(rd_decimal)
    imm_decimal = np.random.randint(0, 1048575)
    imm_binary = "{0:020b}".format(imm_decimal)

    instruction_binary = imm_binary + rd_binary + opcode_instruction
    instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", " + str(imm_decimal)

    add_instructions(instruction_binary, instruction_assembly)


# Function to generate an UJ-Type instruction
def generate_uj(name):
    # print('Generating UJ')
    opcode_instruction = OPCODES[name]
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_binary = "{0:05b}".format(rd_decimal)
    max_jump_immediate = min(max(2, (Instructions_Number * 4) - 2), 1048574)
    imm_decimal = choose_aligned_immediate(max_jump_immediate, excluded=INSTRUCTION_CURRENT * 4)

    imm_binary = "{0:020b}".format(imm_decimal)

    instruction_binary = imm_binary[0] + imm_binary[10:] + imm_binary[9] + imm_binary[1:9] + rd_binary + opcode_instruction
    instruction_assembly = format(name, '10s') + "\tx" + str(rd_decimal) + ", " + str(imm_decimal)

    add_instructions(instruction_binary, instruction_assembly)

def generate_csr(name):
    opcode_instruction = OPCODES[name]
    funct3_instruction = FUNCT_CODES[name]

    # Pick a CSR
    csr_val, csr_name = random.choice(CSR_SET)
    csr_bits = f"{csr_val:012b}"

    # Pick rd (x0 to discard read result is allowed)
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_bits = f"{rd_decimal:05b}"

    is_imm = name.endswith('I')
    if is_imm:
        # zimm = 5-bit immediate
        zimm_val = random.randint(0, 31)
        rs1_or_zimm_bits = f"{zimm_val:05b}"
        asm_src = str(zimm_val)
    else:
        rs1_decimal = random.choice(REGISTERS_TO_USE)
        rs1_or_zimm_bits = f"{rs1_decimal:05b}"
        asm_src = f"x{rs1_decimal}"

    # Binary: csr[31:20] | rs1/zimm[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0]
    instruction_binary = (
        csr_bits +
        rs1_or_zimm_bits +
        funct3_instruction +
        rd_bits +
        opcode_instruction
    )

    instruction_assembly = (
        f"{format(name, '10s')}\tx{rd_decimal}, 0x{csr_val:03x}, {asm_src}"
        + f"\t# {csr_name}"
    )

    add_instructions(instruction_binary, instruction_assembly)


def generate_f(name):
    opcode_instruction = OPCODES[name]

    rm_map = {
        'FADD.S': '000', 'FSUB.S': '000', 'FMUL.S': '000', 'FDIV.S': '000', 'FSQRT.S': '000',
        'FCVT.W.S': '000', 'FCVT.WU.S': '000', 'FCVT.S.W': '000', 'FCVT.S.WU': '000'
    }

    enc = {
        'FADD.S': ('0000000', None, 'ffr'),
        'FSUB.S': ('0000100', None, 'ffr'),
        'FMUL.S': ('0001000', None, 'ffr'),
        'FDIV.S': ('0001100', None, 'ffr'),
        'FSQRT.S': ('0101100', '00000', 'ff'),
        'FSGNJ.S': ('0010000', None, 'ffr'),
        'FSGNJN.S': ('0010000', None, 'ffr'),
        'FSGNJX.S': ('0010000', None, 'ffr'),
        'FMIN.S': ('0010100', None, 'ffr'),
        'FMAX.S': ('0010100', None, 'ffr'),
        'FCVT.W.S': ('1100000', '00000', 'fgr'),
        'FCVT.WU.S': ('1100000', '00001', 'fgr'),
        'FMV.X.W': ('1110000', '00000', 'fgr'),
        'FEQ.S': ('1010000', None, 'ffg'),
        'FLT.S': ('1010000', None, 'ffg'),
        'FLE.S': ('1010000', None, 'ffg'),
        'FCLASS.S': ('1110000', '00000', 'fgr'),
        'FCVT.S.W': ('1101000', '00000', 'gfr'),
        'FCVT.S.WU': ('1101000', '00001', 'gfr'),
        'FMV.W.X': ('1111000', '00000', 'gfr')
    }

    funct3_map = {
        'FADD.S': '000', 'FSUB.S': '000', 'FMUL.S': '000', 'FDIV.S': '000', 'FSQRT.S': '000',
        'FSGNJ.S': '000', 'FSGNJN.S': '001', 'FSGNJX.S': '010',
        'FMIN.S': '000', 'FMAX.S': '001',
        'FCVT.W.S': '000', 'FCVT.WU.S': '000',
        'FMV.X.W': '000',
        'FEQ.S': '010', 'FLT.S': '001', 'FLE.S': '000',
        'FCLASS.S': '001',
        'FCVT.S.W': '000', 'FCVT.S.WU': '000', 'FMV.W.X': '000'
    }

    funct7, forced_rs2, form = enc[name]
    rm = rm_map.get(name, funct3_map[name])

    rs1_decimal = random.choice(REGISTERS_TO_USE)
    rs1_binary = f"{rs1_decimal:05b}"
    rs2_decimal = random.choice(REGISTERS_TO_USE)
    rs2_binary = f"{rs2_decimal:05b}"
    rd_decimal = random.choice(REGISTERS_TO_USE)
    rd_binary = f"{rd_decimal:05b}"

    if forced_rs2 is not None:
        rs2_binary = forced_rs2

    instruction_binary = funct7 + rs2_binary + rs1_binary + rm + rd_binary + opcode_instruction

    if form == 'ffr':
        instruction_assembly = f"{format(name, '10s')}\tf{rd_decimal}, f{rs1_decimal}, f{rs2_decimal}"
    elif form == 'ff':
        instruction_assembly = f"{format(name, '10s')}\tf{rd_decimal}, f{rs1_decimal}"
    elif form == 'fgr':
        instruction_assembly = f"{format(name, '10s')}\tx{rd_decimal}, f{rs1_decimal}"
    elif form == 'ffg':
        instruction_assembly = f"{format(name, '10s')}\tx{rd_decimal}, f{rs1_decimal}, f{rs2_decimal}"
    else:
        instruction_assembly = f"{format(name, '10s')}\tf{rd_decimal}, x{rs1_decimal}"

    add_instructions(instruction_binary, instruction_assembly)

# Instruction generation wrapper
def generate_instruction(name):
    if INSTRUCTION_TO_TYPE[name] == 'R_TYPE':
        generate_r(name)
    elif INSTRUCTION_TO_TYPE[name] == 'I_TYPE':
        generate_i(name)
    elif INSTRUCTION_TO_TYPE[name] == 'S_TYPE':
        generate_s(name)
    elif INSTRUCTION_TO_TYPE[name] == 'SB_TYPE':
        generate_sb(name)
    elif INSTRUCTION_TO_TYPE[name] == 'U_TYPE':
        generate_u(name)
    elif INSTRUCTION_TO_TYPE[name] == 'UJ_TYPE':
        generate_uj(name)
    elif INSTRUCTION_TO_TYPE[name] == 'CSR_TYPE':
        generate_csr(name)
    elif INSTRUCTION_TO_TYPE[name] == 'F_TYPE':
        generate_f(name)


# Validaing Input
while int(TEST_CASES_NUMBER) < 1:
    TEST_CASES_NUMBER = input('Enter Number of test cases to produce: ')

for test_case in range(int(TEST_CASES_NUMBER)):
    # Initializing all variables
    REGISTERS_NUMBER = 0
    Instructions_Number = 0
    INSTRUCTION_CURRENT = 0
    STORED_MEMORY_LOCATIONS = []
    Instructions_list_binary = []
    instructions_list_assembly = []
    instructions_list_hex = []

    # Recieving and validaing inputs
    while int(Instructions_Number) < 1:
        Instructions_Number = input('Enter Number of Instructions to produce: ')

    while int(REGISTERS_NUMBER) < 1 or int(REGISTERS_NUMBER) > 32:
        REGISTERS_NUMBER = input('Enter Number of Registers to use(1 to 32) : ')

    # Random Registers to use
    REGISTERS_TO_USE = np.random.randint(1, 32, int(REGISTERS_NUMBER))
    Instructions_Number = int(Instructions_Number)

    # Generating instructions
    for instruction in range(Instructions_Number):
        INSTRUCTION_CURRENT = instruction
        instruction_name = random.choice(list(INSTRUCTION_TO_TYPE.keys()))

        # Check for load instruction with no prior store
        while instruction_name in LOAD_INSTRUCTION_NAMES and len(STORED_MEMORY_LOCATIONS) == 0:
            instruction_name = random.choice(list(INSTRUCTION_TO_TYPE.keys()))

        generate_instruction(instruction_name)

    # Writing and formatting ouput files
    binary_file = open("C:/Ain_shams/RiscV/Python/binary" + str(test_case + 1) + ".txt", "w")
    assembly_file = open("C:/Ain_shams/RiscV/Python/assembly" + str(test_case + 1) + ".s", "w")
    hex_file = open("C:/Ain_shams/RiscV/Python/hex" + str(test_case + 1) + ".v", "w")

    assembly_file.write('test' + str(test_case + 1) + '.elf:     file format elf32-littleriscv\n\n\n')
    assembly_file.write('Disassembly of section .text:\n\n00000000 <main>:\n')
    hex_file.write("@00000000\n")

    for i in range(Instructions_Number):
        binary_file.write(Instructions_list_binary[i] + "\n")
        assembly_file.write(
            str(hex(i * 4))[2:] + ':\t\t' + instructions_list_hex[i] + '\t' + instructions_list_assembly[i] + "\n")
        split_hex = re.findall('..', instructions_list_hex[i])
        if i % 4 == 0 and i != 0:
            hex_file.write("\n")
        hex_file.write(split_hex[3] + ' ' + split_hex[2] + ' ' + split_hex[1] + ' ' + split_hex[0] + ' ')

    binary_file.close()
    assembly_file.close()
    hex_file.close()

    print("FINISHED TEST CASE " + str(test_case + 1))
