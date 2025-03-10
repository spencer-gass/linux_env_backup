// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for:
    axis_packet_generator
    axis_packet_checker
    axis_array_packet_generator
    axis_array_packet_checker
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps


module axis_array_packet_generator_and_checker_tb ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int NUM_AXIS_INTFS = 4;
    parameter int DATA_BYTES = 8;
    parameter int MTU_BYTES = 1500;                // MTU for the router
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [0:MTU_BYTES*8-1]    send_packet_data        [NUM_AXIS_INTFS-1:0];
    int                        send_packet_byte_length [NUM_AXIS_INTFS-1:0];
    logic [NUM_AXIS_INTFS-1:0] send_packet_req;
    logic [NUM_AXIS_INTFS-1:0] send_packet_req_d;
    logic [NUM_AXIS_INTFS-1:0] send_packet_busy;

    int expected_count;
    int received_count;
    bit receive_cntr_clear;

    logic [NUM_AXIS_INTFS-1:0]          ing_phys_ports_tlast;
    logic [ING_COUNTERS_WIDTH-1:0] expected_ing_cnts [NUM_AXIS_INTFS-1:0] [6:0];

    logic [0:MTU_BYTES*8-1]             tx_snoop_data_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_AXIS_INTFS_LOG-1:0]           tx_snoop_ing_port_buf   [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr;

    logic [NUM_PACKETS_TO_SEND-1:0] packet_received [NUM_AXIS_INTFS-1:0];
    logic [MTU_BYTES*8-1:0]         rx_packet_buf;
    logic [MTU_BYTES*8-1:0]         rx_packet;
    int                             rx_wcnt;
    int                             rx_blen;
    int                             rx_ing_port;
    logic                           rx_validate;

    int sink_interpacekt_gap;


    /////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES )
    ) packet_axis [NUM_AXIS_INTFS-1:0] (
        .clk     (clk_ifc.clk                                 ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic implemenatation

    // Simulation clocks
    always #5 clk_ifc.clk <= ~clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    axis_array_packet_generator #(
        .NUM_AXIS_INTFS          ( NUM_AXIS_INTFS    ),
        .MTU_BYTES          ( MTU_BYTES         )
    ) packet_generator (
        .axis_packet_out    ( packet_axis               ),
        .busy               ( send_packet_busy          ),
        .send_packet_req    ( send_packet_req           ),
        .packet_byte_length ( send_packet_byte_length   ),
        .packet_user        ( '{default: '0}            ),
        .packet_data        ( send_packet_data          )
    );

    axis_array_packet_checker #(
        .NUM_AXIS_INTFS                         ( NUM_AXIS_INTFS                 ),
        .AXIS_PACKET_IN_DATA_BYTES         ( packet_axis.DATA_BYTES         ),
        .AXIS_PACKET_IN_USER_WIDTH         ( packet_axis.USER_WIDTH         ),
        .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( packet_axis.ALLOW_BACKPRESSURE ),
        .MTU_BYTES                         ( MTU_BYTES                      ),
        .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND            )
    )  packet_checker  (
        .axis_packet_in ( packet_axis                   ),
        .packet_in_id   ( '{default: '0}                ),
        .num_tx_pkts    ( tx_snoop_wr_ptr               ),
        .expected_pkts  ( tx_snoop_data_buf             ),
        .expected_blens ( tx_snoop_blen_buf             ),
        .expected_ids   ( '{default: '{default: '0}}    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Tx Packet Capture

    always_ff @(posedge clk_ifc.clk ) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH || receive_cntr_clear) begin
            tx_snoop_data_buf       <= '{default: '0};
            tx_snoop_blen_buf       <= '{default: 0};
            tx_snoop_ing_port_buf   <= '{default: 0};
            tx_snoop_wr_ptr         <= '0;
            send_packet_req_d       <= '{default: '0};
        end else begin
            send_packet_req_d <= send_packet_req;
            for (int send_packet_port=0; send_packet_port<NUM_AXIS_INTFS; send_packet_port++) begin
                automatic int width_index = get_port_width_index(send_packet_port, ING_PORT_INDEX_MAP);
                automatic int array_index = get_port_array_index(send_packet_port, ING_PORT_INDEX_MAP);
                if (send_packet_req[width_index][array_index] && ! send_packet_req_d[width_index][array_index]) begin
                    tx_snoop_data_buf[tx_snoop_wr_ptr] <= send_packet_data[width_index][array_index];
                    tx_snoop_blen_buf[tx_snoop_wr_ptr] <= send_packet_byte_length[width_index][array_index];
                    tx_snoop_ing_port_buf[tx_snoop_wr_ptr] <= send_packet_port;
                    tx_snoop_wr_ptr++;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Packet Counters

    // generate
    //     for (genvar i=0; i<NUM_8B_PORTS; i++) begin
    //         assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_8B][i]] = ing_8b_phys_ports[i].tready & ing_8b_phys_ports[i].tvalid & ing_8b_phys_ports[i].tlast;
    //     end
    //     for (genvar i=0; i<NUM_16B_PORTS; i++) begin
    //         assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_16B][i]] = ing_16b_phys_ports[i].tready & ing_16b_phys_ports[i].tvalid & ing_16b_phys_ports[i].tlast;
    //     end
    //     for (genvar i=0; i<NUM_32B_PORTS; i++) begin
    //         assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_32B][i]] = ing_32b_phys_ports[i].tready & ing_32b_phys_ports[i].tvalid & ing_32b_phys_ports[i].tlast;
    //     end
    //     for (genvar i=0; i<NUM_64B_PORTS; i++) begin
    //         assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_64B][i]] = ing_64b_phys_ports[i].tready & ing_64b_phys_ports[i].tvalid & ing_64b_phys_ports[i].tlast;
    //     end
    // endgenerate

    // always_ff @(posedge clk_ifc.clk) begin
    //     if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH || receive_cntr_clear) begin
    //         expected_ing_cnts = '{default: '{default: '0}};
    //     end else begin
    //         for (int port_index; port_index<NUM_AXIS_INTFS; port_index++) begin
    //             if (ing_phys_ports_enable[port_index]) begin
    //                 expected_ing_cnts[port_index][AXIS_PROFILE_PKT_CNT_INDEX] += ing_phys_ports_tlast[port_index];
    //             end
    //         end
    //     end
    // end


    // ////////////////////////////////////////////////////////////////////////////////////////////////
    // // SUB-SECTION: Receive packet counter

    // always_ff @(posedge core_clk_ifc.clk) begin : rx_pkt_cntr
    //     if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH || receive_cntr_clear) begin
    //         received_count <= 0;
    //     end else begin
    //         if (ing_bus.tlast & ing_bus.tvalid & ing_bus.tready) begin
    //             received_count <= received_count + 1;
    //         end
    //     end
    // end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        send_packet_byte_length[send_packet_port] = packet_byte_length;

        // Wait till we can send data
        while(send_packet_busy[send_packet_port]) @(posedge clk_ifc.clk);

        for (int i=0; i<MTU_BYTES/4; i++) begin
            send_packet_data[send_packet_port][i*32-1 +: 32] = $random();
        end

        send_packet_req[send_packet_port] = 1'b1;
        // Wait till its received
        while(!send_packet_busy[send_packet_port]) @(posedge clk_ifc.clk);
        send_packet_req[send_packet_port] = 1'b0;
        // Wait till its finished
        while(send_packet_busy[send_packet_port]) @(posedge clk_ifc.clk);
    end
    endtask;

    task automatic send_random_length_packet (
        input int send_packet_port
    );
        send_packet(send_packet_port, $urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN));
    endtask

    task automatic check_pkt_cnts();
        // Compare tx and rx counts
        `CHECK_EQUAL(received_count, expected_count); // test bench packet count at ingress bus
        `CHECK_EQUAL(ing_bus_pkt_cnt, expected_count); // DUT packet count at ingress bus
        for (int i=0; i<NUM_AXIS_INTFS; i++) begin
            // Check that the expected number of packets were counted by the DUT ingress counters
            `CHECK_EQUAL(ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], expected_ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX]);
            // Verify that the DUT ingress counters clears and don't disrupt other counts
            ing_cnts_clear[i] = 1'b1;
            @(posedge core_clk_ifc.clk);
            #1;
            `CHECK_EQUAL(ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], 0);
        end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk_ifc.clk = 1'b0;
            core_clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = '{default: '{default: 1'b0}};
        end

        `TEST_CASE_SETUP begin
            sink_interpacekt_gap = 0;
            ignore_overflow = 1'b0;
            receive_cntr_clear = 1'b0;
            @(posedge clk_ifc.clk);
            sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
            packet_sink_reset = 1'b1;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;

            send_packet_req = '{default: '{default: 1'b0}};

            repeat (10) @(posedge clk_ifc.clk);
            sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;
            packet_sink_reset = 1'b0;

            repeat (2) @(posedge clk_ifc.clk);
        end

        // Send packets to all interfaces simultaneously
        `TEST_CASE("smoke") begin

            expected_count = (NUM_PACKETS_TO_SEND / NUM_AXIS_INTFS) * NUM_AXIS_INTFS;

            // Send packets to all interfacess in parallel
            for (int intf_thread=0; intf_thread<NUM_AXIS_INTFS; intf_thread++ ) begin
                automatic int intf = intf_thread;
                fork
                    begin
                        for(int packet=0; packet<NUM_PACKETS_TO_SEND/NUM_AXIS_INTFS; packet++) begin
                            send_random_length_packet(intf);
                        end
                    end
                join_none
            end
            wait fork;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge core_clk_ifc.clk);

            // Check that expected equals received
            check_pkt_cnts;
        end
    end

    `WATCHDOG(1ms);

endmodule