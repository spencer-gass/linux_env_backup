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

    localparam CDC_DATA_WIDTH = CONVERGED_BUS_DATA_BYTES*8 + CONVERGED_BUS_DATA_BYTES + 1; // tdata + tkeep + tlast


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GT(CONVERGED_BUS_DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : phys_ports_g

        // Signal declarations

        logic cdc_idle;
        logic cdc_req;
        logic cdc_ack;
        logic cdc_valid;
        logic [CDC_DATA_WIDTH-1:0] cdc_data_in;
        logic [CDC_DATA_WIDTH-1:0] cdc_data_out;


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



        logic [CDC_DATA_WIDTH-1:0] async_buf [7:0];
        logic [CDC_DATA_WIDTH-1:0] async_buf_rd_data;
        logic [2:0] wr_ptr;
        logic [2:0] wr_ptr_cdc;
        logic [2:0] rd_ptr;

        always_ff @(posedge ing_phys_ports[port_index].clk) begin
            ing_phys_ports[port_index].tready = 1'b1;
            if (ing_phys_ports[port_index].tvalid) begin
                wr_ptr++;
                async_buf[wr_ptr] <= {ing_phys_ports[port_index].tdata, ing_phys_ports[port_index].tkeep, ing_phys_ports[port_index].tlast};
            end
        end

        // add gray coder cdc for pointers
        assign wr_ptr_cdc = wr_ptr;

        assign async_buf_rd_data = async_buf[rd_ptr];

        assign ing_phys_port_cdc.tvalid = rd_ptr != wr_ptr_cdc ? 1'b0 : 1'b1;
        assign ing_phys_port_cdc.tdata  = async_buf_rd_data[1 + ing_phys_ports[port_index].DATA_BYTES +: ing_phys_ports[port_index].DATA_BYTES*8];
        assign ing_phys_port_cdc.tkeep  = async_buf_rd_data[1 +: ing_phys_ports[port_index].DATA_BYTES];
        assign ing_phys_port_cdc.tlast  = async_buf_rd_data[0];

        always_ff @(posedge ing_phys_ports_adapted[port_index].clk) begin
            if (ing_phys_ports_adapted[port_index].sresetn == 1'b0) begin
                rd_ptr <= '0;
            end else if (ing_phys_port_cdc.tready && ing_phys_port_cdc.tvalid) begin
                rd_ptr++;
            end
        end

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

        assign ing_buf_full_drop = 1'b0; // revise this once you have characterized the system better

    end

endmodule

`default_nettype wire
