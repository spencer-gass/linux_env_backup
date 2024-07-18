// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * MPLS Egress Port Array Adapter
 *  Operates on an array of AXIS interfaces
 *  Encapsulates axis_async_fifo for CDC and buffering
 *  and axis_adapter_wrapper for data width conversion,
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module mpls_egress_port_array_adapt #(
    parameter int NUM_EGR_PHYS_PORTS = 0,
    parameter int EGR_BUS_DATA_BYTES = 0,
    parameter int MTU_BYTES = 1500
) (
    AXIS_int.Master     egr_phys_ports_demuxed  [NUM_EGR_PHYS_PORTS-1:0],
    AXIS_int.Slave      egr_phys_ports          [NUM_EGR_PHYS_PORTS-1:0],

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
            .axis_in             ( egr_phys_ports_demuxed[port_index]   ),
            .axis_out            ( egr_phys_port_buf_out                ),
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
            .axis_out(egr_phys_ports[port_index])
        );


        // // Connect to the output AXIS array here rather than connecting an array elemet to the fifo to avoid Modelsim bug
        // always_comb begin
        //     egr_phys_ports_adapted[port_index].tvalid = egr_phys_port_buf_out.tvalid;
        //     egr_phys_port_buf_out.tready              = egr_phys_ports_adapted[port_index].tready;
        //     egr_phys_ports_adapted[port_index].tdata  = egr_phys_port_buf_out.tdata;
        //     egr_phys_ports_adapted[port_index].tstrb  = egr_phys_port_buf_out.tstrb;
        //     egr_phys_ports_adapted[port_index].tkeep  = egr_phys_port_buf_out.tkeep;
        //     egr_phys_ports_adapted[port_index].tlast  = egr_phys_port_buf_out.tlast;
        //     egr_phys_ports_adapted[port_index].tid    = egr_phys_port_buf_out.tid;
        //     egr_phys_ports_adapted[port_index].tdest  = egr_phys_port_buf_out.tdest;
        //     egr_phys_ports_adapted[port_index].tuser  = egr_phys_port_buf_out.tuser;
        // end

    end

endmodule

`default_nettype wire
