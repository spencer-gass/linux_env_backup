// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Egress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Encapsulates
 *   axis_adapter_wrapper
 *   axis_mute
 *   axis_profile
 *   axis_async_fifo
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none


module p4_router_egress_port_array_adapt #(
    parameter int NUM_EGR_PHYS_PORTS    = 0,
    parameter int EGR_BUS_DATA_BYTES    = 0,
    parameter int PHYS_PORT_DATA_BYTES  = 0,
    parameter int MTU_BYTES             = 1500,
    parameter int EGR_COUNTERS_WIDTH    = 32
) (
    AXIS_int.Slave   egr_phys_ports_demuxed  [NUM_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master  egr_phys_ports          [NUM_EGR_PHYS_PORTS-1:0],

    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_phys_ports_enable,
    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_clear,
    output var logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_ports_connected,
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_EGR_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(EGR_BUS_DATA_BYTES, 0);
    `ELAB_CHECK_GT(PHYS_PORT_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port=0; port<NUM_EGR_PHYS_PORTS; port++) begin : phys_ports_g

        // Declare AXIS interfaces
        AXIS_int #(
            .DATA_BYTES ( EGR_BUS_DATA_BYTES  )
        ) egr_phys_port_demuxed_i (
            .clk     (egr_phys_ports_demuxed[port].clk    ),
            .sresetn (egr_phys_ports_demuxed[port].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( EGR_BUS_DATA_BYTES  )
        ) egr_phys_port_gated (
            .clk     (egr_phys_ports_demuxed[port].clk    ),
            .sresetn (egr_phys_ports_demuxed[port].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( PHYS_PORT_DATA_BYTES  )
        ) egr_phys_port_adapted (
            .clk     (egr_phys_ports_demuxed[port].clk    ),
            .sresetn (egr_phys_ports_demuxed[port].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( PHYS_PORT_DATA_BYTES  )
        ) egr_phys_port_buf_out (
            .clk     (egr_phys_ports[port].clk    ),
            .sresetn (egr_phys_ports[port].sresetn)
        );

        // connect AXIS array element to a local AXIS interface here rather than connecting an array element to a module to avoid Modelsim bug
        always_comb begin
            egr_phys_port_demuxed_i.tvalid       = egr_phys_ports_demuxed[port].tvalid;
            egr_phys_ports_demuxed[port].tready  = egr_phys_port_demuxed_i.tready;
            egr_phys_port_demuxed_i.tdata        = egr_phys_ports_demuxed[port].tdata;
            egr_phys_port_demuxed_i.tstrb        = egr_phys_ports_demuxed[port].tstrb;
            egr_phys_port_demuxed_i.tkeep        = egr_phys_ports_demuxed[port].tkeep;
            egr_phys_port_demuxed_i.tlast        = egr_phys_ports_demuxed[port].tlast;
            egr_phys_port_demuxed_i.tid          = egr_phys_ports_demuxed[port].tid;
            egr_phys_port_demuxed_i.tdest        = egr_phys_ports_demuxed[port].tdest;
            egr_phys_port_demuxed_i.tuser        = egr_phys_ports_demuxed[port].tuser;
        end

        // Enable/disable egress port
        axis_mute #(
            .ALLOW_LAST_WORD   ( 1 ),
            .DROP_WHEN_MUTED   ( 1 ),
            .FRAMED            ( 1 ),
            .ALLOW_LAST_FRAME  ( 1 ),
            .TAG_BAD_FRAME     ( 0 )
        ) egr_port_gate (
            .axis_in    ( egr_phys_port_demuxed_i       ),
            .axis_out   ( egr_phys_port_gated           ),
            .enable     ( egr_phys_ports_enable[port]   ),
            .connected  ( egr_ports_connected[port]     )
        );

        // Packet, Byte, and Error Counts
        `MAKE_AXIS_MONITOR(egr_monitor, egr_phys_port_gated);

        axis_profile  #(
            .COUNT_WIDTH         ( EGR_COUNTERS_WIDTH ),
            .BYTECOUNT_DIVISOR   ( 1                  ),
            .FRAME_COUNT_DIVISOR ( 1                  ),
            .ERROR_COUNT_DIVISOR ( 1                  )
        ) egrress_counters (
            .axis                ( egr_monitor                 ),
            .enable              ( egr_phys_ports_enable[port] ),
            .clear_stb           ( egr_cnts_clear[port]        ),
            .error_count         (                             ),
            .frame_count         (                             ),
            .backpressure_time   (                             ),
            .stall_time          (                             ),
            .active_time         (                             ),
            .idle_time           (                             ),
            .data_count          (                             ),
            .counts              ( egr_cnts[port]              )
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(egr_phys_port_gated),
            .axis_out(egr_phys_port_adapted)
        );

        /// add logic to delay deque untill near full or eop in fifo
        // axis_dist_ram_fifo #(
        //     .DEPTH         ( 64     ),
        //     .ASYNC_CLOCKS  ( 1'b0   )
        // ) async_fifo (
        //     .axis_in           ( egr_phys_port_adapted           ),
        //     .axis_out          ( egr_phys_ports[port]            ),
        //     .axis_in_overflow  (                                 ),
        //     .axis_out_overflow ( ing_async_fifo_overflow[port]   )
        // );

        // Buffer
        /// Should only need 32-64 words of buffering so axis_dist_ram_fifo modified to wait for near full or tlast would be a good fit
        /// easier to use axis_fifo at the cost of 1 BRAM. Revisit if saving 1 BRAM per egress port would be worth while.
        axis_fifo_wrapper #(
            .DEPTH                ( 512 * (8/PHYS_PORT_DATA_BYTES) ),   // BRAMs are 64-bits wide by 512 deep. use one BRAM
            .KEEP_ENABLE          ( 1'b1 ),
            .LAST_ENABLE          ( 1'b1 ),
            .ID_ENABLE            ( 1'b0 ),
            .DEST_ENABLE          ( 1'b0 ),
            .USER_ENABLE          ( 1'b0 ),
            .FRAME_FIFO           ( 1'b1 ),
            .USER_BAD_FRAME_VALUE ( 1'b0 ),
            .USER_BAD_FRAME_MASK  ( 1'b0 ),
            .DROP_BAD_FRAME       ( 1'b0 ),
            .DROP_WHEN_FULL       ( 1'b0 ),
            .PIPELINE_OUTPUT      ( 2    )

        ) egress_buffer (
            .axis_in             ( egr_phys_port_adapted    ),
            .axis_out            ( egr_phys_port_buf_out    ),
            .status_overflow     ( egr_buf_full_drop[port]  ),
            .status_bad_frame    (),
            .status_good_frame   ()
        );

        // connect AXIS array element to a local AXIS interface here rather than connecting an array element to a module to avoid Modelsim bug
        always_comb begin
            egr_phys_ports[port].tvalid   = egr_phys_port_buf_out.tvalid;
            egr_phys_port_buf_out.tready  = egr_phys_ports[port].tready;
            egr_phys_ports[port].tdata    = egr_phys_port_buf_out.tdata;
            egr_phys_ports[port].tstrb    = egr_phys_port_buf_out.tstrb;
            egr_phys_ports[port].tkeep    = egr_phys_port_buf_out.tkeep;
            egr_phys_ports[port].tlast    = egr_phys_port_buf_out.tlast;
            egr_phys_ports[port].tid      = egr_phys_port_buf_out.tid;
            egr_phys_ports[port].tdest    = egr_phys_port_buf_out.tdest;
            egr_phys_ports[port].tuser    = egr_phys_port_buf_out.tuser;
        end

    end

endmodule

`default_nettype wire
