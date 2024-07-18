// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * IP Checksum Verifier
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module ipv4_checksum_verify
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
    input  var logic [15:0] ip_hdr_chksum,
    input  var logic [7:0]  ip_protocol,
    input  var logic [31:0] ip_source_ip,
    input  var logic [31:0] ip_dest_ip,

    output var logic        output_valid,
    output var logic        chksum_valid

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: localparams

    localparam GEN_DELAY = 2;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations

    logic                       chksum_calc_valid;
    logic [15:0]                chksum_calc;

    logic [GEN_DELAY:1]         req_d;
    logic [GEN_DELAY:1] [15:0]  chksum_in_d ;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ipv4_checksum_gen chksum_gen (
        .clk                  ( clk                ),
        .req                  ( req                ),
        .eth_dest_mac         ( eth_dest_mac       ),
        .eth_src_mac          ( eth_src_mac        ),
        .eth_type             ( eth_type           ),
        .ip_dscp              ( ip_dscp            ),
        .ip_ecn               ( ip_ecn             ),
        .ip_length            ( ip_length          ),
        .ip_identification    ( ip_identification  ),
        .ip_flags             ( ip_flags           ),
        .ip_fragment_offset   ( ip_fragment_offset ),
        .ip_ttl               ( ip_ttl             ),
        .ip_protocol          ( ip_protocol        ),
        .ip_source_ip         ( ip_source_ip       ),
        .ip_dest_ip           ( ip_dest_ip         ),
        .valid                ( chksum_calc_valid  ),
        .ip_hdr_chksum        ( chksum_calc        )
    );

    always_ff @(posedge clk) begin
        req_d <= {req_d[GEN_DELAY-1:1], req};
        chksum_in_d <= {chksum_in_d[GEN_DELAY:1], ip_hdr_chksum};

        output_valid <= req_d[GEN_DELAY];
        chksum_valid <= (chksum_calc == chksum_in_d[GEN_DELAY]) ? 1'b1 : 1'b0;
    end

endmodule

`default_nettype wire
