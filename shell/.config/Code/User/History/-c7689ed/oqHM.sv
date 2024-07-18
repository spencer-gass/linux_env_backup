// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for ipv4_checksum_update
 */
module ipv4_checksum_update_tb ();



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces


    logic        clk;

    logic        update_req;
    logic [15:0] old_ip_checksum;
    logic [15:0] old_field;
    logic [15:0] new_field;

    logic        update_valid;
    logic [15:0] new_ip_checksum;
    logic [15:0] checksum_out;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task init;
        begin
            update_req = 1'b0;
            old_ip_checksum = '0;
            old_field = '0;
            new_field = '0;
        end
    endtask

    task update_ipv4_checksum;
        input  [15:0] old_chksum_i;
        input  [15:0] old_field_i;
        input  [15:0] new_field_i;
        output [15:0] new_chksum_o;
    begin

        @(posedge clk);
        update_req = 1'b1;
        old_ip_checksum = old_chksum_i;
        old_field = old_field_i;
        new_field = new_field_i;

        @(posedge clk);
        update_req = 1'b0;
        wait (update_valid);
        new_chksum_o = new_ip_checksum;

    end
    endtask


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

    function automatic logic [15:0] checksum_update_func(
        input logic [15:0] hc,
        input logic [15:0] m,
        input logic [15:0] m_prime
    );
        automatic logic [15:0] sum;
        sum = add1c16b(~hc, ~m);
        sum = add1c16b(sum, m_prime);
        sum = ~sum;
        return sum;
    endfunction

    always #5 clk <= ~clk;

    ipv4_checksum_update dut
    (
        .clk              ( clk             ),
        .update_req       ( update_req      ),
        .old_ip_checksum  ( old_ip_checksum ),
        .old_field        ( old_field       ),
        .new_field        ( new_field       ),
        .update_valid     ( update_valid    ),
        .new_ip_checksum  ( new_ip_checksum )
    );

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

        `TEST_CASE("rand") begin
            automatic logic [15:0] old_checksum_i;
            automatic logic [15:0] old_field_i;
            automatic logic [15:0] new_checksum_i;

            for (int i; i < 100; i++) begin
                old_checksum_i = $urandom();
                old_field_i = $urandom();
                new_checksum_i = $urandom();
                update_ipv4_checksum(old_checksum_i, old_field_i, new_checksum_i, checksum_out);
                `CHECK_EQUAL(checksum_out, checksum_update_func(old_checksum_i, old_field_i, new_checksum_i));
                @(posedge clk);
            end
        end

    end

    `WATCHDOG(10us);
endmodule
