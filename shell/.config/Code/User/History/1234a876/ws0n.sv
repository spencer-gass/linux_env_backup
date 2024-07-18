// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * MPLS Ingress Test Bench Package
**/

package mpls_ingress_tb_pkg;

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;

    enum {
        WIDTH_INDEX_CMD,
        ARRAY_INDEX_CMD
    } INDEX_CONV_CMDS;

    function int _get_port_width_or_array_index(
        input int port_index,
        input logic cmd
    );
        for (int width_index=0; width_index<NUM_EGR_AXIS_ARRAYS; width_index++) begin
            for (int array_index=0; array_index<MAX_NUM_PORTS_PER_ARRAY; array_index++) begin
                if (EGR_PORT_INDEX_MAP[width_index][array_index] == port_index) begin
                    case (cmd)
                        WIDTH_INDEX_CMD: return width_index;
                        ARRAY_INDEX_CMD: return array_index;
                        default: return -1;
                    endcase
                end
            end
        end
    endfunction

    function int get_port_width_index(input int port_index);
        return _get_port_width_or_array_index(port_index, WIDTH_INDEX_CMD);
    endfunction

    function int get_port_array_index(input int port_index);
        return _get_port_width_or_array_index(port_index, ARRAY_INDEX_CMD);
    endfunction

    // This was the best method I could find to create a task that could operate on a variable width data bus
    class axis_packet_formatter #(
        int BYTES_PER_WORD = 1,
        int MAX_PKT_WLEN = 1,
        int MTU_BYTES = 1500
    );
        static task get_packet_data (
            input  logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            output logic [MTU_BYTES*8-1:0] packet_data
        ); begin
            for (integer b = 0; b<packet_byte_length; b++) begin
                packet_data[b*8 +: 8] = b % 256;
            end
        end
        endtask

        static task get_packet (
            input logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            ref logic   [BYTES_PER_WORD*8-1:0] packet_word_array [MAX_PKT_WLEN-1:0]
        ); begin
            automatic logic [MTU_BYTES*8-1:0] packet_data;
            get_packet_data(packet_byte_length, packet_data);
            for (integer w = 0; w*BYTES_PER_WORD < packet_byte_length; w++) begin
                automatic logic [BYTES_PER_WORD*8-1:0] next_word = 0;
                packet_word_array[w] = packet_data[w*BYTES_PER_WORD*8 +: BYTES_PER_WORD*8];
            end
        end
        endtask

    endclass

endpackage