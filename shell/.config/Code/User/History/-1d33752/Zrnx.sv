// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * AXIS FIFO that targets Xilinx distributed RAM.
 * Parameterized sync or async read and write clocks.
 * Ultrascale and Ultrascale+ have 6-input LUTs which can be used as 1-bit wide 64 deep RAMs.
 * This module is best used for narrow fifos less than 64-words deep but is also suitable for designs
 * where BRAM is limited or a FIFO with less than 1 BRAM (32kb) is needed.
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
    localparam GUARD_BAND = 2;
    localparam DEPTH_LOG = $clog2(DEPTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation

    `ELAB_CHECK_EQUAL(axis_in.DATA_BYTES, axis_out.DATA_BYTES);
    `ELAB_CHECK_EQUAL(2**$clog2(DEPTH), DEPTH); // ensure depth is a power of 2


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    (* ram_style = "distributed" *) logic [CDC_DATA_WIDTH-1:0] async_buf [DEPTH-1:0];
    logic [CDC_DATA_WIDTH-1:0] async_buf_rd_data;
    logic [DEPTH_LOG-1:0] wr_ptr;
    logic [DEPTH_LOG-1:0] wr_ptr_gc;
    (* ASYNC_REG = "TRUE" *) logic [DEPTH_LOG-1:0] wr_ptr_rr [1:0];
    logic [DEPTH_LOG-1:0] wr_ptr_gc_cdc;
    logic [DEPTH_LOG-1:0] rd_ptr_gc;
    logic [DEPTH_LOG-1:0] rd_ptr_gc_reg;
    (* ASYNC_REG = "TRUE" *) logic [DEPTH_LOG-1:0] rd_ptr_rr [1:0];
    logic [DEPTH_LOG-1:0] rd_ptr;
    logic [DEPTH_LOG-1:0] rd_ptr_cdc;
    logic [DEPTH_LOG-1:0] occupancy;
    logic reg_ce;
    logic rd_en;
    logic full;
    logic empty;
    logic drop;
    (* ASYNC_REG = "TRUE" *) logic [1:0] drop_rr;
    logic drop_cdc;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Write Controller

    assign axis_in.tready = !full | !axis_in.ALLOW_BACKPRESSURE | !ALLOW_BACKPRESSURE;
    assign occupancy = wr_ptr - rd_ptr_cdc;

    always_ff @(posedge axis_in.clk) begin
        if (!axis_in.sresetn) begin
            wr_ptr           <= '0;
            wr_ptr_gc        <= '0;
            drop             <= 1'b0;
            axis_in_overflow <= 1'b0;
            full             <= 1'b0;
        end
        axis_in_overflow <= 1'b0;
        wr_ptr_gc <= wr_ptr ^ (wr_ptr >> 1); // gray code write pointer for clock domain crossing

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
        full <= (occupancy >= DEPTH - GUARD_BAND) ? 1'b1 : 1'b0;
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clock Domain Crossing

    generate
        if (ASYNC_CLOCKS) begin : cdc_g
            // synchronize gray coded write pointer to axis_out.clk domain
            always_ff @(posedge axis_out.clk) begin
                wr_ptr_rr <= {wr_ptr_rr[0], wr_ptr_gc};
            end
            assign wr_ptr_gc_cdc = wr_ptr_rr[1]; // just need to compare if wr_ptr==rd_ptr. no need to do gray code to binary conversion

            // synchronize gray coded read pointer to axis_in.clk domain
            assign rd_ptr_gc = rd_ptr ^ (rd_ptr >> 1);
            always_ff @(posedge axis_out.clk) begin
                rd_ptr_gc_reg <= rd_ptr_gc;
            end
            always_ff @(posedge axis_in.clk) begin
                rd_ptr_rr <= {rd_ptr_rr[0], rd_ptr_gc_reg};
            end

            // Convert gray code to binary for buffer occupancy calculation
            always_comb begin
                rd_ptr_cdc[DEPTH_LOG-1] = rd_ptr_rr[1][DEPTH_LOG-1];
                for (int i = DEPTH_LOG-2; i >= 0; i--) begin
                    rd_ptr_cdc[i] = rd_ptr_cdc[i+1] ^ rd_ptr_rr[1][i];
                end
            end

            // synchronize drop indicator
            always_ff @(posedge axis_out.clk) begin
                drop_rr <= {drop_rr[0], drop | (full & axis_in.tvalid & axis_in.tready)};
            end
            assign drop_cdc = drop_rr[1];
            assign empty = rd_ptr_gc == wr_ptr_gc_cdc ? 1'b1 : 1'b0;

        end else begin // bypass gray coders and synchronizers if the clocks are synchronous
            assign wr_ptr_gc_cdc = '0;
            assign rd_ptr_cdc = '0;
            assign drop_cdc = drop | (full & axis_in.tvalid & axis_in.tready);
            assign empty = rd_ptr == wr_ptr ? 1'b1 : 1'b0;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Read Controller

    assign async_buf_rd_data = async_buf[rd_ptr];
    assign axis_out_overflow = drop_cdc;
    assign reg_ce = (~axis_out.tvalid | rd_en) & ~empty;
    assign rd_en = axis_out.tready & axis_out.tvalid;

    always_ff @(posedge axis_out.clk) begin
        if (!axis_out.sresetn) begin
            axis_out.tvalid <= 1'b0;
            rd_ptr <= '0;
            axis_out.tlast  <= 1'b0;
        end else begin
            if (reg_ce) begin
                axis_out.tvalid <= 1'b1;
                axis_out.tdata  <= async_buf_rd_data[1 + axis_in.DATA_BYTES +: axis_in.DATA_BYTES*8];
                axis_out.tkeep  <= async_buf_rd_data[1 +: axis_in.DATA_BYTES];
                axis_out.tlast  <= async_buf_rd_data[0];
            end else if (rd_en) begin
                axis_out.tvalid <= 1'b0;
                axis_out.tlast  <= 1'b0;
            end

            if (!empty && (!axis_out.tvalid || reg_ce)) begin
                rd_ptr <= rd_ptr+1;
            end
        end
    end

    // Tie off unused AXIS signals
    assign axis_out.tstrb = '1;
    assign axis_out.tid   = '0;
    assign axis_out.tdest = '0;
    assign axis_out.tuser = '0;

endmodule

`default_nettype wire
