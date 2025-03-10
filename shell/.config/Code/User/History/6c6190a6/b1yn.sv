// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`default_nettype none

/**
 * P4 Router Vitis Networking P4 Echo Physical Port Package
 *
 * Contains relevant types and constants for a specific configuration of vitis_net_p4 IP.
 * copied from p4_2021/p4_2021.gen/sources_1/ip/vitis_net_p4_ech0_phys_port/src/verilog/vitis_net_p4_echo_phys_port_pkg.sv
**/
package p4_router_vnp4_echo_phys_port_pkg;


    ////////////////////////////////////////////////////////////////////////////////
    // Section: Parameters


    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/workspace/p4_2021/p4_2021.gen/sources_1/ip/vitis_net_p4_echo_phys_port/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/echo_phys_port.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = " ";

    localparam PACKET_RATE           = 300.0;
    localparam AXIS_CLK_FREQ_MHZ     = 300.0;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 300.0;
    localparam OUT_META_FOR_DROP     = 0;
    localparam TOTAL_LATENCY         = 5;
    localparam PLUGIN_MODE           = 0;

    localparam TDATA_NUM_BYTES       = 64;
    localparam AXIS_DATA_WIDTH       = 512;
    localparam USER_META_DATA_WIDTH  = 33;
    localparam NUM_USER_EXTERNS      = 1;
    localparam USER_EXTERN_IN_WIDTH  = 1;
    localparam USER_EXTERN_OUT_WIDTH = 1;

    localparam S_AXI_DATA_WIDTH      = 32;
    localparam S_AXI_ADDR_WIDTH      = 1;
    localparam M_AXI_HBM_NUM_SLOTS   = 0;
    localparam M_AXI_HBM_DATA_WIDTH  = 256;
    localparam M_AXI_HBM_ADDR_WIDTH  = 33;
    localparam M_AXI_HBM_ID_WIDTH    = 6;
    localparam M_AXI_HBM_LEN_WIDTH   = 4;

    // Metadata interface info
    localparam USER_METADATA_T_BYTE_LENGTH_WIDTH = 14;
    localparam USER_METADATA_T_BYTE_LENGTH_MSB   = 13;
    localparam USER_METADATA_T_BYTE_LENGTH_LSB   = 0;
    localparam USER_METADATA_T_PRIO_WIDTH = 3;
    localparam USER_METADATA_T_PRIO_MSB   = 16;
    localparam USER_METADATA_T_PRIO_LSB   = 14;
    localparam USER_METADATA_T_EGR_SPEC_WIDTH = 8;
    localparam USER_METADATA_T_EGR_SPEC_MSB   = 24;
    localparam USER_METADATA_T_EGR_SPEC_LSB   = 17;
    localparam USER_METADATA_T_ING_PORT_WIDTH = 8;
    localparam USER_METADATA_T_ING_PORT_MSB   = 32;
    localparam USER_METADATA_T_ING_PORT_LSB   = 25;

    // User Extern interface info

////////////////////////////////////////////////////////////////////////////////
// Declarations
////////////////////////////////////////////////////////////////////////////////

    // Metadata top-struct
    typedef struct packed {
        logic [7:0] ing_port;
        logic [7:0] egr_spec;
        logic [2:0] prio;
        logic [13:0] byte_length;
    } USER_META_DATA_T;

endpackage

`default_nettype wire
