// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for:
    axis_packet_generator
    axis_packet_checker
    axis_array_packet_generator
    axis_array_packet_checker
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps


module axis_array_packet_generator_and_checker_tb ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int NUM_AXIS_INTFS = 4;
    parameter int DATA_BYTES = 8;
    parameter int MTU_BYTES = 1500;                // MTU for the router
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [0:MTU_BYTES*8-1]             send_packet_data        [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];
    int                                 send_packet_byte_length [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_req         [NUM_ING_AXIS_ARRAYS-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_req_d       [NUM_ING_AXIS_ARRAYS-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_busy        [NUM_ING_AXIS_ARRAYS-1:0];

    int expected_count;
    int received_count;
    bit receive_cntr_clear;

    logic [NUM_PORTS-1:0]          ing_phys_ports_tlast;
    logic [ING_COUNTERS_WIDTH-1:0] expected_ing_cnts [NUM_PORTS-1:0] [6:0];

    logic [0:MTU_BYTES*8-1]             tx_snoop_data_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PORTS_LOG-1:0]           tx_snoop_ing_port_buf   [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr;

    logic [NUM_PACKETS_TO_SEND-1:0] packet_received [NUM_PORTS-1:0];
    logic [MTU_BYTES*8-1:0]         rx_packet_buf;
    logic [MTU_BYTES*8-1:0]         rx_packet;
    int                             rx_wcnt;
    int                             rx_blen;
    int                             rx_ing_port;
    logic                           rx_validate;

    int sink_interpacekt_gap;


    /////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( DATA_BYTES )
    ) packet_axis [NUM_AXIS_INTFS-1:0] (
        .clk     (clk_ifc.clk                                 ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic implemenatation

    // Simulation clocks
    always #5 clk_ifc.clk <= ~clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet generators

    axis_array_packet_generator #(
        .NUM_PORTS          ( NUM_              ),
        .MTU_BYTES          ( MTU_BYTES                 )
    ) packet_generator_8b (
        .axis_packet_out    ( ing_8b_phys_ports                                 ),
        .busy               ( send_packet_busy[INDEX_8B][NUM_8B_PORTS-1:0]      ),
        .send_packet_req    ( send_packet_req[INDEX_8B][NUM_8B_PORTS-1:0]       ),
        .packet_byte_length ( send_packet_byte_length[INDEX_8B][NUM_8B_PORTS-1:0]),
        .packet_user        ( '{default: '0}                                    ),
        .packet_data        ( send_packet_data[INDEX_8B][NUM_8B_PORTS-1:0]      )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    // CDC
    generate
        for (genvar port_index=0; port_index<NUM_8B_PORTS; port_index++) begin
            axis_dist_ram_fifo #(
                .DEPTH         ( CDC_FIFO_DEPTH ),
                .ASYNC_CLOCKS  ( 1'b1           )
            ) async_fifo (
                .axis_in           ( ing_8b_phys_ports[port_index]          ),
                .axis_out          ( ing_8b_phys_ports_cdc[port_index]      ),
                .axis_in_overflow  (                                        ),
                .axis_out_overflow ( ing_8b_async_fifo_overflow[port_index] )
            );
        end
        for (genvar port_index=0; port_index<NUM_16B_PORTS; port_index++) begin
            axis_dist_ram_fifo #(
                .DEPTH         ( CDC_FIFO_DEPTH ),
                .ASYNC_CLOCKS  ( 1'b1           )
            ) async_fifo (
                .axis_in           ( ing_16b_phys_ports[port_index]          ),
                .axis_out          ( ing_16b_phys_ports_cdc[port_index]      ),
                .axis_in_overflow  (                                         ),
                .axis_out_overflow ( ing_16b_async_fifo_overflow[port_index] )
            );
        end
        for (genvar port_index=0; port_index<NUM_32B_PORTS; port_index++) begin
            axis_dist_ram_fifo #(
                .DEPTH         ( CDC_FIFO_DEPTH ),
                .ASYNC_CLOCKS  ( 1'b1           )
            ) async_fifo (
                .axis_in           ( ing_32b_phys_ports[port_index]          ),
                .axis_out          ( ing_32b_phys_ports_cdc[port_index]      ),
                .axis_in_overflow  (                                         ),
                .axis_out_overflow ( ing_32b_async_fifo_overflow[port_index] )
            );
        end
        for (genvar port_index=0; port_index<NUM_64B_PORTS; port_index++) begin
            axis_dist_ram_fifo #(
                .DEPTH         ( CDC_FIFO_DEPTH ),
                .ASYNC_CLOCKS  ( 1'b1           )
            ) async_fifo (
                .axis_in           ( ing_64b_phys_ports[port_index]          ),
                .axis_out          ( ing_64b_phys_ports_cdc[port_index]      ),
                .axis_in_overflow  (                                         ),
                .axis_out_overflow ( ing_64b_async_fifo_overflow[port_index] )
            );
        end
    endgenerate

    p4_router_ingress #(
        .NUM_8B_ING_PHYS_PORTS  ( NUM_8B_PORTS          ),
        .NUM_16B_ING_PHYS_PORTS ( NUM_16B_PORTS         ),
        .NUM_32B_ING_PHYS_PORTS ( NUM_32B_PORTS         ),
        .NUM_64B_ING_PHYS_PORTS ( NUM_64B_PORTS         ),
        .MTU_BYTES              ( MTU_BYTES             )
    ) DUT (
        .ing_8b_phys_ports          ( ing_8b_phys_ports_cdc     ),
        .ing_16b_phys_ports         ( ing_16b_phys_ports_cdc    ),
        .ing_32b_phys_ports         ( ing_32b_phys_ports_cdc    ),
        .ing_64b_phys_ports         ( ing_64b_phys_ports_cdc    ),
        .ing_bus                    ( ing_bus                   ),
        .ing_bus_pkt_cnt            ( ing_bus_pkt_cnt           ),
        .ing_bus_pkt_cnt_clear      ( ing_bus_pkt_cnt_clear     ),
        .ing_phys_ports_enable      ( ing_phys_ports_enable     ),
        .ing_cnts_clear             ( ing_cnts_clear            ),
        .ing_cnts                   ( ing_cnts                  ),
        .ing_ports_conneted         ( ing_ports_conneted        ),
        .ing_buf_overflow           ( ing_buf_overflow          )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Tx Packet Capture

    always_ff @(posedge ing_port_clk_ifc.clk ) begin
        if (packet_sink_reset) begin
            tx_snoop_data_buf  <= '{default: '0};
            tx_snoop_blen_buf  <= '{default: 0};
            tx_snoop_ing_port_buf    <= '{default: 0};
            tx_snoop_wr_ptr    <= '0;
            send_packet_req_d  <= '{default: '0};
        end else begin
            send_packet_req_d <= send_packet_req;
            for (int send_packet_port=0; send_packet_port<NUM_PORTS; send_packet_port++) begin
                automatic int width_index = get_port_width_index(send_packet_port, ING_PORT_INDEX_MAP);
                automatic int array_index = get_port_array_index(send_packet_port, ING_PORT_INDEX_MAP);
                if (send_packet_req[width_index][array_index] && ! send_packet_req_d[width_index][array_index]) begin
                    tx_snoop_data_buf[tx_snoop_wr_ptr] <= send_packet_data[width_index][array_index];
                    tx_snoop_blen_buf[tx_snoop_wr_ptr] <= send_packet_byte_length[width_index][array_index];
                    tx_snoop_ing_port_buf[tx_snoop_wr_ptr] <= send_packet_port;
                    tx_snoop_wr_ptr++;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Packet Sink and Check

    assign packet_checker_axis.tdata    = ing_bus.tdata;
    assign packet_checker_axis.tvalid   = ing_bus.tvalid;
    assign ing_bus.tready               = packet_checker_axis.tready | flush_ing_buffer;
    assign packet_checker_axis.tlast    = ing_bus.tlast;
    assign packet_checker_axis.tkeep    = ing_bus.tkeep;
    assign packet_checker_axis.tuser    = ing_bus.tuser;
    assign packet_checker_axis.tdest    = ing_bus.tdest;
    assign packet_checker_axis.tid      = ing_bus.tid;
    assign packet_checker_axis.tstrb    = ing_bus.tstrb;

    assign ingress_metadata = ing_bus.tuser;

    axis_packet_checker #(
        .PKT_ID_STRING              ( "Ingress Port"        ),
        .NUM_PKT_IDS                ( NUM_PORTS             ),
        .MTU_BYTES                  ( MTU_BYTES             ),
        .NUM_PACKETS_BEING_SENT     ( NUM_PACKETS_TO_SEND   )
    ) packet_checker (
        .axis_packet_in ( packet_checker_axis           ),
        .packet_in_id   ( ingress_metadata.ingress_port ),
        .num_tx_pkts    ( tx_snoop_wr_ptr               ),
        .expected_pkts  ( tx_snoop_data_buf             ),
        .expected_blens ( tx_snoop_blen_buf             ),
        .expected_ids   ( tx_snoop_ing_port_buf         ),
        .interpacket_gap ( sink_interpacekt_gap         )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Packet Counters

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
        if (ing_port_sreset_ifc.reset == ing_port_sreset_ifc.ACTIVE_HIGH || receive_cntr_clear) begin
            expected_ing_cnts = '{default: '{default: '0}};
        end else begin
            for (int port_index; port_index<NUM_PORTS; port_index++) begin
                if (ing_phys_ports_enable[port_index]) begin
                    expected_ing_cnts[port_index][AXIS_PROFILE_PKT_CNT_INDEX] += ing_phys_ports_tlast[port_index];
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Receive packet counter

    always_ff @(posedge core_clk_ifc.clk) begin : rx_pkt_cntr
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH || receive_cntr_clear) begin
            received_count <= 0;
        end else begin
            if (ing_bus.tlast & ing_bus.tvalid & ing_bus.tready) begin
                received_count <= received_count + 1;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Verify physical port index is inserted into tuser

    always_ff @( posedge core_clk_ifc.clk ) begin
        if (ing_bus.tlast & ing_bus.tvalid & ing_bus.tready) begin
            `ELAB_CHECK_GE(ingress_metadata.ingress_port, 0);
            `ELAB_CHECK_LT(ingress_metadata.ingress_port, NUM_PORTS);
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Verify that there are no buffer overflows

    always_ff @( posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH) begin
            if (!ignore_overflow) begin
                `CHECK_EQUAL(ing_8b_async_fifo_overflow , 0);
                `CHECK_EQUAL(ing_16b_async_fifo_overflow , 0);
                `CHECK_EQUAL(ing_32b_async_fifo_overflow , 0);
                `CHECK_EQUAL(ing_64b_async_fifo_overflow , 0);
                `CHECK_EQUAL(ing_buf_overflow , 0);
            end
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

        send_packet_byte_length[port_width_index][port_array_index] = packet_byte_length;

        // Wait till we can send data
        while(send_packet_busy [port_width_index][port_array_index]) @(posedge ing_port_clk_ifc.clk);

        case (port_width_index)
            INDEX_8B:  axis_packet_formatter #( BYTES_PER_8BIT_WORD,  MAX_PKT_WLEN_8B , MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data[INDEX_8B] [port_array_index]);
            INDEX_16B: axis_packet_formatter #( BYTES_PER_16BIT_WORD, MAX_PKT_WLEN_16B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data[INDEX_16B][port_array_index]);
            INDEX_32B: axis_packet_formatter #( BYTES_PER_32BIT_WORD, MAX_PKT_WLEN_32B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data[INDEX_32B][port_array_index]);
            INDEX_64B: axis_packet_formatter #( BYTES_PER_64BIT_WORD, MAX_PKT_WLEN_64B, MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data[INDEX_64B][port_array_index]);
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
        `CHECK_EQUAL(received_count, expected_count); // test bench packet count at ingress bus
        `CHECK_EQUAL(ing_bus_pkt_cnt, expected_count); // DUT packet count at ingress bus
        for (int i=0; i<NUM_PORTS; i++) begin
            // Check that the expected number of packets were counted by the DUT ingress counters
            `CHECK_EQUAL(ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], expected_ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX]);
            // Verify that the DUT ingress counters clears and don't disrupt other counts
            ing_cnts_clear[i] = 1'b1;
            @(posedge core_clk_ifc.clk);
            #1;
            `CHECK_EQUAL(ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], 0);
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
            sink_interpacekt_gap = 0;
            ignore_overflow = 1'b0;
            flush_ing_buffer = 1'b0;
            receive_cntr_clear = 1'b0;
            @(posedge ing_port_clk_ifc.clk);
            ing_port_sreset_ifc.reset = ing_port_sreset_ifc.ACTIVE_HIGH;
            packet_sink_reset = 1'b1;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;

            send_packet_req = '{default: '{default: 1'b0}};

            repeat (10) @(posedge ing_port_clk_ifc.clk);
            ing_port_sreset_ifc.reset = ~ing_port_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;
            packet_sink_reset = 1'b0;

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
                expected_count += expected_ing_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX];
            end
            check_pkt_cnts;
        end

        // Send packets to all ports simultaneously
        // deassert tready between packets.
        `TEST_CASE("ing_bus_backpressure") begin

            sink_interpacekt_gap = 20;
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

        `TEST_CASE("ing_buf_overflow_recovery") begin

            automatic logic [NUM_PORTS-1:0] ovf_det = '0;
            automatic bit packet_seen = 1'b1;

            packet_sink_reset = 1'b1;
            expected_count = (NUM_PACKETS_TO_SEND / NUM_PORTS) * NUM_PORTS;
            ignore_overflow = 1'b1;

            // Send packets to all interfacess in parallel utill the buffers overflow
            for (int phys_port_thread=0; phys_port_thread<NUM_PORTS; phys_port_thread++ ) begin
                automatic int phys_port = phys_port_thread;
                fork
                    begin
                        while (!flush_ing_buffer) begin
                            send_random_length_packet(phys_port);
                        end
                    end
                join_none
            end

            while (~&ovf_det) begin
                @(posedge core_clk_ifc.clk);
                #1
                ovf_det |= ing_buf_overflow;
            end
            flush_ing_buffer = 1'b1;

            wait fork;

            // let the buffer clear so we can count packets
            while (packet_seen) begin
                packet_seen = 1'b0;
                for (int i=0; i<PACKET_MAX_BLEN; i++) begin
                    @(posedge core_clk_ifc.clk);
                    #1
                    packet_seen |= ing_bus.tvalid;
                end
            end

            ignore_overflow = 1'b0;
            @(posedge core_clk_ifc.clk);
            #1
            ing_cnts_clear = '1;
            receive_cntr_clear = 1'b1;
            ing_bus_pkt_cnt_clear = 1'b1;
            repeat (10) @(posedge core_clk_ifc.clk);
            #1
            ing_cnts_clear = '0;
            receive_cntr_clear = 1'b0;
            ing_bus_pkt_cnt_clear = 1'b0;
            packet_sink_reset = 1'b0;
            flush_ing_buffer = 1'b0;
            @(posedge core_clk_ifc.clk);
            #1

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
            packet_seen = 1'b1;
            while (packet_seen) begin
                packet_seen = 1'b0;
                for (int i=0; i<PACKET_MAX_BLEN; i++) begin
                    @(posedge core_clk_ifc.clk);
                    #1
                    packet_seen |= ing_bus.tvalid;
                end
            end

            // Check that expected equals received
            check_pkt_cnts;
        end
    end


    `WATCHDOG(10ms);

endmodule