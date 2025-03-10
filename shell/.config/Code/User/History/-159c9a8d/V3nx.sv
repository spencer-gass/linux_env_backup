// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Vitis Networking P4 FRR T1 ECP Package
 *
 * Contains relevant types and constants for a specific configuration of vitis_net_p4 IP.
 * Copied from 15eglv_pcuecp/pcuecp.gen/sources_1/ip/vitis_net_p4_echo_phys_port_ecp/src/verilog/vitis_net_p4_echo_phys_port_ecp_pkg.sv
 *
**/

`default_nettype none

package p4_router_vnp4_echo_phys_port_ecp_pkg;

////////////////////////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////////////////////////

    // IP configuration info
    localparam JSON_FILE             = "/home/sgass/Projects/kepler/hdl/vivado/workspace/15eglv_pcuecp/pcuecp.gen/sources_1/ip/vitis_net_p4_echo_phys_port_ecp/main.json"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4_FILE               = "/home/sgass/Projects/kepler/p4/echo_phys_port.p4"; // Note: this localparam is not used internally in the IP, it is just for reference
    localparam P4C_ARGS              = " ";

    localparam PACKET_RATE           = 15;
    localparam AXIS_CLK_FREQ_MHZ     = 200;
    localparam CAM_MEM_CLK_FREQ_MHZ  = 200;
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
    localparam S_AXI_ADDR_WIDTH      = 13;
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
//             NameStringPtr : "user_metadata_t.ing_port",
//             Value         : 8
//         },
//         '{
//             NameStringPtr : "user_metadata_t.egr_spec",
//             Value         : 8
//         },
//         '{
//             NameStringPtr : "user_metadata_t.prio",
//             Value         : 3
//         },
//         '{
//             NameStringPtr : "user_metadata_t.byte_length",
//             Value         : 14
//         }
//     };

//     // list of all tables defined in the design
//     XilVitisNetP4TargetTableConfig XilVitisNetP4TableList[] =
//     {
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
//         NumP4Elements     : 0,
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
//         NumP4Elements : 0,
//         NumComponents : 2,
//         ClkInHz       : 200000000,
//         PktRatePerSec : 15000000
//     };

//     // Top Level VitisNetP4 Configuration
//     XilVitisNetP4TargetConfig XilVitisNetP4Config_vitis_net_p4_echo_phys_port_ecp =
//     '{
//         BuildInfoPtr  : XilVitisNetP4BuildInfo,
//         InterruptPtr  : XilVitisNetP4Interrupt,
//         CtrlConfigPtr : XilVitisNetP4Control,
//         Endian        : XIL_VITIS_NET_P4_LITTLE_ENDIAN,
//         TableListSize : 0,
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

//--------------------------------------------------------------------------
// Machine-generated file - do NOT modify by hand !
// File created on 18 of October, 2024 @ 14:13:00
// by VitisNetP4 IP, version v1.0 revision 2
//--------------------------------------------------------------------------
