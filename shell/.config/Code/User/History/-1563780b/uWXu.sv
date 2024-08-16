// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Ingress subsystem for P4 router
 *  input arrays of AXIS interfaces grouped by data width
 *  p4_router_ingress_port_array_adapt performs CDC and width conversion
 *  ingress buffer aggregates words from the adapted interfaces into packets to send toward VNP4
 *
 * Notes:
 *  The purpose of this module is to aggregate packets from many narrow axis interfaces into a
 *  single wide axis interface without backpressuring the input interface, or overflowing buffers
 *  while using as little RAM as possible.
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_ingress #(
    parameter int NUM_8B_ING_PHYS_PORTS  = 0,
    parameter int NUM_16B_ING_PHYS_PORTS = 0,
    parameter int NUM_32B_ING_PHYS_PORTS = 0,
    parameter int NUM_64B_ING_PHYS_PORTS = 0,
    parameter int MTU_BYTES = 1500,
    parameter int ING_COUNTERS_WIDTH = 32,
    parameter int NUM_ING_PHYS_PORTS = NUM_64B_ING_PHYS_PORTS +
                                       NUM_32B_ING_PHYS_PORTS +
                                       NUM_16B_ING_PHYS_PORTS +
                                       NUM_8B_ING_PHYS_PORTS
)
(
    AXIS_int.Slave      ing_8b_phys_ports  [NUM_8B_ING_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Slave      ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0],

    AXIS_int.Master     ing_bus,

    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    output var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_async_fifo_overflow,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams



    localparam int MTU_WORDS = U_INT_CEIL_DIV(MTU_BYTES,ing_bus.DATA_BYTES);
    localparam int GUARD_BAND = 100;
    // Need to be able to hold MTU bytes since all of the words of a packet need to be pressent before the packet
    // can begin to be dispatched from the buffer. MTU_WORDS*(NUM_ING_PHYS_PORTS-1) would be the max number of cycles
    // a complete pacekt would need to wait before being scheduled (i.e. every other interface has to dispatch an MTU
    // before the interface of interest can start dispatching). Minimun cycles to add a word to the buffer would be
    // ing_bus.DATA_BYTES/8 (64-bit/8-byte interfaces would fill fastest) so
    // MTU_WORDS*(NUM_ING_PHYS_PORTS-1)/ing_bus.DATA_BYTES/8 + MTU_WORDS would be the requirement. Current design
    // requires power-of-two sized partitions and equally size partitions. Could create a patition offset map and
    // add the partition offset rather than concatinating ingress port number in order to get non-power-of-two,
    // and unequal sized partitions.

    localparam int BYTES_PER_64_BITS = 8;
    localparam int MAX_SCHED_WAIT_CYCLES = MTU_WORDS*(NUM_ING_PHYS_PORTS-1);
    localparam int MIN_CYCLES_TO_ADD_A_WORD = ing_bus.DATA_BYTES/BYTES_PER_64_BITS;
    localparam int MIN_ING_BUF_DEPTH_PER_IFC = MTU_WORDS + MAX_SCHED_WAIT_CYCLES/MIN_CYCLES_TO_ADD_A_WORD;
    localparam int ING_BUF_DEPTH_PER_IFC = 2**($clog2(MIN_ING_BUF_DEPTH_PER_IFC));

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_ING_PHYS_PORTS,
                                                                             NUM_32B_ING_PHYS_PORTS,
                                                                             NUM_16B_ING_PHYS_PORTS,
                                                                             NUM_8B_ING_PHYS_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_ING_PHYS_PORTS_PER_ARRAY);

    typedef int ing_port_index_map_t [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];

    function ing_port_index_map_t create_ing_port_index_map();
        automatic ing_port_index_map_t map = '{default: '{default: -1}};
        automatic int cnt = 0;
        for(int i=0; i<NUM_ING_AXIS_ARRAYS; i++) begin
            for(int j=0; j<NUM_ING_PHYS_PORTS_PER_ARRAY[i]; j++) begin
                map[i][j] = cnt;
                cnt++;
            end
        end
        return map;
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
    `ELAB_CHECK_EQUAL(NUM_ING_PHYS_PORTS, NUM_64B_ING_PHYS_PORTS +
                                          NUM_32B_ING_PHYS_PORTS +
                                          NUM_16B_ING_PHYS_PORTS +
                                          NUM_8B_ING_PHYS_PORTS);


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

    // For each ingress physical port, convert data bus width to converged_bus width and cdc to core clock through an async FIFO
    generate
        if (NUM_8B_ING_PHYS_PORTS) begin
            p4_router_ingress_port_array_adapt #(
                .NUM_ING_PHYS_PORTS         ( NUM_8B_ING_PHYS_PORTS     ),
                .CONVERGED_BUS_DATA_BYTES   ( ing_bus.DATA_BYTES        ),
                .MTU_BYTES                  ( MTU_BYTES                 ),
                .ING_COUNTERS_WIDTH         ( ING_COUNTERS_WIDTH        )
            ) ingress_port_array_adapt_8b (
                .ing_phys_ports             ( ing_8b_phys_ports ),
                .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_8B_START+:NUM_8B_ING_PHYS_PORTS]     ),
                .ing_phys_ports_enable      ( ing_phys_ports_enable[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]    ),
                .ing_cnts_clear             ( ing_cnts_clear[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]           ),
                .ing_cnts                   ( ing_cnts[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]                 ),
                .ing_ports_connected        ( ing_ports_conneted[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]       ),
                .ing_async_fifo_overflow    ( ing_async_fifo_overflow[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]  )
            );
        end

        if (NUM_16B_ING_PHYS_PORTS) begin
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
                .ing_ports_connected        ( ing_ports_conneted[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]     ),
                .ing_async_fifo_overflow    ( ing_async_fifo_overflow[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS])
            );
        end

        if (NUM_32B_ING_PHYS_PORTS) begin
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
                .ing_ports_connected        ( ing_ports_conneted[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]     ),
                .ing_async_fifo_overflow    ( ing_async_fifo_overflow[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS])
            );
        end

        if (NUM_64B_ING_PHYS_PORTS) begin
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
                .ing_ports_connected        ( ing_ports_conneted[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]     ),
                .ing_async_fifo_overflow    ( ing_async_fifo_overflow[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS])
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Merge AXIS to a single bus

    p4_router_ingress_buffer #(
        .NUM_ING_PHYS_PORTS     ( NUM_ING_PHYS_PORTS    ),
        .ING_BUF_DEPTH_PER_IFC  ( ING_BUF_DEPTH_PER_IFC )
    ) ing_buf (
        .ing_phys_ports_adapted ( ing_phys_ports_adapted ),
        .ing_bus                ( ing_bus                ),

        .ing_buf_overflow       ( ing_buf_overflow       )
    );


endmodule

`default_nettype wire
