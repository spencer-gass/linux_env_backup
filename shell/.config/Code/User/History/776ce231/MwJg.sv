// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Vitis Networking P4 FRR T1 ECP Package
 *
 * Contains relevant types and constants for a specific configuration of vitis_net_p4 IP.
 * Copied from 15eglv_pcuecp/pcuecp.gen/sources_1/ip/vitis_net_p4_frr_t1_ecp/src/verilog/vitis_net_p4_frr_t1_ecp_pkg.sv
 *
**/

`default_nettype none

package p4_router_vnp4_frr_t1_ecp_pkg;

////////////////////////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////////////////////////

    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/ipsrcs/tcl-managed/pcuecp/15eglv/vitis_net_p4_frr_t1_ecp/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/frr_dplane_xilinx.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = "";

    localparam PACKET_RATE           = 15;
    localparam AXIS_CLK_FREQ_MHZ     = 200;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 200;
    localparam OUT_META_FOR_DROP     = 0;
    localparam TOTAL_LATENCY         = 115;
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

// `ifndef SYNTHESIS

//     // Common internal data structures
//     typedef chandle XilVitisNetP4CamCtx;
//     typedef chandle XilVitisNetP4TargetBuildInfoCtx;
//     typedef chandle XilVitisNetP4TargetInterruptCtx;
//     typedef chandle XilVitisNetP4TargetControlCtx;
//     typedef longint XilVitisNetP4AddressType;
//     typedef byte byteArray [127:0];

//     // Select which type of endian is used
//     typedef enum {
//         XIL_VITIS_NET_P4_LITTLE_ENDIAN,    // < use the little endian format
//         XIL_VITIS_NET_P4_BIG_ENDIAN,       // < use the big endian format
//         XIL_VITIS_NET_P4_NUM_ENDIAN        // < For validation by driver - do not use
//     } XilVitisNetP4Endian;

//     // Selects which type of mode is used to implement the table
//     typedef enum {
//         XIL_VITIS_NET_P4_TABLE_MODE_BCAM,      // < Table configured as exact match or BCAM
//         XIL_VITIS_NET_P4_TABLE_MODE_STCAM,     // < Table configured as lpm or STCAM
//         XIL_VITIS_NET_P4_TABLE_MODE_TCAM,      // < Table configured as ternary or TCAM
//         XIL_VITIS_NET_P4_TABLE_MODE_DCAM,      // < Table configured as direct or DCAM
//         XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM, // < Table configured as tiny CAM
//         XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM, // < Table configured as tiny CAM
//         XIL_VITIS_NET_P4_NUM_TABLE_MODES       // < For validation by driver - do not use
//     } XilVitisNetP4TableMode;

//     // Selects which type of FPGA memory resources are used to implement the CAM
//     typedef enum {
//         XIL_VITIS_NET_P4_CAM_MEM_AUTO,     // < Automatically selects between BRAM and URAM based on CAM size
//         XIL_VITIS_NET_P4_CAM_MEM_BRAM,     // < CAM storage uses block RAM
//         XIL_VITIS_NET_P4_CAM_MEM_URAM,     // < CAM storage uses ultra RAM
//         XIL_VITIS_NET_P4_CAM_MEM_HBM,      // < CAM storage uses High Bandwidth Memory
//         XIL_VITIS_NET_P4_CAM_MEM_RAM,      // < CAM storage uses external RAM (future feature, only used for internal testing)
//         XIL_VITIS_NET_P4_NUM_CAM_MEM_TYPES // < For validation by driver - do not use
//     } XilVitisNetP4CamMemType;

//     // Selects what type of optimization that was applied to the implemented CAM
//     typedef enum {
//         XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE,         // < No optimizations
//         XIL_VITIS_NET_P4_CAM_OPTIMIZE_RAM,          // < Used to reduce ram cost with a potentially higher logic cost.
//         XIL_VITIS_NET_P4_CAM_OPTIMIZE_LOGIC,        // < Used to reduce logic cost with a potentially higher ram cost.
//         XIL_VITIS_NET_P4_NUM_CAM_OPTIMIZATION_TYPE  // < For validation by driver - do not use
//     } XilVitisNetP4CamOptimizationType;

//     // ECC error types
//     typedef enum {
//         XIL_VITIS_NET_P4_INTERRUPT_ECC_ERROR_SINGLE_BIT,  // < Single bit ECC error - internally recoverable
//         XIL_VITIS_NET_P4_INTERRUPT_ECC_ERROR_DOUBLE_BIT,  // < Double bit ECC error - internally not recoverable
//         XIL_VITIS_NET_P4_INTERRUPT_ECC_ERROR_ALL,         // < Both single and double bit ECC errors
//         XIL_VITIS_NET_P4_INTERRUPT_ECC_ERROR_TYPE_MAX     // < For validation by driver - do not use
//     } XilVitisNetP4InterruptEccErrorType;

//     // Individual engine reset control
//     typedef enum {
//         XIL_VITIS_NET_P4_TARGET_CTRL_ALL_ENGINES,        // < Target all internal engines
//         XIL_VITIS_NET_P4_TARGET_CTRL_DEPARSER_ENGINE,    // < Target Deparser engine only
//         XIL_VITIS_NET_P4_TARGET_CTRL_FIFO_ENGINE,        // < Target sync FIFOs engine only
//         XIL_VITIS_NET_P4_TARGET_CTRL_MA_ENGINE,          // < Target Match-Action engine only
//         XIL_VITIS_NET_P4_TARGET_CTRL_PARSER_ENGINE       // < Target Parser engine only
//     } XilVitisNetP4ControlEngineId;

//     // Structure to define the XilVitisNetP4Version
//     typedef struct {
//         byte Major;    // < VitisNetP4 major version number
//         byte Minor;    // < VitisNetP4 minor version number
//         byte Revision; // < VitisNetP4 revision number
//     } XilVitisNetP4Version;

//     // Structure to define the XilVitisNetP4Version
//     typedef struct {
//         int PacketRateMps;      // < Packet rate in Mp/s
//         int CamMemoryClockMhz;  // < CAM memory clock in MHz
//         int AxiStreamClockMhz;  // < AXI Stream clock in MHz
//     } XilVitisNetP4TargetBuildInfoIpSettings;

//     typedef struct {
//         int unsigned SingleBitErrorStatus; // < 1 indicates present, 0 indicates not present
//         int unsigned DoubleBitErrorStatus; // < 1 indicates present, 0 indicates not present
//     } XilVitisNetP4TargetInterruptEccErrorStatus;

//     // Structure to define the CAM configuration
//     typedef struct {
//         XilVitisNetP4AddressType         BaseAddr;           // < Base address of the CAM
//         string                           FormatStringPtr;    // < Format string - refer to \ref fmt for details
//         int                              NumEntries;         // < Number of entries the CAM holds
//         int                              RamFrequencyHz;     // < RAM clock frequency, specified in Hertz
//         int                              LookupFrequencyHz;  // < Lookup engine clock frequency, specified in Hertz
//         int                              LookupsPerSec;      // < Number of lookups per second
//         shortint                         ResponseSizeBits;   // < Size of CAM response data, specified in bits
//         byte                             PrioritySizeBits;   // < Size of priority field, specified in bits (applies to TCAM only)
//         byte                             NumMasks;           // < STCAM only: specifies the number of unique masks that are available
//         XilVitisNetP4Endian              Endian;             // < Format of key, mask and response data
//         XilVitisNetP4CamMemType          MemType;            // < FPGA memory resource selection
//         int                              RamSizeKbytes;      // < RAM size in KiloBytes, (for internal testing of ASIC ram the unit equals data-width)
//         XilVitisNetP4CamOptimizationType OptimizationType;   // < Optimization type applied to the CAM
//     } XilVitisNetP4CamConfig;

//     // Structure to define a name-value pairs
//     typedef struct {
//        string  NameStringPtr;    // < Name of the attribute
//        int     Value;            // < value of the attribute
//     } XilVitisNetP4Attribute;

//     // Structure to define the action configuration
//     typedef struct {
//         string                  NameStringPtr;    // < Name of the action
//         int                     ParamListSize;    // < Total number of parameters
//         XilVitisNetP4Attribute  ParamListPtr[];   // < List of parameters
//     } XilVitisNetP4Action;

//     // Structure to define the table configuration
//     typedef struct {
//         XilVitisNetP4Endian     Endian;            // < Format of key, mask and action parameter byte arrays
//         XilVitisNetP4TableMode  Mode;              // < Table mode selection
//         int                     KeySizeBits;       // < Size of table key data, specified in bits
//         XilVitisNetP4CamConfig  CamConfig;         // < CAM configuration
//         int                     ActionIdWidthBits; // < Size of action ID field in response data, specified in bits
//         int                     ActionListSize;    // < Total number of associated actions
//         XilVitisNetP4Action     ActionListPtr[];   // < List of associated actions
//     } XilVitisNetP4TableConfig;

//     // Wrapper structure to group table name with table configuration
//     typedef struct {
//         string                     NameStringPtr;   // < Table control plane name
//         XilVitisNetP4TableConfig   Config;          // < Table configuration
//         XilVitisNetP4CamCtx        PrivateCtxPtr;   // < Internal context data used by driver implementation
//     } XilVitisNetP4TargetTableConfig;

//     // Structure to define the FIFOs names
//     typedef struct {
//         string NameStringPtr;
//     } XilVitisNetP4ComponentName;

//     // Configuration that describes the block information of the VitisNetP4 instance
//     typedef struct {
//         XilVitisNetP4AddressType BaseAddr;   // < Base address within the VitisNetP4 instance
//     } XilVitisNetP4TargetBuildInfoConfig;

//     // Configuration that describes the interrupt controller of the VitisNetP4 instance
//     typedef struct {
//         XilVitisNetP4AddressType    BaseAddr;                // < Base address within the VitisNetP4 instance
//         int                         NumP4Elements;           // < Number of P4 Elements present in the VitisNetP4 instance
//         int                         NumComponents;           // < Number of internal FIFOs present in the VitisNetP4 instance
//         XilVitisNetP4ComponentName  ComponentNameList[2];    // < List of FIFOs name that are present in the VitisNetP4 instance
//     } XilVitisNetP4TargetInterruptConfig;

//     // Configuration that describes the operations controller of the VitisNetP4 instance
//     typedef struct {
//         XilVitisNetP4AddressType  BaseAddr;           // < Base address within the VitisNetP4 instance
//         int                       NumP4Elements;      // < Number of P4 Elements present in the VitisNetP4 instance
//         int                       NumComponents;      // < Number of internal FIFOs present in the VitisNetP4 instance
//         int                       ClkInHz;            // < Clock in Hz
//         int                       PktRatePerSec;      // < Packet rate in packets per second
//     } XilVitisNetP4TargetCtrlConfig;

//     // Structure to define VitisNetP4's configuration
//     typedef struct {
//         XilVitisNetP4Endian                  Endian;         // < Global endianness setting - applies to all P4 element drivers instantiated by the target
//         int                                  TableListSize;  // < Total number of tables in the design
//         XilVitisNetP4TargetTableConfig       TableListPtr[]; // < List of tables in the design
//         XilVitisNetP4TargetBuildInfoConfig   BuildInfoPtr;   // < Pointer to the configuration for the build information reader
//         XilVitisNetP4TargetInterruptConfig   InterruptPtr;   // < Pointer to the configuration for the interrupt manager
//         XilVitisNetP4TargetCtrlConfig        CtrlConfigPtr;  // < Pointer to the configuration for the control manager
//     } XilVitisNetP4TargetConfig;

// ////////////////////////////////////////////////////////////////////////////////
// // Constants
// ////////////////////////////////////////////////////////////////////////////////

//     // CAM priority width default value
//     int XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT = 'hFF;

//     // User metadata definition
//     XilVitisNetP4Attribute XilVitisNetP4UserMetadataFields[] =
//     '{
//         '{
//             NameStringPtr : "user_metadata.ler_pop",
//             Value         : 1
//         },
//         '{
//             NameStringPtr : "user_metadata.ingress_port",
//             Value         : 10
//         },
//         '{
//             NameStringPtr : "user_metadata.egress_port",
//             Value         : 8
//         },
//         '{
//             NameStringPtr : "user_metadata.vlan_id",
//             Value         : 12
//         },
//         '{
//             NameStringPtr : "user_metadata.vrf_id",
//             Value         : 32
//         }
//     };
//     // Action 'NoAction' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_NoAction[] =
//     {
//     };
//     // Action 'drop' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_drop[] =
//     {
//     };
//     // Action 'md_set' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_md_set[] =
//     '{
//         '{
//             NameStringPtr : "vrf_id",
//             Value         : 32
//         },
//         '{
//             NameStringPtr : "vlan_id",
//             Value         : 12
//         }
//     };
//     // Action 'strip_dot1q' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_strip_dot1q[] =
//     '{
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'tag_dot1q' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_tag_dot1q[] =
//     '{
//         '{
//             NameStringPtr : "vlan_id",
//             Value         : 12
//         }
//     };
//     // Action 'ler_pop' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_ler_pop[] =
//     '{
//         '{
//             NameStringPtr : "label_stack",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'ler_tx' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_ler_tx[] =
//     '{
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'ler_push' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_ler_push[] =
//     '{
//         '{
//             NameStringPtr : "out_stack",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'lsr_push' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_lsr_push[] =
//     '{
//         '{
//             NameStringPtr : "out_label",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'lsr_pop' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_lsr_pop[] =
//     '{
//         '{
//             NameStringPtr : "out_label",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'lsr_swap' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_lsr_swap[] =
//     '{
//         '{
//             NameStringPtr : "out_label",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'lsr_noop' Parameters list
//     XilVitisNetP4Attribute XilVitisNetP4ActionParams_lsr_noop[] =
//     '{
//         '{
//             NameStringPtr : "out_label",
//             Value         : 20
//         },
//         '{
//             NameStringPtr : "src_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "dst_addr",
//             Value         : 48
//         },
//         '{
//             NameStringPtr : "port",
//             Value         : 8
//         }
//     };
//     // Action 'NoAction' definition
//     XilVitisNetP4Action XilVitisNetP4Action_NoAction =
//     '{
//         NameStringPtr : "NoAction",
//         ParamListSize : 0,
//         ParamListPtr  : XilVitisNetP4ActionParams_NoAction
//     };
//     // Action 'drop' definition
//     XilVitisNetP4Action XilVitisNetP4Action_drop =
//     '{
//         NameStringPtr : "drop",
//         ParamListSize : 0,
//         ParamListPtr  : XilVitisNetP4ActionParams_drop
//     };
//     // Action 'md_set' definition
//     XilVitisNetP4Action XilVitisNetP4Action_md_set =
//     '{
//         NameStringPtr : "md_set",
//         ParamListSize : 2,
//         ParamListPtr  : XilVitisNetP4ActionParams_md_set
//     };
//     // Action 'strip_dot1q' definition
//     XilVitisNetP4Action XilVitisNetP4Action_strip_dot1q =
//     '{
//         NameStringPtr : "strip_dot1q",
//         ParamListSize : 1,
//         ParamListPtr  : XilVitisNetP4ActionParams_strip_dot1q
//     };
//     // Action 'tag_dot1q' definition
//     XilVitisNetP4Action XilVitisNetP4Action_tag_dot1q =
//     '{
//         NameStringPtr : "tag_dot1q",
//         ParamListSize : 1,
//         ParamListPtr  : XilVitisNetP4ActionParams_tag_dot1q
//     };
//     // Action 'ler_pop' definition
//     XilVitisNetP4Action XilVitisNetP4Action_ler_pop =
//     '{
//         NameStringPtr : "ler_pop",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_ler_pop
//     };
//     // Action 'ler_tx' definition
//     XilVitisNetP4Action XilVitisNetP4Action_ler_tx =
//     '{
//         NameStringPtr : "ler_tx",
//         ParamListSize : 3,
//         ParamListPtr  : XilVitisNetP4ActionParams_ler_tx
//     };
//     // Action 'ler_push' definition
//     XilVitisNetP4Action XilVitisNetP4Action_ler_push =
//     '{
//         NameStringPtr : "ler_push",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_ler_push
//     };
//     // Action 'lsr_push' definition
//     XilVitisNetP4Action XilVitisNetP4Action_lsr_push =
//     '{
//         NameStringPtr : "lsr_push",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_lsr_push
//     };
//     // Action 'lsr_pop' definition
//     XilVitisNetP4Action XilVitisNetP4Action_lsr_pop =
//     '{
//         NameStringPtr : "lsr_pop",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_lsr_pop
//     };
//     // Action 'lsr_swap' definition
//     XilVitisNetP4Action XilVitisNetP4Action_lsr_swap =
//     '{
//         NameStringPtr : "lsr_swap",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_lsr_swap
//     };
//     // Action 'lsr_noop' definition
//     XilVitisNetP4Action XilVitisNetP4Action_lsr_noop =
//     '{
//         NameStringPtr : "lsr_noop",
//         ParamListSize : 4,
//         ParamListPtr  : XilVitisNetP4ActionParams_lsr_noop
//     };
//     // Table 'intf_map' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_intf_map[] =
//     '{
//         XilVitisNetP4Action_md_set,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'intf_map' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_intf_map =
//     '{
//         NameStringPtr : "intf_map",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_BCAM,
//             KeySizeBits       : 10,
//             CamConfig         : '{
//                  BaseAddr           : 'h00002000
//                 ,FormatStringPtr    : "10c"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 46
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 0
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_intf_map
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'vlan_map' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_vlan_map[] =
//     '{
//         XilVitisNetP4Action_strip_dot1q,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'vlan_map' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_vlan_map =
//     '{
//         NameStringPtr : "vlan_map",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_BCAM,
//             KeySizeBits       : 12,
//             CamConfig         : '{
//                  BaseAddr           : 'h00004000
//                 ,FormatStringPtr    : "12c"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 10
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 0
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_vlan_map
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'lfib' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_lfib[] =
//     '{
//         XilVitisNetP4Action_ler_pop,
//         XilVitisNetP4Action_lsr_push,
//         XilVitisNetP4Action_lsr_pop,
//         XilVitisNetP4Action_lsr_swap,
//         XilVitisNetP4Action_lsr_noop,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'lfib' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_lfib =
//     '{
//         NameStringPtr : "lfib",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_BCAM,
//             KeySizeBits       : 20,
//             CamConfig         : '{
//                  BaseAddr           : 'h00006000
//                 ,FormatStringPtr    : "20c"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 127
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 0
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 3,
//             ActionListSize    : 7,
//             ActionListPtr     : XilVitisNetP4TableActions_lfib
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'cmp_ipv4_fib' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_cmp_ipv4_fib[] =
//     '{
//         XilVitisNetP4Action_tag_dot1q,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'cmp_ipv4_fib' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_cmp_ipv4_fib =
//     '{
//         NameStringPtr : "cmp_ipv4_fib",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_STCAM,
//             KeySizeBits       : 64,
//             CamConfig         : '{
//                  BaseAddr           : 'h00008000
//                 ,FormatStringPtr    : "32c:32p"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 14
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 32
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_cmp_ipv4_fib
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'ipv4_fib_ingress' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_ipv4_fib_ingress[] =
//     '{
//         XilVitisNetP4Action_ler_push,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'ipv4_fib_ingress' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_ipv4_fib_ingress =
//     '{
//         NameStringPtr : "ipv4_fib_ingress",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_STCAM,
//             KeySizeBits       : 64,
//             CamConfig         : '{
//                  BaseAddr           : 'h0000A000
//                 ,FormatStringPtr    : "32c:32p"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 126
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 32
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_ipv4_fib_ingress
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'cmp_mac_fib' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_cmp_mac_fib[] =
//     '{
//         XilVitisNetP4Action_tag_dot1q,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'cmp_mac_fib' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_cmp_mac_fib =
//     '{
//         NameStringPtr : "cmp_mac_fib",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_BCAM,
//             KeySizeBits       : 58,
//             CamConfig         : '{
//                  BaseAddr           : 'h0000C000
//                 ,FormatStringPtr    : "48c:10c"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 14
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 0
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_cmp_mac_fib
//         },
//         PrivateCtxPtr  : null
//     };
//     // Table 'ipv4_fib_egress' Action list
//     XilVitisNetP4Action XilVitisNetP4TableActions_ipv4_fib_egress[] =
//     '{
//         XilVitisNetP4Action_ler_tx,
//         XilVitisNetP4Action_drop,
//         XilVitisNetP4Action_NoAction
//     };

//     // Table 'ipv4_fib_egress' definition
//     XilVitisNetP4TargetTableConfig XilVitisNetP4Table_ipv4_fib_egress =
//     '{
//         NameStringPtr : "ipv4_fib_egress",
//         Config        : '{
//             Endian            : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//             Mode              : XIL_VITIS_NET_P4_TABLE_MODE_STCAM,
//             KeySizeBits       : 64,
//             CamConfig         : '{
//                  BaseAddr           : 'h0000E000
//                 ,FormatStringPtr    : "32c:32p"
//                 ,NumEntries         : 1024
//                 ,RamFrequencyHz     : 200000000
//                 ,LookupFrequencyHz  : 200000000
//                 ,LookupsPerSec      : 15000000
//                 ,ResponseSizeBits   : 106
//                 ,PrioritySizeBits   : XIL_VITIS_NET_P4_CAM_PRIORITY_SIZE_DEFAULT
//                 ,NumMasks           : 32
//                 ,Endian             : XIL_VITIS_NET_P4_LITTLE_ENDIAN
//                 ,MemType            : XIL_VITIS_NET_P4_CAM_MEM_BRAM
//                 ,RamSizeKbytes      : 0
//                 ,OptimizationType   : XIL_VITIS_NET_P4_CAM_OPTIMIZE_NONE
//             },
//             ActionIdWidthBits : 2,
//             ActionListSize    : 3,
//             ActionListPtr     : XilVitisNetP4TableActions_ipv4_fib_egress
//         },
//         PrivateCtxPtr  : null
//     };

//     // list of all tables defined in the design
//     XilVitisNetP4TargetTableConfig XilVitisNetP4TableList[] =
//     '{
//         XilVitisNetP4Table_intf_map,
//         XilVitisNetP4Table_vlan_map,
//         XilVitisNetP4Table_lfib,
//         XilVitisNetP4Table_cmp_ipv4_fib,
//         XilVitisNetP4Table_ipv4_fib_ingress,
//         XilVitisNetP4Table_cmp_mac_fib,
//         XilVitisNetP4Table_ipv4_fib_egress
//     };

//     // Build info
//     XilVitisNetP4TargetBuildInfoConfig XilVitisNetP4BuildInfo =
//     '{
//         BaseAddr : 'h00000000
//     };

//     // Interrupt controller
//     XilVitisNetP4TargetInterruptConfig XilVitisNetP4Interrupt =
//     '{
//         BaseAddr          : 'h00000008,
//         NumP4Elements     : 7,
//         NumComponents     : 2,
//         ComponentNameList : '{
//             '{
//                 NameStringPtr : "MetadataFIFO"
//             },
//             '{
//                 NameStringPtr : "PacketFIFO"
//             }
//         }
//     };

//     // Operations controller
//     XilVitisNetP4TargetCtrlConfig XilVitisNetP4Control =
//     '{
//         BaseAddr      : 'h000000E8,
//         NumP4Elements : 7,
//         NumComponents : 2,
//         ClkInHz       : 200000000,
//         PktRatePerSec : 15000000
//     };

//     // Top Level VitisNetP4 Configuration
//     XilVitisNetP4TargetConfig XilVitisNetP4Config_vitis_net_p4_frr_t1_ecp =
//     '{
//         BuildInfoPtr  : XilVitisNetP4BuildInfo,
//         InterruptPtr  : XilVitisNetP4Interrupt,
//         CtrlConfigPtr : XilVitisNetP4Control,
//         Endian        : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//         TableListSize : 7,
//         TableListPtr  : XilVitisNetP4TableList
//     };

// ////////////////////////////////////////////////////////////////////////////////
// // Tasks and Functions
// ////////////////////////////////////////////////////////////////////////////////

//     // get table ID
//     function int get_table_id;
//        input string table_name;

//        for (int tbl_idx = 0; tbl_idx < XilVitisNetP4TableList.size(); tbl_idx++) begin
//            if (table_name == XilVitisNetP4TableList[tbl_idx].NameStringPtr) begin
//                return tbl_idx;
//            end
//        end

//        return -1;
//     endfunction

//     // get action ID
//     function int get_action_id;
//        input string table_name;
//        input string action_name;

//        for (int tbl_idx = 0; tbl_idx < XilVitisNetP4TableList.size(); tbl_idx++) begin
//            if (table_name == XilVitisNetP4TableList[tbl_idx].NameStringPtr) begin
//                for (int act_idx = 0; act_idx < XilVitisNetP4TableList[tbl_idx].Config.ActionListPtr.size(); act_idx++) begin
//                    if (action_name == XilVitisNetP4TableList[tbl_idx].Config.ActionListPtr[act_idx].NameStringPtr) begin
//                        return act_idx;
//                    end
//                end
//            end
//        end

//        return -1;
//     endfunction

//     // Initialize and instantiate all required drivers: tables, externs, etc. ...
//     task initialize;
//         input string axi_lite_master;

//         chandle env, config_data;
//         int unsigned cfg_size;

//         env = XilVitisNetP4DpiGetEnv(axi_lite_master);

//         if (env != null) begin
//             for (int tbl_idx = 0; tbl_idx < XilVitisNetP4TableList.size(); tbl_idx++) begin
//                 case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//                     XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                         XilVitisNetP4BcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                     XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                         XilVitisNetP4TinyBcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                     XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                         XilVitisNetP4TcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                     XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                         XilVitisNetP4StcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                     XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                         XilVitisNetP4TinyTcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                     XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                         XilVitisNetP4DcamInit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, env, XilVitisNetP4TableList[tbl_idx].Config.CamConfig);
//                     end
//                 endcase
//             end
//         end

//     endtask

//     // Terminate and destroy all instantiated drivers: tables, externs, etc. ...
//     task terminate;

//         for (int tbl_idx = 0; tbl_idx < XilVitisNetP4TableList.size(); tbl_idx++) begin
//             case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//                 XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                     XilVitisNetP4BcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                     XilVitisNetP4TinyBcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                     XilVitisNetP4TcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                     XilVitisNetP4StcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                     XilVitisNetP4TinyTcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                     XilVitisNetP4DcamExit(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//             endcase
//         end

//     endtask

//     // Add entry to a table.
//     // Usage: table_add <table name> <entry key> <key mask> <entry response> <entry priority>
//     task table_add;
//         input  string      table_name;
//         input  bit[1023:0] entry_key;
//         input  bit[1023:0] key_mask;
//         input  bit[1023:0] entry_response;
//         input  int         entry_priority;

//         int tbl_idx;
//         tbl_idx = get_table_id(table_name);

//         case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//             XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                 XilVitisNetP4BcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                 XilVitisNetP4TinyBcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                 XilVitisNetP4TcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), entry_priority, byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                 XilVitisNetP4StcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), entry_priority, byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                 XilVitisNetP4TinyTcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), entry_priority, byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                 XilVitisNetP4DcamInsert(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, int'(entry_key), byteArray'(entry_response));
//             end
//         endcase

//     endtask

//     // Modify entry from a table.
//     // Usage: table_modify <table name> <entry key> <key mask> <entry response>
//     task table_modify;
//         input string      table_name;
//         input bit[1023:0] entry_key;
//         input bit[1023:0] key_mask;
//         input bit[1023:0] entry_response;

//         int tbl_idx;
//         tbl_idx = get_table_id(table_name);

//         case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//             XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                 XilVitisNetP4BcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                 XilVitisNetP4TinyBcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                 XilVitisNetP4TcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                 XilVitisNetP4StcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                 XilVitisNetP4TinyTcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask), byteArray'(entry_response));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                 XilVitisNetP4DcamUpdate(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, int'(entry_key), byteArray'(entry_response));
//             end
//         endcase

//     endtask

//     // Delete entry from a match table.
//     // Usage: table_delete <table name> <entry key> <key mask>
//     task table_delete;
//         input string      table_name;
//         input bit[1023:0] entry_key;
//         input bit[1023:0] key_mask;

//         int tbl_idx;
//         tbl_idx = get_table_id(table_name);

//         case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//             XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                 XilVitisNetP4BcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                 XilVitisNetP4TinyBcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                 XilVitisNetP4TcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                 XilVitisNetP4StcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                 XilVitisNetP4TinyTcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, byteArray'(entry_key), byteArray'(key_mask));
//             end
//             XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                 XilVitisNetP4DcamDelete(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr, int'(entry_key));
//             end
//         endcase

//     endtask

//     // Reset all state in the switch (tables and externs, etc.), but P4 config is preserved.
//     // Usage: reset_state
//     task reset_state;

//         for (int tbl_idx = 0; tbl_idx < XilVitisNetP4TableList.size(); tbl_idx++) begin
//             case (XilVitisNetP4TableList[tbl_idx].Config.Mode)
//                 XIL_VITIS_NET_P4_TABLE_MODE_BCAM : begin
//                     XilVitisNetP4BcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TINY_BCAM : begin
//                     XilVitisNetP4TinyBcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TCAM : begin
//                     XilVitisNetP4TcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_STCAM : begin
//                     XilVitisNetP4StcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_TINY_TCAM : begin
//                     XilVitisNetP4TinyTcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//                 XIL_VITIS_NET_P4_TABLE_MODE_DCAM : begin
//                     XilVitisNetP4DcamReset(XilVitisNetP4TableList[tbl_idx].PrivateCtxPtr);
//                 end
//             endcase
//         end

//     endtask

// ////////////////////////////////////////////////////////////////////////////////
// // DPI imports
// ////////////////////////////////////////////////////////////////////////////////

//     // Utilities
//     import "DPI-C" context function chandle XilVitisNetP4DpiGetEnv(string hier_path);
//     import "DPI-C" context function chandle XilVitisNetP4DpiByteArrayCreate(int unsigned bit_len);
//     import "DPI-C" context function void XilVitisNetP4DpiStringToByteArray(string str, chandle key_mask, int unsigned bit_len);
//     import "DPI-C" context function void XilVitisNetP4DpiByteArrayDestroy(chandle key_mask);
//     import "DPI-C" context function void XilVitisNetP4CamSetDebugFlags(int unsigned flags);
//     import "DPI-C" context function void FillCamConfigsFromJson(input string file_path);
//     import "DPI-C" context function void FindCamConfigByName(input string table_name, chandle ConfigBinDataPtrPtr, inout int unsigned ConfigDataNumBytesPtr);

//     // BuildInfo Driver API
//     import "DPI-C" context task XilVitisNetP4TargetBuildInfoInit(inout XilVitisNetP4TargetBuildInfoCtx ctx, input chandle env, input XilVitisNetP4TargetBuildInfoConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TargetBuildInfoGetIpVersion(inout XilVitisNetP4TargetBuildInfoCtx ctx, XilVitisNetP4Version ip_version);
//     import "DPI-C" context task XilVitisNetP4TargetBuildInfoGetIpSettings(inout XilVitisNetP4TargetBuildInfoCtx ctx, XilVitisNetP4TargetBuildInfoIpSettings ip_settings);
//     import "DPI-C" context task XilVitisNetP4TargetBuildInfoExit(inout XilVitisNetP4TargetBuildInfoCtx ctx);

//     // Interrupt Driver API
//     import "DPI-C" context function int XilVitisNetP4TargetInterruptGetP4ElementCount(inout XilVitisNetP4TargetInterruptCtx ctx, int unsigned num_elements);
//     import "DPI-C" context function int XilVitisNetP4TargetInterruptGetComponentCount(inout XilVitisNetP4TargetInterruptCtx ctx, int unsigned num_components);
//     import "DPI-C" context function int XilVitisNetP4TargetInterruptGetComponentIndexByName(inout XilVitisNetP4TargetInterruptCtx ctx, input string component_name, int unsigned idx);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptInit(inout XilVitisNetP4TargetInterruptCtx ctx, input chandle env, input XilVitisNetP4TargetInterruptConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptEnableP4ElementEccErrorById(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned element_id, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptDisableP4ElementEccErrorById(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned element_id, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptGetP4ElementEccErrorStatusById(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned element_id, XilVitisNetP4TargetInterruptEccErrorStatus status);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptClearP4ElementEccErrorStatusById(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned element_id, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptEnableComponentEccErrorByIndex(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned fifo_idx, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptDisableComponentEccErrorByIndex(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned fifo_idx, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptGetComponentEccErrorStatusByIndex(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned fifo_idx, XilVitisNetP4TargetInterruptEccErrorStatus status);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptClearComponentEccErrorStatusByIndex(inout XilVitisNetP4TargetInterruptCtx ctx, input int unsigned fifo_idx, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetInterruptExit(inout XilVitisNetP4TargetInterruptCtx ctx);

//     // Control Driver API
//     import "DPI-C" context task XilVitisNetP4TargetCtrlInit(inout XilVitisNetP4TargetControlCtx ctx, input chandle env, input XilVitisNetP4TargetCtrlConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlExit(inout XilVitisNetP4TargetControlCtx ctx);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlGetP4ElementCount(inout XilVitisNetP4TargetControlCtx ctx, int unsigned num_p4_elements);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlGetClkInHz(inout XilVitisNetP4TargetControlCtx ctx, int unsigned clk_in_hz);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlGetNumComponents(inout XilVitisNetP4TargetControlCtx ctx, int unsigned num_components);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlGetPktRatePerSec(inout XilVitisNetP4TargetControlCtx ctx, int unsigned pkt_rate_per_sec);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlSoftResetEngine(inout XilVitisNetP4TargetControlCtx ctx, XilVitisNetP4ControlEngineId EngineId);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlSetPacketRateLimitMargin(inout XilVitisNetP4TargetControlCtx ctx, input int unsigned packet_rate_margin);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlGetPacketRateLimitMargin(inout XilVitisNetP4TargetControlCtx ctx, int unsigned packet_rate_margin);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlIpComponentEnableInjectEccError(inout XilVitisNetP4TargetControlCtx ctx, input int unsigned component_index, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlIpComponentDisableInjectEccError(inout XilVitisNetP4TargetControlCtx ctx, input int unsigned component_index, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlP4ElementEnableInjectEccError(inout XilVitisNetP4TargetControlCtx ctx, input int unsigned p4_element_id, XilVitisNetP4InterruptEccErrorType ecc_type);
//     import "DPI-C" context task XilVitisNetP4TargetCtrlP4ElementDisableInjectEccError(inout XilVitisNetP4TargetControlCtx ctx, input int unsigned p4_element_id, XilVitisNetP4InterruptEccErrorType ecc_type);

//     // BCAM API
//     import "DPI-C" context task XilVitisNetP4BcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4BcamInsert(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4BcamUpdate(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4BcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, byteArray key);
//     import "DPI-C" context task XilVitisNetP4BcamGetByKey(inout XilVitisNetP4CamCtx ctx, input byteArray key, inout byteArray resp);
//     import "DPI-C" context task XilVitisNetP4BcamDelete(inout XilVitisNetP4CamCtx ctx, input byteArray key);
//     import "DPI-C" context task XilVitisNetP4BcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4BcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4BcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4BcamExit(inout XilVitisNetP4CamCtx ctx);

//     // Tiny BCAM API
//     import "DPI-C" context task XilVitisNetP4TinyBcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TinyBcamInsert(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyBcamUpdate(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyBcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, byteArray key);
//     import "DPI-C" context task XilVitisNetP4TinyBcamGetByKey(inout XilVitisNetP4CamCtx ctx, input byteArray key, inout byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyBcamDelete(inout XilVitisNetP4CamCtx ctx, input byteArray key);
//     import "DPI-C" context task XilVitisNetP4TinyBcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4TinyBcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4TinyBcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4TinyBcamExit(inout XilVitisNetP4CamCtx ctx);

//     // TCAM Driver API
//     import "DPI-C" context task XilVitisNetP4TcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TcamInsert(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TcamUpdate(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, byteArray key, byteArray key_mask);
//     import "DPI-C" context task XilVitisNetP4TcamGetByKey(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, inout int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TcamLookup(inout XilVitisNetP4CamCtx ctx, input byteArray key, inout byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TcamDelete(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask);
//     import "DPI-C" context task XilVitisNetP4TcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4TcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4TcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4TcamExit(inout XilVitisNetP4CamCtx ctx);

//     // Tiny TCAM API
//     import "DPI-C" context task XilVitisNetP4TinyTcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4TinyTcamInsert(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyTcamUpdate(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyTcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, byteArray key, byteArray key_mask);
//     import "DPI-C" context task XilVitisNetP4TinyTcamGetByKey(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, inout int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4TinyTcamDelete(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask);
//     import "DPI-C" context task XilVitisNetP4TinyTcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4TinyTcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4TinyTcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4TinyTcamExit(inout XilVitisNetP4CamCtx ctx);

//     // STCAM Driver API
//     import "DPI-C" context task XilVitisNetP4StcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4StcamInsert(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4StcamUpdate(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4StcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, byteArray key, byteArray key_mask);
//     import "DPI-C" context task XilVitisNetP4StcamGetByKey(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask, inout int unsigned prio, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4StcamLookup(inout XilVitisNetP4CamCtx ctx, input byteArray key, inout byteArray resp);
//     import "DPI-C" context task XilVitisNetP4StcamDelete(inout XilVitisNetP4CamCtx ctx, input byteArray key, byteArray mask);
//     import "DPI-C" context task XilVitisNetP4StcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4StcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4StcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4StcamExit(inout XilVitisNetP4CamCtx ctx);

//     // DCAM Driver API
//     import "DPI-C" context task XilVitisNetP4DcamInit(inout XilVitisNetP4CamCtx ctx, input chandle env, XilVitisNetP4CamConfig cfg);
//     import "DPI-C" context task XilVitisNetP4DcamInsert(inout XilVitisNetP4CamCtx ctx, input int unsigned key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4DcamUpdate(inout XilVitisNetP4CamCtx ctx, input int unsigned key, byteArray resp);
//     import "DPI-C" context task XilVitisNetP4DcamGetByResponse(inout XilVitisNetP4CamCtx ctx, input byteArray resp, byteArray resp_mask, inout int unsigned pos, inout int unsigned key);
//     import "DPI-C" context task XilVitisNetP4DcamLookup(inout XilVitisNetP4CamCtx ctx, input int unsigned key, inout byteArray resp);
//     import "DPI-C" context task XilVitisNetP4DcamDelete(inout XilVitisNetP4CamCtx ctx, input int unsigned key);
//     import "DPI-C" context task XilVitisNetP4DcamGetEccCountersClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned corrected_single, inout int unsigned uncorrected_double);
//     import "DPI-C" context task XilVitisNetP4DcamGetEccAddressesClearOnRead(inout XilVitisNetP4CamCtx ctx, inout int unsigned failing_address_single, inout int unsigned failing_address_double);
//     import "DPI-C" context task XilVitisNetP4DcamReset(inout XilVitisNetP4CamCtx ctx);
//     import "DPI-C" context task XilVitisNetP4DcamExit(inout XilVitisNetP4CamCtx ctx);

// `endif

endpackage

`default_nettype wire