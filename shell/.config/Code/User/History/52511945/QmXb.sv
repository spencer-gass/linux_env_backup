// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for p4_router_egress.
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps


module p4_router_egress_tb ();

    /////////////////////////////////////////////////////////////////////////
    // Parameter definition
    parameter int NUM_8B_PORTS  = 3;               // Number of 8-bit  physical ports to the DUT
    parameter int NUM_16B_PORTS = 0;               // Number of 16-bit physical ports to the DUT
    parameter int NUM_32B_PORTS = 3;               // Number of 32-bit physical ports to the DUT
    parameter int NUM_64B_PORTS = 0;               // Number of 640bit physical ports to the DUT
    parameter int EGR_AXIS_DATA_BYTES = 8;         // Width of axis bus toward VNP4
    parameter int MTU_BYTES = 9600;                // MTU for the router
    parameter int PACKET_MAX_BLEN = 1000;          // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;
    parameter int EGR_COUNTERS_WIDTH = 32;

    localparam RAND = 0;
    localparam INC = 1;
    localparam PAYLOAD_TYPE = RAND;

    /////////////////////////////////////////////////////////////////////////
    // Import

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::U_INT_CEIL_DIV;

    /////////////////////////////////////////////////////////////////////////
    // Local parameter definition
    localparam real AXIS_CLK_PERIOD = 10.0;

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_PORTS,
                                                                             NUM_32B_PORTS,
                                                                             NUM_16B_PORTS,
                                                                             NUM_8B_PORTS
                                                                          };

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array(NUM_EGR_PHYS_PORTS_PER_ARRAY);

    localparam int NUM_PORTS      = NUM_8B_PORTS + NUM_16B_PORTS + NUM_32B_PORTS + NUM_64B_PORTS;
    localparam int NUM_PORTS_LOG  = $clog2(NUM_PORTS);

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

    localparam egr_port_index_map_t EGR_PORT_INDEX_MAP = create_egr_port_index_map();
    localparam INDEX_8B_START  = EGR_PORT_INDEX_MAP[INDEX_8B][0];
    localparam INDEX_16B_START = EGR_PORT_INDEX_MAP[INDEX_16B][0];
    localparam INDEX_32B_START = EGR_PORT_INDEX_MAP[INDEX_32B][0];
    localparam INDEX_64B_START = EGR_PORT_INDEX_MAP[INDEX_64B][0];

    enum {
        WIDTH_INDEX_CMD,
        ARRAY_INDEX_CMD
    } INDEX_CONV_CMDS;

    function int _get_port_width_or_array_index(
        input int port_index,
        input logic cmd
    );
        for (int width_index=0; width_index<NUM_EGR_AXIS_ARRAYS; width_index++) begin
            for (int array_index=0; array_index<MAX_NUM_PORTS_PER_ARRAY; array_index++) begin
                if (EGR_PORT_INDEX_MAP[width_index][array_index] == port_index) begin
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

    localparam int MAX_PKT_EGR_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, EGR_AXIS_DATA_BYTES);
    localparam int MAX_PKT_WLEN_8B  = PACKET_MAX_BLEN/BYTES_PER_8BIT_WORD;
    localparam int MAX_PKT_WLEN_16B = PACKET_MAX_BLEN/BYTES_PER_16BIT_WORD;
    localparam int MAX_PKT_WLEN_32B = PACKET_MAX_BLEN/BYTES_PER_32BIT_WORD;
    localparam int MAX_PKT_WLEN_64B = PACKET_MAX_BLEN/BYTES_PER_64BIT_WORD;

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int PACKET_MAX_BLEN_LOG = $clog2(PACKET_MAX_BLEN);

    localparam int FRAME_COUNT_INDEX = 5;



    ////////////////////////////////////////////////////////////////////////
    // Logic declarations

    logic [NUM_PORTS-1:0]          egr_phys_ports_enable;
    logic [NUM_PORTS-1:0]          egr_cnts_clear;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_PORTS-1:0] [6:0];
    logic [NUM_PORTS-1:0]          egr_ports_conneted;

    logic [EGR_AXIS_DATA_BYTES*8-1:0]   send_packet_data [MAX_PKT_EGR_WLEN-1:0];
    int                                 send_packet_byte_length;
    logic [MTU_BYTES*8-1:0]             packet_vec;
    logic [NUM_PORTS_LOG-1:0]           send_packet_egr_port;
    logic                               send_packet_req;
    logic                               send_packet_busy;

    int expected_count;
    int received_count_array [NUM_PORTS-1:0];
    int received_count;

    logic [NUM_PORTS-1:0] egr_phys_ports_tlast;
    logic [NUM_PORTS-1:0] egr_phys_ports_tvalid;
    logic packet_received;

    logic [EGR_COUNTERS_WIDTH-1:0] expected_egr_cnts [NUM_PORTS-1:0] [6:0];

    logic [NUM_PORTS-1:0]  egr_buf_full_drop;

    logic verify_no_overflows;
    logic verify_sequence;
    int seq_cnt;


    /////////////////////////////////////////////////////////////////////////
    // Internal Axis definitions

    AXIS_int #(
        .DATA_BYTES ( EGR_AXIS_DATA_BYTES ),
        .USER_WIDTH ( NUM_PORTS_LOG       )
    ) egr_bus (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) egr_8b_phys_ports [NUM_8B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) egr_16b_phys_ports [NUM_16B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) egr_32b_phys_ports [NUM_32B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) egr_64b_phys_ports [NUM_64B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )    // Doesn't matter for TB
    ) sreset_ifc ();


    //////////////////////////////////////////////////////////////////////////
    // Logic implemenatation

    // Simulation clock
    always #(AXIS_CLK_PERIOD/2) clk_ifc.clk <= ~clk_ifc.clk;


    // Packet generator
    AXIS_driver # (
        .DATA_BYTES(EGR_AXIS_DATA_BYTES),
        .USER_WIDTH(NUM_PORTS_LOG),
        .ID_WIDTH(1),
        .DEST_WIDTH(1)
    ) driver_interface_inst (
        .clk (egr_bus.clk),
        .sresetn(egr_bus.sresetn)
    );

    AXIS_driver_module driver_module_inst (
        .control (driver_interface_inst),
        .o ( egr_bus )
    );

    always_ff @(posedge egr_bus.clk) begin
        send_packet_busy = 1'b0;
        if (send_packet_req) begin

            automatic logic [EGR_AXIS_DATA_BYTES*8-1:0] data [$] = {};
            automatic logic                             last [$] = {};
            automatic logic [EGR_AXIS_DATA_BYTES-1:0]   keep [$] = {};
            automatic logic [EGR_AXIS_DATA_BYTES-1:0]   strb [$] = {};
            automatic logic [0:0]                       id   [$] = {};
            automatic logic [0:0]                       dest [$] = {};
            automatic logic [NUM_PORTS_LOG-1:0]         user [$] = {};
            automatic logic [EGR_AXIS_DATA_BYTES-1:0]   keep_last = '0;
            automatic int                               keep_bytes = send_packet_byte_length % EGR_AXIS_DATA_BYTES;
            automatic int                               packet_word_length = U_INT_CEIL_DIV(send_packet_byte_length, EGR_AXIS_DATA_BYTES);

            send_packet_busy = 1'b1;
            for (integer w = 0; w < packet_word_length; w++) begin
                if (w == packet_word_length-1) begin
                    last.push_back(1'b1);
                    if (keep_bytes) begin
                        for (int b=0; b<keep_bytes; b++) keep_last[b] = 1'b1;
                    end else begin
                        keep_last = '1;
                    end
                    keep.push_back(keep_last);
                end else begin
                    last.push_back(1'b0);
                    keep.push_back('1);
                end

                data.push_back(send_packet_data[w]);
                strb.push_back(1'b0);
                id  .push_back(1'b0);
                dest.push_back(1'b0);
                user.push_back(send_packet_egr_port);
            end
            driver_interface_inst.write_queue_ext(
                .input_data(data),
                .input_last(last),
                .input_keep(keep),
                .input_strb(strb),
                .input_id(id),
                .input_dest(dest),
                .input_user(user)
            );
        end
    end

    // DUT
    p4_router_egress #(
        .NUM_8B_EGR_PHYS_PORTS  ( NUM_8B_PORTS      ),
        .NUM_16B_EGR_PHYS_PORTS ( NUM_16B_PORTS     ),
        .NUM_32B_EGR_PHYS_PORTS ( NUM_32B_PORTS     ),
        .NUM_64B_EGR_PHYS_PORTS ( NUM_64B_PORTS     ),
        .MTU_BYTES              ( MTU_BYTES         ),
        .EGR_COUNTERS_WIDTH     ( EGR_COUNTERS_WIDTH)
    ) DUT (
        .clk_ifc                ( clk_ifc               ),
        .sreset_ifc             ( sreset_ifc            ),
        .egr_8b_phys_ports      ( egr_8b_phys_ports     ),
        .egr_16b_phys_ports     ( egr_16b_phys_ports    ),
        .egr_32b_phys_ports     ( egr_32b_phys_ports    ),
        .egr_64b_phys_ports     ( egr_64b_phys_ports    ),
        .egr_bus                ( egr_bus               ),
        .egr_phys_ports_enable  ( egr_phys_ports_enable ),
        .egr_cnts_clear         ( egr_cnts_clear        ),
        .egr_cnts               ( egr_cnts              ),
        .egr_ports_conneted     ( egr_ports_conneted    ),
        .egr_buf_full_drop      ( egr_buf_full_drop     )
    );

    // Packet sink
    generate
        for (genvar i=0; i<NUM_8B_PORTS; i++) begin
            AXIS_sink #(
                .DATA_BYTES  ( BYTES_PER_8BIT_WORD ),
                .ID_WIDTH    ( egr_8b_phys_ports[i].ID_WIDTH   ),
                .DEST_WIDTH  ( egr_8b_phys_ports[i].DEST_WIDTH ),
                .USER_WIDTH  ( egr_8b_phys_ports[i].USER_WIDTH ),
                .ASSIGN_DELAY(1)
            ) axis_egr_phys_port_sink (
                .clk    ( egr_8b_phys_ports[i].clk     ),
                .sresetn( egr_8b_phys_ports[i].sresetn )
            );

            AXIS_sink_module axis_test_sink_module (
                .control( axis_egr_phys_port_sink ),
                .i      ( egr_8b_phys_ports[i]       )
            );

            always begin
                while (1) axis_egr_phys_port_sink.accept_wait;
            end
        end

        for (genvar i=0; i<NUM_16B_PORTS; i++) begin
            AXIS_sink #(
                .DATA_BYTES  ( BYTES_PER_16BIT_WORD ),
                .ID_WIDTH    ( egr_16b_phys_ports[i].ID_WIDTH   ),
                .DEST_WIDTH  ( egr_16b_phys_ports[i].DEST_WIDTH ),
                .USER_WIDTH  ( egr_16b_phys_ports[i].USER_WIDTH ),
                .ASSIGN_DELAY(1)
            ) axis_egr_phys_port_sink (
                .clk    ( egr_16b_phys_ports[i].clk     ),
                .sresetn( egr_16b_phys_ports[i].sresetn )
            );

            AXIS_sink_module axis_test_sink_module (
                .control( axis_egr_phys_port_sink ),
                .i      ( egr_16b_phys_ports[i]   )
            );

            always begin
                while (1) axis_egr_phys_port_sink.accept_wait;
            end
        end

        for (genvar i=0; i<NUM_32B_PORTS; i++) begin
            AXIS_sink #(
                .DATA_BYTES  ( BYTES_PER_32BIT_WORD ),
                .ID_WIDTH    ( egr_32b_phys_ports[i].ID_WIDTH   ),
                .DEST_WIDTH  ( egr_32b_phys_ports[i].DEST_WIDTH ),
                .USER_WIDTH  ( egr_32b_phys_ports[i].USER_WIDTH ),
                .ASSIGN_DELAY(1)
            ) axis_egr_phys_port_sink (
                .clk    ( egr_32b_phys_ports[i].clk     ),
                .sresetn( egr_32b_phys_ports[i].sresetn )
            );

            AXIS_sink_module axis_test_sink_module (
                .control( axis_egr_phys_port_sink ),
                .i      ( egr_32b_phys_ports[i]   )
            );

            always begin
                while (1) axis_egr_phys_port_sink.accept_wait;
            end
        end

        for (genvar i=0; i<NUM_64B_PORTS; i++) begin
            AXIS_sink #(
                .DATA_BYTES  ( BYTES_PER_64BIT_WORD ),
                .ID_WIDTH    ( egr_64b_phys_ports[i].ID_WIDTH   ),
                .DEST_WIDTH  ( egr_64b_phys_ports[i].DEST_WIDTH ),
                .USER_WIDTH  ( egr_64b_phys_ports[i].USER_WIDTH ),
                .ASSIGN_DELAY(1)
            ) axis_egr_phys_port_sink (
                .clk    ( egr_64b_phys_ports[i].clk     ),
                .sresetn( egr_64b_phys_ports[i].sresetn )
            );

            AXIS_sink_module axis_test_sink_module (
                .control( axis_egr_phys_port_sink ),
                .i      ( egr_64b_phys_ports[i]   )
            );

            always begin
                while (1) axis_egr_phys_port_sink.accept_wait;
            end
        end

    endgenerate


    // Receive packet counter and demux verification

    // Modelsim didn't want to iterate over arrays of interfaces in an always_ff
    // pull tlast into a logic vector that Modelsim will allow iteraton over.
    generate
        for (genvar i=0; i<NUM_8B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_8B][i]] = egr_8b_phys_ports[i].tready & egr_8b_phys_ports[i].tvalid & egr_8b_phys_ports[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_8B][i]] = egr_8b_phys_ports[i].tready & egr_8b_phys_ports[i].tvalid & egr_8b_phys_ports[i].tvalid;
        end
        for (genvar i=0; i<NUM_16B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_16B][i]] = egr_16b_phys_ports[i].tready & egr_16b_phys_ports[i].tvalid & egr_16b_phys_ports[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_16B][i]] = egr_16b_phys_ports[i].tready & egr_16b_phys_ports[i].tvalid & egr_16b_phys_ports[i].tvalid;
        end
        for (genvar i=0; i<NUM_32B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_32B][i]] = egr_32b_phys_ports[i].tready & egr_32b_phys_ports[i].tvalid & egr_32b_phys_ports[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_32B][i]] = egr_32b_phys_ports[i].tready & egr_32b_phys_ports[i].tvalid & egr_32b_phys_ports[i].tvalid;
        end
        for (genvar i=0; i<NUM_64B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[INDEX_64B][i]] = egr_64b_phys_ports[i].tready & egr_64b_phys_ports[i].tvalid & egr_64b_phys_ports[i].tlast;
            assign egr_phys_ports_tvalid[EGR_PORT_INDEX_MAP[INDEX_64B][i]] = egr_64b_phys_ports[i].tready & egr_64b_phys_ports[i].tvalid & egr_64b_phys_ports[i].tvalid;
        end
    endgenerate

    always_ff @(posedge clk_ifc.clk ) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            received_count_array <= '{default: 0};
            received_count = 0;
            seq_cnt <= 0;
            expected_egr_cnts = '{default: '{default: '{default: '0}}};
        end else begin
            packet_received <= 1'b0;
            for (int port=0; port<NUM_PORTS; port++) begin
                if (egr_phys_ports_tlast[port]) begin
                    if (verify_sequence) begin
                       `CHECK_EQUAL(port,seq_cnt % NUM_PORTS);
                        seq_cnt++;
                    end
                    received_count++;
                    packet_received <= 1'b1;
                    expected_egr_cnts[port][FRAME_COUNT_INDEX]++;
                end
            end
        end
    end

    // Verify that there are no buffer overflows
    always_ff @( posedge clk_ifc.clk ) begin
        if (verify_no_overflows) begin
            `CHECK_EQUAL(egr_buf_full_drop , 0);
        end
    end

    // Validate Packet Data
    generate
        if (NUM_8B_PORTS) begin
            axis_array_pkt_chk #(
                .NUM_PORTS(NUM_8B_PORTS),
                .PACKET_MAX_BLEN(PACKET_MAX_BLEN),
                .DATA_BYTES(BYTES_PER_8BIT_WORD)
            )  pkt_chk_8b  (
                .axis_in(egr_8b_phys_ports)
            );
        end

        if (NUM_16B_PORTS) begin
            axis_array_pkt_chk #(
                .NUM_PORTS(NUM_16B_PORTS),
                .PACKET_MAX_BLEN(PACKET_MAX_BLEN),
                .DATA_BYTES(BYTES_PER_16BIT_WORD)
            ) pkt_chk_16b (
                .axis_in(egr_16b_phys_ports)
            );
        end

        if (NUM_32B_PORTS) begin
            axis_array_pkt_chk #(
                .NUM_PORTS(NUM_32B_PORTS),
                .PACKET_MAX_BLEN(PACKET_MAX_BLEN),
                .DATA_BYTES(BYTES_PER_32BIT_WORD)
            ) pkt_chk_32b (
                .axis_in(egr_32b_phys_ports)
            );
        end

        if (NUM_64B_PORTS) begin
            axis_array_pkt_chk #(
                .NUM_PORTS(NUM_64B_PORTS),
                .PACKET_MAX_BLEN(PACKET_MAX_BLEN),
                .DATA_BYTES(BYTES_PER_64BIT_WORD)
            ) pkt_chk_64b (
                .axis_in(egr_64b_phys_ports)
            );
        end
    endgenerate

    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        automatic int port_width_index = get_port_width_index(send_packet_port);
        automatic int port_array_index = get_port_array_index(send_packet_port);
        // round byte length to a multiple of bytes per word to make checking easier


        send_packet_byte_length = packet_byte_length;
        send_packet_egr_port = send_packet_port;

        // Wait till we can send data
        while(send_packet_busy) @(posedge clk_ifc.clk);
        axis_packet_formatter #( EGR_AXIS_DATA_BYTES,  MAX_PKT_EGR_WLEN , MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data, packet_vec);
        send_packet_req = 1'b1;
        // Wait till its received
        while(!send_packet_busy) @(posedge clk_ifc.clk);
        send_packet_req = 1'b0;
        // Wait till its finished
        while(send_packet_busy) @(posedge clk_ifc.clk);
    end
    endtask;

    task automatic send_random_length_packet (
        input int send_packet_port
    ); begin
    end
        send_packet(send_packet_port, $urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN));
    endtask

    task automatic check_pkt_cnts();
        // Compare tx and rx counts
        `CHECK_EQUAL(received_count, expected_count);
        for (int i=0; i<NUM_PORTS; i++) begin
            // Check that the expected number of packets were counted by the DUT ingress counters
            `CHECK_EQUAL(egr_cnts[i][FRAME_COUNT_INDEX], expected_egr_cnts[i][FRAME_COUNT_INDEX]);
            // Verify that the DUT ingress counters clears and don't disrupt other counts
            egr_cnts_clear[i] = 1'b1;
            @(posedge clk_ifc.clk);
            #1;
            `CHECK_EQUAL(egr_cnts[i][FRAME_COUNT_INDEX], 0);
        end
    endtask

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = 1'b0;
        end

        `TEST_CASE_SETUP begin
            egr_cnts_clear = '0;
            egr_phys_ports_enable = '1;
            sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
            send_packet_req = 1'b0;
            verify_no_overflows = 1'b0;
            verify_sequence = 1'b0;
            expected_count = NUM_PACKETS_TO_SEND;
            repeat (2) @(posedge clk_ifc.clk);
            sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge clk_ifc.clk);
        end

        // Send packets to all ports sequentially and wait for the packet to be output
        // before sending the next packet to verify that packets are getting muxed to the
        // correct port
        `TEST_CASE("test_demux") begin
            verify_no_overflows = 1'b1;
            verify_sequence = 1'b1;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                wait (packet_received);
            end
            // Check that expected equals received
            check_pkt_cnts;
        end

        // force a packet drop then verify the buffer recovers
        `TEST_CASE("test_drop") begin

            automatic int idle_cnt = 100;

            // Send 10 packets to each port at a rate that they can't keep up with to force drops
            for (int pkt=0; pkt<10*NUM_16B_PORTS; pkt++) begin
                send_packet(pkt/NUM_16B_PORTS, PACKET_MAX_BLEN);
            end

            // wait for the buffers to clear

            repeat (100) @(posedge clk_ifc.clk);

            while (|egr_phys_ports_tvalid || idle_cnt > 0) begin
                @(posedge clk_ifc.clk);
                if (|egr_phys_ports_tvalid) begin
                    idle_cnt = 100;
                end else begin
                    idle_cnt--;
                end

            end

            // All packets received after this point should be received
            expected_count = received_count + NUM_PACKETS_TO_SEND;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                wait (packet_received);
            end

            repeat (100) @(posedge clk_ifc.clk);

            // Check that expected equals received
            `CHECK_EQUAL(received_count, expected_count);
        end

        // Send packets with all ports disabled
        `TEST_CASE("disable_all_ports") begin
            verify_no_overflows = 1'b1;
            egr_phys_ports_enable = '0;
            expected_count = 0;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                repeat (100) @(posedge clk_ifc.clk);
            end
            // Check that expected equals received
            check_pkt_cnts;
        end

        // Send packets with one port disabled
        `TEST_CASE("disable_one_port") begin
            verify_no_overflows = 1'b1;
            egr_phys_ports_enable = '0;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                repeat (100) @(posedge clk_ifc.clk);
            end
            // Check that expected equals received
            expected_count = 0;
            for (int i=0; i<NUM_PORTS; i++) begin
                expected_count += egr_cnts[i][FRAME_COUNT_INDEX];
            end
            check_pkt_cnts;
        end
    end

    `WATCHDOG(10ms);


endmodule
