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

module p4_router_vnp4_wrapper #(
    parameter int USER_METADATA_WIDTH = 0
) (

    input var logic                             cam_clk,
    input var logic                             cam_sresetn,

    AXI4Lite_int.Slave                          control,

    AXIS_int.Slave                              data_in,
    input var logic [USER_METADATA_WIDTH-1:0]   user_metadata_in,
    input var logic                             user_metadata_in_valid,

    AXIS_int.Master                             data_out,
    output var logic [USER_METADATA_WIDTH-1:0]  user_metadata_out,
    output var logic                            user_metadata_out_valid,

    output var logic                            ram_ecc_event

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    enum {
        CPU_RTL_ING_ID,
        OISL0_RTL_ING_ID,
        OISL1_RTL_ING_ID,
        ECP0_RTL_ING_ID,
        ECP1_RTL_ING_ID,
        ECP1_RTL_ING_ID,
        ECP1_RTL_ING_ID,
        HDR0_RTL_ING_ID,
        HDR1_RTL_ING_ID,
        ECG0_RTL_ING_ID,
        ECG1_RTL_ING_ID,
        ECG2_RTL_ING_ID,
        ECG0_RTL_ING_ID
    } rtl_ing_ids;

    enum {
        CPU_RTL_EGR_ID,
        OISL0_RTL_EGR_ID,
        OISL1_RTL_EGR_ID,
        ECP0_RTL_EGR_ID,
        ECP1_RTL_EGR_ID,
        ECP1_RTL_EGR_ID,
        ECP1_RTL_EGR_ID,
        HDR0_RTL_EGR_ID,
        HDR1_RTL_EGR_ID,
        ECG0_RTL_EGR_ID,
        ECG1_RTL_EGR_ID,
        ECG2_RTL_EGR_ID,
        ECG0_RTL_EGR_ID
    } rtl_egr_ids;

    localparam int CPU_RTL_ING_ID   = ;
    localparam int OISL0_RTL_ING_ID = ;
    localparam int OISL1_RTL_ING_ID = ;
    localparam int ECP0_RTL_ING_ID  = ;
    localparam int ECP1_RTL_ING_ID  = ;
    localparam int ECP1_RTL_ING_ID  = ;
    localparam int ECP1_RTL_ING_ID  = ;
    localparam int HDR0_RTL_ING_ID  = ;
    localparam int HDR1_RTL_ING_ID  = ;
    localparam int ECG0_RTL_ING_ID  = ;
    localparam int ECG1_RTL_ING_ID  = ;
    localparam int ECG2_RTL_ING_ID  = ;
    localparam int ECG0_RTL_ING_ID  = ;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(USER_METADATA_WIDTH, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function logic [7:0] ingress_map(
        input logic [7:0] ing_id;
    );
        case (ing_id)
            :
            default:
        endcase
    endfunction

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Map RTL ingress port id to p4 ingress port id

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Map p4 egress port id to RTL egress port id

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4

    vitis_net_p4_0 vnp4 (
    .s_axis_aclk                ( data_in.clk               ),    // input wire s_axis_aclk
    .s_axis_aresetn             ( data_in.sresetn           ),    // input wire s_axis_aresetn
    .s_axi_aclk                 ( control.clk               ),    // input wire s_axi_aclk
    .s_axi_aresetn              ( control.sresetn           ),    // input wire s_axi_aresetn
    .cam_mem_aclk               ( cam_clk                   ),    // input wire cam_mem_aclk
    .cam_mem_aresetn            ( cam_sresetn               ),    // input wire cam_mem_aresetn
    .user_metadata_in           ( user_metadata_in          ),    // input wire [18 : 0] user_metadata_in
    .user_metadata_in_valid     ( user_metadata_in_valid    ),    // input wire user_metadata_in_valid
    .user_metadata_out          ( user_metadata_out         ),    // output wire [18 : 0] user_metadata_out
    .user_metadata_out_valid    ( user_metadata_out_valid   ),    // output wire user_metadata_out_valid - synchronus to s_axis_aclk
    .irq                        ( ram_ecc_event             ),    // output wire irq
    .s_axis_tdata               ( data_in.tdata             ),    // input wire [63 : 0] s_axis_tdata
    .s_axis_tkeep               ( data_in.tkeep             ),    // input wire [7 : 0] s_axis_tkeep
    .s_axis_tlast               ( data_in.tlast             ),    // input wire s_axis_tlast
    .s_axis_tvalid              ( data_in.tvalid            ),    // input wire s_axis_tvalid
    .s_axis_tready              ( data_in.tready            ),    // output wire s_axis_tready
    .m_axis_tdata               ( data_out.tdata            ),    // output wire [63 : 0] m_axis_tdata
    .m_axis_tkeep               ( data_out.tkeep            ),    // output wire [7 : 0] m_axis_tkeep
    .m_axis_tlast               ( data_out.tlast            ),    // output wire m_axis_tlast
    .m_axis_tvalid              ( data_out.tvalid           ),    // output wire m_axis_tvalid
    .m_axis_tready              ( data_out.tready           ),    // input wire m_axis_tready
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