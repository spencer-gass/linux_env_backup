// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module is an alternative to verilog-axis axis_adapter module.
 * it attempts to use fewer LUTs by shifting words rather than muxing.
 *
 * axis_adapter is not fully AXI4-Streaming compliant
 * 1. It does not slice or combine TUSER bits, instead it copies the last seen value to the output
 * 2. TSTRB is not connected and is defaulted to all '1
 * 3. TID and TUSER if changed every beat will be reflected on the output even though the AXI4-Streaming spec says this is not supported
 *    in this case however it would be the master on axis_in violating the specification.
 */
module axis_adapter_shift_register (
    AXIS_int.Slave  axis_in,  // AXI stream inputs
    AXIS_int.Master axis_out  // AXI stream output
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(axis_in.ID_WIDTH, axis_out.ID_WIDTH);
    `ELAB_CHECK_EQUAL(axis_in.DEST_WIDTH, axis_out.DEST_WIDTH);

    // See AXI4-Stream specification non-compliance point 1. above
    `ELAB_CHECK_EQUAL(axis_in.USER_WIDTH, axis_out.USER_WIDTH);

    // The width of the narrower signal must divide the width of the wider signal
    `ELAB_CHECK_EQUAL(UTIL_INTS::U_INT_GCD(axis_in.DATA_BYTES, axis_out.DATA_BYTES),
                      UTIL_INTS::U_INT_MIN(axis_in.DATA_BYTES, axis_out.DATA_BYTES));


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam bit EXPAND = axis_in.DATA_BYTES < axis_out.DATA_BYTES;
    localparam int NUM_SUBWORDS_PER_WORD = EXAND ? axis_out.DATA_BYTES/axis_in.DATA_BYTES : axis_in.DATA_BYTES/axis_out.DATA_BYTES;
    localparam int NUM_SUBWORDS_PER_WORD_LOG = $clog2(NUM_SUBWORDS_PER_WORD);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    generate
        if (EXPAND) begin
            logic [axis_out.DATA_BYTES*8-1 : 0] tdata_sr;
            logic [axis_out.DATA_BYTES-1   : 0] tkeep_sr;
            logic [NUM_SUBWORDS_PER_WORD_LOG :0] wcnt;
            logic                               next_word_ready;
            logic                               axis_in_tlast_d;

            assign axis_in.tready = ~(wcnt[NUM_SUBWORDS_PER_WORD_LOG] & axis_out.tvalid);

            always_ff @(posedge axis_in.clk) begin
                if (~axis_in.sresetn) begin
                    wcnt <= '0;
                    tkeep_sr <= '0;
                    axis_out.tvalid <= 1'b0;
                    next_word_ready <= 1'b0;
                    axis_in_tlast_d <= 1'b0;
                end else begin
                    axis_in_tlast_d <= axis_in.tlast & axis_in.tvalid & axis_in.tready;
                    if (axis_out.tready & axis_out.tvalid) begin
                        axis_out.tvalid <= next_word_ready;
                        if (next_word_ready) begin
                            axis_out.tdata <= tdata_sr;
                            axis_out.tkeep <= tkeep_sr;
                            axis_out.tuser <= axis_in.tuser;
                            axis_out.tdest <= axis_in.tdest;
                            axis_out.tid   <= axis_in.tid;
                            wcnt <= '0;
                            tkeep_sr <= '0;
                            next_word_ready <= 1'b0;
                        end
                    end
                    if (axis_in.tvalid && axis_in.tready) begin
                        tdata_sr <= {tdata_sr[axis_out.DATA_BYTES*8-axis_in.DATA_BYTES*8-1:0], axis_in.tdata};
                        tkeep_sr <= {tkeep_sr[axis_out.DATA_BYTES*8-axis_in.DATA_BYTES-1  :0], axis_in.tkeep};
                        wcnt <= wcnt + 1;
                    end
                    if (wcnt[NUM_SUBWORDS_PER_WORD_LOG] || axis_in_tlast_d) begin
                        if (axis_out.tvalid) begin
                            next_word_ready <= 1'b1;
                        end else begin
                            axis_out.tdata <= tdata_sr;
                            axis_out.tkeep <= tkeep_sr;
                            axis_out.tuser <= axis_in.tuser;
                            axis_out.tdest <= axis_in.tdest;
                            axis_out.tid   <= axis_in.tid;
                            wcnt <= '0;
                            tkeep_sr <= '0;
                            axis_out.tvalid <= 1'b1;
                        end
                        if (axis_in.tvalid && axis_in.tready) begin
                            tkeep_sr[axis_in.DATA_BYTES-1:0] <= axis_in.tkeep;
                            wcnt <= 1;
                        end
                    end
                end
            end
            assign axis_out.tstrb = '1;
        end else begin

        end
    endgenerate


endmodule

`default_nettype wire
