// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Egress subsystem for MPLS router
 *  Input wide AXIS bus from VNP4
 *  axis_demux_wrapper to split out to egress port buffers
 *  axis_async_fifo to buffer and CDC
 *  output to physical ports
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none


module mpls_egress #(
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


    output var logic [NUM_8B_EGR_PHYS_PORTS-1:0]  egr_8b_buf_overflow,
    output var logic [NUM_16B_EGR_PHYS_PORTS-1:0] egr_16b_buf_overflow,
    output var logic [NUM_32B_EGR_PHYS_PORTS-1:0] egr_32b_buf_overflow,
    output var logic [NUM_64B_EGR_PHYS_PORTS-1:0] egr_64b_buf_overflow
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    enum {
        EGR_8B_INDEX,
        EGR_16B_INDEX,
        EGR_32B_INDEX,
        EGR_64B_INDEX,
        NUM_EGR_AXIS_ARRAYS
    } port_width_indecies;

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_EGR_PHYS_PORTS,
                                                                             NUM_32B_EGR_PHYS_PORTS,
                                                                             NUM_16B_EGR_PHYS_PORTS,
                                                                             NUM_8B_EGR_PHYS_PORTS
                                                                          };

    function int get_max_num_ports_per_array();
        automatic int max = 0;
        for (int i=0; i<NUM_EGR_AXIS_ARRAYS; i++) begin
            if (NUM_EGR_PHYS_PORTS_PER_ARRAY[i] > max) begin
                max = NUM_EGR_PHYS_PORTS_PER_ARRAY[i];
            end
        end
        return max;
    endfunction

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array();

    typedef int egr_port_index_map_t [NUM_EGR_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];

    function egr_port_index_map_t create_egr_port_index_map();
        automatic egr_port_index_map_t map = '{default: '{default: -1}};
        automatic int cnt = 0;
        for(int i=0; i<NUM_EGR_AXIS_ARRAYS; i++) begin
            for(int j=0; j<NUM_EGR_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                map[i][j] = cnt;
                cnt++;
            end
        end
        return map;
    endfunction

    localparam NUM_EGR_PHYS_PORTS = {NUM_64B_EGR_PHYS_PORTS +
                                     NUM_32B_EGR_PHYS_PORTS +
                                     NUM_16B_EGR_PHYS_PORTS +
                                     NUM_8B_EGR_PHYS_PORTS};

    localparam NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);

    localparam egr_port_index_map_t EGR_PORT_INDEX_MAP = create_egr_port_index_map();
    localparam INDEX_8B_START  = EGR_PORT_INDEX_MAP[EGR_8B_INDEX][0];
    localparam INDEX_16B_START = EGR_PORT_INDEX_MAP[EGR_16B_INDEX][0];
    localparam INDEX_32B_START = EGR_PORT_INDEX_MAP[EGR_32B_INDEX][0];
    localparam INDEX_64B_START = EGR_PORT_INDEX_MAP[EGR_64B_INDEX][0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GE(egr_bus.DATA_BYTES, 8) // wide output bus needs to be at least as wide as the widest input bus
    `ELAB_CHECK_GT(NUM_EGR_PHYS_PORTS, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  )
    ) egr_phys_ports_demuxed [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk      ),
        .sresetn ( sreset_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  ),
        .USER_WIDTH ( NUM_EGR_PHYS_PORTS_LOG        )
    ) egr_phys_ports_tuser_index_insert [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk      ),
        .sresetn ( sreset_ifc.reset )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Egress Demux

    axis_demux_wrapper #(
        parameter int N = NUM
    ) egress_demux (
        .axis_in    ( egr_bus ),
        .axis_out   ( egr_phys_ports_demuxed ),
        .enable     (  ),
        .drop       (  ),
        .select     (  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Per-Physical-Port Logic

    // For each egress physical port, convert data bus width to egr_bus width and cdc to core clock through an async FIFO
    generate
        if (NUM_8B_EGR_PHYS_PORTS) begin
            mpls_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_8B_EGR_PHYS_PORTS         ),
                .CONVERGED_BUS_DATA_BYTES   ( egr_bus.DATA_BYTES  ),
                .MTU_BYTES                  ( MTU_BYTES                     )
            ) egress_port_array_adapt_8b (
                .egr_phys_ports             ( egr_8b_phys_ports ),
                .egr_phys_ports_adapted     ( egr_phys_ports_adapted[INDEX_8B_START+:NUM_8B_EGR_PHYS_PORTS] ),
                .egr_buf_overflow           ( egr_8b_buf_overflow )
            );
        end else begin
            assign egr_8b_buf_overflow = 1'b0;
        end

        if (NUM_16B_EGR_PHYS_PORTS) begin
            mpls_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS         ),
                .CONVERGED_BUS_DATA_BYTES   ( egr_bus.DATA_BYTES  ),
                .MTU_BYTES                  ( MTU_BYTES                     )
            ) egress_port_array_adapt_16b (
                .egr_phys_ports             ( egr_16b_phys_ports ),
                .egr_phys_ports_adapted     ( egr_phys_ports_adapted[INDEX_16B_START+:NUM_16B_EGR_PHYS_PORTS] ),
                .egr_buf_overflow           ( egr_16b_buf_overflow )
            );
        end else begin
            assign egr_16b_buf_overflow = 1'b0;
        end

        if (NUM_32B_EGR_PHYS_PORTS) begin
            mpls_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS         ),
                .CONVERGED_BUS_DATA_BYTES   ( egr_bus.DATA_BYTES  ),
                .MTU_BYTES                  ( MTU_BYTES                     )
            ) egress_port_array_adapt_32b (
                .egr_phys_ports             ( egr_32b_phys_ports ),
                .egr_phys_ports_adapted     ( egr_phys_ports_adapted[INDEX_32B_START+:NUM_32B_EGR_PHYS_PORTS] ),
                .egr_buf_overflow           ( egr_32b_buf_overflow )
            );
        end else begin
            assign egr_32b_buf_overflow = 1'b0;
        end

        if (NUM_64B_EGR_PHYS_PORTS) begin
            mpls_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS         ),
                .CONVERGED_BUS_DATA_BYTES   ( egr_bus.DATA_BYTES  ),
                .MTU_BYTES                  ( MTU_BYTES                     )
            ) egress_port_array_adapt_64b (
                .egr_phys_ports             ( egr_64b_phys_ports ),
                .egr_phys_ports_adapted     ( egr_phys_ports_adapted[INDEX_64B_START+:NUM_64B_EGR_PHYS_PORTS] ),
                .egr_buf_overflow           ( egr_64b_buf_overflow )
            );
        end else begin
            assign egr_64b_buf_overflow = 1'b0;
        end
    endgenerate

    // Insert physical port index into tuser
    generate
        for (genvar port_index=0; port_index<NUM_EGR_PHYS_PORTS; port_index++) begin : insert_phys_port_index_g
            always_comb begin
                egr_phys_ports_tuser_index_insert[port_index].tvalid = egr_phys_ports_adapted[port_index].tvalid;
                egr_phys_ports_adapted[port_index].tready            = egr_phys_ports_tuser_index_insert[port_index].tready;
                egr_phys_ports_tuser_index_insert[port_index].tdata  = egr_phys_ports_adapted[port_index].tdata;
                egr_phys_ports_tuser_index_insert[port_index].tstrb  = egr_phys_ports_adapted[port_index].tstrb;
                egr_phys_ports_tuser_index_insert[port_index].tkeep  = egr_phys_ports_adapted[port_index].tkeep;
                egr_phys_ports_tuser_index_insert[port_index].tlast  = egr_phys_ports_adapted[port_index].tlast;
                egr_phys_ports_tuser_index_insert[port_index].tid    = egr_phys_ports_adapted[port_index].tid;
                egr_phys_ports_tuser_index_insert[port_index].tdest  = egr_phys_ports_adapted[port_index].tdest;
                egr_phys_ports_tuser_index_insert[port_index].tuser  = port_index;
            end
        end
    endgenerate

endmodule

`default_nettype wire

