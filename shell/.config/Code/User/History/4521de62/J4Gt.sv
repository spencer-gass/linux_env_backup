// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router Top Level Module
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "vitis_net_p4_0_pkg.sv"
`default_nettype none

module p4_router_user_extern_wrapper
    import vitis_net_p4_0_pkg::*;
#(
    parameter int USER_METADATA_WIDTH = 0
) (

    input var logic core_clk,
    input var logic core_sresetn,


);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(USER_METADATA_WIDTH, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation



endmodule

`default_nettype wire
