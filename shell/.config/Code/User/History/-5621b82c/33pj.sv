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

    // logic [0:MTU_BYTES*8-1]             tx_snoop_data_buf [NUM_AXIS_INTFS-1:0][NUM_PACKETS_TO_SEND-1:0];
    // logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf [NUM_AXIS_INTFS-1:0][NUM_PACKETS_TO_SEND-1:0];
    // logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr   [NUM_AXIS_INTFS-1:0];

    logic axis_in_overflow;
    logic axis_out_overflow;
    int   packet_count;


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

    // always_ff @(posedge clk_ifc.clk ) begin
    //     if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
    //         tx_snoop_data_buf       <= '{default: '{default: '0}};
    //         tx_snoop_blen_buf       <= '{default: '{default: 0}};
    //         tx_snoop_wr_ptr         <= '{default: '0};
    //         send_packet_req_d       <= '{default: '0};
    //     end else begin
    //         send_packet_req_d <= send_packet_req;
    //         for (int send_packet_port=0; send_packet_port<NUM_AXIS_INTFS; send_packet_port++) begin
    //             if (send_packet_req[send_packet_port] && !send_packet_req_d[send_packet_port]) begin
    //                 tx_snoop_data_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_data[send_packet_port];
    //                 tx_snoop_blen_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_byte_length[send_packet_port];
    //                 tx_snoop_wr_ptr[send_packet_port]++;
    //             end
    //         end
    //     end
    // end


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

            automatic logic [packet_out.DATA_BYTES*8-1:0]    data [$] = {};
            automatic logic                                  last [$] = {};
            automatic logic [packet_in.DATA_BYTES-1:0]       keep [$] = {};
            automatic logic [packet_in.DATA_BYTES-1:0]       strb [$] = {};
            automatic logic [packet_in.ID_WIDTH-1:0]         id   [$] = {};
            automatic logic [packet_in.DEST_WIDTH-1:0]       dest [$] = {};
            automatic logic [packet_in.USER_WIDTH-1:0]       user [$] = {};
            automatic logic [packet_in.DATA_BYTES*8-1:0]     data_word;
            automatic int                                    packet_byte_length;
            automatic logic [packet_in.DATA_BYTES-1:0]       keep_vec;

            packet_out.tready = 1'b1;


            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
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
                        data_word[i*8 +: 8] = $random();
                    end
                    data.push_back(data_word);
                    strb.push_back('1);
                    id.push_back($random());
                    dest.push_back($random());
                    user.push_back($random());
                    if ((word+1)*packet_in.DATA_BYTES >= packet_byte_length) begin
                        last.push_back(1'b1);
                        keep.push_back(keep_vec);
                    end else begin
                        last.push_back(1'b0);
                        keep.push_back('1);
                    end
                end
                driver_interface_inst.write_queue_ext(
                    .input_data(data),
                    .input_last(last),
                    .input_keep(keep),
                    .input_strb(strb),
                    .input_id(id),
                    .input_dest(dest),
                    .input_user(user)
                );
            end

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

            // Check packet counts
            `CHECK_EQUAL(packet_count, expected_count);
        end
    end

    `WATCHDOG(1ms);

endmodule