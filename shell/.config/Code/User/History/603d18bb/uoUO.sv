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
    import UTIL_INTS::U_INT_CEIL_DIV;
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
        .axi_aresetn(interconnect_sreset_ifc.reset != inter),
        // AXI4-lite interface
        output logic [S_AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
        output logic                          m_axi_awvalid,
        input  logic                          m_axi_awready,
        output logic [S_AXI_DATA_WIDTH-1:0]   m_axi_wdata,
        output logic [S_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
        output logic                          m_axi_wvalid,
        input  logic                          m_axi_wready,
        input  logic [1:0]                    m_axi_bresp,
        input  logic                          m_axi_bvalid,
        output logic                          m_axi_bready,
        output logic [S_AXI_ADDR_WIDTH-1:0]   m_axi_araddr,
        output logic                          m_axi_arvalid,
        input  logic                          m_axi_arready,
        input  logic [S_AXI_DATA_WIDTH-1:0]   m_axi_rdata,
        input  logic                          m_axi_rvalid,
        output logic                          m_axi_rready,
        input  logic [1:0]                    m_axi_rresp
    );


endmodule

`default_nettype wire
