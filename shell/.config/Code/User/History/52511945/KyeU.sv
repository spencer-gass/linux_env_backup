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

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int NUM_8B_PORTS  = 3;               // Number of 8-bit  physical ports to the DUT
    parameter int NUM_16B_PORTS = 0;               // Number of 16-bit physical ports to the DUT
    parameter int NUM_32B_PORTS = 3;               // Number of 32-bit physical ports to the DUT
    parameter int NUM_64B_PORTS = 0;               // Number of 640bit physical ports to the DUT
    parameter int EGR_AXIS_DATA_BYTES = 8;         // Width of axis bus toward VNP4
    parameter int MTU_BYTES = 1500;                // MTU for the router
    parameter int PACKET_MAX_BLEN = 1000;          // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;
    parameter int EGR_COUNTERS_WIDTH = 32;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Import

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::U_INT_CEIL_DIV;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam PAYLOAD_TYPE = INC;

    localparam int NUM_EGR_PHYS_PORTS_PER_ARRAY [NUM_EGR_AXIS_ARRAYS-1:0] = {NUM_64B_PORTS,
                                                                             NUM_32B_PORTS,
                                                                             NUM_16B_PORTS,
                                                                             NUM_8B_PORTS
                                                                          };

    localparam int NUM_PORTS      = NUM_8B_PORTS + NUM_16B_PORTS + NUM_32B_PORTS + NUM_64B_PORTS;
    localparam int NUM_PORTS_LOG  = $clog2(NUM_PORTS);

    localparam port_index_map_t EGR_PORT_INDEX_MAP = create_port_index_map(NUM_EGR_PHYS_PORTS_PER_ARRAY);
    localparam EGR_8B_START  = EGR_PORT_INDEX_MAP[INDEX_8B][0];
    localparam EGR_16B_START = EGR_PORT_INDEX_MAP[INDEX_16B][0];
    localparam EGR_32B_START = EGR_PORT_INDEX_MAP[INDEX_32B][0];
    localparam EGR_64B_START = EGR_PORT_INDEX_MAP[INDEX_64B][0];

    localparam int MAX_PKT_EGR_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, EGR_AXIS_DATA_BYTES);
    localparam int MAX_PKT_WLEN_8B  = PACKET_MAX_BLEN/BYTES_PER_8BIT_WORD;
    localparam int MAX_PKT_WLEN_16B = PACKET_MAX_BLEN/BYTES_PER_16BIT_WORD;
    localparam int MAX_PKT_WLEN_32B = PACKET_MAX_BLEN/BYTES_PER_32BIT_WORD;
    localparam int MAX_PKT_WLEN_64B = PACKET_MAX_BLEN/BYTES_PER_64BIT_WORD;

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int PACKET_MAX_BLEN_LOG = $clog2(PACKET_MAX_BLEN);
    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_PORTS-1:0]          egr_buf_ready;
    logic [NUM_PORTS-1:0]          egr_phys_ports_enable;
    logic [NUM_PORTS-1:0]          egr_cnts_clear;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_PORTS-1:0] [6:0];
    logic [NUM_PORTS-1:0]          egr_ports_conneted;

    int                                 send_packet_byte_length;
    vnp4_wrapper_metadata_t             send_packet_user;

    logic [MTU_BYTES*8-1:0]             send_packet_data;
    logic                               send_packet_req;
    logic                               send_packet_req_d;
    logic [NUM_PORTS-1:0]               send_packet_busy;

    int expected_count;
    int received_count_array [NUM_PORTS-1:0];
    int received_count;
    logic packet_received;

    logic [NUM_PORTS-1:0] egr_phys_ports_tlast;
    logic [NUM_PORTS-1:0] egr_phys_ports_tvalid;

    logic [EGR_COUNTERS_WIDTH-1:0] expected_egr_cnts [NUM_PORTS-1:0] [6:0];

    logic [NUM_PORTS-1:0]  egr_buf_full_drop;
    logic [NUM_PORTS-1:0]  egr_buf_full_drop_sticky;
    logic                  egr_buf_full_drop_clear;

    logic verify_no_overflows;
    logic verify_sequence;
    int seq_cnt;

    logic [MTU_BYTES*8-1:0]             tx_snoop_data_buf   [NUM_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf   [NUM_PORTS-1:0] [NUM_PACKETS_TO_SEND-1:0];
    logic [NUM_PACKETS_TO_SEND_LOG:0]   tx_snoop_wr_ptr     [NUM_PORTS-1:0];

    logic [MTU_BYTES*8-1:0]       send_data_buf        [NUM_PORTS-1:0];
    int                         send_byte_length_buf [NUM_PORTS-1:0];
    vnp4_wrapper_metadata_t     send_user_buf        [NUM_PORTS-1:0];
    int                         send_egr_port;
    int                         egr_port_rr;
    logic [EGR_AXIS_DATA_BYTES-1:0] tkeep_comb;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( EGR_AXIS_DATA_BYTES           ),
        .USER_WIDTH ( VNP4_WRAPPER_METADATA_WIDTH   )
    ) egr_bus (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) egr_8b_phys_ports [NUM_8B_PORTS-1:0] (
        .clk     (egr_port_clk_ifc.clk       ),
        .sresetn (egr_port_sreset_ifc.reset != egr_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) egr_16b_phys_ports [NUM_16B_PORTS-1:0] (
        .clk     (egr_port_clk_ifc.clk       ),
        .sresetn (egr_port_sreset_ifc.reset != egr_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) egr_32b_phys_ports [NUM_32B_PORTS-1:0] (
        .clk     (egr_port_clk_ifc.clk       ),
        .sresetn (egr_port_sreset_ifc.reset != egr_port_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) egr_64b_phys_ports [NUM_64B_PORTS-1:0] (
        .clk     (egr_port_clk_ifc.clk       ),
        .sresetn (egr_port_sreset_ifc.reset != egr_port_sreset_ifc.ACTIVE_HIGH )
    );

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) egr_port_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) egr_port_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implemenatation

    // Simulation clocks
    always #(PHYS_PORT_CLK_PERIOD/2) egr_port_clk_ifc.clk <= ~egr_port_clk_ifc.clk;
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk     <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet generator

    assign send_egr_port = send_packet_user.egress_port[NUM_PORTS_LOG-1:0];

    always_comb begin
        for (int port=0; port<NUM_PORTS; port++) begin
            send_packet_busy[port] = (send_byte_length_buf[port] === 0) ? 1'b0 : 1'b1;
        end
    end

    always_comb begin
        tkeep_comb = '0;
        for (int b=0; b<EGR_AXIS_DATA_BYTES; b++) begin
            if (send_byte_length_buf[egr_port_rr] % EGR_AXIS_DATA_BYTES == 0) begin
                tkeep_comb[b] = 1'b1;
            end else if (b < send_byte_length_buf[egr_port_rr] % EGR_AXIS_DATA_BYTES) begin
                tkeep_comb[b] = 1'b1;
            end
        end
    end

    logic [DQ_LATENCY-1:0] dq_in_flight [NUM_PORTS-1:0];
    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            send_data_buf        <= '{default: '0};
            send_byte_length_buf <= '{default: 0};
            send_user_buf        <= '{default: '0};
            egr_port_rr          <= 0;
            dq_in_flight         <= '{default: '0};
        end else begin
            if (send_packet_req && !send_packet_req_d && !send_packet_busy[send_egr_port]) begin
                send_data_buf[send_egr_port]        <= send_packet_data;
                send_byte_length_buf[send_egr_port] <= send_packet_byte_length;
                send_user_buf[send_egr_port]        <= send_packet_user;
            end

            if (egr_port_rr == NUM_PORTS-1) begin
                egr_port_rr <= 0;
            end else begin
                egr_port_rr <= egr_port_rr + 1;
            end

            for (int port=0; port<NUM_PORTS; port++) begin
                dq_in_flight[port] <= {dq_in_flight[port][DQ_LATENCY-2:0], 1'b0};
            end

            egr_bus.tlast <= 1'b0;
            egr_bus.tkeep <= '1;
            egr_bus.tvalid <= 1'b0;
            if (egr_buf_ready[egr_port_rr] && send_packet_busy[egr_port_rr] && ~|dq_in_flight[egr_port_rr]) begin
                egr_bus.tvalid <= 1'b1;
                egr_bus.tdata   <= send_data_buf[egr_port_rr][egr_bus.DATA_BYTES*8-1:0];
                egr_bus.tuser  <= send_user_buf[egr_port_rr];
                dq_in_flight[egr_port_rr][0] <= 1'b1;
                send_data_buf[egr_port_rr]  <= '0;
                send_data_buf[egr_port_rr]  <= send_data_buf[egr_port_rr][MTU_BYTES*8-1:egr_bus.DATA_BYTES*8];
                if (send_byte_length_buf[egr_port_rr] <= egr_bus.DATA_BYTES) begin
                    egr_bus.tlast <= 1'b1;
                    egr_bus.tkeep <= tkeep_comb;
                    send_byte_length_buf[egr_port_rr] <= 0;
                end else begin
                    send_byte_length_buf[egr_port_rr] <= send_byte_length_buf[egr_port_rr] - egr_bus.DATA_BYTES;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Tx Packet Capture

    always_ff @(posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf  <= '{default: '{default: '0}};
            tx_snoop_blen_buf  <= '{default: '{default: '0}};
            tx_snoop_wr_ptr    <= '{default: '0};
            send_packet_req_d  <= 1'b0;
        end else begin
            send_packet_req_d <= send_packet_req;
            if (send_packet_req && !send_packet_req_d) begin
                tx_snoop_data_buf[send_packet_user.egress_port][tx_snoop_wr_ptr[send_packet_user.egress_port]] <= send_packet_data;
                tx_snoop_blen_buf[send_packet_user.egress_port][tx_snoop_wr_ptr[send_packet_user.egress_port]] <= send_packet_byte_length;
                tx_snoop_wr_ptr[send_packet_user.egress_port]++;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_egress #(
        .NUM_8B_EGR_PHYS_PORTS  ( NUM_8B_PORTS      ),
        .NUM_16B_EGR_PHYS_PORTS ( NUM_16B_PORTS     ),
        .NUM_32B_EGR_PHYS_PORTS ( NUM_32B_PORTS     ),
        .NUM_64B_EGR_PHYS_PORTS ( NUM_64B_PORTS     ),
        .MTU_BYTES              ( MTU_BYTES         ),
        .EGR_COUNTERS_WIDTH     ( EGR_COUNTERS_WIDTH)
    ) DUT (
        .egr_bus                ( egr_bus               ),
        .egr_buf_ready          ( egr_buf_ready         ),
        .egr_8b_phys_ports      ( egr_8b_phys_ports     ),
        .egr_16b_phys_ports     ( egr_16b_phys_ports    ),
        .egr_32b_phys_ports     ( egr_32b_phys_ports    ),
        .egr_64b_phys_ports     ( egr_64b_phys_ports    ),
        .egr_phys_ports_enable  ( egr_phys_ports_enable ),
        .egr_cnts_clear         ( egr_cnts_clear        ),
        .egr_cnts               ( egr_cnts              ),
        .egr_ports_conneted     ( egr_ports_conneted    ),
        .egr_buf_full_drop      ( egr_buf_full_drop     )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Receive packet counter and demux verification

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

    always_ff @(posedge egr_port_clk_ifc.clk ) begin
        if (egr_port_sreset_ifc.reset == egr_port_sreset_ifc.ACTIVE_HIGH) begin
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
                    expected_egr_cnts[port][AXIS_PROFILE_PKT_CNT_INDEX]++;
                end
            end
        end
    end

    // Verify that there are no buffer overflows
    always_ff @( posedge core_clk_ifc.clk ) begin
        if (verify_no_overflows) begin
            `CHECK_EQUAL(egr_buf_full_drop , 0);
        end
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH || egr_buf_full_drop_clear) begin
           egr_buf_full_drop_sticky <= '0;
        end else begin
           egr_buf_full_drop_sticky <= egr_buf_full_drop_sticky | egr_buf_full_drop;
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sink and Check

    generate
        if (NUM_8B_PORTS) begin
            axis_array_packet_checker #(
                .NUM_PORTS                         ( NUM_8B_PORTS                            ),
                .MODULE_ID_STRING_0                ( "Width Index"                           ),
                .MODULE_ID_VALUE_0                 ( INDEX_8B                                ),
                .MODULE_ID_STRING_1                ( "Array Index"                           ),
                .AXIS_PACKET_IN_DATA_BYTES         ( egr_8b_phys_ports[0].DATA_BYTES         ),
                .AXIS_PACKET_IN_USER_WIDTH         ( egr_8b_phys_ports[0].USER_WIDTH         ),
                .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( egr_8b_phys_ports[0].ALLOW_BACKPRESSURE ),
                .MTU_BYTES                         ( MTU_BYTES                               ),
                .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND                     )
            )  packet_checker_8b  (
                .axis_packet_in ( egr_8b_phys_ports  ),
                .packet_in_id   ( '{default: '0}      ),
                .num_tx_pkts    ( tx_snoop_wr_ptr[EGR_8B_START +: NUM_8B_PORTS]  ),
                .expected_pkts  ( tx_snoop_data_buf[EGR_8B_START +: NUM_8B_PORTS]),
                .expected_blens ( tx_snoop_blen_buf[EGR_8B_START +: NUM_8B_PORTS]),
                .expected_ids   ( '{default: '{default: '0}}                     )
            );
        end

        if (NUM_16B_PORTS) begin
            axis_array_packet_checker #(
                .NUM_PORTS                         ( NUM_16B_PORTS                            ),
                .MODULE_ID_STRING_0                ( "Width Index"                            ),
                .MODULE_ID_VALUE_0                 ( INDEX_16B                                ),
                .MODULE_ID_STRING_1                ( "Array Index"                            ),
                .AXIS_PACKET_IN_DATA_BYTES         ( egr_16b_phys_ports[0].DATA_BYTES         ),
                .AXIS_PACKET_IN_USER_WIDTH         ( egr_16b_phys_ports[0].USER_WIDTH         ),
                .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( egr_16b_phys_ports[0].ALLOW_BACKPRESSURE ),
                .MTU_BYTES                         ( MTU_BYTES                                ),
                .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND                      )
            ) packet_checker_16b (
                .axis_packet_in ( egr_16b_phys_ports ),
                .packet_in_id   ( '{default: '0}      ),
                .num_tx_pkts    ( tx_snoop_wr_ptr[EGR_16B_START +: NUM_16B_PORTS]   ),
                .expected_pkts  ( tx_snoop_data_buf[EGR_16B_START +: NUM_16B_PORTS] ),
                .expected_blens ( tx_snoop_blen_buf[EGR_16B_START +: NUM_16B_PORTS] ),
                .expected_ids   ( '{default: '{default: '0}}                        )
            );
        end

        if (NUM_32B_PORTS) begin
            axis_array_packet_checker #(
                .NUM_PORTS                         ( NUM_32B_PORTS                            ),
                .MODULE_ID_STRING_0                ( "Width Index"                            ),
                .MODULE_ID_VALUE_0                 ( INDEX_32B                                ),
                .MODULE_ID_STRING_1                ( "Array Index"                            ),
                .AXIS_PACKET_IN_DATA_BYTES         ( egr_32b_phys_ports[0].DATA_BYTES         ),
                .AXIS_PACKET_IN_USER_WIDTH         ( egr_32b_phys_ports[0].USER_WIDTH         ),
                .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( egr_32b_phys_ports[0].ALLOW_BACKPRESSURE ),
                .MTU_BYTES                         ( MTU_BYTES                                ),
                .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND                      )
            ) packet_checker_32b (
                .axis_packet_in ( egr_32b_phys_ports ),
                .packet_in_id   ( '{default: '0}      ),
                .num_tx_pkts    ( tx_snoop_wr_ptr[EGR_32B_START +: NUM_32B_PORTS]   ),
                .expected_pkts  ( tx_snoop_data_buf[EGR_32B_START +: NUM_32B_PORTS] ),
                .expected_blens ( tx_snoop_blen_buf[EGR_32B_START +: NUM_32B_PORTS] ),
                .expected_ids   ( '{default: '{default: '0}}                        )
            );
        end

        if (NUM_64B_PORTS) begin
            axis_array_packet_checker #(
                .NUM_PORTS                         ( NUM_64B_PORTS                            ),
                .MODULE_ID_STRING_0                ( "Width Index"                            ),
                .MODULE_ID_VALUE_0                 ( INDEX_64B                                ),
                .MODULE_ID_STRING_1                ( "Array Index"                            ),
                .AXIS_PACKET_IN_DATA_BYTES         ( egr_64b_phys_ports[0].DATA_BYTES         ),
                .AXIS_PACKET_IN_USER_WIDTH         ( egr_64b_phys_ports[0].USER_WIDTH         ),
                .AXIS_PACKET_IN_ALLOW_BACKPRESSURE ( egr_64b_phys_ports[0].ALLOW_BACKPRESSURE ),
                .MTU_BYTES                         ( MTU_BYTES                                ),
                .NUM_PACKETS_BEING_SENT            ( NUM_PACKETS_TO_SEND                      )
            ) packet_checker_64b (
                .axis_packet_in ( egr_64b_phys_ports ),
                .packet_in_id   ( '{default: '0}      ),
                .num_tx_pkts    ( tx_snoop_wr_ptr[EGR_64B_START +: NUM_64B_PORTS]   ),
                .expected_pkts  ( tx_snoop_data_buf[EGR_64B_START +: NUM_64B_PORTS] ),
                .expected_blens ( tx_snoop_blen_buf[EGR_64B_START +: NUM_64B_PORTS] ),
                .expected_ids   ( '{default: '{default: '0}}                        )
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input int send_packet_port,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin


        // Wait till we can send data
        @(posedge core_clk_ifc.clk && !send_packet_busy[send_packet_port]);
        #1;
        send_packet_user.egress_port = send_packet_port;
        send_packet_byte_length = packet_byte_length;
        axis_packet_formatter #( EGR_AXIS_DATA_BYTES,  MAX_PKT_EGR_WLEN , MTU_BYTES)::get_packet(PAYLOAD_TYPE, packet_byte_length, send_packet_data);
        send_packet_req = 1'b1;
        @(posedge core_clk_ifc.clk);
        #1;
        send_packet_req = 1'b0;
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
            // Check that the expected number of packets were counted by the DUT egress counters
            `CHECK_EQUAL(egr_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], expected_egr_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX]);
            // Verify that the DUT egrress counters clears and don't disrupt other counts
            egr_cnts_clear[i] = 1'b1;
            @(posedge core_clk_ifc.clk);
            #1;
            `CHECK_EQUAL(egr_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX], 0);
        end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            core_clk_ifc.clk = 1'b0;
            egr_port_clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = 1'b0;
        end

        `TEST_CASE_SETUP begin
            egr_cnts_clear = '0;
            egr_phys_ports_enable = '1;
            egr_buf_full_drop_clear <= 1'b0;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            egr_port_sreset_ifc.reset = egr_port_sreset_ifc.ACTIVE_HIGH;
            send_packet_req = 1'b0;
            verify_no_overflows = 1'b0;
            verify_sequence = 1'b0;
            expected_count = NUM_PACKETS_TO_SEND;
            repeat (10) @(posedge egr_port_clk_ifc.clk);
            egr_port_sreset_ifc.reset = ~egr_port_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        // Send packets to all ports
        `TEST_CASE("send_to_all_ports") begin

            automatic int pkt_blen;
            automatic int pkt_port;
            automatic bit egress_active = 1'b1;

            verify_no_overflows = 1'b1;
            expected_count = NUM_PACKETS_TO_SEND;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                // Send random length packet to each port sequentially
                pkt_blen = $urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN);
                pkt_port = pkt % NUM_PORTS;
                send_packet(pkt_port, pkt_blen);
                // @(core_clk_ifc.clk);
            end

            // wait for packets to exit the DUT
            while (egress_active) begin
                egress_active = 1'b0;
                for (int i=0; i<64; i++) begin
                    @(posedge egr_port_clk_ifc.clk);
                    #1;
                    egress_active = egress_active | |egr_phys_ports_tvalid;
                end
            end
            repeat (MAX_PKT_WLEN_8B) @(posedge egr_port_clk_ifc.clk);
            @(core_clk_ifc.clk);


            check_pkt_cnts;
        end

        // Send packets with all ports disabled
        `TEST_CASE("disable_all_ports") begin
            verify_no_overflows = 1'b1;
            egr_phys_ports_enable = '0;
            expected_count = 0;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                repeat (100) @(posedge core_clk_ifc.clk);
            end
            check_pkt_cnts;
        end

        // Send packets with one port disabled
        `TEST_CASE("disable_one_port") begin
            verify_no_overflows = 1'b1;
            egr_phys_ports_enable = '0;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_length_packet(pkt % NUM_PORTS);
                repeat (100) @(posedge core_clk_ifc.clk);
            end
            expected_count = 0;
            for (int i=0; i<NUM_PORTS; i++) begin
                expected_count += egr_cnts[i][AXIS_PROFILE_PKT_CNT_INDEX];
            end
            check_pkt_cnts;
        end
    end

    `WATCHDOG(10ms);


endmodule
