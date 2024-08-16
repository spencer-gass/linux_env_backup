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
 * Doesn't support tid, tdest, tstrb, or tuser
 * Operates as a word fifo so if back pressure isn't allowed and the fifo overflows, packets will be corrupted
 */
module axis_dist_ram_fifo #(
    parameter int DEPTH              = 64,
    parameter bit OUTPUT_REG         = 1'b1,
    parameter bit ALLOW_BACKPRESSURE = 1'b0,
    parameter bit ASYNC_CLOCKS       = 1'b0
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
    logic [$clog2(DEPTH)-1:0] occupancy;
    logic reg_ce;
    logic rd_en;
    logic full;
    logic empty;
    logic drop;
    logic drop_cdc;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign axis_in.tready = !full | !axis_in.ALLOW_BACKPRESSURE | !ALLOW_BACKPRESSURE;
    assign occupancy = wr_ptr - rd_ptr_cdc

    always_ff @(posedge axis_in.clk) begin
        if (!axis_in.sresetn) begin
            wr_ptr           <= '0;
            drop             <= 1'b0;
            axis_in_overflow <= 1'b0;
        end
        axis_in_overflow <= 1'b0;
        if (axis_in.tvalid & axis_in.tready) begin
            if (full) begin
                drop <= ~axis_in.tlast;
            end else begin
                wr_ptr <= wr_ptr+1;
                async_buf[wr_ptr] <= {axis_in.tdata, axis_in.tkeep, axis_in.tlast};
            end
            if (axis_in.tlast) begin
                axis_in_overflow <= drop | full;
                drop <= 1'b0;
            end
        end
        full <= (occupancy < DEPTH - GUARD_BAND) ? 1'b0 : 1'b1;
    end

    generate
        if (ASYNC_CLOCKS) begin : cdc_g

    // add gray coder cdc for pointers
        end else begin
            assign wr_ptr_cdc = wr_ptr;
            assign rd_ptr_cdc = rd_ptr;
            assign drop_cdc = drop | (full & axis_in.tvalid & axis_in.tready);
        end
    endgenerate

    assign async_buf_rd_data = async_buf[rd_ptr];
    assign axis_out_overflow = drop_cdc;

    generate
        if (OUTPUT_REG) begin : read_controler_g
            assign empty = rd_ptr == wr_ptr_cdc ? 1'b1 : 1'b0;
            assign reg_ce = (~axis_out.tvalid | rd_en) & ~empty;
            assign rd_en = axis_out.tready & axis_out.tvalid;

            always_ff @(posedge axis_out.clk) begin
                if (!axis_out.sresetn) begin
                        axis_out.tvalid <= 1'b0;
                    rd_ptr <= '0;
                    // axis_out.tdata  <= '0;
                    // axis_out.tkeep  <= '0;
                    axis_out.tlast  <= 1'b0;
                end else begin
                    if (reg_ce) begin
                        axis_out.tvalid <= 1'b1;
                        axis_out.tdata  <= async_buf_rd_data[1 + axis_in.DATA_BYTES +: axis_in.DATA_BYTES*8];
                        axis_out.tkeep  <= async_buf_rd_data[1 +: axis_in.DATA_BYTES];
                        axis_out.tlast  <= async_buf_rd_data[0];
                    end else if (rd_en) begin
                        axis_out.tvalid <= 1'b0;
                        // axis_out.tdata  <= '0;
                        // axis_out.tkeep  <= '0;
                        axis_out.tlast  <= 1'b0;
                    end

                    if (!empty && (!axis_out.tvalid || reg_ce)) begin
                        rd_ptr <= rd_ptr+1;
                    end
                end
            end

        end else begin
            assign axis_out.tvalid = rd_ptr != wr_ptr_cdc ? 1'b0 : 1'b1;
            assign axis_out.tdata  = async_buf_rd_data[1 + axis_in.DATA_BYTES +: axis_in.DATA_BYTES*8];
            assign axis_out.tkeep  = async_buf_rd_data[1 +: axis_in.DATA_BYTES];
            assign axis_out.tlast  = async_buf_rd_data[0];

            always_ff @(posedge axis_out.clk) begin
                if (!axis_out.sresetn) begin
                    rd_ptr <= '0;
                end else if (axis_out.tready && axis_out.tvalid) begin
                    rd_ptr <= rd_ptr+1;
                end
            end
        end
    endgenerate

    assign axis_out.tstrb = '1;
    assign axis_out.tid   = '0;
    assign axis_out.tdest = '0;
    assign axis_out.tuser = '0;

endmodule

`default_nettype wire
