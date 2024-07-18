// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Ingress subsystem for MPLS router
  * Version 1 -
  *     axis adapt, axis async fifo, axis arb mux
  *     Quick and simple.
  *     some loss to ineffiecient byte packing on wide fifo
  *     maybe able to save RAM by grouping low rate interfaces into a single buffer
  *     could be other area and throughput efficiencies to be gained from a more custom solution
  *     this should be pretty close to area and performance that we need though
  * Potential Improvements
  *     shallow async word fifos for CDC
  *     extra port mux stage that groups low rate interfaces together by mergin outputs of the shallow fifos and creating N AXIS with width F that is a factor of VNP4 bus width
  *     schedule words from the per-physical-port fifos to N parallel memories where each memory is F wide and N*F=VNP4_data_width.
  *     each physical port has an offset into the segmented wide memory
  *     this RAM would operate on packets rather than words
  *     schedule packets out of the segmented wide ram toward VNP4
  *     Need to think through the details of how to schedule simply while maintaining full utilization in congested state. may need to do a bit of rotating and re-aranging
  */

module mpls_ingress #(
    parameter int NUM_8B_ING_PHYS_PORTS  = 1,
    parameter int NUM_16B_ING_PHYS_PORTS = 1,
    parameter int NUM_32B_ING_PHYS_PORTS = 1,
    parameter int NUM_64B_ING_PHYS_PORTS = 1,
    parameter int MTU_BYTES = 9600 // get input on MTU requirement and move this to a package
)(
    Clock_int.Output    clk_ifc,
    Reset_int.ResetOut  sreset_ifc,

    AXIS_int.Slave      ing_8b_phys_ports  [NUM_8B_ING_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Slave      ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0],

    AXIS_int.Master     converged_ing_bus,

    output var logic [NUM_8B_ING_PHYS_PORTS-1:0]  ing_8b_buf_overflow,
    output var logic [NUM_16B_ING_PHYS_PORTS-1:0] ing_16b_buf_overflow,
    output var logic [NUM_32B_ING_PHYS_PORTS-1:0] ing_32b_buf_overflow,
    output var logic [NUM_64B_ING_PHYS_PORTS-1:0] ing_64b_buf_overflow
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    enum {
        ING_8B_INDEX,
        ING_16B_INDEX,
        ING_32B_INDEX,
        ING_64B_INDEX,
        NUM_ING_AXIS_ARRAYS
    } port_width_indecies;

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_ING_PHYS_PORTS,
                                                                             NUM_32B_ING_PHYS_PORTS,
                                                                             NUM_16B_ING_PHYS_PORTS,
                                                                             NUM_8B_ING_PHYS_PORTS
                                                                          };

    function int get_max_num_ports_per_array();
        automatic int max = 0;
        for (int i=0; i<NUM_ING_AXIS_ARRAYS; i++) begin
            if (NUM_ING_PHYS_PORTS_PER_ARRAY[i] > max) begin
                max = NUM_ING_PHYS_PORTS_PER_ARRAY[i];
            end
        end
        return max;
    endfunction

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array();

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

    localparam NUM_ING_PHYS_PORTS = {NUM_64B_ING_PHYS_PORTS +
                                     NUM_32B_ING_PHYS_PORTS +
                                     NUM_16B_ING_PHYS_PORTS +
                                     NUM_8B_ING_PHYS_PORTS};

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);

    localparam ing_port_index_map_t ING_PORT_INDEX_MAP = create_ing_port_index_map();
    localparam INDEX_8B_START  = ING_PORT_INDEX_MAP[ING_8B_INDEX][0];
    localparam INDEX_16B_START = ING_PORT_INDEX_MAP[ING_16B_INDEX][0];
    localparam INDEX_32B_START = ING_PORT_INDEX_MAP[ING_32B_INDEX][0];
    localparam INDEX_64B_START = ING_PORT_INDEX_MAP[ING_64B_INDEX][0];

    // localparam INDEX_8B_START  = 0;
    // localparam INDEX_16B_START = 3;
    // localparam INDEX_32B_START = 6;
    // localparam INDEX_64B_START = 9;

    initial begin
        for (int i=0; i<NUM_ING_AXIS_ARRAYS; i++) begin
            $display("%d", NUM_ING_PHYS_PORTS_PER_ARRAY[i]);
        end
        $display("%d %d %d", ING_PORT_INDEX_MAP[ING_8B_INDEX][0],  ING_PORT_INDEX_MAP[ING_8B_INDEX][1],  ING_PORT_INDEX_MAP[ING_8B_INDEX][2]);
        $display("%d %d %d", ING_PORT_INDEX_MAP[ING_16B_INDEX][0], ING_PORT_INDEX_MAP[ING_16B_INDEX][1], ING_PORT_INDEX_MAP[ING_16B_INDEX][2]);
        $display("%d %d %d", ING_PORT_INDEX_MAP[ING_32B_INDEX][0], ING_PORT_INDEX_MAP[ING_32B_INDEX][1], ING_PORT_INDEX_MAP[ING_32B_INDEX][2]);
        $display("%d %d %d", ING_PORT_INDEX_MAP[ING_64B_INDEX][0], ING_PORT_INDEX_MAP[ING_64B_INDEX][1], ING_PORT_INDEX_MAP[ING_64B_INDEX][2]);
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GE(converged_ing_bus.USER_WIDTH, NUM_ING_PHYS_PORTS_LOG); // physical port index is conveyed through tuser
    `ELAB_CHECK_GE(converged_ing_bus.DATA_BYTES, 8) // wide output bus needs to be at least as wide as the widest input bus
    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    AXIS_int #(
        .DATA_BYTES ( converged_ing_bus.DATA_BYTES  )
    ) ing_phys_ports_adapted [NUM_ING_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk      ),
        .sresetn ( sreset_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( converged_ing_bus.DATA_BYTES  ),
        .USER_WIDTH ( NUM_ING_PHYS_PORTS_LOG        )
    ) ing_phys_ports_tuser_index_insert [NUM_ING_PHYS_PORTS-1:0] (
        .clk     ( clk_ifc.clk      ),
        .sresetn ( sreset_ifc.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Per-Physical-Port Logic

    // For each ingress physical port, convert data bus width to converged_bus width and cdc to core clock
    mpls_ingress_port_array_adapt #(
        .NUM_ING_PHYS_PORTS         ( NUM_8B_ING_PHYS_PORTS         ),
        .CONVERGED_BUS_DATA_BYTES   ( converged_ing_bus.DATA_BYTES  ),
        .MTU_BYTES                  ( MTU_BYTES                     )
    ) ingress_port_array_adapt_8b (
        .ing_phys_ports             ( ing_8b_phys_ports ),
        .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_8B_START+:NUM_8B_ING_PHYS_PORTS] ),
        .ing_buf_overflow           ( ing_8b_buf_overflow )
    );

    mpls_ingress_port_array_adapt #(
        .NUM_ING_PHYS_PORTS         ( NUM_16B_ING_PHYS_PORTS         ),
        .CONVERGED_BUS_DATA_BYTES   ( converged_ing_bus.DATA_BYTES  ),
        .MTU_BYTES                  ( MTU_BYTES                     )
    ) ingress_port_array_adapt_16b (
        .ing_phys_ports             ( ing_16b_phys_ports ),
        .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_16B_START+:NUM_16B_ING_PHYS_PORTS] ),
        .ing_buf_overflow           ( ing_16b_buf_overflow )
    );

    mpls_ingress_port_array_adapt #(
        .NUM_ING_PHYS_PORTS         ( NUM_32B_ING_PHYS_PORTS         ),
        .CONVERGED_BUS_DATA_BYTES   ( converged_ing_bus.DATA_BYTES  ),
        .MTU_BYTES                  ( MTU_BYTES                     )
    ) ingress_port_array_adapt_32b (
        .ing_phys_ports             ( ing_32b_phys_ports ),
        .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_32B_START+:NUM_32B_ING_PHYS_PORTS] ),
        .ing_buf_overflow           ( ing_32b_buf_overflow )
    );

    mpls_ingress_port_array_adapt #(
        .NUM_ING_PHYS_PORTS         ( NUM_64B_ING_PHYS_PORTS         ),
        .CONVERGED_BUS_DATA_BYTES   ( converged_ing_bus.DATA_BYTES  ),
        .MTU_BYTES                  ( MTU_BYTES                     )
    ) ingress_port_array_adapt_64b (
        .ing_phys_ports             ( ing_64b_phys_ports ),
        .ing_phys_ports_adapted     ( ing_phys_ports_adapted[INDEX_64B_START+:NUM_64B_ING_PHYS_PORTS] ),
        .ing_buf_overflow           ( ing_64b_buf_overflow )
    );

    // Insert physical port index into tuser
    generate
        for (genvar port_index=0; port_index<NUM_ING_PHYS_PORTS; port_index++) begin : insert_phys_port_index_g
            always_comb begin
                ing_phys_ports_tuser_index_insert[port_index].tvalid = ing_phys_ports_adapted[port_index].tvalid;
                ing_phys_ports_adapted[port_index].tready            = ing_phys_ports_tuser_index_insert[port_index].tready;
                ing_phys_ports_tuser_index_insert[port_index].tdata  = ing_phys_ports_adapted[port_index].tdata;
                ing_phys_ports_tuser_index_insert[port_index].tstrb  = ing_phys_ports_adapted[port_index].tstrb;
                ing_phys_ports_tuser_index_insert[port_index].tkeep  = ing_phys_ports_adapted[port_index].tkeep;
                ing_phys_ports_tuser_index_insert[port_index].tlast  = ing_phys_ports_adapted[port_index].tlast;
                ing_phys_ports_tuser_index_insert[port_index].tid    = ing_phys_ports_adapted[port_index].tid;
                ing_phys_ports_tuser_index_insert[port_index].tdest  = ing_phys_ports_adapted[port_index].tdest;
                ing_phys_ports_tuser_index_insert[port_index].tuser  = port_index;
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Merge AXIS to a single bus

    axis_arb_mux_wrapper #(
        .N(NUM_ING_PHYS_PORTS),
        .ARB_TYPE("ROUND_ROBIN")
    ) ingress_scheduler (
        .axis_in        ( ing_phys_ports_tuser_index_insert ),
        .axis_out       ( converged_ing_bus                 ),
        .grant          (),
        .grant_valid    (),
        .grant_encoded  ()
    );


endmodule

`default_nettype wire

