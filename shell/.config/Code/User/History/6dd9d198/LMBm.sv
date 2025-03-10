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

    enum {
        CPU_RTL_ID,
        OISL0_RTL_ID,
        OISL1_RTL_ID,
        ECP0_RTL_ID,
        ECP1_RTL_ID,
        HDR0_RTL_ID,
        HDR1_RTL_ID,
        ECG0_RTL_ID,
        ECG1_RTL_ID,
        ECG2_RTL_ID,
        ECG3_RTL_ID
    } rtl_ids;

    localparam int CPU_P4_ID   = 0;
    localparam int HDR0_P4_ID  = 1;
    localparam int HDR1_P4_ID  = 2;
    localparam int OISL0_P4_ID = 10;
    localparam int OISL1_P4_ID = 11;
    localparam int ECP0_P4_ID  = 20;
    localparam int ECP1_P4_ID  = 21;
    localparam int ECG0_P4_ID  = 30;
    localparam int ECG1_P4_ID  = 31;
    localparam int ECG2_P4_ID  = 32;
    localparam int ECG3_P4_ID  = 33;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    function automatic logic [7:0] port_map(
        input logic [7:0] port_id
    ); begin
        case (port_id)
            CPU_RTL_ID   : return CPU_P4_ID;
            OISL0_RTL_ID : return OISL0_P4_ID;
            OISL1_RTL_ID : return OISL1_P4_ID;
            ECP0_RTL_ID  : return ECP0_P4_ID;
            ECP1_RTL_ID  : return ECP1_P4_ID;
            HDR0_RTL_ID  : return HDR0_P4_ID;
            HDR1_RTL_ID  : return HDR1_P4_ID;
            ECG0_RTL_ID  : return ECG0_P4_ID;
            ECG1_RTL_ID  : return ECG1_P4_ID;
            ECG2_RTL_ID  : return ECG2_P4_ID;
            ECG3_RTL_ID  : return ECG3_P4_ID;
            default: return 8'hFF;
        endcase
    end
    endfunction

    function automatic logic [7:0] port_demap(
        input logic [7:0] port_id
    ); begin
        case (port_id)
            CPU_P4_ID   : return  CPU_RTL_ID;
            OISL0_P4_ID : return  OISL0_RTL_ID;
            OISL1_P4_ID : return  OISL1_RTL_ID;
            ECP0_P4_ID  : return  ECP0_RTL_ID;
            ECP1_P4_ID  : return  ECP1_RTL_ID;
            HDR0_P4_ID  : return  HDR0_RTL_ID;
            HDR1_P4_ID  : return  HDR1_RTL_ID;
            ECG0_P4_ID  : return  ECG0_RTL_ID;
            ECG1_P4_ID  : return  ECG1_RTL_ID;
            ECG2_P4_ID  : return  ECG2_RTL_ID;
            ECG3_P4_ID  : return  ECG3_RTL_ID;
            default: return 8'hFF;
        endcase
    end
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ingress_metadata_t      ingress_metadata;
    user_meta_data_t        user_metadata_in_p4_map;
    user_meta_data_t        user_metadata_out_p4_map;
    vnp4_wrapper_metadata_t vnp4_wrapper_metadata;

    user_extern_in_t    user_extern_in;
    user_extern_valid_t user_extern_in_valid;
    user_extern_out_t   user_extern_out;
    user_extern_valid_t user_extern_out_valid;

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
    // SUB-SECTION: Convert between RTL port indices and port ids defined in p4


    assign ingress_metadata = packet_data_in.tuser;

    // VNP4 Metadata Inputs
    assign user_metadata_in_p4_map.vlan_id     = '0;
    assign user_metadata_in_p4_map.vrf_id      = '0;
    assign user_metadata_in_p4_map.bos         = 1'b0;
    assign user_metadata_in_p4_map.byte_length = ingress_metadata.byte_length;

    // Map port indices to P4 port IDs
    assign user_metadata_in_p4_map.ingress_port = port_map(ingress_metadata.ingress_port);
    assign user_metadata_in_p4_map.egress_port  = '0;
    assign vnp4_wrapper_metadata.ingress_port   = port_demap(user_metadata_out_p4_map.ingress_port);
    assign vnp4_wrapper_metadata.egress_port    = port_demap(user_metadata_out_p4_map.egress_port);
    assign packet_data_out.tuser                = vnp4_wrapper_metadata;

    `MAKE_AXIS_MONITOR(packet_data_in_monitor, packet_data_in);

    axis_sof ing_bus_sof_inst (
        .axis ( packet_data_in_monitor  ),
        .sof  ( user_metadata_in_valid  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4


    vitis_net_p4_frr_t1_ecp vnp4 (
        .s_axis_aclk                ( packet_data_in.clk        ),
        .s_axis_aresetn             ( packet_data_in.sresetn    ),
        .s_axi_aclk                 ( control.clk               ),
        .s_axi_aresetn              ( control.sresetn           ),
        .cam_mem_aclk               ( cam_clk                   ),
        .cam_mem_aresetn            ( cam_sresetn               ),
        .user_metadata_in           ( user_metadata_in_p4_map   ),
        .user_metadata_in_valid     ( user_metadata_in_valid    ),
        .user_metadata_out          ( user_metadata_out_p4_map  ),
        .user_metadata_out_valid    ( user_metadata_out_valid   ),
        .irq                        ( ram_ecc_event             ),
        .user_extern_in             ( user_extern_in            ),
        .user_extern_in_valid       ( user_extern_in_valid      ),
        .user_extern_out            ( user_extern_out           ),
        .user_extern_out_valid      ( user_extern_out_valid     ),
        .s_axis_tdata               ( packet_data_in.tdata      ),
        .s_axis_tkeep               ( packet_data_in.tkeep      ),
        .s_axis_tlast               ( packet_data_in.tlast      ),
        .s_axis_tvalid              ( packet_data_in.tvalid     ),
        .s_axis_tready              ( packet_data_in.tready     ),
        .m_axis_tdata               ( packet_data_out.tdata     ),
        .m_axis_tkeep               ( packet_data_out.tkeep     ),
        .m_axis_tlast               ( packet_data_out.tlast     ),
        .m_axis_tvalid              ( packet_data_out.tvalid    ),
        .m_axis_tready              ( packet_data_out.tready    ),
        .s_axi_araddr               ( control.araddr            ),
        .s_axi_arready              ( control.arready           ),
        .s_axi_arvalid              ( control.arvalid           ),
        .s_axi_awaddr               ( control.awaddr            ),
        .s_axi_awready              ( control.awready           ),
        .s_axi_awvalid              ( control.awvalid           ),
        .s_axi_bready               ( control.bready            ),
        .s_axi_bresp                ( control.bresp             ),
        .s_axi_bvalid               ( control.bvalid            ),
        .s_axi_rdata                ( control.rdata             ),
        .s_axi_rready               ( control.rready            ),
        .s_axi_rresp                ( control.rresp             ),
        .s_axi_rvalid               ( control.rvalid            ),
        .s_axi_wdata                ( control.wdata             ),
        .s_axi_wready               ( control.wready            ),
        .s_axi_wstrb                ( control.wstrb             ),
        .s_axi_wvalid               ( control.wvalid            )
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
