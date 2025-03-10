// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router URAM Queue Memory
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_uram_queue_memory #(
    parameter int QUEUE_MEM_URAM_DEPTH = 1,
    parameter int BYTES_PER_PAGE = 0,
    parameter int NUM_PAGES = 0,
    parameter int NUM_EGR_PORTS = 0,
    parameter int MTU_BYTES = 2000
) (
    AXIS_int.Slave      packet_in,

    AXIS_int.Slave      sched_dequeue_req,

    AXIS_int.Master     word_out,
    AXI4Lite_int.Master queue_head_pointer_a4l,
    AXIS_int.Master     dequeue_notification,
    AXIS_int.Master     queue_mem_free
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int WORDS_PER_URAM = 4096;
    localparam int QUEUE_MEM_DEPTH = WORDS_PER_URAM * QUEUE_MEM_URAM_DEPTH;
    localparam int QUEUE_MEM_DEPTH_LOG = $clog2(QUEUE_MEM_DEPTH);
    localparam int WORDS_PER_PAGE = BYTES_PER_PAGE / packet_in.DATA_BYTES;
    localparam int WORDS_PER_PAGE_LOG = $clog2(WORDS_PER_PAGE);
    localparam int NUM_PAGES_LOG = $clog2(NUM_PAGES);
    localparam int DATA_BYTES_LOG = $clog2(packet_in.DATA_BYTES);
    localparam int NUM_QUEUES = NUM_EGR_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int NUM_EGR_PORTS_LOG = $clog2(NUM_EGR_PORTS);
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Type Definitions

    typedef struct packed {
        logic [DATA_BYTES_LOG-1:0] keep_encoded;
        logic last;
    } blen_mem_entry_t;

    localparam int BLEN_MEM_WIDTH = DATA_BYTES_LOG + 1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    // encode tkeep as valid_bytes with the exception of all ones tkeep mapping to zero.
    // All zeros tkeep isn't valid so using this mapping saves a bit.

    function logic [DATA_BYTES_LOG-1:0] encode_keep(
        input logic [packet_in.DATA_BYTES-1:0] tkeep
    );
        for (int i=1; i<packet_in.DATA_BYTES; i++) begin
            if (tkeep[i] == 1'b0) begin
                return i;
            end
        end
        return 0;
    endfunction

    function logic [packet_in.DATA_BYTES-1:0] decode_keep(
        input logic [DATA_BYTES_LOG-1:0] keep_encoded
    );
        automatic logic [packet_in.DATA_BYTES-1:0] tkeep = '0;

        if (keep_encoded == 0) return '1;

        for (int i=0; i<packet_in.DATA_BYTES; i++) begin
            if (i < keep_encoded) begin
                tkeep[i] = 1'b1;
            end
        end
        return tkeep;
    endfunction

    function [DATA_BYTES_LOG:0] keep_encoded_to_valid_bytes(
        input logic [DATA_BYTES_LOG-1:0] keep_encoded
    );
        return (keep_encoded == 0) ? packet_in.DATA_BYTES : keep_encoded;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);
    `ELAB_CHECK_GT(BYTES_PER_PAGE, 0);
    `ELAB_CHECK_GT(NUM_PAGES, 0);
    `ELAB_CHECK_GT(packet_in.DATA_BYTES, 0);
    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);
    `ELAB_CHECK_GE(sched_dequeue_req.DATA_BYTES, U_INT_CEIL_DIV(NUM_QUEUES_LOG, 8));
    `ELAB_CHECK_GE(dequeue_notification.DATA_BYTES, U_INT_CEIL_DIV(DATA_BYTES_LOG+1, 8));
    `ELAB_CHECK_EQUAL(dequeue_notification.USER_WIDTH, NUM_QUEUES_LOG);
    `ELAB_CHECK_EQUAL(word_out.USER_WIDTH, QUEUE_SYS_METADATA_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    (* ram_style = "ultra" *) logic [packet_in.DATA_BYTES*8-1:0]  queue_mem [QUEUE_MEM_DEPTH-1:0];
    (* ram_style = "block" *) logic [BLEN_MEM_WIDTH-1:0]          blen_mem  [QUEUE_MEM_DEPTH-1:0];

    // Enqueue
    logic                           packet_in_sop;
    cong_man_metadata_t             packet_in_metadata;
    logic [WORDS_PER_PAGE_LOG-1:0]  tail_ptr;
    logic [NUM_PAGES_LOG-1:0]       current_page;
    logic [NUM_PAGES_LOG-1:0]       next_page;
    logic [QUEUE_MEM_DEPTH_LOG-1:0] queue_mem_wr_addr;
    logic [packet_in.DATA_BYTES*8-1:0]  queue_mem_wr;
    blen_mem_entry_t                blen_mem_wr;
    logic                           wren;

    // Dequeue
    queue_head_pointer_read_t       queue_head_pointer_read;
    logic [NUM_QUEUES_LOG-1:0]      queue_id [1:0];
    logic [NUM_EGR_PORTS_LOG-1:0]   egress_port;
    blen_mem_entry_t                blen_mem_rd;
    queue_system_metadata_t         queue_system_metadata;
    logic [QUEUE_MEM_DEPTH_LOG-1:0] queue_mem_rd_addr;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Enqueue

    assign packet_in.tready = 1'b1;
    assign packet_in_metadata = packet_in.tuser;

    always_ff @(posedge packet_in.clk) begin
        if (!packet_in.sresetn) begin
            packet_in_sop <= 1'b1;
            wren <= 1'b0;
        end else begin
            // Stage 0
            wren <= packet_in.tvalid;
            blen_mem_wr.keep_encoded <= encode_keep(packet_in.tkeep);
            blen_mem_wr.last <= packet_in.tlast;
            queue_mem_wr <= packet_in.tdata;
            if (packet_in.tvalid) begin
                packet_in_sop <= packet_in.tlast;
            end
            if (packet_in.tvalid && packet_in_sop) begin
                queue_mem_wr_addr <= {packet_in_metadata.current_page_ptr[NUM_PAGES_LOG-1:0], packet_in_metadata.tail_ptr[WORDS_PER_PAGE_LOG-1:0]};
                tail_ptr <= packet_in_metadata.tail_ptr[WORDS_PER_PAGE_LOG-1:0] + 1;
                if (packet_in_metadata.tail_ptr[WORDS_PER_PAGE_LOG-1:0] == WORDS_PER_PAGE-1) begin
                    current_page <= packet_in_metadata.next_page_ptr[NUM_PAGES_LOG-1:0];
                end else begin
                    current_page <= packet_in_metadata.current_page_ptr[NUM_PAGES_LOG-1:0];
                end
                next_page <= packet_in_metadata.next_page_ptr;
            end else if (packet_in.tvalid) begin
                queue_mem_wr_addr <= {current_page, tail_ptr};
                tail_ptr <= tail_ptr + 1;
                if (tail_ptr == WORDS_PER_PAGE-1) begin
                    current_page <= next_page;
                end
            end
            // Stage 1
            if (wren) begin
                queue_mem[queue_mem_wr_addr] <= queue_mem_wr;
                blen_mem[queue_mem_wr_addr] <= blen_mem_wr;
            end

        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Dequeue

    assign sched_dequeue_req.tready = 1'b1;

    assign queue_head_pointer_a4l.rready = 1'b1;
    assign queue_head_pointer_a4l.arprot = '0;
    assign queue_head_pointer_a4l.awaddr = '0;
    assign queue_head_pointer_a4l.awprot = '0;
    assign queue_head_pointer_a4l.awvalid = 1'b0;
    assign queue_head_pointer_a4l.wdata = '0;
    assign queue_head_pointer_a4l.wstrb = '1;
    assign queue_head_pointer_a4l.wvalid = 1'b0;
    assign queue_head_pointer_a4l.bready = 1'b1;

    assign dequeue_notification.tkeep = '1;
    assign dequeue_notification.tstrb = '1;
    assign dequeue_notification.tid   = '0;
    assign dequeue_notification.tdest = '0;

    assign queue_head_pointer_read = queue_head_pointer_a4l.rdata;
    assign queue_mem_rd_addr = {queue_head_pointer_read.page_ptr[NUM_PAGES_LOG-1:0], queue_head_pointer_read.head_ptr[WORDS_PER_PAGE_LOG-1:0]};

    assign egress_port = queue_id[1][NUM_QUEUES_LOG-1:NUM_QUEUES_PER_EGR_PORT_LOG];
    assign queue_system_metadata.egress_port = egress_port;

    assign word_out.tkeep = decode_keep(blen_mem_rd.keep_encoded);
    assign word_out.tlast = blen_mem_rd.last;
    assign dequeue_notification.tlast = blen_mem_rd.last;
    assign dequeue_notification.tdata = keep_encoded_to_valid_bytes(blen_mem_rd.keep_encoded);

    always_ff @(posedge word_out.clk) begin
        if (!word_out.sresetn) begin
            blen_mem_rd <= '{default: '0};
        end else begin
            blen_mem_rd <= blen_mem[queue_mem_rd_addr];

            if (sched_dequeue_req.tvalid) begin
                queue_head_pointer_a4l.arvalid <= 1'b1;
                queue_head_pointer_a4l.araddr <= sched_dequeue_req.tdata;
                queue_id[0] <= sched_dequeue_req.tdata;
            end else begin
                queue_head_pointer_a4l.arvalid <= 1'b0;
            end
            queue_id[1] <= queue_id[0];

            word_out.tvalid <= queue_head_pointer_a4l.rvalid;
            queue_mem_free.tvalid <= 1'b0;
            if (queue_head_pointer_a4l.rvalid) begin
                word_out.tdata <= queue_mem[queue_mem_rd_addr];

                word_out.tuser <= queue_system_metadata;
                // free page
                if (queue_head_pointer_read.head_ptr == WORDS_PER_PAGE-1) begin
                    queue_mem_free.tvalid <= 1'b1;
                    queue_mem_free.tdata <= queue_head_pointer_read.page_ptr[NUM_PAGES_LOG-1:0];
                end
                // update queue occupancy
                dequeue_notification.tvalid <= 1'b1;
                dequeue_notification.tuser <= queue_id[1];

            end else begin
                dequeue_notification.tvalid <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
