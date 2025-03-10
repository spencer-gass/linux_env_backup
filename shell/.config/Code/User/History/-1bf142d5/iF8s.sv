// CONFIDENTIAL
// Copyright (c) 2019 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Performance profiler for AXI streams.
 *
 * This module monitors an AXIS_int stream and measures the following:
 *     * errors transferred (indicated by tuser)
 *     * frames transferred (indicated by asserted tlast)
 *     * time back-pressured (source has data but sink not ready to receive)
 *     * time stalled (sink ready to receive but source has no data)
 *     * words transferred
 *
 * Timing values are measured by counting clock cycles internally, so that short events will not
 * be missed. Divisors (which could be 1) are applied to the outputs. Separate divisors are provided
 * for the active and idle times, since they might be much larger than the other time counts.
 *
 * The 'counts' output is for convenience: it is a packed form of the other counter outputs. Indices are:
 * 6: error_count
 * 5: frame_count
 * 4: backpressure_time
 * 3: stall_time
 * 2: active_time
 * 1: idle_time
 * 0: data_count
 */
module axis_profile #(
    parameter int     COUNT_WIDTH         = 32,   // Width of outputs, after the divisor.
    parameter int     WAIT_TIME_DIVISOR   = 100,  // Divisor applied to time counters.
    parameter int     ACTIVE_TIME_DIVISOR = 100,  // Divisor applied to active time.
    parameter int     IDLE_TIME_DIVISOR   = 100,  // Divisor applied to idle time.
    parameter int     BYTECOUNT_DIVISOR   = 1024, // Divisor applied to the word counter.
    parameter int     FRAME_COUNT_DIVISOR = 1,    // Divisor applied to the frame counter.
    parameter int     ERROR_COUNT_DIVISOR = 1,    // Divisor applied to the error counter.

    parameter int                   TUSER_WIDTH             = 1,
    parameter bit [TUSER_WIDTH-1:0] TUSER_BAD_FRAME_VALUE   = 1, // Selects what tuser value will qualify as an error
    parameter bit [TUSER_WIDTH-1:0] TUSER_BAD_FRAME_MASK    = 1, // Mask the bits of tuser when checking for error assertion
    parameter bit                   ONLY_BAD_FRAME_ON_TLAST = 1  // Selects whether error counter increments only on tlast or every tvalid with an error
) (
    AXIS_int.Monitor                   axis,
    input  var logic                   enable,             // Profiling only happens while this is high.
    input  var logic                   clear_stb,          // Zero counts.
    output var logic [COUNT_WIDTH-1:0] error_count,        // tuser-indicated errors xfr'd
    output var logic [COUNT_WIDTH-1:0] frame_count,        // frames xfr'd
    output var logic [COUNT_WIDTH-1:0] backpressure_time,  // time back-pressured / time_divisor
    output var logic [COUNT_WIDTH-1:0] stall_time,         // time stalled / time_divisor
    output var logic [COUNT_WIDTH-1:0] active_time,        // time active / active_divisor
    output var logic [COUNT_WIDTH-1:0] idle_time,          // time idle / idle_divisor
    output var logic [COUNT_WIDTH-1:0] data_count,         // words xfr'd / wordcount_divisor
    output var logic [COUNT_WIDTH-1:0] counts [6:0]        // Unpacked array of counts
);


    /////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(TUSER_WIDTH, axis.USER_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int     ERROR_DIV_WIDTH   = $clog2(WAIT_TIME_DIVISOR);
    localparam int     FRAME_DIV_WIDTH   = $clog2(WAIT_TIME_DIVISOR);
    localparam int     TIME_DIV_WIDTH    = $clog2(WAIT_TIME_DIVISOR);
    localparam int     ACTIVE_DIV_WIDTH  = $clog2(ACTIVE_TIME_DIVISOR);
    localparam int     IDLE_DIV_WIDTH    = $clog2(IDLE_TIME_DIVISOR);
    localparam int     BCOUNT_DIV_WIDTH  = $clog2(BYTECOUNT_DIVISOR);
    localparam int     VALID_BYTES_WIDTH = (axis.DATA_BYTES == 1) ? 1 : $clog2(axis.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    initial begin
        if (ERROR_COUNT_DIVISOR < 1) begin
            `FATAL_ERROR("ERROR_COUNT_DIVISOR must be >= 1.");
        end
        if (FRAME_COUNT_DIVISOR < 1) begin
            `FATAL_ERROR("FRAME_COUNT_DIVISOR must be >= 1.");
        end
        if (WAIT_TIME_DIVISOR < 1) begin
            `FATAL_ERROR("WAIT_TIME_DIVISOR must be >= 1.");
        end
        if (IDLE_TIME_DIVISOR < 1) begin
            `FATAL_ERROR("IDLE_TIME_DIVISOR must be >= 1.");
        end
        if (BYTECOUNT_DIVISOR < 1) begin
            `FATAL_ERROR("BYTECOUNT_DIVISOR must be >= 1.");
        end
        if (2**$clog2(BYTECOUNT_DIVISOR) != BYTECOUNT_DIVISOR) begin
            `FATAL_ERROR("BYTECOUNT_DIVISOR must be a nonzero power of two. It's currently %d", BYTECOUNT_DIVISOR);
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: These signals count up until the appropriate divisor, then increment the the output signal.


    logic [ERROR_DIV_WIDTH:0]    pre_error_count;
    logic [FRAME_DIV_WIDTH:0]    pre_frame_count;
    logic [TIME_DIV_WIDTH:0]     pre_bp_count;
    logic [TIME_DIV_WIDTH:0]     pre_stall_count;
    logic [ACTIVE_DIV_WIDTH:0]   pre_active_count;
    logic [IDLE_DIV_WIDTH:0]     pre_idle_count;
    logic [BCOUNT_DIV_WIDTH-1:0] pre_data_count;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: These signals pulse when the counts should be incremented.


    logic                       incr_error;
    logic                       incr_frame;
    logic                       incr_bp;
    logic                       incr_stall;
    logic                       incr_active;
    logic                       incr_idle;
    logic [VALID_BYTES_WIDTH:0] incr_data;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: This signal contains the number of meaningful bytes in the current transaction based on tkeep.


    logic [VALID_BYTES_WIDTH:0] num_valid_bytes;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign counts = '{
        error_count,
        frame_count,
        backpressure_time,
        stall_time,
        active_time,
        idle_time,
        data_count
    };


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    //Count valid bytes
    always_comb begin
        num_valid_bytes = '0;
        for(int b = 0; b < axis.DATA_BYTES; b++) begin
            num_valid_bytes += axis.tkeep[b];
        end
    end


    // Pre-divisor counts
    always_ff @(posedge axis.clk) begin
        if (~axis.sresetn || clear_stb) begin
            pre_error_count  <= '0;
            pre_frame_count  <= '0;
            pre_active_count <= '0;
            pre_bp_count     <= '0;
            pre_stall_count  <= '0;
            pre_idle_count   <= '0;
            pre_data_count   <= '0;

            incr_error  <= 1'b0;
            incr_frame  <= 1'b0;
            incr_active <= 1'b0;
            incr_bp     <= 1'b0;
            incr_stall  <= 1'b0;
            incr_idle   <= 1'b0;
            incr_data   <= 1'b0;
        end else if (enable) begin
            // Strobes
            incr_error  <= 1'b0;
            incr_frame  <= 1'b0;
            incr_active <= 1'b0;
            incr_bp     <= 1'b0;
            incr_stall  <= 1'b0;
            incr_idle   <= 1'b0;
            incr_data   <= 1'b0;

            if ((axis.tvalid & axis.tready) && ((axis.tuser & TUSER_BAD_FRAME_MASK) == TUSER_BAD_FRAME_VALUE) && (~ONLY_BAD_FRAME_ON_TLAST || axis.tlast)) begin   // error
                if (pre_error_count == ERROR_COUNT_DIVISOR-1) begin
                    incr_error      <= 1'b1;
                    pre_error_count <= '0;
                end else begin
                    pre_error_count <= pre_error_count + 1;
                end
            end

            if (axis.tvalid & axis.tready & axis.tlast) begin   // frame-end
                if (pre_frame_count == FRAME_COUNT_DIVISOR-1) begin
                    incr_frame      <= 1'b1;
                    pre_frame_count <= '0;
                end else begin
                    pre_frame_count <= pre_frame_count + 1;
                end
            end

            if (axis.tvalid & ~axis.tready) begin   // back-pressured
                if (pre_bp_count == WAIT_TIME_DIVISOR-1) begin
                    incr_bp      <= 1'b1;
                    pre_bp_count <= '0;
                end else begin
                    pre_bp_count <= pre_bp_count + 1;
                end
            end

            if (axis.tready & ~axis.tvalid) begin   // stalled
                if (pre_stall_count == WAIT_TIME_DIVISOR-1) begin
                    incr_stall      <= 1'b1;
                    pre_stall_count <= '0;
                end else begin
                    pre_stall_count <= pre_stall_count + 1;
                end
            end

            if (axis.tvalid & axis.tready) begin // active
                if (pre_active_count == ACTIVE_TIME_DIVISOR-1) begin
                    incr_active      <= 1'b1;
                    pre_active_count <= '0;
                end else begin
                    pre_active_count <= pre_active_count + 1;
                end

                if(BYTECOUNT_DIVISOR == 1) begin
                    incr_data <= num_valid_bytes;
                end else begin
                    {incr_data, pre_data_count} <= {{VALID_BYTES_WIDTH{1'b0}}, pre_data_count} + num_valid_bytes;
                end
            end

            if (~axis.tready & ~axis.tvalid) begin // idle
                if (pre_idle_count == IDLE_TIME_DIVISOR-1) begin
                    incr_idle      <= 1'b1;
                    pre_idle_count <= '0;
                end else begin
                    pre_idle_count <= pre_idle_count + 1;
                end
            end
        end
    end


    // Main counts.
    always_ff @(posedge axis.clk) begin
        if (~axis.sresetn || clear_stb) begin
            error_count       <= '0;
            frame_count       <= '0;
            backpressure_time <= '0;
            stall_time        <= '0;
            active_time       <= '0;
            idle_time         <= '0;
            data_count        <= '0;
        end else if (enable) begin
            if (incr_error) begin
                error_count <= error_count + 1;
            end

            if (incr_frame) begin
                frame_count <= frame_count + 1;
            end

            if (incr_bp) begin
                backpressure_time <= backpressure_time + 1;
            end

            if (incr_stall) begin
                stall_time <= stall_time + 1;
            end

            if (incr_active) begin
                active_time <= active_time + 1;
            end

            if (incr_idle) begin
                idle_time <= idle_time + 1;
            end

            data_count <= data_count + incr_data;
        end
    end
endmodule

`default_nettype wire
