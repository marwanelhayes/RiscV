"""One-line RTL mutants of Design/csr_file.sv (B4 mutation proof).

  python3 Scripts/mk_mutants.py build <repo> <outdir>   one tree per mutant, each differs by exactly one line
  python3 Scripts/mk_mutants.py check <outdir>          CAUGHT / SURVIVED per mutant from its logs

Run each tree in between (own Scratch):
  <outdir>/<name>/Scripts/regress.sh -s 1234 -x "32 64" -t "csr_top risc_top" -c

A mutant is CAUGHT when any of its logs has >= 1 UVM_ERROR/UVM_FATAL under one of its expected IDs.
Directed/compliance tests and SVAs report a failure once, so one hit is enough.
build also makes an unmutated tree 'baseline' (run it the same way): an ID that already fails in the
same baseline log (the known rv*uf / ma_data compliance fails) does not count.
"""
import collections, glob, os, re, shutil, subprocess, sys

LOCKSTEP = ('ISS_CHK', 'SPIKE_CHK')
CSR_ENV = ('csr_scoreboard', 'csr_reg_checker')
M = [  # name, line (only used when the text occurs more than once), old, new, expected error IDs
 ('tos_m',     372, 'ToS = (PrivMode != MachineMode) &&', 'ToS = 1\'b1 &&', ('COMPLIANCE',) + LOCKSTEP),
 ('sie_noand', 223, 'CsrOut = MieValue & MidelegMask;', 'CsrOut = MieValue;', ('COMPLIANCE',) + LOCKSTEP + CSR_ENV),
 ('ens_m',     353, '(PrivMode == SupervisorMode && MStatusSIE)', 'MStatusSIE', LOCKSTEP + CSR_ENV + ('SVA_CSR',)),
 ('sret_tsr',  340, '(PrivMode == SupervisorMode && MStatusTSR)', '1\'b0', ('COMPLIANCE',)),
 ('sret_spp',  495, "MStatusSPP  <= 1'b0;", 'MStatusSPP  <= MStatusSPP;', ('COMPLIANCE', 'SVA_CSR') + LOCKSTEP),
 ('sret_mprv', 496, "MStatusMPRV <= 1'b0;", 'MStatusMPRV <= MStatusMPRV;', ('COMPLIANCE',) + LOCKSTEP),
 ('mip_base',  None, 'CsrBase[`SE_I] = MipSeipSw;', 'CsrBase[`SE_I] = MipValue[`SE_I];', ('COMPLIANCE',) + LOCKSTEP),
 ('cnt_scen',  331, ' || (PrivMode == UserMode && !Scounteren[`CY])', '', ('COMPLIANCE',) + LOCKSTEP),
 ('cnt_mcen',  331, '(PrivMode != MachineMode && !Mcounteren[`CY])', '(PrivMode == UserMode && !Mcounteren[`CY])', ('COMPLIANCE',) + LOCKSTEP),
 ('ecall_s',   169, "EcallSOrSupervisorExternalInterrupt: TrapCause = DATA_WIDTH'(9);", "EcallSOrSupervisorExternalInterrupt: TrapCause = DATA_WIDTH'(11);", LOCKSTEP),
 ('med_b11',   87,  "20'h8_03FF", "20'h8_0BFF", ('COMPLIANCE',) + LOCKSTEP),
 ('med_b19',   87,  "20'h8_03FF", "20'h0_03FF", ('COMPLIANCE',) + LOCKSTEP),
 ('stval_ill', 464, '(InterruptPending || CsrIllegal) ?', 'InterruptPending ?', LOCKSTEP + ('SVA_CSR',)),
 ('wfi_u',     341, '(MStatusTW || PrivMode == UserMode)', 'MStatusTW', ('COMPLIANCE',) + LOCKSTEP),
 ('irq_order', 354, 'IrqSel   = (|IrqPendM) ? IrqPendM : IrqPendS;', 'IrqSel   = IrqPendM | IrqPendS;', ('COMPLIANCE',) + CSR_ENV),
 ('fs_off',    342, '(FpOp && MStatusFS == 2\'b00) ||', '', LOCKSTEP + CSR_ENV),
]
# "# UVM_ERROR <file>(<line>) @ <time>: <reporter> [<ID>] ..." (the file part is absent for SVAs)
ERROR_RE = re.compile(r'^# UVM_(?:ERROR|FATAL) .*?@ *\d+: \S+ \[([^\]]+)\]')


def build(repo, out):
    src = open(os.path.join(repo, 'Design/csr_file.sv')).read().split('\n')
    for name, line, old, new, _ in M + [('baseline', None, None, None, ())]:
        d = os.path.join(out, name)
        if name == 'baseline':
            shutil.rmtree(d, ignore_errors=True)
            for sub in ('Design', 'Verification', 'Program', 'Scripts'):
                shutil.copytree(os.path.join(repo, sub), os.path.join(d, sub), symlinks=True)
            os.symlink(os.path.join(repo, 'ThirdParty'), os.path.join(d, 'ThirdParty'))
            print('baseline   (unmutated)')
            continue
        hits = [i + 1 for i, l in enumerate(src) if old in l]
        if len(hits) > 1:
            hits = [h for h in hits if h == line]          # several matches: the line number picks one
        assert len(hits) == 1 and src[hits[0] - 1].count(old) == 1, (name, hits)
        line = hits[0]
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
        for sub in ('Design', 'Verification', 'Program', 'Scripts'):
            shutil.copytree(os.path.join(repo, sub), os.path.join(d, sub), symlinks=True)
        os.symlink(os.path.join(repo, 'ThirdParty'), os.path.join(d, 'ThirdParty'))
        mut = list(src)
        mut[line - 1] = mut[line - 1].replace(old, new)
        open(os.path.join(d, 'Design/csr_file.sv'), 'w').write('\n'.join(mut))
        diff = subprocess.run(['diff', os.path.join(repo, 'Design/csr_file.sv'), os.path.join(d, 'Design/csr_file.sv')],
                              capture_output=True, text=True).stdout
        changed = [l for l in diff.splitlines() if l[:1] in '<>']
        assert len(changed) == 2, (name, diff)
        print('{:10s} {}'.format(name, changed[1][2:].strip()))


def error_ids(log):
    """Counter of UVM_ERROR/UVM_FATAL IDs in one log."""
    with open(log, errors='replace') as f:
        return collections.Counter(m.group(1) for m in map(ERROR_RE.match, f) if m)


def logs_of(out, name):
    return sorted(glob.glob(os.path.join(out, name, 'Scratch', 'x*', 'run', 'logs', '*.log')))


def check(out):
    base_logs = logs_of(out, 'baseline')
    if not base_logs:
        sys.exit('baseline not run: run {}/baseline/Scripts/regress.sh like the mutants first'.format(out))
    # (x32/rv32uf-p-fadd, COMPLIANCE) pairs that fail without any mutant
    known = {(rel, i) for log in base_logs for i in error_ids(log)
             for rel in [os.path.relpath(log, os.path.join(out, 'baseline'))]}
    print('baseline: {} failing (log, ID) pairs ignored'.format(len(known)))
    survived = 0
    for name, _, _, _, expected in M:
        logs = logs_of(out, name)
        if not logs:
            print('{:10s} NOT RUN'.format(name))
            survived += 1
            continue
        hits, other = collections.Counter(), collections.Counter()
        where = collections.defaultdict(list)
        for log in logs:
            run = '{}/{}'.format(log.split(os.sep)[-4], os.path.basename(log)[:-4])     # x32/risc_top.s1234
            for i, n in error_ids(log).items():
                if (os.path.relpath(log, os.path.join(out, name)), i) in known:
                    continue
                (hits if i in expected else other)[i] += n
                if i in expected:
                    where[i].append(run)
        survived += not hits
        print('{:10s} {:8s} expected {}'.format(name, 'CAUGHT' if hits else 'SURVIVED', '/'.join(expected)))
        for i, n in hits.items():
            print('             {:16s} {:4d}  {}'.format(i, n, ' '.join(where[i][:6]) + (' ...' if len(where[i]) > 6 else '')))
        if other:
            print('             other: ' + ', '.join('{} {}'.format(i, n) for i, n in other.items()))
    print('{} of {} mutants caught'.format(len(M) - survived, len(M)))
    return survived


def selftest():
    assert ERROR_RE.match('# UVM_ERROR /a/commit_checker.sv(175) @ 3135: reporter [COMPLIANCE] FAIL: x').group(1) == 'COMPLIANCE'
    assert ERROR_RE.match('# UVM_ERROR @ 1525: reporter [SVA_MEMORY] MEM/WB did not').group(1) == 'SVA_MEMORY'
    assert ERROR_RE.match('# UVM_FATAL /a.sv(9) @ 0: uvm_test_top.env.sb [csr_scoreboard] bad').group(1) == 'csr_scoreboard'
    assert not ERROR_RE.match('# UVM_ERROR :    1')                       # report summary line
    assert not ERROR_RE.match('# UVM_INFO /a.sv(177) @ 9: reporter [ISS_CHK] summary: 0 mismatches')


if __name__ == '__main__':
    selftest()
    if len(sys.argv) == 4 and sys.argv[1] == 'build':
        build(*sys.argv[2:])
    elif len(sys.argv) == 3 and sys.argv[1] == 'check':
        sys.exit(1 if check(sys.argv[2]) else 0)
    else:
        sys.exit(__doc__)
