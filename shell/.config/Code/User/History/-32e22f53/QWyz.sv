// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for p4_router_ingress.
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps


module p4_router_ingress_tb ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int NUM_8B_PORTS  = 3;               // Number of 8-bit  physical ports to the DUT
    parameter int NUM_16B_PORTS = 0;               // Number of 16-bit physical ports to the DUT
    parameter int NUM_32B_PORTS = 3;               // Number of 32-bit physical ports to the DUT
    parameter int NUM_64B_PORTS = 0;               // Number of 640bit physical ports to the DUT
    parameter int CONVERGED_AXIS_DATA_BYTES = 8;   // Width of axis bus toward VNP4
    parameter int MTU_BYTES = 1500;                // MTU for the router
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;
    parameter int ING_COUNTERS_WIDTH = 32;

    localparam RAND = 0;
    localparam INC = 1;
    localparam PAYLOAD_TYPE = RAND;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam real ING_PORT_CLK_PERIOD = 6.4;
    localparam real AXIS_CLK_PERIOD = 3.333;

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_PORTS,
                                                                             NUM_32B_PORTS,
                                                                             NUM_16B_PORTS,
                                                                             NUM_8B_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_ING_PHYS_PORTS_PER_ARRAY);

    localparam int NUM_PORTS      = NUM_8B_PORTS + NUM_16B_PORTS + NUM_32B_PORTS + NUM_64B_PORTS;
    localparam int NUM_PORTS_LOG  = $clog2(NUM_PORTS);

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

    localparam ing_port_index_map_t ING_PORT_INDEX_MAP = create_ing_port_index_map();
    localparam INDEX_8B_START  = ING_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_16B_START = ING_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_32B_START = ING_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_64B_START = ING_PORT_INDEX_MAP[INDEX_64B][0];

    enum {
        WIDTH_INDEX_CMD,
        ARRAY_INDEX_CMD
    } INDEX_CONV_CMDS;

    function int _get_port_width_or_array_index(
        input int port_index,
        input logic cmd
    );
        for (int width_index=0; width_index<NUM_ING_AXIS_ARRAYS; width_index++) begin
            for (int array_index=0; array_index<MAX_NUM_PORTS_PER_ARRAY; array_index++) begin
                if (ING_PORT_INDEX_MAP[width_index][array_index] == port_index) begin
                    case (cmd)
                        WIDTH_INDEX_CMD: return width_index;
                        ARRAY_INDEX_CMD: return array_index;
                        default: return -1;
                    endcase
                end
            end
        end
    endfunction

    function int get_port_width_index(input int port_index);
        return _get_port_width_or_array_index(port_index, WIDTH_INDEX_CMD);
    endfunction

    function int get_port_array_index(input int port_index);
        return _get_port_width_or_array_index(port_index, ARRAY_INDEX_CMD);
    endfunction

    localparam int MAX_PKT_WLEN_8B  = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_8BIT_WORD);
    localparam int MAX_PKT_WLEN_16B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_16BIT_WORD);
    localparam int MAX_PKT_WLEN_32B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_32BIT_WORD);
    localparam int MAX_PKT_WLEN_64B = U_INT_CEIL_DIV(MTU_BYTES,BYTES_PER_64BIT_WORD);

    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);

    localparam int FRAME_COUNT_INDEX = 5;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_PORTS-1:0]           ing_phys_ports_enable;
    logic [NUM_PORTS-1:0]           ing_cnts_clear;
    logic [ING_COUNTERS_WIDTH-1:0]  ing_cnts [NUM_PORTS-1:0] [6:0];
    logic [NUM_PORTS-1:0]           ing_ports_conneted;

    logic [7:0]                     send_packet_data_8      [NUM_8B_PORTS-1:0]  [MAX_PKT_WLEN_8B-1:0];
    logic [15:0]                    send_packet_data_16     [NUM_16B_PORTS-1:0] [MAX_PKT_WLEN_16B-1:0];
    logic [31:0]                    send_packet_data_32     [NUM_32B_PORTS-1:0] [MAX_PKT_WLEN_32B-1:0];
    logic [63:0]                    send_packet_data_64     [NUM_64B_PORTS-1:0] [MAX_PKT_WLEN_64B-1:0];
    logic [MTU_BYTES*8-1:0]         send_packet_vec         [NUM_PORTS-1:0];

    logic [MTU_BYTES_LOG-1:0]           send_packet_byte_length [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_req         [NUM_ING_AXIS_ARRAYS-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_req_d       [NUM_ING_AXIS_ARRAYS-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_busy        [NUM_ING_AXIS_ARRAYS-1:0];

    int expected_count;
    int received_count;

    logic [NUM_PORTS-1:0]          ing_phys_ports_tlast;
    logic [ING_COUNTERS_WIDTH-1:0] expected_ing_cnts [NUM_PORTS-1:0] [6:0];

    logic [NUM_PORTS-1:0]  ing_async_fifo_overflow;
    logic [NUM_PORTS-1:0]  ing_buf_overflow;

    logic [MTU_BYTES*8-1:0]             tx_snoop_data_buf   [NUM_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf   [NUM_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG-1:0] tx_snoop_wr_ptr     [NUM_PORTS-1:0];

    logic [NUM_PACKETS_TO_SEND-1:0] packet_received [NUM_PORTS-1:0];
    logic [MTU_BYTES*8-1:0]         rx_packet_buf;
    logic [MTU_BYTES*8-1:0]         rx_packet;
    int                             rx_wcnt;
    int                             rx_blen;
    int                             rx_ing_port;
    logic                           rx_validate;

    /////////////////////////////////////////////////////////////////////////
    // Internal Axis definitions

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) ing_8b_phys_ports [NUM_8B_PORTS-1:0] (
        .clk     (ing_port_clk_ifc.clk                                          ),
        .sresetn (ing_port_sreset_ifc.reset != ing_port_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) ing_16b_phys_ports [NUM_16B_PORTS-1:0] (
        .clk     (ing_port_clk_ifc.clk                                          ),
        .sresetn (ing_port_sreset_ifc.reset != ing_port_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) ing_32b_phys_ports [NUM_32B_PORTS-1:0] (
        .clk     (ing_port_clk_ifc.clk                                          ),
        .sresetn (ing_port_sreset_ifc.reset != ing_port_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) ing_64b_phys_ports [NUM_64B_PORTS-1:0] (
        .clk     (ing_port_clk_ifc.clk                                          ),
        .sresetn (ing_port_sreset_ifc.reset != ing_port_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( CONVERGED_AXIS_DATA_BYTES ),
        .USER_WIDTH ( NUM_PORTS_LOG             )
    ) ing_bus (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) ing_port_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) ing_port_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic implemenatation

    // Simulation clocks
    always #(ING_PORT_CLK_PERIOD/2) ing_port_clk_ifc.clk <= ~ing_port_clk_ifc.clk;
    always #(AXIS_CLK_PERIOD/2)     core_clk_ifc.clk     <= ~core_clk_ifc.clk;

    // Packet generators
    generate
        if (NUM_8B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_8B_PORTS              ),
                .AXIS_DATA_BYTES    ( BYTES_PER_8BIT_WORD       ),
                .MTU_BYTES          ( MTU_BYTES                 )
            ) pkt_gen_8b (
                .axis_out           ( ing_8b_phys_ports                                 ),
                .busy               ( send_packet_busy[INDEX_8B][NUM_8B_PORTS-1:0]      ),
                .send_req           ( send_packet_req[INDEX_8B][NUM_8B_PORTS-1:0]       ),
                .packet_byte_length ( send_packet_byte_length[INDEX_8B][NUM_8B_PORTS-1:0]),
                .packet_data        ( send_packet_data_8                                )
            );
        end

        if (NUM_16B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_16B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_16BIT_WORD      ),
                .MTU_BYTES          ( MTU_BYTES                 )
            ) pkt_gen_16b (
                .axis_out           ( ing_16b_phys_ports                                    ),
                .busy               ( send_packet_busy[INDEX_16B][NUM_16B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[INDEX_16B][NUM_16B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[INDEX_16B][NUM_16B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_16                                   )
            );
        end

        if (NUM_32B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_32B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_32BIT_WORD      ),
                .MTU_BYTES          ( MTU_BYTES                 )
            ) pkt_gen_32b (
                .axis_out           ( ing_32b_phys_ports                                    ),
                .busy               ( send_packet_busy[INDEX_32B][NUM_32B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[INDEX_32B][NUM_32B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[INDEX_32B][NUM_32B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_32                                   )
            );
        end

        if (NUM_64B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_64B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_64BIT_WORD      ),
                .MTU_BYTES          ( MTU_BYTES                 )
            ) pkt_gen_64b (
                .axis_out           ( ing_64b_phys_ports                                    ),
                .busy               ( send_packet_busy[INDEX_64B][NUM_64B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[INDEX_64B][NUM_64B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[INDEX_64B][NUM_64B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_64                                   )
            );
        end
    endgenerate

    // DUT
    p4_router_ingress #(
        .NUM_8B_ING_PHYS_PORTS  ( NUM_8B_PORTS          ),
        .NUM_16B_ING_PHYS_PORTS ( NUM_16B_PORTS         ),
        .NUM_32B_ING_PHYS_PORTS ( NUM_32B_PORTS         ),
        .NUM_64B_ING_PHYS_PORTS ( NUM_64B_PORTS         ),
        .MTU_BYTES              ( MTU_BYTES             ),
        .ING_COUNTERS_WIDTH     ( ING_COUNTERS_WIDTH    )
    ) DUT (
        .ing_8b_phys_ports          ( ing_8b_phys_ports         ),
        .ing_16b_phys_ports         ( ing_16b_phys_ports        ),
        .ing_32b_phys_ports         ( ing_32b_phys_ports        ),
        .ing_64b_phys_ports         ( ing_64b_phys_ports        ),
        .ing_bus                    ( ing_bus                   ),
        .ing_phys_ports_enable      ( ing_phys_ports_enable     ),
        .ing_cnts_clear             ( ing_cnts_clear            ),
        .ing_cnts                   ( ing_cnts                  ),
        .ing_ports_conneted         ( ing_ports_conneted        ),
        .ing_async_fifo_overflow    ( ing_async_fifo_overflow   ),
        .ing_buf_overflow           ( ing_buf_overflow          )
    );


    // Packet sink
    AXIS_sink #(
        .DATA_BYTES  ( ing_bus.DATA_BYTES ),
        .ID_WIDTH    ( ing_bus.ID_WIDTH   ),
        .DEST_WIDTH  ( ing_bus.DEST_WIDTH ),
        .USER_WIDTH  ( ing_bus.USER_WIDTH ),
        .ASSIGN_DELAY(1)
    ) axis_converged_bus_sink (
        .clk    ( ing_bus.clk     ),
        .sresetn( ing_bus.sresetn )
    );

    AXIS_sink_module axis_test_sink_module (
        .control( axis_converged_bus_sink ),
        .i      ( ing_bus                 )
    );

    always begin
        while (1) axis_converged_bus_sink.accept_wait;
    end

    // Capture tx packets to use as expected packets for rx
    always_ff @(posedge ing_port_clk_ifc.clk ) begin
        if (ing_port_sreset_ifc.reset == ing_port_sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf  <= '{default: '{default: '0}};
            tx_snoop_blen_buf  <= '{default: '{default: '0}};
            tx_snoop_wr_ptr    <= '{default: '0};
            send_packet_req_d  <= '{default: '0};
        end else begin
            send_packet_req_d <= send_packet_req;
            for (int send_packet_port=0; send_packet_port<NUM_PORTS; send_packet_port++) begin
                if (send_packet_req[get_port_width_index(send_packet_port)][get_port_array_index(send_packet_port)] && ! send_packet_req_d[get_port_width_index(send_packet_port)][get_port_array_index(send_packet_port)]) begin
                    tx_snoop_data_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_vec[send_packet_port];
                    tx_snoop_blen_buf[send_packet_port][tx_snoop_wr_ptr[send_packet_port]] <= send_packet_byte_length[get_port_width_index(send_packet_port)][get_port_array_index(send_packet_port)];
                    tx_snoop_wr_ptr[send_packet_port] <= tx_snoop_wr_ptr[send_packet_port] + 1;
                end
            end
        end
    end

    // Compare rx packets to captured tx packets
    function int tkeep_to_bytes(input logic [CONVERGED_AXIS_DATA_BYTES-1:0] tkeep) ;
        automatic int bytes = 0;
        for (int i=0; i<CONVERGED_AXIS_DATA_BYTES; i++) begin
            bytes += tkeep[i];
        end
        return bytes;
    endfunction

    function logic packets_are_equal(
        input logic [MTU_BYTES*8-1:0]         rx_packet,
        input int                             rx_blen,
        input logic [MTU_BYTES*8-1:0]         tx_packet,
        input logic [MTU_BYTES_LOG-1:0]       tx_blen
    );
        if (rx_blen != tx_blen) return 1'b0;
        for (int b=0; b<rx_blen; b++) begin
            if (rx_packet[b*8 +: 8] !== tx_packet[b*8 +: 8]) return 1'b0;
        end
        // $display("rx_pkt: %h", rx_packet);
        // $display("tx_pkt: %h", tx_packet);
        // $display("tx_blen: %d rx_blen: %d", tx_blen, rx_blen);
        // $display("");
        return 1'b1;
    endfunction

    `MAKE_AXIS_MONITOR(ing_bus_monitor, ing_bus);

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            packet_received    <= '{default: '{default: '0}};
            rx_packet_buf      <= '0;
            rx_packet          <= '0;
            rx_wcnt            <= 0;
            rx_blen            <= 0;
            rx_ing_port        <= 0;
        end else begin
            rx_validate <= ing_bus_monitor.tlast & ing_bus_monitor.tvalid & ing_bus_monitor.tready;
            if (ing_bus_monitor.tvalid && ing_bus_monitor.tready) begin
                rx_packet_buf[rx_wcnt*CONVERGED_AXIS_DATA_BYTES*8 +: CONVERGED_AXIS_DATA_BYTES*8] <= ing_bus_monitor.tdata;
                rx_wcnt <= rx_wcnt +1;
                if (ing_bus_monitor.tlast) begin
                    rx_blen <= rx_wcnt*CONVERGED_AXIS_DATA_BYTES + tkeep_to_bytes(ing_bus_monitor.tkeep);
                    rx_ing_port <= ing_bus_monitor.tuser;
                    rx_packet <= rx_packet_buf;
                    rx_packet[rx_wcnt*CONVERGED_AXIS_DATA_BYTES*8 +: CONVERGED_AXIS_DATA_BYTES*8] <= ing_bus_monitor.tdata;
                    rx_wcnt <= 0;
                    rx_packet_buf <= '0;
                end
            end
            if (rx_validate) begin
                for (int pkt=0; pkt<=NUM_PACKETS_TO_SEND; pkt++) begin
                    if (pkt == NUM_PACKETS_TO_SEND) begin
                        $display("");
                        $display("rx ingress port: %d", rx_ing_port);
                        $display("rx byte length: %d", rx_blen);
                        $display("rx packet: %h", rx_packet);
                        $display("");
                        $display("possible tx packet matches");
                        for (int txp=0; txp<tx_snoop_wr_ptr[rx_ing_port]; txp++) begin
                            if (!packet_received[rx_ing_port][txp]) begin
                                $display("tx byte length: %d", tx_snoop_blen_buf[rx_ing_port][txp]);
                                $display("tx packet: %h", tx_snoop_data_buf[rx_ing_port][txp]);
                            end
                        end
                        $display("");
                        $error("RX packet not found in TX snoop buffer.");
                    end else if (packets_are_equal(rx_packet, rx_blen, tx_snoop_data_buf[rx_ing_port][pkt], tx_snoop_blen_buf[rx_ing_port][pkt])) begin
                        packet_received[rx_ing_port][pkt] <= 1'b1;
                        break;
                    end
                end
            end
        end
    end

    // Transmit packet counters
    generate
        for (genvar i=0; i<NUM_8B_PORTS; i++) begin
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_8B][i]] = ing_8b_phys_ports[i].tready & ing_8b_phys_ports[i].tvalid & ing_8b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_16B_PORTS; i++) begin
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_16B][i]] = ing_16b_phys_ports[i].tready & ing_16b_phys_ports[i].tvalid & ing_16b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_32B_PORTS; i++) begin
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_32B][i]] = ing_32b_phys_ports[i].tready & ing_32b_phys_ports[i].tvalid & ing_32b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_64B_PORTS; i++) begin
            assign ing_phys_ports_tlast[ING_PORT_INDEX_MAP[INDEX_64B][i]] = ing_64b_phys_ports[i].tready & ing_64b_phys_ports[i].tvalid & ing_64b_phys_ports[i].tlast;
        end
    endgenerate

    always_ff @(posedge ing_port_clk_ifc.clk) begin
        if (ing_port_sreset_ifc.reset == ing_port_sreset_ifc.ACTIVE_HIGH) begin
            expected_ing_cnts = '{default: '{default: '{default: '0}}};
        end else begin
            for (int port_index; port_index<NUM_PORTS; port_index++) begin
                if (ing_phys_ports_enable[port_index]) begin
                    expected_ing_cnts[port_index][FRAME_COUNT_INDEX] += ing_phys_ports_tlast[port_index];
                end
            end
        end
    end

    // Receive packet counter
    always_ff @(posedge core_clk_ifc.clk) begin : rx_pkt_cntr
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            received_count <= 0;
        end else begin
            if (ing_bus.tlast & ing_bus.tvalid & ing_bus.tready) begin
                received_count <= received_count + 1;
            end
        end
    end

    // Verify physical port index is inserted into tuser
    always_ff @( posedge core_clk_ifc.clk ) begin
        if (ing_bus.tlast & ing_bus.tvalid & ing_bus.tready) begin
            `ELAB_CHECK_GE(ing_bus.tuser, 0);
            `ELAB_CHECK_LT(ing_bus.tuser, NUM_PORTS);
        end
    end

    // Verify that there are no buffer overflows
    always_ff @( posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH) begin
            `CHECK_EQUAL(ing_async_fifo_overflow , 0);
            `CHECK_EQUAL(ing_buf_overflow , 0);
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks
    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        automatic int port_width_index = get_port_width_index(send_packet_port);
        automatic int port_array_index = get_port_array_index(send_packet_port);

        send_packet_byte_length[port_width_index][port_array_index] = packet_byte_length;

        // Wait till we can send data
        while(send_packet_busy [port_width_index][port_array_index]) @(posedge ing_port_clk_ifc.clk);

        case (port_width_index)
            INDEX_8B:  axis_packet_formatter #( BYTES_PER_8BIT_WORD,  MAX_PKT_WLEN_8B , MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data_8 [port_array_index], send_packet_vec[send_packet_port]);
            INDEX_16B: axis_packet_formatter #( BYTES_PER_16BIT_WORD, MAX_PKT_WLEN_16B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data_16[port_array_index], send_packet_vec[send_packet_port]);
            INDEX_32B: axis_packet_formatter #( BYTES_PER_32BIT_WORD, MAX_PKT_WLEN_32B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data_32[port_array_index], send_packet_vec[send_packet_port]);
            INDEX_64B: axis_packet_formatter #( BYTES_PER_64BIT_WORD, MAX_PKT_WLEN_64B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data_64[port_array_index], send_packet_vec[send_packet_port]);
            default: ;
        endcase

        send_packet_req[port_width_index][port_array_index] = 1'b1;
        // Wait till its received
        while(!send_packet_busy[port_width_index][port_array_index]) @(posedge ing_port_clk_ifc.clk);
        send_packet_req[port_width_index][port_array_index] = 1'b0;
        // Wait till its finished
        while(send_packet_busy[port_width_index][port_array_index]) @(posedge ing_port_clk_ifc.clk);
    end
    endtask;

    task automatic send_random_length_packet (
        input int send_packet_port
    );
        send_packet(send_packet_port, $urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN));
    endtask

    task automatic check_pkt_cnts();
        // Compare tx and rx counts
        `CHECK_EQUAL(received_count, expected_count);
        for (int i=0; i<NUM_PORTS; i++) begin
            // Check that the expected number of packets were counted by the DUT ingress counters
            `CHECK_EQUAL(ing_cnts[i][FRAME_COUNT_INDEX], expected_ing_cnts[i][FRAME_COUNT_INDEX]);
            // Verify that the DUT ingress counters clears and don't disrupt other counts
            ing_cnts_clear[i] = 1'b1;
            @(posedge core_clk_ifc.clk);
            #1;
            `CHECK_EQUAL(ing_cnts[i][FRAME_COUNT_INDEX], 0);
        end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            ing_port_clk_ifc.clk = 1'b0;
            core_clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = '{default: '{default: 1'b0}};
        end

        `TEST_CASE_SETUP begin
            ing_phys_ports_enable = '1;
            ing_cnts_clear = '0;
            @(posedge ing_port_clk_ifc.clk);
            ing_port_sreset_ifc.reset = ing_port_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;

            send_packet_req = '{default: '{default: 1'b0}};

            repeat (10) @(posedge ing_port_clk_ifc.clk);
            ing_port_sreset_ifc.reset = ~ing_port_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

            repeat (2) @(posedge ing_port_clk_ifc.clk);
        end

        // Send packets to all ports simultaneously
        // expect all packets to be labeled with the correct ingress port
        // and to exit on ing_bus AXIS interface
        `TEST_CASE("send_to_all_ports") begin

            expected_count = (NUM_PACKETS_TO_SEND / NUM_PORTS) * NUM_PORTS;

            // Send packets to all interfacess in parallel
            for (int phys_port_thread=0; phys_port_thread<NUM_PORTS; phys_port_thread++ ) begin
                automatic int phys_port = phys_port_thread;
                fork
                    begin
                        for(int packet=0; packet<NUM_PACKETS_TO_SEND/NUM_PORTS; packet++) begin
                            send_random_length_packet(phys_port);
                        end
                    end
                join_none
            end
            wait fork;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge core_clk_ifc.clk);

            // Check that expected equals received
            check_pkt_cnts;
        end

        // Send packets to all ports when all ports are disabled
        // expect no packets to exit on ing_bus AXIS interface.
        `TEST_CASE("send_pkts_w_all_ports_disabled") begin

            expected_count = 0;
            ing_phys_ports_enable = '0;

            // Send packets to all interfacess in parallel
            for (int phys_port_thread=0; phys_port_thread<NUM_PORTS; phys_port_thread++ ) begin
                automatic int phys_port = phys_port_thread;
                fork
                    begin
                        for(int packet=0; packet<NUM_PACKETS_TO_SEND/NUM_PORTS; packet++) begin
                            send_random_length_packet(phys_port);
                        end
                    end
                join_none
            end
            wait fork;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge core_clk_ifc.clk);

            // Check that expected equals received
            check_pkt_cnts;
        end

        // Sent packets to all interfaces with one interface disabled
        // expect to see all but the disabled interfaces pacekts exit
        // ing_bus AXIS interface
        `TEST_CASE("send_pkts_w_one_port_disabled") begin

            ing_phys_ports_enable[0] = 1'b1;

            // Send packets to all interfacess in parallel
            for (int phys_port_thread=0; phys_port_thread<NUM_PORTS; phys_port_thread++ ) begin
                automatic int phys_port = phys_port_thread;
                fork
                    begin
                        for(int packet=0; packet<NUM_PACKETS_TO_SEND/NUM_PORTS; packet++) begin
                            send_random_length_packet(phys_port);
                        end
                    end
                join_none
            end
            wait fork;

            // Give time for all the packets to be received
            for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge core_clk_ifc.clk);

            // Check that expected equals received
            expected_count = 0;
            for (int i=0; i<NUM_PORTS; i++) begin
                expected_count += expected_ing_cnts[i][FRAME_COUNT_INDEX];
            end
            check_pkt_cnts;
        end
    end

    `WATCHDOG(10ms);

endmodule