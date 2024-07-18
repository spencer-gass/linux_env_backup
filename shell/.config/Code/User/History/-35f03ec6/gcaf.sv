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

module ipv4_checksum_gen
(

    input  var logic        clk,

    input  var logic        req,
    input  var logic [47:0] eth_dest_mac,
    input  var logic [47:0] eth_src_mac,
    input  var logic [15:0] eth_type,
    input  var logic [5:0]  ip_dscp,
    input  var logic [1:0]  ip_ecn,
    input  var logic [15:0] ip_length,
    input  var logic [15:0] ip_identification,
    input  var logic [2:0]  ip_flags,
    input  var logic [12:0] ip_fragment_offset,
    input  var logic [7:0]  ip_ttl,
    input  var logic [7:0]  ip_protocol,
    input  var logic [31:0] ip_source_ip,
    input  var logic [31:0] ip_dest_ip,

    output var logic        valid,
    output var logic [15:0] ip_hdr_chksum

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: localparams

    localparam logic [3:0] ip_version = 4'd4;
    localparam logic [3:0] ip_ihl = 4'd5 ;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations

    logic [19:0] hdr_sum_1;
    logic [16:0] hdr_sum_2;
    logic        req_d;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    always_ff @(posedge clk) begin
        // Stage 1
        req_d <= req;
        hdr_sum_1 <= {ip_version, ip_ihl, s_ip_dscp, s_ip_ecn} +
                    s_ip_length +
                    s_ip_identification +
                    {s_ip_flags, s_ip_fragment_offset} +
                    {s_ip_ttl, s_ip_protocol} +
                    s_ip_source_ip[31:16] +
                    s_ip_source_ip[15: 0] +
                    s_ip_dest_ip[31:16] +
                    s_ip_dest_ip[15: 0];

        // Stage 2
        valid <= req_d
        ip_hdr_chksum <= hdr_sum_2[15:0];
    end

    always_comb begin
        hdr_sum_2 = hdr_sum_1[15:0] + hdr_sum_1[19:16];
        hdr_sum_2 = hdr_sum_2[15:0] + hdr_sum_2[16];
        hdr_sum_2 = ~hdr_sum_2;
    end

endmodule

`default_nettype wire
