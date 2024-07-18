// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Uses avmm_to_axi4lite module as an entry point for VNP4 table config controller.
 */
 s
module avmm_to_axi4lite
(
    Clock_int.Input         clk_ifc,
    Reset_int.ResetIn       interconnect_sreset_ifc,
    Reset_int.ResetIn       peripheral_sreset_ifc,

    AvalonMM_int.Slave      avmm,
    AXI4Lite_int.Master     axi4lite
);

    vnp4_control_sim table_config (
        // Clocks & Resets
        .axi_aclk(clk_ifc.clk),
        .axi_aresetn(interconnect_sreset_ifc.reset != interconnect_sreset_ifc.ACTIVE_HIGH),
        // AXI4-lite interface
        .m_axi_awaddr   ( axi4lite.awaddr   ),
        .m_axi_awvalid  ( axi4lite.awvalid  ),
        .m_axi_awready  ( axi4lite.awready  ),
        .m_axi_wdata    ( axi4lite.wdata    ),
        .m_axi_wstrb    ( axi4lite.wstrb    ),
        .m_axi_wvalid   ( axi4lite.wvalid   ),
        .m_axi_wready   ( axi4lite.wready   ),
        .m_axi_bresp    ( axi4lite.bresp    ),
        .m_axi_bvalid   ( axi4lite.bvalid   ),
        .m_axi_bready   ( axi4lite.bready   ),
        .m_axi_araddr   ( axi4lite.araddr   ),
        .m_axi_arvalid  ( axi4lite.arvalid  ),
        .m_axi_arready  ( axi4lite.arready  ),
        .m_axi_rdata    ( axi4lite.rdata    ),
        .m_axi_rvalid   ( axi4lite.rvalid   ),
        .m_axi_rready   ( axi4lite.rready   ),
        .m_axi_rresp    ( axi4lite.rresp    )
    );


endmodule

`default_nettype wire
