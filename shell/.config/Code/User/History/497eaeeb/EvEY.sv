// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module wraps the verilog-axis axis_async_fifo module.
 *
 * TSTRB is not supported, the axis_out.tstrb will be all 1's
 */
module axis_async_fifo_wrapper #(
    /*
     * FIFO depth in words, each of which is axis_in.DATA_BYTES bytes wide
     * Rounded up to nearest power of 2.
     * Note that the maximum fill level of the FIFO is actually DEPTH+PIPELINE_OUTPUT (although if
     * FRAME_FIFO=1, a single frame cannot exceed DEPTH samples).
     */
    parameter int DEPTH                = 128,
    parameter bit KEEP_ENABLE          = 1'b1,
    parameter bit LAST_ENABLE          = 1'b1,
    parameter bit ID_ENABLE            = 1'b1,
    parameter bit DEST_ENABLE          = 1'b1,
    parameter bit USER_ENABLE          = 1'b1,
    parameter bit FRAME_FIFO           = 1'b0,
    parameter int USER_BAD_FRAME_VALUE = 1'b1,
    parameter int USER_BAD_FRAME_MASK  = 1'b1,
    parameter bit DROP_BAD_FRAME       = 1'b0,
    parameter bit DROP_WHEN_FULL       = 1'b0,
    parameter int PIPELINE_OUTPUT      = 2
) (
    AXIS_int.Slave  axis_in,   // AXI stream input
    AXIS_int.Master axis_out,  // AXI stream output

    output var logic axis_in_overflow,
    output var logic axis_in_bad_frame,
    output var logic axis_in_good_frame,
    output var logic axis_out_overflow,
    output var logic axis_out_bad_frame,
    output var logic axis_out_good_frame
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(axis_in.DATA_BYTES, axis_out.DATA_BYTES);
    //`ELAB_CHECK_EQUAL(axis_in.ID_WIDTH, axis_out.ID_WIDTH);
    //`ELAB_CHECK_EQUAL(axis_in.DEST_WIDTH, axis_out.DEST_WIDTH);
    //`ELAB_CHECK_EQUAL(axis_in.USER_WIDTH, axis_out.USER_WIDTH);

    // Compensate for the unusual way that axis_async_fifo handles depth.
    localparam int WORDS_PER_CYCLE = KEEP_ENABLE ? axis_in.DATA_BYTES : 1;
    localparam int DEPTH_ADJUSTED  = DEPTH * WORDS_PER_CYCLE;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic async_fifo_rst;
    logic axis_out_sresetn_on_axis_in_clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    // CDC for FIFO reset
    xclock_resetn sync_async_fifo_rst (
        .tx_clk     ( axis_in.clk                     ),
        .resetn_in  ( axis_in.sresetn                 ),
        .rx_clk     ( axis_in.clk                     ),
        .resetn_out ( axis_out_sresetn_on_axis_in_clk )
    );

    always_ff @(posedge axis_in.clk) begin
        async_fifo_rst <= !(axis_in.sresetn && axis_out_sresetn_on_axis_in_clk);
    end

    axis_async_fifo #(
        .DEPTH                ( DEPTH_ADJUSTED                                    ),
        .DATA_WIDTH           ( 8*axis_in.DATA_BYTES                              ),
        .KEEP_ENABLE          ( KEEP_ENABLE                                       ),
        .LAST_ENABLE          ( LAST_ENABLE                                       ),
        .ID_ENABLE            ( ID_ENABLE && (axis_in.ID_WIDTH > 0)               ),
        .ID_WIDTH             ( (axis_in.ID_WIDTH > 0) ? axis_in.ID_WIDTH : 1     ),
        .DEST_ENABLE          ( DEST_ENABLE && (axis_in.DEST_WIDTH > 0)           ),
        .DEST_WIDTH           ( (axis_in.DEST_WIDTH > 0) ? axis_in.DEST_WIDTH : 1 ),
        .USER_ENABLE          ( USER_ENABLE && (axis_in.USER_WIDTH > 0)           ),
        .USER_WIDTH           ( (axis_in.USER_WIDTH > 0) ? axis_in.USER_WIDTH : 1 ),
        .FRAME_FIFO           ( FRAME_FIFO                                        ),
        .USER_BAD_FRAME_VALUE ( USER_BAD_FRAME_VALUE                              ),
        .USER_BAD_FRAME_MASK  ( USER_BAD_FRAME_MASK                               ),
        .DROP_BAD_FRAME       ( DROP_BAD_FRAME                                    ),
        .DROP_WHEN_FULL       ( DROP_WHEN_FULL                                    ),
        .PIPELINE_OUTPUT      ( PIPELINE_OUTPUT                                   )
    ) axis_async_fifo_inst (
        .async_rst           ( async_fifo_rst      ),
        .s_clk               ( axis_in.clk         ),
        .s_axis_tdata        ( axis_in.tdata       ),
        .s_axis_tkeep        ( axis_in.tkeep       ),
        .s_axis_tvalid       ( axis_in.tvalid      ),
        .s_axis_tready       ( axis_in.tready      ),
        .s_axis_tlast        ( axis_in.tlast       ),
        .s_axis_tid          ( axis_in.tid         ),
        .s_axis_tdest        ( axis_in.tdest       ),
        .s_axis_tuser        ( axis_in.tuser       ),
        .m_clk               ( axis_out.clk        ),
        .m_axis_tdata        ( axis_out.tdata      ),
        .m_axis_tkeep        ( axis_out.tkeep      ),
        .m_axis_tvalid       ( axis_out.tvalid     ),
        .m_axis_tready       ( axis_out.tready     ),
        .m_axis_tlast        ( axis_out.tlast      ),
        .m_axis_tid          ( axis_out.tid        ),
        .m_axis_tdest        ( axis_out.tdest      ),
        .m_axis_tuser        ( axis_out.tuser      ),
        .s_status_overflow   ( axis_in_overflow    ),
        .s_status_bad_frame  ( axis_in_bad_frame   ),
        .s_status_good_frame ( axis_in_good_frame  ),
        .m_status_overflow   ( axis_out_overflow   ),
        .m_status_bad_frame  ( axis_out_bad_frame  ),
        .m_status_good_frame ( axis_out_good_frame )
    );

    assign axis_out.tstrb = '1;

endmodule

`default_nettype wire
