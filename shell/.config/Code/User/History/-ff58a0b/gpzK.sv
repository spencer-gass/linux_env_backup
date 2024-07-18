// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for ipv4_checksum_verify
 */

module ipv4_checksum_verify_tb();

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

    AXIS_int #(
        .DATA_BYTES         ( 48 )
        .ALLOW_BACKPRESSURE ( 0  )
    ) update_req (
        .clk        (clk),
        .sresetn    (1'b1)
    );

    AXIS_int #(
        .DATA_BYTES         ( 16 )
        .ALLOW_BACKPRESSURE ( 0  )
    ) new_checksum (
        .clk        (clk),
        .sresetn    (1'b1)
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic test_rand_valid;

        @(posedge clk);

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

        ip_hdr_chksum = ipv4_checksum_gen_func(
            eth_dest_mac,
            eth_src_mac,
            eth_type,
            ip_dscp,
            ip_ecn,
            ip_length,
            ip_identification,
            ip_flags,
            ip_fragment_offset,
            ip_ttl,
            ip_protocol,
            ip_source_ip,
            ip_dest_ip
        );

        req = 1'b1;

        @(posedge clk);
        req = 1'b0;

        wait(output_valid);
        `CHECK_EQUAL(chksum_valid, 1'b1);

        @(posedge clk);

    endtask

    task automatic test_rand_invalid;

        automatic logic [15:0] chksum_calc;

        @(posedge clk);

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

        ip_hdr_chksum      = $urandom();

        chksum_calc = ipv4_checksum_gen_func(
            eth_dest_mac,
            eth_src_mac,
            eth_type,
            ip_dscp,
            ip_ecn,
            ip_length,
            ip_identification,
            ip_flags,
            ip_fragment_offset,
            ip_ttl,
            ip_protocol,
            ip_source_ip,
            ip_dest_ip
        );

        if (ip_hdr_chksum == chksum_calc) ip_hdr_chksum++;

        req = 1'b1;

        @(posedge clk);
        req = 1'b0;

        wait(output_valid);
        `CHECK_EQUAL(chksum_valid, 1'b0);

        @(posedge clk);

    endtask

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers

    function automatic logic [15:0] ipv4_checksum_gen_func(
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
        input  var logic [31:0] ip_dest_ip
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
               ip_dest_ip[15: 0];

        sum = sum[15:0] + sum[19:16];
        sum = sum[15:0] + sum[16];
        return ~sum[15:0];

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
        input  var logic [31:0] ip_dest_ip
    );
        automatic logic [15:0] sum;

        sum = ipv4_checksum_gen_func(
                eth_dest_mac,
                eth_src_mac,
                eth_type,
                ip_dscp,
                ip_ecn,
                ip_length,
                ip_identification,
                ip_flags,
                ip_fragment_offset,
                ip_ttl,
                ip_protocol,
                ip_source_ip,
                ip_dest_ip
            );
        return ~|(~sum[15:0] + ip_hdr_chksum);

    endfunction

    ipv4_checksum_verify dut (
        .ipv4_header         ( ipv4_header         ),
        .ipv4_checksum_valid ( ipv4_checksum_valid )
    );

    always #5 clk <= ~clk;

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk     <= 1'b0;
            req     = 1'b0;
        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
            req     = 1'b0;
        end

        // submit random headers with valid checksums
        `TEST_CASE("rand_valid") begin
            for (int i; i < 100; i++) begin
                test_rand_valid;
            end
        end

        // submit random headers with invalid checksums
        `TEST_CASE("rand_invalid") begin
            for (int i; i < 100; i++) begin
                test_rand_invalid;
            end
        end

        // submit a mix of valid and invalid checksums
        `TEST_CASE("rand_mix") begin
            for (int i; i < 100; i++) begin
                if ($urandom % 2) begin
                    test_rand_valid;
                end else begin
                    test_rand_invalid;
                end
            end
        end
    end

    `WATCHDOG(10us);
endmodule
