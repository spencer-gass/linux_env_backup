// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Ingress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Encapsulates axis_adapter_wrapper for data width conversion,
 *  and axis_async_fifo for CDC and buffering
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../util/util_make_monitors.svh"
`default_nettype none

module p4_router_ingress_port_array_adapt #(
    parameter int NUM_ING_PHYS_PORTS        = 0,
    parameter int CONVERGED_BUS_DATA_BYTES  = 0,
    parameter int MTU_BYTES                 = 1500,
    parameter int ING_COUNTERS_WIDTH        = 32
) (
    AXIS_int.Slave      ing_phys_ports          [NUM_ING_PHYS_PORTS-1:0],
    AXIS_int.Master     ing_phys_ports_adapted  [NUM_ING_PHYS_PORTS-1:0],

    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    output var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_connected,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_full_drop

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam CDC_FIFO_DEPTH = 32;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(CONVERGED_BUS_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : phys_ports_g

        // AXIS interfaces declarations

        AXIS_int #(
            .DATA_BYTES ( ing_phys_ports[port_index].DATA_BYTES )
        ) ing_phys_port_cdc (
            .clk     (ing_phys_ports_adapted[port_index].clk    ),
            .sresetn (ing_phys_ports_adapted[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( ing_phys_ports[port_index].DATA_BYTES )
        ) ing_phys_port_gated (
            .clk     (ing_phys_ports_adapted[port_index].clk    ),
            .sresetn (ing_phys_ports_adapted[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( CONVERGED_BUS_DATA_BYTES  )
        ) ing_phys_port_width_conv (
            .clk     (ing_phys_ports_adapted[port_index].clk    ),
            .sresetn (ing_phys_ports_adapted[port_index].sresetn)
        );

        axis_dist_ram_fifo #(
            .DEPTH           ( CDC_FIFO_DEPTH  ),
            .KEEP_ENABLE     ( 1'b1 ),
            .LAST_ENABLE     ( 1'b1 ),
            .ID_ENABLE       ( 1'b0 ),
            .DEST_ENABLE     ( 1'b0 ),
            .USER_ENABLE     ( 1'b0 ),
            .PIPELINE_OUTPUT ( 1    ),
            .ASYNC_CLOCKS    ( 1'b0 )
        ) async_fifo (
            .axis_in            ( ing_phys_ports[port_index] ),
            .axis_out           ( ing_phys_port_cdc          ),
            .axis_in_overflow   (                            ),
            .axis_out_overflow  ( ing_buf_full_drop          )
        );

    axis_async_fifo #(
        DEPTH = 32,
        DATA_WIDTH = 8,
        KEEP_ENABLE = (DATA_WIDTH>8),
        KEEP_WIDTH = (DATA_WIDTH/8),
        LAST_ENABLE = 1,
        ID_ENABLE = 0,
        ID_WIDTH = 8,
        DEST_ENABLE = 0,
        DEST_WIDTH = 8,
        USER_ENABLE = 1,
        USER_WIDTH = 1,
        PIPELINE_OUTPUT = 2,
        FRAME_FIFO = 0,
        USER_BAD_FRAME_VALUE = 1'b1,
        USER_BAD_FRAME_MASK = 1'b1,
        DROP_BAD_FRAME = 0,
        DROP_WHEN_FULL = 0
    ) async_fifo (
    .async_rst      (),

    .s_clk                  (  ),
    .s_axis_tdata           (  ),
    .s_axis_tkeep           (  ),
    .s_axis_tvalid          (  ),
    .s_axis_tready          (  ),
    .s_axis_tlast           (  ),
    .s_axis_tid             (  ),
    .s_axis_tdest           (  ),
    .s_axis_tuser           (  ),

    .m_clk                  (  ),
    .m_axis_tdata           (  ),
    .m_axis_tkeep           (  ),
    .m_axis_tvalid          (  ),
    .m_axis_tready          (  ),
    .m_axis_tlast           (  ),
    .m_axis_tid             (  ),
    .m_axis_tdest           (  ),
    .m_axis_tuser           (  ),

    .s_status_overflow      (  ),
    .s_status_bad_frame     (  ),
    .s_status_good_frame    (  ),
    .m_status_overflow      (  ),
    .m_status_bad_frame     (  ),
    .m_status_good_frame    (  )
);

        // Packet Byte and Error Counts
        `MAKE_AXIS_MONITOR(ing_monitor, ing_phys_port_cdc);

        axis_profile  #(
            .COUNT_WIDTH         ( ING_COUNTERS_WIDTH ),
            .BYTECOUNT_DIVISOR   ( 1                 ),
            .FRAME_COUNT_DIVISOR ( 1                 ),
            .ERROR_COUNT_DIVISOR ( 1                 )
        ) ingress_counters (
            .axis                ( ing_monitor                       ),
            .enable              ( ing_phys_ports_enable[port_index] ),
            .clear_stb           ( ing_cnts_clear[port_index]        ),
            .error_count         (                                   ),
            .frame_count         (                                   ),
            .backpressure_time   (                                   ),
            .stall_time          (                                   ),
            .active_time         (                                   ),
            .idle_time           (                                   ),
            .data_count          (                                   ),
            .counts              ( ing_cnts[port_index]              )
        );

        // Enable/disable ingress port
        axis_mute #(
            .ALLOW_LAST_WORD   ( 1 ),
            .DROP_WHEN_MUTED   ( 1 ),
            .FRAMED            ( 1 ),
            .ALLOW_LAST_FRAME  ( 1 ),
            .TAG_BAD_FRAME     ( 0 )
        ) ing_port_gate (
            .axis_in    ( ing_phys_port_cdc                 ),
            .axis_out   ( ing_phys_port_gated               ),
            .enable     ( ing_phys_ports_enable[port_index] ),
            .connected  ( ing_ports_connected[port_index]   )
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(ing_phys_port_gated        ),
            .axis_out(ing_phys_port_width_conv  )
        );

        // connect AXIS array element to a local AXIS interface here rather than connecting an array elemet to the fifo to avoid Modelsim bug
        always_comb begin
            ing_phys_ports_adapted[port_index].tvalid   = ing_phys_port_width_conv.tvalid;
            ing_phys_port_width_conv.tready             = ing_phys_ports_adapted[port_index].tready;
            ing_phys_ports_adapted[port_index].tdata    = ing_phys_port_width_conv.tdata;
            ing_phys_ports_adapted[port_index].tstrb    = ing_phys_port_width_conv.tstrb;
            ing_phys_ports_adapted[port_index].tkeep    = ing_phys_port_width_conv.tkeep;
            ing_phys_ports_adapted[port_index].tlast    = ing_phys_port_width_conv.tlast;
            ing_phys_ports_adapted[port_index].tid      = ing_phys_port_width_conv.tid;
            ing_phys_ports_adapted[port_index].tdest    = ing_phys_port_width_conv.tdest;
            ing_phys_ports_adapted[port_index].tuser    = ing_phys_port_width_conv.tuser;
        end

    end

endmodule

`default_nettype wire