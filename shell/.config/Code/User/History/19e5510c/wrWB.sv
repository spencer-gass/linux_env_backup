// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router Congestion Manager
 *  Not yet implemented. Passthrough for now.
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_congestoin_manager #(
    parameter int NUM_PAGES = 0,
    parameter int MTU_BYTES = 2000
) (

    AvalonMM_int.Slave  avmm,

    AXIS_int.Slave          packet_in,
    AXIS_int.Master         packet_out,
    AXI4Lite_int.Master     queue_occupancy,
    input var logic         num_free_pages

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, packet_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_PAGES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    //  AXIS_int #(
    //     .DATA_BYTES ( packet_in.data_bytes                       ),
    //     .USER_WIDTH ( USER_METADATA_WIDTH + POLICER_COLOR_BITS   )
    // ) policer_to_cong_man (
    //     .clk     ( packet_in.clk     ),
    //     .sresetn ( packet_in.sresetn )
    // );

    // AXI4Lite_int #(
    //     .DATALEN    ( MAX_QUEUE_OCCUPANCY_LOG ),
    //     .ADDRLEN    ( NUM_QUEUES_LOG          )
    // ) cong_man_queue_occupancy (
    //     .clk     ( packet_in.clk     ),
    //     .sresetn ( packet_in.sresetn )
    // );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Policer

    axis_connect passthrough (
        .axis_in    (packet_in ),
        .axis_out   (packet_out)
    );


endmodule

`default_nettype wire
