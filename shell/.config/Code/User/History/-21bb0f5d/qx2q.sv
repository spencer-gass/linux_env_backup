// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Egress subsystem for P4 router
 *  Input wide AXIS bus from VNP4
 *  axis_demux_wrapper to split out to egress port buffers
 *  axis_async_fifo to buffer and CDC
 *  output to physical ports
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none


module p4_router_egress #(
    parameter int NUM_8B_EGR_PHYS_PORTS  = 0,
    parameter int NUM_16B_EGR_PHYS_PORTS = 0,
    parameter int NUM_32B_EGR_PHYS_PORTS = 0,
    parameter int NUM_64B_EGR_PHYS_PORTS = 0,
    parameter int MTU_BYTES = 9600
)(
    Clock_int.Output    clk_ifc,
    Reset_int.ResetOut  sreset_ifc,

    AXIS_int.Slave      egr_bus,

    AXIS_int.Master     egr_8b_phys_ports  [NUM_8B_EGR_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Master     egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0],


    output var logic [NUM_8B_EGR_PHYS_PORTS-1:0]  egr_8b_buf_overflow,  // overflow = congestion drop since there isn't a queue system yet
    output var logic [NUM_16B_EGR_PHYS_PORTS-1:0] egr_16b_buf_overflow,
    output var logic [NUM_32B_EGR_PHYS_PORTS-1:0] egr_32b_buf_overflow,
    output var logic [NUM_64B_EGR_PHYS_PORTS-1:0] egr_64b_buf_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_params_pkg::*;
    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GE(egr_bus.DATA_BYTES, 8) // wide output bus needs to be at least as wide as the widest input bus
    `ELAB_CHECK_GT(NUM_EGR_PHYS_PORTS, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  )
    ) egr_phys_ports_demuxed [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk                                ),
        .sresetn ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  ),
        .USER_WIDTH ( NUM_EGR_PHYS_PORTS_LOG        )
    ) egr_phys_ports_tuser_index_insert [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk                                ),
        .sresetn ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  )
    ) egr_bus_tuser_stripped (
        .clk     ( clk_ifc.clk                                ),
        .sresetn ( sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] egr_port_sel;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Egress Demux

    always_comb begin : strip_tuser
        egr_bus_tuser_stripped.tvalid   = egr_bus.tvalid;
        egr_bus.tready                  = egr_bus_tuser_stripped.tready;
        egr_bus_tuser_stripped.tdata    = egr_bus.tdata;
        egr_bus_tuser_stripped.tstrb    = egr_bus.tstrb;
        egr_bus_tuser_stripped.tkeep    = egr_bus.tkeep;
        egr_bus_tuser_stripped.tlast    = egr_bus.tlast;
        egr_bus_tuser_stripped.tid      = egr_bus.tid;
        egr_bus_tuser_stripped.tdest    = egr_bus.tdest;
        egr_bus_tuser_stripped.tuser    = 1'b0;
        egr_port_sel                    = egr_bus.tuser;
    end

    axis_demux_wrapper #(
        .N (NUM_EGR_PHYS_PORTS)
    ) egress_demux (
        .axis_in    ( egr_bus_tuser_stripped    ),
        .axis_out   ( egr_phys_ports_demuxed    ),
        .enable     ( 1'b1                      ),
        .drop       ( 1'b0                      ),
        .select     ( egr_port_sel              )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Per-Physical-Port Logic

    // For each egress physical port, cdc to physical interface clocks through a async FIFOs and convert data bus width to physical port width
    generate
        if (NUM_8B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_8B_EGR_PHYS_PORTS ),
                .EGR_BUS_DATA_BYTES      ( egr_bus.DATA_BYTES    ),
                .MTU_BYTES                  ( MTU_BYTES             )
            ) egress_port_array_adapt_8b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_8B_START+:NUM_8B_EGR_PHYS_PORTS] ),
                .egr_phys_ports             ( egr_8b_phys_ports ),
                .egr_buf_overflow           ( egr_8b_buf_overflow )
            );
        end else begin
            assign egr_8b_buf_overflow = 1'b0;
        end

        if (NUM_16B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES      ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 )
            ) egress_port_array_adapt_16b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_16B_START+:NUM_16B_EGR_PHYS_PORTS] ),
                .egr_phys_ports             ( egr_16b_phys_ports ),
                .egr_buf_overflow           ( egr_16b_buf_overflow )
            );
        end else begin
            assign egr_16b_buf_overflow = 1'b0;
        end

        if (NUM_32B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES      ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 )
            ) egress_port_array_adapt_32b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_32B_START+:NUM_32B_EGR_PHYS_PORTS] ),
                .egr_phys_ports             ( egr_32b_phys_ports ),
                .egr_buf_overflow           ( egr_32b_buf_overflow )
            );
        end else begin
            assign egr_32b_buf_overflow = 1'b0;
        end

        if (NUM_64B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES      ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 )
            ) egress_port_array_adapt_64b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_64B_START+:NUM_64B_EGR_PHYS_PORTS] ),
                .egr_phys_ports             ( egr_64b_phys_ports ),
                .egr_buf_overflow           ( egr_64b_buf_overflow )
            );
        end else begin
            assign egr_64b_buf_overflow = 1'b0;
        end
    endgenerate


endmodule

`default_nettype wire