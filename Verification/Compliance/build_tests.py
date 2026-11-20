# =============================================================================
# build_tests.py
# -----------------------------------------------------------------------------
# Builds the riscv-tests ISA programs and local directed tests for risc_top.
#
# The test sources, environment (env/p) and per-suite test lists (Makefrag)
# are used unmodified; only the link script differs (link.ld: code and data
# in the core's 4 KiB address space). Each test becomes one program directory:
#   binary1.txt       whole image, one 32-bit word per line ($readmemb)
#   dmem.hex          whole image, one XLEN-bit word per line ($readmemh)
#   program_info.txt  number of 32-bit words in the image
#   tohost.txt        address of the tohost symbol (hex)
#
# Usage:
#   python3 build_tests.py --xlen 32 --out <dir> [--riscv-tests <path>]
#                          [--suites ui um ua uf mi | --fence-i]
# Prints one line per test: "<name> <dir>" when built, "SKIP <name> <reason>"
# when it does not link (too large for the memories) or is out of scope
# (OUT_OF_SCOPE: needs an extension the core does not implement).
# =============================================================================
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
PREFIX = "riscv64-unknown-elf-"
MEM_BYTES = 4096                    # 2**FINAL_ADDR_WIDTH

# rv32mi/rv64mi tests the core does not claim (docs/blocks/B3.md, Compliance)
OUT_OF_SCOPE = {
    "breakpoint": "out of scope: needs Sdtrig trigger CSRs (tselect traps)",
    "pmpaddr": "out of scope: needs PMP CSRs (B6.1)",
}


def suite_tests(isa_dir, suite):
    """Test names of one suite, from its Makefrag (<suite>_sc_tests)."""
    text = open(os.path.join(isa_dir, suite, "Makefrag")).read().replace("\\\n", " ")
    m = re.search(rf"^{suite}_sc_tests\s*=(.*)$", text, re.M)
    return m.group(1).split() if m else []


def build(isa_dir, env_dir, name, source, xlen, out_dir):
    """Compile one test; return (dir, None) or (None, reason)."""
    arch = ["-march=rv32g", "-mabi=ilp32"] if xlen == 32 else ["-march=rv64g", "-mabi=lp64d"]
    tdir = os.path.join(out_dir, name)
    os.makedirs(tdir, exist_ok=True)
    elf = os.path.join(tdir, name)
    cc = subprocess.run([PREFIX + "gcc", *arch, "-static", "-mcmodel=medany", "-fvisibility=hidden",
                         "-nostdlib", "-nostartfiles", "-I" + env_dir,
                         "-I" + os.path.join(isa_dir, "macros", "scalar"),
                         "-T" + os.path.join(HERE, "link.ld"),
                         source, "-o", elf],
                        capture_output=True, text=True)
    if cc.returncode != 0:
        why = re.search(r"(code|data) does not fit[^\n\"]*", cc.stderr)
        return None, why.group(0) if why else cc.stderr.strip().splitlines()[-1]

    subprocess.run([PREFIX + "objcopy", "-O", "binary", elf, elf + ".bin"], check=True)
    image = open(elf + ".bin", "rb").read()
    assert len(image) <= MEM_BYTES, name
    word = xlen // 8
    image += bytes(-len(image) % word)

    with open(os.path.join(tdir, "binary1.txt"), "w") as f:
        for i in range(0, len(image), 4):
            f.write(f"{int.from_bytes(image[i:i + 4], 'little'):032b}\n")
    with open(os.path.join(tdir, "dmem.hex"), "w") as f:
        for i in range(0, len(image), word):
            f.write(f"{int.from_bytes(image[i:i + word], 'little'):0{2 * word}x}\n")
    with open(os.path.join(tdir, "program_info.txt"), "w") as f:
        f.write(f"{len(image) // 4}\n")

    nm = subprocess.run([PREFIX + "nm", elf], capture_output=True, text=True, check=True).stdout
    tohost = re.search(r"^([0-9a-f]+) \w tohost$", nm, re.M)
    with open(os.path.join(tdir, "tohost.txt"), "w") as f:
        f.write(tohost.group(1) + "\n")
    return tdir, None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--xlen", type=int, choices=(32, 64), required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--riscv-tests", default=os.path.join(REPO, "third_party", "riscv-tests"))
    selection = ap.add_mutually_exclusive_group()
    selection.add_argument("--suites", nargs="+", default=["ui", "um", "ua", "uf", "mi"])
    selection.add_argument("--fence-i", action="store_true", help="build only the two FENCE.I tests")
    args = ap.parse_args()

    isa_dir = os.path.join(args.riscv_tests, "isa")
    env_dir = os.path.join(args.riscv_tests, "env", "p")
    if not os.path.isdir(env_dir):
        sys.exit(f"riscv-tests not found at {args.riscv_tests} "
                 "(git clone --recursive https://github.com/riscv-software-src/riscv-tests)")
    tests = []
    for s in ["ui"] if args.fence_i else args.suites:
        suite = f"rv{args.xlen}{s}"
        names = ["fence_i"] if args.fence_i else suite_tests(isa_dir, suite)
        tests.extend((f"{suite}-p-{name}", os.path.join(isa_dir, suite, name + ".S")) for name in names)
        if s == "ui":
            tests.append((f"{suite}-p-fence_i_smc", os.path.join(HERE, "fence_i_smc.S")))
        if s == "mi":
            tests.append((f"{suite}-p-priv_u_mode", os.path.join(HERE, "priv_u_mode.S")))

    for name, source in tests:
        test = name.split("-p-")[1]
        if test in OUT_OF_SCOPE:
            print(f"SKIP {name} {OUT_OF_SCOPE[test]}")
            continue
        tdir, why = build(isa_dir, env_dir, name, source, args.xlen, args.out)
        if not tdir and name.endswith(("-p-fence_i", "-p-fence_i_smc")):
            sys.exit(f"{name}: {why}")
        print(f"{name} {tdir}" if tdir else f"SKIP {name} {why}")


if __name__ == "__main__":
    main()
