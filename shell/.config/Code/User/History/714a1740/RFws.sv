// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Package
**/

`default_nettype none

package p4_router_params_pkg;

    localparam int NUM_8B_ING_PHYS_PORTS  = 0,
    localparam int NUM_16B_ING_PHYS_PORTS = 0,
    localparam int NUM_32B_ING_PHYS_PORTS = 0,
    localparam int NUM_64B_ING_PHYS_PORTS = 0,

    localparam int NUM_8B_EGR_PHYS_PORTS  = 0,
    localparam int NUM_16B_EGR_PHYS_PORTS = 0,
    localparam int NUM_32B_EGR_PHYS_PORTS = 0,
    localparam int NUM_64B_EGR_PHYS_PORTS = 0,

    localparam int MTU_BYTES = 9600 // get input on MTU requirement and move this to a package

endpackage