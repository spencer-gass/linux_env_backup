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
    // SECTION: localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces

    logic        clk;

    ipv4_header_t ip_hdr;

    AXIS_int #(
        .DATA_BYTES         ( 20 ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ipv4_header (
        .clk        (clk),
        .sresetn    (1'b1)
    );

    AXIS_int #(
        .DATA_BYTES         ( 1 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) ipv4_checksum_valid (
        .clk        (clk),
        .sresetn    (1'b1)
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic test_rand_valid;

        @(posedge clk);
        #0;

        ip_hdr.version  = $urandom();
        ip_hdr.hdr_len  = $urandom();
        ip_hdr.tos      = $urandom();
        ip_hdr.length   = $urandom();
        ip_hdr.id       = $urandom();
        ip_hdr.flags    = $urandom();
        ip_hdr.offset   = $urandom();
        ip_hdr.ttl      = $urandom();
        ip_hdr.protocol = $urandom();
        ip_hdr.src      = $urandom();
        ip_hdr.dst      = $urandom();

        ip_hdr_chksum = ipv4_checksum_gen_func(
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

        ipv4_header.tdata = {
            IP_VERSION,
            IP_IHL,
            ip_dscp,
            ip_ecn,
            ip_length,
            ip_identification,
            ip_flags,
            ip_fragment_offset,
            ip_ttl,
            ip_protocol,
            ip_hdr_chksum,
            ip_source_ip,
            ip_dest_ip
        };
        ipv4_header.tvalid = 1'b1;

        @(posedge clk);
        #0;
        ipv4_header.tvalid = 1'b0;

        wait(ipv4_checksum_valid.tvalid);
        `CHECK_EQUAL(ipv4_checksum_valid.tdata[0], 1'b1);

        @(posedge clk);

    endtask

    task automatic test_rand_invalid;

        automatic logic [15:0] chksum_calc;

        @(posedge clk);
        #0;

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

        ipv4_header.tdata = {
            IP_VERSION,
            IP_IHL,
            ip_dscp,
            ip_ecn,
            ip_length,
            ip_identification,
            ip_flags,
            ip_fragment_offset,
            ip_ttl,
            ip_protocol,
            ip_hdr_chksum,
            ip_source_ip,
            ip_dest_ip
        };
        ipv4_header.tvalid = 1'b1;

        @(posedge clk);
        #0;
        ipv4_header.tvalid = 1'b0;

        wait(ipv4_checksum_valid.tvalid);
        `CHECK_EQUAL(ipv4_checksum_valid.tdata[0], 1'b0);

        @(posedge clk);

    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers

    ipv4_checksum_verify dut (
        .ipv4_header         ( ipv4_header         ),
        .ipv4_checksum_valid ( ipv4_checksum_valid )
    );

    always #5 clk <= ~clk;

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk <= 1'b0;
        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
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
