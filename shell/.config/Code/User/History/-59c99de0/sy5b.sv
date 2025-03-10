// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * A wrapper for axis_fifo from verilog-axis, which wraps the ports into AXIS_int interfaces and
 * provides a fill level counter.
 *
 * All of the default values of parameters are chosen to match the defaults of axis_fifo.
 *
 * NOTE: tstrb is ignored from axis_in and tied to '1 for axis_out, since axis_fifo does not
 * support it.
 */
module axis_fifo_wrapper #(
    parameter RAM_STYLE = "auto", // "block" for BRAM, "ultra" for URAM
    /*
     * FIFO depth in words, each of which is axis_in.DATA_BYTES bytes wide.
     * Rounded up to nearest power of 2.
     * Note that the maximum fill level of the FIFO is actually DEPTH+PIPELINE_OUTPUT (although if
     * FRAME_FIFO=1, a single frame cannot exceed DEPTH samples).
     */
    parameter   int DEPTH = 4096,
    // Propagate tkeep signal. If disabled, tkeep assumed to be 1'b1
    parameter   bit KEEP_ENABLE = 1,
    // Propagate tlast signal
    parameter   bit LAST_ENABLE = 1,
    // Propagate tid signal
    parameter   bit ID_ENABLE = 0,
    // Propagate tdest signal
    parameter   bit DEST_ENABLE = 0,
    // Propagate tuser signal
    parameter   bit USER_ENABLE = 1,
    // number of output pipeline registers
    parameter   int PIPELINE_OUTPUT = 2,
    /*
     * Frame FIFO mode - operate on frames instead of cycles.
     * When set, m_axis_tvalid will not be de-asserted within a frame.
     * Requires LAST_ENABLE set.
     */
    parameter   bit FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter   int USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter   int USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames marked bad. Requires FRAME_FIFO set
    parameter   bit DROP_BAD_FRAME = 0,
    /*
     * Drop incoming frames when full
     * When set, s_axis_tready is always asserted
     * Requires FRAME_FIFO set
     */
    parameter   bit DROP_WHEN_FULL = 0,
    /**
     * If this is set to 1, fill_level will output the number of samples in the FIFO, otherwise
     * it will be tied to 0.
     */
    parameter   bit FILL_LEVEL_ENABLE = 0,
    // Compensate for the unusual way that axis_fifo handles depth
    localparam int WORDS_PER_CYCLE = KEEP_ENABLE ? axis_in.DATA_BYTES : 1;
    localparam int DEPTH_ADJUSTED  = DEPTH * WORDS_PER_CYCLE;
    localparam  int FILL_LEVEL_WIDTH = $clog2(DEPTH_ADJUSTED) + 1
) (
    AXIS_int.Slave                          axis_in,
    AXIS_int.Master                         axis_out,
    output var logic                        status_overflow,
    output var logic                        status_bad_frame,
    output var logic                        status_good_frame,

    /*
     * To reset the read pointer to 0 (should be tied off to 0 if unused).
     * This can be used to store data in the FIFO and then replay it several times, so long as the
     * data began at address 0 (typically this means that the module is reset immediately before
     * each packet), and no data is written to the FIFO after the first capture. Note that if data
     * is written to the FIFO during the replay, it can also loop around and overwrite the values
     * at the beginning of the FIFO.
     */
    input  var logic                        reset_read_ptr,

    /*
     * The number of words the have been received by axis_in minus the number of words that have
     * been emitted by axis_out. Note that:
     *  1) each cycle counts as one word, regardless of KEEP_ENABLE, KEEP_WIDTH, or which bits of tkeep are set.
     *  2) this may exceed DEPTH by a few words due to samples in the output pipeline.
     */
    output var logic [FILL_LEVEL_WIDTH-1:0] fill_level
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(axis_in.DATA_BYTES,   axis_out.DATA_BYTES);
    `ELAB_CHECK_EQUAL(axis_in.ID_WIDTH,     axis_out.ID_WIDTH);
    `ELAB_CHECK_EQUAL(axis_in.DEST_WIDTH,   axis_out.DEST_WIDTH);
    `ELAB_CHECK_EQUAL(axis_in.USER_WIDTH,   axis_out.USER_WIDTH);

    /*
     * The value of fill_level must be large enough for the maximum number of
     * words that can be stored in the FIFO, including the output pipeline.
     */
    `ELAB_CHECK_GE(2**FILL_LEVEL_WIDTH-1, DEPTH + PIPELINE_OUTPUT);




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    axis_fifo #(
        .RAM_STYLE              ( RAM_STYLE             ),
        .DEPTH                  ( DEPTH_ADJUSTED        ),
        .DATA_WIDTH             ( 8*axis_in.DATA_BYTES  ),
        .KEEP_ENABLE            ( KEEP_ENABLE           ),
        .KEEP_WIDTH             ( axis_in.DATA_BYTES    ),
        .LAST_ENABLE            ( LAST_ENABLE           ),
        .ID_ENABLE              ( ID_ENABLE             ),
        .ID_WIDTH               ( axis_in.ID_WIDTH      ),
        .DEST_ENABLE            ( DEST_ENABLE           ),
        .DEST_WIDTH             ( axis_in.DEST_WIDTH    ),
        .USER_ENABLE            ( USER_ENABLE           ),
        .USER_WIDTH             ( axis_in.USER_WIDTH    ),
        .PIPELINE_OUTPUT        ( PIPELINE_OUTPUT       ),
        .FRAME_FIFO             ( FRAME_FIFO            ),
        .USER_BAD_FRAME_VALUE   ( USER_BAD_FRAME_VALUE  ),
        .USER_BAD_FRAME_MASK    ( USER_BAD_FRAME_MASK   ),
        .DROP_BAD_FRAME         ( DROP_BAD_FRAME        ),
        .DROP_WHEN_FULL         ( DROP_WHEN_FULL        ),
        .FILL_LEVEL_ENABLE      ( FILL_LEVEL_ENABLE     ),
        .FILL_LEVEL_FULL_WORDS  ( 1                     )
    ) axis_fifo_inst (
        .clk                ( axis_in.clk           ),
        .rst                (~axis_in.sresetn       ),

        .s_axis_tdata       ( axis_in.tdata         ),
        .s_axis_tkeep       ( axis_in.tkeep         ),
        .s_axis_tvalid      ( axis_in.tvalid        ),
        .s_axis_tready      ( axis_in.tready        ),
        .s_axis_tlast       ( axis_in.tlast         ),
        .s_axis_tid         ( axis_in.tid           ),
        .s_axis_tdest       ( axis_in.tdest         ),
        .s_axis_tuser       ( axis_in.tuser         ),

        .m_axis_tdata       ( axis_out.tdata        ),
        .m_axis_tkeep       ( axis_out.tkeep        ),
        .m_axis_tvalid      ( axis_out.tvalid       ),
        .m_axis_tready      ( axis_out.tready       ),
        .m_axis_tlast       ( axis_out.tlast        ),
        .m_axis_tid         ( axis_out.tid          ),
        .m_axis_tdest       ( axis_out.tdest        ),
        .m_axis_tuser       ( axis_out.tuser        ),

        .status_overflow    ( status_overflow       ),
        .status_bad_frame   ( status_bad_frame      ),
        .status_good_frame  ( status_good_frame     ),

        .reset_read_ptr     ( reset_read_ptr        ),
        .fill_level         ( fill_level            )
    );

    assign axis_out.tstrb = '1;
endmodule

`default_nettype wire
