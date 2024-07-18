// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * MPLS Router Package
**/

package mpls_router_pkg;

    enum {
        INDEX_8B,
        INDEX_16B,
        INDEX_32B,
        INDEX_64B,
        NUM_AXIS_ARRAYS
    } port_width_indecies;

    localparam int NUM_ING_AXIS_ARRAYs = NUM_AXIS_ARRAYS;
    localparam int NUM_EGR_AXIS_ARRAYs = NUM_AXIS_ARRAYS;

endpackage