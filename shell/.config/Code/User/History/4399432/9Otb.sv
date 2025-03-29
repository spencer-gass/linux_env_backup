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
    parameter   int     N = 2
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
    // SECTION: Signal Declarations


    logic   [N-1:0]                 axis_out_tready;
    logic   [N-1:0]                 axis_out_tvalid;
    logic   [N*8*DATA_BYTES-1:0]    axis_out_tdata;
    logic   [N*DATA_BYTES-1:0]      axis_out_tstrb;
    logic   [N*DATA_BYTES-1:0]      axis_out_tkeep;
    logic   [N-1:0]                 axis_out_tlast;
    logic   [N*ID_WIDTH-1:0]        axis_out_tid;
    logic   [N*DEST_WIDTH-1:0]      axis_out_tdest;
    logic   [N*USER_WIDTH-1:0]      axis_out_tuser;



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    // Pack broadcast output into AXIS interfaces
    generate
        for (genvar i=0; i<N; i++) begin
            assign axis_out_tready[i] = axis_out[i].tready;

            assign axis_out[i].tvalid = axis_out_tvalid[i];
            assign axis_out[i].tdata  = axis_out_tdata [i*8*DATA_BYTES +: 8*DATA_BYTES];
            // tstrb is not supported by axis_broadcast
            assign axis_out[i].tstrb  = '1;
            assign axis_out[i].tkeep  = axis_out_tkeep [i*DATA_BYTES   +: DATA_BYTES];
            assign axis_out[i].tlast  = axis_out_tlast [i];
            assign axis_out[i].tid    = axis_out_tid   [i*ID_WIDTH     +: ID_WIDTH];
            assign axis_out[i].tdest  = axis_out_tdest [i*DEST_WIDTH   +: DEST_WIDTH];
            assign axis_out[i].tuser  = axis_out_tuser [i*USER_WIDTH   +: USER_WIDTH];
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    axis_broadcast_wrapper #(
        .N ( N )
    ) point_to_multipoint_broadcast (
        axis_in  (  ),
        axis_out (  )
    );

    axis_arb_mux_wrapper #(
        .N          ( N             ),
        .ARB_TYPE   ( "ROUND_ROBIN" ),
    ) multipoint_to_point_arb_mux (
        .axis_in        (  ),
        .axis_out       (  ),
        .grant          (  ),
        .grant_valid    (  ),
        .grant_encoded  (  )
    );


endmodule

`default_nettype wire
