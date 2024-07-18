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
    parameter int VNP4_DATA_BYTES = 0
) (

    Clock_int.Output    clk_ifc,
    Reset_int.ResetOut  sreset_ifc,

    AXI4Lite_int.Slave  control

    AXIS_int.Slave      data_in,
    AXIS_int.Master     data_out,

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(VNP4_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    vitis_net_p4_frr_0 vnp4 (
    .s_axis_aclk                ( clk_ifc.clk                                   ),    // input wire s_axis_aclk
    .s_axis_aresetn             ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH    ),    // input wire s_axis_aresetn
    .s_axi_aclk                 ( clk_ifc.clk                                   ),    // input wire s_axi_aclk
    .s_axi_aresetn              ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH    ),    // input wire s_axi_aresetn
    .cam_mem_aclk               ( clk_ifc.clk                                   ),    // input wire cam_mem_aclk
    .cam_mem_aresetn            ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH    ),    // input wire cam_mem_aresetn
    .user_metadata_in           ( user_metadata_in                              ),    // input wire [18 : 0] user_metadata_in
    .user_metadata_in_valid     ( user_metadata_in_valid                        ),    // input wire user_metadata_in_valid
    .user_metadata_out          ( user_metadata_out                             ),    // output wire [18 : 0] user_metadata_out
    .user_metadata_out_valid    ( user_metadata_out_valid                       ),    // output wire user_metadata_out_valid
    .irq                        ( irq                                           ),    // output wire irq
    .s_axis_tdata               ( data_in.s_axis_tdata                          ),    // input wire [63 : 0] s_axis_tdata
    .s_axis_tkeep               ( data_in.s_axis_tkeep                          ),    // input wire [7 : 0] s_axis_tkeep
    .s_axis_tlast               ( data_in.s_axis_tlast                          ),    // input wire s_axis_tlast
    .s_axis_tvalid              ( data_in.s_axis_tvalid                         ),    // input wire s_axis_tvalid
    .s_axis_tready              ( data_in.s_axis_tready                         ),    // output wire s_axis_tready
    .m_axis_tdata               ( data_out.m_axis_tdata                         ),    // output wire [63 : 0] m_axis_tdata
    .m_axis_tkeep               ( data_out.m_axis_tkeep                         ),    // output wire [7 : 0] m_axis_tkeep
    .m_axis_tlast               ( data_out.m_axis_tlast                         ),    // output wire m_axis_tlast
    .m_axis_tvalid              ( data_out.m_axis_tvalid                        ),    // output wire m_axis_tvalid
    .m_axis_tready              ( data_out.m_axis_tready                        ),    // input wire m_axis_tready
    .s_axi_araddr               ( s_axi_araddr              ),    // input wire [14 : 0] s_axi_araddr
    .s_axi_arready              ( s_axi_arready             ),  // output wire s_axi_arready
    .s_axi_arvalid              ( s_axi_arvalid             ),  // input wire s_axi_arvalid
    .s_axi_awaddr               ( s_axi_awaddr              ),    // input wire [14 : 0] s_axi_awaddr
    .s_axi_awready              ( s_axi_awready             ),  // output wire s_axi_awready
    .s_axi_awvalid              ( s_axi_awvalid             ),  // input wire s_axi_awvalid
    .s_axi_bready               ( s_axi_bready              ),    // input wire s_axi_bready
    .s_axi_bresp                ( s_axi_bresp               ),      // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid               ( s_axi_bvalid              ),    // output wire s_axi_bvalid
    .s_axi_rdata                ( s_axi_rdata               ),      // output wire [31 : 0] s_axi_rdata
    .s_axi_rready               ( s_axi_rready              ),    // input wire s_axi_rready
    .s_axi_rresp                ( s_axi_rresp               ),      // output wire [1 : 0] s_axi_rresp
    .s_axi_rvalid               ( s_axi_rvalid              ),    // output wire s_axi_rvalid
    .s_axi_wdata                ( s_axi_wdata               ),      // input wire [31 : 0] s_axi_wdata
    .s_axi_wready               ( s_axi_wready              ),    // output wire s_axi_wready
    .s_axi_wstrb                ( s_axi_wstrb               ),      // input wire [3 : 0] s_axi_wstrb
    .s_axi_wvalid               ( s_axi_wvalid              )    // input wire s_axi_wvalid
    );

endmodule

`default_nettype wire
