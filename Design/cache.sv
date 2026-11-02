// =============================================================================
// cache.sv
// -----------------------------------------------------------------------------
// Parameterized cache with configurable WAY.
//
// WAY model:
//   - WAY = 1                 -> direct-mapped cache
//   - 1 < WAY < TOTAL_LINES           -> set-associative cache
//   - WAY = TOTAL_LINES               -> fully associative cache
//
// Geometry defaults:
//   TOTAL_LINES       = 32
//   WAY        = 1
//   SETS        = TOTAL_LINES         / WAY
//   LINE_WORDS  = 4
//   DATA_WIDTH  = 32
//   Line size   = 4 words x 4 bytes = 16 bytes
//   Capacity    = TOTAL_LINES   x LINE_WORDS x DATA_WIDTH/8
//               = 32 x 4 x 4 = 512 bytes by default
//
// Data cache policy: write-back, write-allocate
//   - Read hit:    return word immediately
//   - Read-through: the cycle after the missed word arrives during a refill,
//                  CacheHit is raised for exactly one cycle with that word (the
//                  refill may still be running); any later cycle looks the line
//                  up normally once the refill is complete
//   - Read miss:   if the victim line is dirty, AXI burst write-back first;
//                  then AXI burst read to fill the victim way
//   - Write hit:   merge the enabled store bytes into the cached word and
//                  mark the line dirty (no AXI traffic)
//   - Write miss:  same refill as a read miss, then merge the enabled store
//                  bytes into the filled line and mark it dirty
//
// Replacement policy for WAY > 1:
//   - invalid way first
//   - otherwise the true least recently used way of the set: each set keeps
//     an age rank per way (0 = most recent, WAY-1 = least recent), updated
//     on every hit and on every completed refill
//
// I-cache: set READ_ONLY=1 to ignore/synthesize away write behavior.
// =============================================================================

import shared_pkg::*;

module cache
#(
    parameter int  DATA_WIDTH   = 32,
    parameter int  ADDR_WIDTH   = 32,
    parameter int  TOTAL_LINES  = 32,                         // total cache lines, power of 2 recommended. This represents the cache capacity for lines of words. Multiply this value by LINE_WORDS to get the number of words stored in cache
    parameter int  WAY          = 1,                          // 1=direct, TOTAL_LINES =fully WAY
    parameter int  LINE_WORDS   = 4,                          // words per cache line, power of 2
    parameter bit  READ_ONLY    = 1'b0,                       // 1 for I-cache
    parameter int  AXI_SIZE     = 4
)
(
    input  logic                  clk,
    input  logic                  rst,

    // ── CPU-side interface ────────────────────────────────────────────────────
    input  logic [ADDR_WIDTH-1:0] CPUAddr,
    input  logic [DATA_WIDTH-1:0] CPUWriteData,
    input  logic [(DATA_WIDTH/8)-1:0] CPUByteEn,  // Bytes written by a store
    input  logic                  CPUWriteEn,
    input  logic                  CPUReadEn,
    output logic [DATA_WIDTH-1:0] CPUReadData,
    output logic                  CacheHit,     // 0 = pipeline must stall

    // ── AXI4 master interface: write address channel ─────────────────────────
    output logic [ADDR_WIDTH-1:0] MAWAddr,
    output logic [7:0]            MAWLen,
    output logic [AXI_SIZE-1:0]   MAWSize,
    output axi_burst_t            MAWBurst,
    output logic                  MAWValid,
    input  logic                  MAWReady,

    // ── AXI4 master interface: write data channel ────────────────────────────
    output logic [DATA_WIDTH-1:0] MWData,
    output logic [(DATA_WIDTH/8)-1:0] MWStrb,
    output logic                  MWLast,
    output logic                  MWValid,
    input  logic                  MWReady,

    // ── AXI4 master interface: write response channel ────────────────────────
    output logic                  MBReady,
    input  axi_resp_t             MBResp,
    input  logic                  MBValid,

    // ── AXI4 master interface: read address channel ──────────────────────────
    output logic [ADDR_WIDTH-1:0] MARAddr,
    output logic [7:0]            MARLen,
    output logic [AXI_SIZE-1:0]   MARSize,
    output axi_burst_t            MARBurst,
    output logic                  MARValid,
    input  logic                  MARReady,

    // ── AXI4 master interface: read data channel ─────────────────────────────
    output logic                  MRReady,
    input  logic [DATA_WIDTH-1:0] MRRData,
    input  axi_resp_t             MRRResp,
    input  logic                  MRRLast,
    input  logic                  MRRValid
);


    localparam int DATA_BYTES  = DATA_WIDTH / 8;
    localparam int SETS        = TOTAL_LINES / WAY;
    localparam int LINE_BYTES  = LINE_WORDS * DATA_BYTES;
    localparam int TRANSFER_SIZE = $clog2(DATA_BYTES); // AXI size encoding (0=1B, 1=2B, 2=4B, ...)

    localparam int BYTE_OFF_W  = (DATA_BYTES  > 1)  ? $clog2(DATA_BYTES)  : 0;
    localparam int OFF_W       = (LINE_BYTES  > 1)  ? $clog2(LINE_BYTES)  : 0;
    localparam int IDX_W_RAW   = (SETS        > 1)  ? $clog2(SETS)        : 0;
    localparam int IDX_W       = (IDX_W_RAW   > 0)  ? IDX_W_RAW           : 1;
    localparam int WAY_W       = (WAY         > 1)  ? $clog2(WAY)         : 1;
    localparam int WORD_W_RAW  = (LINE_WORDS  > 1)  ? $clog2(LINE_WORDS)  : 0;
    localparam int WORD_W      = (WORD_W_RAW  > 0)  ? WORD_W_RAW          : 1;
    localparam int TAG_W       = ADDR_WIDTH - OFF_W - IDX_W_RAW;

    // The cache must be smaller than the address space it caches
    // (elaboration-time check).
    generate
        if(TAG_W < 1)
        begin:gen_bad_geometry
            $error("cache: ADDR_WIDTH leaves no tag bits for this line size and set count");
        end:gen_bad_geometry
    endgenerate

    logic valid_reg [SETS][WAY];  // valid bits
    logic valid [SETS][WAY];
    logic [TAG_W-1:0] tags_reg [SETS][WAY];  // tags
    logic [TAG_W-1:0] tags [SETS][WAY];
    logic [DATA_WIDTH-1:0] data_reg [SETS][WAY][LINE_WORDS];  // Data arrays
    logic [DATA_WIDTH-1:0] data [SETS][WAY][LINE_WORDS];
    logic [WORD_W-1:0] counter_reg; // for tracking burst progress
    logic [WORD_W-1:0] counter;
    logic [WAY_W-1:0] lru_way_empty_reg [SETS]; // for replacement logic
    logic [WAY_W-1:0] lru_way_empty [SETS];
    logic pending_write;
    logic [DATA_WIDTH-1:0] pending_write_data;
    logic [(DATA_WIDTH/8)-1:0] pending_write_be;
    logic [ADDR_WIDTH-1:0] miss_line_addr;
    logic [WAY_W-1:0] hit_way;
    logic [WAY_W-1:0] victim_way;
    logic [WAY_W-1:0] victim_way_reg;
    logic [WAY-1:0] hit_array;

    logic [IDX_W-1:0] CpuIdx;
    logic [TAG_W-1:0] CpuTag;
    logic [OFF_W-1:0] CpuOffset;


    logic [IDX_W-1:0] CpuIdx_reg;
    logic [TAG_W-1:0] CpuTag_reg;
    logic [OFF_W-1:0] CpuOffset_reg;

    logic read_through_hit_reg;
    logic read_through_hit;
    logic refill_error_reg;
    logic refill_error;

    logic [ADDR_WIDTH-1:0] MAWAddr_next;
    logic [7:0]            MAWLen_next;
    logic [2:0]            MAWSize_next;
    axi_burst_t            MAWBurst_next;
    logic                  MAWValid_next;
    logic [DATA_WIDTH-1:0] MWData_next;
    logic [(DATA_WIDTH/8)-1:0] MWStrb_next;
    logic                  MWLast_next;
    logic                  MWValid_next;

    logic                  MBReady_next;
    logic [ADDR_WIDTH-1:0] MARAddr_next;
    logic [7:0]            MARLen_next;
    logic [2:0]            MARSize_next;
    axi_burst_t            MARBurst_next;
    logic                  MARValid_next;

    logic [WAY_W-1:0] lru_way [SETS];

    logic and_valid_bits;


    axi_state_t state, next_state;

    // Byte-wise merge of a store into a cached word
    function automatic logic [DATA_WIDTH-1:0] MergeBytes(
        input logic [DATA_WIDTH-1:0]     OldWord,
        input logic [DATA_WIDTH-1:0]     NewWord,
        input logic [(DATA_WIDTH/8)-1:0] ByteEn
    );
        MergeBytes = OldWord;
        for(int b = 0; b < DATA_WIDTH/8; b++)
            if(ByteEn[b])
                MergeBytes[8*b +: 8] = NewWord[8*b +: 8];
    endfunction:MergeBytes

    always_comb
    begin
        CpuOffset = CPUAddr[OFF_W-1:0];
        if(WAY == TOTAL_LINES)
        begin
            CpuIdx = '0;
            CpuTag = CPUAddr[ADDR_WIDTH-1:OFF_W];
        end
        else
        begin
            CpuIdx = CPUAddr[OFF_W+IDX_W-1:OFF_W];
            CpuTag = CPUAddr[ADDR_WIDTH-1:OFF_W+IDX_W];
        end
    end


    always_comb
    begin
        hit_array = '0;
        hit_way = '0;
        victim_way = lru_way[CpuIdx];

        for(int i = 0; i < WAY; i++)
        begin
            if(valid_reg[CpuIdx][i] && (tags_reg[CpuIdx][i] == CpuTag))
            begin
                hit_array[i] = 1'b1;
                hit_way = WAY_W'(i);
            end
        end

        for(int i = WAY - 1; i >= 0; i--)
        begin
            if(!valid_reg[CpuIdx][i])
            begin
                victim_way = WAY_W'(i);
            end
        end
    end

    always_comb
    begin
        and_valid_bits = 1'b1;
        for(int i = 0; i < WAY; i++)
        begin
            and_valid_bits &= valid_reg[CpuIdx_reg][i];
        end
    end

    generate
        if(WAY == 1)
        begin : gen_direct_mapped
            always_comb
            begin
                if(CPUReadEn || CPUWriteEn)
                begin
                    if((|hit_array) && (state == AXI_IDLE))
                    begin
                        CacheHit = 1'b1;
                    end
                    else if(read_through_hit_reg)
                    begin
                        CacheHit = 1'b1;
                    end
                    else
                    begin
                        CacheHit = 1'b0;
                    end
                end
                else
                begin
                    CacheHit = 1'b1;
                end
            end

            always_comb
            begin
                if(read_through_hit_reg)
                begin
                    CPUReadData = data_reg[CpuIdx_reg][0][CpuOffset_reg[OFF_W-1 : BYTE_OFF_W]];
                end
                else if(CPUWriteEn && CacheHit)
                begin
                    CPUReadData = CPUWriteData;
                end
                else if(CacheHit)
                begin
                    CPUReadData = data_reg[CpuIdx][0][CpuOffset[OFF_W-1 : BYTE_OFF_W]];
                end
                else
                begin
                    CPUReadData = '0;
                end
            end
        end:gen_direct_mapped
        else
        begin:gen_set_associative
            always_comb
            begin
                if(CPUReadEn || CPUWriteEn)
                begin
                    if(|hit_array && (state == AXI_IDLE))
                    begin
                        CacheHit = 1'b1;
                    end
                    else if(read_through_hit_reg)
                    begin
                        CacheHit = 1'b1;
                    end
                    else
                    begin
                        CacheHit = 1'b0;
                    end
                end
                else
                begin
                    CacheHit = 1'b1;
                end
            end

            always_comb
            begin
                CPUReadData = '0;
                for(int i = 0; i < WAY; i++)
                begin
                    if(hit_array[i] && CacheHit)
                    begin
                        if(CPUWriteEn)
                        begin
                            CPUReadData = CPUWriteData;
                        end
                        else
                        begin
                            CPUReadData = data_reg[CpuIdx][i][CpuOffset[OFF_W-1 : BYTE_OFF_W]];
                        end
                    end
                    else if(read_through_hit_reg)
                    begin
                        CPUReadData = data_reg[CpuIdx_reg][victim_way_reg][CpuOffset_reg[OFF_W-1 : BYTE_OFF_W]];
                    end
                end
            end

            // True LRU: per-set age ranks, kept as a permutation of
            // 0..WAY-1 (0 = most recently used). A way is "used" by a hit on an
            // idle access or by a successful refill into it.
            logic [WAY_W-1:0] lru_age [SETS][WAY];
            logic             lru_touch;
            logic [IDX_W-1:0] lru_touch_idx;
            logic [WAY_W-1:0] lru_touch_way;

            always_comb
            begin
                lru_touch = 1'b0;
                lru_touch_idx = CpuIdx;
                lru_touch_way = hit_way;
                if((state == AXI_RD_DATA) && MRRValid && MRReady && MRRLast &&
                   (MRRResp == AXI_OKAY) && !refill_error_reg)
                begin
                    lru_touch = 1'b1;
                    lru_touch_idx = CpuIdx_reg;
                    lru_touch_way = victim_way_reg;
                end
                else if((CPUReadEn || CPUWriteEn) && (|hit_array) && (state == AXI_IDLE))
                begin
                    lru_touch = 1'b1;
                end
            end

            always_ff @(posedge clk or negedge rst)
            begin
                if(!rst)
                begin
                    foreach (lru_age[i, j]) lru_age[i][j] <= WAY_W'(j);
                end
                else if(lru_touch)
                begin
                    for(int j = 0; j < WAY; j++)
                    begin
                        if(WAY_W'(j) == lru_touch_way)
                            lru_age[lru_touch_idx][j] <= '0;
                        else if(lru_age[lru_touch_idx][j] < lru_age[lru_touch_idx][lru_touch_way])
                            lru_age[lru_touch_idx][j] <= lru_age[lru_touch_idx][j] + 1'b1;
                    end
                end
            end

            // LRU way of each set = the way with the oldest age rank.
            always_comb
            begin
                foreach (lru_way[i])
                begin
                    lru_way[i] = '0;
                    for(int j = 0; j < WAY; j++)
                        if(lru_age[i][j] == WAY_W'(WAY-1))
                            lru_way[i] = WAY_W'(j);
                end
            end
        end:gen_set_associative
    endgenerate

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            CpuIdx_reg <= '0;
            CpuTag_reg <= '0;
            CpuOffset_reg <= '0;
            pending_write <= 1'b0;
            pending_write_data <= '0;
            pending_write_be <= '0;
            miss_line_addr <= '0;
            victim_way_reg <= '0;
        end
        else
        begin
            if((state == AXI_IDLE) && (CPUReadEn || CPUWriteEn) && !CacheHit)
            begin
                CpuOffset_reg <= CpuOffset;
                pending_write <= CPUWriteEn;
                pending_write_data <= CPUWriteData;
                pending_write_be <= CPUByteEn;
                miss_line_addr <= {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                victim_way_reg <= victim_way;
                if(WAY == TOTAL_LINES)
                begin
                    CpuIdx_reg <= '0;
                    CpuTag_reg <= CpuTag;
                end
                else
                begin
                    CpuIdx_reg <= CpuIdx;
                    CpuTag_reg <= CpuTag;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            state <= AXI_IDLE;
            foreach (valid_reg[i, j]) valid_reg[i][j] <= 1'b0;
            foreach (tags_reg[i, j]) tags_reg[i][j] <= '0;
            foreach (data_reg[i, j, k]) data_reg[i][j][k] <= '0;
            foreach (lru_way_empty_reg[i]) lru_way_empty_reg[i] <= '0;
        end
        else
        begin
            state <= next_state;
            foreach (valid_reg[i, j]) valid_reg[i][j] <= valid[i][j];
            foreach (tags_reg[i, j]) tags_reg[i][j] <= tags[i][j];
            foreach (data_reg[i, j, k]) data_reg[i][j][k] <= data[i][j][k];
            foreach (lru_way_empty_reg[i]) lru_way_empty_reg[i] <= lru_way_empty[i];
        end
    end

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            MAWAddr <= '0;
            MAWLen <= '0;
            MAWSize <= '0;
            MAWBurst <= FIXED;
            MAWValid <= 1'b0;
            MWData <= '0;
            MWStrb <= '0;
            MWLast <= 1'b0;
            MWValid <= 1'b0;
            MBReady <= 1'b0;
            MARAddr <= '0;
            MARLen <= '0;
            MARSize <= '0;
            MARBurst <= FIXED;
            MARValid <= 1'b0;
            MRReady <= 1'b0;
            counter_reg <= '0;
            read_through_hit_reg <= 1'b0;
            refill_error_reg <= 1'b0;
        end
        else
        begin
            MAWAddr <= MAWAddr_next;
            MAWLen <= MAWLen_next;
            MAWSize <= MAWSize_next;
            MAWBurst <= MAWBurst_next;
            MAWValid <= MAWValid_next;
            MWData <= MWData_next;
            MWStrb <= MWStrb_next;
            MWLast <= MWLast_next;
            MWValid <= MWValid_next;
            MBReady <= MBReady_next;
            MARAddr <= MARAddr_next;
            MARLen <= MARLen_next;
            MARSize <= MARSize_next;
            MARBurst <= MARBurst_next;
            MARValid <= MARValid_next;
            MRReady <= 1'b1;
            counter_reg <= counter;
            read_through_hit_reg <= read_through_hit;
            refill_error_reg <= refill_error;
        end
    end

    generate
        if(READ_ONLY)
        begin:gen_read_only_cache
            always_comb
            begin
                next_state = state;
                valid = valid_reg;
                tags = tags_reg;
                data = data_reg;
                MAWAddr_next = MAWAddr;
                MAWLen_next = MAWLen;
                MAWSize_next = MAWSize;
                MAWBurst_next = MAWBurst;
                MAWValid_next = MAWValid;
                MWData_next = MWData;
                MWStrb_next = MWStrb;
                MWLast_next = MWLast;
                MWValid_next = MWValid;
                MBReady_next = MBReady;
                MARAddr_next = MARAddr;
                MARLen_next = MARLen;
                MARSize_next = MARSize;
                MARBurst_next = MARBurst;
                MARValid_next = MARValid;
                counter = counter_reg;
                lru_way_empty = lru_way_empty_reg;
                read_through_hit = 1'b0;          // one-cycle pulse: set only when the missed word arrives
                refill_error = refill_error_reg;

                case(state)
                    AXI_IDLE:
                    begin
                        if(CPUReadEn && !CacheHit)
                        begin
                            next_state = AXI_RD_ADDR;
                            MARValid_next = 1'b1;
                            MARAddr_next = {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                            MARLen_next = LINE_WORDS - 1;
                            MARSize_next = TRANSFER_SIZE;
                            MARBurst_next = INCR;
                            counter = '0;
                            read_through_hit = 1'b0;
                            refill_error = 1'b0;
                            MAWAddr_next = 'b0;
                            MAWLen_next = 'b0;
                            MAWSize_next = 'b0;
                            MAWBurst_next = FIXED;
                            MAWValid_next = 'b0;
                            MWData_next = 'b0;
                            MWStrb_next = 'b0;
                            MWLast_next = 'b0;
                            MWValid_next = 'b0;
                            MBReady_next = 'b0;
                        end
                        else
                        begin
                            next_state = AXI_IDLE;
                            MAWValid_next = 1'b0;
                            MARAddr_next = '0;
                            MARValid_next = 1'b0;
                            MARLen_next = '0;
                            MARSize_next = '0;
                            MARBurst_next = INCR;
                            counter = '0;
                            read_through_hit = 1'b0;
                            refill_error = 1'b0;
                            MAWAddr_next = 'b0;
                            MAWLen_next = 'b0;
                            MAWSize_next = 'b0;
                            MAWBurst_next = FIXED;
                            MAWValid_next = 'b0;
                            MWData_next = 'b0;
                            MWStrb_next = 'b0;
                            MWLast_next = 'b0;
                            MWValid_next = 'b0;
                            MBReady_next = 'b0;
                        end
                    end
                    AXI_RD_ADDR:
                    begin
                        if(MARReady && MARValid)
                        begin
                            next_state = AXI_RD_DATA;
                            MARValid_next = 1'b0;
                            MAWValid_next = 1'b0;
                            MARAddr_next = '0;
                            MARValid_next = 1'b0;
                            MARLen_next = '0;
                            MARSize_next = '0;
                            MARBurst_next = INCR;
                            counter = '0;
                            read_through_hit = 1'b0;
                        end
                    end

                    AXI_RD_DATA:
                    begin
                        if(WAY == 1)
                        begin:direct_mapped_read
                            if(MRRValid && MRReady)
                            begin
                                if(MRRResp == AXI_OKAY)
                                begin
                                    data[CpuIdx_reg][0][counter] = MRRData;
                                end
                                else
                                begin
                                    refill_error = 1'b1;
                                end
                                if((MRRResp == AXI_OKAY) && (counter == (CpuOffset_reg[OFF_W-1:BYTE_OFF_W])))
                                begin
                                    read_through_hit = 1'b1;
                                end
                                else
                                begin
                                    read_through_hit = 1'b0;
                                end
                                counter = counter + 1'b1;
                                if(MRRLast)
                                begin
                                    if((MRRResp == AXI_OKAY) && !refill_error_reg)
                                    begin
                                        valid[CpuIdx_reg][0] = 1'b1;
                                        tags[CpuIdx_reg][0] = CpuTag_reg;
                                    end
                                    next_state = AXI_IDLE;
                                    counter = '0;
                                end
                            end
                        end:direct_mapped_read
                        else
                        begin:set_associative_read
                            if(MRRValid && MRReady)
                            begin
                                if(MRRResp == AXI_OKAY)
                                begin
                                    data[CpuIdx_reg][victim_way_reg][counter] = MRRData;
                                end
                                else
                                begin
                                    refill_error = 1'b1;
                                end
                                if((MRRResp == AXI_OKAY) && (counter == (CpuOffset_reg[OFF_W-1:BYTE_OFF_W])))
                                begin
                                    read_through_hit = 1'b1;
                                end
                                else
                                begin
                                    read_through_hit = 1'b0;
                                end
                                counter = counter + 1'b1;

                                if(MRRLast)
                                begin
                                    if((MRRResp == AXI_OKAY) && !refill_error_reg)
                                    begin
                                        valid[CpuIdx_reg][victim_way_reg] = 1'b1;
                                        tags[CpuIdx_reg][victim_way_reg] = CpuTag_reg;
                                    end
                                    next_state = AXI_IDLE;
                                    MAWValid_next = 1'b0;
                                    MARAddr_next = '0;
                                    MARValid_next = 1'b0;
                                    MARLen_next = '0;
                                    MARSize_next = '0;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    if(!and_valid_bits)
                                    begin
                                        lru_way_empty[CpuIdx_reg] = lru_way_empty[CpuIdx_reg] + 1'b1;
                                    end
                                end
                            end
                        end:set_associative_read
                    end
                endcase
            end
        end:gen_read_only_cache

        else
        begin:gen_read_write_cache

            logic dirty_reg [SETS][WAY];
            logic dirty [SETS][WAY];

            always_ff @(posedge clk or negedge rst)
            begin
                if(!rst)
                begin
                    foreach (dirty_reg[i, j]) dirty_reg[i][j] <= 1'b0;
                end
                else
                begin
                    foreach (dirty_reg[i, j]) dirty_reg[i][j] <= dirty[i][j];
                end
            end

            always_comb
            begin
                next_state = state;
                valid = valid_reg;
                tags = tags_reg;
                data = data_reg;
                MAWAddr_next = MAWAddr;
                MAWLen_next = MAWLen;
                MAWSize_next = MAWSize;
                MAWBurst_next = MAWBurst;
                MAWValid_next = MAWValid;
                MWData_next = MWData;
                MWStrb_next = MWStrb;
                MWLast_next = MWLast;
                MWValid_next = MWValid;
                MBReady_next = MBReady;
                MARAddr_next = MARAddr;
                MARLen_next = MARLen;
                MARSize_next = MARSize;
                MARBurst_next = MARBurst;
                MARValid_next = MARValid;
                counter = counter_reg;
                lru_way_empty = lru_way_empty_reg;
                read_through_hit = 1'b0;          // one-cycle pulse: set only when the missed word arrives
                refill_error = refill_error_reg;
                dirty = dirty_reg;

                case(state)
                    AXI_IDLE:
                    begin
                        read_through_hit = 1'b0;
                        if(CPUReadEn && !CacheHit)
                        begin
                            if(WAY == 1)
                            begin:direct_mapped_read
                                if (valid_reg[CpuIdx][0] && dirty_reg[CpuIdx][0])
                                begin
                                    next_state = AXI_WR_ADDR;
                                    MAWValid_next = 1'b1;
                                    MAWAddr_next = {tags_reg[CpuIdx][0], CpuIdx, {OFF_W{1'b0}}};
                                    MAWLen_next = LINE_WORDS - 1;
                                    MAWSize_next = TRANSFER_SIZE;
                                    MAWBurst_next = INCR;
                                    counter = '0;
                                    MBReady_next = 1'b0;
                                    refill_error = 1'b0;
                                end
                                else
                                begin
                                    MARValid_next = 1'b1;
                                    MARAddr_next = {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                                    MARLen_next = LINE_WORDS - 1;
                                    MARSize_next = TRANSFER_SIZE;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    refill_error = 1'b0;
                                    next_state = AXI_RD_ADDR;

                                end
                            end:direct_mapped_read
                            else
                            begin:set_associative_read
                                if (valid_reg[CpuIdx][victim_way] && dirty_reg[CpuIdx][victim_way])
                                begin
                                    next_state = AXI_WR_ADDR;
                                    MAWValid_next = 1'b1;
                                    MAWAddr_next = (WAY == TOTAL_LINES)
                                                 ? {tags_reg[CpuIdx][victim_way], {OFF_W{1'b0}}}
                                                 : {tags_reg[CpuIdx][victim_way], CpuIdx, {OFF_W{1'b0}}};
                                    MAWLen_next = LINE_WORDS - 1;
                                    MAWSize_next = TRANSFER_SIZE;
                                    MAWBurst_next = INCR;
                                    counter = '0;
                                    MBReady_next = 1'b0;
                                    refill_error = 1'b0;
                                end
                                else
                                begin
                                    MARValid_next = 1'b1;
                                    MARAddr_next = {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                                    MARLen_next = LINE_WORDS - 1;
                                    MARSize_next = TRANSFER_SIZE;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    refill_error = 1'b0;
                                    next_state = AXI_RD_ADDR;
                                end
                            end:set_associative_read
                        end
                        else if(CPUWriteEn && CacheHit)
                        begin
                            next_state = AXI_IDLE;
                            MAWValid_next = 1'b0;
                            MARAddr_next = '0;
                            MARValid_next = 1'b0;
                            MARLen_next = '0;
                            MARSize_next = '0;
                            MARBurst_next = INCR;

                            MAWAddr_next = 'b0;
                            MAWLen_next = 'b0;
                            MAWSize_next = 'b0;
                            MAWBurst_next = FIXED;
                            MAWValid_next = 'b0;
                            MWData_next = 'b0;
                            MWStrb_next = 'b0;
                            MWLast_next = 'b0;
                            MWValid_next = 'b0;

                            counter = '0;
                            read_through_hit = 1'b0;
                            if(WAY == 1)
                            begin:direct_mapped_write
                                data[CpuIdx][0][CpuOffset[OFF_W-1:BYTE_OFF_W]] = MergeBytes(data_reg[CpuIdx][0][CpuOffset[OFF_W-1:BYTE_OFF_W]], CPUWriteData, CPUByteEn);
                                dirty[CpuIdx][0] = 1'b1;
                            end:direct_mapped_write
                            else                            
                            begin:set_associative_write
                                data[CpuIdx][hit_way][CpuOffset[OFF_W-1:BYTE_OFF_W]] = MergeBytes(data_reg[CpuIdx][hit_way][CpuOffset[OFF_W-1:BYTE_OFF_W]], CPUWriteData, CPUByteEn);
                                dirty[CpuIdx][hit_way] = 1'b1;
                            end:set_associative_write
                        end
                        else if(CPUWriteEn && !CacheHit)
                        begin
                            if(WAY == 1)
                            begin:direct_mapped_write_miss
                                if(valid_reg[CpuIdx][0] && dirty_reg[CpuIdx][0])
                                begin
                                    next_state = AXI_WR_ADDR;
                                    MAWValid_next = 1'b1;
                                    MAWAddr_next = {tags_reg[CpuIdx][0], CpuIdx, {OFF_W{1'b0}}};
                                    MAWLen_next = LINE_WORDS - 1;
                                    MAWSize_next = TRANSFER_SIZE;
                                    MAWBurst_next = INCR;
                                    counter = '0;
                                    MBReady_next = 1'b0;
                                end
                                else
                                begin
                                    MARValid_next = 1'b1;
                                    MARAddr_next = {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                                    MARLen_next = LINE_WORDS - 1;
                                    MARSize_next = TRANSFER_SIZE;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    read_through_hit = 1'b0;
                                    refill_error = 1'b0;
                                    next_state = AXI_RD_ADDR;
                                end
                            end:direct_mapped_write_miss
                            else
                            begin:set_associative_write_miss
                                if(valid_reg[CpuIdx][victim_way] && dirty_reg[CpuIdx][victim_way])
                                begin
                                    next_state = AXI_WR_ADDR;
                                    MAWValid_next = 1'b1;
                                    MAWAddr_next = (WAY == TOTAL_LINES)
                                                 ? {tags_reg[CpuIdx][victim_way], {OFF_W{1'b0}}}
                                                 : {tags_reg[CpuIdx][victim_way], CpuIdx, {OFF_W{1'b0}}};
                                    MAWLen_next = LINE_WORDS - 1;
                                    MAWSize_next = TRANSFER_SIZE;
                                    MAWBurst_next = INCR;
                                    counter = '0;
                                    MBReady_next = 1'b0;
                                end
                                else
                                begin
                                    MARValid_next = 1'b1;
                                    MARAddr_next = {CPUAddr[ADDR_WIDTH-1:OFF_W], {OFF_W{1'b0}}};
                                    MARLen_next = LINE_WORDS - 1;
                                    MARSize_next = TRANSFER_SIZE;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    read_through_hit = 1'b0;
                                    refill_error = 1'b0;
                                    next_state = AXI_RD_ADDR;
                                end
                            end:set_associative_write_miss
                        end
                    end

                    AXI_WR_ADDR:
                    begin
                        if(MAWValid && MAWReady)
                        begin
                            next_state = AXI_WR_DATA;
                            MAWValid_next = 1'b0;
                            MWStrb_next = {(DATA_BYTES){1'b1}};
                            MWValid_next = 1'b1;
                            MWLast_next = (LINE_WORDS == 1);
                            MARAddr_next = '0;
                            MARValid_next = 1'b0;
                            MARLen_next = '0;
                            MARSize_next = '0;
                            MARBurst_next = INCR;
                            if(WAY == 1)
                            begin
                                MWData_next = data_reg[CpuIdx_reg][0][0];
                            end
                            else
                            begin
                                MWData_next = data_reg[CpuIdx_reg][victim_way_reg][0];
                            end
                        end
                    end

                    AXI_WR_DATA:
                    begin
                        if(MWValid && MWReady)
                        begin
                            if(counter_reg == (LINE_WORDS - 1))
                            begin
                                next_state = AXI_WR_RESP;
                                MWValid_next = 1'b0;
                                MWLast_next = 1'b0;
                                MBReady_next = 1'b1;
                                counter = '0;
                            end
                            else
                            begin
                                counter = counter_reg + 1'b1;
                                MWStrb_next = {(DATA_BYTES){1'b1}};
                                MWValid_next = 1'b1;
                                MWLast_next = ((counter_reg + 1'b1) == (LINE_WORDS - 1));
                                if(WAY == 1)
                                begin
                                    MWData_next = data_reg[CpuIdx_reg][0][counter_reg + 1'b1];
                                end
                                else
                                begin
                                    MWData_next = data_reg[CpuIdx_reg][victim_way_reg][counter_reg + 1'b1];
                                end
                            end
                        end
                    end

                    AXI_WR_RESP:
                    begin
                        MBReady_next = 1'b1;
                        if(MBValid && MBReady)
                        begin
                            MBReady_next = 1'b0;
                            MAWValid_next = 1'b0;
                            if(MBResp == AXI_OKAY)
                            begin
                                next_state = AXI_RD_ADDR;
                                MARValid_next = 1'b1;
                                MARAddr_next = miss_line_addr;
                                MARLen_next = LINE_WORDS - 1;
                                MARSize_next = TRANSFER_SIZE;
                                MARBurst_next = INCR;
                                counter = '0;
                                read_through_hit = 1'b0;
                                refill_error = 1'b0;
                                if(WAY == 1)
                                begin
                                    dirty[CpuIdx_reg][0] = 1'b0;
                                end
                                else
                                begin
                                    dirty[CpuIdx_reg][victim_way_reg] = 1'b0;
                                end

                            end
                            else
                            begin
                                next_state = AXI_IDLE;
                                MARValid_next = 1'b0;
                            end
                        end
                    end

                    AXI_RD_ADDR:
                    begin
                        if(MARReady && MARValid)
                        begin
                            next_state = AXI_RD_DATA;
                            MARValid_next = 1'b0;
                            MAWValid_next = 1'b0;
                            MARAddr_next = '0;
                            MARValid_next = 1'b0;
                            MARLen_next = '0;
                            MARSize_next = '0;
                            MARBurst_next = INCR;
                            counter = '0;
                            read_through_hit = 1'b0;
                            refill_error = 1'b0;
                        end
                    end

                    AXI_RD_DATA:
                    begin
                        if(WAY == 1)
                        begin:direct_mapped_read_loop
                            if(MRRValid && MRReady)
                            begin
                                if(MRRResp == AXI_OKAY)
                                begin
                                    data[CpuIdx_reg][0][counter] = MRRData;
                                end
                                else
                                begin
                                    refill_error = 1'b1;
                                end
                                if((MRRResp == AXI_OKAY) && !pending_write &&
                                   (counter == (CpuOffset_reg[OFF_W-1:BYTE_OFF_W])))
                                begin
                                    read_through_hit = 1'b1;
                                end
                                else
                                begin
                                    read_through_hit = 1'b0;
                                end
                                counter = counter + 1'b1;
                                if(MRRLast)
                                begin
                                    if((MRRResp == AXI_OKAY) && !refill_error_reg)
                                    begin
                                        if(pending_write)
                                        begin
                                            data[CpuIdx_reg][0][CpuOffset_reg[OFF_W-1:BYTE_OFF_W]] = MergeBytes(data[CpuIdx_reg][0][CpuOffset_reg[OFF_W-1:BYTE_OFF_W]], pending_write_data, pending_write_be);
                                            dirty[CpuIdx_reg][0] = 1'b1;
                                        end
                                        else
                                        begin
                                            dirty[CpuIdx_reg][0] = 1'b0;
                                        end
                                        valid[CpuIdx_reg][0] = 1'b1;
                                        tags[CpuIdx_reg][0] = CpuTag_reg;
                                    end
                                    next_state = AXI_IDLE;
                                    counter = '0;
                                end
                            end
                        end:direct_mapped_read_loop
                        else
                        begin:set_associative_read_loop
                            if(MRRValid && MRReady)
                            begin
                                if(MRRResp == AXI_OKAY)
                                begin
                                    data[CpuIdx_reg][victim_way_reg][counter] = MRRData;
                                end
                                else
                                begin
                                    refill_error = 1'b1;
                                end
                                if((MRRResp == AXI_OKAY) && !pending_write &&
                                   (counter == (CpuOffset_reg[OFF_W-1:BYTE_OFF_W])))
                                begin
                                    read_through_hit = 1'b1;
                                end
                                else
                                begin
                                    read_through_hit = 1'b0;
                                end
                                counter = counter + 1'b1;

                                if(MRRLast)
                                begin
                                    if((MRRResp == AXI_OKAY) && !refill_error_reg)
                                    begin
                                        if(pending_write)
                                        begin
                                            data[CpuIdx_reg][victim_way_reg][CpuOffset_reg[OFF_W-1:BYTE_OFF_W]] = MergeBytes(data[CpuIdx_reg][victim_way_reg][CpuOffset_reg[OFF_W-1:BYTE_OFF_W]], pending_write_data, pending_write_be);
                                            dirty[CpuIdx_reg][victim_way_reg] = 1'b1;
                                        end
                                        else
                                        begin
                                            dirty[CpuIdx_reg][victim_way_reg] = 1'b0;
                                        end
                                        valid[CpuIdx_reg][victim_way_reg] = 1'b1;
                                        tags[CpuIdx_reg][victim_way_reg] = CpuTag_reg;
                                    end
                                    next_state = AXI_IDLE;
                                    MAWValid_next = 1'b0;
                                    MARAddr_next = '0;
                                    MARValid_next = 1'b0;
                                    MARLen_next = '0;
                                    MARSize_next = '0;
                                    MARBurst_next = INCR;
                                    counter = '0;
                                    if(!and_valid_bits)
                                    begin
                                        lru_way_empty[CpuIdx_reg] = lru_way_empty[CpuIdx_reg] + 1'b1;
                                    end
                                end
                            end
                        end:set_associative_read_loop
                    end
                endcase
            end
        end:gen_read_write_cache
    endgenerate
endmodule
