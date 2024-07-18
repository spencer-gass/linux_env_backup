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

        @posedge clk;
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
        `TEST_CASE("mmi_transfers") begin
            check_mmi_transfers(RAND_RUNS);
        end

        // a random series of mmi reads and writes while peripheral reset is asserted
        `TEST_CASE("peripheral_reset") begin
            check_peripheral_reset(RAND_RUNS);
        end

        // a random series of mmi reads
        `TEST_CASE("rand_mmi_read") begin
            repeat(RAND_RUNS) begin
                rand_mmi_read();
            end
        end

        // a random series of mmi writes to the dac reg
        `TEST_CASE("rand_mmi_dac_write") begin
            en_mmi_ctrl = 1'b1;
            @(posedge clk);
            repeat(RAND_RUNS) begin
                rand_mmi_dac_write();
            end
        end

        // a random series of direct dac writes
        `TEST_CASE("rand_direct_dac_write") begin
            en_mmi_ctrl = 1'b0;
            @(posedge clk);
            repeat(RAND_RUNS) begin
                rand_direct_dac_write();
            end
        end

        // a random series of mmi and direct dac writes
        `TEST_CASE("rand_mmi_and_direct_dac_write") begin
            repeat(RAND_RUNS) begin
                randomized = $urandom();
                if(randomized) begin
                    en_mmi_ctrl = 1'b0;
                    @(posedge clk);
                    rand_direct_dac_write();
                end else begin
                    en_mmi_ctrl = 1'b1;
                    @(posedge clk);
                    rand_mmi_dac_write();
                end
            end
        end

        // write to dac_reg via MMI when en_mmi_ctrl=0
        `TEST_CASE("rand_mmi_dac_write_mmi_disabled") begin
            en_mmi_ctrl = 1'b0;
            @(posedge clk);
            repeat(RAND_RUNS) begin
                rand_mmi_dac_write();
            end
        end

        // direct writes to dac_reg when en_mmi_ctrl=1
        `TEST_CASE("rand_dac_write_mmi_enabled") begin
            en_mmi_ctrl = 1'b1;
            @(posedge clk);
            repeat(RAND_RUNS) begin
                strobe_dac_data_in($urandom);
            end
        end
    end

    `WATCHDOG(1us + (RAND_RUNS * 1us));
endmodule
