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


module axis_array_packet_generator_and_checker_tb();

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
    localparam int NUM_AXIS_INTFS_LOG = $clog2(NUM_AXIS_INTFS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [0:MTU_BYTES*8-1]    send_packet_data        [NUM_AXIS_INTFS-1:0];
    int                        send_packet_byte_length [NUM_AXIS_INTFS-1:0];
    logic [NUM_AXIS_INTFS-1:0] send_packet_req;
    logic [NUM_AXIS_INTFS-1:0] send_packet_req_d;
    logic [NUM_AXIS_INTFS-1:0] send_packet_busy;

    logic [0:MTU_BYTES*8-1]             tx_snoop_data_buf [NUM_AXIS_INTFS-1:0][NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf [NUM_AXIS_INTFS-1:0][NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr   [NUM_AXIS_INTFS-1:0];

    logic [NUM_AXIS_INTFS-1:0] packet_tlast;
    int                        packet_counts [NUM_AXIS_INTFS-1:0];


    /////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES )
    ) gen_out_axis [NUM_AXIS_INTFS-1:0] (
        .clk     (clk_ifc.clk                                 ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES         ),
        .DEST_WIDTH ( NUM_AXIS_INTFS_LOG )
    ) chk_in_axis [NUM_AXIS_INTFS-1:0] (
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
        .NUM_PORTS          ( NUM_AXIS_INTFS    ),
        .MTU_BYTES          ( MTU_BYTES         )
    ) packet_generator (
        .axis_packet_out    ( gen_out_axis              ),
        .busy               ( send_packet_busy          ),
        .send_packet_req    ( send_packet_req           ),
        .packet_byte_length ( send_packet_byte_length   ),
        .packet_user        ( '{default: '0}            ),
        .packet_data        ( send_packet_data          )
    );

    // Insert Generator ID into tdest
    generate
        for (genvar gen_id=0; gen_id<NUM_AXIS_INTFS; gen_id++) begin : dest_insert
            assign gen_out_axis[gen_id].tready  = chk_in_axis[gen_id].tready;
            assign chk_in_axis[gen_id].tvalid   = gen_out_axis[gen_id].tvalid;
            assign chk_in_axis[gen_id].tdata    = gen_out_axis[gen_id].tdata;
            assign chk_in_axis[gen_id].tstrb    = gen_out_axis[gen_id].tstrb;
            assign chk_in_axis[gen_id].tkeep    = gen_out_axis[gen_id].tkeep;
            assign chk_in_axis[gen_id].tlast    = gen_out_axis[gen_id].tlast;
            assign chk_in_axis[gen_id].tid      = gen_out_axis[gen_id].tid;
            assign chk_in_axis[gen_id].tuser    = gen_out_axis[gen_id].tuser;
            assign chk_in_axis[gen_id].tdest    = gen_id;
        end
    endgenerate

    axis_array_packet_checker #(
        .NUM_PORTS                         ( NUM_AXIS_INTFS         ),
        .AXIS_PACKET_IN_DATA_BYTES         ( DATA_BYTES             ),
        .AXIS_PACKET_IN_USER_WIDTH         ( 1'b1                   ),
        .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( 1'b1                   ),
        .MTU_BYTES                         ( MTU_BYTES              ),
        .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND    )
    )  packet_checker  (
        .axis_packet_in             ( chk_in_axis                   ),
        .num_tx_pkts                ( tx_snoop_wr_ptr               ),
        .expected_pkts              ( tx_snoop_data_buf             ),
        .expected_blens             ( tx_snoop_blen_buf             ),
        .expected_dests             ( '{default: '{default: '0}}    ),
        .max_back_pressure_latency  ( 0                             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Tx Packet Capture

    always_ff @(posedge clk_ifc.clk ) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf       <= '{default: '{default: '0}};
            tx_snoop_blen_buf       <= '{default: '{default: 0}};
            tx_snoop_wr_ptr         <= '{default: '0};
            send_packet_req_d       <= '{default: '0};
        end else begin
            send_packet_req_d <= send_packet_req;
            for (int send_packet_port=0; send_packet_port<NUM_AXIS_INTFS; send_packet_port++) begin
                if (send_packet_req[send_packet_port] && !send_packet_req_d[send_packet_port]) begin
                    tx_snoop_data_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_data[send_packet_port];
                    tx_snoop_blen_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_byte_length[send_packet_port];
                    tx_snoop_wr_ptr[send_packet_port]++;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Packet Counters

    generate
        for (genvar i=0; i<NUM_AXIS_INTFS; i++) begin : packet_tlast_g
            assign packet_tlast[i] = gen_out_axis[i].tready & gen_out_axis[i].tvalid & gen_out_axis[i].tlast;
        end
    endgenerate

    always_ff @(posedge clk_ifc.clk) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            packet_counts = '{default: 0};
        end else begin
            for (int intf; intf<NUM_AXIS_INTFS; intf++) begin
                packet_counts[intf] += packet_tlast[intf];
            end
        end
    end


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


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = '{default: '{default: 1'b0}};
        end

        `TEST_CASE_SETUP begin
            @(posedge clk_ifc.clk);
            sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
            send_packet_req = '{default: '{default: 1'b0}};
            repeat (10) @(posedge clk_ifc.clk);
            sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge clk_ifc.clk);
        end

        // Send packets to all interfaces simultaneously
        `TEST_CASE("smoke") begin

            automatic int expected_count = NUM_PACKETS_TO_SEND / NUM_AXIS_INTFS;

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
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

            // Check packet counts
            for (int intf=0; intf<NUM_AXIS_INTFS; intf++) begin
                `CHECK_EQUAL(packet_counts[intf], expected_count);
            end
        end
    end

    `WATCHDOG(1ms);

endmodule
