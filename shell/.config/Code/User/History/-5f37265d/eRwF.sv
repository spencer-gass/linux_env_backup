// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Test bench for mpls_ingress.
 * TODO
 * add variable config to .py
 * MR
 * move the comments at the top of mpls_ingress to notes
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps


module mpls_ingress_tb ();

    /////////////////////////////////////////////////////////////////////////
    // Parameter definition
    parameter int NUM_8B_PORTS  = 3;               // Number of 8-bit  physical ports to the DUT
    parameter int NUM_16B_PORTS = 0;               // Number of 16-bit physical ports to the DUT
    parameter int NUM_32B_PORTS = 3;               // Number of 32-bit physical ports to the DUT
    parameter int NUM_64B_PORTS = 0;               // Number of 640bit physical ports to the DUT
    parameter int CONVERGED_AXIS_DATA_BYTES = 8;   // Width of axis bus toward VNP4
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
        ING_8B_INDEX,
        ING_16B_INDEX,
        ING_32B_INDEX,
        ING_64B_INDEX,
        NUM_ING_AXIS_ARRAYS
    } port_width_indecies;

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;

    localparam int NUM_ING_PHYS_PORTS_PER_ARRAY [NUM_ING_AXIS_ARRAYS-1:0] = {NUM_64B_PORTS,
                                                                             NUM_32B_PORTS,
                                                                             NUM_16B_PORTS,
                                                                             NUM_8B_PORTS
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

    localparam int MAX_PKT_WLEN_8B  = PACKET_MAX_BLEN/BYTES_PER_8BIT_WORD;
    localparam int MAX_PKT_WLEN_16B = PACKET_MAX_BLEN/BYTES_PER_16BIT_WORD;
    localparam int MAX_PKT_WLEN_32B = PACKET_MAX_BLEN/BYTES_PER_32BIT_WORD;
    localparam int MAX_PKT_WLEN_64B = PACKET_MAX_BLEN/BYTES_PER_64BIT_WORD;

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int PACKET_MAX_BLEN_LOG = $clog2(PACKET_MAX_BLEN);

    ////////////////////////////////////////////////////////////////////////
    // Logic declarations

    logic [7:0]                         send_packet_data_8      [NUM_8B_PORTS-1:0]  [MAX_PKT_WLEN_8B-1:0];
    logic [15:0]                        send_packet_data_16     [NUM_16B_PORTS-1:0] [MAX_PKT_WLEN_16B-1:0];
    logic [31:0]                        send_packet_data_32     [NUM_32B_PORTS-1:0] [MAX_PKT_WLEN_32B-1:0];
    logic [63:0]                        send_packet_data_64     [NUM_64B_PORTS-1:0] [MAX_PKT_WLEN_64B-1:0];

    logic [PACKET_MAX_BLEN_LOG-1:0]     send_packet_byte_length [NUM_ING_AXIS_ARRAYS-1:0] [MAX_NUM_PORTS_PER_ARRAY-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_req         [NUM_ING_AXIS_ARRAYS-1:0];
    logic [MAX_NUM_PORTS_PER_ARRAY-1:0] send_packet_busy        [NUM_ING_AXIS_ARRAYS-1:0];

    int expected_count;
    int received_count;

    logic [NUM_8B_PORTS-1:0]  ing_8b_buf_overflow;
    logic [NUM_16B_PORTS-1:0] ing_16b_buf_overflow;
    logic [NUM_32B_PORTS-1:0] ing_32b_buf_overflow;
    logic [NUM_64B_PORTS-1:0] ing_64b_buf_overflow;

    logic check_sequential_port_nums;
    int port_seq_cnt;

    /////////////////////////////////////////////////////////////////////////
    // Internal Axis definitions

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) ing_8b_phys_ports [NUM_8B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) ing_16b_phys_ports [NUM_16B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) ing_32b_phys_ports [NUM_32B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) ing_64b_phys_ports [NUM_64B_PORTS-1:0] (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( CONVERGED_AXIS_DATA_BYTES ),
        .USER_WIDTH ( NUM_PORTS_LOG             )
    ) converged_ing_bus (
        .clk     (clk_ifc.clk       ),
        .sresetn (sreset_ifc.reset != sreset_ifc.ACTIVE_HIGH  )
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


    // Packet generators
    generate

        if (NUM_8B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_8B_PORTS              ),
                .AXIS_DATA_BYTES    ( BYTES_PER_8BIT_WORD       ),
                .PACKET_MAX_BLEN       ( PACKET_MAX_BLEN           )
            ) pkt_gen_8b (
                .axis_out           ( ing_8b_phys_ports                                 ),
                .busy               ( send_packet_busy[ING_8B_INDEX][NUM_8B_PORTS-1:0]  ),
                .send_req           ( send_packet_req[ING_8B_INDEX][NUM_8B_PORTS-1:0]   ),
                .packet_byte_length ( send_packet_byte_length[ING_8B_INDEX][NUM_8B_PORTS-1:0]),
                .packet_data        ( send_packet_data_8                                )
            );
        end

        if (NUM_16B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_16B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_16BIT_WORD      ),
                .PACKET_MAX_BLEN       ( PACKET_MAX_BLEN           )
            ) pkt_gen_16b (
                .axis_out           ( ing_16b_phys_ports                                    ),
                .busy               ( send_packet_busy[ING_16B_INDEX][NUM_16B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[ING_16B_INDEX][NUM_16B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[ING_16B_INDEX][NUM_16B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_16                                   )
            );
        end

        if (NUM_32B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_32B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_32BIT_WORD      ),
                .PACKET_MAX_BLEN       ( PACKET_MAX_BLEN           )
            ) pkt_gen_32b (
                .axis_out           ( ing_32b_phys_ports                                    ),
                .busy               ( send_packet_busy[ING_32B_INDEX][NUM_32B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[ING_32B_INDEX][NUM_32B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[ING_32B_INDEX][NUM_32B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_32                                   )
            );
        end

        if (NUM_64B_PORTS) begin
            axis_array_pkt_gen #(
                .NUM_PORTS          ( NUM_64B_PORTS             ),
                .AXIS_DATA_BYTES    ( BYTES_PER_64BIT_WORD      ),
                .PACKET_MAX_BLEN       ( PACKET_MAX_BLEN           )
            ) pkt_gen_64b (
                .axis_out           ( ing_64b_phys_ports                                    ),
                .busy               ( send_packet_busy[ING_64B_INDEX][NUM_64B_PORTS-1:0]    ),
                .send_req           ( send_packet_req[ING_64B_INDEX][NUM_64B_PORTS-1:0]     ),
                .packet_byte_length ( send_packet_byte_length[ING_64B_INDEX][NUM_64B_PORTS-1:0]  ),
                .packet_data        ( send_packet_data_64                                   )
            );
        end
    endgenerate

    // DUT
    mpls_ingress #(
        .NUM_8B_ING_PHYS_PORTS  ( NUM_8B_PORTS    ),
        .NUM_16B_ING_PHYS_PORTS ( NUM_16B_PORTS   ),
        .NUM_32B_ING_PHYS_PORTS ( NUM_32B_PORTS   ),
        .NUM_64B_ING_PHYS_PORTS ( NUM_64B_PORTS   ),
        .MTU_BYTES              ( MTU_BYTES )
    ) DUT (
        .clk_ifc                ( clk_ifc               ),
        .sreset_ifc             ( sreset_ifc            ),
        .ing_8b_phys_ports      ( ing_8b_phys_ports     ),
        .ing_16b_phys_ports     ( ing_16b_phys_ports    ),
        .ing_32b_phys_ports     ( ing_32b_phys_ports    ),
        .ing_64b_phys_ports     ( ing_64b_phys_ports    ),
        .converged_ing_bus      ( converged_ing_bus     ),
        .ing_8b_buf_overflow    ( ing_8b_buf_overflow   ),
        .ing_16b_buf_overflow   ( ing_16b_buf_overflow ),
        .ing_32b_buf_overflow   ( ing_32b_buf_overflow ),
        .ing_64b_buf_overflow   ( ing_64b_buf_overflow )
    );


    // Packet sink
    AXIS_sink #(
        .DATA_BYTES  ( converged_ing_bus.DATA_BYTES ),
        .ID_WIDTH    ( converged_ing_bus.ID_WIDTH   ),
        .DEST_WIDTH  ( converged_ing_bus.DEST_WIDTH ),
        .USER_WIDTH  ( converged_ing_bus.USER_WIDTH ),
        .ASSIGN_DELAY(1)
    ) axis_converged_bus_sink (
        .clk    ( converged_ing_bus.clk     ),
        .sresetn( converged_ing_bus.sresetn )
    );

    AXIS_sink_module axis_test_sink_module (
        .control( axis_converged_bus_sink ),
        .i      ( converged_ing_bus       )
    );

    always begin
        while (1) axis_converged_bus_sink.accept_wait;
    end


    // Receive packet counter
    always_ff @(posedge clk_ifc.clk) begin : rx_pkt_cntr
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            received_count <= 0;
        end else begin
            if (converged_ing_bus.tlast & converged_ing_bus.tvalid & converged_ing_bus.tready) begin
                received_count <= received_count + 1;
            end
        end
    end

    // Verify physical port index is inserted into tuser
    always_ff @( posedge clk_ifc.clk ) begin
        if (converged_ing_bus.tlast & converged_ing_bus.tvalid & converged_ing_bus.tready) begin
            `ELAB_CHECK_GE(converged_ing_bus.tuser, 0);
            `ELAB_CHECK_LT(converged_ing_bus.tuser, NUM_PORTS);
        end

        if (!check_sequential_port_nums) begin
            port_seq_cnt <= 0;
        end else if (converged_ing_bus.tlast & converged_ing_bus.tvalid & converged_ing_bus.tready) begin
            `ELAB_CHECK_EQUAL(converged_ing_bus.tuser, port_seq_cnt);
            port_seq_cnt = port_seq_cnt>=NUM_PORTS-1 ? 0 : port_seq_cnt+1;
        end
    end

    // Verify that there are no buffer overflows
    always_ff @( posedge clk_ifc.clk ) begin
        `CHECK_EQUAL(ing_8b_buf_overflow , 0);
        `CHECK_EQUAL(ing_16b_buf_overflow, 0);
        `CHECK_EQUAL(ing_32b_buf_overflow, 0);
        `CHECK_EQUAL(ing_64b_buf_overflow, 0);
    end

    // Validate Packet Data

    localparam WORD_BIT_WIDTH = CONVERGED_AXIS_DATA_BYTES*8;

    int                             wrw_ptr;
    logic [PACKET_MAX_BLEN*8-1:0]   output_buf;
    int                             output_packet_blen;
    int                             byte_cnt;
    logic                           tlast_d;

    `MAKE_AXIS_MONITOR(converged_ing_bus_monitor, converged_ing_bus);

    // in this test bench, packets consist of incrementing bytes
    // check data valid by comparing data byte to it's byte index
    task automatic validate_output_packet();
        for (int b=0; b<output_packet_blen; b++) begin
            `CHECK_EQUAL(output_buf[b*8 +: 8], b % 256);
        end
    endtask

    always_ff @(posedge clk_ifc.clk) begin : packet_data_checker
        if (sreset_ifc.reset == sreset_ifc.ACTIVE_HIGH) begin
            output_buf <= '{default: 0};
            output_packet_blen <= 0;
            tlast_d <= 0;
        end else begin

            // Validate data
            tlast_d <= converged_ing_bus_monitor.tlast;
            if (tlast_d) begin
                validate_output_packet;
            end

            // Convert output packet from a sequence of words to a single logic vector
            if (converged_ing_bus_monitor.tvalid & converged_ing_bus_monitor.tready) begin
                output_buf[wrw_ptr*WORD_BIT_WIDTH +: WORD_BIT_WIDTH] <= converged_ing_bus_monitor.tdata;
                if (converged_ing_bus_monitor.tlast) begin
                    wrw_ptr <= 0;
                    byte_cnt <= 0;
                    // add bytes from partial word to byte length
                    for (int b=$size(converged_ing_bus_monitor.tkeep)-1; b>=0; b--) begin
                        if (converged_ing_bus_monitor.tkeep[b]) begin
                            output_packet_blen <= byte_cnt + b + 1;
                            break;
                        end
                        if (b==0) begin
                            $error("tlast is asserted by tkeep is zero.");
                        end
                    end
                end else begin
                    byte_cnt <= byte_cnt + CONVERGED_AXIS_DATA_BYTES;
                    wrw_ptr++;
                end
            end

        end
    end

    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        automatic int port_width_index = get_port_width_index(send_packet_port);
        automatic int port_array_index = get_port_array_index(send_packet_port);
        // round byte length to a multiple of bytes per word to make checking easier
        automatic int bytes_per_word = 2**port_width_index;
        automatic int packet_byte_length_word_aligned = packet_byte_length % bytes_per_word ? (packet_byte_length/bytes_per_word+1)*bytes_per_word  : packet_byte_length;

        send_packet_byte_length[port_width_index][port_array_index] = packet_byte_length_word_aligned;

        // Wait till we can send data
        while(send_packet_busy [port_width_index][port_array_index]) @(posedge clk_ifc.clk);

        case (port_width_index)
            ING_8B_INDEX:  axis_packet_formatter #( BYTES_PER_8BIT_WORD,  MAX_PKT_WLEN_8B , MTU_BYTES)::get_packet(packet_byte_length_word_aligned, send_packet_data_8 [port_array_index]);
            ING_16B_INDEX: axis_packet_formatter #( BYTES_PER_16BIT_WORD, MAX_PKT_WLEN_16B, MTU_BYTES)::get_packet(packet_byte_length_word_aligned, send_packet_data_16[port_array_index]);
            ING_32B_INDEX: axis_packet_formatter #( BYTES_PER_32BIT_WORD, MAX_PKT_WLEN_32B, MTU_BYTES)::get_packet(packet_byte_length_word_aligned, send_packet_data_32[port_array_index]);
            ING_64B_INDEX: axis_packet_formatter #( BYTES_PER_64BIT_WORD, MAX_PKT_WLEN_64B, MTU_BYTES)::get_packet(packet_byte_length_word_aligned, send_packet_data_64[port_array_index]);
            default: ;
        endcase

        send_packet_req[port_width_index][port_array_index] = 1'b1;
        // Wait till its received
        while(!send_packet_busy[port_width_index][port_array_index]) @(posedge clk_ifc.clk);
        send_packet_req[port_width_index][port_array_index] = 1'b0;
        // Wait till its finished
        while(send_packet_busy[port_width_index][port_array_index]) @(posedge clk_ifc.clk);
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
        send_packet_req = '{default: '{default: 1'b0}};
    end

    `TEST_CASE_SETUP begin
        sreset_ifc.reset = sreset_ifc.ACTIVE_HIGH;
        send_packet_req = '{default: '{default: 1'b0}};
        check_sequential_port_nums = 1'b0;
        repeat (2) @(posedge clk_ifc.clk);
        sreset_ifc.reset = ~sreset_ifc.ACTIVE_HIGH;
        repeat (2) @(posedge clk_ifc.clk);
    end

    // Send packets to all ports simultaneously
    `TEST_CASE("send_all_ports_packets_simultaneously") begin

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
        for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

        // Check that expected equals received
        `CHECK_EQUAL(received_count, expected_count);
    end

    // Send packets to all ports sequentially
    // This allows tuser physical port index insertion validation
    `TEST_CASE("send_all_ports_packets_sequentially") begin

        automatic int phys_port = 0;

        check_sequential_port_nums = 1'b1;
        // Send packets to all interfacess in parallel
        for(int packet=0; packet<NUM_PACKETS_TO_SEND; packet++) begin
            send_random_length_packet(phys_port);
            phys_port = phys_port == NUM_PORTS-1 ? 0 : phys_port+1;
        end

        // Give time for all the packets to be received
        for (integer i = 0; i < PACKET_MAX_BLEN + 64; i++) @(posedge clk_ifc.clk);

        // Check that expected equals received
        `CHECK_EQUAL(received_count, NUM_PACKETS_TO_SEND);

    end
end

`WATCHDOG(10ms);

endmodule

// encapsulate packet gens into a module so that there can be one perameterized module instantiatoin per
// axis array ranther than four instances of nearly identical logic.
module axis_array_pkt_gen #(
    parameter NUM_PORTS = 0,
    parameter AXIS_DATA_BYTES = 0,
    parameter PACKET_MAX_BLEN = 16

) (
    AXIS_int.Master axis_out [NUM_PORTS-1:0],

    output var logic [NUM_PORTS-1:0]                busy,
    input  var logic [NUM_PORTS-1:0]                send_req,
    input  var logic [$clog2(PACKET_MAX_BLEN)-1:0]  packet_byte_length  [NUM_PORTS-1:0],
    input  var logic [AXIS_DATA_BYTES*8-1:0]        packet_data         [NUM_PORTS-1:0] [PACKET_MAX_BLEN/AXIS_DATA_BYTES-1:0]
);

    `ELAB_CHECK_GT(NUM_PORTS, 0);
    `ELAB_CHECK_GT(AXIS_DATA_BYTES, 0);

    generate
        for (genvar axis=0; axis < NUM_PORTS; axis++) begin

            AXIS_driver # (
                .DATA_BYTES(AXIS_DATA_BYTES)
            ) driver_interface_inst (
                .clk (axis_out[axis].clk),
                .sresetn(axis_out[axis].sresetn)
            );

            AXIS_driver_module driver_module_inst (
                .control (driver_interface_inst),
                .o ( axis_out[axis] )
            );

            always_ff @(posedge axis_out[axis].clk) begin
                busy[axis] = 1'b0;
                if (send_req[axis]) begin
                    automatic logic [AXIS_DATA_BYTES*8-1:0] data [$] = {};
                    busy[axis] = 1'b1;
                    for (integer w = 0; w * AXIS_DATA_BYTES < packet_byte_length[axis]; w++) begin
                        data.push_back(packet_data[axis][w]);
                    end
                    driver_interface_inst.write_queue(data);
                end
            end

        end
    endgenerate

endmodule
