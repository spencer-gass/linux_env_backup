// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module wraps the verilog-axis axis_rate_limit module.
 */
module
     #(
    parameter RATE_CONFIG_WIDTH = 8,
    parameter RATE_ACC_WIDTH = 23
) (
    AXIS_int.Slave                          axis_in,
    AXIS_int.Master                         axis_out,

    input var logic [RATE_CONFIG_WIDTH-1:0] rate_num,
    input var logic [RATE_CONFIG_WIDTH-1:0] rate_denom,
    input var logic                         rate_by_frame
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int DATA_BYTES = axis_in.DATA_BYTES;
    localparam int ID_WIDTH   = axis_in.ID_WIDTH;
    localparam int DEST_WIDTH = axis_in.DEST_WIDTH;
    localparam int USER_WIDTH = axis_in.USER_WIDTH;

    `ELAB_CHECK_EQUAL(DATA_BYTES, axis_out.DATA_BYTES);
    `ELAB_CHECK_EQUAL(ID_WIDTH  , axis_out.ID_WIDTH  );
    `ELAB_CHECK_EQUAL(DEST_WIDTH, axis_out.DEST_WIDTH);
    `ELAB_CHECK_EQUAL(USER_WIDTH, axis_out.USER_WIDTH);
    `ELAB_CHECK_GT(RATE_CONFIG_WIDTH, 0);
    `ELAB_CHECK_GT(RATE_ACC_WIDTH, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    axis_rate_limit #(
        .DATA_WIDTH         ( 8*DATA_BYTES      ),
        .ID_ENABLE          ( ID_WIDTH > 0      ),
        .ID_WIDTH           ( ID_WIDTH          ),
        .DEST_ENABLE        ( DEST_WIDTH > 0    ),
        .DEST_WIDTH         ( DEST_WIDTH        ),
        .USER_ENABLE        ( USER_WIDTH > 0    ),
        .USER_WIDTH         ( USER_WIDTH        ),
        .RATE_CONFIG_WIDTH  ( RATE_CONFIG_WIDTH ),
        .RATE_ACC_WIDTH     ( RATE_ACC_WIDTH    )
    ) axis_broadcast_inst (
        .clk            ( axis_in.clk       ),
        .rst            (!axis_in.sresetn   ),

        .s_axis_tdata   ( axis_in.tdata     ),
        .s_axis_tkeep   ( axis_in.tkeep     ),
        .s_axis_tvalid  ( axis_in.tvalid    ),
        .s_axis_tready  ( axis_in.tready    ),
        .s_axis_tlast   ( axis_in.tlast     ),
        .s_axis_tid     ( axis_in.tid       ),
        .s_axis_tdest   ( axis_in.tdest     ),
        .s_axis_tuser   ( axis_in.tuser     ),

        .m_axis_tdata   ( axis_out.tdata    ),
        .m_axis_tkeep   ( axis_out.tkeep    ),
        .m_axis_tvalid  ( axis_out.tvalid   ),
        .m_axis_tready  ( axis_out.tready   ),
        .m_axis_tlast   ( axis_out.tlast    ),
        .m_axis_tid     ( axis_out.tid      ),
        .m_axis_tdest   ( axis_out.tdest    ),
        .m_axis_tuser   ( axis_out.tuser    ),

        .rate_num       ( rate_num          ),
        .rate_denom     ( rate_denom        ),
        .rate_by_frame  ( rate_by_frame     )
    );

endmodule

`default_nettype wire
