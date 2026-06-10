// =============================================================================
// axi_interface.sv
// -----------------------------------------------------------------------------
// Reusable AXI4 verification interface with master/slave modports and assertions.
// =============================================================================
import shared_pkg::*;

interface axi_interface
#(
    parameter int  DATA_WIDTH = 32,
    parameter int  ADDR_WIDTH = 32,
    parameter int  AXI_SIZE   = 4
)
(
    input bit clk
);

    logic                  rst;

    // ── AXI4 write address channel ───────────────────────────────────────────
    logic [ADDR_WIDTH-1:0] MAWAddr;
    logic [7:0]            MAWLen;
    logic [AXI_SIZE-1:0]   MAWSize;
    axi_burst_t            MAWBurst;
    logic                  MAWValid;
    logic                  MAWReady;

    // ── AXI4 write data channel ──────────────────────────────────────────────
    logic [DATA_WIDTH-1:0] MWData;
    logic [(DATA_WIDTH/8)-1:0] MWStrb;
    logic                  MWLast;
    logic                  MWValid;
    logic                  MWReady;

    // ── AXI4 write response channel ──────────────────────────────────────────
    logic                  MBReady;
    axi_resp_t             MBResp;
    logic                  MBValid;

    // ── AXI4 read address channel ────────────────────────────────────────────
    logic [ADDR_WIDTH-1:0] MARAddr;
    logic [7:0]            MARLen;
    logic [AXI_SIZE-1:0]   MARSize;
    axi_burst_t            MARBurst;
    logic                  MARValid;
    logic                  MARReady;

    // ── AXI4 read data channel ───────────────────────────────────────────────
    logic                  MRReady;
    logic [DATA_WIDTH-1:0] MRRData;
    axi_resp_t             MRRResp;
    logic                  MRRLast;
    logic                  MRRValid;

    modport MASTER (
        input  clk,
        input  rst,
        output MAWAddr,
        output MAWLen,
        output MAWSize,
        output MAWBurst,
        output MAWValid,
        input  MAWReady,
        output MWData,
        output MWStrb,
        output MWLast,
        output MWValid,
        input  MWReady,
        output MBReady,
        input  MBResp,
        input  MBValid,
        output MARAddr,
        output MARLen,
        output MARSize,
        output MARBurst,
        output MARValid,
        input  MARReady,
        output MRReady,
        input  MRRData,
        input  MRRResp,
        input  MRRLast,
        input  MRRValid
    );

    modport SLAVE (
        input  clk,
        input  rst,
        input  MAWAddr,
        input  MAWLen,
        input  MAWSize,
        input  MAWBurst,
        input  MAWValid,
        output MAWReady,
        input  MWData,
        input  MWStrb,
        input  MWLast,
        input  MWValid,
        output MWReady,
        input  MBReady,
        output MBResp,
        output MBValid,
        input  MARAddr,
        input  MARLen,
        input  MARSize,
        input  MARBurst,
        input  MARValid,
        output MARReady,
        input  MRReady,
        output MRRData,
        output MRRResp,
        output MRRLast,
        output MRRValid
    );

endinterface
