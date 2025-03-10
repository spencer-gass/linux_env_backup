// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`default_nettype none

/**
 * P4 Router Vitis Networking P4 Passthrough with IPv4 User Extern Package
 *
 * Contains relevant types and constants for a specific configuration of vitis_net_p4 IP.
 * copied from p4_2021/p4_2021.gen/sources_1/ip/vitis_net_p4_passthrough_with_ipv4_user_extern/src/verilog/vitis_net_p4_passthrough_with_ipv4_user_extern_pkg.sv
 *
**/
package vitis_net_p4_passthrough_with_ipv4_user_extern_pkg;


    ////////////////////////////////////////////////////////////////////////////////
    // Section: Parameters


    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/workspace/p4_2021/p4_2021.gen/sources_1/ip/vitis_net_p4_passthrough_with_ipv4_user_extern/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/passthrough_with_ipv4_user_extern.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = " ";

    localparam PACKET_RATE           = 300.0;
    localparam AXIS_CLK_FREQ_MHZ     = 300.0;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 300.0;
    localparam OUT_META_FOR_DROP     = 1;
    localparam TOTAL_LATENCY         = 27;
    localparam PLUGIN_MODE           = 0;

    localparam TDATA_NUM_BYTES       = 64;
    localparam AXIS_DATA_WIDTH       = 512;
    localparam USER_META_DATA_WIDTH  = 288;
    localparam NUM_USER_EXTERNS      = 2;
    localparam USER_EXTERN_IN_WIDTH  = 17;
    localparam USER_EXTERN_OUT_WIDTH = 192;

    localparam S_AXI_DATA_WIDTH      = 32;
    localparam S_AXI_ADDR_WIDTH      = 13;
    localparam M_AXI_HBM_NUM_SLOTS   = 0;
    localparam M_AXI_HBM_DATA_WIDTH  = 256;
    localparam M_AXI_HBM_ADDR_WIDTH  = 33;
    localparam M_AXI_HBM_ID_WIDTH    = 6;
    localparam M_AXI_HBM_LEN_WIDTH   = 4;

    // Metadata interface info
    localparam USER_METADATA_IP_DA_WIDTH        = 32;
    localparam USER_METADATA_IP_DA_MSB          = 31;
    localparam USER_METADATA_IP_DA_LSB          = 0;
    localparam USER_METADATA_IP_SA_WIDTH        = 32;
    localparam USER_METADATA_IP_SA_MSB          = 63;
    localparam USER_METADATA_IP_SA_LSB          = 32;
    localparam USER_METADATA_IP_HDR_CHK_WIDTH   = 16;
    localparam USER_METADATA_IP_HDR_CHK_MSB     = 79;
    localparam USER_METADATA_IP_HDR_CHK_LSB     = 64;
    localparam USER_METADATA_IP_PROTOCOL_WIDTH  = 8;
    localparam USER_METADATA_IP_PROTOCOL_MSB    = 87;
    localparam USER_METADATA_IP_PROTOCOL_LSB    = 80;
    localparam USER_METADATA_IP_TTL_WIDTH       = 8;
    localparam USER_METADATA_IP_TTL_MSB         = 95;
    localparam USER_METADATA_IP_TTL_LSB         = 88;
    localparam USER_METADATA_IP_OFFSET_WIDTH    = 13;
    localparam USER_METADATA_IP_OFFSET_MSB      = 108;
    localparam USER_METADATA_IP_OFFSET_LSB      = 96;
    localparam USER_METADATA_IP_FLAGS_WIDTH     = 3;
    localparam USER_METADATA_IP_FLAGS_MSB       = 111;
    localparam USER_METADATA_IP_FLAGS_LSB       = 109;
    localparam USER_METADATA_IP_ID_WIDTH        = 16;
    localparam USER_METADATA_IP_ID_MSB          = 127;
    localparam USER_METADATA_IP_ID_LSB          = 112;
    localparam USER_METADATA_IP_LENGTH_WIDTH    = 16;
    localparam USER_METADATA_IP_LENGTH_MSB      = 143;
    localparam USER_METADATA_IP_LENGTH_LSB      = 128;
    localparam USER_METADATA_IP_TOS_WIDTH       = 8;
    localparam USER_METADATA_IP_TOS_MSB         = 151;
    localparam USER_METADATA_IP_TOS_LSB         = 144;
    localparam USER_METADATA_IP_HDR_LEN_WIDTH   = 4;
    localparam USER_METADATA_IP_HDR_LEN_MSB     = 155;
    localparam USER_METADATA_IP_HDR_LEN_LSB     = 152;
    localparam USER_METADATA_IP_VERSION_WIDTH   = 4;
    localparam USER_METADATA_IP_VERSION_MSB     = 159;
    localparam USER_METADATA_IP_VERSION_LSB     = 156;
    localparam USER_METADATA_IP_IS_VALID_WIDTH  = 1;
    localparam USER_METADATA_IP_IS_VALID_MSB    = 160;
    localparam USER_METADATA_IP_IS_VALID_LSB    = 160;
    localparam USER_METADATA_ETHER_TYPE_WIDTH   = 16;
    localparam USER_METADATA_ETHER_TYPE_MSB     = 176;
    localparam USER_METADATA_ETHER_TYPE_LSB     = 161;
    localparam USER_METADATA_MAC_SA_WIDTH       = 48;
    localparam USER_METADATA_MAC_SA_MSB         = 224;
    localparam USER_METADATA_MAC_SA_LSB         = 177;
    localparam USER_METADATA_MAC_DA_WIDTH       = 48;
    localparam USER_METADATA_MAC_DA_MSB         = 272;
    localparam USER_METADATA_MAC_DA_LSB         = 225;
    localparam USER_METADATA_ETH_IS_VALID_WIDTH = 1;
    localparam USER_METADATA_ETH_IS_VALID_MSB   = 273;
    localparam USER_METADATA_ETH_IS_VALID_LSB   = 273;
    localparam USER_METADATA_BYTE_LENGTH_WIDTH  = 14;
    localparam USER_METADATA_BYTE_LENGTH_MSB    = 287;
    localparam USER_METADATA_BYTE_LENGTH_LSB    = 274;

    // User Extern interface info
    localparam USER_EXTERN_VALID_USERIPV4CHKVERIFY              = 0;
    localparam USER_EXTERN_VALID_USERIPV4CHKUPDATE              = 1;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_WIDTH           = 1;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_MSB             = 0;
    localparam USER_EXTERN_IN_USERIPV4CHKVERIFY_LSB             = 0;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_WIDTH           = 16;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_MSB             = 16;
    localparam USER_EXTERN_IN_USERIPV4CHKUPDATE_LSB             = 1;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_WIDTH      = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_MSB        = 31;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_DST_LSB        = 0;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_WIDTH      = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_MSB        = 63;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_SRC_LSB        = 32;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_WIDTH  = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_MSB    = 79;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_CHK_LSB    = 64;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_WIDTH = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_MSB   = 87;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_PROTOCOL_LSB   = 80;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_WIDTH      = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_MSB        = 95;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TTL_LSB        = 88;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_WIDTH   = 13;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_MSB     = 108;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_OFFSET_LSB     = 96;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_WIDTH    = 3;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_MSB      = 111;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_FLAGS_LSB      = 109;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_WIDTH       = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_MSB         = 127;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_ID_LSB         = 112;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_WIDTH   = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_MSB     = 143;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_LENGTH_LSB     = 128;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_WIDTH      = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_MSB        = 151;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_TOS_LSB        = 144;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_WIDTH  = 4;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_MSB    = 155;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_HDR_LEN_LSB    = 152;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_WIDTH  = 4;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_MSB    = 159;
    localparam USER_EXTERN_OUT_USERIPV4CHKVERIFY_VERSION_LSB    = 156;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_WIDTH  = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_MSB    = 167;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_NEW_TTL_LSB    = 160;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_WIDTH  = 8;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_MSB    = 175;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_OLD_TTL_LSB    = 168;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_WIDTH  = 16;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_MSB    = 191;
    localparam USER_EXTERN_OUT_USERIPV4CHKUPDATE_HDR_CHK_LSB    = 176;


    ////////////////////////////////////////////////////////////////////////////////
    // Section: Declarations


    // Metadata top-struct
    typedef struct packed {
        logic [13:0] byte_length;
        logic eth_is_valid;
        logic [47:0] mac_da;
        logic [47:0] mac_sa;
        logic [15:0] ether_type;
        logic ip_is_valid;
        logic [3:0] ip_version;
        logic [3:0] ip_hdr_len;
        logic [7:0] ip_tos;
        logic [15:0] ip_length;
        logic [15:0] ip_id;
        logic [2:0] ip_flags;
        logic [12:0] ip_offset;
        logic [7:0] ip_ttl;
        logic [7:0] ip_protocol;
        logic [15:0] ip_hdr_chk;
        logic [31:0] ip_sa;
        logic [31:0] ip_da;
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
