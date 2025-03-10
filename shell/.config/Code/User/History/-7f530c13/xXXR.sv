// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * System-level testbench for p4_router_queue_system
 */

module p4_router_queue_system_tb ();

    parameter int NUM_ING_PHYS_PORTS = 4;
    parameter int NUM_8B_EGR_PHYS_PORTS  = 1;
    parameter int NUM_16B_EGR_PHYS_PORTS = 1;
    parameter int NUM_32B_EGR_PHYS_PORTS = 1;
    parameter int NUM_64B_EGR_PHYS_PORTS = 1;

    parameter int QUEUE_MEM_URAM_DEPTH = 8;
    parameter int MTU_BYTES = 1500;
    parameter int PACKET_MAX_BLEN = MTU_BYTES;
    parameter int PACKET_MIN_BLEN = 64;
    parameter int VNP4_DATA_BYTES = 64;

    parameter int NUM_PACKETS_TO_SEND = 100;

    /////////////////////////////////////////////////////////////////////////
    // Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // Constants

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int NUM_EGR_PHYS_PORTS = NUM_8B_EGR_PHYS_PORTS + NUM_16B_EGR_PHYS_PORTS + NUM_32B_EGR_PHYS_PORTS + NUM_64B_EGR_PHYS_PORTS;
    localparam int NUM_QUEUES = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);
    localparam int MAX_PKT_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, VNP4_DATA_BYTES);
    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int VNP4_DATA_BYTES_LOG = $clog2(VNP4_DATA_BYTES);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces

    int                                     send_packet_byte_length;
    logic [0:MTU_BYTES*8-1]                 send_packet_data;
    vnp4_wrapper_metadata_t                 send_packet_user;
    logic                                   send_packet_req;
    logic                                   send_packet_req_d;
    logic                                   send_packet_busy;

    logic [0:MTU_BYTES*8-1]             tx_snoop_data_buf     [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf     [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0]  tx_snoop_egr_port_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr;

    logic [NUM_PACKETS_TO_SEND_LOG-1:0] expected_rx_pkt_cnts [NUM_EGR_PHYS_PORTS_LOG-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG-1:0] rx_pkt_cnts          [NUM_EGR_PHYS_PORTS_LOG-1:0];
    int                                 total_rx_pkts;

    vnp4_wrapper_metadata_t dut_in_metadata;
    queue_system_metadata_t dut_out_metadata;
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] dut_in_egr_port;
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] dut_out_egr_port;
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] dut_out_egr_port_d;

    logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_ready;

    logic [NUM_ING_PHYS_PORTS-1:0] ing_policer_enable;
    bucket_decrement_t             ing_policer_decrement       [NUM_ING_PHYS_PORTS-1:0];
    bucket_depth_threshold_t       ing_policer_depth_threshold [NUM_ING_PHYS_PORTS-1:0];

    logic pkt_cnt_clear = 1'b0;
    logic [63:0] qsys_in_pkt_cnt;
    logic [63:0] enqueue_pkt_cnt;
    logic [63:0] dequeue_pkt_cnt;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets

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
    // SUB-SECTION: AXIS Interfaces

    AXIS_int #(
        .USER_WIDTH ( VNP4_WRAPPER_METADATA_WIDTH   ),
        .DATA_BYTES ( VNP4_DATA_BYTES               )
    ) dut_packet_in (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( QUEUE_SYS_METADATA_WIDTH  ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_word_out (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interfaces

    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) cong_man_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) ing_policer_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_COUNTER_WIDTH    ),
        .ADDRLEN    ( QSYS_COUNTER_ID_WIDTH )
    ) cong_man_counter_access (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    //////////////////////////////////////////////////////////////////////////
    // Logic Implemenatation

    // Simulation Clock
    always #(AVMM_CLK_PERIOD/2)      avmm_clk_ifc.clk <= ~avmm_clk_ifc.clk;
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Generators

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
    // SUB-SECTION: Capture tx packets to use as expected packets for rx

    always_ff @(posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf       <= '{default: '0};
            tx_snoop_blen_buf       <= '{default: '0};
            tx_snoop_egr_port_buf   <= '{default: '0};
            tx_snoop_wr_ptr         <= '0;
            send_packet_req_d       <= 1'b0;
        end else begin
            send_packet_req_d <= send_packet_req;
            if (send_packet_req && !send_packet_req_d) begin
                tx_snoop_data_buf[tx_snoop_wr_ptr]      <= send_packet_data;
                tx_snoop_blen_buf[tx_snoop_wr_ptr]      <= send_packet_byte_length;
                tx_snoop_egr_port_buf[tx_snoop_wr_ptr]  <= send_packet_user.egress_port;
                tx_snoop_wr_ptr++;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit packet counters

    assign dut_in_metadata  = dut_packet_in.tuser;
    assign dut_in_egr_port  = dut_in_metadata.egress_port[NUM_EGR_PHYS_PORTS_LOG-1:0];

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            expected_rx_pkt_cnts = '{default: '0};
        end else begin
            if (dut_packet_in.tlast) begin
                expected_rx_pkt_cnts[dut_in_egr_port] <= expected_rx_pkt_cnts[dut_in_egr_port] + 1;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_queue_system #(
        .NUM_ING_PORTS          ( NUM_ING_PHYS_PORTS      ),
        .NUM_EGR_PORTS          ( NUM_EGR_PHYS_PORTS      ),
        .QUEUE_MEM_URAM_DEPTH   ( QUEUE_MEM_URAM_DEPTH    ),
        .MTU_BYTES              ( MTU_BYTES               )
    ) dut (
        .ing_policer_enable          ( ing_policer_enable          ),
        .ing_policer_table_config    ( ing_policer_table_config    ),
        .cong_man_table_config       ( cong_man_table_config       ),
        .cong_man_counter_access     ( cong_man_counter_access     ),
        .pkt_cnt_clear               ( pkt_cnt_clear   ),
        .qsys_in_pkt_cnt             ( qsys_in_pkt_cnt ),
        .enqueue_pkt_cnt             ( enqueue_pkt_cnt ),
        .dequeue_pkt_cnt             ( dequeue_pkt_cnt ),
        .packet_in                   ( dut_packet_in               ),
        .egr_buf_ready               ( egr_buf_ready               ),
        .word_out                    ( dut_word_out                )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sinks & Data Validation

    axis_packet_checker #(
        .PKT_ID_STRING              ( "Egress Port"        ),
        .NUM_PKT_IDS                ( NUM_EGR_PHYS_PORTS   ),
        .MTU_BYTES                  ( MTU_BYTES             ),
        .NUM_PACKETS_BEING_SENT     ( NUM_PACKETS_TO_SEND   )
    ) packet_checker (
        .axis_packet_in ( dut_word_out           ),
        .packet_in_id   ( dut_out_metadata.egress_port[NUM_EGR_PHYS_PORTS_LOG-1:0] ),
        .num_tx_pkts    ( tx_snoop_wr_ptr        ),
        .expected_pkts  ( tx_snoop_data_buf      ),
        .expected_blens ( tx_snoop_blen_buf      ),
        .expected_ids   ( tx_snoop_egr_port_buf  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress Buffer Ready Models

    generate
        for (genvar port=0; port<NUM_EGR_PHYS_PORTS; port++) begin
            always begin
                automatic string err_str;
                egr_buf_ready[port] = 1'b1;
                @(posedge core_clk_ifc.clk && dut_word_out.tvalid && dut_word_out.tuser === port);
                egr_buf_ready[port] = 1'b0;
                for (int i=0; i<8; i++) begin
                    @(posedge core_clk_ifc.clk);
                    #1;
                    $sformat(err_str, "Dequeued to port %d when it wasn't ready", port);
                    `CHECK_EQUAL(dut_word_out.tvalid && dut_word_out.tuser === port, 0, err_str);
                end
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Receive packet counter

    assign dut_out_metadata = dut_word_out.tuser;
    assign dut_out_egr_port = dut_out_metadata.egress_port[NUM_EGR_PHYS_PORTS_LOG-1:0];

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            rx_pkt_cnts = '{default: '0};
            total_rx_pkts <= 0;
        end else begin
            if (dut_word_out.tvalid && dut_word_out.tlast) begin
                rx_pkt_cnts[dut_out_egr_port] <= rx_pkt_cnts[dut_out_egr_port] + 1;
                total_rx_pkts <= total_rx_pkts + 1;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input int send_packet_ing_port,
        input int send_packet_egr_port,
        input int send_packet_prio,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length,
        input int payload_type
    ); begin

        send_packet_byte_length = packet_byte_length;

        send_packet_user.ingress_port   = send_packet_ing_port;
        send_packet_user.egress_port    = send_packet_egr_port;
        send_packet_user.prio           = send_packet_prio;
        send_packet_user.byte_length    = packet_byte_length;

        // Wait till we can send data
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_data = '0;
        axis_packet_formatter #( VNP4_DATA_BYTES,  MAX_PKT_WLEN , MTU_BYTES)::get_packet(payload_type, packet_byte_length, send_packet_data);
        #0
        send_packet_req = 1'b1;
        // Wait till its received
        while(!send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_req = 1'b0;
        // Wait till its finished
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
    end
    endtask;

    task send_pkts_to_rand_queues(
        input int num_queues_to_enqueue,
        input bit enqueue_fast = 1,
        input int packet_size = -1
    );

            automatic int expected_total_packets = NUM_PACKETS_TO_SEND;
            automatic bit valid_seen = 1'b1;
            automatic int ingress_port;
            automatic int egress_port;
            automatic int prio;
            automatic int queue;
            automatic int pkt_blen;
            automatic int inter_pkt_wait_time;

            // Send packets to all interfacess in parallel
            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                queue = $urandom() % num_queues_to_enqueue;
                egress_port = queue[NUM_QUEUES_PER_EGR_PORT_LOG +: NUM_EGR_PHYS_PORTS_LOG];
                prio = queue_to_prio(queue[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]);
                do ingress_port = $urandom() % NUM_ING_PHYS_PORTS; while (egress_port == ingress_port);
                if (packet_size == -1) begin
                    pkt_blen = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                end else begin
                    pkt_blen = packet_size;
                end
                send_packet (
                    .send_packet_ing_port   ( ingress_port  ),
                    .send_packet_egr_port   ( egress_port   ),
                    .send_packet_prio       ( prio          ),
                    .packet_byte_length     ( pkt_blen      ),
                    .payload_type           ( RAND          )
                );
                if (!enqueue_fast) begin // enqueue at 1Gbps per ingress interface
                    inter_pkt_wait_time = pkt_blen * 6.4 / CORE_CLK_PERIOD / NUM_ING_PHYS_PORTS;
                    repeat (inter_pkt_wait_time) @(posedge core_clk_ifc.clk);
                end
                // Else enqueue as fast as possible. May be higher rate than the ingress ports can produce.
            end

            // Give time for all the packets to be received
            while (valid_seen) begin
                valid_seen = 1'b0;
                for (integer i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    valid_seen |= dut_word_out.tvalid;
                end
            end

            // Check that expected equals received
            for (int port=0; port<NUM_EGR_PHYS_PORTS; port++) begin
                `CHECK_EQUAL(rx_pkt_cnts[port], expected_rx_pkt_cnts[port]);
            end
            `CHECK_EQUAL(qsys_in_pkt_cnt, NUM_PACKETS_TO_SEND);     // Packet entering queue system
            `CHECK_EQUAL(enqueue_pkt_cnt, expected_total_packets);  // Packets that passed congestion manager
            `CHECK_EQUAL(dequeue_pkt_cnt, expected_total_packets);  // Packets that were dequeued
            `CHECK_EQUAL(total_rx_pkts,   expected_total_packets);  // Packets that exiting queue system
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk        <= 1'b0;
            core_clk_ifc.clk        <= 1'b0;
            send_packet_req         <= 1'b0;
        end

        `TEST_CASE_SETUP begin

            /// Disable the ingress policer for now.
            ing_policer_enable = '0;
            ing_policer_decrement = '{default: '1};
            ing_policer_depth_threshold = '{default: '1};

            interconnect_sreset_ifc.reset = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = peripheral_sreset_ifc.ACTIVE_HIGH;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = ~peripheral_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

        end

        `TEST_CASE("send_to_one_queue_fast") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(1),
                .enqueue_fast(1)
            );
        end

        `TEST_CASE("send_to_two_queues_fast") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(2),
                .enqueue_fast(1)
            );
        end

        `TEST_CASE("send_to_all_queues_fast") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(NUM_QUEUES),
                .enqueue_fast(1)
            );
        end

        `TEST_CASE("send_to_one_queue_slow") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(1),
                .enqueue_fast(0)
            );
        end

        `TEST_CASE("send_to_two_queues_slow") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(2),
                .enqueue_fast(0)
            );
        end

        `TEST_CASE("send_to_all_queues_slow") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(NUM_QUEUES),
                .enqueue_fast(0)
            );
        end

        // Congestion Manager has a limitation of how quickly it can turn around and
        // survice a packet to the same queue. This test sends single cycle packets
        // to the same queue, two cycles apart. eventually we will want to support
        // sending back to back.
        `TEST_CASE("cong_man_back_to_back") begin
            send_pkts_to_rand_queues(
                .num_queues_to_enqueue(1),
                .enqueue_fast(1),
                .packet_size(PACKET_MIN_BLEN)
            );
        end
    end

    `WATCHDOG(1ms);

endmodule
