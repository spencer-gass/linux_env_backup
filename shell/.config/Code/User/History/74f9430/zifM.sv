// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Ingress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Shallow async FIFO for CDC and buffering
 *  axis_adapt for width conversion to ingress bus width
 *  axis_mute to enable/disable a port
 *  axis_profile for stats counters
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
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_async_fifo_overflow

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam CDC_FIFO_DEPTH = 32;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(CONVERGED_BUS_DATA_BYTES, ing_phys_ports[0].DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : phys_ports_g

        // AXIS interfaces declarations

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

        // Packet Byte and Error Counts
        `MAKE_AXIS_MONITOR(ing_monitor, ing_phys_ports[port_index]);

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

        // Enable/Disable Ingress Port
        axis_mute #(
            .ALLOW_LAST_WORD   ( 1 ),
            .DROP_WHEN_MUTED   ( 1 ),
            .FRAMED            ( 1 ),
            .ALLOW_LAST_FRAME  ( 1 ),
            .TAG_BAD_FRAME     ( 0 )
        ) ing_port_gate (
            .axis_in    ( ing_phys_ports[port_index]                 ),
            .axis_out   ( ing_phys_port_gated               ),
            .enable     ( ing_phys_ports_enable[port_index] ),
            .connected  ( ing_ports_connected[port_index]   )
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(ing_phys_port_gated        ),
            .axis_out(ing_phys_port_width_conv  )
        );

        // Connect AXIS array element to a local AXIS interface here rather than connecting an array elemet to the fifo to avoid Modelsim bug
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
