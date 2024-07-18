// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Converts Xilinx Vitis Networking P4 user_extern interface to two AXIS interfaces.
 * - user_extern interface sends data+valid, and expects to recieve back data+valid
 *   a fixed number of clock cycles later.
 * - user_extern is used for computation offload to user logic so data widths don't have
 *   to be symetric.
 */

module axis_to_user_extern #(
    parameter int UE_IN_DATA_BITS = 0,
    parameter int UE_OUT_DATA_BITS = 0
) (
    // Input from VNP4
    input var logic [UE_IN_DATA_BITS-1:0]   user_extern_data_in,
    input var logic                         user_extern_valid_in,
    // Output to VNP4
    input var logic [UE_OUT_DATA_BITS-1:0]  user_extern_data_out,
    input var logic                         user_extern_valid_out,
    // Output to user logic
    AXIS_int.Master                         axis_out,
    // Input from user logic
    AXIS_int.Slave                          axis_in
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation

    `ELAB_CHECK_GT(UE_IN_DATA_BITS, 0);
    `ELAB_CHECK_GT(UE_OUT_DATA_BITS, 0);
    // Data width of AXIS must accomidate user_extern data width
    `ELAB_CHECK_GE(8*axis_out.DATA_BYTES, UE_IN_DATA_BITS);
    `ELAB_CHECK_GE(8*axis_in.DATA_BYTES,  UE_OUT_DATA_BITS);
    // User extern doesn't allow backpressure
    `ELAB_CHECK_EQUAL(axis_out.ALLOW_BACKPRESSURE, 1'b0);
    `ELAB_CHECK_EQUAL(axis_in.ALLOW_BACKPRESSURE, 1'b0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign axis_out.tvalid     = user_extern_valid_in;
    assign axis_out.tdata      = user_extern_data_in;
    assign axis_out.tstrb      = '1; // if unused, set to '1
    assign axis_out.tkeep      = '1; // if unused, set to '1
    assign axis_out.tlast      = user_extern_valid_in;
    assign axis_out.tid        = '0; // if unused, set to '0
    assign axis_out.tdest      = '0; // if unused, set to '0
    assign axis_out.tuser      = '0; // if unused, set to '0

    assign axis_in.tready        = 1'b1;
    assign user_extern_valid_out = axis_in.tvalid;
    assign user_extern_data_out  = axis_in.tdata[UE_OUT_DATA_BITS-1:0];

endmodule

`default_nettype wire
