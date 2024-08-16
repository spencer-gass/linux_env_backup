// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * Vitis Net P4 wrapper select module
 * Generates the appropriate wrapper containing a project specific instance of VNP4
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_vnp4_wrapper #(
    parameter int EGR_SPEC_ID_WIDTH = 0,
    parameter int ING_PORT_ID_WIDTH = 0,
    parameter int USER_METADATA_WIDTH = EGR_SPEC_ID_WIDTH + ING_PORT_ID_WIDTH,
    parameter int VNP4_DATA_BYTES = 0,
    parameter int VNP4_IP_SEL = 0
) (

    input var logic                             cam_clk,
    input var logic                             cam_sresetn,

    AXI4Lite_int.Slave                          control,

    AXIS_int.Slave                              packet_data_in,
    input var logic [ING_PORT_ID_WIDTH-1:0]     user_metadata_in_ing_port,
    input var logic                             user_metadata_in_valid,

    AXIS_int.Master                             packet_data_out,
    output var logic [ING_PORT_ID_WIDTH-1:0]    user_metadata_out_ing_port,
    output var logic [EGR_SPEC_ID_WIDTH-1:0]    user_metadata_out_egr_spec,
    output var logic                            user_metadata_out_valid,

    output var logic                            ram_ecc_event

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import vitis_net_p4_0_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    enum {
        CPU_RTL_ING_ID,
        OISL0_RTL_ING_ID,
        OISL1_RTL_ING_ID,
        ECP0_RTL_ING_ID,
        ECP1_RTL_ING_ID,
        HDR0_RTL_ING_ID,
        HDR1_RTL_ING_ID,
        ECG0_RTL_ING_ID,
        ECG1_RTL_ING_ID,
        ECG2_RTL_ING_ID,
        ECG3_RTL_ING_ID
    } rtl_ing_ids;

    enum {
        CPU_RTL_EGR_ID,
        OISL0_RTL_EGR_ID,
        OISL1_RTL_EGR_ID,
        ECP0_RTL_EGR_ID,
        ECP1_RTL_EGR_ID,
        HDR0_RTL_EGR_ID,
        HDR1_RTL_EGR_ID,
        ECG0_RTL_EGR_ID,
        ECG1_RTL_EGR_ID,
        ECG2_RTL_EGR_ID,
        ECG3_RTL_EGR_ID
    } rtl_egr_ids;

    localparam int CPU_P4_ID   = 0;
    localparam int OISL0_P4_ID = 20;
    localparam int OISL1_P4_ID = 21;
    localparam int ECP0_P4_ID  = 40;
    localparam int ECP1_P4_ID  = 41;
    localparam int HDR0_P4_ID  = 60;
    localparam int HDR1_P4_ID  = 61;
    localparam int ECG0_P4_ID  = 80;
    localparam int ECG1_P4_ID  = 81;
    localparam int ECG2_P4_ID  = 82;
    localparam int ECG3_P4_ID  = 83;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(ING_PORT_ID_WIDTH, 0);
    `ELAB_CHECK_GT(EGR_SPEC_ID_WIDTH, 0);
    `ELAB_CHECK_EQUAL(VNP4_DATA_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(VNP4_DATA_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function logic [7:0] ingress_map(
        input logic [7:0] ing_id
    );
        case (ing_id)
            CPU_RTL_ING_ID   : return CPU_P4_ID;
            OISL0_RTL_ING_ID : return OISL0_P4_ID;
            OISL1_RTL_ING_ID : return OISL1_P4_ID;
            ECP0_RTL_ING_ID  : return ECP0_P4_ID;
            ECP1_RTL_ING_ID  : return ECP1_P4_ID;
            HDR0_RTL_ING_ID  : return HDR0_P4_ID;
            HDR1_RTL_ING_ID  : return HDR1_P4_ID;
            ECG0_RTL_ING_ID  : return ECG0_P4_ID;
            ECG1_RTL_ING_ID  : return ECG1_P4_ID;
            ECG2_RTL_ING_ID  : return ECG2_P4_ID;
            ECG3_RTL_ING_ID  : return ECG3_P4_ID;
            default: return 8'hFF;
        endcase
    endfunction

    function logic [7:0] egress_map(
        input logic [7:0] egr_id
    );
        case (egr_id)
            CPU_P4_ID   : return CPU_RTL_EGR_ID;
            OISL0_P4_ID : return OISL0_RTL_EGR_ID;
            OISL1_P4_ID : return OISL1_RTL_EGR_ID;
            ECP0_P4_ID  : return ECP0_RTL_EGR_ID;
            ECP1_P4_ID  : return ECP1_RTL_EGR_ID;
            HDR0_P4_ID  : return HDR0_RTL_EGR_ID;
            HDR1_P4_ID  : return HDR1_RTL_EGR_ID;
            ECG0_P4_ID  : return ECG0_RTL_EGR_ID;
            ECG1_P4_ID  : return ECG1_RTL_EGR_ID;
            ECG2_P4_ID  : return ECG2_RTL_EGR_ID;
            ECG3_P4_ID  : return ECG3_RTL_EGR_ID;
            default: return 8'hFF;
        endcase
    endfunction

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    USER_META_DATA_T user_metadata_in_p4_map;
    USER_META_DATA_T user_metadata_out_p4_map;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Convert between RTL port indecies and port ids defined in p4

    assign user_metadata_in_p4_map.ing_port = ingress_map(user_metadata_in_ing_port);
    assign user_metadata_in_p4_map.egr_spec = '0;
    assign user_metadata_out_ing_port = user_metadata_out_p4_map.ing_port;
    assign user_metadata_out_egr_spec = egress_map(user_metadata_out_p4_map.egr_spec);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4

    vitis_net_p4_0 vnp4 (
    .s_axis_aclk                ( packet_data_in.clk        ),    // input wire s_axis_aclk
    .s_axis_aresetn             ( packet_data_in.sresetn    ),    // input wire s_axis_aresetn
    .s_axi_aclk                 ( control.clk               ),    // input wire s_axi_aclk
    .s_axi_aresetn              ( control.sresetn           ),    // input wire s_axi_aresetn
    .cam_mem_aclk               ( cam_clk                   ),    // input wire cam_mem_aclk
    .cam_mem_aresetn            ( cam_sresetn               ),    // input wire cam_mem_aresetn
    .user_metadata_in           ( user_metadata_in_p4_map   ),    // input wire [18 : 0] user_metadata_in
    .user_metadata_in_valid     ( user_metadata_in_valid    ),    // input wire user_metadata_in_valid
    .user_metadata_out          ( user_metadata_out_p4_map  ),    // output wire [18 : 0] user_metadata_out
    .user_metadata_out_valid    ( user_metadata_out_valid   ),    // output wire user_metadata_out_valid - synchronus to s_axis_aclk
    .irq                        ( ram_ecc_event             ),    // output wire irq
    .s_axis_tdata               ( packet_data_in.tdata      ),    // input wire [63 : 0] s_axis_tdata
    .s_axis_tkeep               ( packet_data_in.tkeep      ),    // input wire [7 : 0] s_axis_tkeep
    .s_axis_tlast               ( packet_data_in.tlast      ),    // input wire s_axis_tlast
    .s_axis_tvalid              ( packet_data_in.tvalid     ),    // input wire s_axis_tvalid
    .s_axis_tready              ( packet_data_in.tready     ),    // output wire s_axis_tready
    .m_axis_tdata               ( packet_data_out.tdata     ),    // output wire [63 : 0] m_axis_tdata
    .m_axis_tkeep               ( packet_data_out.tkeep     ),    // output wire [7 : 0] m_axis_tkeep
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
