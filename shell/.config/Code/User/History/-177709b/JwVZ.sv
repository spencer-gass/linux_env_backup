// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for p4_router_congestion_manager
 */

module p4_router_congestion_manager_tb();

    parameter int NUM_ING_PHYS_PORTS = 11;
    parameter int NUM_EGR_PHYS_PORTS = 11;

    parameter int QUEUE_MEM_URAM_DEPTH = 8;
    parameter int MTU_BYTES = 1500;
    parameter int PACKET_MAX_BLEN = MTU_BYTES;
    parameter int PACKET_MIN_BLEN = 64;
    parameter int VNP4_DATA_BYTES = 64;
    parameter int BYTES_PER_PAGE = 4096;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int WORDS_PER_URAM = 4096;
    localparam int QUEUE_MEM_TOTAL_BYTES = WORDS_PER_URAM * QUEUE_MEM_URAM_DEPTH * VNP4_DATA_BYTES;
    localparam int QUEUE_MEM_TOTAL_BYTES_LOG = $clog2(QUEUE_MEM_TOTAL_BYTES);
    localparam int NUM_PAGES = QUEUE_MEM_TOTAL_BYTES / BYTES_PER_PAGE;
    localparam int NUM_PAGES_LOG = $clog2(NUM_PAGES);
    localparam int NUM_QUEUES = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int NUM_PAGES_LOG_BYTES = U_INT_CEIL_DIV(NUM_PAGES_LOG, 8);
    localparam int MAX_QUEUE_OCCUPANCY = QUEUE_MEM_TOTAL_BYTES;
    localparam int WORDS_PER_PAGE = BYTES_PER_PAGE / VNP4_DATA_BYTES;

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);
    localparam int MAX_PKT_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, VNP4_DATA_BYTES);
    localparam int VNP4_DATA_BYTES_LOG = $clog2(VNP4_DATA_BYTES);
    localparam int AVERAGE_PKT_BLEN = (PACKET_MAX_BLEN+PACKET_MIN_BLEN)/2;

    localparam int QUEUE_OCC_DATALEN = 2**$clog2(QUEUE_MEM_TOTAL_BYTES_LOG);
    localparam int DROP_THRESH_TABLE_DATALEN = 32;
    localparam int DROP_THRESH_TABLE_ADDRLEN = NUM_QUEUES_LOG;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces

    int                     send_packet_byte_length;
    logic [MTU_BYTES*8-1:0] send_packet_data;
    policer_metadata_t      send_packet_user;
    logic                   send_packet_req;
    logic                   send_packet_busy;
    int                     send_packet_count;

    logic [NUM_PAGES_LOG:0] num_free_pages;

    policer_metadata_t  send_packet_metadata_queue [$];
    logic [QUEUE_OCC_DATALEN-1:0] occupancy_rd_queue [$];
    logic [QUEUE_OCC_DATALEN-1:0] expected_occupancy_wr_queue [$];
    queue_tail_pointer_read_t tail_pointer_rd_queue [$];
    queue_tail_pointer_write_t expected_tail_pointer_wr_queue [$];
    logic [NUM_PAGES_LOG-1:0] malloc_rd_queue [$];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: clocks and resets

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) avmm_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) peripheral_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) interconnect_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS interfaces

    AXIS_int #(
        .USER_WIDTH ( POLICER_METADATA_WIDTH   ),
        .DATA_BYTES ( VNP4_DATA_BYTES               )
    ) dut_packet_in (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( CONG_MAN_METADATA_WIDTH  ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_packet_out (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES         ( NUM_PAGES_LOG_BYTES  ),
        .ALLOW_BACKPRESSURE ( 0              )
    ) queue_mem_alloc (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite interfaces

    AXI4Lite_int #(
        .DATALEN    ( DROP_THRESH_TABLE_DATALEN ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH       )
    ) table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_OCC_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG    )
    ) cong_man_queue_occupancy (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             )
    ) queue_tail_pointer (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    //////////////////////////////////////////////////////////////////////////
    // Logic implemenatation

    // simulation clock
    always #(AVMM_CLK_PERIOD/2)      avmm_clk_ifc.clk <= ~avmm_clk_ifc.clk;
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet generators

    axis_packet_generator
    #(
        .MTU_BYTES (MTU_BYTES)
    ) packet_generator (
        .axis_packet_out     (dut_packet_in),
        .busy                (send_packet_busy),
        .send_packet_req     (send_packet_req),
        .packet_byte_length  (send_packet_byte_length),
        .packet_user         (send_packet_user),
        .packet_data         (send_packet_data)
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue State Model

    AXI4Lite_slave #(
        .DATALEN    ( QUEUE_OCC_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG    )
    ) queue_occupancy_model (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_slave_module queue_occupancy_model_inst (
        .control    ( queue_occupancy_model      ),
        .i          ( cong_man_queue_occupancy  )
    );

    AXI4Lite_slave #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             )
    ) tail_pointer_model (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_slave_module tail_pointer_slave_inst (
        .control    ( tail_pointer_model   ),
        .i          ( queue_tail_pointer  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MMU model

    AXIS_driver # (
        .DATA_BYTES  ( queue_mem_alloc.DATA_BYTES  ),
        .ID_WIDTH    ( queue_mem_alloc.ID_WIDTH    ),
        .DEST_WIDTH  ( queue_mem_alloc.DEST_WIDTH  ),
        .USER_WIDTH  ( queue_mem_alloc.USER_WIDTH  ),
        .X_WHEN_IDLE ( 0                           )
    ) malloc_model (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_driver_module malloc_model_inst (
        .control (malloc_model),
        .o ( queue_mem_alloc )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Table Config

    AXI4Lite_master #(
        .DATALEN    ( DROP_THRESH_TABLE_DATALEN ),
        .ADDRLEN    ( DROP_THRESH_TABLE_ADDRLEN )
    ) table_config_master (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_master_module table_config_model_inst (
        .control    ( table_config_master        ),
        .o          ( table_config )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_congestion_manager #(
        .NUM_PAGES                  ( NUM_PAGES                 ),
        .BYTES_PER_PAGE             ( BYTES_PER_PAGE            ),
        .MAX_BYTES_PER_QUEUE        ( QUEUE_MEM_TOTAL_BYTES     ),
        .NUM_EGR_PORTS              ( NUM_EGR_PHYS_PORTS        ),
        .MTU_BYTES                  ( MTU_BYTES                 )
    ) dut (
        .packet_in              ( dut_packet_in             ),
        .table_config           ( table_config  ),
        .queue_occupancy_a4l    ( cong_man_queue_occupancy  ),
        .queue_tail_pointer_a4l ( queue_tail_pointer        ),
        .queue_malloc_axis      ( queue_mem_alloc           ),
        .packet_out             ( dut_packet_out            ),
        .num_free_pages         ( num_free_pages            )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sinks & Data Validation

    assign dut_packet_out.tready = dut_packet_out.sresetn;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input policer_metadata_t send_packet_metadata,
        input int payload_type
    ); begin

        send_packet_byte_length = send_packet_metadata.byte_length[MTU_BYTES_LOG-1:0];
        send_packet_user        = send_packet_metadata;

        // Wait till we can send data
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
        axis_packet_formatter #( VNP4_DATA_BYTES,  MAX_PKT_WLEN , MTU_BYTES)::get_packet(payload_type, send_packet_metadata.byte_length[MTU_BYTES_LOG-1:0], send_packet_data);
        #0
        send_packet_req = 1'b1;
        // Wait till its received
        while(!send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_req = 1'b0;
        // Wait till its finished
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_count++;
    end
    endtask;

    task write_drop_thresh_table(
        input int queue,
        input int drop_threshold
    );
        automatic logic [1:0] resp;

        table_config_master.write_data(
            .addr ( queue           ),
            .data ( drop_threshold  ),
            .resp ( resp            )
        );
    endtask

    task run_test(
        input policer_metadata_t send_packet_metadata [$],
        input logic [QUEUE_OCC_DATALEN-1:0] occupancy_rd [$],
        input logic [QUEUE_OCC_DATALEN-1:0] expected_occupancy_wr [$],
        input queue_tail_pointer_read_t tail_pointer_rd [$],
        input queue_tail_pointer_write_t expected_tail_pointer_wr [$],
        input logic [NUM_PAGES_LOG_BYTES*8-1:0] malloc_rd [$],
        input logic [NUM_PAGES_LOG:0] num_free_pages_start
    );

        automatic bit test_complete = 1'b0;

        fork
            begin
                while (
                    send_packet_metadata.size() ||
                    occupancy_rd.size() ||
                    expected_occupancy_wr.size() ||
                    tail_pointer_rd.size() ||
                    expected_tail_pointer_wr.size() ||
                    malloc_rd.size()
                ) begin
                    @(posedge core_clk_ifc.clk);
                end
                test_complete = 1'b1;
            end

            begin // Send Packets
                while(send_packet_metadata.size()) begin
                    send_packet(
                        .send_packet_metadata ( send_packet_metadata.pop_front() ),
                        .payload_type         ( RAND                       )
                    );
                end
                $display("Send Packets Completed");
            end

            begin // Queue Occupancy Read Model
                automatic logic [NUM_QUEUES_LOG-1:0] addr;
                while (occupancy_rd.size()) begin
                    queue_occupancy_model.begin_read_response(addr);
                    queue_occupancy_model.end_read_response(occupancy_rd.pop_front(), cong_man_queue_occupancy.OKAY);
                end
                $display("Read Occ Completed");
            end

            begin // Queue Occupancy Write Model
                automatic logic [NUM_QUEUES_LOG-1:0] addr;
                automatic logic [QUEUE_OCC_DATALEN-1:0] enqueues_bytes = '0;
                while (expected_occupancy_wr.size()) begin
                    queue_occupancy_model.begin_write_response(addr, enqueues_bytes);
                    queue_occupancy_model.end_write_response(cong_man_queue_occupancy.OKAY);
                    `CHECK_EQUAL(enqueues_bytes, expected_occupancy_wr.pop_front());
                end
                $display("Write Occ Completed");
            end

            begin // Tail Pointer Read Model
                automatic logic [NUM_QUEUES_LOG-1:0] addr;
                automatic queue_tail_pointer_read_t ptr_rd = '{default: '0};
                while (tail_pointer_rd.size()) begin
                    tail_pointer_model.begin_read_response(addr);
                    tail_pointer_model.end_read_response(tail_pointer_rd.pop_front(), queue_tail_pointer.OKAY);
                end
                $display("Tail Pointer Read Completed");
            end

            begin // Tail Pointer Write Model
                automatic logic [NUM_QUEUES_LOG-1:0] addr;
                automatic queue_tail_pointer_write_t ptr_wr = '{default: '0};
                automatic queue_tail_pointer_write_t expected_ptr_wr = '{default: '0};
                while (expected_tail_pointer_wr.size()) begin
                    tail_pointer_model.begin_write_response(addr, ptr_wr);
                    tail_pointer_model.end_write_response(queue_tail_pointer.OKAY);
                    expected_ptr_wr = expected_tail_pointer_wr.pop_front();
                    `CHECK_EQUAL(ptr_wr.new_tail_ptr,    expected_ptr_wr.new_tail_ptr);
                    `CHECK_EQUAL(ptr_wr.malloc_approved, expected_ptr_wr.malloc_approved);
                    if (ptr_wr.malloc_approved) begin
                        `CHECK_EQUAL(ptr_wr.next_page_ptr,   expected_ptr_wr.next_page_ptr);
                    end
                end
                $display("Tail Pointer Write Completed");
            end

            begin // MMU model
                if (malloc_rd.size()) begin
                    malloc_model.write_queue(malloc_rd);
                    malloc_rd.delete();
                end
                $display("Malloc Completed");
            end

            begin
                num_free_pages = num_free_pages_start;
                while (!test_complete) begin
                    @(posedge core_clk_ifc.clk);
                    if (queue_mem_alloc.tready && queue_mem_alloc.tvalid) begin
                        num_free_pages <= num_free_pages - 1;
                    end
                end
                $display("Free Pages Competed");
            end

        join
    endtask

    task smoke_test(
        input bit empty0_rand1
    );
        automatic bit valid_seen = 1'b1;
        automatic policer_metadata_t metadata;
        automatic queue_tail_pointer_read_t tail_pointer_rd;
        automatic queue_tail_pointer_write_t tail_pointer_wr;
        automatic int drop_threshold = QUEUE_MEM_TOTAL_BYTES/4;
        automatic int occupancy_rd;
        automatic bit malloc_required;
        automatic int malloc_count = 0;
        automatic int START_FREE_PAGES;

        localparam int NUM_PACKETS_TO_SEND = 1000;

        if (empty0_rand1) begin
            // Of the sent packets, 1/2 are queue droped.
            // an average sized packet would need a malloc with a porbability of pkt_blen/page_blen
            // packets start to get malloc dropped as pages run out so divide by some factor to
            // get to free pages to zero before the end of the sim.
            START_FREE_PAGES = NUM_PACKETS_TO_SEND/2 * AVERAGE_PKT_BLEN/BYTES_PER_PAGE / 4;
        end else begin
            START_FREE_PAGES = NUM_PAGES;
        end

        // Set drop thresholds
        for (int q=0; q<NUM_QUEUES; q++) begin
            write_drop_thresh_table(
                .queue              ( q              ),
                .drop_threshold     ( drop_threshold ));
        end

        for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
            // Define packet profile
            metadata.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
            do metadata.ingress_port = $urandom() % NUM_ING_PHYS_PORTS; while (metadata.ingress_port == metadata.egress_port);
            metadata.prio = $urandom();
            metadata.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
            metadata.policer_drop_mark = (($urandom() % 10) == 0) ? 1'b1 : 1'b0;
            send_packet_metadata_queue.push_back(metadata);

            // Define model behavior and expected DUT behavior
            if (empty0_rand1) begin
                // set 50% probability of queue-too-deep drop
                occupancy_rd = $urandom() % drop_threshold * 2;
                tail_pointer_rd.tail_ptr = $urandom() % WORDS_PER_PAGE;
                tail_pointer_rd.current_page_ptr = $urandom() % NUM_PAGES;
                tail_pointer_rd.current_page_valid = 1'b1;
            end else begin
                occupancy_rd = 0;
                tail_pointer_rd.tail_ptr = 0;
                tail_pointer_rd.current_page_ptr = 0;
                tail_pointer_rd.current_page_valid = 1'b0;
            end
            occupancy_rd_queue.push_back(occupancy_rd);
            tail_pointer_rd_queue.push_back(tail_pointer_rd);

            if (!tail_pointer_rd.current_page_valid || (tail_pointer_rd.tail_ptr + U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES)) >= WORDS_PER_PAGE) begin
                malloc_required = 1'b1;
            end else begin
                malloc_required = 1'b0;
            end

            if (metadata.byte_length + occupancy_rd > drop_threshold) begin
                $display("Drop packet %d blen %d. queue occupancy %d > threshold %d. policer drop_mark %d", pkt, metadata.byte_length, occupancy_rd, drop_threshold, metadata.policer_drop_mark);
            end else if (metadata.policer_drop_mark && metadata.prio < 6) begin
                $display("Drop packet %d blen %d. queue occupancy %d > threshold %d. policer drop_mark %d", pkt, metadata.byte_length, occupancy_rd, drop_threshold, metadata.policer_drop_mark);
            end else if (malloc_required && occupancy_rd/BYTES_PER_PAGE > START_FREE_PAGES - malloc_count) begin
                $display("Drop packet %d blen %d. queue occupancy in pages %d > free page count %d", pkt, metadata.byte_length, (metadata.byte_length + occupancy_rd)/BYTES_PER_PAGE, START_FREE_PAGES - malloc_count);
            end else if (malloc_required && START_FREE_PAGES - malloc_count < 1) begin
                $display("Drop packet %d blen %d. no pages avalable to malloc", pkt, metadata.byte_length);
            end else begin
                expected_occupancy_wr_queue.push_back(metadata.byte_length);
                tail_pointer_wr.new_tail_ptr = (tail_pointer_rd.tail_ptr + U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES)) % WORDS_PER_PAGE;
                tail_pointer_wr.next_page_ptr = malloc_count;
                if (malloc_required) begin
                    $display("Enqueue packet %d blen %d malloc page %d", pkt, metadata.byte_length, malloc_count);
                    tail_pointer_wr.malloc_approved = 1'b1;
                    malloc_rd_queue.push_back(malloc_count);
                    malloc_count++;
                end else begin
                    $display("Enqueue packet %d blen %d", pkt, metadata.byte_length);
                    tail_pointer_wr.malloc_approved = 1'b0;
                end
                expected_tail_pointer_wr_queue.push_back(tail_pointer_wr);
            end
        end

        // Test task
        run_test(
            .send_packet_metadata     ( send_packet_metadata_queue     ),
            .occupancy_rd             ( occupancy_rd_queue             ),
            .expected_occupancy_wr    ( expected_occupancy_wr_queue    ),
            .tail_pointer_rd          ( tail_pointer_rd_queue          ),
            .expected_tail_pointer_wr ( expected_tail_pointer_wr_queue ),
            .malloc_rd                ( malloc_rd_queue                ),
            .num_free_pages_start     ( START_FREE_PAGES               )
        );

        // Wait for all the packets to be received
        while (valid_seen) begin
            valid_seen = 1'b0;
            for (integer i=0; i<64; i++) begin
                @(posedge core_clk_ifc.clk);
                valid_seen |= dut_packet_out.tvalid;
            end
        end
    endtask

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk        <= 1'b0;
            core_clk_ifc.clk        <= 1'b0;
            send_packet_req         <= 1'b0;
            send_packet_count       <= 0;
            queue_occupancy_model.W_MAX_RESPONSE_TIME = -1;
            queue_occupancy_model.R_MAX_RESPONSE_TIME = -1;
            tail_pointer_model.W_MAX_RESPONSE_TIME    = -1;
            tail_pointer_model.R_MAX_RESPONSE_TIME    = -1;
        end

        `TEST_CASE_SETUP begin

            occupancy_rd_queue.delete();
            expected_occupancy_wr_queue.delete();
            tail_pointer_rd_queue.delete();
            expected_tail_pointer_wr_queue.delete();
            malloc_rd_queue.delete();

            interconnect_sreset_ifc.reset = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = peripheral_sreset_ifc.ACTIVE_HIGH;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = ~peripheral_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

        end

        `TEST_CASE("smoke_test_empty_queues") begin
            smoke_test(0);
        end

        `TEST_CASE("smoke_test_nonempty_queues") begin
            smoke_test(1);
        end

        `TEST_CASE("policer_drop_test") begin
            automatic bit valid_seen = 1'b1;
            automatic policer_metadata_t metadata;
            automatic queue_tail_pointer_read_t tail_pointer_rd;
            automatic queue_tail_pointer_write_t tail_pointer_wr;
            automatic int occupancy_rd;
            automatic bit malloc_required;
            automatic int malloc_count = 0;
            automatic int START_FREE_PAGES = NUM_PAGES;

            localparam int NUM_PACKETS_TO_SEND = 1000;

            // Use default drop thresholds

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                do metadata.ingress_port = $urandom() % NUM_ING_PHYS_PORTS; while (metadata.ingress_port == metadata.egress_port);
                metadata.prio = $urandom();
                metadata.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                metadata.policer_drop_mark = $urandom() % 2;
                send_packet_metadata_queue.push_back(metadata);

                // Define model behavior and expected DUT behavior
                occupancy_rd = 0;
                tail_pointer_rd.tail_ptr = 0;
                tail_pointer_rd.current_page_ptr = 0;
                tail_pointer_rd.current_page_valid = 1'b1;
                occupancy_rd_queue.push_back(occupancy_rd);
                tail_pointer_rd_queue.push_back(tail_pointer_rd);

                malloc_required = 1'b0;

                if (!metadata.policer_drop_mark || metadata.prio > 5) begin
                    expected_occupancy_wr_queue.push_back(metadata.byte_length);
                    tail_pointer_wr.new_tail_ptr = (tail_pointer_rd.tail_ptr + U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES)) % WORDS_PER_PAGE;
                    tail_pointer_wr.next_page_ptr = malloc_count;
                    if (malloc_required) begin
                        $display("Enqueue packet %d blen %d malloc page %d", pkt, metadata.byte_length, malloc_count);
                        tail_pointer_wr.malloc_approved = 1'b1;
                        malloc_rd_queue.push_back(malloc_count);
                        malloc_count++;
                    end else begin
                        $display("Enqueue packet %d blen %d", pkt, metadata.byte_length);
                        tail_pointer_wr.malloc_approved = 1'b0;
                    end
                    expected_tail_pointer_wr_queue.push_back(tail_pointer_wr);
                end
            end

            // Test task
            run_test(
                .send_packet_metadata     ( send_packet_metadata_queue     ),
                .occupancy_rd             ( occupancy_rd_queue             ),
                .expected_occupancy_wr    ( expected_occupancy_wr_queue    ),
                .tail_pointer_rd          ( tail_pointer_rd_queue          ),
                .expected_tail_pointer_wr ( expected_tail_pointer_wr_queue ),
                .malloc_rd                ( malloc_rd_queue                ),
                .num_free_pages_start     ( START_FREE_PAGES               )
            );

            // Wait for all the packets to be received
            while (valid_seen) begin
                valid_seen = 1'b0;
                for (integer i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    valid_seen |= dut_packet_out.tvalid;
                end
            end
        end

        `TEST_CASE("queue_full_drop_tests") begin
            /*
            Set queue 0 and 1 to have different drop thresholds
            Send two packets to queue 0 one just below and one just above the threshold
            Send two packets to queue 1 one just below and one just above the threshold
            */

            automatic bit valid_seen = 1'b1;
            automatic policer_metadata_t metadata;
            automatic queue_tail_pointer_read_t tail_pointer_rd;
            automatic queue_tail_pointer_write_t tail_pointer_wr;
            automatic int queue_0_drop_thresh = QUEUE_MEM_TOTAL_BYTES/4;
            automatic int queue_1_drop_thresh = QUEUE_MEM_TOTAL_BYTES/8;

            // Set drop thresholds
            write_drop_thresh_table(
                .queue              ( 0                     ),
                .drop_threshold     ( queue_0_drop_thresh  ));

            write_drop_thresh_table(
                .queue              ( 1                     ),
                .drop_threshold     ( queue_1_drop_thresh  ));


            for (int pkt=0; pkt<4; pkt++ ) begin
                // Define packet profile
                metadata.ingress_port = 1;
                metadata.egress_port = 0;
                metadata.prio = (pkt < 2) ? 0 : 5; // prio 4:0 map to queue 0
                metadata.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                metadata.policer_drop_mark = 1'b0;
                send_packet_metadata_queue.push_back(metadata);

                // Define model behavior and expected DUT behavior
                case (pkt % 4)
                    0 : occupancy_rd_queue.push_back(queue_0_drop_thresh - metadata.byte_length );     // queue 0 accept
                    1 : occupancy_rd_queue.push_back(queue_0_drop_thresh - metadata.byte_length + 1 ); // queue 0 drop
                    2 : occupancy_rd_queue.push_back(queue_1_drop_thresh - metadata.byte_length );     // queue 1 accept
                    3 : occupancy_rd_queue.push_back(queue_1_drop_thresh - metadata.byte_length + 1 ); // queue 1 drop
                    default : ;
                endcase

                if (pkt % 2 == 0) begin // only expect responses from packets that aren't dropped
                    expected_occupancy_wr_queue.push_back(metadata.byte_length);
                end

                tail_pointer_rd.tail_ptr = '0;
                tail_pointer_rd.current_page_ptr = '0;
                tail_pointer_rd.current_page_valid = 1'b1;
                tail_pointer_rd_queue.push_back(tail_pointer_rd);

                if (pkt % 2 == 0) begin // only expect responses from packets that aren't dropped
                    tail_pointer_wr.new_tail_ptr = U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES);
                    tail_pointer_wr.next_page_ptr = '0;
                    tail_pointer_wr.malloc_approved = 1'b0;
                    expected_tail_pointer_wr_queue.push_back(tail_pointer_wr);
                end

                // malloc_rd_queue.push_back(0);
            end

            // Test task
            run_test(
                .send_packet_metadata     ( send_packet_metadata_queue     ),
                .occupancy_rd             ( occupancy_rd_queue             ),
                .expected_occupancy_wr    ( expected_occupancy_wr_queue    ),
                .tail_pointer_rd          ( tail_pointer_rd_queue          ),
                .expected_tail_pointer_wr ( expected_tail_pointer_wr_queue ),
                .malloc_rd                ( malloc_rd_queue                ),
                .num_free_pages_start     ( NUM_PAGES                      )
            );

            // Give time for all the packets to be received
            while (valid_seen) begin
                valid_seen = 1'b0;
                for (integer i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    valid_seen |= dut_packet_out.tvalid;
                end
            end
        end

        `TEST_CASE("malloc_drop_tests") begin
            /*
            Set queue 0 and 1 to have different drop thresholds
            Send two packets to queue 0 one with free pages just below and one just above the allocation threshold
            Send two packets to queue 1 one with free pages just below and one just above the allocation threshold
            */

            automatic bit valid_seen = 1'b1;
            automatic policer_metadata_t metadata;
            automatic queue_tail_pointer_read_t tail_pointer_rd;
            automatic queue_tail_pointer_write_t tail_pointer_wr;
            automatic logic [NUM_PAGES_LOG:0] free_pages = NUM_PAGES/4;

            // Use default queue drop thresholds

            for (int pkt=0; pkt<4; pkt++ ) begin
                // Define packet profile
                metadata.ingress_port = 1;
                metadata.egress_port = 0;
                metadata.prio = (pkt < 2) ? 0 : 5; // prio 4:0 map to queue 0
                metadata.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                metadata.policer_drop_mark = 1'b0;
                send_packet_metadata_queue.push_back(metadata);
                if (pkt % 2 == 0) begin
                    occupancy_rd_queue.push_back(free_pages * BYTES_PER_PAGE - pkt/2); // accept
                    expected_occupancy_wr_queue.push_back(metadata.byte_length);
                end else begin
                    occupancy_rd_queue.push_back(free_pages * BYTES_PER_PAGE); // drop
                end

                tail_pointer_rd.tail_ptr = '1;
                tail_pointer_rd.current_page_ptr = '0;
                tail_pointer_rd.current_page_valid = 1'b1;
                tail_pointer_rd_queue.push_back(tail_pointer_rd);

                if (pkt % 2 == 0) begin // only expect responses from packets that aren't dropped
                    tail_pointer_wr.new_tail_ptr = U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES) - 1;
                    tail_pointer_wr.next_page_ptr = pkt+1;
                    tail_pointer_wr.malloc_approved = 1'b1;
                    expected_tail_pointer_wr_queue.push_back(tail_pointer_wr);
                    malloc_rd_queue.push_back(pkt+1);
                end

            end

            // Test task
            run_test(
                .send_packet_metadata     ( send_packet_metadata_queue     ),
                .occupancy_rd             ( occupancy_rd_queue             ),
                .expected_occupancy_wr    ( expected_occupancy_wr_queue    ),
                .tail_pointer_rd          ( tail_pointer_rd_queue          ),
                .expected_tail_pointer_wr ( expected_tail_pointer_wr_queue ),
                .malloc_rd                ( malloc_rd_queue                ),
                .num_free_pages_start     ( free_pages                     )
            );

            // Give time for all the packets to be received
            while (valid_seen) begin
                valid_seen = 1'b0;
                for (integer i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    valid_seen |= dut_packet_out.tvalid;
                end
            end
        end

        `TEST_CASE("mem_full_drop_tests") begin
            /*
            Send two packets to queue 0 one with one page left and the second with zero
            Should accept packet 1 and drop packet 2
            */

            automatic bit valid_seen = 1'b1;
            automatic policer_metadata_t metadata;
            automatic queue_tail_pointer_read_t tail_pointer_rd;
            automatic queue_tail_pointer_write_t tail_pointer_wr;
            automatic logic [NUM_PAGES_LOG:0] free_pages = 1;

            // Use default queue drop thresholds

            for (int pkt=0; pkt<2; pkt++ ) begin
                // Define packet profile
                metadata.ingress_port = 1;
                metadata.egress_port = 0;
                metadata.prio = 0;
                metadata.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                metadata.policer_drop_mark = 1'b0;
                send_packet_metadata_queue.push_back(metadata);
                occupancy_rd_queue.push_back(0); // accept
                if (pkt % 2 == 0) begin
                    expected_occupancy_wr_queue.push_back(metadata.byte_length);
                end

                tail_pointer_rd.tail_ptr = '1;
                tail_pointer_rd.current_page_ptr = '0;
                tail_pointer_rd.current_page_valid = 1'b1;
                tail_pointer_rd_queue.push_back(tail_pointer_rd);

                if (pkt % 2 == 0) begin // only expect responses from packets that aren't dropped
                    tail_pointer_wr.new_tail_ptr = U_INT_CEIL_DIV(metadata.byte_length, VNP4_DATA_BYTES) - 1;
                    tail_pointer_wr.next_page_ptr = 1;
                    tail_pointer_wr.malloc_approved = 1'b1;
                    expected_tail_pointer_wr_queue.push_back(tail_pointer_wr);
                    malloc_rd_queue.push_back(1);
                end

            end

            // Test task
            run_test(
                .send_packet_metadata     ( send_packet_metadata_queue     ),
                .occupancy_rd             ( occupancy_rd_queue             ),
                .expected_occupancy_wr    ( expected_occupancy_wr_queue    ),
                .tail_pointer_rd          ( tail_pointer_rd_queue          ),
                .expected_tail_pointer_wr ( expected_tail_pointer_wr_queue ),
                .malloc_rd                ( malloc_rd_queue                ),
                .num_free_pages_start     ( free_pages                     )
            );

            // Give time for all the packets to be received
            while (valid_seen) begin
                valid_seen = 1'b0;
                for (integer i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    valid_seen |= dut_packet_out.tvalid;
                end
            end
        end
    end

    `WATCHDOG(500us);

endmodule
