//////////////////////////////////////////////////////////////////////////////
// be767e8644eee50b2645307571242b99d62eea726bb276dae1cba7a07fa60690
// Proprietary Note:
// XILINX CONFIDENTIAL
//
// Copyright 2015 Xilinx, Inc. All rights reserved.
// This file contains confidential and proprietary information of Xilinx, Inc.
// and is protected under U.S. and international copyright and other
// intellectual property laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////

package VITIS_NET_P4_NETWORK_PACKET_UTILS_PARSER_PKG;

////////////////////////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////////////////////////

    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/workspace/p4_2021/p4_2021.gen/sources_1/ip/vitis_net_p4_network_packet_utils_parser/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/network_packet_utils_parser.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = " ";

    localparam PACKET_RATE           = 300.0;
    localparam AXIS_CLK_FREQ_MHZ     = 300.0;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 300.0;
    localparam OUT_META_FOR_DROP     = 1;
    localparam TOTAL_LATENCY         = 22;
    localparam PLUGIN_MODE           = 0;

    localparam TDATA_NUM_BYTES       = 8;
    localparam AXIS_DATA_WIDTH       = 64;
    localparam USER_META_DATA_WIDTH  = 372;
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
    localparam USER_METADATA_IPV4_DST_WIDTH = 32;
    localparam USER_METADATA_IPV4_DST_MSB   = 31;
    localparam USER_METADATA_IPV4_DST_LSB   = 0;
    localparam USER_METADATA_IPV4_SRC_WIDTH = 32;
    localparam USER_METADATA_IPV4_SRC_MSB   = 63;
    localparam USER_METADATA_IPV4_SRC_LSB   = 32;
    localparam USER_METADATA_IPV4_HDR_CHK_WIDTH = 16;
    localparam USER_METADATA_IPV4_HDR_CHK_MSB   = 79;
    localparam USER_METADATA_IPV4_HDR_CHK_LSB   = 64;
    localparam USER_METADATA_IPV4_PROTOCOL_WIDTH = 8;
    localparam USER_METADATA_IPV4_PROTOCOL_MSB   = 87;
    localparam USER_METADATA_IPV4_PROTOCOL_LSB   = 80;
    localparam USER_METADATA_IPV4_TTL_WIDTH = 8;
    localparam USER_METADATA_IPV4_TTL_MSB   = 95;
    localparam USER_METADATA_IPV4_TTL_LSB   = 88;
    localparam USER_METADATA_IPV4_OFFSET_WIDTH = 13;
    localparam USER_METADATA_IPV4_OFFSET_MSB   = 108;
    localparam USER_METADATA_IPV4_OFFSET_LSB   = 96;
    localparam USER_METADATA_IPV4_FLAGS_WIDTH = 3;
    localparam USER_METADATA_IPV4_FLAGS_MSB   = 111;
    localparam USER_METADATA_IPV4_FLAGS_LSB   = 109;
    localparam USER_METADATA_IPV4_ID_WIDTH = 16;
    localparam USER_METADATA_IPV4_ID_MSB   = 127;
    localparam USER_METADATA_IPV4_ID_LSB   = 112;
    localparam USER_METADATA_IPV4_LEN_WIDTH = 16;
    localparam USER_METADATA_IPV4_LEN_MSB   = 143;
    localparam USER_METADATA_IPV4_LEN_LSB   = 128;
    localparam USER_METADATA_IPV4_TOS_WIDTH = 8;
    localparam USER_METADATA_IPV4_TOS_MSB   = 151;
    localparam USER_METADATA_IPV4_TOS_LSB   = 144;
    localparam USER_METADATA_IPV4_HDR_LEN_WIDTH = 4;
    localparam USER_METADATA_IPV4_HDR_LEN_MSB   = 155;
    localparam USER_METADATA_IPV4_HDR_LEN_LSB   = 152;
    localparam USER_METADATA_IPV4_VERSION_WIDTH = 4;
    localparam USER_METADATA_IPV4_VERSION_MSB   = 159;
    localparam USER_METADATA_IPV4_VERSION_LSB   = 156;
    localparam USER_METADATA_IPV4_VALID_WIDTH = 1;
    localparam USER_METADATA_IPV4_VALID_MSB   = 160;
    localparam USER_METADATA_IPV4_VALID_LSB   = 160;
    localparam USER_METADATA_MPLS1_WIDTH = 32;
    localparam USER_METADATA_MPLS1_MSB   = 192;
    localparam USER_METADATA_MPLS1_LSB   = 161;
    localparam USER_METADATA_MPLS0_WIDTH = 32;
    localparam USER_METADATA_MPLS0_MSB   = 224;
    localparam USER_METADATA_MPLS0_LSB   = 193;
    localparam USER_METADATA_MPLS_LABELS_VALID_WIDTH = 2;
    localparam USER_METADATA_MPLS_LABELS_VALID_MSB   = 226;
    localparam USER_METADATA_MPLS_LABELS_VALID_LSB   = 225;
    localparam USER_METADATA_VLAN_WIDTH = 32;
    localparam USER_METADATA_VLAN_MSB   = 258;
    localparam USER_METADATA_VLAN_LSB   = 227;
    localparam USER_METADATA_VLAN_TAG_VALID_WIDTH = 1;
    localparam USER_METADATA_VLAN_TAG_VALID_MSB   = 259;
    localparam USER_METADATA_VLAN_TAG_VALID_LSB   = 259;
    localparam USER_METADATA_ETHER_TYPE_WIDTH = 16;
    localparam USER_METADATA_ETHER_TYPE_MSB   = 275;
    localparam USER_METADATA_ETHER_TYPE_LSB   = 260;
    localparam USER_METADATA_MAC_SA_WIDTH = 48;
    localparam USER_METADATA_MAC_SA_MSB   = 323;
    localparam USER_METADATA_MAC_SA_LSB   = 276;
    localparam USER_METADATA_MAC_DA_WIDTH = 48;
    localparam USER_METADATA_MAC_DA_MSB   = 371;
    localparam USER_METADATA_MAC_DA_LSB   = 324;

    // User Extern interface info

////////////////////////////////////////////////////////////////////////////////
// Declarations
////////////////////////////////////////////////////////////////////////////////

    // Metadata top-struct
    typedef struct packed {
        logic [47:0] mac_da;
        logic [47:0] mac_sa;
        logic [15:0] ether_type;
        logic vlan_tag_valid;
        logic [31:0] vlan;
        logic [1:0] mpls_labels_valid;
        logic [31:0] mpls0;
        logic [31:0] mpls1;
        logic ipv4_valid;
        logic [3:0] ipv4_version;
        logic [3:0] ipv4_hdr_len;
        logic [7:0] ipv4_tos;
        logic [15:0] ipv4_len;
        logic [15:0] ipv4_id;
        logic [2:0] ipv4_flags;
        logic [12:0] ipv4_offset;
        logic [7:0] ipv4_ttl;
        logic [7:0] ipv4_protocol;
        logic [15:0] ipv4_hdr_chk;
        logic [31:0] ipv4_src;
        logic [31:0] ipv4_dst;
    } USER_META_DATA_T;

endpackage
