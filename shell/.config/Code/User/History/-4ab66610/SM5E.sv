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


module vnp4_ipv4_user_extern_tb ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter definition

    parameter int AXIS_DATA_BYTES = 64;     // Width of axis bus toward VNP4
    parameter int MTU_BYTES = 1500;         // MTU for the router
    parameter int PACKET_MAX_BLEN = 1500;   // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;     // Minimum packet size in BYTES
    parameter int NUM_PACKETS_TO_SEND = 100;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Import

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import ipv4_checksum_tb_pkg::*;
    import vitis_net_p4_passthrough_with_ipv4_user_extern_pkg::*;
    import UTIL_INTS::U_INT_CEIL_DIV;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int MAX_PKT_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, AXIS_DATA_BYTES);

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int PACKET_MAX_BLEN_LOG = $clog2(PACKET_MAX_BLEN);
    localparam int NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND);

    localparam IPV4_HEADER_BYTES = 20;
    localparam IPV4_HEADER_CHECKSUM_BYTES = 2;
    localparam IPV4_HEADER_BITS = 8*IPV4_HEADER_BYTES;
    localparam IPV4_HEADER_CHECKSUM_BITS = 8*IPV4_HEADER_CHECKSUM_BYTES;
    localparam IPV4_UPDATE_IN_DATA_BYTES = 6;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function automatic logic [PACKET_MAX_BLEN*8-1:0] update_ipv4_ttl_and_checksum (
        input var logic [0:PACKET_MAX_BLEN*8-1] pkt
    );
        automatic eth_header_t  eth_hdr = pkt[0 : ETH_HEADER_BYTES*8-1];
        automatic ipv4_header_t ip_hdr = pkt[ETH_HEADER_BYTES*8 +: IPV4_HEADER_BYTES];
        automatic logic [0 : (PACKET_MAX_BLEN-ETH_HEADER_BYTES-IPV4_HEADER_BYTES)*8-1] payload = pkt[(ETH_HEADER_BYTES+IPV4_HEADER_BYTES)*8 : PACKET_MAX_BLEN*8-1];

        ip_hdr.hdr_chk = checksum_update_func(ip_hdr.hdr_chk, ip_hdr.ttl, ip_hdr.ttl-1);
        ip_hdr.ttl--;

        return {eth_hdr, ip_hdr, payload};
    endfunction

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    USER_META_DATA_T user_metadata_in_p4;
    USER_META_DATA_T user_metadata_out_p4;

    USER_EXTERN_IN_T    user_extern_in;
    USER_EXTERN_VALID_T user_extern_in_valid;
    USER_EXTERN_OUT_T   user_extern_out;
    USER_EXTERN_VALID_T user_extern_out_valid;

    logic [IPV4_UPDATE_IN_DATA_BYTES*8-1:0] user_ipv4_chk_update;
    logic user_metadata_in_valid;
    logic user_metadata_out_valid;

    logic                       send_packet_req;
    logic                       send_packet_req_d;
    logic [0:MTU_BYTES*8-1]     send_packet_data;
    int                         send_packet_byte_length;
    vnp4_wrapper_metadata_t     send_packet_user;
    logic                       send_packet_busy;
    int                         send_packet_wcnt;
    logic [AXIS_DATA_BYTES-1:0] keep_comb;

    int expected_count;
    int received_count;

    logic [MTU_BYTES*8-1:0]             tx_snoop_data_buf [NUM_PACKETS_TO_SEND-1:0];
    logic [MTU_BYTES_LOG-1:0]           tx_snoop_blen_buf [NUM_PACKETS_TO_SEND-1:0];
    int                                 tx_snoop_wr_ptr;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: AXIS Declarations

    AXIS_int #(
        .DATA_BYTES ( AXIS_DATA_BYTES        ),
        .USER_WIDTH ( USER_META_DATA_WIDTH   )
    ) packet_in (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( AXIS_DATA_BYTES        ),
        .USER_WIDTH ( USER_META_DATA_WIDTH   )
    ) packet_out (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_verif_req (
        .clk        (packet_in.clk),
        .sresetn    (packet_in.sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( 1 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) ip_chksum_verif_resp (
        .clk        (packet_in.clk),
        .sresetn    (packet_in.sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_UPDATE_IN_DATA_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_gen_req (
        .clk        (packet_in.clk),
        .sresetn    (packet_in.sresetn)
    );

    AXIS_int #(
        .DATA_BYTES         ( IPV4_HEADER_CHECKSUM_BYTES ),
        .ALLOW_BACKPRESSURE ( 0  )
    ) ip_chksum_gen_resp (
        .clk        (packet_in.clk),
        .sresetn    (packet_in.sresetn)
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

    // Simulation clock
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk     <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet generator

    always_comb begin
        for (int i=0; i<packet_in.DATA_BYTES; i++) begin
            if (i < send_packet_byte_length % packet_in.DATA_BYTES) begin
                keep_comb[i] = 1'b1;
            end else begin
                keep_comb[i] = 1'b0;
            end
        end
        if (send_packet_byte_length % packet_in.DATA_BYTES == 0) begin
            keep_comb = '1;
        end
    end

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            send_packet_busy <= 1'b0;
        end else begin
            if (send_packet_req && !send_packet_req_d && !send_packet_busy) begin
                send_packet_busy <= 1'b1;
                send_packet_wcnt <= 1;
            end

            packet_in.tvalid <= send_packet_busy;
            if ((packet_in.tready || !packet_in.tvalid) && send_packet_busy) begin
                packet_in.tdata  <= send_packet_data[0:packet_in.DATA_BYTES*8-1];
                packet_in.tuser  <= send_packet_user;
                send_packet_data  <= '0;
                send_packet_data  <= send_packet_data[packet_in.DATA_BYTES*8:MTU_BYTES*8-1];
                if (send_packet_wcnt * packet_in.DATA_BYTES >= send_packet_byte_length) begin
                    packet_in.tlast <= 1'b1;
                    packet_in.tkeep <= keep_comb;
                    send_packet_wcnt <= 0;
                    send_packet_busy <= 1'b0;
                end else begin
                    packet_in.tlast <= 1'b0;
                    send_packet_wcnt++;
                    packet_in.tkeep <= '1;
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  Tx Packet Capture

    always_ff @(posedge core_clk_ifc.clk ) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            tx_snoop_data_buf  <= '{default: '0};
            tx_snoop_blen_buf  <= '{default: '0};
            tx_snoop_wr_ptr    <= '0;
            send_packet_req_d  <= 1'b0;
        end else begin
            send_packet_req_d <= send_packet_req;
            if (send_packet_req && !send_packet_req_d) begin
                tx_snoop_data_buf[tx_snoop_wr_ptr] <= update_ipv4_ttl_and_checksum(send_packet_data);
                tx_snoop_blen_buf[tx_snoop_wr_ptr] <= send_packet_byte_length;
                tx_snoop_wr_ptr++;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    vitis_net_p4_passthrough_with_ipv4_user_extern dut (
        .s_axis_aclk                ( core_clk_ifc.clk          ),
        .s_axis_aresetn             ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH ),
        .s_axi_aclk                 ( core_clk_ifc.clk          ),
        .s_axi_aresetn              ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH           ),
        .user_metadata_in           ( user_metadata_in_p4   ),
        .user_metadata_in_valid     ( user_metadata_in_valid    ),
        .user_metadata_out          ( user_metadata_out_p4  ),
        .user_metadata_out_valid    ( user_metadata_out_valid   ),
        .irq                        (              ),
        .user_extern_in             ( user_extern_in            ),
        .user_extern_in_valid       ( user_extern_in_valid      ),
        .user_extern_out            ( user_extern_out           ),
        .user_extern_out_valid      ( user_extern_out_valid     ),
        .s_axis_tdata               ( packet_in.tdata           ),
        .s_axis_tkeep               ( packet_in.tkeep           ),
        .s_axis_tlast               ( packet_in.tlast           ),
        .s_axis_tvalid              ( packet_in.tvalid          ),
        .s_axis_tready              ( packet_in.tready          ),
        .m_axis_tdata               ( packet_out.tdata          ),
        .m_axis_tkeep               ( packet_out.tkeep          ),
        .m_axis_tlast               ( packet_out.tlast          ),
        .m_axis_tvalid              ( packet_out.tvalid         ),
        .m_axis_tready              ( packet_out.tready         ),
        .s_axi_araddr               ( '0    ),
        .s_axi_arready              (       ),
        .s_axi_arvalid              ( 1'b0  ),
        .s_axi_awaddr               ( '0    ),
        .s_axi_awready              (       ),
        .s_axi_awvalid              ( 1'b0  ),
        .s_axi_bready               (       ),
        .s_axi_bresp                ( '0    ),
        .s_axi_bvalid               ( 1'b0  ),
        .s_axi_rdata                (       ),
        .s_axi_rready               ( 1'b1  ),
        .s_axi_rresp                (       ),
        .s_axi_rvalid               (       ),
        .s_axi_wdata                ( '0    ),
        .s_axi_wready               (       ),
        .s_axi_wstrb                ( '1    ),
        .s_axi_wvalid               ( 1'b0  )
        );

        axis_to_user_extern #(
            .UE_IN_DATA_BITS  ( IPV4_HEADER_BITS ),
            .UE_OUT_DATA_BITS ( 1   )
        ) ipv4_checksum_verfiy_req_converter (
            .user_extern_data_in        ( user_extern_out.UserIPv4ChkVerify       ),
            .user_extern_valid_in       ( user_extern_out_valid.UserIPv4ChkVerify ),
            .user_extern_data_out       ( user_extern_in.UserIPv4ChkVerify        ),
            .user_extern_valid_out      ( user_extern_in_valid.UserIPv4ChkVerify  ),
            .axis_out                   ( ip_chksum_verif_req                     ),
            .axis_in                    ( ip_chksum_verif_resp                    )
        );

        ipv4_checksum_verify ipv4_checksum_verfier (
            .ipv4_header            ( ip_chksum_verif_req   ),
            .ipv4_checksum_valid    ( ip_chksum_verif_resp  )
        );

        assign user_ipv4_chk_update[47:32] = user_extern_out.UserIPv4ChkUpdate.hdr_chk;
        assign user_ipv4_chk_update[31:16] = {8'b00, user_extern_out.UserIPv4ChkUpdate.old_ttl};
        assign user_ipv4_chk_update[15:0 ] = {8'b00, user_extern_out.UserIPv4ChkUpdate.new_ttl};

        axis_to_user_extern #(
            .UE_IN_DATA_BITS  ( IPV4_UPDATE_IN_DATA_BYTES   ),
            .UE_OUT_DATA_BITS ( IPV4_HEADER_CHECKSUM_BITS   )
        ) ipv4_checksum_gen_req_converter (
            .user_extern_data_in        ( user_ipv4_chk_update                    ),
            .user_extern_valid_in       ( user_extern_out_valid.UserIPv4ChkUpdate ),
            .user_extern_data_out       ( user_extern_in.UserIPv4ChkUpdate        ),
            .user_extern_valid_out      ( user_extern_in_valid.UserIPv4ChkUpdate  ),
            .axis_out                   ( ip_chksum_gen_req                       ),
            .axis_in                    ( ip_chksum_gen_resp                      )
        );

        ipv4_checksum_update ipv4_checksum_updater (
            .update_req     ( ip_chksum_gen_req     ),
            .new_checksum   ( ip_chksum_gen_resp    )
        );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sink and Check

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            received_count = 0;
        end else begin
            if (packet_out.tvalid && packet_out.tlast) begin
                received_count++;
            end
        end
    end

    axis_packet_checker #(
        // .PKT_ID_STRING              ( "Ingress Port"        ),
        // .NUM_PKT_IDS                ( NUM_PORTS             ),
        .MTU_BYTES                  ( MTU_BYTES             ),
        .NUM_PACKETS_BEING_SENT     ( NUM_PACKETS_TO_SEND   )
    ) packet_checker (
        .axis_packet_in ( packet_out            ),
        .packet_in_id   ( '0                    ),
        .num_tx_pkts    ( tx_snoop_wr_ptr       ),
        .expected_pkts  ( tx_snoop_data_buf     ),
        .expected_blens ( tx_snoop_blen_buf     ),
        .expected_ids   ( '{default: '0}        ),
        .interpacket_gap ( 0                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input int ingress_port,
        input int ipv4_ttl,
        input logic [MTU_BYTES_LOG-1:0] packet_byte_length
    ); begin

        automatic eth_header_t eth_hdr = '{
            ether_type  : IPV4_ETHER_TYPE,
            default     : '0
        };

        automatic ipv4_header_t ip_hdr = '{
            version : IPV4_VERSION,
            hdr_len : IPV4_IHL,
            length  : packet_byte_length,
            ttl     : ipv4_ttl,
            default : '0
        };

        automatic logic [0 : (ETH_HEADER_BYTES + IPV4_HEADER_BYTES) * 8 - 1] header;

        ip_hdr.hdr_chk = ipv4_checksum_gen_func(ip_hdr);
        header = {eth_hdr, ip_hdr};

        // Wait till we can send data
        @(posedge core_clk_ifc.clk && !send_packet_busy);
        #1;

        for (int b=ETH_HEADER_BYTES+IPV4_HEADER_BYTES; b<PACKET_MAX_BLEN; b++) begin
            send_packet_data[b*8 +: 8] = b-ETH_HEADER_BYTES+IPV4_HEADER_BYTES;
        end
        send_packet_data[0:(ETH_HEADER_BYTES+IPV4_HEADER_BYTES)*8-1] = header;
        send_packet_user.ingress_port = ingress_port;
        send_packet_user.byte_length = packet_byte_length;
        send_packet_byte_length = packet_byte_length;
        send_packet_req = 1'b1;
        @(posedge core_clk_ifc.clk);
        #1;
        send_packet_req = 1'b0;
    end
    endtask;

    task automatic send_random_packet;
        send_packet(
            .ingress_port       ($urandom_range(0,7)),
            .ipv4_ttl           ($urandom_range(1,2**16-1)),
            .packet_byte_length ($urandom_range(PACKET_MAX_BLEN, PACKET_MIN_BLEN))
        );
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            core_clk_ifc.clk = 1'b0;
            $timeformat(-9, 3, " ns", 20);
            send_packet_req = 1'b0;
        end

        `TEST_CASE_SETUP begin
            send_packet_req = 1'b0;
            expected_count = NUM_PACKETS_TO_SEND;

            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;

            repeat (8) @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        `TEST_CASE("smoke_test") begin

            automatic bit packet_out_active = 1'b1;

            expected_count = NUM_PACKETS_TO_SEND;

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++) begin
                send_random_packet;
            end

            // wait for packets to exit the DUT
            while (packet_out_active) begin
                packet_out_active = 1'b0;
                for (int i=0; i<64; i++) begin
                    @(posedge core_clk_ifc.clk);
                    #1;
                    packet_out_active = packet_out_active | packet_out.tvalid;
                end
            end

            `CHECK_EQUAL(received_count, expected_count);
        end
    end

    `WATCHDOG(10ms);


endmodule
