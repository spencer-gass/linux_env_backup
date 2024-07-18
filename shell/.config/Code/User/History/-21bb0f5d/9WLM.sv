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
    parameter int MTU_BYTES = 9600,
    parameter int NUM_EGR_PHYS_PORTS = NUM_64B_EGR_PHYS_PORTS +
                                       NUM_32B_EGR_PHYS_PORTS +
                                       NUM_16B_EGR_PHYS_PORTS +
                                       NUM_8B_EGR_PHYS_PORTS
)(
    Clock_int.Output    clk_ifc,
    Reset_int.ResetOut  sreset_ifc,

    AXIS_int.Slave      egr_bus,

    AXIS_int.Master     egr_8b_phys_ports  [NUM_8B_EGR_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Master     egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0],

    output var logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_EGR_PHYS_PORTS,
                                                                             NUM_32B_EGR_PHYS_PORTS,
                                                                             NUM_16B_EGR_PHYS_PORTS,
                                                                             NUM_8B_EGR_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_EGR_PHYS_PORTS_PER_ARRAY);

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



    localparam NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);

    localparam egr_port_index_map_t EGR_PORT_INDEX_MAP = create_egr_port_index_map();
    localparam INDEX_8B_START  = EGR_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_16B_START = EGR_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_32B_START = EGR_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_64B_START = EGR_PORT_INDEX_MAP[INDEX_64B][0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GE(egr_bus.DATA_BYTES, 8) // wide output bus needs to be at least as wide as the widest input bus
    `ELAB_CHECK_GT(NUM_EGR_PHYS_PORTS, 0);
    `ELAB_CHECK_EQUAL(NUM_EGR_PHYS_PORTS, NUM_64B_EGR_PHYS_PORTS +
                                          NUM_32B_EGR_PHYS_PORTS +
                                          NUM_16B_EGR_PHYS_PORTS +
                                          NUM_8B_EGR_PHYS_PORTS);


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
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES    ),
                .MTU_BYTES                  ( MTU_BYTES             ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH    )
            ) egress_port_array_adapt_8b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_8B_START+:NUM_8B_EGR_PHYS_PORTS]     ),
                .egr_phys_ports             ( egr_8b_phys_ports                                                 ),
                .egr_ports_enable           ( egr_ports_enable[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]       ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]     ),
                .egr_buf_overflow           ( egr_buf_overflow[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]         )
            );
        end

        if (NUM_16B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_16b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_16B_START+:NUM_16B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_16b_phys_ports                                                ),
                .egr_ports_enable           ( egr_ports_enable[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]       ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]     ),
                .egr_buf_overflow           ( egr_buf_overflow[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]       )
            );
        end

        if (NUM_32B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_32b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_32B_START+:NUM_32B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_32b_phys_ports                                                ),
                .egr_ports_enable           ( egr_ports_enable[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]       ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]     ),
                .egr_buf_overflow           ( egr_buf_overflow[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]       )
            );
        end

        if (NUM_64B_EGR_PHYS_PORTS) begin
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_64b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_64B_START+:NUM_64B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_64b_phys_ports                                                ),
                .egr_ports_enable           ( egr_ports_enable[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]       ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]     ),
                .egr_buf_overflow           ( egr_buf_overflow[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]       )
            );
        end
    endgenerate


endmodule

`default_nettype wire
