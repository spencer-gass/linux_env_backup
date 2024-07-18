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
        inout  [15:0] old_field_i;
        inout  [15:0] new_field_i;
        output [15:0] new_chksum_o;
    begin

        @(posedge clk);
        update_req = 1'b1;
        old_ip_checksum = old_chksum_i;
        old_field = old_field_i;
        new_field = new_field_i;

        wait (update_valid);
        new_chksum_o = new_ip_checksum;

    end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers


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
        end

    end

    `WATCHDOG(1us);
endmodule
