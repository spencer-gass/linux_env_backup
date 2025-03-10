// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for axis_dist_ram_fifo
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps


module axis_dist_ram_fifo_tb();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int DATA_BYTES = 8;
    parameter int FIFO_DEPTH = 32;
    parameter int MTU_BYTES = 1500;                // MTU for the router
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic axis_in_overflow;
    logic axis_out_overflow;
    int   packet_count;

    logic [packet_in.DATA_BYTES*8-1:0]     fifo_model_data_queue [$] = {};
    logic                                  fifo_model_last_queue [$] = {};
    logic [packet_in.DATA_BYTES-1:0]       fifo_model_keep_queue [$] = {};
    logic [packet_in.DATA_BYTES-1:0]       fifo_model_strb_queue [$] = {};
    logic [packet_in.ID_WIDTH-1:0]         fifo_model_id_queue   [$] = {};
    logic [packet_in.DEST_WIDTH-1:0]       fifo_model_dest_queue [$] = {};
    logic [packet_in.USER_WIDTH-1:0]       fifo_model_user_queue [$] = {};


    /////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES )
    ) packet_in (
        .clk     (clk_ifc.clk                                 ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES )
    ) packet_out (
        .clk     (clk_ifc.clk                                 ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic implemenatation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Simulation clocks

    always #5 clk_ifc.clk <= ~clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Generator

    AXIS_driver # (
        .DATA_BYTES ( packet_in.DATA_BYTES  ),
        .ID_WIDTH   ( packet_in.ID_WIDTH    ),
        .DEST_WIDTH ( packet_in.DEST_WIDTH  ),
        .USER_WIDTH ( packet_in.USER_WIDTH  )
    ) driver_interface_inst (
        .clk     ( packet_in.clk        ),
        .sresetn ( packet_in.sresetn    )
    );

    AXIS_driver_module driver_module_inst (
        .control ( driver_interface_inst ),
        .o       ( packet_in             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    axis_dist_ram_fifo #(
        .DEPTH         ( FIFO_DEPTH   ),
        .ASYNC_CLOCKS  ( 1'b1         )
    ) dut (
        .axis_in            ( packet_in         ),
        .axis_out           ( packet_out        ),
        .axis_in_overflow   ( axis_in_overflow  ),
        .axis_out_overflow  ( axis_out_overflow )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  FIFO model

    // strb, id, dest, and user aren't supported
    always_ff @(posedge clk_ifc.clk ) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            fifo_model_data_queue.delete();
            fifo_model_last_queue.delete();
            fifo_model_keep_queue.delete();
        end else begin
            if (packet_in.tvalid && packet_in.tready) begin
                fifo_model_data_queue.push_back(packet_in.tdata);
                fifo_model_keep_queue.push_back(packet_in.tkeep);
                fifo_model_last_queue.push_back(packet_in.tlast);
            end
            if (packet_out.tvalid && packet_out.tready) begin
                `CHECK_EQUAL(fifo_model_data_queue.pop_front(), packet_out.tdata);
                `CHECK_EQUAL(fifo_model_keep_queue.pop_front(), packet_out.tkeep);
                `CHECK_EQUAL(fifo_model_last_queue.pop_front(), packet_out.tlast);
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Counters

    always_ff @(posedge clk_ifc.clk) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            packet_count = 0;
        end else begin
            packet_count += (packet_in.tvalid & packet_in.tready & packet_in.tlast);
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packets(
        input int num_packets
    );
        automatic logic [packet_in.DATA_BYTES*8-1:0]    data_queue [$] = {};
        automatic logic                                  last_queue [$] = {};
        automatic logic [packet_in.DATA_BYTES-1:0]       keep_queue [$] = {};
        automatic logic [packet_in.DATA_BYTES-1:0]       strb_queue [$] = {};
        automatic logic [packet_in.ID_WIDTH-1:0]         id_queue   [$] = {};
        automatic logic [packet_in.DEST_WIDTH-1:0]       dest_queue [$] = {};
        automatic logic [packet_in.USER_WIDTH-1:0]       user_queue [$] = {};
        automatic logic [packet_in.DATA_BYTES*8-1:0]     data;
        automatic int                                    packet_byte_length;
        automatic logic [packet_in.DATA_BYTES-1:0]       keep_vec;


        for (int pkt=0; pkt<num_packets; pkt++) begin

            packet_byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
            keep_vec = '0;
            for (int b=0; b<packet_in.DATA_BYTES; b++) begin
                if (packet_byte_length % packet_in.DATA_BYTES == 0) begin
                    keep_vec[b] = 1'b1;
                end else if (b < packet_byte_length % packet_in.DATA_BYTES) begin
                    keep_vec[b] = 1'b1;
                end
            end
            for (integer word = 0; word * packet_in.DATA_BYTES < packet_byte_length; word++) begin
                for (int i=0; i<packet_in.DATA_BYTES; i++) begin
                    data[i*8 +: 8] = $urandom();
                end
                data_queue.push_back(data);
                // strb, id, dest, and user aren't supported
                strb_queue.push_back('1);
                id_queue.push_back('0);
                dest_queue.push_back('0);
                user_queue.push_back('0);
                if ((word+1)*packet_in.DATA_BYTES >= packet_byte_length) begin
                    last_queue.push_back(1'b1);
                    keep_queue.push_back(keep_vec);
                end else begin
                    last_queue.push_back(1'b0);
                    keep_queue.push_back('1);
                end
            end
            driver_interface_inst.write_queue_ext(
                .input_data(data_queue),
                .input_last(last_queue),
                .input_keep(keep_queue),
                .input_strb(strb_queue),
                .input_id(id_queue),
                .input_dest(dest_queue),
                .input_user(user_queue)
            );

            data_queue.delete();
            last_queue.delete();
            keep_queue.delete();
            strb_queue.delete();
            id_queue.delete();
            dest_queue.delete();
            user_queue.delete();

        end

    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
        end

        `TEST_CASE_SETUP begin
            @(posedge clk_ifc.clk);
            sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
            repeat (10) @(posedge clk_ifc.clk);
            sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge clk_ifc.clk);
        end

        // Send packets to all interfaces simultaneously
        `TEST_CASE("smoke") begin

            automatic int expected_count = NUM_PACKETS_TO_SEND;

            packet_out.tready = 1'b1;

            fork
                begin : packet_tx_thread
                    send_packets(NUM_PACKETS_TO_SEND);
                end
                begin : overflow_monitor_thread
                    while(1) begin
                        @(posedge clk_ifc.clk);
                        #1;
                        `CHECK_EQUAL(axis_in_overflow, 1'b0);
                    end
                end
            join_any

            disable overflow_monitor_thread;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

            // Check packet counts
            `CHECK_EQUAL(packet_count, expected_count);

            // Verify that the fifo model is empty
            `CHECK_EQUAL(fifo_model_data_queue.size(), 0);
            `CHECK_EQUAL(fifo_model_keep_queue.size(), 0);
            `CHECK_EQUAL(fifo_model_last_queue.size(), 0);
        end

        `TEST_CASE("overflow") begin

            automatic int expected_count = NUM_PACKETS_TO_SEND;
            automatic bit overflow_detected = 1'b0;

            packet_out.tready = 1'b0;

            fork
                begin : packet_tx_thread
                    send_packets(NUM_PACKETS_TO_SEND);
                end
                begin : overflow_monitor_thread
                    while(1) begin
                        @(posedge clk_ifc.clk);
                        #1;
                        overflow_detected |= axis_in_overflow;
                    end
                end
            join_any

            disable overflow_monitor_thread;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

            // Check overflow
            `CHECK_EQUAL(overflow_detected, 1'b1);
        end
    end

    `WATCHDOG(1ms);

endmodule
