// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Vitis Net P4 wrapper select module
 * Generates the appropriate wrapper containing a project specific instance of VNP4
**/
module p4_router_vnp4_wrapper_select #(
    parameter int EGR_SPEC_METADATA_WIDTH = 0,
    parameter int ING_PORT_METADATA_WIDTH = 0,
    parameter int USER_METADATA_WIDTH     = EGR_SPEC_METADATA_WIDTH + ING_PORT_METADATA_WIDTH,
    parameter int VNP4_DATA_BYTES         = 0,
    parameter int VNP4_IP_SEL             = 0,
    parameter bit DEBUG_ILA               = 1'b0
) (
    input var logic     cam_clk,
    input var logic     cam_sresetn,

    AXI4Lite_int.Slave  control,

    AXIS_int.Slave      packet_data_in,
    AXIS_int.Master     packet_data_out,

    output var logic    ram_ecc_event
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_GT(VNP4_IP_SEL, 0);
    `ELAB_CHECK_LT(VNP4_IP_SEL, NUM_VNP4_IP_OPTIONS);
    `ELAB_CHECK_EQUAL(VNP4_DATA_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(VNP4_DATA_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4 Wrapper Generate


    generate
        case (VNP4_IP_SEL)
            ECHO_PHYS_PORT: begin
                p4_router_vnp4_echo_phys_port_wrapper #(
                    .DEBUG_ILA (DEBUG_ILA)
                ) vnp4_wrapper (
                    .cam_clk            ( cam_clk         ),
                    .cam_sresetn        ( cam_sresetn     ),
                    .control            ( control         ),
                    .packet_data_in     ( packet_data_in  ),
                    .packet_data_out    ( packet_data_out ),
                    .ram_ecc_event      ( ram_ecc_event   )
                );
            end
            FRR_T1_ECP: begin
                p4_router_vnp4_frr_t1_ecp_wrapper #(
                    .DEBUG_ILA (DEBUG_ILA)
                ) vnp4_wrapper (
                    .cam_clk            ( cam_clk         ),
                    .cam_sresetn        ( cam_sresetn     ),
                    .control            ( control         ),
                    .packet_data_in     ( packet_data_in  ),
                    .packet_data_out    ( packet_data_out ),
                    .ram_ecc_event      ( ram_ecc_event   )
                );
            end
            FRR_T1_MPCU: begin
                p4_router_vnp4_frr_t1_mpcu_wrapper #(
                    .DEBUG_ILA (DEBUG_ILA)
                ) vnp4_wrapper (
                    .cam_clk            ( cam_clk         ),
                    .cam_sresetn        ( cam_sresetn     ),
                    .control            ( control         ),
                    .packet_data_in     ( packet_data_in  ),
                    .packet_data_out    ( packet_data_out ),
                    .ram_ecc_event      ( ram_ecc_event   )
                );
            end
        endcase
    endgenerate

endmodule

`default_nettype wire
