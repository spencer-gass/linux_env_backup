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

    parameter int VNP4_DATA_BYTES = 0,
    parameter int USER_METADATA_WIDTH = 0,
    parameter int ING_PHYS_PORT_METADATA_WIDTH = 0,
    parameter int VNP4_AXI4LITE_DATALEN = 32,
    parameter int VNP4_AXI4LITE_ADDRLEN = 15,

    parameter int MTU_BYTES = 9600
) (

    Clock_int.Output    core_clk_ifc,
    Reset_int.ResetOut  core_sreset_ifc,

    Clock_int.Output    cam_clk_ifc,
    Reset_int.ResetOut  cam_sreset_ifc,

    Clock_int.Output    avmm_clk_ifc,
    Reset_int.ResetOut  interconnect_sreset_ifc,
    Reset_int.ResetOut  peripheral_sreset_ifc,

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

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(VNP4_DATA_BYTES, 0);
    `ELAB_CHECK_GE(ING_PHYS_PORT_METADATA_WIDTH, NUM_ING_PHYS_PORTS_LOG);
    `ELAB_CHECK_GE(USER_METADATA_WIDTH, ING_PHYS_PORT_METADATA_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_ING_PHYS_PORTS-1:0]  ing_buf_overflow;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_overflow;

    logic                           ing_bus_sof;

    logic [USER_METADATA_WIDTH-1:0] user_metadata_out;
    logic                           user_metadata_out_valid;

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES  )
    ) ing_bus (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES  )
    ) egr_bus (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( VNP4_AXI4LITE_DATALEN   ),
        .ADDRLEN    ( VNP4_AXI4LITE_ADDRLEN   )
    ) axi4lite_vnp4 (
        .clk        ( avmm_clk_ifc.clk        ),
        .sresetn    ( interconnect_sreset_ifc.reset != interconnect_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Registers

    p4_router_avmm_regs
    #(
        .MODULE_ID          ( MODULE_ID          ),
        .NUM_ING_PHYS_PORTS ( NUM_ING_PHYS_PORTS ),
        .NUM_EGR_PHYS_PORTS ( NUM_EGR_PHYS_PORTS )
    ) p4_router_regs (
        .clk_ifc                    ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .avmm                       ( p4_router_avmm            ),
        .ing_buf_overflow           ( ing_buf_overflow          ),
        .egr_buf_overflow           ( egr_buf_overflow          )
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
        .clk_ifc            ( core_clk_ifc    ),
        .sreset_ifc         ( core_sreset_ifc ),

        .ing_8b_phys_ports  ( ing_8b_phys_ports  ),
        .ing_16b_phys_ports ( ing_16b_phys_ports ),
        .ing_32b_phys_ports ( ing_32b_phys_ports ),
        .ing_64b_phys_ports ( ing_64b_phys_ports ),

        .ing_bus            ( ing_bus            ),

        .ing_buf_overflow   ( ing_buf_overflow   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4

    avmm_to_axi4lite vnp4_avmm_to_axi4lite
    (
        .clk_ifc                    ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .avmm                       ( vnp4_avmm                 ),
        .axi4lite                   ( axi4lite_vnp4             )
    );

    axis_sof ing_bus_sof_inst (
        .axis ( ing_bus.Monitor ),
        .sof  ( ing_bus_sof     )
    );

    // p4_router_ingress inserts ingress physical port index into ing_bus.tuser
    // p4_router_egress exepects egress physical port select to be inserted into egr_bus.tuser
    // The user_metadata format is defined in p4. It is expected to be in the following format:
    //     struc {
    //         logic [ING_PHYS_PORT_METADATA_WIDTH-1:0]                     ing_phys_port;
    //         logic [USER_METADATA_WIDTH-1:ING_PHYS_PORT_METADATA_WIDTH]   egr_phys_port_sel;
    //     } user_metadata

    p4_router_vnp4_wrapper #(
        .USER_METADATA_WIDTH(USER_METADATA_WIDTH)
    ) vnp4_wrapper (
        .cam_clk                    ( cam_clk_ifc.clk           ),
        .cam_sresetn                ( cam_sreset_ifc.reset != cam_sreset_ifc.ACTIVE_HIGH    ),
        .control                    ( axi4lite_vnp4             ),
        .data_in                    ( ing_bus                   ),
        .user_metadata_in           ( ing_bus.tuser[ING_PHYS_PORT_METADATA_WIDTH-1:0]   ),
        .user_metadata_in_valid     ( ing_bus_sof               ),
        .data_out                   ( egr_bus                   ),
        .user_metadata_out          ( user_metadata_out         ),
        .user_metadata_out_valid    ( user_metadata_out_valid   ),
        .ram_ecc_event              (  )
    );

    assign egr_bus.tuser = user_metadata_out;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue System


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress

    p4_router_egress #(
        .NUM_8B_EGR_PHYS_PORTS  ( NUM_8B_EGR_PHYS_PORTS  ),
        .NUM_16B_EGR_PHYS_PORTS ( NUM_16B_EGR_PHYS_PORTS ),
        .NUM_32B_EGR_PHYS_PORTS ( NUM_32B_EGR_PHYS_PORTS ),
        .NUM_64B_EGR_PHYS_PORTS ( NUM_64B_EGR_PHYS_PORTS ),
        .MTU_BYTES              ( MTU_BYTES              )
    ) egress (
        .clk_ifc            ( core_clk_ifc    ),
        .sreset_ifc         ( core_sreset_ifc ),

        .egr_bus            ( egr_bus    ),

        .egr_8b_phys_ports  ( egr_8b_phys_ports  ),
        .egr_16b_phys_ports ( egr_16b_phys_ports ),
        .egr_32b_phys_ports ( egr_32b_phys_ports ),
        .egr_64b_phys_ports ( egr_64b_phys_ports ),

        .egr_buf_overflow   ( egr_buf_overflow   )  // overflow = congestion drop since there isn't a queue system yet
    );


endmodule

`default_nettype wire
