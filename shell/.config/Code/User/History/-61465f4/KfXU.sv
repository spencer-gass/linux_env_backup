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
    parameter bit [15:0]  MODULE_ID          = 0,
    parameter int         NUM_PS_TO_PL_LINKS = 4,
    parameter int         MTU_BYTES          = 2000
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

    AXIS_int.Slave      ingress_from_ps  [NUM_PS_TO_PL_LINKS-1:0],
    AXIS_int.Master     egress_to_ps     [NUM_PS_TO_PL_LINKS-1:0],

    AXIS_int.Slave      ingress_pkt_gen [9:0],
    AXIS_int.Master     egress_64bit    [9:0]
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import P4_ROUTER_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants


    localparam CDC_FIFO_DEPTH = 32;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interface Arrays


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) unused_ing_8b_phys_ports [-1 :0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_ing_16b_phys_ports [-1:0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_ing_32b_phys_ports [-1:0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) unused_egr_8b_phys_ports [-1 :0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 2 )
    ) unused_egr_16b_phys_ports [-1:0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );

    AXIS_int #(
        .DATA_BYTES ( 4 )
    ) unused_egr_32b_phys_ports [-1:0] (
        .clk     ( 1'b0 ),
        .sresetn ( 1'b0 )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: CDC


    // generate
    //     for (genvar  i=0; i<NUM_PS_TO_PL_LINKS; i++) begin : cdc_fifos
    //         axis_dist_ram_fifo #(
    //             .DEPTH         ( CDC_FIFO_DEPTH ),
    //             .ASYNC_CLOCKS  ( 1'b1           )
    //         ) ing_async_fifo0 (
    //             .axis_in       ( ingress_from_ps[i]     ),
    //             .axis_out      ( ing_8b_phys_ports[i]   )
    //         );

    //         axis_async_fifo_wrapper egr_async_fifo (
    //             .axis_in       ( egr_8b_phys_ports[i] ),
    //             .axis_out      ( egress_to_ps[i]      )
    //         );
    //     end
    // endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: P4 Router


    p4_router #(
        .MODULE_ID                  ( 0                                                         ),
        .NUM_8B_ING_PHYS_PORTS      ( 0                                                         ),
        .NUM_8B_EGR_PHYS_PORTS      ( 0                                                         ),
        .NUM_64B_ING_PHYS_PORTS     ( 10                                                        ),
        .NUM_64B_EGR_PHYS_PORTS     ( 10                                                        ),
        .VNP4_IP_SEL                ( FRR_T1_ECP_TINY_BCAM                                      ),
        .VNP4_DATA_BYTES            ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::TDATA_NUM_BYTES  ),
        .VNP4_AXI4LITE_DATALEN      ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_DATA_WIDTH ),
        .VNP4_AXI4LITE_ADDRLEN      ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_ADDR_WIDTH ),
        .QUEUE_MEM_URAM_DEPTH       ( 8                                                         ),
        .CLOCK_PERIOD_NS            ( 5.0                                                       ),
        .MTU_BYTES                  ( 2000                                                      ),

        .ING_8B_PORT_DEBUG_ILA      ( '0                        ),
        .ING_16B_PORT_DEBUG_ILA     ( '0                        ),
        .ING_32B_PORT_DEBUG_ILA     ( '0                        ),
        .ING_64B_PORT_DEBUG_ILA     ( '{0: 1'b1, default: 1'b0} ),
        .ING_BUF_DEBUG_ILA          ( 1'b1                      ),
        .VNP4_DEBUG_ILA             ( 1'b1                      ),
        .CONG_MAN_DEBUG_ILA         ( 1'b1                      ),
        .QUEUE_STATES_DEBUG_ILA     ( 1'b1                      ),
        .SCHEDULER_DEBUG_ILA        ( 1'b1                      ),
        .EGR_BUS_DEBUG_ILA          ( 1'b0                      ),
        .EGR_8B_PORT_DEBUG_ILA      ( '0                        ),
        .EGR_16B_PORT_DEBUG_ILA     ( '0                        ),
        .EGR_32B_PORT_DEBUG_ILA     ( '0                        ),
        .EGR_64B_PORT_DEBUG_ILA     ( '0                        )
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
        .ing_64b_phys_ports         ( ingress_pkt_gen           ),
        .egr_8b_phys_ports          ( unused_egr_8b_phys_ports  ),
        .egr_16b_phys_ports         ( unused_egr_16b_phys_ports ),
        .egr_32b_phys_ports         ( unused_egr_32b_phys_ports ),
        .egr_64b_phys_ports         ( egress_64bit              )
    );

endmodule

`default_nettype wire
