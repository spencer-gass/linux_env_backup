// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Egress subsystem for P4 router
 *  Input wide AXIS bus from VNP4
 *  axis_demux_wrapper to split out to egress port buffers
 *  axis_adapt to width convert
 *  output to physical ports
**/
module p4_router_egress
    import p4_router_pkg::*;
 #(
    parameter int                               NUM_8B_EGR_PHYS_PORTS  = 0,
    parameter int                               NUM_16B_EGR_PHYS_PORTS = 0,
    parameter int                               NUM_32B_EGR_PHYS_PORTS = 0,
    parameter int                               NUM_64B_EGR_PHYS_PORTS = 0,
    parameter int                               MTU_BYTES              = 1500,
    parameter int                               NUM_EGR_PHYS_PORTS     = NUM_64B_EGR_PHYS_PORTS
                                                                       + NUM_32B_EGR_PHYS_PORTS
                                                                       + NUM_16B_EGR_PHYS_PORTS
                                                                       + NUM_8B_EGR_PHYS_PORTS,

    parameter bit                               EGR_BUS_DEBUG_ILA      = 1'b0,
    parameter bit [NUM_8B_EGR_PHYS_PORTS-1:0]   EGR_8B_PORT_DEBUG_ILA  = '0,
    parameter bit [NUM_16B_EGR_PHYS_PORTS-1:0]  EGR_16B_PORT_DEBUG_ILA = '0,
    parameter bit [NUM_32B_EGR_PHYS_PORTS-1:0]  EGR_32B_PORT_DEBUG_ILA = '0,
    parameter bit [NUM_64B_EGR_PHYS_PORTS-1:0]  EGR_64B_PORT_DEBUG_ILA = '0
)(
    AXIS_int.Slave                            egr_bus,
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_ready,

    AXIS_int.Master                           egr_8b_phys_ports  [NUM_8B_EGR_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Master                           egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master                           egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master                           egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0],

    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_phys_ports_enable,
    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_clear,
    output var logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_ports_conneted,
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_EGR_PHYS_PORTS,
                                                                             NUM_32B_EGR_PHYS_PORTS,
                                                                             NUM_16B_EGR_PHYS_PORTS,
                                                                             NUM_8B_EGR_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_EGR_PHYS_PORTS_PER_ARRAY);

    typedef int egr_port_index_map_t [NUM_EGR_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];

    function automatic egr_port_index_map_t create_egr_port_index_map();
        begin
            automatic egr_port_index_map_t map = '{default: '{default: -1}};
            automatic int cnt = 0;
            for(int i=0; i<NUM_EGR_AXIS_ARRAYS; i++) begin
                for(int j=0; j<NUM_EGR_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                    map[i][j] = cnt;
                    cnt++;
                end
            end
            return map;
        end
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
    `ELAB_CHECK_EQUAL(NUM_EGR_PHYS_PORTS, NUM_64B_EGR_PHYS_PORTS
                                        + NUM_32B_EGR_PHYS_PORTS
                                        + NUM_16B_EGR_PHYS_PORTS
                                        + NUM_8B_EGR_PHYS_PORTS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    AXIS_int #(
        .DATA_BYTES ( egr_bus.DATA_BYTES  )
    ) egr_phys_ports_demuxed [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     ( egr_bus.clk     ),
        .sresetn ( egr_bus.sresetn )
    );

    queue_system_metadata_t queue_system_metadata;
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] egr_port_sel;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Egress Demux

    assign queue_system_metadata    = egr_bus.tuser;
    assign egr_port_sel             = queue_system_metadata.egress_port[NUM_EGR_PHYS_PORTS_LOG-1:0];
    assign egr_bus.tready           = 1'b1;

    generate
        for (genvar port=0; port<NUM_EGR_PHYS_PORTS; port++) begin : egress_demux
            assign egr_buf_ready[port] = egr_phys_ports_demuxed[port].tready;
            always_ff @(posedge egr_bus.clk) begin
                egr_phys_ports_demuxed[port].tvalid <= (egr_bus.tvalid && egr_port_sel === port && egr_bus.sresetn) ? 1'b1 : 1'b0;
                egr_phys_ports_demuxed[port].tdata  <= egr_bus.tdata;
                egr_phys_ports_demuxed[port].tstrb  <= egr_bus.tstrb;
                egr_phys_ports_demuxed[port].tkeep  <= egr_bus.tkeep;
                egr_phys_ports_demuxed[port].tlast  <= egr_bus.tlast;
                egr_phys_ports_demuxed[port].tid    <= egr_bus.tid;
                egr_phys_ports_demuxed[port].tdest  <= egr_bus.tdest;
                egr_phys_ports_demuxed[port].tuser  <= 1'b0;
            end
        end
    endgenerate



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Per-Physical-Port Logic

    // For each egress physical port, cdc to physical interface clocks through a async FIFOs and convert data bus width to physical port width
    generate
        if (NUM_8B_EGR_PHYS_PORTS) begin : adapt_8b
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_8B_EGR_PHYS_PORTS ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES    ),
                .PHYS_PORT_DATA_BYTES       ( 1                     ),
                .MTU_BYTES                  ( MTU_BYTES             ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH    )
            ) egress_port_array_adapt_8b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_8B_START+:NUM_8B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_8b_phys_ports                                               ),
                .egr_phys_ports_enable      ( egr_phys_ports_enable[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]  ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]     ),
                .egr_buf_full_drop          ( egr_buf_full_drop[INDEX_8B_START +: NUM_8B_EGR_PHYS_PORTS]      )
            );
        end

        if (NUM_16B_EGR_PHYS_PORTS) begin : adapt_16b
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .PHYS_PORT_DATA_BYTES       ( 2                         ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_16b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_16B_START+:NUM_16B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_16b_phys_ports                                                ),
                .egr_phys_ports_enable      ( egr_phys_ports_enable[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]  ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]     ),
                .egr_buf_full_drop          ( egr_buf_full_drop[INDEX_16B_START +: NUM_16B_EGR_PHYS_PORTS]      )
            );
        end

        if (NUM_32B_EGR_PHYS_PORTS) begin : adapt_32b
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .PHYS_PORT_DATA_BYTES       ( 4                         ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_32b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_32B_START+:NUM_32B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_32b_phys_ports                                                ),
                .egr_phys_ports_enable      ( egr_phys_ports_enable[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]  ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]     ),
                .egr_buf_full_drop          ( egr_buf_full_drop[INDEX_32B_START +: NUM_32B_EGR_PHYS_PORTS]      )
            );
        end

        if (NUM_64B_EGR_PHYS_PORTS) begin : adapt_64b
            p4_router_egress_port_array_adapt #(
                .NUM_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS    ),
                .EGR_BUS_DATA_BYTES         ( egr_bus.DATA_BYTES        ),
                .PHYS_PORT_DATA_BYTES       ( 8                         ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .EGR_COUNTERS_WIDTH         ( EGR_COUNTERS_WIDTH        )
            ) egress_port_array_adapt_64b (
                .egr_phys_ports_demuxed     ( egr_phys_ports_demuxed[INDEX_64B_START+:NUM_64B_EGR_PHYS_PORTS]   ),
                .egr_phys_ports             ( egr_64b_phys_ports                                                ),
                .egr_phys_ports_enable      ( egr_phys_ports_enable[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]  ),
                .egr_cnts_clear             ( egr_cnts_clear[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]         ),
                .egr_cnts                   ( egr_cnts[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]               ),
                .egr_ports_connected        ( egr_ports_conneted[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]     ),
                .egr_buf_full_drop          ( egr_buf_full_drop[INDEX_64B_START +: NUM_64B_EGR_PHYS_PORTS]      )
            );
        end
    endgenerate

    `ifndef MODEL_TECH
        generate
                if (EGR_BUS_DEBUG_ILA) begin : gen_ila
                    logic [31:0] dbg_cntr;
                    always_ff @(posedge egr_bus.clk) begin
                        if (!egr_bus.sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug egr_bus_ila (
                        .clk    ( egr_bus.clk       ),
                        .probe0 ( egr_bus.sresetn   ),
                        .probe1 ( egr_bus.tready    ),
                        .probe2 ( egr_bus.tvalid    ),
                        .probe3 ( egr_bus.tkeep     ),
                        .probe4 ( egr_bus.tlast     ),
                        .probe5 ( egr_bus.tuser     ),
                        .probe6 ( dbg_cntr ),
                        .probe7 ( '0 ),
                        .probe8 ( '0 ),
                        .probe9 ( '0 ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end


            for (genvar port=0; port<NUM_8B_EGR_PHYS_PORTS; port++) begin : ila_8b
                if (EGR_8B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge egr_8b_phys_ports[port].clk) begin
                        if (!egr_8b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug egr_8b_port_ila (
                        .clk    ( egr_8b_phys_ports[port].clk       ),
                        .probe0 ( egr_8b_phys_ports[port].sresetn   ),
                        .probe1 ( egr_8b_phys_ports[port].tready    ),
                        .probe2 ( egr_8b_phys_ports[port].tvalid    ),
                        .probe3 ( egr_8b_phys_ports[port].tdata     ),
                        .probe4 ( egr_8b_phys_ports[port].tkeep     ),
                        .probe5 ( egr_8b_phys_ports[port].tlast     ),
                        .probe6 ( dbg_cntr ),
                        .probe7 ( '0 ),
                        .probe8 ( '0 ),
                        .probe9 ( '0 ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end

            for (genvar port=0; port<NUM_16B_EGR_PHYS_PORTS; port++) begin : ila_16b
                if (EGR_16B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge egr_16b_phys_ports[port].clk) begin
                        if (!egr_16b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug egr_16b_port_ila (
                        .clk    ( egr_16b_phys_ports[port].clk       ),
                        .probe0 ( egr_16b_phys_ports[port].sresetn   ),
                        .probe1 ( egr_16b_phys_ports[port].tready    ),
                        .probe2 ( egr_16b_phys_ports[port].tvalid    ),
                        .probe3 ( egr_16b_phys_ports[port].tdata     ),
                        .probe4 ( egr_16b_phys_ports[port].tkeep     ),
                        .probe5 ( egr_16b_phys_ports[port].tlast     ),
                        .probe6 ( dbg_cntr),
                        .probe7 ( '0 ),
                        .probe8 ( '0 ),
                        .probe9 ( '0 ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end

            for (genvar port=0; port<NUM_32B_EGR_PHYS_PORTS; port++) begin : ila_32b
                if (EGR_32B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge egr_32b_phys_ports[port].clk) begin
                        if (!egr_32b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug egr_32b_port_ila (
                        .clk    ( egr_32b_phys_ports[port].clk       ),
                        .probe0 ( egr_32b_phys_ports[port].sresetn   ),
                        .probe1 ( egr_32b_phys_ports[port].tready    ),
                        .probe2 ( egr_32b_phys_ports[port].tvalid    ),
                        .probe3 ( egr_32b_phys_ports[port].tdata     ),
                        .probe4 ( egr_32b_phys_ports[port].tkeep     ),
                        .probe5 ( egr_32b_phys_ports[port].tlast     ),
                        .probe6 ( dbg_cntr ),
                        .probe7 ( '0 ),
                        .probe8 ( '0 ),
                        .probe9 ( '0 ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end
            for (genvar port=0; port<NUM_64B_EGR_PHYS_PORTS; port++) begin : ila_64b
                if (EGR_64B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge egr_64b_phys_ports[port].clk) begin
                        if (!egr_64b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug egr_64b_port_ila (
                        .clk    ( egr_64b_phys_ports[port].clk          ),
                        .probe0 ( egr_64b_phys_ports[port].sresetn      ),
                        .probe1 ( egr_64b_phys_ports[port].tready       ),
                        .probe2 ( egr_64b_phys_ports[port].tvalid       ),
                        .probe3 ( egr_64b_phys_ports[port].tdata[63:32] ),
                        .probe4 ( egr_64b_phys_ports[port].tdata[31:0]  ),
                        .probe5 ( egr_64b_phys_ports[port].tkeep        ),
                        .probe6 ( egr_64b_phys_ports[port].tlast        ),
                        .probe7 ( dbg_cntr ),
                        .probe8 ( '0 ),
                        .probe9 ( '0 ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
