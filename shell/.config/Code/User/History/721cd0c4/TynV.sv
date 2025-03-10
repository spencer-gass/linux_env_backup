// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`default_nettype none

/**
 * P4 Router Vitis Networking P4 FRR T1 ECP with Tiny BCAM Package
 *
 * Contains relevant types and constants for a specific configuration of vitis_net_p4 IP.
 * Copied from 15eglv_pcuecp/pcuecp.gen/sources_1/ip/vitis_net_p4_frr_t1_ecp_tiny_bcam/src/verilog/vitis_net_p4_frr_t1_ecp_tiny_bcam_pkg.sv
 *
**/

package VITIS_NET_P4_FRR_T1_ECP_TINY_BCAM_PKG;

////////////////////////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////////////////////////

    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/workspace/15eglv_pcuecp/pcuecp.gen/sources_1/ip/vitis_net_p4_frr_t1_ecp_tiny_bcam/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/app_tiny_bcam.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = " ";

    localparam PACKET_RATE           = 35;
    localparam AXIS_CLK_FREQ_MHZ     = 200.0;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 200.0;
    localparam OUT_META_FOR_DROP     = 0;
    localparam TOTAL_LATENCY         = 49;
    localparam PLUGIN_MODE           = 0;

    localparam TDATA_NUM_BYTES       = 64;
    localparam AXIS_DATA_WIDTH       = 512;
    localparam USER_META_DATA_WIDTH  = 79;
    localparam NUM_USER_EXTERNS      = 2;
    localparam USER_EXTERN_IN_WIDTH  = 17;
    localparam USER_EXTERN_OUT_WIDTH = 192;

    localparam S_AXI_DATA_WIDTH      = 32;
    localparam S_AXI_ADDR_WIDTH      = 16;
    localparam M_AXI_HBM_NUM_SLOTS   = 0;
    localparam M_AXI_HBM_DATA_WIDTH  = 256;
    localparam M_AXI_HBM_ADDR_WIDTH  = 33;
    localparam M_AXI_HBM_ID_WIDTH    = 6;
    localparam M_AXI_HBM_LEN_WIDTH   = 4;

    // Metadata interface info
    localparam USER_METADATA_VRF_ID_WIDTH = 32;
    localparam USER_METADATA_VRF_ID_MSB   = 31;
    localparam USER_METADATA_VRF_ID_LSB   = 0;
    localparam USER_METADATA_VLAN_ID_WIDTH = 12;
    localparam USER_METADATA_VLAN_ID_MSB   = 43;
    localparam USER_METADATA_VLAN_ID_LSB   = 32;
    localparam USER_METADATA_BYTE_LENGTH_WIDTH = 14;
    localparam USER_METADATA_BYTE_LENGTH_MSB   = 57;
    localparam USER_METADATA_BYTE_LENGTH_LSB   = 44;
    localparam USER_METADATA_BOS_WIDTH = 1;
    localparam USER_METADATA_BOS_MSB   = 58;
    localparam USER_METADATA_BOS_LSB   = 58;
    localparam USER_METADATA_EGRESS_PORT_WIDTH = 10;
    localparam USER_METADATA_EGRESS_PORT_MSB   = 68;
    localparam USER_METADATA_EGRESS_PORT_LSB   = 59;
    localparam USER_METADATA_INGRESS_PORT_WIDTH = 10;
    localparam USER_METADATA_INGRESS_PORT_MSB   = 78;
    localparam USER_METADATA_INGRESS_PORT_LSB   = 69;

    // User Extern interface info
    localparam USER_EXTERN_VALID_USERIPV4CHKVERIFY     = 0;
    localparam USER_EXTERN_VALID_USERIPV4CHKUPDATE     = 1;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_WIDTH  = 1;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_MSB    = 0;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_LSB    = 0;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_WIDTH  = 16;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_MSB    = 16;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_LSB    = 1;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_WIDTH = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_MSB   = 31;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_LSB   = 0;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_WIDTH = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_MSB   = 63;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_LSB   = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_WIDTH = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_MSB   = 79;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_LSB   = 64;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_MSB   = 87;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_LSB   = 80;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_MSB   = 95;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_LSB   = 88;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_WIDTH = 13;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_MSB   = 108;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_LSB   = 96;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_WIDTH = 3;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_MSB   = 111;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_LSB   = 109;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_WIDTH = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_MSB   = 127;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_LSB   = 112;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_WIDTH = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_MSB   = 143;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_LSB   = 128;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_MSB   = 151;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_LSB   = 144;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_WIDTH = 4;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_MSB   = 155;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_LSB   = 152;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_WIDTH = 4;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_MSB   = 159;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_LSB   = 156;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_MSB   = 167;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_LSB   = 160;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_MSB   = 175;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_LSB   = 168;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_WIDTH = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_MSB   = 191;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_LSB   = 176;

////////////////////////////////////////////////////////////////////////////////
// Declarations
////////////////////////////////////////////////////////////////////////////////

    // Metadata top-struct
    typedef struct packed {
        logic [9:0] ingress_port;
        logic [9:0] egress_port;
        logic bos;
        logic [13:0] byte_length;
        logic [11:0] vlan_id;
        logic [31:0] vrf_id;
    } USER_META_DATA_T;

    // User Extern sub-struct chksum_update_in
    typedef struct packed {
        logic [15:0] hdr_chk;
        logic [7:0] old_ttl;
        logic [7:0] new_ttl;
    } CHKSUM_UPDATE_IN_T;


    // User Extern sub-struct ipv4
    typedef struct packed {
        logic [3:0] version;
        logic [3:0] hdr_len;
        logic [7:0] tos;
        logic [15:0] length;
        logic [15:0] id;
        logic [2:0] flags;
        logic [12:0] offset;
        logic [7:0] ttl;
        logic [7:0] protocol;
        logic [15:0] hdr_chk;
        logic [31:0] src;
        logic [31:0] dst;
    } IPV4_T;


    // User Extern In top-struct
    typedef struct packed {
        logic [15:0] UserIPv4ChkUpdate;
        logic UserIPv4ChkVerify;
    } USER_EXTERN_IN_T;

    // User Extern Out top-struct
    typedef struct packed {
        CHKSUM_UPDATE_IN_T UserIPv4ChkUpdate;
        IPV4_T UserIPv4ChkVerify;
    } USER_EXTERN_OUT_T;

    // User Extern (In/Out) Valid top-struct
    typedef struct packed {
        logic UserIPv4ChkUpdate;
        logic UserIPv4ChkVerify;
    } USER_EXTERN_VALID_T;

endpackage
