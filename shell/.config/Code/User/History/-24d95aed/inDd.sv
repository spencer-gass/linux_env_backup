// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router Top Level Module
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "vitis_net_p4_0_pkg.sv"
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

    localparam IPV4_HEADER_BYTES = 20;
    localparam IPV4_HEADER_CHECKSUM_BYTES = 2;
    localparam IPV4_HEADER_BITS = 8*IPV4_HEADER_BYTES;
    localparam IPV4_HEADER_CHECKSUM_BITS = 8*IPV4_HEADER_CHECKSUM_BYTES;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(USER_METADATA_WIDTH, 0);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    USER_EXTERN_IN_T    user_extern_in;
    USER_EXTERN_VALID_T user_extern_in_valid;
    USER_EXTERN_OUT_T   user_extern_out;
    USER_EXTERN_VALID_T user_extern_out_valid;

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_verif_req (
        .clk        (data_in.clk),
        .sresetn    (data_in.cam_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( 1 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) ip_chksum_verif_resp (
        .clk        (data_in.clk),
        .sresetn    (data_in.cam_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_gen_req (
        .clk        (data_in.clk),
        .sresetn    (data_in.cam_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_CHECKSUM_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_gen_resp (
        .clk        (data_in.clk),
        .sresetn    (data_in.cam_sresetn)
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

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
    .user_extern_in             ( user_extern_in            ),    // input wire [16 : 0] user_extern_in
    .user_extern_in_valid       ( user_extern_in_valid      ),    // input wire [1 : 0] user_extern_in_valid
    .user_extern_out            ( user_extern_out           ),    // output wire [191 : 0] user_extern_out
    .user_extern_out_valid      ( user_extern_out_valid     ),    // output wire [1 : 0] user_extern_out_valid
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

    axis_to_user_extern #(
        .UE_IN_DATA_BITS  ( IPV4_HEADER_BITS ),
        .UE_OUT_DATA_BITS ( 1   )
    ) ipv4_checksum_verfiy_req_converter (
        .user_extern_data_in        ( user_extern_out.UserIPv4ChkVerify       ),
        .user_extern_valid_in       ( user_extern_out_valid.UserIPv4ChkVerify ),
        .user_extern_data_out       ( user_extern_in.UserIPv4ChkVerify        ),
        .user_extern_valid_out      ( user_extern_in_valid.UserIPv4ChkVerify  ),
        .axis_out                   ( ip_chksum_verif_req                     ),
        .axis_in                    ( ip_chksum_verif_resp                    )
    );

    ipv4_checksum_verify ipv4_checksum_verfier (
        .ipv4_header            ( ip_chksum_verif_req   ),
        .ipv4_checksum_valid    ( ip_chksum_verif_resp  )
    );

    axis_to_user_extern #(
        .UE_IN_DATA_BITS  ( IPV4_HEADER_BITS            ),
        .UE_OUT_DATA_BITS ( IPV4_HEADER_CHECKSUM_BITS   )
    ) ipv4_checksum_gen_req_converter (
        .user_extern_data_in        ( user_extern_out.UserIPv4ChkUpdate       ),
        .user_extern_valid_in       ( user_extern_out_valid.UserIPv4ChkUpdate ),
        .user_extern_data_out       ( user_extern_in.UserIPv4ChkUpdate        ),
        .user_extern_valid_out      ( user_extern_in_valid.UserIPv4ChkUpdate  ),
        .axis_out                   ( ip_chksum_gen_req                       ),
        .axis_in                    ( ip_chksum_gen_resp                      )
    );

    ipv4_checksum_verify ipv4_checksum_verfier (
        .ipv4_header            ( ip_chksum_gen_req     ),
        .ipv4_checksum_valid    ( ip_chksum_gen_resp    )
    );

endmodule

`default_nettype wire
