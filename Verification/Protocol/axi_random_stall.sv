// =============================================================================
// axi_random_stall.sv
// -----------------------------------------------------------------------------
// Verification-only AXI4 back-pressure shim between one master and one slave.
//
// On every channel the VALID seen by the receiver and the READY seen by the
// sender are both gated by the same random per-cycle "open" bit, so a beat
// still transfers only when VALID and READY are high together, and the
// sender keeps its payload stable while the gate is closed - the AXI rules
// hold, only the timing changes. This exposes pipeline-freeze bugs that a
// zero-wait memory hides.
//
// Stall probability per channel per cycle: +AXI_STALL_PCT=<0..95> (default
// 0 = transparent).
// =============================================================================
import shared_pkg::*;

module axi_random_stall
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int AXI_SIZE   = 4
)
(
    input  logic clk,

    // ── Master side (core / cache) ───────────────────────────────────────────
    input  logic [ADDR_WIDTH-1:0]     m_MAWAddr,
    input  logic [7:0]                m_MAWLen,
    input  logic [AXI_SIZE-1:0]       m_MAWSize,
    input  axi_burst_t                m_MAWBurst,
    input  logic                      m_MAWValid,
    output logic                      m_MAWReady,
    input  logic [DATA_WIDTH-1:0]     m_MWData,
    input  logic [(DATA_WIDTH/8)-1:0] m_MWStrb,
    input  logic                      m_MWLast,
    input  logic                      m_MWValid,
    output logic                      m_MWReady,
    input  logic                      m_MBReady,
    output axi_resp_t                 m_MBResp,
    output logic                      m_MBValid,
    input  logic [ADDR_WIDTH-1:0]     m_MARAddr,
    input  logic [7:0]                m_MARLen,
    input  logic [AXI_SIZE-1:0]       m_MARSize,
    input  axi_burst_t                m_MARBurst,
    input  logic                      m_MARValid,
    output logic                      m_MARReady,
    input  logic                      m_MRReady,
    output logic [DATA_WIDTH-1:0]     m_MRRData,
    output axi_resp_t                 m_MRRResp,
    output logic                      m_MRRLast,
    output logic                      m_MRRValid,

    // ── Slave side (memory) ───────────────────────────────────────────────────
    output logic [ADDR_WIDTH-1:0]     s_MAWAddr,
    output logic [7:0]                s_MAWLen,
    output logic [AXI_SIZE-1:0]       s_MAWSize,
    output axi_burst_t                s_MAWBurst,
    output logic                      s_MAWValid,
    input  logic                      s_MAWReady,
    output logic [DATA_WIDTH-1:0]     s_MWData,
    output logic [(DATA_WIDTH/8)-1:0] s_MWStrb,
    output logic                      s_MWLast,
    output logic                      s_MWValid,
    input  logic                      s_MWReady,
    output logic                      s_MBReady,
    input  axi_resp_t                 s_MBResp,
    input  logic                      s_MBValid,
    output logic [ADDR_WIDTH-1:0]     s_MARAddr,
    output logic [7:0]                s_MARLen,
    output logic [AXI_SIZE-1:0]       s_MARSize,
    output axi_burst_t                s_MARBurst,
    output logic                      s_MARValid,
    input  logic                      s_MARReady,
    output logic                      s_MRReady,
    input  logic [DATA_WIDTH-1:0]     s_MRRData,
    input  axi_resp_t                 s_MRRResp,
    input  logic                      s_MRRLast,
    input  logic                      s_MRRValid
);

    int unsigned stall_pct = 0;
    logic        open_aw = 1, open_w = 1, open_b = 1, open_ar = 1, open_r = 1;

    initial
    begin
        void'($value$plusargs("AXI_STALL_PCT=%d", stall_pct));
        if(stall_pct > 95) stall_pct = 95;
    end

    // New gate values just after each rising edge, stable for the whole cycle
    always @(posedge clk)
    begin
        open_aw <= ($urandom_range(0, 99) >= stall_pct);
        open_w  <= ($urandom_range(0, 99) >= stall_pct);
        open_b  <= ($urandom_range(0, 99) >= stall_pct);
        open_ar <= ($urandom_range(0, 99) >= stall_pct);
        open_r  <= ($urandom_range(0, 99) >= stall_pct);
    end

    always_comb
    begin
        // Write address
        s_MAWAddr  = m_MAWAddr;
        s_MAWLen   = m_MAWLen;
        s_MAWSize  = m_MAWSize;
        s_MAWBurst = m_MAWBurst;
        s_MAWValid = m_MAWValid & open_aw;
        m_MAWReady = s_MAWReady & open_aw;
        // Write data
        s_MWData   = m_MWData;
        s_MWStrb   = m_MWStrb;
        s_MWLast   = m_MWLast;
        s_MWValid  = m_MWValid & open_w;
        m_MWReady  = s_MWReady & open_w;
        // Write response
        m_MBResp   = s_MBResp;
        m_MBValid  = s_MBValid & open_b;
        s_MBReady  = m_MBReady & open_b;
        // Read address
        s_MARAddr  = m_MARAddr;
        s_MARLen   = m_MARLen;
        s_MARSize  = m_MARSize;
        s_MARBurst = m_MARBurst;
        s_MARValid = m_MARValid & open_ar;
        m_MARReady = s_MARReady & open_ar;
        // Read data
        m_MRRData  = s_MRRData;
        m_MRRResp  = s_MRRResp;
        m_MRRLast  = s_MRRLast;
        m_MRRValid = s_MRRValid & open_r;
        s_MRReady  = m_MRReady & open_r;
    end

endmodule
