// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * MPLS Ingress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Encapsulates axis_adapter_wrapper for data width conversion,
 *  and axis_async_fifo for CDC and buffering
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_ingress_port_array_adapt #(
    parameter int NUM_ING_PHYS_PORTS = 0,
    parameter int CONVERGED_BUS_DATA_BYTES = 0,
    parameter int MTU_BYTES = 1500
) (
    AXIS_int.Slave      ing_phys_ports          [NUM_ING_PHYS_PORTS-1:0],
    AXIS_int.Master     ing_phys_ports_adapted  [NUM_ING_PHYS_PORTS-1:0],

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(CONVERGED_BUS_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : phys_ports_g

        // Declare AXIS interfaces
        AXIS_int #(
            .DATA_BYTES ( CONVERGED_BUS_DATA_BYTES  )
        ) ing_phys_port_width_conv (
            .clk     (ing_phys_ports[port_index].clk    ),
            .sresetn (ing_phys_ports[port_index].sresetn)
        );

        AXIS_int #(
            .DATA_BYTES ( CONVERGED_BUS_DATA_BYTES  )
        ) ing_phys_port_buf_out (
            .clk     (ing_phys_ports[port_index].clk    ),
            .sresetn (ing_phys_ports[port_index].sresetn)
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(ing_phys_ports[port_index]),
            .axis_out(ing_phys_port_width_conv)
        );

        // Buffer and CDC
        axis_async_fifo_wrapper #(
            .DEPTH                ( MTU_BYTES * 2 / CONVERGED_BUS_DATA_BYTES ),   // room for 2 MTUs
            .KEEP_ENABLE          ( 1'b1 ),
            .LAST_ENABLE          ( 1'b1 ),
            .ID_ENABLE            ( 1'b0 ),
            .DEST_ENABLE          ( 1'b0 ),
            .USER_ENABLE          ( 1'b0 ),
            .FRAME_FIFO           ( 1'b1 ),
            .USER_BAD_FRAME_VALUE ( 1'b0 ),
            .USER_BAD_FRAME_MASK  ( 1'b0 ),
            .DROP_BAD_FRAME       ( 1'b0 ),
            .DROP_WHEN_FULL       ( 1'b1 ),             // Keep this part of the system feed forward and size buses and fifos so that fifos don't overflow
            .PIPELINE_OUTPUT      ( 2    )

        ) ingress_buffer (
            .axis_in             ( ing_phys_port_width_conv             ),
            .axis_out            ( ing_phys_port_buf_out                ),
            .axis_in_overflow    (),
            .axis_in_bad_frame   (),
            .axis_in_good_frame  (),
            .axis_out_overflow   ( ing_buf_overflow[port_index] ),
            .axis_out_bad_frame  (),
            .axis_out_good_frame ()
        );

        // Connect to the output AXIS array here rather than connecting an array elemet to the fifo to avoid Modelsim bug
        always_comb begin
            ing_phys_ports_adapted[port_index].tvalid = ing_phys_port_buf_out.tvalid;
            ing_phys_port_buf_out.tready              = ing_phys_ports_adapted[port_index].tready;
            ing_phys_ports_adapted[port_index].tdata  = ing_phys_port_buf_out.tdata;
            ing_phys_ports_adapted[port_index].tstrb  = ing_phys_port_buf_out.tstrb;
            ing_phys_ports_adapted[port_index].tkeep  = ing_phys_port_buf_out.tkeep;
            ing_phys_ports_adapted[port_index].tlast  = ing_phys_port_buf_out.tlast;
            ing_phys_ports_adapted[port_index].tid    = ing_phys_port_buf_out.tid;
            ing_phys_ports_adapted[port_index].tdest  = ing_phys_port_buf_out.tdest;
            ing_phys_ports_adapted[port_index].tuser  = ing_phys_port_buf_out.tuser;
        end

    end


endmodule

`default_nettype wire
