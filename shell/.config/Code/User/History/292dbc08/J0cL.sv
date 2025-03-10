// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Queue_States
 *  Data store for queue occupacies, head pointers and tail pointers.
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_queue_states
    import p4_router_pkg::*;
#(
    parameter int NUM_PAGES = 0,
    parameter int WORDS_PER_PAGE = 0,
    parameter int BYTES_PER_WORD = 0,
    parameter int NUM_EGR_PORTS = 0,
    parameter int NUM_QUEUES = NUM_EGR_PORTS * NUM_QUEUES_PER_EGR_PORT,
    parameter int MTU_BYTES = 2000
) (
    AXI4Lite_int.Slave enqueue_queue_occupancy_a4l,
    AXI4Lite_int.Slave queue_tail_pointer_a4l,
    AXI4Lite_int.Slave queue_head_pointer_a4l,
    AXIS_int.Slave     dequeue_queue_occupancy_axis,
    output var logic [NUM_QUEUES-1:0] queue_empty
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int WORDS_PER_PAGE_LOG = $clog2(WORDS_PER_PAGE);
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int NUM_PAGES_LOG = $clog2(NUM_PAGES);
    localparam int TOTAL_NUM_BYTES = NUM_PAGES * WORDS_PER_PAGE * BYTES_PER_WORD;
    localparam int TOTAL_NUM_BYTES_LOG = $clog2(TOTAL_NUM_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_PAGES, 0);
    `ELAB_CHECK_GT(WORDS_PER_PAGE, 0);
    `ELAB_CHECK_GT(BYTES_PER_WORD, 0);
    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);

    `ELAB_CHECK_EQUAL(dequeue_queue_occupancy_axis.ALLOW_BACKPRESSURE, 0);
    `ELAB_CHECK_GE(dequeue_queue_occupancy_axis.USER_WIDTH, NUM_QUEUES_LOG);

    `ELAB_CHECK_EQUAL(queue_tail_pointer_a4l.DATALEN, QUEUE_TAIL_POINTER_DATALEN);
    `ELAB_CHECK_EQUAL(queue_tail_pointer_a4l.ADDRLEN, NUM_QUEUES_LOG);

    `ELAB_CHECK_EQUAL(queue_head_pointer_a4l.ADDRLEN, NUM_QUEUES_LOG);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [WORDS_PER_PAGE_LOG-1:0] head_pointers [NUM_QUEUES-1:0];
    logic [WORDS_PER_PAGE_LOG-1:0] tail_pointers [NUM_QUEUES-1:0];
    logic [WORDS_PER_PAGE_LOG-1:0] next_head_ptr;
    (* ram_style = "block" *)
    logic [NUM_PAGES_LOG-1:0] page_pointer_fifo [NUM_QUEUES-1:0] [NUM_PAGES-1:0]; ///

    logic [TOTAL_NUM_BYTES_LOG-1:0] queue_occupancies [NUM_QUEUES-1:0];
    logic [NUM_PAGES_LOG-1:0] page_fifo_wr_ptrs [NUM_QUEUES-1:0];
    logic [NUM_PAGES_LOG-1:0] page_fifo_rd_ptrs [NUM_QUEUES-1:0];
    logic [NUM_PAGES_LOG-1:0] next_page_fifo_rd_ptr;

    queue_tail_pointer_read_t queue_tail_pointer_rdata; ///
    queue_tail_pointer_write_t queue_tail_pointer_wdata;

    queue_head_pointer_read_t queue_head_pointer_rdata; ///
    logic [NUM_QUEUES-1:0]    page_fifo_empty;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Queue Empty Indecator

    assign next_head_ptr = head_pointers[queue_head_pointer_a4l.araddr] + 1;
    assign next_page_fifo_rd_ptr = head_pointers[queue_head_pointer_a4l.araddr] == WORDS_PER_PAGE-1 ?
                                   page_fifo_rd_ptrs[queue_head_pointer_a4l.araddr] + 1 :
                                   page_fifo_rd_ptrs[queue_head_pointer_a4l.araddr];

    always_ff @(posedge enqueue_queue_occupancy_a4l.clk) begin
        if (!enqueue_queue_occupancy_a4l.sresetn) begin
            queue_empty <= '1;
        end else begin
            if (queue_head_pointer_a4l.arvalid) begin
                if (next_head_ptr == tail_pointers[queue_head_pointer_a4l.araddr] &&
                    next_page_fifo_rd_ptr == page_fifo_wr_ptrs[queue_head_pointer_a4l.araddr]) begin
                    queue_empty[queue_head_pointer_a4l.araddr] <= 1'b1;
                end
            end
            if (enqueue_queue_occupancy_a4l.awvalid && enqueue_queue_occupancy_a4l.wvalid) begin
                queue_empty[enqueue_queue_occupancy_a4l.awaddr] <= 1'b0;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue Occupancy

    // Queue Occupancy Update
    assign enqueue_queue_occupancy_a4l.awready = 1'b1;
    assign enqueue_queue_occupancy_a4l.wready = 1'b1;
    assign enqueue_queue_occupancy_a4l.bresp = enqueue_queue_occupancy_a4l.OKAY;

    assign dequeue_queue_occupancy_axis.tready = 1'b1;

    always_ff @(posedge enqueue_queue_occupancy_a4l.clk) begin
        if (!enqueue_queue_occupancy_a4l.sresetn) begin
            queue_occupancies <= '{default: '0};
            enqueue_queue_occupancy_a4l.bvalid <= 1'b0;
        end else begin
            enqueue_queue_occupancy_a4l.bvalid <= 1'b0;
            if (enqueue_queue_occupancy_a4l.awvalid && enqueue_queue_occupancy_a4l.wvalid && dequeue_queue_occupancy_axis.tvalid && enqueue_queue_occupancy_a4l.awaddr == dequeue_queue_occupancy_axis.tuser) begin
                queue_occupancies[enqueue_queue_occupancy_a4l.awaddr] <= queue_occupancies[enqueue_queue_occupancy_a4l.awaddr] + enqueue_queue_occupancy_a4l.wdata - dequeue_queue_occupancy_axis.tdata;
                enqueue_queue_occupancy_a4l.bvalid <= 1'b1;
            end else begin
                if (dequeue_queue_occupancy_axis.tvalid) begin
                    queue_occupancies[dequeue_queue_occupancy_axis.tuser] <= queue_occupancies[dequeue_queue_occupancy_axis.tuser] - dequeue_queue_occupancy_axis.tdata;
                    if (dequeue_queue_occupancy_axis.tdata == queue_occupancies[dequeue_queue_occupancy_axis.tuser]) begin
                    end
                end
                if (enqueue_queue_occupancy_a4l.awvalid && enqueue_queue_occupancy_a4l.wvalid) begin
                    queue_occupancies[enqueue_queue_occupancy_a4l.awaddr] <= queue_occupancies[enqueue_queue_occupancy_a4l.awaddr] + enqueue_queue_occupancy_a4l.wdata;
                    enqueue_queue_occupancy_a4l.bvalid <= 1'b1;
                end
            end
        end
    end

    // Queue Occupancy Read
    assign enqueue_queue_occupancy_a4l.arready = 1'b1;

    always_ff @(posedge enqueue_queue_occupancy_a4l.clk) begin
        if (!enqueue_queue_occupancy_a4l.sresetn) begin
            enqueue_queue_occupancy_a4l.rdata   <= '0;
            enqueue_queue_occupancy_a4l.rresp   <= '0;
            enqueue_queue_occupancy_a4l.rvalid  <= 1'b0;
        end else begin
            if (enqueue_queue_occupancy_a4l.arvalid) begin
                enqueue_queue_occupancy_a4l.rdata <= queue_occupancies[enqueue_queue_occupancy_a4l.araddr];
                enqueue_queue_occupancy_a4l.rvalid <= 1'b1;
                enqueue_queue_occupancy_a4l.rresp <= enqueue_queue_occupancy_a4l.OKAY;
            end else if (enqueue_queue_occupancy_a4l.rready) begin
                enqueue_queue_occupancy_a4l.rvalid <= 1'b0;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue Pointers

    // Tail Pointers Write
    assign queue_tail_pointer_a4l.awready = 1'b1;
    assign queue_tail_pointer_a4l.wready = 1'b1;
    assign queue_tail_pointer_wdata = queue_tail_pointer_a4l.wdata;

    // Tail Pointers Read
    assign queue_tail_pointer_a4l.arready = 1'b1;
    assign queue_tail_pointer_a4l.rdata = queue_tail_pointer_rdata;

    // Head Pointers Write
    assign queue_head_pointer_a4l.awready = 1'b1;
    assign queue_head_pointer_a4l.wready = 1'b1;
    assign queue_head_pointer_a4l.bresp = queue_head_pointer_a4l.OKAY;
    assign queue_head_pointer_a4l.bvalid = 1'b0;

    // Head Pointers Read
    assign queue_head_pointer_a4l.arready = 1'b1;
    assign queue_head_pointer_a4l.rdata = queue_head_pointer_rdata;

    always_ff @(posedge queue_tail_pointer_a4l.clk) begin
        if (!queue_tail_pointer_a4l.sresetn) begin
            page_fifo_empty                 <= '1;
            page_pointer_fifo               <= '{default: '0};

            // Tail Pointers Write
            queue_tail_pointer_a4l.bresp    <= queue_tail_pointer_a4l.OKAY;
            queue_tail_pointer_a4l.bvalid   <= 1'b0;
            tail_pointers                   <= '{default: '0};
            page_fifo_wr_ptrs               <= '{default: '0};

            // Tail Pointers Read
            queue_tail_pointer_rdata        <= '{default: '0};
            queue_tail_pointer_a4l.rresp    <= queue_tail_pointer_a4l.OKAY;
            queue_tail_pointer_a4l.rvalid   <= 1'b0;

            // Head Pointers Read
            queue_head_pointer_rdata       <= '{default: '0};
            queue_head_pointer_a4l.rresp   <= queue_head_pointer_a4l.OKAY;
            queue_head_pointer_a4l.rvalid  <= 1'b0;
            head_pointers                  <= '{default: '0};
            page_fifo_rd_ptrs              <= '{default: '0};
        end else begin

            // Tail Pointers Write
            if (queue_tail_pointer_a4l.awvalid && queue_tail_pointer_a4l.wvalid) begin
                if (queue_tail_pointer_wdata.malloc_approved) begin
                    if (page_fifo_empty[queue_tail_pointer_a4l.awaddr]) begin
                        page_pointer_fifo[queue_tail_pointer_a4l.awaddr][page_fifo_wr_ptrs[queue_tail_pointer_a4l.awaddr]] <= queue_tail_pointer_wdata.next_page_ptr;
                        page_fifo_empty[queue_tail_pointer_a4l.awaddr] <= 1'b0;
                    end else begin
                        page_pointer_fifo[queue_tail_pointer_a4l.awaddr][page_fifo_wr_ptrs[queue_tail_pointer_a4l.awaddr]+1] <= queue_tail_pointer_wdata.next_page_ptr;
                        page_fifo_wr_ptrs[queue_tail_pointer_a4l.awaddr] <= page_fifo_wr_ptrs[queue_tail_pointer_a4l.awaddr] + 1;
                    end
                end
                tail_pointers[queue_tail_pointer_a4l.awaddr] <= queue_tail_pointer_wdata.new_tail_ptr;
                queue_tail_pointer_a4l.bvalid <= 1'b1;
                queue_tail_pointer_a4l.bresp <= queue_tail_pointer_a4l.OKAY;
            end else if (queue_tail_pointer_a4l.bready) begin
                queue_tail_pointer_a4l.bvalid <= 1'b0;
            end

            // Tail Pointers Read
            if (queue_tail_pointer_a4l.arvalid) begin
                queue_tail_pointer_rdata.tail_ptr           <= tail_pointers[queue_tail_pointer_a4l.araddr];
                queue_tail_pointer_rdata.current_page_ptr   <= page_pointer_fifo[queue_tail_pointer_a4l.araddr][page_fifo_wr_ptrs[queue_tail_pointer_a4l.araddr]];
                queue_tail_pointer_rdata.current_page_valid <= ~page_fifo_empty[queue_tail_pointer_a4l.araddr];
                queue_tail_pointer_a4l.rvalid <= 1'b1;
                queue_tail_pointer_a4l.rresp <= queue_tail_pointer_a4l.OKAY;
            end else if (queue_tail_pointer_a4l.rready) begin
                queue_tail_pointer_a4l.rvalid <= 1'b0;
            end

            // Head Pointers Read
            if (queue_head_pointer_a4l.arvalid) begin
                // respond to head lookup request
                queue_head_pointer_rdata.page_ptr <= page_pointer_fifo[queue_head_pointer_a4l.araddr][page_fifo_rd_ptrs[queue_head_pointer_a4l.araddr]];
                queue_head_pointer_rdata.head_ptr <= head_pointers[queue_head_pointer_a4l.araddr];
                queue_head_pointer_a4l.rvalid <= 1'b1;
                queue_head_pointer_a4l.rresp <= queue_head_pointer_a4l.OKAY;
                // update pointers
                head_pointers[queue_head_pointer_a4l.araddr] <= head_pointers[queue_head_pointer_a4l.araddr] + 1;
                if (head_pointers[queue_head_pointer_a4l.araddr] == WORDS_PER_PAGE-1) begin
                    page_fifo_rd_ptrs[queue_head_pointer_a4l.araddr] <= page_fifo_rd_ptrs[queue_head_pointer_a4l.araddr] + 1;
                end
            end else if (queue_head_pointer_a4l.rready) begin
                queue_head_pointer_a4l.rvalid <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
