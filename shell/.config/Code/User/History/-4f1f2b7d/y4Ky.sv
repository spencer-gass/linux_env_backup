// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Queue Memory Management Unit
 *  Not yet implemented. Passthrough for now.
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_queue_mmu #(
    parameter int NUM_PAGES_LOG = 0,
    parameter int MTU_BYTES = 2000
) (

    output var logic [NUM_PAGES_LOG-1:0] num_free_pages;
    AXIS_int.Slave                       malloc,
    AXIS_int.Master                      free

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_PAGES_LOG, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

     AXIS_int #(
        .DATA_BYTES ( packet_in.data_bytes                       ),
        .USER_WIDTH ( USER_METADATA_WIDTH + POLICER_COLOR_BITS   )
    ) policer_to_cong_man (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXI4Lite_int #(
        .DATALEN    ( MAX_QUEUE_OCCUPANCY_LOG ),
        .ADDRLEN    ( NUM_QUEUES_LOG          )
    ) cong_man_queue_occupancy (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Policer



endmodule

`default_nettype wire
