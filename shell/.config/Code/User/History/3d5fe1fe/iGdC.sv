// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Package
**/

`default_nettype none

package p4_router_pkg;

    // Single entry point for the code generated VNP4 package that is specific to the VNP4 custumizatoin
    import vitis_net_p4_0_pkg::*;

    localparam int VNP4_DATA_BYTES = TDATA_NUM_BYTES;
    typedef USER_META_DATA_METADATA_T USER_META_DATA_METADATA_T;
    // localparam int ING_PORT_METADATA_WIDTH = 0,
    // localparam int EGR_SPEC_METADATA_WIDTH = 0,
    localparam int VNP4_AXI4LITE_DATALEN = S_AXI_DATA_WIDTH,
    localparam int VNP4_AXI4LITE_ADDRLEN = S_AXI_ADDR_WIDTH,

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

endpackage

`default_nettype wire