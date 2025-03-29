// CONFIDENTIAL
// Copyright (c) 2025 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module implements an axis point to multi-point interconnect where
 *  packets are broadcast in the point to multi-point direction, and round-robin
 *  muxed in the multi-point to point direction.
 */
module axis_point_to_multipoint_hub #(
    parameter   int     N = 2 // Number of axis interfaces in the multipoint axis interface arrays
) (
    AXIS_int.Slave      axis_point_in,
    AXIS_int.Master     axis_point_out,
    AXIS_int.Slave      axis_multipoint_in  [N-1:0]
    AXIS_int.Master     axis_multipoint_out [N-1:0]
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int DATA_BYTES = axis_in.DATA_BYTES;
    localparam int ID_WIDTH   = axis_in.ID_WIDTH;
    localparam int DEST_WIDTH = axis_in.DEST_WIDTH;
    localparam int USER_WIDTH = axis_in.USER_WIDTH;

    `ELAB_CHECK_EQUAL(DATA_BYTES, axis_out[0].DATA_BYTES);
    `ELAB_CHECK_EQUAL(ID_WIDTH  , axis_out[0].ID_WIDTH  );
    `ELAB_CHECK_EQUAL(DEST_WIDTH, axis_out[0].DEST_WIDTH);
    `ELAB_CHECK_EQUAL(USER_WIDTH, axis_out[0].USER_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    axis_broadcast_wrapper #(
        .N ( N )
    ) point_to_multipoint_broadcast (
        axis_in  ( axis_point_in        ),
        axis_out ( axis_multipoint_out  )
    );

    axis_arb_mux_wrapper #(
        .N          ( N             ),
        .ARB_TYPE   ( "ROUND_ROBIN" ),
    ) multipoint_to_point_arb_mux (
        .axis_in        ( axis_multipoint_in ),
        .axis_out       ( axis_point_out     ),
        .grant          (  ),
        .grant_valid    (  ),
        .grant_encoded  (  )
    );


endmodule

`default_nettype wire
