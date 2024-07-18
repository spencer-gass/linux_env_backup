// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Package
**/

`default_nettype none

package p4_router_pkg;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_params_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Common Constants and Functions

    enum {
        INDEX_8B,
        INDEX_16B,
        INDEX_32B,
        INDEX_64B,
        NUM_AXIS_ARRAYS
    } port_width_indecies;

    localparam int NUM_ING_AXIS_ARRAYS = NUM_AXIS_ARRAYS;
    localparam int NUM_EGR_AXIS_ARRAYS = NUM_AXIS_ARRAYS;

    function int get_max_num_ports_per_array(
        input int array [NUM_AXIS_ARRAYS-1:0]
    );
        automatic int max = 0;
        for (int i=0; i<NUM_AXIS_ARRAYS; i++) begin
            if (array[i] > max) begin
                max = array[i];
            end
        end
        return max;
    endfunction

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Calculated Constants

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ingress Constants

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_ING_PHYS_PORTS,
                                                                             NUM_32B_ING_PHYS_PORTS,
                                                                             NUM_16B_ING_PHYS_PORTS,
                                                                             NUM_8B_ING_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_ING_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_ING_PHYS_PORTS_PER_ARRAY);

    typedef int ing_port_index_map_t [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_ING_PORTS_PER_ARRAY-1:0];

    function ing_port_index_map_t create_ing_port_index_map();
        automatic ing_port_index_map_t map = '{default: '{default: -1}};
        automatic int cnt = 0;
        for(int i=0; i<NUM_ING_AXIS_ARRAYS; i++) begin
            for(int j=0; j<NUM_ING_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                map[i][j] = cnt;
                cnt++;
            end
        end
        return map;
    endfunction

    localparam ing_port_index_map_t ING_PORT_INDEX_MAP = create_ing_port_index_map();

    localparam NUM_ING_PHYS_PORTS = NUM_64B_ING_PHYS_PORTS +
                                    NUM_32B_ING_PHYS_PORTS +
                                    NUM_16B_ING_PHYS_PORTS +
                                    NUM_8B_ING_PHYS_PORTS;

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);

    localparam INDEX_ING_8B_START  = ING_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_ING_16B_START = ING_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_ING_32B_START = ING_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_ING_64B_START = ING_PORT_INDEX_MAP[INDEX_64B][0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress Constants

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_EGR_PHYS_PORTS,
                                                                             NUM_32B_EGR_PHYS_PORTS,
                                                                             NUM_16B_EGR_PHYS_PORTS,
                                                                             NUM_8B_EGR_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_EGR_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_EGR_PHYS_PORTS_PER_ARRAY);

    typedef int egr_port_index_map_t [NUM_EGR_AXIS_ARRAYS-1:0] [MAX_NUM_EGR_PORTS_PER_ARRAY-1:0];

    function egr_port_index_map_t create_egr_port_index_map();
        automatic egr_port_index_map_t map = '{default: '{default: -1}};
        automatic int cnt = 0;
        for(int i=0; i<NUM_EGR_AXIS_ARRAYS; i++) begin
            for(int j=0; j<NUM_EGR_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                map[i][j] = cnt;
                cnt++;
            end
        end
        return map;
    endfunction

    localparam egr_port_index_map_t EGR_PORT_INDEX_MAP = create_egr_port_index_map();

    localparam NUM_EGR_PHYS_PORTS = NUM_64B_EGR_PHYS_PORTS +
                                    NUM_32B_EGR_PHYS_PORTS +
                                    NUM_16B_EGR_PHYS_PORTS +
                                    NUM_8B_EGR_PHYS_PORTS;

    localparam NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);

    localparam INDEX_EGR_8B_START  = EGR_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_EGR_16B_START = EGR_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_EGR_32B_START = EGR_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_EGR_64B_START = EGR_PORT_INDEX_MAP[INDEX_64B][0];


endpackage