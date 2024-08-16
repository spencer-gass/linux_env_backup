// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Ingress subsystem for P4 router
 *  input arrays of AXIS interfaces grouped by data width
 *  axis adapt to converged_bus width,
 *  axis async fifo per physical port,
 *  axis arb mux to converge input streams into a single wide AXIS interface toward VNP4
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none


module p4_router_ingress #(
    parameter int NUM_8B_ING_PHYS_PORTS  = 0,
    parameter int NUM_16B_ING_PHYS_PORTS = 0,
    parameter int NUM_32B_ING_PHYS_PORTS = 0,
    parameter int NUM_64B_ING_PHYS_PORTS = 0,
    parameter int MTU_BYTES = 9600,
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
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_full_drop
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int MTU_WORDS = MTU_BYTES/ing_bus.DATA_BYTES;
    localparam int MTU_WORDS_LOG = $clog2(MTU_WORDS);
    // localparam int ING_BUF_DEPTH_PER_IFC = MTU_WORDS*2;
    localparam int ING_BUF_DEPTH_PER_IFC = 4096/ing_bus.DATA_BYTES; // could make this a function of MTU. using a power of 2 for not to make pointer math simple for both data and attribute rams
    localparam int ING_BUF_DEPTH_PER_IFC_LOG = $clog2(ING_BUF_DEPTH_PER_IFC);
    localparam int ING_BUF_DEPTH = ING_BUF_DEPTH_PER_IFC * NUM_ING_PHYS_PORTS;

    localparam int MIN_PKT_WORDS = U_INT_CEIL_DIV(64, ing_bus.DATA_BYTES);

    localparam int NUM_PKTS_PER_IFC = U_INT_CEIL_DIV(ING_BUF_DEPTH_PER_IFC, MIN_PKT_WORDS);
    localparam int NUM_PKTS_PER_IFC_LOG = $clog2(NUM_PKTS_PER_IFC);
    localparam int ATR_BUF_WIDTH = MTU_WORDS_LOG+ing_bus.DATA_BYTES-1;
    localparam int ATR_BUF_DEPTH = NUM_PKTS_PER_IFC * NUM_ING_PHYS_PORTS;
    localparam int ATR_BUF_DEPTH_LOG = $clog2(ATR_BUF_DEPTH);

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

    AXIS_int #(
        .DATA_BYTES ( ing_bus.DATA_BYTES        ),
        .USER_WIDTH ( NUM_ING_PHYS_PORTS_LOG    )
    ) ing_phys_ports_tuser_index_insert [NUM_ING_PHYS_PORTS-1:0] (
        .clk     ( ing_bus.clk      ),
        .sresetn ( ing_bus.sresetn  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Per-Physical-Port Logic

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
                .ing_buf_full_drop          ( ing_buf_full_drop[INDEX_8B_START +: NUM_8B_ING_PHYS_PORTS]        )
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
                .ing_buf_full_drop          ( ing_buf_full_drop[INDEX_16B_START +: NUM_16B_ING_PHYS_PORTS]      )
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
                .ing_buf_full_drop          ( ing_buf_full_drop[INDEX_32B_START +: NUM_32B_ING_PHYS_PORTS]      )
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
                .ing_buf_full_drop          ( ing_buf_full_drop[INDEX_64B_START +: NUM_64B_ING_PHYS_PORTS]      )
            );
        end
    endgenerate

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

    // axis_arb_mux_wrapper #(
    //     .N(NUM_ING_PHYS_PORTS),
    //     .ARB_TYPE("ROUND_ROBIN")
    // ) ingress_scheduler (
    //     .axis_in        ( ing_phys_ports_tuser_index_insert ),
    //     .axis_out       ( ing_bus                           ),
    //     .grant          (),
    //     .grant_valid    (),
    //     .grant_encoded  ()
    // );

    logic [NUM_ING_PHYS_PORTS_LOG-1:0] wr_if_sel;
    (* ram_style = "ultra" *)       logic [ing_bus.DATA_BYTES*8-1:0] ing_buf [ING_BUF_DEPTH-1:0];
    (* ram_style = "distributed" *) logic [ATR_BUF_WIDTH-1:0] atr_buf [ATR_BUF_DEPTH-1:0];
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_wr_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_wr_ptr [NUM_ING_PHYS_PORTS-1:0];

    logic [NUM_ING_PHYS_PORTS-1:0]   tvalid;
    logic [ing_bus.DATA_BYTES*8-1:0] tdata [NUM_ING_PHYS_PORTS-1:0];
    logic [ing_bus.DATA_BYTES-1:0]   tkeep [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_ING_PHYS_PORTS-1:0]   tlast;

    for (genvar ifc=0; ifc<NUM_ING_PHYS_PORTS; ifc++) begin
        assign ing_phys_ports_tuser_index_insert[ifc].tready = wr_if_sel == ifc ? 1'b1 : 1'b0;
        assign tvalid[ifc] = ing_phys_ports_tuser_index_insert[ifc].tvalid;
        assign tdata[ifc]  = ing_phys_ports_tuser_index_insert[ifc].tdata;
        assign tkeep[ifc]  = ing_phys_ports_tuser_index_insert[ifc].tkeep;
        assign tlast[ifc]  = ing_phys_ports_tuser_index_insert[ifc].tlast;
    end

    always_ff @(posedge ing_bus.clk ) begin : ing_buf_wr
        if (~ing_bus.sresetn) begin
            wr_if_sel <= '0;
            ing_wr_ptr <= '{default: '0};
            atr_wr_ptr <= '{default: '0};
        end else begin
            // Round-Robbin for now. could create an access pattern that hits wider interfaces more often to use the bus more efficiently
            if (wr_if_sel == NUM_ING_PHYS_PORTS) begin
                wr_if_sel <= '0;
            end else begin
                wr_if_sel <= wr_if_sel + 1;
            end
            if (tvalid[wr_if_sel]) begin
                ing_buf[{wr_if_sel, ing_wr_ptr[wr_if_sel]}] <= tdata[wr_if_sel];
                ing_wr_ptr[wr_if_sel] <= ing_wr_ptr[wr_if_sel] + 1;
                if (tlast[wr_if_sel]) begin
                    atr_buf[{wr_if_sel, atr_wr_ptr[wr_if_sel]}] <= {ing_wr_ptr[wr_if_sel], tkeep[wr_if_sel]};
                    atr_wr_ptr[wr_if_sel] <= atr_wr_ptr[wr_if_sel] + 1;
                end
            end
        end
    end

    logic [NUM_ING_PHYS_PORTS_LOG-1:0] rd_if_sel;

    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] last_word;
    logic [ATR_BUF_WIDTH-1:0]        atr_rd;
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_rd_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_rd_ptr [NUM_ING_PHYS_PORTS-1:0];

    assign atr_rd       = atr_buf[{rd_if_sel, atr_rd_ptr[rd_if_sel]}];
    assign last_word    = atr_rd[ing_bus.DATA_BYTES +: ING_BUF_DEPTH_PER_IFC_LOG];

    always_ff @(posedge ing_bus.clk) begin : ing_buf_rd
        if (~ing_bus.sresetn) begin
            rd_if_sel <= '0;
            ing_rd_ptr <= '{default: '0};
            atr_rd_ptr <= '{default: '0};
            ing_bus.tvalid <= 1'b0;
            ing_bus.tlast  <= 1'b0;
        end else begin
            // Round-Robbin for now. could create an access pattern that hits wider interfaces more often to use the bus more efficiently
            ing_bus.tvalid <= 1'b0;
            ing_bus.tlast <= 1'b0;
            ing_bus.tkeep <= '1;
            if (atr_rd_ptr[rd_if_sel] == atr_wr_ptr[rd_if_sel]) begin
                if (rd_if_sel == NUM_ING_PHYS_PORTS-1) begin
                    rd_if_sel <= '0;
                end else begin
                    rd_if_sel <= rd_if_sel + 1;
                end
            end else begin
                ing_bus.tvalid <= 1'b1;
                ing_bus.tdata  <= ing_buf[{rd_if_sel, ing_rd_ptr[rd_if_sel]}];
                ing_rd_ptr[rd_if_sel] <= ing_rd_ptr[rd_if_sel] + 1;
                if (ing_rd_ptr[rd_if_sel] == last_word) begin
                    ing_bus.tlast <= 1'b1;
                    ing_bus.tkeep <= atr_rd[ing_bus.DATA_BYTES-1:0];
                    atr_rd_ptr[rd_if_sel] <= atr_rd_ptr[rd_if_sel] + 1;
                end else begin

                end
            end
        end
    end

    assign ing_bus.tstrb = '1;
    assign ing_bus.tid   = '0;
    assign ing_bus.tdest = '0;
    assign ing_bus.tuser = rd_if_sel;

endmodule

`default_nettype wire
