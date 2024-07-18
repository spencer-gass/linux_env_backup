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




endpackage