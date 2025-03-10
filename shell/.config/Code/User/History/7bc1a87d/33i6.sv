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

module p4_router_vnp4_phys_port_echo_wrapper #(
    parameter int EGR_SPEC_METADATA_WIDTH = 0,
    parameter int ING_PORT_METADATA_WIDTH = 0
) (

    input var logic                                 cam_clk,
    input var logic                                 cam_sresetn,

    AXI4Lite_int.Slave                              control,

    AXIS_int.Slave                                  packet_data_in,
    AXIS_int.Master                                 packet_data_out,

    output var logic                                ram_ecc_event

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Import

    import p4_router_pkg::*;
    import p4_router_vnp4_phys_port_echo_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function logic [USER_METADATA_T_ING_PORT_WIDTH-1:0] ingress_map(
        input logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0] ing_id
    );
        return ing_id;
    endfunction

    function logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0] egress_map(
        input logic [USER_METADATA_T_EGR_SPEC_WIDTH-1:0] egr_id
    );
        return egr_id;
    endfunction

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    ingress_metadata_t ingress_metadata;
    USER_META_DATA_T user_metadata_in_p4_map;
    USER_META_DATA_T user_metadata_out_p4_map;
    vnp4_wrapper_metadata_t vnp4_wrapper_metadata;

    logic user_metadata_in_valid;
    logic user_metadata_out_valid;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Convert between RTL port indecies and port ids defined in p4

    assign ingress_metadata = packet_data_in.tuser;

    assign user_metadata_in_p4_map.ing_port = ingress_map(ingress_metadata.ingress_port);
    assign user_metadata_in_p4_map.egr_spec = '0;
    assign vnp4_wrapper_metadata.ingress_port = user_metadata_out_p4_map.ing_port;
    assign vnp4_wrapper_metadata.egress_port = egress_map(user_metadata_out_p4_map.egr_spec);
    assign packet_data_out.tuser = vnp4_wrapper_metadata;

    `MAKE_AXIS_MONITOR(packet_data_in_monitor, packet_data_in);

    axis_sof ing_bus_sof_inst (
        .axis ( packet_data_in_monitor  ),
        .sof  ( user_metadata_in_valid  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4

    vitis_net_p4_phys_port_echo vnp4 (
    .s_axis_aclk                ( packet_data_in.clk        ),    // input wire s_axis_aclk
    .s_axis_aresetn             ( packet_data_in.sresetn    ),    // input wire s_axis_aresetn
    .s_axi_aclk                 ( control.clk               ),    // input wire s_axi_aclk
    .s_axi_aresetn              ( control.sresetn           ),    // input wire s_axi_aresetn
    // .cam_mem_aclk               ( cam_clk                   ),    // input wire cam_mem_aclk
    // .cam_mem_aresetn            ( cam_sresetn               ),    // input wire cam_mem_aresetn
    .user_metadata_in           ( user_metadata_in_p4_map   ),    // input wire [15 : 0] user_metadata_in
    .user_metadata_in_valid     ( user_metadata_in_valid    ),    // input wire user_metadata_in_valid
    .user_metadata_out          ( user_metadata_out_p4_map  ),    // output wire [15 : 0] user_metadata_out
    .user_metadata_out_valid    ( user_metadata_out_valid   ),    // output wire user_metadata_out_valid - synchronus to s_axis_aclk
    .irq                        ( ram_ecc_event             ),    // output wire irq
    .s_axis_tdata               ( packet_data_in.tdata      ),    // input wire [511 : 0] s_axis_tdata
    .s_axis_tkeep               ( packet_data_in.tkeep      ),    // input wire [63 : 0] s_axis_tkeep
    .s_axis_tlast               ( packet_data_in.tlast      ),    // input wire s_axis_tlast
    .s_axis_tvalid              ( packet_data_in.tvalid     ),    // input wire s_axis_tvalid
    .s_axis_tready              ( packet_data_in.tready     ),    // output wire s_axis_tready
    .m_axis_tdata               ( packet_data_out.tdata     ),    // output wire [511 : 0] m_axis_tdata
    .m_axis_tkeep               ( packet_data_out.tkeep     ),    // output wire [63 : 0] m_axis_tkeep
    .m_axis_tlast               ( packet_data_out.tlast     ),    // output wire m_axis_tlast
    .m_axis_tvalid              ( packet_data_out.tvalid    ),    // output wire m_axis_tvalid
    .m_axis_tready              ( packet_data_out.tready    ),    // input wire m_axis_tready
    .s_axi_araddr               ( control.araddr            ),    // input wire [14 : 0] s_axi_araddr
    .s_axi_arready              ( control.arready           ),    // output wire s_axi_arready
    .s_axi_arvalid              ( control.arvalid           ),    // input wire s_axi_arvalid
    .s_axi_awaddr               ( control.awaddr            ),    // input wire [14 : 0] s_axi_awaddr
    .s_axi_awready              ( control.awready           ),    // output wire s_axi_awready
    .s_axi_awvalid              ( control.awvalid           ),    // input wire s_axi_awvalid
    .s_axi_bready               ( control.bready            ),    // input wire s_axi_bready
    .s_axi_bresp                ( control.bresp             ),    // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid               ( control.bvalid            ),    // output wire s_axi_bvalid
    .s_axi_rdata                ( control.rdata             ),    // output wire [31 : 0] s_axi_rdata
    .s_axi_rready               ( control.rready            ),    // input wire s_axi_rready
    .s_axi_rresp                ( control.rresp             ),    // output wire [1 : 0] s_axi_rresp
    .s_axi_rvalid               ( control.rvalid            ),    // output wire s_axi_rvalid
    .s_axi_wdata                ( control.wdata             ),    // input wire [31 : 0] s_axi_wdata
    .s_axi_wready               ( control.wready            ),    // output wire s_axi_wready
    .s_axi_wstrb                ( control.wstrb             ),    // input wire [3 : 0] s_axi_wstrb
    .s_axi_wvalid               ( control.wvalid            )     // input wire s_axi_wvalid
    );

endmodule

`default_nettype wire
