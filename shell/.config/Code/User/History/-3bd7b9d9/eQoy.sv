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

module p4_router_uram_queue_mmu #(
    parameter int NUM_PAGES = 0,
    parameter int NUM_PAGES_LOG = $clog2(NUM_PAGES),
    parameter int MTU_BYTES = 2000
) (

    output var logic [NUM_PAGES_LOG-1:0] num_free_pages,
    AXIS_int.Master                      malloc,
    AXIS_int.Slave                       free

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_PAGES_LOG, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Policer



endmodule

`default_nettype wire
