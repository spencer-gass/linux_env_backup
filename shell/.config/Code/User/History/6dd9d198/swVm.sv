// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none

/**
 * Vitis net p4 IP wrapper for frr_dplane.p4 targeting
 * pcuecp for development purposes.
**/
module p4_router_vnp4_frr_t1_ecp_wrapper #(
    parameter bit DEBUG_ILA = 1'b0
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


    import P4_ROUTER_PKG::*;
    import P4_ROUTER_VNP4_FRR_T1_ECP_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants


    localparam IPV4_HEADER_BYTES = 20;
    localparam IPV4_HEADER_CHECKSUM_BYTES = 2;
    localparam IPV4_HEADER_BITS = 8*IPV4_HEADER_BYTES;
    localparam IPV4_HEADER_CHECKSUM_BITS = 8*IPV4_HEADER_CHECKSUM_BYTES;
    localparam IPV4_UPDATE_IN_DATA_BYTES = 6;

    //TODO(sgass): Determine interface indices and define a mapping from RTL ports to p4 application ports.
    // Something like this:
    // enum {
    //     CPU_RTL_ING_ID,
    //     OISL0_RTL_ING_ID,
    //     OISL1_RTL_ING_ID,
    //     ECP0_RTL_ING_ID,
    //     ECP1_RTL_ING_ID,
    //     HDR0_RTL_ING_ID,
    //     HDR1_RTL_ING_ID,
    //     ECG0_RTL_ING_ID,
    //     ECG1_RTL_ING_ID,
    //     ECG2_RTL_ING_ID,
    //     ECG3_RTL_ING_ID
    // } rtl_ing_ids;
    //
    // enum {
    //     CPU_RTL_EGR_ID,
    //     OISL0_RTL_EGR_ID,
    //     OISL1_RTL_EGR_ID,
    //     ECP0_RTL_EGR_ID,
    //     ECP1_RTL_EGR_ID,
    //     HDR0_RTL_EGR_ID,
    //     HDR1_RTL_EGR_ID,
    //     ECG0_RTL_EGR_ID,
    //     ECG1_RTL_EGR_ID,
    //     ECG2_RTL_EGR_ID,
    //     ECG3_RTL_EGR_ID
    // } rtl_egr_ids;
    //
    // localparam int CPU_P4_ID   = 0;
    // localparam int HDR0_P4_ID  = 60;
    // localparam int HDR1_P4_ID  = 61;
    // localparam int OISL0_P4_ID = 20;
    // localparam int OISL1_P4_ID = 21;
    // localparam int ECP0_P4_ID  = 40;
    // localparam int ECP1_P4_ID  = 41;
    // localparam int ECG0_P4_ID  = 80;
    // localparam int ECG1_P4_ID  = 81;
    // localparam int ECG2_P4_ID  = 82;
    // localparam int ECG3_P4_ID  = 83;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    //TODO(sgass): Continuation of the interface mapping example that needs to be completed.
    // function automatic logic [7:0] ingress_map(
    //     input logic [7:0] ing_id
    // ); begin
    //     case (ing_id)
    //         CPU_RTL_ING_ID   : return CPU_P4_ID;
    //         OISL0_RTL_ING_ID : return OISL0_P4_ID;
    //         OISL1_RTL_ING_ID : return OISL1_P4_ID;
    //         ECP0_RTL_ING_ID  : return ECP0_P4_ID;
    //         ECP1_RTL_ING_ID  : return ECP1_P4_ID;
    //         HDR0_RTL_ING_ID  : return HDR0_P4_ID;
    //         HDR1_RTL_ING_ID  : return HDR1_P4_ID;
    //         ECG0_RTL_ING_ID  : return ECG0_P4_ID;
    //         ECG1_RTL_ING_ID  : return ECG1_P4_ID;
    //         ECG2_RTL_ING_ID  : return ECG2_P4_ID;
    //         ECG3_RTL_ING_ID  : return ECG3_P4_ID;
    //         default: return 8'hFF;
    //     endcase
    // end
    // endfunction

    // function automatic logic [7:0] egress_map(
    //     input logic [7:0] egr_id
    // ); begin
    //     case (egr_id)
    //         CPU_P4_ID   : return CPU_RTL_EGR_ID;
    //         OISL0_P4_ID : return OISL0_RTL_EGR_ID;
    //         OISL1_P4_ID : return OISL1_RTL_EGR_ID;
    //         ECP0_P4_ID  : return ECP0_RTL_EGR_ID;
    //         ECP1_P4_ID  : return ECP1_RTL_EGR_ID;
    //         HDR0_P4_ID  : return HDR0_RTL_EGR_ID;
    //         HDR1_P4_ID  : return HDR1_RTL_EGR_ID;
    //         ECG0_P4_ID  : return ECG0_RTL_EGR_ID;
    //         ECG1_P4_ID  : return ECG1_RTL_EGR_ID;
    //         ECG2_P4_ID  : return ECG2_RTL_EGR_ID;
    //         ECG3_P4_ID  : return ECG3_RTL_EGR_ID;
    //         default: return 8'hFF;
    //     endcase
    // end
    // endfunction

    // function automatic logic [7:0] ingress_demap(
    //     input logic [7:0] ing_id
    // ); begin
    //     case (ing_id)
    //         CPU_P4_ID   : return  CPU_RTL_ING_ID;
    //         OISL0_P4_ID : return  OISL0_RTL_ING_ID;
    //         OISL1_P4_ID : return  OISL1_RTL_ING_ID;
    //         ECP0_P4_ID  : return  ECP0_RTL_ING_ID;
    //         ECP1_P4_ID  : return  ECP1_RTL_ING_ID;
    //         HDR0_P4_ID  : return  HDR0_RTL_ING_ID;
    //         HDR1_P4_ID  : return  HDR1_RTL_ING_ID;
    //         ECG0_P4_ID  : return  ECG0_RTL_ING_ID;
    //         ECG1_P4_ID  : return  ECG1_RTL_ING_ID;
    //         ECG2_P4_ID  : return  ECG2_RTL_ING_ID;
    //         ECG3_P4_ID  : return  ECG3_RTL_ING_ID;
    //         default: return 8'hFF;
    //     endcase
    // end
    // endfunction

    // Could adjust these to match linux eth numbering to make thinks easier for software
    function automatic logic [USER_METADATA_INGRESS_PORT_WIDTH-1:0] ingress_map(
        input logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0] ing_id
    );
        return ing_id;
    endfunction

    function automatic logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0] egress_map(
        input logic [USER_METADATA_EGRESS_PORT_WIDTH-1:0] egr_id
    );
        return egr_id;
    endfunction

    function automatic logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0] ingress_demap(
        input logic [USER_METADATA_INGRESS_PORT_WIDTH-1:0] ing_id
    );
        return ing_id;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ingress_metadata_t      ingress_metadata;
    USER_META_DATA_T        user_metadata_in_p4_map;
    USER_META_DATA_T        user_metadata_out_p4_map;
    vnp4_wrapper_metadata_t vnp4_wrapper_metadata;

    USER_EXTERN_IN_T    user_extern_in;
    USER_EXTERN_VALID_T user_extern_in_valid;
    USER_EXTERN_OUT_T   user_extern_out;
    USER_EXTERN_VALID_T user_extern_out_valid;

    logic [IPV4_UPDATE_IN_DATA_BYTES*8-1:0] user_ipv4_chk_update;
    logic user_metadata_in_valid;
    logic user_metadata_out_valid;

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_BYTES ),
        .ALLOW_BACKPRESSURE ( 0                 )
    ) ip_chksum_verif_req (
        .clk        ( packet_data_in.clk        ),
        .sresetn    ( packet_data_in.sresetn    )
    );

    AXIS_int #(
        .DATA_BYTES         ( 1 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) ip_chksum_verif_resp (
        .clk        ( packet_data_in.clk        ),
        .sresetn    ( packet_data_in.sresetn    )
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_UPDATE_IN_DATA_BYTES ),
        .ALLOW_BACKPRESSURE ( 0                         )
    ) ip_chksum_update_req (
        .clk        ( packet_data_in.clk     ),
        .sresetn    ( packet_data_in.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_CHECKSUM_BYTES ),
        .ALLOW_BACKPRESSURE ( 0                          )
    ) ip_chksum_update_resp (
        .clk        ( packet_data_in.clk     ),
        .sresetn    ( packet_data_in.sresetn )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Convert between RTL port indecies and port ids defined in p4


    assign ingress_metadata = packet_data_in.tuser;

    // VNP4 Metadata Inputs
    assign user_metadata_in_p4_map.vlan_id     = '0;
    assign user_metadata_in_p4_map.vrf_id      = '0;
    assign user_metadata_in_p4_map.bos         = 1'b0;
    assign user_metadata_in_p4_map.byte_length = ingress_metadata.byte_length;

    // Map port indecies to P4 port IDs
    assign user_metadata_in_p4_map.ingress_port = ingress_map(ingress_metadata.ingress_port);
    assign user_metadata_in_p4_map.egress_port  = '0;
    assign vnp4_wrapper_metadata.ingress_port   = ingress_demap(user_metadata_out_p4_map.ingress_port);
    assign vnp4_wrapper_metadata.egress_port    = egress_map(user_metadata_out_p4_map.egress_port);
    assign packet_data_out.tuser                = vnp4_wrapper_metadata;

    `MAKE_AXIS_MONITOR(packet_data_in_monitor, packet_data_in);

    axis_sof ing_bus_sof_inst (
        .axis ( packet_data_in_monitor  ),
        .sof  ( user_metadata_in_valid  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4


    vitis_net_p4_frr_t1_ecp vnp4 (
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
    .user_extern_in             ( user_extern_in            ),    // input wire [16 : 0] user_extern_in
    .user_extern_in_valid       ( user_extern_in_valid      ),    // input wire [1 : 0] user_extern_in_valid
    .user_extern_out            ( user_extern_out           ),    // output wire [191 : 0] user_extern_out
    .user_extern_out_valid      ( user_extern_out_valid     ),    // output wire [1 : 0] user_extern_out_valid
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

    assign user_ipv4_chk_update[47:32] = user_extern_out.UserIPv4ChkUpdate.hdr_chk;
    assign user_ipv4_chk_update[31:16] = {8'b00, user_extern_out.UserIPv4ChkUpdate.old_ttl};
    assign user_ipv4_chk_update[15:0 ] = {8'b00, user_extern_out.UserIPv4ChkUpdate.new_ttl};

    axis_to_user_extern #(
        .UE_IN_DATA_BITS  ( IPV4_UPDATE_IN_DATA_BYTES*8 ),
        .UE_OUT_DATA_BITS ( IPV4_HEADER_CHECKSUM_BITS   )
    ) ipv4_checksum_gen_req_converter (
        .user_extern_data_in        ( user_ipv4_chk_update                    ),
        .user_extern_valid_in       ( user_extern_out_valid.UserIPv4ChkUpdate ),
        .user_extern_data_out       ( user_extern_in.UserIPv4ChkUpdate        ),
        .user_extern_valid_out      ( user_extern_in_valid.UserIPv4ChkUpdate  ),
        .axis_out                   ( ip_chksum_update_req                    ),
        .axis_in                    ( ip_chksum_update_resp                   )
    );

    ipv4_checksum_update ipv4_checksum_updater (
        .update_req     ( ip_chksum_update_req     ),
        .new_checksum   ( ip_chksum_update_resp    )
    );

    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                logic [31:0] dbg_cntr;
                always_ff @(posedge packet_data_in.clk) begin
                    if (!packet_data_in.sresetn) begin
                        dbg_cntr <= '0;
                    end else begin
                        dbg_cntr <= dbg_cntr + 1'b1;
                    end
                end

                ila_debug ila (
                    .clk    ( packet_data_in.clk        ),
                    .probe0 ( packet_data_in.sresetn    ),
                    .probe1 ( packet_data_in.tready     ),
                    .probe2 ( packet_data_in.tvalid     ),
                    .probe3 ( packet_data_in.tkeep      ),
                    .probe4 ( packet_data_in.tlast      ),
                    .probe5 ( packet_data_in.tuser      ),
                    .probe6 ( packet_data_out.tready    ),
                    .probe7 ( packet_data_out.tvalid    ),
                    .probe8 ( packet_data_out.tkeep     ),
                    .probe9 ( packet_data_out.tlast     ),
                    .probe10( packet_data_out.tuser     ),
                    .probe11( user_extern_in_valid      ),
                    .probe12( user_extern_out_valid     ),
                    .probe13( '0                        ),
                    .probe14( '0                        ),
                    .probe15( '0                        )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
