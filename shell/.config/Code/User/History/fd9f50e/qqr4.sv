// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for p4_router_queue_states
 */

module p4_router_queue_states_tb();

    parameter int NUM_ING_PHYS_PORTS = 4;
    parameter int NUM_EGR_PHYS_PORTS = 4;

    parameter int QUEUE_MEM_URAM_DEPTH = 8;
    parameter int MTU_BYTES = 1500;
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int VNP4_DATA_BYTES = 64;
    parameter int BYTES_PER_PAGE = 4096;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int AXI4LITE_DATALEN = 64;
    localparam int AXI4LITE_ADDRLEN = 8;

    localparam int WORDS_PER_URAM = 4096;
    localparam int WORDS_PER_PAGE = BYTES_PER_PAGE / VNP4_DATA_BYTES;
    localparam int QUEUE_MEM_TOTAL_BYTES = WORDS_PER_URAM * QUEUE_MEM_URAM_DEPTH * VNP4_DATA_BYTES;
    localparam int QUEUE_MEM_TOTAL_BYTES_LOG = $clog2(QUEUE_MEM_TOTAL_BYTES);
    localparam int NUM_PAGES = QUEUE_MEM_TOTAL_BYTES / BYTES_PER_PAGE;
    localparam int NUM_PAGES_LOG = $clog2(NUM_PAGES);
    localparam int NUM_QUEUES = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int NUM_PAGES_LOG_BYTES = U_INT_CEIL_DIV(NUM_PAGES_LOG, 8);

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);
    localparam int MAX_PKT_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, VNP4_DATA_BYTES);
    localparam int VNP4_DATA_BYTES_LOG = $clog2(VNP4_DATA_BYTES);

    localparam int QUEUE_OCC_DATALEN = 2**$clog2(QUEUE_MEM_TOTAL_BYTES_LOG);
    localparam int DQ_NOTE_DATA_BYTES = U_INT_CEIL_DIV($clog2(VNP4_DATA_BYTES)+1, 8);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    logic [NUM_QUEUES-1:0] dut_queue_empty;
    logic [MTU_BYTES_LOG-1:0] blen_queue_front [NUM_QUEUES-1:0];
    int num_packets_to_send;
    int timer;
    bit sched_enable;

    queue_head_pointer_read_t head_ptr_rd;
    int dq_blen;

    // Sim Model
    int queue_occupancies [NUM_QUEUES-1:0];
    int tail_ptrs [NUM_QUEUES-1:0];
    int head_ptrs [NUM_QUEUES-1:0];
    int page_fifo [NUM_QUEUES-1:0] [$];
    int page_fifo_size [NUM_QUEUES-1:0];
    int tail_page [NUM_QUEUES-1:0];
    int head_page [NUM_QUEUES-1:0];
    bit [NUM_QUEUES-1:0] queue_empty;
    bit [NUM_QUEUES-1:0] page_fifo_init;
    int blen_queue [NUM_QUEUES-1:0] [$];
    int free_page_queue [$];

    int dq_pkt_cnt;
    int egr_port_sel;
    bit [NUM_EGR_PHYS_PORTS-1:0] pkt_dq_in_progress;
    int dq_in_progress_queue [NUM_EGR_PHYS_PORTS-1:0];
    bit pkt_last_word;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces

    AXIS_int #(
        .DATA_BYTES ( DQ_NOTE_DATA_BYTES ),
        .USER_WIDTH ( NUM_QUEUES_LOG ),
        .ALLOW_BACKPRESSURE ( 0      )
    ) dequeue_notification (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interfaces

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_OCC_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG    )
    ) cong_man_queue_occupancy (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG    )
    ) queue_tail_pointer (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_HEAD_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             )
    ) queue_head_pointer (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    //////////////////////////////////////////////////////////////////////////
    // Logic Implemenatation

    // simulation clock
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Mocks

    AXI4Lite_master #(
        .DATALEN    ( QUEUE_OCC_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG    ),
        .ASSIGN_DELAY ( 0               )
    ) queue_occupancy_enqueue_master (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_master_module queue_occupancy_enqueue_master_inst (
        .control    ( queue_occupancy_enqueue_master      ),
        .o          ( cong_man_queue_occupancy  )
    );

    AXI4Lite_master #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             ),
        .ASSIGN_DELAY ( 0                        )
    ) tail_pointer_master (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_master_module tail_pointer_master_inst (
        .control    ( tail_pointer_master   ),
        .o          ( queue_tail_pointer  )
    );

    AXI4Lite_master #(
        .DATALEN    ( QUEUE_HEAD_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             ),
        .ASSIGN_DELAY ( 0                        )
    ) head_pointer_master (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_master_module head_pointer_master_inst (
        .control    ( head_pointer_master   ),
        .o          ( queue_head_pointer  )
    );

    AXIS_driver # (
        .DATA_BYTES  ( dequeue_notification.DATA_BYTES  ),
        .ID_WIDTH    ( dequeue_notification.ID_WIDTH    ),
        .DEST_WIDTH  ( dequeue_notification.DEST_WIDTH  ),
        .USER_WIDTH  ( dequeue_notification.USER_WIDTH  ),
        .ASSIGN_DELAY ( 0                               )
    ) dequeue_master (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_driver_module dequeue_master_inst (
        .control ( dequeue_master         ),
        .o       ( dequeue_notification )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_queue_states #(
        .NUM_PAGES               ( NUM_PAGES            ),
        .WORDS_PER_PAGE          ( WORDS_PER_PAGE       ),
        .BYTES_PER_WORD          ( VNP4_DATA_BYTES      ),
        .NUM_EGR_PORTS           ( NUM_EGR_PHYS_PORTS   ),
        .MTU_BYTES               ( MTU_BYTES            )
    ) dut (
        .enqueue_queue_occupancy_a4l    ( cong_man_queue_occupancy    ),
        .queue_tail_pointer_a4l         ( queue_tail_pointer          ),
        .queue_head_pointer_a4l         ( queue_head_pointer          ),
        .dequeue_queue_occupancy_axis   ( dequeue_notification        ),
        .queue_empty                    ( dut_queue_empty             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: States Sim Model

    initial begin
        queue_empty = '1;
        page_fifo_init = '1;
        tail_page = '{default: -1};
        head_page = '{default: -1};
        for (int i = 0; i < NUM_PAGES; i++) begin
            free_page_queue.push_back(i);
        end
    end

    always_comb begin
        for (int q=0; q<NUM_QUEUES; q++) begin
            blen_queue_front[q] = blen_queue[q][0];
            head_page[q] = page_fifo[q][0];
            page_fifo_size[q] = page_fifo[q].size();
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Scheduler Sim Model

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH || !sched_enable) begin
            dq_pkt_cnt <= 0;
            egr_port_sel <= 0;
            pkt_dq_in_progress <= '{default: '0};
        end else begin
            if (egr_port_sel < NUM_EGR_PHYS_PORTS) begin
                if (~&dut_queue_empty[egr_port_sel*NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT]) begin
                    if (pkt_dq_in_progress[egr_port_sel]) begin
                        dequeue_word({egr_port_sel, dq_in_progress_queue[egr_port_sel][NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}, pkt_last_word);
                    end else begin
                        for (int prio=NUM_QUEUES_PER_EGR_PORT-1; prio >= 0; prio--) begin
                            if (~queue_empty[{egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}]) begin
                                dequeue_word({egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}, pkt_last_word);
                                dq_in_progress_queue[egr_port_sel] <= prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0];
                                pkt_dq_in_progress[egr_port_sel] <= 1'b1;
                                break;
                            end
                        end
                    end
                    if (pkt_last_word) begin
                        dq_pkt_cnt++;
                        pkt_dq_in_progress[egr_port_sel] <= 1'b0;
                    end
                end
            end
            if (egr_port_sel >= 31) begin
                egr_port_sel = 0;
            end else begin
                egr_port_sel <= egr_port_sel + 1;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Tasks

    task enqueue_packet(
        input int byte_length,
        input int queue
    );
        automatic int word_length = U_INT_CEIL_DIV(byte_length, VNP4_DATA_BYTES);
        automatic logic [QUEUE_OCC_DATALEN] occupancy;
        automatic logic [QUEUE_OCC_DATALEN] occupancy_sample;
        automatic queue_tail_pointer_read_t tail_ptr_rd;
        automatic queue_tail_pointer_write_t tail_ptr_wr;
        automatic bit malloc_approved = 1'b0;
        automatic int page_fifo_last;
        automatic int new_page;
        automatic int new_tail_ptr;
        automatic int resp;
        automatic string err_str;
        $sformat(err_str, "Queue: %d, Byte Lenght: %d", queue, byte_length);

        // Read Queue Occupancy and Tail Pointer and Compare to Expected
        fork
            begin
                queue_occupancy_enqueue_master.read_data(
                    .addr( queue     ),
                    .data( occupancy ),
                    .resp( resp      ));
                # 1;
                `CHECK_EQUAL(occupancy, occupancy_sample, err_str);
            end
            begin
                while(!cong_man_queue_occupancy.arvalid) begin
                    @(posedge core_clk_ifc.clk);
                end
                occupancy_sample = queue_occupancies[queue];
            end
            begin
                tail_pointer_master.read_data(
                    .addr( queue        ),
                    .data( tail_ptr_rd  ),
                    .resp( resp         ));
                `CHECK_EQUAL(tail_ptr_rd.tail_ptr, tail_ptrs[queue], err_str);
                if (page_fifo_init[queue]) begin
                    `CHECK_EQUAL(page_fifo[queue].size(), 0, err_str);
                end else begin
                    `CHECK_GREATER(page_fifo[queue].size(), 0, err_str);
                    page_fifo_last = page_fifo[queue].pop_back();
                    `CHECK_NOT_EQUAL(tail_ptr_rd.current_page_valid , page_fifo_init[queue], err_str);
                    `CHECK_EQUAL(tail_ptr_rd.current_page_ptr, page_fifo_last, err_str);
                    page_fifo[queue].push_back(page_fifo_last);
                end
            end
        join

        // Generate Responses
        if (tail_ptrs[queue] + word_length >= WORDS_PER_PAGE) begin
            new_tail_ptr += word_length - WORDS_PER_PAGE;
        end else begin
            new_tail_ptr += word_length;
        end

        if (tail_ptrs[queue] + word_length >= WORDS_PER_PAGE || page_fifo_init[queue]) begin
            `CHECK_GREATER(free_page_queue.size(), 0, {"Allocated a page but there weren't any avaiable.", err_str});
            new_page = free_page_queue.pop_front();
            malloc_approved = 1'b1;
        end

        // Simulate Congestion Manager's Latency
        repeat (2) @(posedge core_clk_ifc.clk);

        // Update the DUT and Model
        fork
            begin
                queue_occupancy_enqueue_master.write_data(
                    .addr ( queue       ),
                    .data ( byte_length ),
                    .resp ( resp        ));
            end
            begin
                while(!cong_man_queue_occupancy.wvalid) begin
                    @(posedge core_clk_ifc.clk);
                end
                queue_empty[queue] = 1'b0;
                page_fifo_init[queue] = 1'b0;
                queue_occupancies[queue] += byte_length;
                blen_queue[queue].push_back(byte_length);
            end

            begin
                tail_ptr_wr.new_tail_ptr    = (tail_ptr_rd.tail_ptr + word_length) % WORDS_PER_PAGE;
                tail_ptr_wr.next_page_ptr   = new_page;
                tail_ptr_wr.malloc_approved = malloc_approved;
                tail_pointer_master.write_data(
                    .addr ( queue       ),
                    .data ( tail_ptr_wr ),
                    .resp ( resp        ));
            end
            begin
                while(!queue_tail_pointer.wvalid) begin
                    @(posedge core_clk_ifc.clk);
                end
                tail_ptrs[queue] += new_tail_ptr;
                if (malloc_approved) begin
                    page_fifo[queue].push_back(new_page);
                    tail_page[queue] = new_page;
                end
            end
        join

    endtask

    task dequeue_word(
        input int queue,
        output bit pkt_last_word
    );
        automatic logic [dequeue_notification.DATA_BYTES*8-1:0] dequeue_data_queue [$];
        automatic int resp;
        automatic string err_str;
        automatic int head_ptr_sample;
        automatic int page_ptr_sample;
        $sformat(err_str, "Queue: %d", queue);

        `CHECK_EQUAL(queue_empty[queue], 1'b0, {"Attempted to dequeue from an empty queue.", err_str});

        // Dequeue a Full Word or EoP Partial Word
        if (blen_queue[queue][0] > VNP4_DATA_BYTES) begin
            dq_blen = VNP4_DATA_BYTES;
            blen_queue[queue][0] -= VNP4_DATA_BYTES;
            pkt_last_word = 1'b0;
        end else begin
            dq_blen = blen_queue[queue].pop_front();
            pkt_last_word = 1'b1;
        end
        $sformat(err_str, "Queue: %d, blen: %d", queue, dq_blen);

        // Read Head Pointer and Compare with Expected
        head_ptr_sample = head_ptrs[queue];
        page_ptr_sample = page_fifo[queue][0];
        fork
            begin
                head_pointer_master.read_data(
                    .addr( queue        ),
                    .data( head_ptr_rd  ),
                    .resp( resp         ));
                `CHECK_EQUAL(head_ptr_rd.head_ptr, head_ptr_sample, err_str);
                `CHECK_EQUAL(head_ptr_rd.page_ptr, page_ptr_sample, err_str);
            end
            begin
                while(!queue_head_pointer.arvalid) begin
                    @(posedge core_clk_ifc.clk);
                end
                if (head_ptrs[queue] == WORDS_PER_PAGE-1) begin
                    `CHECK_GREATER(page_fifo[queue].size(), 0, {"Attempted to free a page when none were allocated.", err_str});
                    page_fifo[queue].pop_front();
                end
                if (head_ptrs[queue] == WORDS_PER_PAGE-1) begin
                    head_ptrs[queue] = 0;
                end else begin
                    head_ptrs[queue]++;
                end
                if (queue_occupancies[queue] == dq_blen) begin
                    queue_empty[queue] = 1'b1;
                end
            end
        join

        // Submit Dequeue Notification
        fork
            begin
                dequeue_data_queue.push_back(dq_blen);
                dequeue_master.write_queue (
                    .input_data ( dequeue_data_queue ),
                    .user       ( queue              ),
                    .send_tlast ( pkt_last_word      ));
                @(posedge core_clk_ifc.clk);
                `CHECK_EQUAL(queue_empty, dut_queue_empty, err_str);
            end
            begin
                while(!dequeue_notification.tvalid) begin
                    @(posedge core_clk_ifc.clk);
                end
                queue_occupancies[queue] -= dq_blen;
                `CHECK_GREATER(queue_occupancies[queue], -1);
            end
        join
    endtask

    task enqueue_fast_test(
        input int num_queues_to_enqueue
    );

        automatic int pkt_blen;
        automatic int pkt_wlen;
        automatic int base_queue = $urandom_range(0, NUM_QUEUES - num_queues_to_enqueue);

        num_packets_to_send = 100 * num_queues_to_enqueue;

        for (int pkt=0; pkt<num_packets_to_send; pkt++ ) begin
            timer = 0;
            fork
                begin : timer_thread
                    while (1'b1) begin
                        @(posedge core_clk_ifc.clk);
                        timer++;
                    end
                end
                begin
                    pkt_blen = $urandom_range(PACKET_MIN_BLEN,PACKET_MAX_BLEN);
                    pkt_wlen = U_INT_CEIL_DIV(pkt_blen, VNP4_DATA_BYTES);
                    enqueue_packet(pkt_blen, base_queue + $urandom() % num_queues_to_enqueue);
                    while (timer < pkt_wlen) begin
                        @(posedge core_clk_ifc.clk);
                    end
                    disable timer_thread;
                end
            join
        end

        wait (&queue_empty);
        repeat (4) @(posedge core_clk_ifc.clk);

        `CHECK_EQUAL(dq_pkt_cnt, num_packets_to_send);

    endtask

    task enqueue_slow_test(
        input int num_queues_to_enqueue
    );

        localparam int MAX_WAIT_TIME = MTU_BYTES * 6.4 / CORE_CLK_PERIOD; // One MTU at 1Gbps
        automatic int pkt_blen;
        automatic int rand_time;
        automatic int base_queue = $uramdom_range(0, NUM_QUEUES - num_queues_to_enqueue);

        num_packets_to_send = 100000;

        for (int pkt=0; pkt<num_packets_to_send; pkt++ ) begin
            timer = 0;
            fork
                begin : timer_thread
                    while (1'b1) begin
                        @(posedge core_clk_ifc.clk);
                        timer++;
                    end
                end
                begin
                    pkt_blen = $urandom_range(PACKET_MIN_BLEN,PACKET_MAX_BLEN);
                    enqueue_packet(pkt_blen,  base_queue + $urandom() % num_queues_to_enqueue);
                    rand_time = $urandom() % MAX_WAIT_TIME;
                    while (timer < rand_time) begin
                        @(posedge core_clk_ifc.clk);
                    end
                    disable timer_thread;
                end
            join
        end

        wait (&queue_empty);
        repeat (4) @(posedge core_clk_ifc.clk);

        `CHECK_EQUAL(dq_pkt_cnt, num_packets_to_send);

    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            core_clk_ifc.clk        <= 1'b0;
            queue_occupancy_enqueue_master.W_MAX_RESPONSE_TIME = -1;
            queue_occupancy_enqueue_master.R_MAX_RESPONSE_TIME = -1;
            tail_pointer_master.W_MAX_RESPONSE_TIME    = -1;
            tail_pointer_master.R_MAX_RESPONSE_TIME    = -1;
            head_pointer_master.W_MAX_RESPONSE_TIME    = -1;
            head_pointer_master.R_MAX_RESPONSE_TIME    = -1;
        end

        `TEST_CASE_SETUP begin

            num_packets_to_send = 0;
            sched_enable = 1'b1;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

        end

        `TEST_CASE("enqueue_one_queue_fast") begin
            enqueue_fast_test(1);
        end

        `TEST_CASE("enqueue_one_queue_slow") begin
            enqueue_slow_test(1);
        end

        `TEST_CASE("enqueue_two_queues_fast") begin
            enqueue_fast_test(2);
        end

        `TEST_CASE("enqueue_two_queues_slow") begin
            enqueue_slow_test(2);
        end

        `TEST_CASE("enqueue_all_queues_fast") begin
            enqueue_fast_test(NUM_QUEUES);
        end

        `TEST_CASE("enqueue_all_queues_slow") begin
            enqueue_slow_test(NUM_QUEUES);
        end

        `TEST_CASE("queue_empty_race_condition") begin

            automatic int queue = 0;
            automatic int pkt_blen;
            automatic bit last;
            num_packets_to_send = 100;
            sched_enable = 1'b0;
            pkt_blen = VNP4_DATA_BYTES;

            fork
                begin
                    for (int pkt=0; pkt<num_packets_to_send; pkt++) begin
                        // while (queue_empty[queue] || !(queue_tail_pointer.arvalid || pkt == num_packets_to_send-1)) begin
                        //     @(posedge core_clk_ifc.clk);
                        // end
                        @(posedge core_clk_ifc.clk && !queue_empty[queue] && (queue_tail_pointer.arvalid || pkt == num_packets_to_send-1));
                        repeat ($urandom % 5) @(posedge core_clk_ifc.clk);
                        dequeue_word(queue, last);
                    end
                end
                begin
                    for (int pkt=0; pkt<num_packets_to_send; pkt++) begin
                        enqueue_packet(pkt_blen, queue);
                        repeat (8) @(posedge core_clk_ifc.clk);
                    end
                end
            join

            wait (&queue_empty);
            repeat (4) @(posedge core_clk_ifc.clk);
        end
    end

    `WATCHDOG(1000ms);
endmodule
