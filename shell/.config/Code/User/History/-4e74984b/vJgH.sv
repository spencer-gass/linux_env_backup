// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * P4 Router Congestion Manager
 *
 *  Per Egress Port Queues:
 *   Prio 7: Emergency
 *   Prio 6: CMP
 *   Prio 5: Voice
 *   Prio 4:0: Low Priority Data
 *
 * Lookup Cache Pipeline:
 *     packet 1                                        |
 *  0) packet_in sop                                   |
 *  1) tail_ptr & occupancy lookup req                 |
 *  2) tail_ptr & occupancy lookup response            | Need to know if previous packets were dropped or not by this stage in order to select between states from queue_states or lookahead
 *  3) intermediate calculations                       |
 *  4) drop decision                                   | decisions for the queue are finalized and can be passed back to stage 2 if the packet is going to the same queue
 *  5) packet_out sop, tail_ptr & occupancy update req |
 *  6) tail_ptr & occupancy updated, queue state valid | starting this cycle an sop wouldn't need to use the cache
 *
 * TODO(sgass): Current implementation doesn't support back to back packets to the same queue.
 * This would only happen with single cycle (64 byte) packets that arrived on adjacent cycles.
 * I'm leaving this limitation in until I build and get more feedback on critical path / logic levels.
**/
module p4_router_congestion_manager #(
    parameter int NUM_PAGES             = 0,
    parameter int NUM_PAGES_LOG         = $clog2(NUM_PAGES),
    parameter int BYTES_PER_PAGE        = 0,
    parameter int MAX_BYTES_PER_QUEUE   = 0,
    parameter int NUM_EGR_PORTS         = 1,
    parameter int MTU_BYTES             = 2000,
    parameter bit DEBUG_ILA             = 1'b0
) (
    AXIS_int.Slave                        packet_in,
    AXI4Lite_int.Slave                    table_config,
    AXI4Lite_int.Slave                    counter_access,
    AXI4Lite_int.Master                   queue_occupancy_a4l,
    AXI4Lite_int.Master                   queue_tail_pointer_a4l,
    AXIS_int.Slave                        queue_malloc_axis,
    AXIS_int.Master                       packet_out,
    input var logic     [NUM_PAGES_LOG:0] num_free_pages
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import P4_ROUTER_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    localparam int STATE_INVALID_CYCLES        = 6; // Number of cycle between state lookup and write back complete.
    localparam int LAST_LOOKAHEAD_STATE        = 3;
    localparam int PIPE_DEPTH                  = 5;
    localparam int CACHE_DEPTH                 = LAST_LOOKAHEAD_STATE + STATE_INVALID_CYCLES - PIPE_DEPTH;
    localparam int PIPE_DEPTH_LOG              = $clog2(PIPE_DEPTH + CACHE_DEPTH);
    localparam int NUM_EGR_PORTS_LOG           = $clog2(NUM_EGR_PORTS);
    localparam int MAX_BYTES_PER_QUEUE_LOG     = $clog2(MAX_BYTES_PER_QUEUE);
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);
    localparam int NUM_QUEUES                  = NUM_QUEUES_PER_EGR_PORT * NUM_EGR_PORTS;
    localparam int NUM_QUEUES_LOG              = $clog2(NUM_QUEUES);
    localparam int BYTES_PER_WORD_LOG          = $clog2(packet_in.DATA_BYTES);
    localparam int BYTES_PER_PAGE_LOG          = $clog2(BYTES_PER_PAGE);
    localparam int WORDS_PER_PAGE              = BYTES_PER_PAGE / packet_in.DATA_BYTES;
    localparam int WORDS_PER_PAGE_LOG          = $clog2(WORDS_PER_PAGE);
    localparam int MTU_BYTES_LOG               = $clog2(MTU_BYTES);
    localparam int COUNTER_RAM_DEPTH_LOG       = NUM_QUEUES_LOG+NUM_COUNTERS_PER_QUEUE_LOG;
    localparam int COUNTER_RAM_DEPTH           = 2**(COUNTER_RAM_DEPTH_LOG);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, packet_out.DATA_BYTES);
    `ELAB_CHECK_EQUAL(table_config.ADDRLEN, QSYS_TABLE_ID_WIDTH);
    `ELAB_CHECK_EQUAL(counter_access.ADDRLEN, QSYS_COUNTER_ID_WIDTH);
    `ELAB_CHECK_GT(NUM_PAGES, 0);
    `ELAB_CHECK_GT(BYTES_PER_PAGE, 0);
    `ELAB_CHECK_GT(MAX_BYTES_PER_QUEUE, 0);
    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);
    `ELAB_CHECK_GE(table_config.DATALEN, MAX_BYTES_PER_QUEUE_LOG);
    `ELAB_CHECK_EQUAL(NUM_QUEUES_PER_EGR_PORT, 4); // This implementation assumes 4 queues per port


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types


    typedef enum {
        INIT,
        ACTIVE
    } counter_state_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    function automatic logic [NUM_QUEUES_PER_EGR_PORT_LOG-1:0] prio_to_queue_map (
        input logic [PRIO_BITS-1:0] prio
    );
        begin
            case (prio)
                7: return 3; // Emergency
                6: return 2; // Network Control/Management
                5: return 1; // Voice
                default: return 0; // Data
            endcase
        end
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [packet_in.DATA_BYTES*8-1:0]  pkt_data        [PIPE_DEPTH-1:1];
    logic [packet_in.DATA_BYTES-1:0]    pkt_keep        [PIPE_DEPTH-1:1];
    logic [MTU_BYTES_LOG-1:0]           pkt_byte_length [PIPE_DEPTH-1:1];
    logic [PIPE_DEPTH-1:1]              pkt_valid;
    logic [PIPE_DEPTH+CACHE_DEPTH-1:0]  pkt_sop;
    logic [PIPE_DEPTH-1:1]              pkt_eop = '0;

    qsys_table_id_t            table_wid;
    logic [NUM_QUEUES_LOG-1:0] table_waddr;
    qsys_table_id_t            table_rid;
    logic [NUM_QUEUES_LOG-1:0] table_raddr;

    logic [MAX_BYTES_PER_QUEUE_LOG-1:0] drop_thresholds [NUM_QUEUES-1:0] = '{default: '1};
    logic [MAX_BYTES_PER_QUEUE_LOG-1:0] drop_thresh_read;
    logic [MAX_BYTES_PER_QUEUE_LOG-1:0] drop_threshold  [PIPE_DEPTH-1:2];

    policer_metadata_t         packet_in_metadata;
    logic [NUM_QUEUES_LOG-1:0] packet_in_queue_id;
    logic [NUM_QUEUES_LOG-1:0] pkt_queue_id [PIPE_DEPTH+CACHE_DEPTH-1:1];
    logic [2:0]                pkt_prio     [PIPE_DEPTH-1:1];
    cong_man_metadata_t        packet_out_metadata;

    logic [MTU_BYTES_LOG-BYTES_PER_WORD_LOG-1:0]           pkt_word_length;
    logic [WORDS_PER_PAGE_LOG:0]                           tail_ptr_plus_wlen [PIPE_DEPTH+CACHE_DEPTH-1:3];
    logic [MAX_BYTES_PER_QUEUE_LOG:0]                      queue_occupancy_plus_blen[PIPE_DEPTH+CACHE_DEPTH-1:3];
    logic [MAX_BYTES_PER_QUEUE_LOG-BYTES_PER_PAGE_LOG-1:0] queue_occupancy_pages;

    logic                              malloc_required_comb;
    logic [PIPE_DEPTH+CACHE_DEPTH-1:4] malloc_required_sr;
    logic [PIPE_DEPTH+CACHE_DEPTH-1:3] malloc_required;
    logic                              malloc_allowed;
    logic                              malloc_approved;
    logic [WORDS_PER_PAGE_LOG-1:0]     tail_ptr [PIPE_DEPTH+CACHE_DEPTH-1:3];
    logic [NUM_PAGES_LOG-1:0]          current_page_ptr [PIPE_DEPTH+CACHE_DEPTH-1:3];
    logic [PIPE_DEPTH+CACHE_DEPTH-1:3] current_page_valid;
    logic [NUM_PAGES_LOG-1:0]          next_page_ptr [PIPE_DEPTH+CACHE_DEPTH-1:4];
    queue_tail_pointer_read_t          queue_tail_pointer_rdata;
    queue_tail_pointer_write_t         queue_tail_pointer_wdata;

    logic [PIPE_DEPTH-1:1]                 policer_drop_mark;
    logic [PIPE_DEPTH+CACHE_DEPTH-1:4]     drop;
    logic [NUM_COUNTERS_PER_QUEUE_LOG-1:0] drop_type;

    logic                      cache_hit    [PIPE_DEPTH-1:1];
    logic [PIPE_DEPTH_LOG-1:0] cache_offset [PIPE_DEPTH-1:1];

    logic [WORDS_PER_PAGE_LOG-1:0]                         lookahead_tail_ptr;
    logic                                                  lookahead_malloc_required;
    logic [NUM_PAGES_LOG-1:0]                              lookahead_current_page_ptr;
    logic [NUM_PAGES_LOG-1:0]                              lookahead_next_page_ptr;
    logic [PIPE_DEPTH-1:3]                                 lookahead_current_page_valid;
    logic [MAX_BYTES_PER_QUEUE_LOG:0]                      lookahead_queue_occupancy;
    logic [MAX_BYTES_PER_QUEUE_LOG-BYTES_PER_PAGE_LOG-1:0] lookahead_queue_occupancy_pages;

    logic ing_policer_drop;
    logic malloc_drop;
    logic mem_full_drop;
    logic queue_full_drop;
    logic [PIPE_DEPTH-1:1] b2b_drop;

    counter_state_t                           cntr_state;
    qsys_counter_id_t                         qsys_counter_id;
    logic [NUM_QUEUES_LOG-1:0]                init_cntr_queue;
    logic [NUM_COUNTERS_PER_QUEUE_LOG-1:0]    init_cntr_type;
    logic [NUM_QUEUES_LOG-1:0]                rd_cntr_queue;
    logic [NUM_COUNTERS_PER_QUEUE_LOG-1:0]    rd_cntr_type;
    logic [NUM_QSYS_COUNTER_OP_CODES_LOG-1:0] cntr_op_code;

    logic [QSYS_COUNTER_WIDTH-1:0]    drop_cntrs [COUNTER_RAM_DEPTH-1:0] = '{default: '0};
    logic                             cntr_we;
    logic [COUNTER_RAM_DEPTH_LOG-1:0] cntr_waddr;
    logic [QSYS_COUNTER_WIDTH-1:0]    cntr_wdata;
    logic                             cntr_clear_req;
    logic [COUNTER_RAM_DEPTH_LOG-1:0] cntr_clear_addr;
    logic [1:0]                       cntr_update_req;
    logic [COUNTER_RAM_DEPTH_LOG-1:0] cntr_update_raddr [1:0];
    logic [QSYS_COUNTER_WIDTH-1:0]    cntr_access_rdata;
    logic [COUNTER_RAM_DEPTH_LOG-1:0] cntr_access_raddr;
    logic [QSYS_COUNTER_WIDTH-1:0]    cntr_update_rdata;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Data Path


    // Stage 0 (I/O)
    assign packet_in_metadata = packet_in.tuser;
    assign packet_in_queue_id = {packet_in_metadata.egress_port[NUM_EGR_PORTS_LOG-1:0], prio_to_queue_map(packet_in_metadata.prio)};

    assign packet_in.tready = 1'b1;

    assign queue_occupancy_a4l.wstrb  = '1;
    assign queue_occupancy_a4l.awprot = '0;
    assign queue_occupancy_a4l.bready = 1'b1;
    assign queue_occupancy_a4l.arprot = '0;
    assign queue_occupancy_a4l.rready = 1'b1;

    // Stage 1
    assign queue_tail_pointer_a4l.wstrb  = '1;
    assign queue_tail_pointer_a4l.awprot = '0;
    assign queue_tail_pointer_a4l.bready = 1'b1;
    assign queue_tail_pointer_a4l.arprot = '0;
    assign queue_tail_pointer_a4l.rready = 1'b1;

    // Stage 2
    assign queue_tail_pointer_rdata        = queue_tail_pointer_a4l.rdata;
    assign queue_occupancy_pages           = queue_occupancy_a4l.rdata[MAX_BYTES_PER_QUEUE_LOG-1:BYTES_PER_PAGE_LOG];
    assign lookahead_queue_occupancy_pages = lookahead_queue_occupancy[MAX_BYTES_PER_QUEUE_LOG-1:BYTES_PER_PAGE_LOG];

    // Stage 3
    assign malloc_required_comb                         = tail_ptr_plus_wlen[3][WORDS_PER_PAGE_LOG] | !current_page_valid[3];
    assign malloc_required[3]                           = tail_ptr_plus_wlen[3][WORDS_PER_PAGE_LOG] | !current_page_valid[3];
    assign malloc_required[PIPE_DEPTH+CACHE_DEPTH-1:4]  = malloc_required_sr;

    // Stage 4
    assign malloc_approved = queue_malloc_axis.tready;
    assign queue_tail_pointer_wdata.new_tail_ptr    = tail_ptr_plus_wlen[4][WORDS_PER_PAGE_LOG-1:0];
    assign queue_tail_pointer_wdata.next_page_ptr   = next_page_ptr[4];
    assign queue_tail_pointer_wdata.malloc_approved = malloc_approved;

    assign packet_out_metadata.tail_ptr         = tail_ptr[4];
    assign packet_out_metadata.current_page_ptr = current_page_valid[4] ? current_page_ptr[4] : next_page_ptr[4];
    assign packet_out_metadata.next_page_ptr    = next_page_ptr[4];

    assign packet_out.tstrb = '1;
    assign packet_out.tid   = '0;
    assign packet_out.tdest = '0;

    always_ff @(posedge packet_in.clk) begin
        if (!packet_in.sresetn) begin
            pkt_sop                         <= '{0: 1'b1, default: 1'b0};
            pkt_valid                       <= '0;
            queue_tail_pointer_a4l.arvalid  <= 1'b0;
            queue_occupancy_a4l.arvalid     <= 1'b0;
            queue_occupancy_a4l.awvalid     <= 1'b0;
            queue_occupancy_a4l.wvalid      <= 1'b0;
            queue_malloc_axis.tready        <= 1'b0;
            queue_tail_pointer_a4l.awvalid  <= 1'b0;
            queue_tail_pointer_a4l.wvalid   <= 1'b0;
        end else begin
            pkt_data                <= {pkt_data[PIPE_DEPTH-2:1], packet_in.tdata};
            pkt_keep                <= {pkt_keep[PIPE_DEPTH-2:1], packet_in.tkeep};
            pkt_byte_length         <= {pkt_byte_length[PIPE_DEPTH-2:1], packet_in_metadata.byte_length};
            pkt_queue_id            <= {pkt_queue_id[PIPE_DEPTH+CACHE_DEPTH-2:1], packet_in_queue_id};
            pkt_prio                <= {pkt_prio[PIPE_DEPTH-2:1], packet_in_metadata.prio};
            policer_drop_mark       <= {policer_drop_mark[PIPE_DEPTH-2:1] , packet_in_metadata.policer_drop_mark};
            pkt_eop                 <= {pkt_eop[PIPE_DEPTH-2:1], packet_in.tvalid & packet_in.tlast};
            pkt_valid               <= {pkt_valid[PIPE_DEPTH-2:1], packet_in.tvalid};
            cache_hit               <= {cache_hit[PIPE_DEPTH-2:1], 1'b0};
            cache_offset            <= {cache_offset[PIPE_DEPTH-2:1], '0};
            b2b_drop                <= {b2b_drop[PIPE_DEPTH-2:1], 1'b0};

            pkt_sop[PIPE_DEPTH+CACHE_DEPTH-1:1]                   <= {pkt_sop[PIPE_DEPTH+CACHE_DEPTH-2:1], pkt_sop[0] & packet_in.tvalid};
            tail_ptr[PIPE_DEPTH+CACHE_DEPTH-1:4]                  <= tail_ptr[PIPE_DEPTH+CACHE_DEPTH-2:3];
            tail_ptr_plus_wlen[PIPE_DEPTH+CACHE_DEPTH-1:4]        <= tail_ptr_plus_wlen[PIPE_DEPTH+CACHE_DEPTH-2:3];
            current_page_ptr[PIPE_DEPTH+CACHE_DEPTH-1:4]          <= current_page_ptr[PIPE_DEPTH+CACHE_DEPTH-2:3];
            current_page_valid[PIPE_DEPTH+CACHE_DEPTH-1:4]        <= current_page_valid[PIPE_DEPTH+CACHE_DEPTH-2:3];
            queue_occupancy_plus_blen[PIPE_DEPTH+CACHE_DEPTH-1:4] <= queue_occupancy_plus_blen[PIPE_DEPTH+CACHE_DEPTH-2:3];
            malloc_required_sr                                    <= {malloc_required_sr[PIPE_DEPTH+CACHE_DEPTH-2:4], malloc_required_comb};

            next_page_ptr[PIPE_DEPTH+CACHE_DEPTH-1:5] <= next_page_ptr[PIPE_DEPTH+CACHE_DEPTH-2:4];
            drop[PIPE_DEPTH+CACHE_DEPTH-1:5]          <= drop[PIPE_DEPTH+CACHE_DEPTH-2:4];


            // Stage 0
            if (packet_in.tvalid) begin
                pkt_sop[0] <= packet_in.tlast;
            end

            if (packet_in.tvalid && pkt_sop[0]) begin
                queue_tail_pointer_a4l.araddr  <= packet_in_queue_id;
                queue_tail_pointer_a4l.arvalid <= 1'b1; // assume always ready
            end else if (queue_tail_pointer_a4l.arready) begin
                queue_tail_pointer_a4l.arvalid <= 1'b0;
            end

            if (packet_in.tvalid && pkt_sop[0]) begin
                queue_occupancy_a4l.araddr  <= packet_in_queue_id;
                queue_occupancy_a4l.arvalid <= 1'b1; // assume always ready
            end else if (queue_occupancy_a4l.arready) begin
                queue_occupancy_a4l.arvalid <= 1'b0;
            end

            if (packet_in.tvalid && pkt_sop[0]) begin
                for (int i=1; i<STATE_INVALID_CYCLES; i++) begin
                    if (pkt_sop[i] && packet_in_queue_id == pkt_queue_id[i]) begin
                        if (i == 1) begin
                            $display("Two packets to the same queue entered congestion manager on back to back cycles. This isn't supported yet.");
                            b2b_drop[1] <= 1'b1;
                        end
                        cache_hit[1]    <= 1'b1;
                        cache_offset[1] <= i;
                        break;
                    end
                end
            end


            // Stage 1
            pkt_word_length <= '0;
            if (pkt_byte_length[1][BYTES_PER_WORD_LOG-1:0]) begin
                pkt_word_length <= (pkt_byte_length[1] >> BYTES_PER_WORD_LOG) + 1;
            end else begin
                pkt_word_length <= (pkt_byte_length[1] >> BYTES_PER_WORD_LOG);
            end

            drop_threshold <= {drop_threshold[PIPE_DEPTH-2:2], drop_thresh_read};

            lookahead_tail_ptr              <= tail_ptr_plus_wlen[1+cache_offset[1]][WORDS_PER_PAGE_LOG-1:0];
            lookahead_malloc_required       <= malloc_required[1+cache_offset[1]];
            lookahead_current_page_ptr      <= current_page_ptr[1+cache_offset[1]];
            lookahead_current_page_valid    <= current_page_valid[1+cache_offset[1]];
            lookahead_queue_occupancy       <= queue_occupancy_plus_blen[1+cache_offset[1]];
            lookahead_next_page_ptr         <= (cache_offset[1] == 2) ? queue_malloc_axis.tdata : next_page_ptr[1+cache_offset[1]];


            // Stage 2
            if (queue_tail_pointer_a4l.rvalid) begin // Assumes 1 cycle latency from tail pointer loopup
                if (!cache_hit[2] || drop[2+cache_offset[2]]) begin
                    tail_ptr[3]             <= queue_tail_pointer_rdata.tail_ptr;
                    tail_ptr_plus_wlen[3]   <= {1'b0, queue_tail_pointer_rdata.tail_ptr[WORDS_PER_PAGE_LOG-1:0]} + pkt_word_length;
                    current_page_ptr[3]     <= queue_tail_pointer_rdata.current_page_ptr;
                    current_page_valid[3]   <= queue_tail_pointer_rdata.current_page_valid;
                end else begin
                    tail_ptr[3]             <= lookahead_tail_ptr;
                    tail_ptr_plus_wlen[3]   <= {1'b0, lookahead_tail_ptr} + pkt_word_length;
                    current_page_valid[3]   <= 1'b1;
                    if (lookahead_malloc_required) begin
                        current_page_ptr[3] <= lookahead_next_page_ptr;
                    end else begin
                        current_page_ptr[3] <= lookahead_current_page_ptr;
                    end
                end
            end

            if (queue_occupancy_a4l.rvalid) begin // Assumes 1 cycle latency from queue occupancy lookup
                if (!cache_hit[2] || drop[2+cache_offset[2]]) begin
                    queue_occupancy_plus_blen[3] <= queue_occupancy_a4l.rdata[MAX_BYTES_PER_QUEUE_LOG-1:0] + pkt_byte_length[2];
                end else begin
                    queue_occupancy_plus_blen[3] <= lookahead_queue_occupancy + pkt_byte_length[2];
                end
            end

            // need more work here.
            // current state: don't allow a malloc to deep queues (used_pages >= free_pages)
            // probably want per-queue setting so that high prio queues can malloc when fuller
            // and low prio can't malloc when mem is ~75%-95% full.
            if  (!cache_hit[2] || drop[2+cache_offset[2]]) begin
                malloc_allowed <= (queue_occupancy_pages <= num_free_pages) ? 1'b1 : 1'b0;
            end else begin
                malloc_allowed <= (lookahead_queue_occupancy_pages <= num_free_pages) ? 1'b1 : 1'b0;
            end


            // Stage 3
            queue_malloc_axis.tready <= 1'b0;
            ing_policer_drop <= 1'b0;
            malloc_drop <= 1'b0;
            mem_full_drop <= 1'b0;
            queue_full_drop <= 1'b0;
            if (pkt_sop[3]) begin
                next_page_ptr[4] <= queue_malloc_axis.tdata;
                if (policer_drop_mark[3] && pkt_prio[3] < 6) begin // Hardcode letting emergency and CMP traffic bypass ingress shaper. could make this configurable later.
                    drop[4]          <= 1'b1;
                    drop_type        <= ING_POLICER_DROP;
                    ing_policer_drop <= 1'b1;
                end else if (queue_occupancy_plus_blen[3] > drop_threshold[3]) begin
                    drop[4]         <= 1'b1;
                    drop_type       <= QUEUE_FULL_DROP;
                    queue_full_drop <= 1'b1;
                end else if (malloc_required[3] && !malloc_allowed) begin
                    drop[4]     <= 1'b1;
                    drop_type   <= MALLOC_DROP;
                    malloc_drop <= 1'b1;
                end else if (malloc_required[3] && !queue_malloc_axis.tvalid) begin
                    drop[4]         <= 1'b1;
                    drop_type       <= MEM_FULL_DROP;
                    mem_full_drop   <= 1'b1;
                end else if (b2b_drop[3]) begin
                    drop[4]         <= 1'b1;
                    drop_type       <= B2B_DROP;
                end else begin
                    drop[4]                  <= 1'b0;
                    queue_malloc_axis.tready <= malloc_required[3];
                end
            end


            // Stage 4
            packet_out.tvalid <= pkt_valid[4] & ~drop[4];
            packet_out.tlast  <= pkt_eop[4]   & ~drop[4];
            packet_out.tdata  <= pkt_data[4];
            packet_out.tkeep  <= pkt_keep[4];
            packet_out.tuser  <= packet_out_metadata;

            // May want to update queue occupancy on EOP
            // enqueue should be faster than dequeue so updating on
            // SOP should work and may reduces latency slightly
            queue_occupancy_a4l.awvalid <= pkt_sop[4] & ~drop[4];
            queue_occupancy_a4l.awaddr  <= pkt_queue_id[4];
            queue_occupancy_a4l.wvalid  <= pkt_sop[4] & ~drop[4];
            queue_occupancy_a4l.wdata   <= '0;
            queue_occupancy_a4l.wdata   <= pkt_byte_length[4];

            queue_tail_pointer_a4l.awvalid  <= pkt_sop[4] & ~drop[4];
            queue_tail_pointer_a4l.awaddr   <= pkt_queue_id[4];
            queue_tail_pointer_a4l.wvalid   <= pkt_sop[4] & ~drop[4];
            queue_tail_pointer_a4l.wdata    <= queue_tail_pointer_wdata;

        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Table config


    assign table_config.awready = ~table_config.bvalid;
    assign table_config.wready  = ~table_config.bvalid;
    assign table_config.arready = ~table_config.rvalid;

    assign table_wid   = table_config.awaddr;
    assign table_rid   = table_config.araddr;
    assign table_waddr = table_wid.address[NUM_QUEUES_LOG-1:0];
    assign table_raddr = table_rid.address[NUM_QUEUES_LOG-1:0];

    always_ff @(posedge table_config.clk) begin
        if (!table_config.sresetn) begin
            table_config.bvalid  <= 1'b0;
            table_config.rvalid  <= 1'b0;
        end else begin

            // Table Write
            if (table_config.awvalid && table_config.wvalid && !table_config.bvalid) begin
                table_config.bvalid <= 1'b1;
                if (table_wid.address < NUM_QUEUES) begin
                    table_config.bresp  <= table_config.OKAY;
                    case (table_wid.select)
                        CONG_MAN_DROP_THRESH_TABLE  : drop_thresholds[table_waddr] <= table_config.wdata[MAX_BYTES_PER_QUEUE_LOG-1:0];
                        // CONG_MAN_MALOC_THRESH_TABLE :  <= table_config.wdata;
                        default : table_config.bresp <= table_config.SLVERR;
                    endcase
                end else begin
                    table_config.bresp  <= table_config.SLVERR;
                end
            end else if (table_config.bready) begin
                table_config.bvalid <= 1'b0;
            end

            // Table Read
            if (packet_in.tvalid) begin // Prioritize reading drop thresholds for incomming packets
                drop_thresh_read <= drop_thresholds[packet_in_queue_id];
            end else if (table_config.arvalid && table_config.arready) begin
                table_config.rvalid <= 1'b1;
                table_config.rdata  <= '0;
                if (table_rid.address < NUM_QUEUES) begin
                    table_config.rresp <= table_config.OKAY;
                    case (table_rid.select)
                        CONG_MAN_DROP_THRESH_TABLE : table_config.rdata[MAX_BYTES_PER_QUEUE_LOG-1:0] <= drop_thresholds[table_raddr];
                        // CONG_MAN_MALOC_THRESH_TABLE : table_config.rdata <= ;
                        default : table_config.rresp <= table_config.SLVERR;
                    endcase
                end else begin
                    table_config.rresp <= table_config.SLVERR;
                end
            end else if (table_config.rready) begin
                table_config.rvalid <= 1'b0;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Drop Counters


    // write interface isn't used
    assign counter_access.awready = 1'b0;
    assign counter_access.wready  = 1'b0;
    assign counter_access.bvalid  = 1'b0;
    assign counter_access.bresp   = '0;

    assign counter_access.arready = cntr_state == ACTIVE ? ~counter_access.rvalid & ~cntr_clear_req : 1'b0;

    assign qsys_counter_id = counter_access.araddr;
    assign cntr_op_code  = qsys_counter_id.op_code[NUM_QSYS_COUNTER_OP_CODES_LOG-1:0];
    assign rd_cntr_queue = qsys_counter_id.queue[NUM_QUEUES_LOG-1:0];
    assign rd_cntr_type  = qsys_counter_id.counter_type[NUM_COUNTERS_PER_QUEUE_LOG-1:0];

    assign counter_access.rdata = cntr_access_rdata;
    assign cntr_access_raddr    = {rd_cntr_queue, rd_cntr_type};

    always_ff @(posedge counter_access.clk) begin
        if (!counter_access.sresetn) begin
            init_cntr_queue        <= '0;
            init_cntr_type         <= '0;
            cntr_state             <= INIT;
            counter_access.rvalid  <= 1'b0;
            cntr_clear_req         <= 1'b0;
        end else begin
            cntr_we           <= 1'b0;
            cntr_update_req   <= {cntr_update_req[0], 1'b0};
            cntr_update_raddr <= {cntr_update_raddr[0], '0};

            case (cntr_state)
                INIT: begin // Clear all counters
                    `ifdef MODEL_TECH
                        // bypass looping through the counters in sim to save time.
                        cntr_state <= ACTIVE;
                    `endif
                    `ifndef MODEL_TECH
                        cntr_we    <= 1'b1;
                        cntr_wdata <= '0;
                        cntr_waddr <= {init_cntr_queue, init_cntr_type};
                        if (init_cntr_queue < NUM_QUEUES-1) begin
                            init_cntr_queue <= init_cntr_queue + 1;
                        end else begin
                            init_cntr_queue <= '0;
                            if (init_cntr_type < NUM_COUNTERS_PER_QUEUE-1) begin
                                init_cntr_type <= init_cntr_type + 1;
                            end else begin
                                init_cntr_type <= '0;
                                cntr_state <= ACTIVE;
                            end
                        end
                    `endif
                end
                ACTIVE: begin
                    if (pkt_sop[4] && drop[4]) begin
                        cntr_update_req[0]   <= 1'b1;
                        cntr_update_raddr[0] <= {pkt_queue_id[4], drop_type};
                    end

                    if (counter_access.arvalid && counter_access.arready) begin
                        case (cntr_op_code)
                            READ : begin
                                counter_access.rvalid <= 1'b1;
                                counter_access.rresp  <= counter_access.OKAY;
                            end
                            READ_AND_CLEAR : begin
                                cntr_clear_req        <= 1'b1;
                                cntr_clear_addr       <= {rd_cntr_queue, rd_cntr_type};
                                counter_access.rvalid <= 1'b1;
                                counter_access.rresp  <= counter_access.OKAY;
                            end
                            CLEAR_ALL : begin
                                counter_access.rvalid <= 1'b1;
                                cntr_state <= INIT;
                                counter_access.rresp <= counter_access.OKAY;
                            end
                            default: begin
                                counter_access.rvalid  <= 1'b1;
                                counter_access.rresp <= counter_access.SLVERR;
                            end
                        endcase
                    end

                    if (cntr_update_req[1]) begin
                        cntr_we    <= 1'b1;
                        cntr_wdata <= (&cntr_update_rdata) ? '1 : cntr_update_rdata + 1;
                        cntr_waddr <= cntr_update_raddr[1];
                    end else if (cntr_clear_req) begin
                        cntr_clear_req <= 1'b0;
                        cntr_we    <= 1'b1;
                        cntr_wdata <= '0;
                        cntr_waddr <= cntr_clear_addr;
                    end

                end
                default: cntr_state <= INIT;
            endcase

            if (counter_access.rvalid && counter_access.rready) begin
                counter_access.rvalid <= 1'b0;
            end
        end
    end

    always_ff @(posedge counter_access.clk) begin
        if (cntr_we) begin
            drop_cntrs[cntr_waddr] <= cntr_wdata;
        end
        cntr_update_rdata <= drop_cntrs[cntr_update_raddr[0]];
        cntr_access_rdata <= drop_cntrs[cntr_access_raddr];

        // bypass looping through the counters in sim to save time.
        `ifdef MODEL_TECH
            if (cntr_state == INIT) begin
                drop_cntrs <= '{default: '0};
            end
        `endif
    end

    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                logic [31:0] dbg_cntr;
                always_ff @(posedge packet_in.clk) begin
                    if (!packet_in.sresetn) begin
                        dbg_cntr <= '0;
                    end else begin
                        dbg_cntr <= dbg_cntr + 1'b1;
                    end
                end

                ila_debug ila_drop_calc (
                    .clk    ( packet_in.clk                     ),
                    .probe0 ( packet_in.tvalid                  ),
                    .probe1 ( packet_in.tlast                   ),
                    .probe2 ( num_free_pages                    ),
                    .probe3 ( queue_tail_pointer_a4l.araddr     ),
                    .probe4 ( queue_tail_pointer_a4l.arvalid    ),
                    .probe5 ( queue_tail_pointer_a4l.rvalid     ),
                    .probe6 ( queue_tail_pointer_rdata          ),
                    .probe7 ( queue_occupancy_a4l.araddr        ),
                    .probe8 ( queue_occupancy_a4l.arvalid       ),
                    .probe9 ( queue_occupancy_a4l.rvalid        ),
                    .probe10( queue_occupancy_a4l.rdata         ),
                    .probe11( pkt_byte_length[2]                ),
                    .probe12( drop_thresh_read                  ),
                    .probe13( drop_type                         ),
                    .probe14( {policer_drop_mark[3],
                               drop[4],
                               malloc_required[3],
                               malloc_allowed}                  ),
                    .probe15( dbg_cntr                          )
                );

                ila_debug ila_drop_counters (
                    .clk    ( packet_in.clk             ),
                    .probe0 ( drop_type                 ),
                    .probe1 ( drop[4]                   ),
                    .probe2 ( counter_access.arready    ),
                    .probe3 ( counter_access.arvalid    ),
                    .probe4 ( counter_access.rresp      ),
                    .probe5 ( counter_access.rdata      ),
                    .probe6 ( counter_access.araddr     ),
                    .probe7 ( cntr_op_code              ),
                    .probe8 ( rd_cntr_queue             ),
                    .probe9 ( rd_cntr_type              ),
                    .probe10( cntr_access_raddr         ),
                    .probe11( cntr_state                ),
                    .probe12( cntr_we                   ),
                    .probe13( cntr_waddr                ),
                    .probe14( cntr_wdata                ),
                    .probe15( dbg_cntr                  )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
