// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

`include "board_pcuecp_config.svh"

`define DEFINED(A) `ifdef A 1 `else 0 `endif

/**
 * Instantiation and connection of high-level blocks for the S-UE-SDR
 */
module board_pcuecp_p4_router_wrapper #(
    parameter bit [15:0]  MODULE_ID = 0,
    parameter int         NUM_PS_TO_PL_LINKS = 4,
    parameter int         MTU_BYTES = 2000
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

    AXIS_int.Slave      ingress_from_ps  [NUM_PS_TO_PL_LINKS-1:0],
    AXIS_int.Master     egress_to_ps     [NUM_PS_TO_PL_LINKS-1:0]
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS interface arrays

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_ing_16b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_ing_32b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) unused_ing_64b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_egr_16b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_egr_32b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) unused_egr_64b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: P4 Router

    p4_router #(
        .MODULE_ID                  ( 0                                                             ),
        .NUM_8B_ING_PHYS_PORTS      ( NUM_PS_TO_PL_LINKS                                            ),
        .NUM_8B_EGR_PHYS_PORTS      ( NUM_PS_TO_PL_LINKS                                            ),
        .VNP4_IP_SEL                ( FRR_T1_ECP                                                    ),
        .VNP4_DATA_BYTES            ( vitis_net_p4_frr_t1_ecp_pkg::TDATA_NUM_BYTES                  ),
        .ING_PORT_METADATA_WIDTH    ( vitis_net_p4_frr_t1_ecp_pkg::USER_METADATA_INGRESS_PORT_WIDTH ),
        .EGR_SPEC_METADATA_WIDTH    ( vitis_net_p4_frr_t1_ecp_pkg::USER_METADATA_EGRESS_PORT_WIDTH  ),
        .VNP4_AXI4LITE_DATALEN      ( vitis_net_p4_frr_t1_ecp_pkg::S_AXI_DATA_WIDTH                 ),
        .VNP4_AXI4LITE_ADDRLEN      ( vitis_net_p4_frr_t1_ecp_pkg::S_AXI_ADDR_WIDTH                 ),
        .MTU_BYTES                  ( 2000                                                          )
    ) p4_router_inst (
        .core_clk_ifc               ( core_clk_ifc              ),
        .core_sreset_ifc            ( core_sreset_ifc           ),
        .cam_clk_ifc                ( cam_clk_ifc               ),
        .cam_sreset_ifc             ( cam_sreset_ifc            ),
        .avmm_clk_ifc               ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .vnp4_avmm                  ( vnp4_avmm                 ),
        .p4_router_avmm             ( p4_router_avmm            ),
        .ing_8b_phys_ports          ( ingress_from_ps           ),
        .ing_16b_phys_ports         ( unused_ing_16b_phys_ports ),
        .ing_32b_phys_ports         ( unused_ing_32b_phys_ports ),
        .ing_64b_phys_ports         ( unused_ing_64b_phys_ports ),
        .egr_8b_phys_ports          ( egress_to_ps              ),
        .egr_16b_phys_ports         ( unused_egr_16b_phys_ports ),
        .egr_32b_phys_ports         ( unused_egr_32b_phys_ports ),
        .egr_64b_phys_ports         ( unused_egr_64b_phys_ports )
    );


endmodule

`default_nettype wire
