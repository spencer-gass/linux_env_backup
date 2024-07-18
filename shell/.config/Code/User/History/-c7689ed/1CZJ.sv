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
    //



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers
    //

    always #5 clk <= ~clk;

    ipv4_checksum_update dut
    (
        .clk              (  ),
        .update_req       (  ),
        .old_ip_checksum  (  ),
        .old_field        (  ),
        .new_field        (  ),
        .update_valid     (  ),
        .new_ip_checksum  (  )
    );

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk     <= 1'b0;

        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
            interconnect_sreset     = 1'b1;
            peripheral_sreset       = 1'b1;
            enable_tb_checks        = 1'b0;
            dac_data_in_valid_stb   = 1'b0;
            en_mmi_ctrl             = 1'b1;

            mmi_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            mmi_driver.randomize_r_latencies;
            mmi_driver.randomize_w_latency;


            @(posedge clk);
            #1;
            interconnect_sreset = 1'b0;

            @(posedge clk);
            #1;
            peripheral_sreset = 1'b0;
            enable_tb_checks = 1'b1;
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
