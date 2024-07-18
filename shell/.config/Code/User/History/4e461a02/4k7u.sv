// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for ipv4_checksum_update
 */

module ipv4_checksum_verify_tb ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces


    logic        clk;

    logic        req;
    logic [47:0] eth_dest_mac;
    logic [47:0] eth_src_mac;
    logic [15:0] eth_type;
    logic [5:0]  ip_dscp;
    logic [1:0]  ip_ecn;
    logic [15:0] ip_length;
    logic [15:0] ip_identification;
    logic [2:0]  ip_flags;
    logic [12:0] ip_fragment_offset;
    logic [7:0]  ip_ttl;
    logic [15:0] ip_hdr_chksum;
    logic [7:0]  ip_protocol;
    logic [31:0] ip_source_ip;
    logic [31:0] ip_dest_ip;
    logic        output_valid;
    logic        chksum_valid;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers

    function [15:0] add1c16b;
        input [15:0] a, b;
        reg [16:0] t;
        begin
            t = a+b;
            add1c16b = t[15:0] + t[16];
        end
    endfunction

    function automatic logic ipv4_checksum_verify_func(
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
    );
        automatic logic [19:0] sum;

        sum = {4'd4, 4'd5, ip_dscp, ip_ecn} +
               ip_length +
               ip_identification +
               {ip_flags, ip_fragment_offset} +
               {ip_ttl, ip_protocol} +
               ip_source_ip[31:16] +
               ip_source_ip[15: 0] +
               ip_dest_ip[31:16] +
               ip_dest_ip[15: 0] +
               ip_hdr_chksum;

        sum = sum[15:0] + sum[19:16];
        sum = sum[15:0] + sum[16];
        return ~|sum[15:0];

    endfunction

    ipv4_checksum_verify dut (
        .clk                 ( clk                ),
        .req                 ( req                ),
        .eth_dest_mac        ( eth_dest_mac       ),
        .eth_src_mac         ( eth_src_mac        ),
        .eth_type            ( eth_type           ),
        .ip_dscp             ( ip_dscp            ),
        .ip_ecn              ( ip_ecn             ),
        .ip_length           ( ip_length          ),
        .ip_identification   ( ip_identification  ),
        .ip_flags            ( ip_flags           ),
        .ip_fragment_offset  ( ip_fragment_offset ),
        .ip_ttl              ( ip_ttl             ),
        .ip_hdr_chksum       ( ip_hdr_chksum      ),
        .ip_protocol         ( ip_protocol        ),
        .ip_source_ip        ( ip_source_ip       ),
        .ip_dest_ip          ( ip_dest_ip         ),
        .output_valid        ( output_valid       ),
        .chksum_valid        ( chksum_valid       )
    );
    always #5 clk <= ~clk;


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk     <= 1'b0;
        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
        end

        // a random series of mmi reads and writes
        `TEST_CASE("rand_valid") begin

            eth_dest_mac       = $urandom();
            eth_src_mac        = $urandom();
            eth_type           = $urandom();
            ip_dscp            = $urandom();
            ip_ecn             = $urandom();
            ip_length          = $urandom();
            ip_identification  = $urandom();
            ip_flags           = $urandom();
            ip_fragment_offset = $urandom();
            ip_ttl             = $urandom();
            ip_protocol        = $urandom();
            ip_source_ip       = $urandom();
            ip_dest_ip         = $urandom();

            ip_hdr_chksum      = ipv4_checksum_verify_func;

            `CHECK_EQUAL(checksum_out, 16'h0000);
            @(posedge clk);
        end

        `TEST_CASE("rand_valid") begin
        end
        `TEST_CASE("rand") begin
        end
    end

    `WATCHDOG(10us);
endmodule
