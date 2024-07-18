module mpls_ingress_port_array_adapt #(
    parameter int NUM_ING_PHYS_PORTS = 0;
    parameter int CONVERGED_BUS_DATA_BYTES = 0;
    parameter int MTU_BYTES = 1500;
) (
    AXIS_int.Slave      ing_phys_ports          [NUM_ING_PHYS_PORTS-1:0],
    AXIS_int.Master     ing_phys_ports_adapted  [NUM_ING_PHYS_PORTS-1:0],

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow

);
    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(CONVERGED_BUS_DATA_BYTES, 0);

    for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : phys_ports_g

        AXIS_int #(
            .DATA_BYTES ( CONVERGED_BUS_DATA_BYTES  )
        ) ing_phys_port_width_conv (
            .clk     (ing_phys_ports[port_index].clk    ),
            .sresetn (ing_phys_ports[port_index].sresetn)
        );

        // Width Convert to output data bus width
        axis_adapter_wrapper width_conv (
            .axis_in(ing_phys_ports[port_index]),
            .axis_out(ing_phys_port_width_conv)
        );

        // Width conv then cdc/buf for now since the buffer output will plug into the ingress buffer easier
        // probably more resource efficient to buffer before width conv
        axis_async_fifo_wrapper #(
            .DEPTH                ( MTU_BYTES * 2 / CONVERGED_BUS_DATA_BYTES ),   // room for 2 MTUs
            .KEEP_ENABLE          ( 1'b1 ),
            .LAST_ENABLE          ( 1'b1 ),
            .ID_ENABLE            ( 1'b0 ),
            .DEST_ENABLE          ( 1'b0 ),
            .USER_ENABLE          ( 1'b1 ),             // convey physical port index via tuser
            .FRAME_FIFO           ( 1'b1 ),
            .USER_BAD_FRAME_VALUE ( 1'b0 ),
            .USER_BAD_FRAME_MASK  ( 1'b0 ),
            .DROP_BAD_FRAME       ( 1'b0 ),
            .DROP_WHEN_FULL       ( 1'b1 ),             // Keep this part of the system feed forward and size buses and fifos so that fifos don't overflow
            .PIPELINE_OUTPUT      ( 2    )

        ) ingress_buffer (
            .axis_in             ( ing_phys_port_width_conv             ),
            .axis_out            ( ing_phys_ports_adapted[port_index]   ),
            .axis_in_overflow    (),
            .axis_in_bad_frame   (),
            .axis_in_good_frame  (),
            .axis_out_overflow   ( ing_buf_overflow[port_index] ),
            .axis_out_bad_frame  (),
            .axis_out_good_frame ()
        );
    end

endmodule