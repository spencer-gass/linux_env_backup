// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router Top Level Module
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router #(
    parameter bit [15:0]  MODULE_ID = 0,

    parameter int NUM_8B_ING_PHYS_PORTS  = 0,
    parameter int NUM_16B_ING_PHYS_PORTS = 0,
    parameter int NUM_32B_ING_PHYS_PORTS = 0,
    parameter int NUM_64B_ING_PHYS_PORTS = 0,

    parameter int NUM_8B_EGR_PHYS_PORTS  = 0,
    parameter int NUM_16B_EGR_PHYS_PORTS = 0,
    parameter int NUM_32B_EGR_PHYS_PORTS = 0,
    parameter int NUM_64B_EGR_PHYS_PORTS = 0,

    parameter int VNP4_IP_SEL = 0,
    parameter int VNP4_DATA_BYTES = 0,
    parameter int VNP4_AXI4LITE_DATALEN = 32,
    parameter int VNP4_AXI4LITE_ADDRLEN = 15,

    parameter int QUEUE_MEM_URAM_DEPTH = 8,

    parameter real CLOCK_PERIOD_NS = 0,
    parameter int MTU_BYTES = 2000
) (

    Clock_int.Input    core_clk_ifc,
    Reset_int.ResetIn  core_sreset_ifc,

    Clock_int.Input    cam_clk_ifc,
    Reset_int.ResetIn  cam_sreset_ifc,

    Clock_int.Input    avmm_clk_ifc,
    Reset_int.ResetIn  interconnect_sreset_ifc,
    Reset_int.ResetIn  peripheral_sreset_ifc,

    AvalonMM_int.Slave  vnp4_avmm,
    AvalonMM_int.Slave  p4_router_avmm,

    AXIS_int.Slave      ing_8b_phys_ports  [NUM_8B_ING_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Slave      ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0],

    AXIS_int.Master     egr_8b_phys_ports  [NUM_8B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0]

);
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Import

    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam NUM_EGR_PHYS_PORTS = NUM_64B_EGR_PHYS_PORTS +
                                    NUM_32B_EGR_PHYS_PORTS +
                                    NUM_16B_EGR_PHYS_PORTS +
                                    NUM_8B_EGR_PHYS_PORTS;

    localparam NUM_ING_PHYS_PORTS = NUM_64B_ING_PHYS_PORTS +
                                    NUM_32B_ING_PHYS_PORTS +
                                    NUM_16B_ING_PHYS_PORTS +
                                    NUM_8B_ING_PHYS_PORTS;

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);
    localparam NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);

    localparam NUM_QUEUES = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam NUM_QUEUES_LOG = $clog2(NUM_QUEUES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(VNP4_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_ING_PHYS_PORTS-1:0]  ing_phys_ports_enable;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_cnts_clear;
    logic [ING_COUNTERS_WIDTH-1:0]  ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0];
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_ports_conneted;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_buf_overflow;

    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_phys_ports_enable;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_cnts_clear;
    logic [EGR_COUNTERS_WIDTH-1:0]  egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0];
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_ports_conneted;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_full_drop;

    logic                           ing_bus_sof;

    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_ready;

    logic [NUM_ING_PHYS_PORTS-1:0] ing_policer_enable;
    bucket_decrement_t        ing_policer_decrement       [NUM_ING_PHYS_PORTS-1:0];
    bucket_depth_threshold_t  ing_policer_depth_threshold [NUM_ING_PHYS_PORTS-1:0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interface Declarations

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES         ),
        .USER_WIDTH ( INGRESS_METADATA_WIDTH )
    ) ingressed_packets (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES         ),
        .USER_WIDTH ( VNP4_WRAPPER_METADATA_WIDTH )
    ) classified_packets (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES             ),
        .USER_WIDTH ( QUEUE_SYS_METADATA_WIDTH )
    ) dequeued_words (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interface Declarations

    AXI4Lite_int #(
        .DATALEN    ( VNP4_AXI4LITE_DATALEN   ),
        .ADDRLEN    ( VNP4_AXI4LITE_ADDRLEN   )
    ) vnp4_a4l (
        .clk        ( avmm_clk_ifc.clk        ),
        .sresetn    ( interconnect_sreset_ifc.reset != interconnect_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) ing_policer_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN  ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) cong_man_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_COUNTER_WIDTH    ),
        .ADDRLEN    ( QSYS_COUNTER_ID_WIDTH )
    ) cong_man_counter_access (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Registers

    p4_router_avmm_regs
    #(
        .MODULE_ID          ( MODULE_ID              ),
        .MTU_BYTES          ( MTU_BYTES              ),
        .VNP4_DATA_BYTES    ( VNP4_DATA_BYTES        ),
        .CLOCK_PERIOD_NS    ( CLOCK_PERIOD_NS        ),
        .ING_COUNTERS_WIDTH ( ING_COUNTERS_WIDTH     ),
        .EGR_COUNTERS_WIDTH ( EGR_COUNTERS_WIDTH     ),
        .NUM_ING_PHYS_PORTS ( NUM_ING_PHYS_PORTS     ),
        .NUM_EGR_PHYS_PORTS ( NUM_EGR_PHYS_PORTS     )
    ) p4_router_regs (
        .avmm_clk_ifc                ( avmm_clk_ifc                ),
        .interconnect_sreset_ifc     ( interconnect_sreset_ifc     ),
        .peripheral_sreset_ifc       ( peripheral_sreset_ifc       ),
        .core_clk_ifc                ( core_clk_ifc                ),
        .core_sreset_ifc             ( core_sreset_ifc             ),
        .avmm                        ( p4_router_avmm              ),
        .ing_phys_ports_enable       ( ing_phys_ports_enable       ),
        .ing_cnts_clear              ( ing_cnts_clear              ),
        .ing_cnts                    ( ing_cnts                    ),
        .ing_ports_conneted          ( ing_ports_conneted          ),
        .ing_buf_overflow            ( ing_buf_overflow            ),
        .ing_policer_enable          ( ing_policer_enable          ),
        .ing_policer_table_config    ( ing_policer_table_config    ),
        .cong_man_table_config       ( cong_man_table_config       ),
        .cong_man_counter_access     ( cong_man_counter_access     ),
        .egr_phys_ports_enable       ( egr_phys_ports_enable       ),
        .egr_cnts_clear              ( egr_cnts_clear              ),
        .egr_cnts                    ( egr_cnts                    ),
        .egr_ports_conneted          ( egr_ports_conneted          ),
        .egr_buf_full_drop           ( egr_buf_full_drop           )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ingress

    p4_router_ingress #(
        .NUM_8B_ING_PHYS_PORTS ( NUM_8B_ING_PHYS_PORTS  ),
        .NUM_16B_ING_PHYS_PORTS( NUM_16B_ING_PHYS_PORTS ),
        .NUM_32B_ING_PHYS_PORTS( NUM_32B_ING_PHYS_PORTS ),
        .NUM_64B_ING_PHYS_PORTS( NUM_64B_ING_PHYS_PORTS ),
        .MTU_BYTES             ( MTU_BYTES              )
    ) ingress (
        .ing_8b_phys_ports          ( ing_8b_phys_ports         ),
        .ing_16b_phys_ports         ( ing_16b_phys_ports        ),
        .ing_32b_phys_ports         ( ing_32b_phys_ports        ),
        .ing_64b_phys_ports         ( ing_64b_phys_ports        ),
        .ing_bus                    ( ingressed_packets         ),
        .ing_phys_ports_enable      ( ing_phys_ports_enable     ),
        .ing_cnts_clear             ( ing_cnts_clear            ),
        .ing_cnts                   ( ing_cnts                  ),
        .ing_ports_conneted         ( ing_ports_conneted        ),
        .ing_buf_overflow           ( ing_buf_overflow          )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4

    avmm_to_axi4lite vnp4_avmm_to_axi4lite
    (
        .clk_ifc                    ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .avmm                       ( vnp4_avmm                 ),
        .axi4lite                   ( vnp4_a4l                  )
    );

    p4_router_vnp4_wrapper_select #(
        .VNP4_DATA_BYTES         ( VNP4_DATA_BYTES         ),
        .VNP4_IP_SEL             ( VNP4_IP_SEL             )
    ) vnp4_wrapper_select (
        .cam_clk                    ( cam_clk_ifc.clk           ),
        .cam_sresetn                ( cam_sreset_ifc.reset != cam_sreset_ifc.ACTIVE_HIGH    ),
        .control                    ( vnp4_a4l                  ),
        .packet_data_in             ( ingressed_packets         ),
        .packet_data_out            ( classified_packets        ),
        .ram_ecc_event              (                           )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue System

    p4_router_queue_system #(
        .NUM_ING_PORTS          ( NUM_ING_PHYS_PORTS    ),
        .NUM_EGR_PORTS          ( NUM_EGR_PHYS_PORTS    ),
        .QUEUE_MEM_URAM_DEPTH   ( QUEUE_MEM_URAM_DEPTH  ),
        .MTU_BYTES              ( MTU_BYTES             )
    ) queue_system (
        .ing_policer_enable          ( ing_policer_enable          ),
        .ing_policer_table_config    ( ing_policer_table_config    ),
        .cong_man_table_config       ( cong_man_table_config       ),
        .cong_man_counter_access     ( cong_man_counter_access     ),
        .packet_in                   ( classified_packets          ),
        .egr_buf_ready               ( egr_buf_ready               ),
        .word_out                    ( dequeued_words              )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress

    p4_router_egress #(
        .NUM_8B_EGR_PHYS_PORTS  ( NUM_8B_EGR_PHYS_PORTS  ),
        .NUM_16B_EGR_PHYS_PORTS ( NUM_16B_EGR_PHYS_PORTS ),
        .NUM_32B_EGR_PHYS_PORTS ( NUM_32B_EGR_PHYS_PORTS ),
        .NUM_64B_EGR_PHYS_PORTS ( NUM_64B_EGR_PHYS_PORTS ),
        .MTU_BYTES              ( MTU_BYTES              )
    ) egress (
        .egr_bus                ( dequeued_words        ),
        .egr_buf_ready          ( egr_buf_ready         ),
        .egr_8b_phys_ports      ( egr_8b_phys_ports     ),
        .egr_16b_phys_ports     ( egr_16b_phys_ports    ),
        .egr_32b_phys_ports     ( egr_32b_phys_ports    ),
        .egr_64b_phys_ports     ( egr_64b_phys_ports    ),
        .egr_phys_ports_enable  ( egr_phys_ports_enable ),
        .egr_cnts_clear         ( egr_cnts_clear        ),
        .egr_cnts               ( egr_cnts              ),
        .egr_ports_conneted     ( egr_ports_conneted    ),
        .egr_buf_full_drop      ( egr_buf_full_drop     )
    );


endmodule

`default_nettype wire
