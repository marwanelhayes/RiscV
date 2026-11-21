// =============================================================================
// spike_dpi.cc
// -----------------------------------------------------------------------------
// Spike (riscv-isa-sim) as a second, independent ISA reference for the
// full-core checker. commit_checker steps it once per commit next to the
// in-house ISS, with the same interrupt lines, the same DUT read value for
// mcycle and the same TB mtime, and compares the two commit records field by
// field.
//
// The hart is a bare processor_t on a simif_t that provides the core's
// shared RAM, with byte addresses truncated to ADDR_BITS like the core.
//
// Core profile: the implementation choices the specs leave open, set the way
// the core documents them (riscv_iss_pkg.sv header). Everything else is
// Spike's own reading of the specs.
//   - ISA rv<XLEN>imaf_zicsr_zicntr_zifencei, M, S and U modes (priv "MSU", no
//     MMU: satp reads 0, SUM/MXR/TVM read 0, SFENCE.VMA is illegal), no PMP CSRs, no mcountinhibit, WFI is a NOP (wfi_as_nop)
//   - f0-f31 reset to +0 like x0-x31 (Spike's raw reset value is not a boxed
//     single and would read as NaN)
//   - scontext does not exist; medeleg bit 19 (Zicntr fault) is writable, as in Spike
//   - misa is read-only; mvendorid = the core's value, marchid = 0
//   - mtval/stval = 0 for illegal-instruction and breakpoint traps
//   - mstatus.FS is real (reset Off); only an FP register or fcsr write dirties it
//   - FP operations do not accrue fflags (known core gap B9.1)
//   - mcycle/cycle(h) reads return the DUT's value (not predictable)
//   - time/timeh read the TB's mtime: spike_step syncs it into Spike's time
//     CSR before every step, so Spike's own read path (mcounteren gate,
//     timeh) is used
//   - data RAM is reservable (LR/SC work on it; Spike's default treats
//     MMIO-only memory as non-reservable and would raise access faults)
// =============================================================================
#include <riscv/processor.h>
#include <riscv/simif.h>
#include <riscv/cfg.h>
#include <riscv/csrs.h>
#include <riscv/encoding.h>
#include <svdpi.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <map>
#include <memory>
#include <string>

namespace {

constexpr unsigned ADDR_BITS = 12;                    // 4 KiB per memory, as FINAL_ADDR_WIDTH
constexpr size_t   MEM_SIZE  = size_t(1) << ADDR_BITS;

class core_sim_t : public simif_t {
public:
    uint8_t image[MEM_SIZE] = {};
    uint8_t dmem[MEM_SIZE] = {};
    cfg_t   cfg;
    std::map<size_t, processor_t*> harts;

    char* addr_to_mem(reg_t) override { return nullptr; }   // use the wrapped physical address below
    bool reservable(reg_t) override { return true; }        // LR/SC on the data RAM
    bool mmio_fetch(reg_t a, size_t len, uint8_t* b) override { return copy(dmem, a, len, b); }
    bool mmio_load(reg_t a, size_t len, uint8_t* b) override { return copy(dmem, a, len, b); }
    bool mmio_store(reg_t a, size_t len, const uint8_t* b) override {
        for (size_t i = 0; i < len; i++) dmem[(a + i) & (MEM_SIZE - 1)] = b[i];
        return true;
    }
    void proc_reset(unsigned) override {}
    const cfg_t& get_cfg() const override { return cfg; }
    const std::map<size_t, processor_t*>& get_harts() const override { return harts; }
    const char* get_symbol(uint64_t) override { return nullptr; }

private:
    static bool copy(const uint8_t* m, reg_t a, size_t len, uint8_t* b) {
        for (size_t i = 0; i < len; i++) b[i] = m[(a + i) & (MEM_SIZE - 1)];
        return true;
    }
};

core_sim_t*  sim;
processor_t* proc;
FILE*        devnull;
std::ostream nullout(nullptr);
std::string  isa;
unsigned     xlen;
uint32_t     mvendorid;

uint64_t mask(uint64_t v) { return xlen == 64 ? v : (v & 0xFFFFFFFFull); }

void apply_profile() {
    state_t* s = proc->get_state();
    auto& m = s->csrmap;
    for (reg_t i = 0; i < 16; i++) m.erase(CSR_PMPCFG0 + i);
    for (reg_t i = 0; i < 64; i++) m.erase(CSR_PMPADDR0 + i);
    m[CSR_MISA]      = std::make_shared<const_csr_t>(proc, CSR_MISA, s->misa->read());
    m[CSR_MVENDORID] = std::make_shared<const_csr_t>(proc, CSR_MVENDORID, mvendorid);
    m[CSR_MARCHID]   = std::make_shared<const_csr_t>(proc, CSR_MARCHID, 0);
    m.erase(CSR_MCOUNTINHIBIT);
    m.erase(CSR_SCONTEXT);
}

uint32_t fetch32(uint64_t pc) {
    uint32_t w = 0;
    for (int i = 0; i < 4; i++) w |= uint32_t(sim->dmem[(pc + i) & (MEM_SIZE - 1)]) << (8 * i);
    return w;
}

}  // namespace

extern "C" {

// Load the program image ($readmemb format: one 32-bit word per line) and
// build the hart. Returns 0 on success.
int spike_init(int xlen_in, const char* image, unsigned int mvendorid_in, const char* data_image) {
    xlen = unsigned(xlen_in);
    mvendorid = mvendorid_in;
    sim = new core_sim_t();

    std::ifstream f(image);
    if (!f) { std::fprintf(stderr, "spike_dpi: cannot open %s\n", image); return 1; }
    std::string line;
    size_t addr = 0;
    while (std::getline(f, line) && addr + 4 <= MEM_SIZE) {
        if (line.size() < 32 || line.find_first_not_of("01\r") != std::string::npos) continue;
        uint32_t w = uint32_t(std::stoul(line.substr(0, 32), nullptr, 2));
        for (int i = 0; i < 4; i++) sim->image[addr++] = uint8_t(w >> (8 * i));
    }

    // The optional XLEN-word data image overlays the same bytes as in the bench.
    std::ifstream data(data_image);
    uint64_t word;
    addr = 0;
    while (addr + xlen / 8 <= MEM_SIZE && (data >> std::hex >> word))
        for (unsigned i = 0; i < xlen / 8; i++) sim->image[addr++] = uint8_t(word >> (8 * i));

    isa = "rv" + std::to_string(xlen) + "imaf_zicsr_zicntr_zifencei";
    sim->cfg.isa = isa.c_str();
    sim->cfg.priv = "MSU";
    sim->cfg.pmpregions = 0;
    sim->cfg.wfi_as_nop = true;
    devnull = std::fopen("/dev/null", "w");
    proc = new processor_t(sim->cfg.isa, sim->cfg.priv, &sim->cfg, sim, 0, false, devnull, nullout);
    sim->harts[0] = proc;
    proc->enable_log_commits();   // rebuilds the opcode map; fills log_reg_write / log_mem_write
    return 0;
}

void spike_reset() {
    proc->reset();
    proc->get_state()->pc = 0;
    for (int i = 0; i < 32; i++)                          // profile: f0-f31 reset to +0 (NaN-boxed)
        proc->get_state()->FPR.write(i, freg_t{{0xFFFFFFFF00000000ull, ~0ull}});
    std::memcpy(sim->dmem, sim->image, MEM_SIZE);
    apply_profile();
}

// One step: an interrupt taken before the instruction, an exception, or one
// retired instruction. Outputs mirror riscv_iss_pkg::iss_commit_t.
void spike_step(svBit ext, svBit tmr, svBit sw, svBit sext, uint64_t csr_rdata, uint64_t mtime,
                uint64_t* pc, unsigned int* insn, svBit* trap, svBit* interrupt,
                uint64_t* cause, uint64_t* tval,
                svBit* rd_we, int* rd, uint64_t* rd_val,
                svBit* frd_we, int* frd, unsigned int* frd_val,
                svBit* st_we, uint64_t* st_addr, int* st_size, uint64_t* st_data,
                uint64_t* next_pc) {
    state_t* s = proc->get_state();
    s->mip->backdoor_write_with_mask(MIP_MEIP | MIP_MTIP | MIP_MSIP | MIP_SEIP,
                                     (ext ? MIP_MEIP : 0) | (tmr ? MIP_MTIP : 0) | (sw ? MIP_MSIP : 0) |
                                     (sext ? MIP_SEIP : 0));
    s->time->sync(mtime);
    s->log_reg_write.clear();
    s->log_mem_read.clear();
    s->log_mem_write.clear();

    *pc = mask(s->pc);
    *insn = fetch32(s->pc);
    const uint32_t in = *insn;
    const reg_t fflags_before = s->fflags->read();
    const reg_t fs_before = s->mstatus->read() & MSTATUS_FS;

    proc->step(1);

    const auto& w = s->log_reg_write;
    const bool trapped_m = w.count((CSR_MEPC << 4) | 4) && w.count((CSR_MCAUSE << 4) | 4);
    const bool trapped_s = w.count((CSR_SEPC << 4) | 4) && w.count((CSR_SCAUSE << 4) | 4);
    const bool trapped = trapped_m || trapped_s;
    *trap = trapped;
    *interrupt = 0; *cause = 0; *tval = 0;
    *rd_we = 0; *rd = 0; *rd_val = 0;
    *frd_we = 0; *frd = 0; *frd_val = 0;
    *st_we = 0; *st_addr = 0; *st_size = 0; *st_data = 0;

    if (trapped) {
        // the delegated trap lands in the S registers
        csr_t_p c = trapped_s ? s->nonvirtual_scause : s->mcause;
        csr_t_p t = trapped_s ? s->nonvirtual_stval : s->mtval;
        *cause = mask(c->read());
        *interrupt = (*cause >> (xlen - 1)) & 1;
        if (!*interrupt && (*cause == CAUSE_ILLEGAL_INSTRUCTION || *cause == CAUSE_BREAKPOINT))
            t->write(0);                                           // profile: mtval/stval = 0
        *tval = mask(t->read());
    } else {
        for (const auto& [key, val] : w) {
            const int r = int(key >> 4);
            if ((key & 0xF) == 0 && r != 0) { *rd_we = 1; *rd = r; *rd_val = mask(val.v[0]); }
            if ((key & 0xF) == 1)           { *frd_we = 1; *frd = r; *frd_val = uint32_t(val.v[0]); }
        }
        if (!s->log_mem_write.empty()) {
            const auto& [a, v, size] = s->log_mem_write.front();
            *st_we = 1; *st_addr = mask(a); *st_size = size;
            *st_data = size == 8 ? v : (v & ((uint64_t(1) << (8 * size)) - 1));
        }
        // profile: mcycle / cycle (and the RV32 high halves) read the DUT's value
        const uint32_t csr = in >> 20, f3 = (in >> 12) & 7;
        if ((in & 0x7F) == 0x73 && f3 != 0 && f3 != 4 &&
            (csr == CSR_MCYCLE || csr == CSR_CYCLE || csr == CSR_MCYCLEH || csr == CSR_CYCLEH) && *rd_we) {
            const reg_t v = xlen == 32 ? reg_t(int64_t(int32_t(csr_rdata))) : csr_rdata;
            s->XPR.write(*rd, v);
            *rd_val = mask(v);
        }
        // profile: FP operations do not accrue fflags, so only an FP register write
        // dirties FS (Spike also dirties it when a flag would be raised)
        if ((in & 0x7F) == 0x53) {
            s->fflags->write(fflags_before);
            if (!*frd_we)
                s->mstatus->write((s->mstatus->read() & ~reg_t(MSTATUS_FS)) | fs_before);
        }
    }
    *next_pc = mask(s->pc);
}

}  // extern "C"
