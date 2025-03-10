// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none

/**
 * P4 Router VNP4 wrapper - physical port echo
**/
module p4_router_vnp4_echo_phys_port_wrapper #(
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
    // SECTION: Import


    import P4_ROUTER_PKG::*;
    import P4_ROUTER_VNP4_ECHO_PHYS_PORT_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_in.DATA_BYTES);
    `ELAB_CHECK_EQUAL(TDATA_NUM_BYTES, packet_data_out.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    function automatic logic [USER_METADATA_T_ING_PORT_WIDTH-1:0] ingress_map(
        input logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0] ing_id
    );
        return ing_id;
    endfunction

    function automatic logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0] egress_map(
        input logic [USER_METADATA_T_EGR_SPEC_WIDTH-1:0] egr_id
    );
        return egr_id;
    endfunction

    function automatic logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0] ingress_demap(
        input logic [USER_METADATA_T_ING_PORT_WIDTH-1:0] ing_id
    );
        return ing_id;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ingress_metadata_t      ingress_metadata;
    user_meta_data_t        user_metadata_in_p4_map;
    user_meta_data_t        user_metadata_out_p4_map;
    vnp4_wrapper_metadata_t vnp4_wrapper_metadata;

    logic user_metadata_in_valid;
    logic user_metadata_out_valid;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Convert between RTL port indices and port ids defined in p4


    assign ingress_metadata = packet_data_in.tuser;

    assign user_metadata_in_p4_map.ing_port     = ingress_metadata.ingress_port;
    assign user_metadata_in_p4_map.egr_spec     = '0;
    assign user_metadata_in_p4_map.prio         = 0;
    assign user_metadata_in_p4_map.byte_length  = ingress_metadata.byte_length;

    assign vnp4_wrapper_metadata.ingress_port   = user_metadata_out_p4_map.ing_port;
    assign vnp4_wrapper_metadata.egress_port    = user_metadata_out_p4_map.egr_spec;
    assign vnp4_wrapper_metadata.prio           = user_metadata_out_p4_map.prio;
    assign vnp4_wrapper_metadata.byte_length    = user_metadata_out_p4_map.byte_length;
    assign packet_data_out.tuser                = vnp4_wrapper_metadata;

    `MAKE_AXIS_MONITOR(packet_data_in_monitor, packet_data_in);

    axis_sof ing_bus_sof_inst (
        .axis ( packet_data_in_monitor  ),
        .sof  ( user_metadata_in_valid  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: VNP4


    vitis_net_p4_echo_phys_port vnp4 (
        .s_axis_aclk                ( packet_data_in.clk        ),
        .s_axis_aresetn             ( packet_data_in.sresetn    ),
        .s_axi_aclk                 ( control.clk               ),
        .s_axi_aresetn              ( control.sresetn           ),
        .user_metadata_in           ( user_metadata_in_p4_map   ),
        .user_metadata_in_valid     ( user_metadata_in_valid    ),
        .user_metadata_out          ( user_metadata_out_p4_map  ),
        .user_metadata_out_valid    ( user_metadata_out_valid   ),
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
                    .probe11( '0                        ),
                    .probe12( '0                        ),
                    .probe13( '0                        ),
                    .probe14( '0                        ),
                    .probe15( '0                        )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
