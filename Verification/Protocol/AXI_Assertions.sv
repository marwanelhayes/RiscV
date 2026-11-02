import shared_pkg::*;

module AXI_Assertions #(
    parameter int  DATA_WIDTH   = 32,
    parameter int  ADDR_WIDTH   = 32,
    parameter int  AXI_SIZE     = 4,
    parameter bit  ALLOW_EXCLUSIVE_RESP = 1'b0,
    parameter bit  REQUIRE_NONZERO_WSTRB = 1'b0
)
(
    input   logic                  clk,
    input   logic                  rst,

    // ── AXI4 master interface: write address channel ─────────────────────────
    input   logic [ADDR_WIDTH-1:0] MAWAddr,
    input   logic [7:0]            MAWLen,
    input   logic [AXI_SIZE-1:0]   MAWSize,
    input   axi_burst_t            MAWBurst,
    input   logic                  MAWValid,
    input   logic                  MAWReady,

    // ── AXI4 master interface: write data channel ────────────────────────────
    input   logic [DATA_WIDTH-1:0] MWData,
    input   logic [(DATA_WIDTH/8)-1:0] MWStrb,
    input   logic                  MWLast,
    input   logic                  MWValid,
    input   logic                  MWReady,

    // ── AXI4 master interface: write response channel ────────────────────────
    input   logic                  MBReady,
    input   axi_resp_t             MBResp,
    input   logic                  MBValid,

    // ── AXI4 master interface: read address channel ──────────────────────────
    input   logic [ADDR_WIDTH-1:0] MARAddr,
    input   logic [7:0]            MARLen,
    input   logic [AXI_SIZE-1:0]   MARSize,
    input   axi_burst_t            MARBurst,
    input   logic                  MARValid,
    input   logic                  MARReady,

    // ── AXI4 master interface: read data channel ─────────────────────────────
    input   logic                  MRReady,
    input   logic [DATA_WIDTH-1:0] MRRData,
    input   axi_resp_t             MRRResp,
    input   logic                  MRRLast,
    input   logic                  MRRValid
);

    localparam int DATA_BYTES = DATA_WIDTH / 8;
    localparam int MAX_SIZE   = (DATA_BYTES > 1) ? $clog2(DATA_BYTES) : 0;

    logic [8:0] wr_beats_expected;
    logic [8:0] wr_beats_seen;
    logic       wr_addr_seen;
    logic       wr_data_done;

    logic [8:0] rd_beats_expected;
    logic [8:0] rd_beats_seen;
    logic       rd_data_active;

    function automatic bit valid_size(input logic [AXI_SIZE-1:0] size);
        valid_size = (!$isunknown(size)) && (int'(size) <= MAX_SIZE);
    endfunction

    function automatic bit valid_burst(input axi_burst_t burst);
        valid_burst = (burst == FIXED) || (burst == INCR) || (burst == WRAP);
    endfunction

    function automatic bit valid_resp(input axi_resp_t resp);
        valid_resp = (resp == AXI_OKAY) ||
                     (resp == AXI_SLVERR) ||
                     (resp == AXI_DECERR) ||
                     (ALLOW_EXCLUSIVE_RESP && (resp == AXI_EXOKAY));
    endfunction

    function automatic bit valid_wrap_len(input logic [7:0] len);
        valid_wrap_len = (len == 8'd1) ||
                         (len == 8'd3) ||
                         (len == 8'd7) ||
                         (len == 8'd15);
    endfunction

    function automatic bit does_not_cross_4kb(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [7:0]            len,
        input logic [AXI_SIZE-1:0]   size,
        input axi_burst_t            burst
    );
        longint unsigned bytes;
        longint unsigned beats;
        longint unsigned first_addr;
        longint unsigned container_low;
        longint unsigned container_size;

        if($isunknown({addr, len, size, burst}))
            return 1'b0;

        bytes      = 64'd1 << int'(size);
        beats      = int'(len) + 1;
        first_addr = addr;
        case(burst)
            FIXED: begin
                container_low  = (first_addr / bytes) * bytes;
                container_size = bytes;
            end
            INCR: begin
                container_low  = (first_addr / bytes) * bytes;
                container_size = bytes * beats;
            end
            WRAP: begin
                container_size = bytes * beats;
                container_low  = (first_addr / container_size) * container_size;
            end
            default: return 1'b0;
        endcase
        does_not_cross_4kb = (container_low / 4096) ==
                             ((container_low + container_size - 1) / 4096);
    endfunction

    function automatic bit aligned_to_transfer(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [AXI_SIZE-1:0]   size
    );
        int unsigned bytes;
        bytes = 1 << int'(size);
        aligned_to_transfer = (int'(addr) % bytes) == 0;
    endfunction

    // ── Channel valid/ready handshake rules ──────────────────────────────────
    property p_aw_payload_stable;
        @(posedge clk) disable iff (!rst)
        (MAWValid && !MAWReady) |=> MAWValid &&
            $stable({MAWAddr, MAWLen, MAWSize, MAWBurst});
    endproperty

    property p_w_payload_stable;
        @(posedge clk) disable iff (!rst)
        (MWValid && !MWReady) |=> MWValid &&
            $stable({MWData, MWStrb, MWLast});
    endproperty

    property p_b_payload_stable;
        @(posedge clk) disable iff (!rst)
        (MBValid && !MBReady) |=> MBValid && $stable(MBResp);
    endproperty

    property p_ar_payload_stable;
        @(posedge clk) disable iff (!rst)
        (MARValid && !MARReady) |=> MARValid &&
            $stable({MARAddr, MARLen, MARSize, MARBurst});
    endproperty

    property p_r_payload_stable;
        @(posedge clk) disable iff (!rst)
        (MRRValid && !MRReady) |=> MRRValid &&
            $stable({MRRData, MRRResp, MRRLast});
    endproperty

    a_aw_payload_stable: assert property (p_aw_payload_stable)
        else $error("AXI AW payload changed before AWREADY");
    a_aw_payload_stable_cover: cover property (p_aw_payload_stable);

    a_w_payload_stable: assert property (p_w_payload_stable)
        else $error("AXI W payload changed before WREADY");
    a_w_payload_stable_cover: cover property (p_w_payload_stable);

    a_b_payload_stable: assert property (p_b_payload_stable)
        else $error("AXI B payload changed before BREADY");
    a_b_payload_stable_cover: cover property (p_b_payload_stable);

    a_ar_payload_stable: assert property (p_ar_payload_stable)
        else $error("AXI AR payload changed before ARREADY");
    a_ar_payload_stable_cover: cover property (p_ar_payload_stable);

    a_r_payload_stable: assert property (p_r_payload_stable)
        else $error("AXI R payload changed before RREADY");
    a_r_payload_stable_cover: cover property (p_r_payload_stable);

    // ── Known, legal channel values when VALID is asserted ───────────────────
    a_aw_known: assert property (@(posedge clk) disable iff (!rst)
        MAWValid |-> !$isunknown({MAWAddr, MAWLen, MAWSize, MAWBurst}))
        else $error("AXI AW channel contains X/Z while AWVALID is high");
    a_aw_known_cover: cover property (@(posedge clk) disable iff (!rst)
        MAWValid |-> !$isunknown({MAWAddr, MAWLen, MAWSize, MAWBurst}));

    a_w_known: assert property (@(posedge clk) disable iff (!rst)
        MWValid |-> !$isunknown({MWData, MWStrb, MWLast}))
        else $error("AXI W channel contains X/Z while WVALID is high");
    a_w_known_cover: cover property (@(posedge clk) disable iff (!rst)
        MWValid |-> !$isunknown({MWData, MWStrb, MWLast}));

    a_b_known: assert property (@(posedge clk) disable iff (!rst)
        MBValid |-> !$isunknown(MBResp))
        else $error("AXI B channel contains X/Z while BVALID is high");
    a_b_known_cover: cover property (@(posedge clk) disable iff (!rst)
        MBValid |-> !$isunknown(MBResp));

    a_ar_known: assert property (@(posedge clk) disable iff (!rst)
        MARValid |-> !$isunknown({MARAddr, MARLen, MARSize, MARBurst}))
        else $error("AXI AR channel contains X/Z while ARVALID is high");
    a_ar_known_cover: cover property (@(posedge clk) disable iff (!rst)
        MARValid |-> !$isunknown({MARAddr, MARLen, MARSize, MARBurst}));

    a_r_known: assert property (@(posedge clk) disable iff (!rst)
        MRRValid |-> !$isunknown({MRRData, MRRResp, MRRLast}))
        else $error("AXI R channel contains X/Z while RVALID is high");
    a_r_known_cover: cover property (@(posedge clk) disable iff (!rst)
        MRRValid |-> !$isunknown({MRRData, MRRResp, MRRLast}));

    a_ready_known: assert property (@(posedge clk) disable iff (!rst)
        !$isunknown({MAWReady, MWReady, MBReady, MARReady, MRReady}))
        else $error("AXI READY signal contains X/Z");
    a_ready_known_cover: cover property (@(posedge clk) disable iff (!rst)
        !$isunknown({MAWReady, MWReady, MBReady, MARReady, MRReady}));

    a_aw_legal: assert property (@(posedge clk) disable iff (!rst)
        MAWValid |-> valid_size(MAWSize) &&
                     valid_burst(MAWBurst) &&
                     does_not_cross_4kb(MAWAddr, MAWLen, MAWSize, MAWBurst) &&
                     ((MAWBurst != FIXED) || (MAWLen <= 8'd15)) &&
                     ((MAWBurst != WRAP) ||
                        (valid_wrap_len(MAWLen) &&
                         aligned_to_transfer(MAWAddr, MAWSize))))
        else $error("AXI AW channel has illegal size, burst, length, alignment, or 4KB crossing");
    a_aw_legal_cover: cover property (@(posedge clk) disable iff (!rst)
        MAWValid |-> valid_size(MAWSize) &&
                     valid_burst(MAWBurst) &&
                     does_not_cross_4kb(MAWAddr, MAWLen, MAWSize, MAWBurst) &&
                     ((MAWBurst != FIXED) || (MAWLen <= 8'd15)) &&
                     ((MAWBurst != WRAP) ||
                        (valid_wrap_len(MAWLen) &&
                         aligned_to_transfer(MAWAddr, MAWSize))));

    a_ar_legal: assert property (@(posedge clk) disable iff (!rst)
        MARValid |-> valid_size(MARSize) &&
                     valid_burst(MARBurst) &&
                     does_not_cross_4kb(MARAddr, MARLen, MARSize, MARBurst) &&
                     ((MARBurst != FIXED) || (MARLen <= 8'd15)) &&
                     ((MARBurst != WRAP) ||
                        (valid_wrap_len(MARLen) &&
                         aligned_to_transfer(MARAddr, MARSize))))
        else $error("AXI AR channel has illegal size, burst, length, alignment, or 4KB crossing");
    a_ar_legal_cover: cover property (@(posedge clk) disable iff (!rst)
        MARValid |-> valid_size(MARSize) &&
                     valid_burst(MARBurst) &&
                     does_not_cross_4kb(MARAddr, MARLen, MARSize, MARBurst) &&
                     ((MARBurst != FIXED) || (MARLen <= 8'd15)) &&
                     ((MARBurst != WRAP) ||
                        (valid_wrap_len(MARLen) &&
                         aligned_to_transfer(MARAddr, MARSize))));

    a_b_resp_legal: assert property (@(posedge clk) disable iff (!rst)
        MBValid |-> valid_resp(MBResp))
        else $error("AXI B channel has an illegal response encoding");
    a_b_resp_legal_cover: cover property (@(posedge clk) disable iff (!rst)
        MBValid |-> valid_resp(MBResp));

    a_r_resp_legal: assert property (@(posedge clk) disable iff (!rst)
        MRRValid |-> valid_resp(MRRResp))
        else $error("AXI R channel has an illegal response encoding");
    a_r_resp_legal_cover: cover property (@(posedge clk) disable iff (!rst)
        MRRValid |-> valid_resp(MRRResp));

    a_b_after_write: assert property (@(posedge clk) disable iff (!rst)
        MBValid |-> wr_addr_seen && wr_data_done)
        else $error("AXI BVALID asserted before both AW and the complete W burst were accepted");

    a_r_after_ar: assert property (@(posedge clk) disable iff (!rst)
        MRRValid |-> rd_data_active)
        else $error("AXI RVALID asserted before an AR transaction was accepted");

    // ── Single-ID, single-outstanding ordering and burst beat accounting ─────
    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            wr_beats_expected <= '0;
            wr_beats_seen     <= '0;
            wr_addr_seen      <= 1'b0;
            wr_data_done      <= 1'b0;
            rd_beats_expected <= '0;
            rd_beats_seen     <= '0;
            rd_data_active    <= 1'b0;
        end
        else
        begin
            // AXI permits AW and W in either order. A completed B handshake
            // frees this single-outstanding slot for same-cycle reuse.
            if (MBValid && MBReady)
            begin
                wr_beats_expected <= '0;
                wr_beats_seen     <= '0;
                wr_addr_seen      <= 1'b0;
                wr_data_done      <= 1'b0;
            end

            if (MAWValid && MAWReady)
            begin
                assert (!wr_addr_seen || (MBValid && MBReady))
                    else $error("AXI AW handshake occurred while a write transaction is still outstanding");
                wr_beats_expected <= {1'b0, MAWLen} + 9'd1;
                wr_addr_seen      <= 1'b1;
                if (!(MBValid && MBReady))
                begin
                    assert (wr_beats_seen <= ({1'b0, MAWLen} + 9'd1))
                        else $error("AXI W beats accepted before AW exceed AWLEN");
                    assert (wr_data_done ==
                            (wr_beats_seen == ({1'b0, MAWLen} + 9'd1)))
                        else $error("AXI WLAST accepted before AW does not match AWLEN");
                end
            end

            if (MWValid && MWReady)
            begin
                assert (!wr_data_done || (MBValid && MBReady))
                    else $error("AXI W beat accepted after WLAST and before the prior B response");
                assert (!REQUIRE_NONZERO_WSTRB || (MWStrb != '0))
                    else $error("AXI W beat accepted with all write strobes low");
                if ((MAWValid && MAWReady) || (wr_addr_seen && !(MBValid && MBReady)))
                begin
                    assert (((MBValid && MBReady) ? 9'd0 : wr_beats_seen) <
                            ((MAWValid && MAWReady) ? ({1'b0, MAWLen} + 9'd1) : wr_beats_expected))
                        else $error("AXI W burst contains more beats than AWLEN");
                    assert (MWLast ==
                            ((((MBValid && MBReady) ? 9'd0 : wr_beats_seen) + 9'd1) ==
                             ((MAWValid && MAWReady) ? ({1'b0, MAWLen} + 9'd1) : wr_beats_expected)))
                        else $error("AXI WLAST does not match AWLEN beat count");
                end
                wr_beats_seen <= ((MBValid && MBReady) ? 9'd0 : wr_beats_seen) + 9'd1;
                wr_data_done  <= MWLast;
            end

            if (MRRValid && MRReady)
            begin
                assert (rd_data_active)
                    else $error("AXI R beat accepted without an outstanding AR transaction");
                assert (MRRLast == (rd_beats_seen == (rd_beats_expected - 9'd1)))
                    else $error("AXI RLAST does not match ARLEN beat count");

                if (rd_data_active)
                begin
                    if (MRRLast)
                    begin
                        rd_beats_expected <= '0;
                        rd_beats_seen     <= '0;
                        rd_data_active    <= 1'b0;
                    end
                    else
                        rd_beats_seen <= rd_beats_seen + 9'd1;
                end
            end

            if (MARValid && MARReady)
            begin
                assert (!rd_data_active || (MRRValid && MRReady && MRRLast))
                    else $error("AXI AR handshake occurred while a read transaction is still outstanding");
                rd_beats_expected <= {1'b0, MARLen} + 9'd1;
                rd_beats_seen     <= '0;
                rd_data_active    <= 1'b1;
            end
        end
    end

endmodule
