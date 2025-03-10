// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

/**
 * Wrapper for p4_router for pcuecp
 */
module board_pcuecp_p4_router_wrapper #(
    parameter bit [15:0]  MODULE_ID = 0,
    parameter int         MTU_BYTES = 2000
) (
    Clock_int.Input     core_clk_ifc,
    Reset_int.ResetIn   core_sreset_ifc,

    Clock_int.Input     cam_clk_ifc,
    Reset_int.ResetIn   cam_sreset_ifc,

    Clock_int.Input     avmm_clk_ifc,
    Reset_int.ResetIn   interconnect_sreset_ifc,
    Reset_int.ResetIn   peripheral_sreset_ifc,

    AvalonMM_int.Slave  vnp4_avmm,
    AvalonMM_int.Slave  p4_router_avmm,

    AXIS_int.Slave      pkt_gen_ingress [9:0],
    AXIS_int.Master     pkt_gen_egress  [9:0]
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam CDC_FIFO_DEPTH = 32;
    localparam NUM_INTERFACES = 4;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS interface arrays

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) unused_ing_8b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_ing_16b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_ing_32b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) ing_64b_phys_ports [9:0] (
        .clk     (core_clk_ifc.clk ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) unused_egr_8b_phys_ports [1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_egr_16b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_egr_32b_phys_ports [-1:0] (
        .clk     (1'b0 ),
        .sresetn (1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) egr_64b_phys_ports [9:0] (
        .clk     (core_clk_ifc.clk ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: CDC

    generate
        for (genvar  i=0; i<10; i++) begin
            axis_dist_ram_fifo #(
                .DEPTH         ( CDC_FIFO_DEPTH ),
                .ASYNC_CLOCKS  ( 1'b1           )
            ) ing_async_fifo_pkt_gen (
                .axis_in       ( pkt_gen_ingress[i]   ),
                .axis_out      ( ing_64b_phys_ports[i] )
            );

            axis_async_fifo_wrapper egr_async_fifo_pkt_gen (
                .axis_in       ( egr_64b_phys_ports[i] ),
                .axis_out      ( pkt_gen_egress[i]     )
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: P4 Router

    p4_router #(
        .MODULE_ID                  ( 0                                                     ),
        .NUM_64B_ING_PHYS_PORTS     ( 10                                                    ),
        .NUM_64B_EGR_PHYS_PORTS     ( 10                                                    ),
        .VNP4_IP_SEL                ( ECHO_PHYS_PORT                                        ),
        .VNP4_DATA_BYTES            ( p4_router_vnp4_echo_phys_port_pkg::TDATA_NUM_BYTES    ),
        .VNP4_AXI4LITE_DATALEN      ( p4_router_vnp4_echo_phys_port_pkg::S_AXI_DATA_WIDTH   ),
        .VNP4_AXI4LITE_ADDRLEN      ( p4_router_vnp4_echo_phys_port_pkg::S_AXI_ADDR_WIDTH   ),
        .QUEUE_MEM_URAM_DEPTH       ( 8                                                     ),
        .CLOCK_PERIOD_NS            ( 5.0                                                   ),
        .MTU_BYTES                  ( 2000                                                  ),
        .POLICER_DEBUG_ILA  (1'b1),
        .CONG_MAN_DEBUG_ILA  (1'b1),
        .QUEUE_STATES_DEBUG_ILA  (1'b1),
    ) p4_router_inst (
        .core_clk_ifc               ( core_clk_ifc              ),
        .core_sreset_ifc            ( core_sreset_ifc           ),
        .cam_clk_ifc                ( cam_clk_ifc               ),
        .cam_sreset_ifc             ( cam_sreset_ifc            ),
        .avmm_clk_ifc               ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .vnp4_avmm                  ( vnp4_avmm                 ),
        .p4_router_avmm             ( p4_router_avmm            ),
        .ing_8b_phys_ports          ( unused_ing_8b_phys_ports  ),
        .ing_16b_phys_ports         ( unused_ing_16b_phys_ports ),
        .ing_32b_phys_ports         ( unused_ing_32b_phys_ports ),
        .ing_64b_phys_ports         ( ing_64b_phys_ports        ),
        .egr_8b_phys_ports          ( unused_egr_8b_phys_ports  ),
        .egr_16b_phys_ports         ( unused_egr_16b_phys_ports ),
        .egr_32b_phys_ports         ( unused_egr_32b_phys_ports ),
        .egr_64b_phys_ports         ( egr_64b_phys_ports        )
    );


endmodule

`default_nettype wire
