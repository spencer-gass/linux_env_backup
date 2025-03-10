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
    // SECTION: Parameters


    parameter int clock_period = 10;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import ipv4_checksum_tb_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    logic        clk;

    ipv4_header_t ip_hdr;

    AXIS_int #(
        .DATA_BYTES         ( 20 ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ipv4_header_axis (
        .clk        ( clk  ),
        .sresetn    ( 1'b1 )
    );

    AXIS_int #(
        .DATA_BYTES         ( 1 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) ipv4_checksum_valid_axis (
        .clk        ( clk  ),
        .sresetn    ( 1'b1 )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks


    task automatic test_rand_valid;

        @(posedge clk);
        #0;

        ip_hdr.version  = IPV4_VERSION;
        ip_hdr.hdr_len  = IPV4_IHL;
        ip_hdr.tos      = $urandom();
        ip_hdr.length   = $urandom();
        ip_hdr.id       = $urandom();
        ip_hdr.flags    = $urandom();
        ip_hdr.offset   = $urandom();
        ip_hdr.ttl      = $urandom();
        ip_hdr.protocol = $urandom();
        ip_hdr.hdr_chk  = '0;
        ip_hdr.src      = $urandom();
        ip_hdr.dst      = $urandom();

        ip_hdr.hdr_chk = ipv4_checksum_gen_func(ip_hdr);

        ipv4_header_axis.tdata  = {ip_hdr};
        ipv4_header_axis.tvalid = 1'b1;

        @(posedge clk);
        #1;
        ipv4_header_axis.tvalid = 1'b0;

        wait(ipv4_checksum_valid_axis.tvalid);
        #1
        `CHECK_EQUAL(ipv4_checksum_valid_axis.tdata[0], 1'b1);

        @(posedge clk);

    endtask

    task automatic test_rand_invalid;

        automatic logic [15:0] chksum_calc;

        @(posedge clk);
        #1;

        ip_hdr.version  = IPV4_VERSION;
        ip_hdr.hdr_len  = IPV4_IHL;
        ip_hdr.tos      = $urandom();
        ip_hdr.length   = $urandom();
        ip_hdr.id       = $urandom();
        ip_hdr.flags    = $urandom();
        ip_hdr.offset   = $urandom();
        ip_hdr.ttl      = $urandom();
        ip_hdr.protocol = $urandom();
        ip_hdr.hdr_chk  = '0;
        ip_hdr.src      = $urandom();
        ip_hdr.dst      = $urandom();

        ip_hdr.hdr_chk  = $urandom();

        chksum_calc = ipv4_checksum_gen_func(ip_hdr);

        if (ip_hdr.hdr_chk == chksum_calc) ip_hdr.hdr_chk++;

        ipv4_header_axis.tdata = {ip_hdr};
        ipv4_header_axis.tvalid = 1'b1;

        @(posedge clk);
        #1;
        ipv4_header_axis.tvalid = 1'b0;

        wait(ipv4_checksum_valid_axis.tvalid);
        #1;
        `CHECK_EQUAL(ipv4_checksum_valid_axis.tdata[0], 1'b0);

        @(posedge clk);

    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and Test Drivers


    ipv4_checksum_verify dut (
        .ipv4_header         ( ipv4_header_axis         ),
        .ipv4_checksum_valid ( ipv4_checksum_valid_axis )
    );

    always #clock_period/2 clk <= ~clk;

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk <= 1'b0;
        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
        end

        // Submit random headers with valid checksums
        `TEST_CASE("rand_valid") begin
            for (int i; i < 100; i++) begin
                test_rand_valid;
            end
        end

        // Submit random headers with invalid checksums
        `TEST_CASE("rand_invalid") begin
            for (int i; i < 100; i++) begin
                test_rand_invalid;
            end
        end

        // Submit a mix of valid and invalid checksums
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
