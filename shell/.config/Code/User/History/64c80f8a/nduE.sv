// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Test Bench Package
**/

`default_nettype none


package p4_router_tb_pkg;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;

    localparam RAND = 0;
    localparam INC = 1;

    localparam real AVMM_CLK_PERIOD = 10.0;
    localparam real CORE_CLK_PERIOD = 3.333;
    localparam real PHYS_PORT_CLK_PERIOD = 6.4;

    localparam int MAX_NUM_PORTS_PER_ARRAY = 256;
    localparam int MAX_NUM_PORTS_PER_ARRAY_LOG = $clog2(MAX_NUM_PORTS_PER_ARRAY);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Type Definitions

    typedef int port_index_map_t [NUM_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function port_index_map_t create_port_index_map(
        input int num_phys_ports_per_array [NUM_AXIS_ARRAYS-1:0]
    );
        automatic port_index_map_t map = '{default: '{default: -1}};
        automatic int cnt = 0;
        for(int i=0; i<NUM_AXIS_ARRAYS; i++) begin
            for(int j=0; j<num_phys_ports_per_array[i]; j++) begin
                map[i][j] = cnt;
                cnt++;
            end
        end
        return map;
    endfunction

    enum {
        WIDTH_INDEX_CMD,
        ARRAY_INDEX_CMD
    } INDEX_CONV_CMDS;

    function int _get_port_width_or_array_index(
        input int port_index,
        input logic cmd,
        port_index_map_t port_index_map
    );
        for (int width_index=0; width_index<NUM_AXIS_ARRAYS; width_index++) begin
            for (int array_index=0; array_index<MAX_NUM_PORTS_PER_ARRAY; array_index++) begin
                if (port_index_map[width_index][array_index] == port_index) begin
                    case (cmd)
                        WIDTH_INDEX_CMD: return width_index;
                        ARRAY_INDEX_CMD: return array_index;
                        default: return -1;
                    endcase
                end
            end
        end
    endfunction

    function int get_port_width_index(
        input int port_index,
        port_index_map_t port_index_map
    );
        return _get_port_width_or_array_index(port_index, WIDTH_INDEX_CMD, port_index_map);
    endfunction

    function int get_port_array_index(
        input int port_index,
        port_index_map_t port_index_map
    );
        return _get_port_width_or_array_index(port_index, ARRAY_INDEX_CMD, port_index_map);
    endfunction

    function bit [PRIO_BITS-1:0] queue_to_prio(
        input bit [NUM_QUEUES_PER_EGR_PORT-1:0] queue
    );
        case (queue)
            7 : return 3;
            6 : return 2;
            5 : return 1;
            default: return 0
        endcase
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Classes

    // This was the best method I could find to create a task that could operate on a variable width data bus
    class axis_packet_formatter #(
        int BYTES_PER_WORD = 1,
        int MAX_PKT_WLEN = 1,
        int MTU_BYTES = 1500
    );
        static task get_packet (
            input  logic                         rand0_inc1,
            input  logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            ref    logic [MTU_BYTES*8-1:0]       packet_data
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
    endclass


endpackage