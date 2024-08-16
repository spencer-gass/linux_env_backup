// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * AXIS async FIFO that targets Xilinx distributed RAM
 * Ultrascale and Ultrascale+ have 6-input LUTs which can be used as 1-bit wide 64 deep rams.async_fifo_rst
 * This module is best used for narrow fifos less than 64-words deep but is also suitable for designs
 * where BRAM is limited or a FIFO with less than 32kb is needed.
 *
 * Doesn't support tid, tdest, or tuser
 * Since it's indended for shallow buffering, it operated like a word fifo, but if backpressure isn't allowed,
 *  it will drop words until the end of the packet and send a drop signal to the output clock domain
 */
module axis_dist_ram_fifo #(
    parameter int DEPTH         = 64,
    parameter bit OUTPUT_REG    = 1'b1,
    parameter bit ASYNC_CLOCKS  = 1'b0
) (
    AXIS_int.Slave  axis_in,
    AXIS_int.Master axis_out,

    output var logic axis_in_overflow,
    output var logic axis_out_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam CDC_DATA_WIDTH = axis_in.DATA_BYTES*8 + axis_in.DATA_BYTES + 1; // tdata + tkeep + tlast
    localparam GUARD_BAND = 1;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(axis_in.DATA_BYTES, axis_out.DATA_BYTES);
    `ELAB_CHECK_EQUAL(axis_in.ID_WIDTH, axis_out.ID_WIDTH);
    `ELAB_CHECK_EQUAL(axis_in.DEST_WIDTH, axis_out.DEST_WIDTH);
    `ELAB_CHECK_EQUAL(axis_in.USER_WIDTH, axis_out.USER_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    (* ram_style = "distributed" *) logic [CDC_DATA_WIDTH-1:0] async_buf [DEPTH-1:0];
    logic [CDC_DATA_WIDTH-1:0] async_buf_rd_data;
    logic [$clog2(DEPTH)-1:0] wr_ptr;
    logic [$clog2(DEPTH)-1:0] wr_ptr_cdc;
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [$clog2(DEPTH)-1:0] rd_ptr_cdc;

    logic axis_out.tvalid;
    logic reg_ce;

    logic full;
    logic empty;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign axis_in.tready = !full | !axis_in.ALLOW_BACKPRESSURE;

    always_ff @(posedge axis_in.clk) begin
        if (!axis_in.sresetn) begin
            wr_ptr <= '0;
            drop   <= 1'b0;
        end
        if (axis_in.tvalid & axis_in.tready) begin
            if (full) begin
                drop <= ~axis_in.tlast;
            end else begin
                wr_ptr++;
                async_buf[wr_ptr] <= {axis_in.tdata, axis_in.tkeep, axis_in.tlast};
            end
            if (axis_in.tlast) begin
                axis_in_overflow <= drop | full;
                drop <= 1'b0;
            end
        end
        full <= (wr_ptr - rd_ptr_cdc < DEPTH - GUARD_BAND) ? 1'b0 : 1'b1;
    end

    generate : cdc_g
        if (ASYNC_CLOCKS) begin

    // add gray coder cdc for pointers
        end else begin
            assign wr_ptr_cdc = wr_ptr;
            assign rd_ptr_cdc = rd_ptr;
        end
    endgenerate

    assign async_buf_rd_data = async_buf[rd_ptr];

    generate : read_controler_g
        if (OUPUT_REG) begin
            assign empty = rd_ptr == wr_ptr_cdc ? 1'b1 : 1'b0;
            assign rd_prime = ~empty & ~axis_out.tvalid;
            assign reg_ce = (rd_en | rd_prime);
            assign rd_en = axis_out.ready & axis_out.tvalid;

            always_ff @(posedge axis_out.clk) begin
                if (reg_ce) begin
                    axis_out.tvalid <= 1'b1;
                else if (rd_en) begin
                    axis_out.tvalid <= 1'b0;
                end

                if (!empty && (!axis_out.tvalid || reg_ce)) begin
                    rd_ptr++;
                end

                if (reg_ce) begin
                    axis_out.tdata  <= async_buf_rd_data[1 + axis_in.DATA_BYTES +: axis_in.DATA_BYTES*8];
                    axis_out.tkeep  <= async_buf_rd_data[1 +: axis_in.DATA_BYTES];
                    axis_out.tlast  <= async_buf_rd_data[0];
                end
            end


        end else begin
            assign axis_out.tvalid = rd_ptr != wr_ptr_cdc ? 1'b0 : 1'b1;
            assign axis_out.tdata  = async_buf_rd_data[1 + axis_in.DATA_BYTES +: axis_in.DATA_BYTES*8];
            assign axis_out.tkeep  = async_buf_rd_data[1 +: axis_in.DATA_BYTES];
            assign axis_out.tlast  = async_buf_rd_data[0];

            always_ff @(posedge axis_out.clk) begin
                if (axis_out.sresetn == 1'b0) begin
                    rd_ptr <= '0;
                end else if (axis_out.tready && axis_out.tvalid) begin
                    rd_ptr++;
                end
            end
        end
    endgenerate

endmodule

`default_nettype wire
