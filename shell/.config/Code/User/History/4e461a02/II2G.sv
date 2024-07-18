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
            init;
        end

        `TEST_CASE_SETUP begin
            @(posedge clk);

        end

        // a random series of mmi reads and writes
        `TEST_CASE("RFC-1624_example") begin
            update_ipv4_checksum(16'hDD2F, 16'h5555, 16'h3285, checksum_out);
            `CHECK_EQUAL(checksum_out, 16'h0000);
            @(posedge clk);
        end


        end

    end

    `WATCHDOG(10us);
endmodule
