// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Top level test bench for p4_router.sv
 * Intended to be used with a vnp4 instance that sets egress specifier to ingress port.
 */
module p4_router_top_tb ();


    parameter int NUM_8B_ING_PHYS_PORTS  = 0;
    parameter int NUM_16B_ING_PHYS_PORTS = 0;
    parameter int NUM_32B_ING_PHYS_PORTS = 0;
    parameter int NUM_64B_ING_PHYS_PORTS = 0;
    parameter int NUM_8B_EGR_PHYS_PORTS  = 0;
    parameter int NUM_16B_EGR_PHYS_PORTS = 0;
    parameter int NUM_32B_EGR_PHYS_PORTS = 0;
    parameter int NUM_64B_EGR_PHYS_PORTS = 0;

    parameter int AVMM_DATALEN = 32;
    parameter int AVMM_ADDRLEN = 16;

    parameter int MTU_BYTES             = 1500;
    parameter int PACKET_MAX_BLEN       = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN       = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND   = 100;


    /////////////////////////////////////////////////////////////////////////
    // Imports


    import P4_ROUTER_PKG::*;
    import P4_ROUTER_TB_PKG::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // Constants


    localparam PAYLOAD_TYPE = RAND;

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_AXIS_ARRAYS-1:0] = { NUM_64B_ING_PHYS_PORTS,
                                                                          NUM_32B_ING_PHYS_PORTS,
                                                                          NUM_16B_ING_PHYS_PORTS,
                                                                          NUM_8B_ING_PHYS_PORTS
                                                                        };

    localparam int MAX_NUM_ING_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_ING_PHYS_PORTS_PER_ARRAY);

    localparam int NUM_ING_PHYS_PORTS      = NUM_8B_ING_PHYS_PORTS + NUM_16B_ING_PHYS_PORTS + NUM_32B_ING_PHYS_PORTS + NUM_64B_ING_PHYS_PORTS;

    localparam port_index_map_t ING_PORT_INDEX_MAP = create_port_index_map(NUM_ING_PHYS_PORTS_PER_ARRAY);

    localparam ING_8B_START  = ING_PORT_INDEX_MAP[INDEX_8B][0];
    localparam ING_16B_START = ING_PORT_INDEX_MAP[INDEX_16B][0];
    localparam ING_32B_START = ING_PORT_INDEX_MAP[INDEX_32B][0];
    localparam ING_64B_START = ING_PORT_INDEX_MAP[INDEX_64B][0];

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_AXIS_ARRAYS-1:0] = { NUM_64B_EGR_PHYS_PORTS,
                                                                          NUM_32B_EGR_PHYS_PORTS,
                                                                          NUM_16B_EGR_PHYS_PORTS,
                                                                          NUM_8B_EGR_PHYS_PORTS
                                                                        };

    localparam int NUM_EGR_PHYS_PORTS      = NUM_8B_EGR_PHYS_PORTS
                                           + NUM_16B_EGR_PHYS_PORTS
                                           + NUM_32B_EGR_PHYS_PORTS
                                           + NUM_64B_EGR_PHYS_PORTS;

    localparam port_index_map_t EGR_PORT_INDEX_MAP = create_port_index_map(NUM_EGR_PHYS_PORTS_PER_ARRAY);

    localparam EGR_8B_START  = EGR_PORT_INDEX_MAP[INDEX_8B][0];
    localparam EGR_16B_START = EGR_PORT_INDEX_MAP[INDEX_16B][0];
    localparam EGR_32B_START = EGR_PORT_INDEX_MAP[INDEX_32B][0];
    localparam EGR_64B_START = EGR_PORT_INDEX_MAP[INDEX_64B][0];

    localparam int MAX_PKT_WLEN_8B  = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_8BIT_WORD);
    localparam int MAX_PKT_WLEN_16B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_16BIT_WORD);
    localparam int MAX_PKT_WLEN_32B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_32BIT_WORD);
    localparam int MAX_PKT_WLEN_64B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_64BIT_WORD);

    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int CDC_FIFO_DEPTH = 32;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    bit   [NUM_ING_PHYS_PORTS-1:0]          ing_phys_ports_enable;

    logic [0:MTU_BYTES*8-1]                 send_packet_data        [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_ING_PORTS_PER_ARRAY-1:0];
    int                                     send_packet_byte_length [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_ING_PORTS_PER_ARRAY-1:0];
    bit  [MAX_NUM_ING_PORTS_PER_ARRAY-1:0]  send_packet_req         [NUM_ING_AXIS_ARRAYS-1:0];
    bit  [MAX_NUM_ING_PORTS_PER_ARRAY-1:0]  send_packet_req_d       [NUM_ING_AXIS_ARRAYS-1:0];
    bit  [MAX_NUM_ING_PORTS_PER_ARRAY-1:0]  send_packet_busy        [NUM_ING_AXIS_ARRAYS-1:0];

    int                                     expected_count;
    int                                     received_count;

    bit   [NUM_ING_PHYS_PORTS-1:0]          ing_phys_ports_tlast;
    bit   [ING_COUNTERS_WIDTH-1:0]          expected_ing_cnts       [NUM_ING_PHYS_PORTS-1:0] [6:0];

    bit   [NUM_ING_PHYS_PORTS-1:0]          ing_async_fifo_overflow;

    logic [0:MTU_BYTES*8-1]                 tx_snoop_data_buf       [NUM_ING_PHYS_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]               tx_snoop_blen_buf       [NUM_ING_PHYS_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]       tx_snoop_wr_ptr         [NUM_ING_PHYS_PORTS-1:0];

    bit   [NUM_EGR_PHYS_PORTS-1:0]          egr_phys_ports_tlast;
    bit   [NUM_EGR_PHYS_PORTS-1:0]          egr_phys_ports_tvalid;

    bit  [EGR_COUNTERS_WIDTH-1:0]           expected_egr_cnts       [NUM_EGR_PHYS_PORTS-1:0] [6:0];

    bit  [NUM_8B_ING_PHYS_PORTS-1:0]        ing_8b_async_fifo_overflow  = '0;
    bit  [NUM_16B_ING_PHYS_PORTS-1:0]       ing_16b_async_fifo_overflow = '0;
    bit  [NUM_32B_ING_PHYS_PORTS-1:0]       ing_32b_async_fifo_overflow = '0;
    bit  [NUM_64B_ING_PHYS_PORTS-1:0]       ing_64b_async_fifo_overflow = '0;
    bit  [NUM_8B_ING_PHYS_PORTS-1:0]        egr_8b_async_fifo_overflow  = '0;
    bit  [NUM_16B_ING_PHYS_PORTS-1:0]       egr_16b_async_fifo_overflow = '0;
    bit  [NUM_32B_ING_PHYS_PORTS-1:0]       egr_32b_async_fifo_overflow = '0;
    bit  [NUM_64B_ING_PHYS_PORTS-1:0]       egr_64b_async_fifo_overflow = '0;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) avmm_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) peripheral_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) interconnect_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) phys_port_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) phys_port_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces


    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) ing_8b_phys_ports [NUM_8B_ING_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) ing_8b_phys_ports_cdc [NUM_8B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) ing_16b_phys_ports_cdc [NUM_16B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) ing_32b_phys_ports_cdc [NUM_32B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) ing_64b_phys_ports_cdc [NUM_64B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) egr_8b_phys_ports [NUM_8B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) egr_8b_phys_ports_cdc [NUM_8B_EGR_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk       ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) egr_16b_phys_ports_cdc [NUM_16B_EGR_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) egr_32b_phys_ports_cdc [NUM_32B_EGR_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) egr_64b_phys_ports_cdc [NUM_64B_EGR_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                          ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Interfaces


    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) p4_router_avmm ();

    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) vnp4_avmm ();


    //////////////////////////////////////////////////////////////////////////
    // Logic Implementation


    // simulation clock
    always #(AVMM_CLK_PERIOD/2)      avmm_clk_ifc.clk <= ~avmm_clk_ifc.clk;
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk <= ~core_clk_ifc.clk;
    always #(PHYS_PORT_CLK_PERIOD/2) phys_port_clk_ifc.clk <= ~phys_port_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Generators


    `define DEF_AXIS_ARRAY_PKT_GEN(WIDTH)                                                                                   \
        if (NUM_``WIDTH``B_ING_PHYS_PORTS) begin : packet_generator_``WIDTH``b_g                                            \
            axis_array_packet_generator #(                                                                                  \
                .NUM_PORTS          ( NUM_``WIDTH``B_ING_PHYS_PORTS     ),                                                  \
                .MTU_BYTES          ( MTU_BYTES                         )                                                   \
            ) packet_generator_``WIDTH``b (                                                                                 \
                .axis_packet_out    ( ing_``WIDTH``b_phys_ports                                                     ),      \
                .busy               ( send_packet_busy[INDEX_``WIDTH``B][NUM_``WIDTH``B_ING_PHYS_PORTS-1:0]         ),      \
                .send_packet_req    ( send_packet_req[INDEX_``WIDTH``B][NUM_``WIDTH``B_ING_PHYS_PORTS-1:0]          ),      \
                .packet_byte_length ( send_packet_byte_length[INDEX_``WIDTH``B][NUM_``WIDTH``B_ING_PHYS_PORTS-1:0]  ),      \
                .packet_user        ( '{default: '0}                                                                ),      \
                .packet_data        ( send_packet_data[INDEX_``WIDTH``B][NUM_``WIDTH``B_ING_PHYS_PORTS-1:0]         )       \
            );                                                                                                              \
        end

    generate
        `DEF_AXIS_ARRAY_PKT_GEN(8);
        `DEF_AXIS_ARRAY_PKT_GEN(16);
        `DEF_AXIS_ARRAY_PKT_GEN(32);
        `DEF_AXIS_ARRAY_PKT_GEN(64);
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Capture tx packets to use as expected packets for rx


    always_ff @(posedge phys_port_clk_ifc.clk ) begin
        if (phys_port_sreset_ifc.reset == phys_port_sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf  <= '{default: '{default: '0}};
            tx_snoop_blen_buf  <= '{default: '{default: '0}};
            tx_snoop_wr_ptr    <= '{default: '0};
            send_packet_req_d  <= '{default: '0};
        end else begin
            send_packet_req_d <= send_packet_req;
            for (int send_packet_port=0; send_packet_port<NUM_ING_PHYS_PORTS; send_packet_port++) begin
                automatic int width_index = get_port_width_index(send_packet_port, ING_PORT_INDEX_MAP);
                automatic int array_index = get_port_array_index(send_packet_port, ING_PORT_INDEX_MAP);
                if (send_packet_req[width_index][array_index] && !send_packet_req_d[width_index][array_index]) begin
                    tx_snoop_data_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_data[width_index][array_index];
                    tx_snoop_blen_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_byte_length[width_index][array_index];
                    tx_snoop_wr_ptr[send_packet_port]                                      <= tx_snoop_wr_ptr[send_packet_port] + 1;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Packet Counters


    generate
        for (genvar i=0; i<NUM_8B_ING_PHYS_PORTS; i++) begin : tlast_8b
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_8B][i]] = ing_8b_phys_ports_cdc[i].tready
                                                                         & ing_8b_phys_ports_cdc[i].tvalid
                                                                         & ing_8b_phys_ports_cdc[i].tlast;
        end
        for (genvar i=0; i<NUM_16B_ING_PHYS_PORTS; i++) begin : tlast_16b
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_16B][i]] = ing_16b_phys_ports_cdc[i].tready
                                                                          & ing_16b_phys_ports_cdc[i].tvalid
                                                                          & ing_16b_phys_ports_cdc[i].tlast;
        end
        for (genvar i=0; i<NUM_32B_ING_PHYS_PORTS; i++) begin : tlast_32b
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_32B][i]] = ing_32b_phys_ports_cdc[i].tready
                                                                          & ing_32b_phys_ports_cdc[i].tvalid
                                                                          & ing_32b_phys_ports_cdc[i].tlast;
        end
        for (genvar i=0; i<NUM_64B_ING_PHYS_PORTS; i++) begin : tlast_64b
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_64B][i]] = ing_64b_phys_ports_cdc[i].tready
                                                                          & ing_64b_phys_ports_cdc[i].tvalid
                                                                          & ing_64b_phys_ports_cdc[i].tlast;
        end
    endgenerate

    always_ff @(posedge phys_port_clk_ifc.clk) begin
        if (phys_port_sreset_ifc.reset == phys_port_sreset_ifc.ACTIVE_HIGH) begin
            expected_ing_cnts = '{default: '{default: '{default: '0}}};
        end else begin
            for (int port_index; port_index<NUM_ING_PHYS_PORTS; port_index++) begin
                if (ing_phys_ports_enable[port_index]) begin
                    expected_ing_cnts[port_index][AXIS_PROFILE_PKT_CNT_INDEX] += ing_phys_ports_tlast[port_index];
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT


    `define DEF_CDC_BUFS(WIDTH)                                                             \
        /* Ingress */                                                                                                       \
        for (genvar port_index=0; port_index<NUM_``WIDTH``B_ING_PHYS_PORTS; port_index++) begin : ing_cdc_``WIDTH``b        \
            axis_dist_ram_fifo #(                                                                                           \
                .DEPTH         ( CDC_FIFO_DEPTH ),                                                                          \
                .ASYNC_CLOCKS  ( 1'b1           )                                                                           \
            ) async_fifo (                                                                                                  \
                .axis_in           ( ing_``WIDTH``b_phys_ports[port_index]          ),                                      \
                .axis_out          ( ing_``WIDTH``b_phys_ports_cdc[port_index]      ),                                      \
                .axis_in_overflow  (                                                ),                                      \
                .axis_out_overflow ( ing_``WIDTH``b_async_fifo_overflow[port_index] )                                       \
            );                                                                                                              \
        end                                                                                                                 \
        /* Egress */                                                                                                        \
        for (genvar port_index=0; port_index<NUM_``WIDTH``B_EGR_PHYS_PORTS; port_index++) begin : egr_cdc_``WIDTH``b        \
            axis_async_fifo_wrapper async_fifo (                                                                            \
                .axis_in             ( egr_``WIDTH``b_phys_ports[port_index]          ),                                    \
                .axis_out            ( egr_``WIDTH``b_phys_ports_cdc[port_index]      ),                                    \
                .axis_in_overflow    ( egr_``WIDTH``b_async_fifo_overflow[port_index] ),                                    \
                .axis_in_bad_frame   (                                                ),                                    \
                .axis_in_good_frame  (                                                ),                                    \
                .axis_out_overflow   (                                                ),                                    \
                .axis_out_bad_frame  (                                                ),                                    \
                .axis_out_good_frame (                                                )                                     \
            );                                                                                                              \
        end

    // CDC
    generate
        `DEF_CDC_BUFS(8);
        `DEF_CDC_BUFS(16);
        `DEF_CDC_BUFS(32);
        `DEF_CDC_BUFS(64);
    endgenerate

    p4_router #(
        .MODULE_ID                      ( 0                                                     ),
        .NUM_8B_ING_PHYS_PORTS          ( NUM_8B_ING_PHYS_PORTS                                 ),
        .NUM_16B_ING_PHYS_PORTS         ( NUM_16B_ING_PHYS_PORTS                                ),
        .NUM_32B_ING_PHYS_PORTS         ( NUM_32B_ING_PHYS_PORTS                                ),
        .NUM_64B_ING_PHYS_PORTS         ( NUM_64B_ING_PHYS_PORTS                                ),
        .NUM_8B_EGR_PHYS_PORTS          ( NUM_8B_EGR_PHYS_PORTS                                 ),
        .NUM_16B_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS                                ),
        .NUM_32B_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS                                ),
        .NUM_64B_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS                                ),
        .VNP4_IP_SEL                    ( ECHO_PHYS_PORT                                        ),
        .VNP4_DATA_BYTES                ( P4_ROUTER_VNP4_ECHO_PHYS_PORT_PKG::TDATA_NUM_BYTES    ),
        .VNP4_AXI4LITE_DATALEN          ( P4_ROUTER_VNP4_ECHO_PHYS_PORT_PKG::S_AXI_DATA_WIDTH   ),
        .VNP4_AXI4LITE_ADDRLEN          ( P4_ROUTER_VNP4_ECHO_PHYS_PORT_PKG::S_AXI_ADDR_WIDTH   ),
        .CLOCK_PERIOD_NS                ( CORE_CLK_PERIOD                                       ),
        .MTU_BYTES                      ( MTU_BYTES                                             )
    ) dut (
        .core_clk_ifc             ( core_clk_ifc            ),
        .core_sreset_ifc          ( core_sreset_ifc         ),
        .cam_clk_ifc              ( core_clk_ifc            ),
        .cam_sreset_ifc           ( core_sreset_ifc         ),
        .avmm_clk_ifc             ( avmm_clk_ifc            ),
        .interconnect_sreset_ifc  ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc    ( peripheral_sreset_ifc   ),
        .vnp4_avmm                ( vnp4_avmm               ),
        .p4_router_avmm           ( p4_router_avmm          ),
        .ing_8b_phys_ports        ( ing_8b_phys_ports_cdc   ),
        .ing_16b_phys_ports       ( ing_16b_phys_ports_cdc  ),
        .ing_32b_phys_ports       ( ing_32b_phys_ports_cdc  ),
        .ing_64b_phys_ports       ( ing_64b_phys_ports_cdc  ),
        .egr_8b_phys_ports        ( egr_8b_phys_ports       ),
        .egr_16b_phys_ports       ( egr_16b_phys_ports      ),
        .egr_32b_phys_ports       ( egr_32b_phys_ports      ),
        .egr_64b_phys_ports       ( egr_64b_phys_ports      )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Receive Packet Counter


    // Modelsim didn't want to iterate over arrays of interfaces in an always_ff
    // pull tlast into a logic vector that Modelsim will allow iteraton over.
    generate
        for (genvar i=0; i<NUM_8B_EGR_PHYS_PORTS; i++) begin : egr_port_axis_sig_array_8b
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_8B][i]]  = egr_8b_phys_ports_cdc[i].tready
                                                                          & egr_8b_phys_ports_cdc[i].tvalid
                                                                          & egr_8b_phys_ports_cdc[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_8B][i]] = egr_8b_phys_ports_cdc[i].tready
                                                                          & egr_8b_phys_ports_cdc[i].tvalid
                                                                          & egr_8b_phys_ports_cdc[i].tvalid;
        end
        for (genvar i=0; i<NUM_16B_EGR_PHYS_PORTS; i++) begin : egr_port_axis_sig_array_16
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_16B][i]]  = egr_16b_phys_ports_cdc[i].tready
                                                                           & egr_16b_phys_ports_cdc[i].tvalid
                                                                           & egr_16b_phys_ports_cdc[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_16B][i]] = egr_16b_phys_ports_cdc[i].tready
                                                                           & egr_16b_phys_ports_cdc[i].tvalid
                                                                           & egr_16b_phys_ports_cdc[i].tvalid;
        end
        for (genvar i=0; i<NUM_32B_EGR_PHYS_PORTS; i++) begin : egr_port_axis_sig_array_32
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_32B][i]]  = egr_32b_phys_ports_cdc[i].tready
                                                                           & egr_32b_phys_ports_cdc[i].tvalid
                                                                           & egr_32b_phys_ports_cdc[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_32B][i]] = egr_32b_phys_ports_cdc[i].tready
                                                                           & egr_32b_phys_ports_cdc[i].tvalid
                                                                           & egr_32b_phys_ports_cdc[i].tvalid;
        end
        for (genvar i=0; i<NUM_64B_EGR_PHYS_PORTS; i++) begin : egr_port_axis_sig_array_64
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_64B][i]]  = egr_64b_phys_ports_cdc[i].tready
                                                                           & egr_64b_phys_ports_cdc[i].tvalid
                                                                           & egr_64b_phys_ports_cdc[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_64B][i]] = egr_64b_phys_ports_cdc[i].tready
                                                                           & egr_64b_phys_ports_cdc[i].tvalid
                                                                           & egr_64b_phys_ports_cdc[i].tvalid;
        end
    endgenerate

    always_ff @(posedge phys_port_clk_ifc.clk ) begin
        if (phys_port_sreset_ifc.reset == phys_port_sreset_ifc.ACTIVE_HIGH) begin
            received_count    <= 0;
            expected_egr_cnts <= '{default: '{default: '{default: '0}}};
        end else begin
            for (int port=0; port<NUM_EGR_PHYS_PORTS; port++) begin
                if (egr_phys_ports_tlast[port]) begin
                    received_count++;
                    expected_egr_cnts[port][AXIS_PROFILE_PKT_CNT_INDEX]++;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sink & Data Validation


    `define DEF_PKT_CHK(WIDTH)                                                                                  \
        if (NUM_``WIDTH``B_EGR_PHYS_PORTS) begin : packet_checker_``WIDTH``b_g                                  \
            axis_array_packet_checker #(                                                                        \
                .NUM_PORTS                         ( NUM_``WIDTH``B_EGR_PHYS_PORTS                       ),     \
                .MODULE_ID_STRING_0                ( "Width Index"                                       ),     \
                .MODULE_ID_VALUE_0                 ( INDEX_``WIDTH``B                                    ),     \
                .MODULE_ID_STRING_1                ( "Array Index"                                       ),     \
                .AXIS_PACKET_IN_DATA_BYTES         ( egr_``WIDTH``b_phys_ports_cdc[0].DATA_BYTES         ),     \
                .AXIS_PACKET_IN_USER_WIDTH         ( egr_``WIDTH``b_phys_ports_cdc[0].USER_WIDTH         ),     \
                .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( egr_``WIDTH``b_phys_ports_cdc[0].ALLOW_BACKPRESSURE ),     \
                .MTU_BYTES                         ( MTU_BYTES                                           ),     \
                .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND                                 )      \
            )  packet_checker_``WIDTH``b  (                                                                     \
                .axis_packet_in ( egr_``WIDTH``b_phys_ports_cdc                                             ),  \
                .num_tx_pkts    ( tx_snoop_wr_ptr[EGR_``WIDTH``B_START +: NUM_``WIDTH``B_EGR_PHYS_PORTS]    ),  \
                .expected_pkts  ( tx_snoop_data_buf[EGR_``WIDTH``B_START +: NUM_``WIDTH``B_EGR_PHYS_PORTS]  ),  \
                .expected_blens ( tx_snoop_blen_buf[EGR_``WIDTH``B_START +: NUM_``WIDTH``B_EGR_PHYS_PORTS]  ),  \
                .expected_dests ( '{default: '0}                                                            )   \
            );                                                                                                  \
        end

    generate
        `DEF_PKT_CHK(8);
        `DEF_PKT_CHK(16);
        `DEF_PKT_CHK(32);
        `DEF_PKT_CHK(64);
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Verify that there are no buffer overflows


    always_ff @( posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH) begin
            `CHECK_EQUAL(ing_8b_async_fifo_overflow  , 0);
            `CHECK_EQUAL(ing_16b_async_fifo_overflow , 0);
            `CHECK_EQUAL(ing_32b_async_fifo_overflow , 0);
            `CHECK_EQUAL(ing_64b_async_fifo_overflow , 0);
            `CHECK_EQUAL(egr_8b_async_fifo_overflow  , 0);
            `CHECK_EQUAL(egr_16b_async_fifo_overflow , 0);
            `CHECK_EQUAL(egr_32b_async_fifo_overflow , 0);
            `CHECK_EQUAL(egr_64b_async_fifo_overflow , 0);
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks


    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        automatic int port_width_index = get_port_width_index(send_packet_port, ING_PORT_INDEX_MAP);
        automatic int port_array_index = get_port_array_index(send_packet_port, ING_PORT_INDEX_MAP);

        // Wait till we can send data
        @(posedge phys_port_clk_ifc.clk && !send_packet_busy[port_width_index][port_array_index]);
        #1;

        send_packet_byte_length[port_width_index][port_array_index] = packet_byte_length;
        case (port_width_index)
            INDEX_8B:  begin
                axis_packet_formatter #(
                    BYTES_PER_8BIT_WORD,
                    MAX_PKT_WLEN_8B ,
                    MTU_BYTES
                )::get_packet(
                    PAYLOAD_TYPE,
                    packet_byte_length,
                    send_packet_data[INDEX_8B] [port_array_index]
                );
            end
            INDEX_16B: begin
                axis_packet_formatter #(
                    BYTES_PER_16BIT_WORD,
                    MAX_PKT_WLEN_16B,
                    MTU_BYTES
                )::get_packet(
                    PAYLOAD_TYPE,
                    packet_byte_length,
                    send_packet_data[INDEX_16B][port_array_index]
                );
            end
            INDEX_32B: begin
                axis_packet_formatter #(
                    BYTES_PER_32BIT_WORD,
                    MAX_PKT_WLEN_32B,
                    MTU_BYTES
                )::get_packet(
                    PAYLOAD_TYPE,
                    packet_byte_length,
                    send_packet_data[INDEX_32B][port_array_index]
                );
            end
            INDEX_64B: begin
                axis_packet_formatter #(
                    BYTES_PER_64BIT_WORD,
                    MAX_PKT_WLEN_64B,
                    MTU_BYTES
                )::get_packet(
                    PAYLOAD_TYPE,
                    packet_byte_length,
                    send_packet_data[INDEX_64B][port_array_index]
                );
            end
            default: ;
        endcase

        send_packet_req[port_width_index][port_array_index] = 1'b1;
        // Wait utill its received
        @(posedge phys_port_clk_ifc.clk);
        #1;
        send_packet_req[port_width_index][port_array_index] = 1'b0;

    end
    endtask;

    task automatic send_random_length_packet (
        input int send_packet_port
    );
    begin
        send_packet(send_packet_port, $urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN));
    end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk       = 1'b0;
            core_clk_ifc.clk       = 1'b0;
            phys_port_clk_ifc.clk  = 1'b0;
            send_packet_req        = '{default: '0};
        end

        `TEST_CASE_SETUP begin

            interconnect_sreset_ifc.reset   = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset     = peripheral_sreset_ifc.ACTIVE_HIGH;
            core_sreset_ifc.reset           = core_sreset_ifc.ACTIVE_HIGH;
            phys_port_sreset_ifc.reset      = phys_port_sreset_ifc.ACTIVE_HIGH;
            repeat (8) @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset   = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset     = ~peripheral_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset           = ~core_sreset_ifc.ACTIVE_HIGH;
            @(posedge phys_port_clk_ifc.clk);
            phys_port_sreset_ifc.reset      = ~phys_port_sreset_ifc.ACTIVE_HIGH;

        end

        // Send packets to all ports simultaneously
        `TEST_CASE("send_to_all_ports") begin
            automatic bit egress_active = 1'b1;

            expected_count = (NUM_PACKETS_TO_SEND / NUM_ING_PHYS_PORTS) * NUM_ING_PHYS_PORTS;

            // Send packets to all interfacess in parallel
            for (int phys_port_thread=0; phys_port_thread<NUM_ING_PHYS_PORTS; phys_port_thread++ ) begin
                automatic int phys_port = phys_port_thread;
                fork
                    begin
                        for(int packet=0; packet<(NUM_PACKETS_TO_SEND/NUM_ING_PHYS_PORTS); packet++) begin
                            send_random_length_packet(phys_port);
                        end
                    end
                join_none
            end
            wait fork;

            // Wait for packets to start egressing
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge phys_port_clk_ifc.clk);

            // wait for packets to exit the DUT
            while (egress_active) begin
                egress_active = 1'b0;
                for (int i=0; i<1024; i++) begin
                    @(posedge phys_port_clk_ifc.clk);
                    #1;
                    egress_active = egress_active | |egr_phys_ports_tvalid;
                end
            end

            // Check that expected equals received
            `CHECK_EQUAL(received_count, expected_count);
        end
    end

    `WATCHDOG(1ms);

endmodule
