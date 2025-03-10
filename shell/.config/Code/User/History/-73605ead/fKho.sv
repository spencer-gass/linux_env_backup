// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for ethernet_ip_packet_src.
 */
 module ethernet_ip_packet_src_tb();
    import AVMM_TEST_DRIVER_PKG::*;
    import AVMM_COMMON_REGS_PKG::*;


    /////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constants Delcarations

    parameter  int                 PACKET_LENGTH                               = 10;


    localparam bit  [15:0]          MODULE_VERSION                              = 0;
    localparam bit  [15:0]          MODULE_ID                                   = 0;


    localparam  bit [47:0]          MAC_ADDR_SRC                                = 48'haa_aa_aa_aa_bb_aa;

    localparam int                  CLK_HALF_PERIOD_AVMM                        = 10;
    localparam int                  CLK_HALF_PERIOD_AXIS                        = 12;

    localparam int                  DATALEN                                     = 32;
    localparam int                  ADDRLEN                                     = 32;
    localparam int                  BURSTLEN                                    = 1;
    localparam int                  BURST_CAPABLE                               = 0;

    localparam int GPOUT_OFFSET = 5;

    localparam int SHAPER_1G   = 32'h01000000;
    localparam int SHAPER_500M = 32'h00800000;
    localparam int SHAPER_100M = 32'h0019999A;
    localparam int SHAPER_1M   = 32'h00004189;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    var   logic     axis_clk;
    var   logic     axis_reset_n;



    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) avmm_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) peripheral_sreset_ifc ();

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_tx (
        .clk     ( axis_clk                   ),
        .sresetn ( axis_reset_n )
    );


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_rx (
        .clk     ( axis_clk                   ),
        .sresetn ( axis_reset_n )
    );


    AvalonMM_int #(
        .DATALEN       ( DATALEN        ),
        .ADDRLEN       ( ADDRLEN        ),
        .BURSTLEN      ( BURSTLEN       ),
        .BURST_CAPABLE ( BURST_CAPABLE  )
    ) avmm ();

    avmm_m_test_driver #(
        .DATALEN          ( DATALEN       ),
        .ADDRLEN          ( ADDRLEN       ),
        .BURSTLEN         ( BURSTLEN      ),
        .BURST_CAPABLE    ( BURST_CAPABLE )
    ) avmm_driver;


    // Signals and Queues
    var   logic                [ADDRLEN-1:0]   test_address;
    var   logic               [BURSTLEN-1:0]   test_burstcount; // burstcount should always be 1, since this module can't do bursts.
    var   logic              [DATALEN/8-1:0]   test_byteenable;
    var   logic              [DATALEN/8-1:0]   test_byteenable_queue [$];
    var   logic                        [1:0]   test_response,               result_response;
    var   logic                        [1:0]   test_response_queue [$],     result_response_queue [$];
    var   logic                [DATALEN-1:0]   writedata_queue [$], test_data_queue [$];
    var   logic                [DATALEN-1:0]   test_readdata_queue [$],     result_readdata_queue [$];
    var   logic                [DATALEN-1:0]   test_readdata, result_readdata;


    GMII_int #() gmii_tx ();
    GMII_int #() gmii_rx ();


    logic tx_error_underflow;
    logic tx_fifo_overflow;
    logic tx_fifo_bad_frame;
    logic tx_fifo_good_frame;
    logic rx_error_bad_frame;
    logic rx_error_bad_fcs;
    logic rx_fifo_overflow;
    logic rx_fifo_bad_frame;
    logic rx_fifo_good_frame;


    logic [7:0] gmii_rx_d ;
    logic       gmii_rx_dv;
    logic       gmii_rx_er;
    logic [7:0] gmii_tx_d ;
    logic       gmii_tx_en;
    logic       gmii_tx_er;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers




    // Device Under Test
    ethernet_ip_packet_src # (
        .MODULE_VERSION      ( MODULE_VERSION      ),
        .MODULE_ID           ( MODULE_ID           ),
        .PACKET_LENGTH       ( PACKET_LENGTH       ),
        .MAC_ADDR_SRC        ( MAC_ADDR_SRC        )
    ) DUT (
        .clk_ifc_avmm            ( avmm_clk_ifc            ),
        .avmm                    ( avmm                    ),
        .axis_out                    (axis_tx),
        .sreset_ifc_avmm_peripheral  (peripheral_sreset_ifc),
        .sreset_ifc_avmm_interconnect(interconnect_sreset_ifc)
    );



        eth_mac_1g_fifo #(
                    .AXIS_DATA_WIDTH    ( 8                           ),
                    .AXIS_KEEP_ENABLE   ( 0                           ),
                    .MIN_FRAME_LENGTH   ( 64                          ),
                    .ENABLE_PADDING     ( 1                           ),
                    .TX_FIFO_DEPTH      ( 2**12 ),
                    .TX_FRAME_FIFO      ( 1                           ),
                    .TX_DROP_BAD_FRAME  ( 1                           ),
                    .TX_DROP_WHEN_FULL  ( 1                           ),
                    .RX_FIFO_DEPTH      ( 2**12 ),
                    .RX_FRAME_FIFO      ( 1                           ),
                    .RX_DROP_BAD_FRAME  ( 1                           ),
                    .RX_DROP_WHEN_FULL  ( 1                           )
                ) gmii_phy_fifo (
                    .rx_clk             ( avmm_clk_ifc.clk),
                    .rx_rst             ( peripheral_sreset_ifc.reset ),

                    .tx_clk             ( avmm_clk_ifc.clk),
                    .tx_rst             ( peripheral_sreset_ifc.reset ),

                    .logic_clk          ( axis_clk),
                    .logic_rst          ( ~axis_reset_n ),

                    .tx_axis_tdata      ( axis_tx.tdata  ),
                    .tx_axis_tkeep      ( '1             ),
                    .tx_axis_tvalid     ( axis_tx.tvalid ),
                    .tx_axis_tready     ( axis_tx.tready ),
                    .tx_axis_tlast      ( axis_tx.tlast  ),
                    .tx_axis_tuser      ( axis_tx.tuser  ),

                    .rx_axis_tdata      ( axis_rx.tdata  ),
                    .rx_axis_tkeep      ( axis_rx.tkeep  ),
                    .rx_axis_tvalid     ( axis_rx.tvalid ),
                    .rx_axis_tready     ( axis_rx.tready ),
                    .rx_axis_tlast      ( axis_rx.tlast  ),
                    .rx_axis_tuser      ( axis_rx.tuser  ),

                    .gmii_rxd           ( gmii_rx_d   ),
                    .gmii_rx_dv         ( gmii_rx_dv  ),
                    .gmii_rx_er         ( gmii_rx_er  ),

                    .gmii_txd           ( gmii_tx_d  ),
                    .gmii_tx_en         ( gmii_tx_en ),
                    .gmii_tx_er         ( gmii_tx_er ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow (tx_error_underflow),
                    .tx_fifo_overflow   (tx_fifo_overflow  ),
                    .tx_fifo_bad_frame  (tx_fifo_bad_frame ),
                    .tx_fifo_good_frame (tx_fifo_good_frame),
                    .rx_error_bad_frame (rx_error_bad_frame),
                    .rx_error_bad_fcs   (rx_error_bad_fcs  ),
                    .rx_fifo_overflow   (rx_fifo_overflow  ),
                    .rx_fifo_bad_frame  (rx_fifo_bad_frame ),
                    .rx_fifo_good_frame (rx_fifo_good_frame)
                );

    // gmii loopback
    assign gmii_rx_d = gmii_tx_d;
    assign gmii_rx_dv = gmii_tx_en;
    assign gmii_rx_er = gmii_tx_er;


    axis_nul_sink   rx_sink  ( .axis ( axis_rx) );
    // Simulation Clocks
    always #CLK_HALF_PERIOD_AVMM avmm_clk_ifc.clk = ~avmm_clk_ifc.clk;
    always #CLK_HALF_PERIOD_AXIS axis_clk         = ~axis_clk;

    task automatic set_header;
        //SET ip_eth_type
        avmm_driver.write_data((16+GPOUT_OFFSET+3) << 2, {32'h0806}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);


        //SET ip_dscp
        avmm_driver.write_data((16+GPOUT_OFFSET+4) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_ecn
        avmm_driver.write_data((16+GPOUT_OFFSET+5) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_identification
        avmm_driver.write_data((16+GPOUT_OFFSET+7) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_flags
        avmm_driver.write_data((16+GPOUT_OFFSET+8) << 2, {32'b010}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_fragment_offset
        avmm_driver.write_data((16+GPOUT_OFFSET+9) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_ttl
        avmm_driver.write_data((16+GPOUT_OFFSET+10) << 2, {32'h2}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_protocol = ICMP
        avmm_driver.write_data((16+GPOUT_OFFSET+11) << 2, {32'h1}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_source_ip = 192.168.109.10
        avmm_driver.write_data((16+GPOUT_OFFSET+12) << 2, {32'hc0_a8_6d_0a}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET ip_dest_ip = 192.168.109.1
        avmm_driver.write_data((16+GPOUT_OFFSET+13) << 2, {32'hc0_a8_6d_01}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);


        //SET PACKET_LENGTH
        avmm_driver.write_data((16+GPOUT_OFFSET+6) << 2, {PACKET_LENGTH}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);


        //SET DEST_MAC_MSB
        avmm_driver.write_data((16+GPOUT_OFFSET+14) << 2, {32'hff_ff}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

        //SET DEST_MAC_LSB
        avmm_driver.write_data((16+GPOUT_OFFSET+15) << 2, {32'hff_ff_ff_ff}, test_byteenable_queue, test_burstcount, result_response);
        `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);
    endtask


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk = 1'b0;
            axis_clk         = 1'b1;
            interconnect_sreset_ifc.reset = 1'b0;
            peripheral_sreset_ifc.reset = 1'b0;
            axis_reset_n                = 1'b1;

            avmm_driver = new (
                .clk_ifc                    ( avmm_clk_ifc              ),
                .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
                .avmm                       ( avmm                      )
            );
        end

        `TEST_CASE_SETUP begin
            avmm_driver.init();

            @(posedge axis_clk);
            axis_reset_n                    = 1'b0;

            @(posedge axis_clk);
            axis_reset_n                    = 1'b1;

            @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset   = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset     = peripheral_sreset_ifc.ACTIVE_HIGH;

            @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset   = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset     = ~peripheral_sreset_ifc.ACTIVE_HIGH;

            @(posedge avmm_clk_ifc.clk);
        end


        `TEST_CASE("send_packets") begin
            automatic logic tx_active = 1'b1;

            test_byteenable         = '1;
            test_byteenable_queue   = { test_byteenable };
            test_burstcount         = 1;

            set_header;

            //SET NUM_PACKETS
            avmm_driver.write_data((16+GPOUT_OFFSET+1) << 2, {32'h5}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);
            //SET SHAPER
            avmm_driver.write_data((16+GPOUT_OFFSET+2) << 2, {32'h0FFFFFFF}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);
            repeat (2) begin
                //START
                avmm_driver.write_data((16+GPOUT_OFFSET+0) << 2, {32'h1}, test_byteenable_queue, test_burstcount, result_response);
                `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);


                while (tx_active) begin
                    tx_active = 1'b0;
                    for (int i=0; i<100; i++) begin
                        @(posedge avmm_clk_ifc.clk);
                        #1;
                        tx_active |= axis_tx.tvalid;
                    end
                end
                tx_active = 1'b1;
            end

        end
        `TEST_CASE("continuous_start_stop") begin
            automatic int tx_pkts = 0;
            automatic logic tx_active = 1'b1;

            test_byteenable         = '1;
            test_byteenable_queue   = { test_byteenable };
            test_burstcount         = 1;

            set_header;

            //SET NUM_PACKETS
            avmm_driver.write_data((16+GPOUT_OFFSET+1) << 2, {32'h1}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);
            //SET SHAPER
            avmm_driver.write_data((16+GPOUT_OFFSET+2) << 2, {32'h0FFFFFFF}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            //START
            avmm_driver.write_data((16+GPOUT_OFFSET+0) << 2, {32'h3}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            while (tx_pkts < 5) begin
                avmm_driver.read_data((16+3) << 2, test_readdata_queue, '1, 1, test_response_queue);
                tx_pkts = test_readdata_queue.pop_front();
            end

            //STOP
            avmm_driver.write_data((16+GPOUT_OFFSET+0) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            while (tx_active) begin
                tx_active = 1'b0;
                for (int i=0; i<100; i++) begin
                    @(posedge avmm_clk_ifc.clk);
                    #1;
                    tx_active |= axis_tx.tvalid;
                end
            end
            tx_active = 1'b1;
        end

        `TEST_CASE("shaper") begin
            automatic int tx_pkts = 0;
            automatic logic tx_active = 1'b1;

            test_byteenable         = '1;
            test_byteenable_queue   = { test_byteenable };
            test_burstcount         = 1;

            set_header;

            //SET NUM_PACKETS
            avmm_driver.write_data((16+GPOUT_OFFSET+1) << 2, {32'h1}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);
            //SET SHAPER
            avmm_driver.write_data((16+GPOUT_OFFSET+2) << 2, {SHAPER_500M}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            //START
            avmm_driver.write_data((16+GPOUT_OFFSET+0) << 2, {32'h3}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            while (tx_pkts < 5) begin
                avmm_driver.read_data((16+3) << 2, test_readdata_queue, '1, 1, test_response_queue);
                tx_pkts = test_readdata_queue.pop_front();
            end

            //STOP
            avmm_driver.write_data((16+GPOUT_OFFSET+0) << 2, {32'h0}, test_byteenable_queue, test_burstcount, result_response);
            `CHECK_EQUAL(result_response, avmm.RESPONSE_OKAY);

            while (tx_active) begin
                tx_active = 1'b0;
                for (int i=0; i<100; i++) begin
                    @(posedge avmm_clk_ifc.clk);
                    #1;
                    tx_active |= axis_tx.tvalid;
                end
            end
            tx_active = 1'b1;
        end
    end
        `WATCHDOG(5ms);
 endmodule
