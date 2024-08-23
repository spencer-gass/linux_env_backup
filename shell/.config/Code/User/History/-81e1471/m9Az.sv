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
 *    update_req.tdata[31:16] = old_ip_checksum
 *    update_req.tdata[15:8]  = old_field
 *    update_req.tdata[7:0]   = new_field
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

    `ELAB_CHECK_EQUAL(update_req.DATA_BYTES, 4);
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

    assign old_ip_checksum  = update_req.tdata[31:16];
    assign old_field        = update_req.tdata[15:8];
    assign new_field        = update_req.tdata[7:0];

    // Unused AXIS interface signals
    assign update_req.tready     = 1'b1;
    assign new_checksum.tstrb    = '1;  // if unused, set to '1
    assign new_checksum.tkeep    = '1;  // if unused, set to '1
    assign new_checksum.tid      = '0;  // if unused, set to '0
    assign new_checksum.tdest    = '0;  // if unused, set to '0
    assign new_checksum.tuser    = '0;  // if unused, set to '0

    always_comb begin
        new_ip_checksum_comb = add1c16b(~old_ip_checksum, ~old_field);
        new_ip_checksum_comb = add1c16b(new_ip_checksum_comb, new_field);
        new_ip_checksum_comb = ~new_ip_checksum_comb;
    end

    always_ff @(posedge update_req.clk) begin
        new_checksum.tvalid <= update_req.tvalid;
        new_checksum.tlast  <= update_req.tvalid;
        new_checksum.tdata  <= new_ip_checksum_comb;
    end


endmodule

`default_nettype wire
