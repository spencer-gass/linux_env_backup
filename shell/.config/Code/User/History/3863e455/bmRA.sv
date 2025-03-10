// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router Queue Memory Management Unit
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_policer #(
    parameter int MTU_BYTES = 2000
) (

    AvalonMM_int.Slave  avmm,

    AXIS_int.Slave  packet_in,
    AXIS_int.Master word_out

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);


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

    p4_router_policer #(
        .MTU_BYTES  ( MTU_BYTES             )
    ) policer (
        .avmm       ( policer_avmm          ),
        .packet_in  ( packet_in             ),
        .packet_out ( policer_to_cong_man   )
    );


endmodule

`default_nettype wire
