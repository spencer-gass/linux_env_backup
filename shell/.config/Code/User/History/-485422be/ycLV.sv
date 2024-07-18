// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Egress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Encapsulates axis_async_fifo for CDC and buffering and
 *  axis_adapter_wrapper for data width conversion.
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none


module p4_router_egress_port_array_adapt #(
    parameter int NUM_EGR_PHYS_PORTS = 0,
    parameter int EGR_BUS_DATA_BYTES = 0,
    parameter int MTU_BYTES          = 1500,
    parameter int EGR_COUNTERS_WIDTH = 32
) (
    AXIS_int.Master     egr_phys_ports_demuxed  [NUM_EGR_PHYS_PORTS-1:0],
    AXIS_int.Slave      egr_phys_ports          [NUM_EGR_PHYS_PORTS-1:0],

    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_phys_ports_enable,
    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_clear,
    output var logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_ports_connected,
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_overflow

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_EGR_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(EGR_BUS_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port_index=0; port_index<NUM_EGR_PHYS_PORTS; port_index++) begin : phys_ports_g

        // Declare AXIS interfaces
        AXIS_int #(
            .DATA_BYTES ( EGR_BUS_DATA_BYTES  )
        ) egr_phys_port_buf_out (
            .clk     (egr_phys_ports[port_index].clk    ),
            .sresetn (egr_phys_ports[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( EGR_BUS_DATA_BYTES  )
        ) egr_phys_port_width_conv (
            .clk     (egr_phys_ports[port_index].clk    ),
            .sresetn (egr_phys_ports[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( EGR_BUS_DATA_BYTES  )
        ) egr_phys_port_demuxed_i (
            .clk     (egr_phys_ports[port_index].clk    ),
            .sresetn (egr_phys_ports[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( egr_phys_ports[port_index].DATA_BYTES  )
        ) egr_phys_port_adapted (
            .clk     (egr_phys_ports[port_index].clk    ),
            .sresetn (egr_phys_ports[port_index].sresetn)
        );

        // connect AXIS array element to a local AXIS interface here rather than connecting an array elemet to the fifo to avoid Modelsim bug
        always_comb begin
            egr_phys_port_demuxed_i.tvalid             = egr_phys_ports_demuxed[port_index].tvalid;
            egr_phys_ports_demuxed[port_index].tready  = egr_phys_port_demuxed_i.tready;
            egr_phys_port_demuxed_i.tdata              = egr_phys_ports_demuxed[port_index].tdata;
            egr_phys_port_demuxed_i.tstrb              = egr_phys_ports_demuxed[port_index].tstrb;
            egr_phys_port_demuxed_i.tkeep              = egr_phys_ports_demuxed[port_index].tkeep;
            egr_phys_port_demuxed_i.tlast              = egr_phys_ports_demuxed[port_index].tlast;
            egr_phys_port_demuxed_i.tid                = egr_phys_ports_demuxed[port_index].tid;
            egr_phys_port_demuxed_i.tdest              = egr_phys_ports_demuxed[port_index].tdest;
            egr_phys_port_demuxed_i.tuser              = egr_phys_ports_demuxed[port_index].tuser;
        end

        // Buffer and CDC
        axis_async_fifo_wrapper #(
            .DEPTH                ( MTU_BYTES * 2 / EGR_BUS_DATA_BYTES ),   // room for 2 MTUs
            .KEEP_ENABLE          ( 1'b1 ),
            .LAST_ENABLE          ( 1'b1 ),
            .ID_ENABLE            ( 1'b0 ),
            .DEST_ENABLE          ( 1'b0 ),
            .USER_ENABLE          ( 1'b0 ),
            .FRAME_FIFO           ( 1'b1 ),
            .USER_BAD_FRAME_VALUE ( 1'b0 ),
            .USER_BAD_FRAME_MASK  ( 1'b0 ),
            .DROP_BAD_FRAME       ( 1'b0 ),
            .DROP_WHEN_FULL       ( 1'b1 ),
            .PIPELINE_OUTPUT      ( 2    )

        ) egress_buffer (
            .axis_in             ( egr_phys_port_demuxed_i   ),
            .axis_out            ( egr_phys_port_buf_out     ),
            .axis_in_overflow    (),
            .axis_in_bad_frame   (),
            .axis_in_good_frame  (),
            .axis_out_overflow   ( egr_buf_overflow[port_index] ),
            .axis_out_bad_frame  (),
            .axis_out_good_frame ()
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(egr_phys_port_buf_out),
            .axis_out(egr_phys_port_adapted)
        );

        // Packet Byte and Error Counts
        `MAKE_AXIS_MONITOR(egr_monitor, egr_phys_port_adapted);

        axis_profile  #(
            .COUNT_WIDTH         ( EGR_COUNTERS_WIDTH ),
            .BYTECOUNT_DIVISOR   ( 1                 ),
            .FRAME_COUNT_DIVISOR ( 1                 ),
            .ERROR_COUNT_DIVISOR ( 1                 )
        ) egrress_counters (
            .axis                ( egr_monitor                       ),
            .enable              ( egr_phys_ports_enable[port_index] ),
            .clear_stb           ( egr_cnts_clear[port_index]        ),
            .error_count         (                                   ),
            .frame_count         (                                   ),
            .backpressure_time   (                                   ),
            .stall_time          (                                   ),
            .active_time         (                                   ),
            .idle_time           (                                   ),
            .data_count          (                                   ),
            .counts              ( egr_cnts[port_index]              )
        );

        // Enable/disable egress port
        axis_mute #(
            .ALLOW_LAST_WORD   ( 1 ),
            .DROP_WHEN_MUTED   ( 1 ),
            .FRAMED            ( 1 ),
            .ALLOW_LAST_FRAME  ( 1 ),
            .TAG_BAD_FRAME     ( 0 )
        ) egr_port_gate (
            .axis_in    ( egr_phys_port_adapted             ),
            .axis_out   ( egr_phys_ports[port_index]        ),
            .enable     ( egr_phys_ports_enable[port_index] ),
            .connected  ( egr_ports_connected[port_index]   )
        );
    end


endmodule

`default_nettype wire
