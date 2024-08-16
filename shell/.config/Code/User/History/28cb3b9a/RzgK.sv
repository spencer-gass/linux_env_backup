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
module board_pcuecp_system

#(

) (




);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PPL

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq Data Busses


    // Ethernet frames from PS to MPCU in PL (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) mpcu_ethernet_ps_to_mpcu (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from MPCU in PL to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) mpcu_ethernet_mpcu_to_ps (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from PL to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pl_ethernet_sgmii_to_ps (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from PS to PL (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pl_ethernet_ps_to_sgmii (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_ethernet_from_ps [5:0] (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_ethernet_to_ps [5:0] (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );



    p4_router #(
        .MODULE_ID                  ( 0     ),
        .NUM_8B_ING_PHYS_PORTS      ( 4     ),
        .NUM_8B_EGR_PHYS_PORTS      ( 4     ),
        .VNP4_DATA_BYTES            ( 64    ),
        .ING_PORT_METADATA_WIDTH    ( 10    ),
        .EGR_SPEC_METADATA_WIDTH    ( 10    ),
        .MTU_BYTES                  ( 2000  )
    ) (
        .core_clk_ifc               (  ),
        .core_sreset_ifc            (  ),
        .cam_clk_ifc                (  ),
        .cam_sreset_ifc             (  ),
        .avmm_clk_ifc               (  ),
        .interconnect_sreset_ifc    (  ),
        .peripheral_sreset_ifc      (  ),
        .vnp4_avmm                  (  ),
        .p4_router_avmm             (  ),
        .ing_8b_phys_ports          ( pspl_ethernet_from_ps[5:2] ),
        .ing_16b_phys_ports         (  ),
        .ing_32b_phys_ports         (  ),
        .ing_64b_phys_ports         (  ),
        .egr_8b_phys_ports          ( pspl_ethernet_to_ps[5:2] ),
        .egr_16b_phys_ports         (  ),
        .egr_32b_phys_ports         (  ),
        .egr_64b_phys_ports         (  )
    );


endmodule

`default_nettype wire
