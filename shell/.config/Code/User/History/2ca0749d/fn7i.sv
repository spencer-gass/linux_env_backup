// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * IP Checksum Updater
 *
 * Using Eq 3 from RFC-1624 (https://www.rfc-editor.org/rfc/rfc1624)
 * ~(~HC + ~m + m')
 *
 * AXIS backpressure is not allowed. tready should always be 1'b1
 *
 * ipv4_header AXIS interface tdata is expected to be in the following format:
 *    update_req.tdata[47:32] = old_ip_checksum
 *    update_req.tdata[31:16] = old_field
 *    update_req.tdata[15:0]  = new_field
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module ipv4_checksum_update (
    AXIS_int.Slave  update_req,
    AXIS_int.Master new_checksum
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration checks

    `ELAB_CHECK_EQUAL(update_req.DATA_BYTES, 12);
    `ELAB_CHECK_EQUAL(new_checksum.DATA_BYTES, 2);
    `ELAB_CHECK_EQUAL(update_req.ALLOW_BACKPRESSURE, 1'b0);
    `ELAB_CHECK_EQUAL(new_checksum.ALLOW_BACKPRESSURE, 1'b0);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function [15:0] add1c16b;
        input [15:0] a, b;
        logic [16:0] t;
        begin
            t = a+b;
            add1c16b = t[15:0] + t[16];
        end
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations

    logic [15:0] new_ip_checksum_comb;

    logic [15:0] old_ip_checksum;
    logic [15:0] old_field;
    logic [15:0] new_field;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign old_ip_checksum  = update_req.tdata[47:32];
    assign old_field        = update_req.tdata[31:16];
    assign new_field        = update_req.tdata[15:0];

    always_comb begin
        new_ip_checksum_comb = add1c16b(~old_ip_checksum, ~old_field);
        new_ip_checksum_comb = add1c16b(new_ip_checksum_comb, new_field);
        new_ip_checksum_comb = ~new_ip_checksum_comb;
    end

    always_ff @(posedge update_req.clk) begin
        new_ip_checksum.tready <= 1'b1; // Backpressure isn't supported
        new_ip_checksum.tvalid <= update_req.tvalid;
        new_ip_checksum.tdata <= new_ip_checksum_comb;
    end


endmodule

`default_nettype wire
