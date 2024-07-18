// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * IP Checksum Updater
 *
 * Using Eq 3 from RFC-1624 (https://www.rfc-editor.org/rfc/rfc1624)
 * ~(~HC + ~m + m')
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module ipv4_checksum_update #()
(

    input  var logic        clk,

    input  var logic        update_req,
    input  var logic [15:0] old_ip_checksum,
    input  var logic [15:0] old_field,
    input  var logic [15:0] new_field,

    output var logic        update_valid,
    output var logic [15:0] new_ip_checksum

);

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


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    always_comb begin
        new_ip_checksum_comb = add1c16b(~old_ip_checksum, ~old_field);
        new_ip_checksum_comb = add1c16b(new_ip_checksum_comb, new_field);
        new_ip_checksum_comb = ~new_ip_checksum_comb;
    end

    always_ff @(posedge clk) begin
        update_valid <= update_req;
        new_ip_checksum <= new_ip_checksum_comb;
    end


endmodule

`default_nettype wire
