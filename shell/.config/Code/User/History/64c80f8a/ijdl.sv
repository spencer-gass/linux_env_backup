// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Test Bench Package
**/

`default_nettype none


package p4_router_tb_pkg;

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;

    // This was the best method I could find to create a task that could operate on a variable width data bus
    class axis_packet_formatter #(
        int BYTES_PER_WORD = 1,
        int MAX_PKT_WLEN = 1,
        int MTU_BYTES = 1500
    );
        static task get_packet_data (
            input logic                          rand0_inc1,
            input  logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            output logic [MTU_BYTES*8-1:0] packet_data
        ); begin
                for (int b = 0; b<packet_byte_length; b++) begin
                    if (rand0_inc1) begin
                        packet_data[b*8 +: 8] = b % 256;
                    end else begin
                        packet_data[b*8 +: 8] = $urandom();
                    end
                end
        end
        endtask

        static task get_packet (
            input logic                         rand0_inc1,
            input logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            ref logic   [BYTES_PER_WORD*8-1:0]  packet_word_array [MAX_PKT_WLEN-1:0],
            ref logic   [MTU_BYTES*8-1:0]       packet_vec
        ); begin
            // automatic logic [MTU_BYTES*8-1:0] packet_data;
            get_packet_data(rand0_inc1, packet_byte_length, packet_vec);
            for (int w = 0; w*BYTES_PER_WORD < packet_byte_length; w++) begin
                automatic logic [BYTES_PER_WORD*8-1:0] next_word = 0;
                packet_word_array[w] = packet_vec[w*BYTES_PER_WORD*8 +: BYTES_PER_WORD*8];
            end
        end
        endtask

    endclass

    localparam RAND = 0;
    localparam INC = 1;

    localparam real AVMM_CLK_PERIOD = 10.0;
    localparam real CORE_CLK_PERIOD = 3.333;
    localparam real PHYS_PORT_CLK_PERIOD = 6.4;
    localparam int POLICER_COLOR_BITS = 2;
    localparam int NUM_QUEUES_PER_EGR_PORT = 4;
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);


endpackage