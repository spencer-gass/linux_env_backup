// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Ingress subsystem for P4 router
 *  Input arrays of AXIS interfaces grouped by data width
 *  p4_router_ingress_port_array_adapt provides width conversion, port enable, and counters.
 *  Ingress buffer aggregates words from the adapted interfaces into packets to send toward VNP4.
 *
 * Notes:
 *  The purpose of this module is to aggregate packets from many narrow axis interfaces into a
 *  single wide axis interface without backpressuring the input interface, or overflowing buffers
 *  while using as little RAM as possible.
**/
module p4_router_ingress
    import P4_ROUTER_PKG::*;
#(
    parameter int                              NUM_8B_ING_PHYS_PORTS  = 0,
    parameter int                              NUM_16B_ING_PHYS_PORTS = 0,
    parameter int                              NUM_32B_ING_PHYS_PORTS = 0,
    parameter int                              NUM_64B_ING_PHYS_PORTS = 0,
    parameter int                              MTU_BYTES              = 1500,
    parameter int                              NUM_ING_PHYS_PORTS     = NUM_64B_ING_PHYS_PORTS
                                                                      + NUM_32B_ING_PHYS_PORTS
                                                                      + NUM_16B_ING_PHYS_PORTS
                                                                      + NUM_8B_ING_PHYS_PORTS,
    parameter bit [NUM_8B_ING_PHYS_PORTS-1:0]  ING_8B_PORT_DEBUG_ILA  = '0,
    parameter bit [NUM_16B_ING_PHYS_PORTS-1:0] ING_16B_PORT_DEBUG_ILA = '0,
    parameter bit [NUM_32B_ING_PHYS_PORTS-1:0] ING_32B_PORT_DEBUG_ILA = '0,
    parameter bit [NUM_64B_ING_PHYS_PORTS-1:0] ING_64B_PORT_DEBUG_ILA = '0,
    parameter bit                              ING_BUF_DEBUG_ILA      = 1'b0
)
(
    AXIS_int.Slave                            ing_8b_phys_ports  [NUM_8B_ING_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Slave                            ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave                            ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave                            ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0],

    AXIS_int.Master                           ing_bus,

    output var logic [63:0]                   ing_bus_pkt_cnt,
    input  var logic                          ing_bus_pkt_cnt_clear,

    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    output var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    // Need to be able to hold MTU bytes since all of the words of a packet need to be present before the packet
    // can begin exiting the buffer. MTU_WORDS*(NUM_ING_PHYS_PORTS-1) would be the max number of cycles a complete
    // packet would need to wait before being scheduled (i.e. every other interface has to dispatch an MTU before
    // the interface of interest can start dispatching). Minimum cycles to add a word to the buffer would be
    // ing_bus.DATA_BYTES/8 (64-bit/8-byte interfaces would fill fastest) so
    // MTU_WORDS*(NUM_ING_PHYS_PORTS-1)/ing_bus.DATA_BYTES/8 + MTU_WORDS would be the requirement.
    // Current design requires power-of-two sized partitions and equally size partitions.
    // Could create a partition offset map and add the partition offset rather than concatenating ingress port number
    // in order to get non-power-of-two and unequal sized partitions. Would also need pointer wrapping logic.
    // Probably reasonable to assume all interfaces won't send MTUs at the same time so that requirement could be relaxed.
    // Slower interfaces add words to the ingress buffer less frequently so that overhead could be reduced for those interfaces.
    // Lower bound would be just north of one MTU.
    // Fudge to 2*MTU so that near power of two MTUs fit well.

    localparam int MTU_WORDS                    = U_INT_CEIL_DIV(MTU_BYTES,ing_bus.DATA_BYTES);
    localparam int BYTES_PER_64_BITS            = 8;
    localparam int MAX_SCHED_WAIT_CYCLES        = MTU_WORDS*(NUM_ING_PHYS_PORTS-1);
    localparam int MIN_CYCLES_TO_ADD_A_WORD     = ing_bus.DATA_BYTES/BYTES_PER_64_BITS;
    localparam int MIN_ING_BUF_DEPTH_PER_IFC    = MTU_WORDS + MAX_SCHED_WAIT_CYCLES/MIN_CYCLES_TO_ADD_A_WORD;
    localparam int ING_BUF_DEPTH_PER_IFC        = 2**($clog2(2*MTU_WORDS));

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_ING_PHYS_PORTS,
                                                                             NUM_32B_ING_PHYS_PORTS,
                                                                             NUM_16B_ING_PHYS_PORTS,
                                                                             NUM_8B_ING_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_ING_PHYS_PORTS_PER_ARRAY);

    typedef int ing_port_index_map_t [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];

    function automatic ing_port_index_map_t create_ing_port_index_map();
        begin
            automatic ing_port_index_map_t map = '{default: '{default: -1}};
            automatic int cnt = 0;
            for(int i=0; i<NUM_ING_AXIS_ARRAYS; i++) begin
                for(int j=0; j<NUM_ING_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                    map[i][j] = cnt;
                    cnt++;
                end
            end
            return map;
        end
    endfunction

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);

    localparam ing_port_index_map_t ING_PORT_INDEX_MAP = create_ing_port_index_map();

    localparam INDEX_8B_START  = ING_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_16B_START = ING_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_32B_START = ING_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_64B_START = ING_PORT_INDEX_MAP[INDEX_64B][0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_GE(ing_bus.USER_WIDTH, NUM_ING_PHYS_PORTS_LOG); // physical port index is conveyed through tuser
    `ELAB_CHECK_GE(ing_bus.DATA_BYTES, 8) // wide output bus needs to be at least as wide as the widest input bus
    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_EQUAL(NUM_ING_PHYS_PORTS, NUM_64B_ING_PHYS_PORTS
                                        + NUM_32B_ING_PHYS_PORTS
                                        + NUM_16B_ING_PHYS_PORTS
                                        + NUM_8B_ING_PHYS_PORTS);
    `ELAB_CHECK_GE(NUM_ING_PHYS_PORTS, 1);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    AXIS_int #(
        .DATA_BYTES ( ing_bus.DATA_BYTES  )
    ) ing_phys_ports_adapted [NUM_ING_PHYS_PORTS-1:0] (
        .clk     ( ing_bus.clk      ),
        .sresetn ( ing_bus.sresetn  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Per-Physical-Port Logic


    `define DEF_ING_PORT_ARRAY_ADAPT(num_ports, axis_array, index_start)                            \
        p4_router_ingress_port_array_adapt #(                                                       \
            .NUM_ING_PHYS_PORTS         ( `num_ports`               ),                              \
            .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),                              \
            .MTU_BYTES                  ( MTU_BYTES                 ),                              \
            .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )                               \
        ) ingress_port_array_adapt_8b (                                                             \
            .ing_phys_ports             ( `axis_array`                                          ),  \
            .ing_phys_ports_adapted     ( ing_phys_ports_adapted[`index_start`+:`num_ports`]    ),  \
            .ing_phys_ports_enable      ( ing_phys_ports_enable[`index_start` +: `num_ports`]   ),  \
            .ing_cnts_clear             ( ing_cnts_clear[`index_start` +: `num_ports`]          ),  \
            .ing_cnts                   ( ing_cnts[`index_start` +: `num_ports`]                ),  \
            .ing_ports_connected        ( ing_ports_conneted[`index_start` +: `num_ports`]      )   \
        );

    // For each ingress physical port, convert data bus width to converged_bus width
    generate
        if (NUM_8B_ING_PHYS_PORTS) begin : array_adapt_8b
            `DEF_ING_PORT_ARRAY_ADAPT(NUM_8B_ING_PHYS_PORTS, ing_8b_phys_ports, INDEX_8B_START);
            // p4_router_ingress_port_array_adapt #(
            //     .NUM_ING_PHYS_PORTS         ( NUM_8B_ING_PHYS_PORTS     ),
            //     .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),
            //     .MTU_BYTES                  ( MTU_BYTES                 ),
            //     .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )
            // ) ingress_port_array_adapt_8b (
            //     .ing_phys_ports             ( ing_8b_phys_ports                                                 ),
            //     .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_8B_START+:NUM_8B_ING_PHYS_PORTS]     ),
            //     .ing_phys_ports_enable      ( ing_phys_ports_enable[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]    ),
            //     .ing_cnts_clear             ( ing_cnts_clear[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]           ),
            //     .ing_cnts                   ( ing_cnts[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]                 ),
            //     .ing_ports_connected        ( ing_ports_conneted[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]       )
            // );
        end

        if (NUM_16B_ING_PHYS_PORTS) begin : array_adapt_16b
            p4_router_ingress_port_array_adapt #(
                .NUM_ING_PHYS_PORTS         ( NUM_16B_ING_PHYS_PORTS    ),
                .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )
            ) ingress_port_array_adapt_16b (
                .ing_phys_ports             ( ing_16b_phys_ports ),
                .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_16B_START+:NUM_16B_ING_PHYS_PORTS]   ),
                .ing_phys_ports_enable      ( ing_phys_ports_enable[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]  ),
                .ing_cnts_clear             ( ing_cnts_clear[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]         ),
                .ing_cnts                   ( ing_cnts[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]               ),
                .ing_ports_connected        ( ing_ports_conneted[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]     )
            );
        end

        if (NUM_32B_ING_PHYS_PORTS) begin : array_adapt_32b
            p4_router_ingress_port_array_adapt #(
                .NUM_ING_PHYS_PORTS         ( NUM_32B_ING_PHYS_PORTS    ),
                .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )
            ) ingress_port_array_adapt_32b (
                .ing_phys_ports             ( ing_32b_phys_ports ),
                .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_32B_START+:NUM_32B_ING_PHYS_PORTS]   ),
                .ing_phys_ports_enable      ( ing_phys_ports_enable[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]  ),
                .ing_cnts_clear             ( ing_cnts_clear[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]         ),
                .ing_cnts                   ( ing_cnts[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]               ),
                .ing_ports_connected        ( ing_ports_conneted[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]     )
            );
        end

        if (NUM_64B_ING_PHYS_PORTS) begin : array_adapt_64b
            p4_router_ingress_port_array_adapt #(
                .NUM_ING_PHYS_PORTS         ( NUM_64B_ING_PHYS_PORTS    ),
                .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )
            ) ingress_port_array_adapt_64b (
                .ing_phys_ports             ( ing_64b_phys_ports ),
                .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_64B_START+:NUM_64B_ING_PHYS_PORTS]   ),
                .ing_phys_ports_enable      ( ing_phys_ports_enable[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]  ),
                .ing_cnts_clear             ( ing_cnts_clear[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]         ),
                .ing_cnts                   ( ing_cnts[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]               ),
                .ing_ports_connected        ( ing_ports_conneted[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]     )
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Merge AXIS to a single bus


    p4_router_ingress_buffer #(
        .NUM_ING_PHYS_PORTS     ( NUM_ING_PHYS_PORTS    ),
        .ING_BUF_DEPTH_PER_IFC  ( ING_BUF_DEPTH_PER_IFC ),
        .DEBUG_ILA              ( ING_BUF_DEBUG_ILA     ),
        .MTU_BYTES              ( MTU_BYTES             )
    ) ing_buf (
        .ing_phys_ports_adapted ( ing_phys_ports_adapted ),
        .ing_bus                ( ing_bus                ),
        .ing_buf_overflow       ( ing_buf_overflow       )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ingress Bus Packet Counter


    always_ff @( posedge ing_bus.clk ) begin
        if (!ing_bus.sresetn || ing_bus_pkt_cnt_clear) begin
            ing_bus_pkt_cnt <= '0;
        end else if (ing_bus.tvalid & ing_bus.tlast & ing_bus.tready & ~&ing_bus_pkt_cnt) begin
            ing_bus_pkt_cnt <= ing_bus_pkt_cnt + 1;
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: ILAs


    `ifndef MODEL_TECH
        generate
            for (genvar port=0; port<NUM_8B_ING_PHYS_PORTS; port++) begin : phys_port_ilas
                if (ING_8B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge ing_8b_phys_ports[port].clk) begin
                        if (!ing_8b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug ing_8b_port_ila (
                        .clk    ( ing_8b_phys_ports[port].clk       ),
                        .probe0 ( ing_8b_phys_ports[port].sresetn   ),
                        .probe1 ( ing_8b_phys_ports[port].tready    ),
                        .probe2 ( ing_8b_phys_ports[port].tvalid    ),
                        .probe3 ( ing_8b_phys_ports[port].tdata     ),
                        .probe4 ( ing_8b_phys_ports[port].tkeep     ),
                        .probe5 ( ing_8b_phys_ports[port].tlast     ),
                        .probe6 ( ing_phys_ports_adapted[INDEX_8B_START+port].tready     ),
                        .probe7 ( ing_phys_ports_adapted[INDEX_8B_START+port].tvalid     ),
                        .probe8 ( ing_phys_ports_adapted[INDEX_8B_START+port].tkeep      ),
                        .probe9 ( ing_phys_ports_adapted[INDEX_8B_START+port].tlast      ),
                        .probe10( dbg_cntr ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end

            for (genvar port=0; port<NUM_16B_ING_PHYS_PORTS; port++) begin
                if (ING_16B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge ing_16b_phys_ports[port].clk) begin
                        if (!ing_16b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug ing_16b_port_ila (
                        .clk    ( ing_16b_phys_ports[port].clk       ),
                        .probe0 ( ing_16b_phys_ports[port].sresetn   ),
                        .probe1 ( ing_16b_phys_ports[port].tready    ),
                        .probe2 ( ing_16b_phys_ports[port].tvalid    ),
                        .probe3 ( ing_16b_phys_ports[port].tdata     ),
                        .probe4 ( ing_16b_phys_ports[port].tkeep     ),
                        .probe5 ( ing_16b_phys_ports[port].tlast     ),
                        .probe6 ( ing_phys_ports_adapted[INDEX_16B_START+port].tready     ),
                        .probe7 ( ing_phys_ports_adapted[INDEX_16B_START+port].tvalid     ),
                        .probe8 ( ing_phys_ports_adapted[INDEX_16B_START+port].tkeep      ),
                        .probe9 ( ing_phys_ports_adapted[INDEX_16B_START+port].tlast      ),
                        .probe10( dbg_cntr ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end

            for (genvar port=0; port<NUM_32B_ING_PHYS_PORTS; port++) begin
                if (ING_32B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge ing_32b_phys_ports[port].clk) begin
                        if (!ing_32b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug ing_32b_port_ila (
                        .clk    ( ing_32b_phys_ports[port].clk       ),
                        .probe0 ( ing_32b_phys_ports[port].sresetn   ),
                        .probe1 ( ing_32b_phys_ports[port].tready    ),
                        .probe2 ( ing_32b_phys_ports[port].tvalid    ),
                        .probe3 ( ing_32b_phys_ports[port].tdata     ),
                        .probe4 ( ing_32b_phys_ports[port].tkeep     ),
                        .probe5 ( ing_32b_phys_ports[port].tlast     ),
                        .probe6 ( ing_phys_ports_adapted[INDEX_32B_START+port].tready     ),
                        .probe7 ( ing_phys_ports_adapted[INDEX_32B_START+port].tvalid     ),
                        .probe8 ( ing_phys_ports_adapted[INDEX_32B_START+port].tkeep      ),
                        .probe9 ( ing_phys_ports_adapted[INDEX_32B_START+port].tlast      ),
                        .probe10( dbg_cntr ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end
            for (genvar port=0; port<NUM_64B_ING_PHYS_PORTS; port++) begin
                if (ING_64B_PORT_DEBUG_ILA[port]) begin : gen_ila

                    logic [31:0] dbg_cntr;
                    always_ff @(posedge ing_64b_phys_ports[port].clk) begin
                        if (!ing_64b_phys_ports[port].sresetn) begin
                            dbg_cntr <= '0;
                        end else begin
                            dbg_cntr <= dbg_cntr + 1'b1;
                        end
                    end

                    ila_debug ing_64b_port_ila (
                        .clk    ( ing_64b_phys_ports[port].clk          ),
                        .probe0 ( ing_64b_phys_ports[port].sresetn      ),
                        .probe1 ( ing_64b_phys_ports[port].tready       ),
                        .probe2 ( ing_64b_phys_ports[port].tvalid       ),
                        .probe3 ( ing_64b_phys_ports[port].tdata[63:32] ),
                        .probe4 ( ing_64b_phys_ports[port].tdata[31:0]  ),
                        .probe5 ( ing_64b_phys_ports[port].tkeep        ),
                        .probe6 ( ing_64b_phys_ports[port].tlast        ),
                        .probe7 ( ing_phys_ports_adapted[INDEX_64B_START+port].tready ),
                        .probe8 ( ing_phys_ports_adapted[INDEX_64B_START+port].tvalid ),
                        .probe9 ( ing_phys_ports_adapted[INDEX_64B_START+port].tkeep  ),
                        .probe10( ing_phys_ports_adapted[INDEX_64B_START+port].tlast  ),
                        .probe11( dbg_cntr ),
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
