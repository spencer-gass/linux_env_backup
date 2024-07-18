// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for dvbs2_bb_frame_counter_avmm.
 */
module dvbs2x_tx_symb_rate_divider_avmm_tb ();
    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;

    parameter bit PROTOCOL_CHECK       = 1;
    parameter int RAND_RUNS            = 500;

    parameter  int W_MAX_RESPONSE_TIME = 1000;
    parameter  int R_MAX_RESPONSE_TIME = 1000;
    parameter  int MAX_LATENCY         = 5;

    parameter  int DATALEN             = 32;
    parameter  int ADDRLEN             = 15;
    parameter  int BURSTLEN            = 11;
    parameter  int BURST_CAPABLE       = 1;

    parameter  bit [15:0] MODULE_VERSION = 1;
    parameter  bit [15:0] MODULE_ID      = 10;

    enum int {
        ADDR_SYMB_RATE_SEL,
        ADDR_SYMB_RATE,
        TOTAL_AVMM_REGS
    } register_address;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) peripheral_sreset_ifc ();

    AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();

    // AVMM driver class
    avmm_m_test_driver #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm_driver;

    `MAKE_AVMM_MONITOR(avmm_monitor, avmm);

    generate
        if (PROTOCOL_CHECK) begin : gen_protocol_check
            avmm_protocol_check #(
                .W_MAX_RESPONSE_TIME   ( W_MAX_RESPONSE_TIME ),
                .R_MAX_RESPONSE_TIME   ( R_MAX_RESPONSE_TIME )
            ) protocol_check_inst (
                .clk_ifc    ( clk_ifc      ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor )
            );
        end
    endgenerate

    // DUT signals

    // Avalon Master control signals
    var logic [DATALEN/8-1:0]          avmm_byteenable_queue[$];
    var logic [1:0]                    avmm_response;
    var logic [BURSTLEN-1:0]           avmm_burstcount;

    var logic [1:0]                    avmm_response_queue[$];
    var logic [DATALEN-1:0]            avmm_writedata_queue[$];
    var logic [DATALEN-1:0]            avmm_readdata_queue[$];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers


    dvbs2x_tx_symb_rate_divider_avmm #(
        .MODULE_ID         ( MODULE_ID ),
        .SYMB_RATE_MSPS    ( HDR_DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::SYMB_RATE_MSPS )
    ) dvbs2x_tx_symb_rate_divider_avmm_inst (
        .clk_ifc_sample               ( clk_ifc.Input                       ),
        .sreset_ifc_sample_device     ( sreset_ifc.ResetIn                  ),
        .clk_ifc_avmm                 ( clk_ifc_156_25.Input                    ),
        .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect.ResetIn  ),
        .sreset_ifc_avmm_peripheral   ( sreset_ifc_156_25_peripheral.ResetIn    ),
        .axis_in_dvbs2x               ( axis_mod_pre_symb_rate.Slave            ),
        .axis_out_dvbs2x              ( axis_mod_samples[0].Master              ),
        .avmm                         ( avmm_dev_ifc[AVMM_TX_SYMB_RATE_DIVIDER] )
    );


    always #10 clk_ifc.clk <= ~clk_ifc.clk;

    // Wait for the reset sequence to complete by periodically performing an AVMM read on the
    // initdone/up avmm common register
    task automatic wait_initdone;
        begin
            logic [DATALEN-1:0] initdone = 0;

            while(!initdone[0]) begin
                avmm_read_data(AVMM_COMMON_STATUS_DEVICE_STATE<<2);
                initdone = read_data;
                repeat(10) @(posedge clk_ifc.clk);
            end
        end
    endtask

    // Performs an AVMM Read and associated response check
    task automatic avmm_read_data;
        input logic [ADDRLEN-1:0] avmm_read_address;
        begin
            avmm_driver.read_data(
                .address        ( avmm_read_address   ),
                .readdata_queue ( avmm_readdata_queue ),
                .byteenable     ( 0                   ),
                .burstcount     ( 1                   ),
                .response_queue ( avmm_response_queue )
            );
            `CHECK_EQUAL(avmm.RESPONSE_OKAY, avmm_response_queue.pop_front(), "Incorrect read response received.");
            read_data = avmm_readdata_queue.pop_front();
        end
    endtask

    // Performs an AVMM Write and associated data and response checks
    task automatic avmm_write_data;
        input logic [ADDRLEN-1:0] avmm_write_address;
        input logic [DATALEN-1:0] avmm_write_data;
        begin
            avmm_byteenable_queue.push_front('1);
            avmm_writedata_queue.push_front(avmm_write_data);
            avmm_driver.write_data(
                .address          ( avmm_write_address    ),
                .writedata_queue  ( avmm_writedata_queue  ),
                .byteenable_queue ( avmm_byteenable_queue ),
                .burstcount       ( 1                     ),
                .response         ( avmm_response         )
            );
            `CHECK_EQUAL(avmm.RESPONSE_OKAY, avmm_response, "Incorrect write response received.");
            `CHECK_EQUAL(DUT.regs[avmm_write_address/4 - AVMM_COMMON_NUM_REGS], avmm_write_data, "Incorrect data written.");
            avmm_writedata_queue.delete();
        end
    endtask

    `TEST_SUITE begin
        // DO NOT place code here
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk_ifc.clk = 1'b0;

            avmm_driver = new (
                .clk_ifc                 ( clk_ifc                 ),
                .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
                .avmm                    ( avmm                    )
            );
        end

        `TEST_CASE_SETUP begin
            avmm_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            avmm_driver.set_random_latencies();

            interconnect_sreset_ifc.reset = 1'b1;
            peripheral_sreset_ifc.reset   = 1'b1;

            golden_total_frame_count = '0;
            golden_ram               = '{default: '0};

            avmm_driver.init();

            @(posedge clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = 1'b0;

            @(posedge clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = 1'b0;

            wait_initdone();

            // Fill up RAM with random values
            repeat (RAND_RUNS) begin
                // Select random modcod for data-frame transmission
                modcod = $urandom();
                @(posedge clk_ifc.clk);

                // Pulse a random number of increment_frame_count_stb, waiting a random increment each time
                repeat($urandom_range(5,15)) begin
                    pulse_increment_stb();
                    wait_frame();
                end
            end
        end

        `TEST_CASE("reset_test") begin
            // Write 1 to bit 0 of control register, issuing count reset
            avmm_write_data((CONTROL_ADDR + AVMM_COMMON_NUM_REGS) << 2, 1);
            golden_total_frame_count = '0;
            golden_ram               = '{default: '0};

            // Ensure that all values have been reset
            total_count_test();

            for (int i = 0; i < RAM_WIDTH; i++) begin
                frame_count_test(i);
            end
        end
    end

    `WATCHDOG(5ms);
endmodule
