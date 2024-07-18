// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for mpls_egress.
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps


module mpls_egress_tb ();

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

    /////////////////////////////////////////////////////////////////////////
    // Import

    import mpls_ingress_tb_pkg::*;

    /////////////////////////////////////////////////////////////////////////
    // Local parameter definition
    localparam real AXIS_CLK_PERIOD = 10.0;

    enum {
        EGR_8B_INDEX,
        EGR_16B_INDEX,
        EGR_32B_INDEX,
        EGR_64B_INDEX,
        NUM_EGR_AXIS_ARRAYS
    } port_width_indecies;

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_PORTS,
                                                                             NUM_32B_PORTS,
                                                                             NUM_16B_PORTS,
                                                                             NUM_8B_PORTS
                                                                          };

    function int get_max_num_ports_per_array();
        automatic int max = 0;
        for (int i=0; i<NUM_EGR_AXIS_ARRAYS; i++) begin
            if (NUM_EGR_PHYS_PORTS_PER_ARRAY[i] > max) begin
                max = NUM_EGR_PHYS_PORTS_PER_ARRAY[i];
            end
        end
        return max;
    endfunction

    localparam int MAX_NUM_PORTS_PER_ARRAY = get_max_num_ports_per_array();

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

    localparam int MAX_PKT_EGR_WLEN = (2**$clog(PACKET_MAX_BLEN)==PACKET_MAX_BLEN) ? PACKET_MAX_BLEN/EGR_AXIS_DATA_BYTES : PACKET_MAX_BLEN/EGR_AXIS_DATA_BYTES+1;
    localparam int MAX_PKT_WLEN_8B  = PACKET_MAX_BLEN/BYTES_PER_8BIT_WORD;
    localparam int MAX_PKT_WLEN_16B = PACKET_MAX_BLEN/BYTES_PER_16BIT_WORD;
    localparam int MAX_PKT_WLEN_32B = PACKET_MAX_BLEN/BYTES_PER_32BIT_WORD;
    localparam int MAX_PKT_WLEN_64B = PACKET_MAX_BLEN/BYTES_PER_64BIT_WORD;

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int PACKET_MAX_BLEN_LOG = $clog2(PACKET_MAX_BLEN);

    ////////////////////////////////////////////////////////////////////////
    // Logic declarations

    logic [EGR_AXIS_DATA_BYTES*8-1:0]   send_packet_data [MAX_PKT_EGR_WLEN-1:0];
    int                                 send_packet_byte_length;
    logic [NUM_PORTS_LOG-1:0]           send_packet_egr_port;
    logic                               send_packet_req;
    logic                               send_packet_busy;

    int expected_count;
    int received_count_array [NUM_PORTS-1:0];
    int received_count;

    logic [NUM_PORTS-1:0] egr_phys_ports_tlast;
    logic packet_received;

    logic [NUM_8B_PORTS-1:0]  egr_8b_buf_overflow;
    logic [NUM_16B_PORTS-1:0] egr_16b_buf_overflow;
    logic [NUM_32B_PORTS-1:0] egr_32b_buf_overflow;
    logic [NUM_64B_PORTS-1:0] egr_64b_buf_overflow;

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
        .USER_WIDTH(NUM_PORTS_LOG)
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
            send_packet_busy = 1'b1;
            for (integer w = 0; w * EGR_AXIS_DATA_BYTES < send_packet_byte_length; w++) begin
                data.push_back(send_packet_data[w]);
            end
            driver_interface_inst.write_queue(.input_data(data), .user(send_packet_egr_port));
        end
    end

    // DUT
    mpls_egress #(
        .NUM_8B_EGR_PHYS_PORTS  ( NUM_8B_PORTS    ),
        .NUM_16B_EGR_PHYS_PORTS ( NUM_16B_PORTS   ),
        .NUM_32B_EGR_PHYS_PORTS ( NUM_32B_PORTS   ),
        .NUM_64B_EGR_PHYS_PORTS ( NUM_64B_PORTS   ),
        .MTU_BYTES              ( MTU_BYTES )
    ) DUT (
        .clk_ifc                ( clk_ifc               ),
        .sreset_ifc             ( sreset_ifc            ),
        .egr_8b_phys_ports      ( egr_8b_phys_ports     ),
        .egr_16b_phys_ports     ( egr_16b_phys_ports    ),
        .egr_32b_phys_ports     ( egr_32b_phys_ports    ),
        .egr_64b_phys_ports     ( egr_64b_phys_ports    ),
        .egr_bus                ( egr_bus               ),
        .egr_8b_buf_overflow    ( egr_8b_buf_overflow   ),
        .egr_16b_buf_overflow   ( egr_16b_buf_overflow  ),
        .egr_32b_buf_overflow   ( egr_32b_buf_overflow  ),
        .egr_64b_buf_overflow   ( egr_64b_buf_overflow  )
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
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[EGR_8B_INDEX][i]] = egr_8b_phys_ports[i].tready & egr_8b_phys_ports[i].tvalid & egr_8b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_16B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[EGR_16B_INDEX][i]] = egr_16b_phys_ports[i].tready & egr_16b_phys_ports[i].tvalid & egr_16b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_32B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[EGR_32B_INDEX][i]] = egr_32b_phys_ports[i].tready & egr_32b_phys_ports[i].tvalid & egr_32b_phys_ports[i].tlast;
        end
        for (genvar i=0; i<NUM_64B_PORTS; i++) begin
            assign egr_phys_ports_tlast[EGR_PORT_INDEX_MAP[EGR_64B_INDEX][i]] = egr_64b_phys_ports[i].tready & egr_64b_phys_ports[i].tvalid & egr_64b_phys_ports[i].tlast;
        end
    endgenerate

    always_ff @(posedge clk_ifc.clk ) begin
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            received_count_array <= '{default: 0};
            received_count = 0;
            seq_cnt <= 0;
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
                end
            end
        end
    end


    // Verify that there are no buffer overflows
    always_ff @( posedge clk_ifc.clk ) begin
        if (verify_no_overflows) begin
            `CHECK_EQUAL(egr_8b_buf_overflow , 0);
            `CHECK_EQUAL(egr_16b_buf_overflow, 0);
            `CHECK_EQUAL(egr_32b_buf_overflow, 0);
            `CHECK_EQUAL(egr_64b_buf_overflow, 0);
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

        automatic int packet_byte_length_word_aligned = packet_byte_length % EGR_AXIS_DATA_BYTES ? (packet_byte_length/EGR_AXIS_DATA_BYTES+1)*EGR_AXIS_DATA_BYTES : packet_byte_length;

        send_packet_byte_length = packet_byte_length_word_aligned;
        send_packet_egr_port = send_packet_port;

        // Wait till we can send data
        while(send_packet_busy) @(posedge clk_ifc.clk);
        axis_packet_formatter #( EGR_AXIS_DATA_BYTES,  MAX_PKT_EGR_WLEN , MTU_BYTES)::get_packet(packet_byte_length_word_aligned, send_packet_data);
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


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = 1'b0;
        end

        `TEST_CASE_SETUP begin
            sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
            send_packet_req = 1'b0;
            verify_no_overflows = 1'b0;
            verify_sequence = 1'b0;
            repeat (2) @(posedge clk_ifc.clk);
            sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge clk_ifc.clk);
        end

        // Send packets to all ports sequentially and wait for the packet to be output
        // before sending the next packet to verify that packets are getting muxed to the
        // correct port
        `TEST_CASE("verify_demux") begin
            verify_no_overflows = 1'b1;
            verify_sequence = 1'b1;
            expected_count = NUM_PACKETS_TO_SEND;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                wait (packet_received);
            end
        end
    end

    `WATCHDOG(10ms);

endmodule

module axis_array_pkt_chk #(
    parameter int NUM_PORTS = 0,
    parameter int PACKET_MAX_BLEN = 0,
    parameter int DATA_BYTES = 0
) (
    AXIS_int.Monitor    axis_in [NUM_PORTS]
);

    `ELAB_CHECK_GT(NUM_PORTS,0);
    `ELAB_CHECK_GT(PACKET_MAX_BLEN,0);
    `ELAB_CHECK_GT(DATA_BYTES,0);

    localparam WORD_BIT_WIDTH = DATA_BYTES*8;

    // in this test bench, packets consist of incrementing bytes
    // check data valid by comparing data byte to it's byte index
    task automatic validate_output_packet(
        input int blen,
        input [PACKET_MAX_BLEN*8-1:0] pkt
    );
        for (int b=0; b<blen; b++) begin
            `CHECK_EQUAL(pkt[b*8 +: 8], b % 256);
        end
    endtask

    generate
        for (genvar port=0; port<NUM_PORTS; port++) begin

            int                             wrw_ptr;
            logic [PACKET_MAX_BLEN*8-1:0]   output_buf;
            int                             output_packet_blen;
            int                             byte_cnt;
            logic                           tlast_d;

            always_ff @(posedge axis_in[port].clk) begin : packet_data_checker
                if (!axis_in[port].sresetn) begin
                    output_buf <= '{default: 0};
                    output_packet_blen <= 0;
                    tlast_d <= 0;
                end else begin

                    // Validate data
                    tlast_d <= axis_in[port].tlast;
                    if (tlast_d) begin
                        validate_output_packet(output_packet_blen, output_buf);
                    end

                    // Convert output packet from a sequence of words to a single logic vector
                    if (axis_in[port].tvalid & axis_in[port].tready) begin
                        output_buf[wrw_ptr*WORD_BIT_WIDTH +: WORD_BIT_WIDTH] <= axis_in[port].tdata;
                        if (axis_in[port].tlast) begin
                            wrw_ptr <= 0;
                            byte_cnt <= 0;
                            // add bytes from partial word to byte length
                            for (int b=$size(axis_in[port].tkeep)-1; b>=0; b--) begin
                                if (axis_in[port].tkeep[b]) begin
                                    output_packet_blen <= byte_cnt + b + 1;
                                    break;
                                end
                                if (b==0) begin
                                    $error("tlast is asserted by tkeep is zero.");
                                end
                            end
                        end else begin
                            byte_cnt <= byte_cnt + axis_in[port].DATA_BYTES;
                            wrw_ptr++;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule
