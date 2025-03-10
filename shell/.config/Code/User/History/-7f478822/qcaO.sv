// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/*
 * Encapsulate packet sink and checking
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_pkt_chk #(
    parameter string ID_STRING_0             = "",
    parameter int    ID_VALUE_0              = 0,
    parameter string ID_STRING_1             = "",
    parameter int    ID_VALUE_1              = 0,
    parameter string PKT_ID_STRING           = "",
    parameter int    MTU_BYTES               = 1500,
    parameter int    NUM_PKT_IDS             = 1,
    parameter int    NUM_PACKETS_BEING_SENT  = 1,
    parameter int    NUM_PACKETS_BEING_SENT_LOG = $clog2(NUM_PACKETS_BEING_SENT)
) (
    AXIS_int.Slave                                   axis_packet_in,
    input var int                                    pkt_id,
    input var logic [NUM_PACKETS_BEING_SENT_LOG-1:0] num_tx_pkts    [NUM_PKT_IDS-1:0],
    input var logic [MTU_BYTES*8-1: 0]               expected_pkts  [NUM_PKT_IDS-1:0][NUM_PACKETS_BEING_SENT-1:0],
    input var logic [$clog2(MTU_BYTES)-1: 0]         expected_blens [NUM_PKT_IDS-1:0][NUM_PACKETS_BEING_SENT-1:0]
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION:  Elaboration Checks

    `ELAB_CHECK_GT(axis_packet_in.DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam BITS_PER_WORD = axis_packet_in.DATA_BYTES*8;
    localparam MTU_BYTES_LOG = $clog2(MTU_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function int tkeep_to_bytes(input logic [axis_packet_in.axis_packet_in.DATA_BYTES-1:0] tkeep) ;
        automatic int bytes = 0;
        for (int i=0; i<axis_packet_in.axis_packet_in.DATA_BYTES; i++) begin
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


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    int                             wcnt;
    logic [MTU_BYTES*8-1:0]         rx_buffer;
    logic [MTU_BYTES*8-1:0]         rx_packet;
    int                             rx_id;
    int                             rx_blen;
    logic                           tlast_d;
    logic [NUM_PACKETS_BEING_SENT-1:0] packet_received;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    AXIS_sink #(
        .DATA_BYTES  ( axis_packet_in.DATA_BYTES    ),
        .ID_WIDTH    ( axis_packet_in.ID_WIDTH      ),
        .DEST_WIDTH  ( axis_packet_in.DEST_WIDTH    ),
        .USER_WIDTH  ( axis_packet_in.USER_WIDTH    )
    ) axis_packet_in_sink (
        .clk    ( axis_packet_in.clk     ),
        .sresetn( axis_packet_in.sresetn )
    );

    AXIS_sink_module axis_test_sink_module (
        .control( axis_packet_in_sink ),
        .i      ( axis_packet_in      )
    );

    always begin
        while (1) axis_packet_in_sink.accept_wait;
    end

    `MAKE_AXIS_MONITOR(axis_packet_in_monitor, axis_packet_in);

    always_ff @(posedge axis_packet_in_monitor.clk) begin : packet_data_checker
        if (!axis_packet_in_monitor.sresetn) begin
            rx_packet <= '{default: 0};
            rx_blen <= 0;
            tlast_d <= 0;
            packet_received <= '0;
        end else begin

            // Convert output packet from a sequence of words to a single logic vector
            if (axis_packet_in_monitor.tvalid & axis_packet_in_monitor.tready) begin
                rx_buffer[wcnt*BITS_PER_WORD +: BITS_PER_WORD] <= axis_packet_in_monitor.tdata;
                if (axis_packet_in_monitor.tlast) begin
                    wcnt <= 0;
                    // add bytes from partial word to byte length
                    rx_id <= pkt_id;
                    rx_blen <= wcnt*axis_packet_in.DATA_BYTES + tkeep_to_bytes(axis_packet_in_monitor.tkeep);
                    rx_packet <= rx_buffer;
                    rx_packet[wcnt*BITS_PER_WORD +: BITS_PER_WORD] <= axis_packet_in_monitor.tdata;
                end else begin
                    wcnt++;
                end
            end

            // Validate data
            tlast_d <= axis_packet_in_monitor.tlast;
            if (tlast_d) begin
                for (int pkt=0; pkt<=NUM_PACKETS_BEING_SENT; pkt++) begin
                    if (pkt == num_tx_pkts[rx_id]) begin
                        $display("");
                        if (ID_STRING_0 != "") $display({ID_STRING_0, ": %d"}, ID_VALUE_0);
                        if (ID_STRING_1 != "") $display({ID_STRING_1, ": %d"}, ID_VALUE_1);
                        if (PKT_ID_STRING != "") $display({PKT_ID_STRING, ": %d"}, rx_id);
                        $display("Rx byte length: %d", rx_blen);
                        $display("Rx packet: %h", rx_packet);
                        $display("");
                        $display("Possible tx packet matches");
                        for (int txp=0; txp<num_tx_pkts[rx_id]; txp++) begin
                            if (!packet_received[rx_id][txp]) begin
                                $display("Tx byte length: %d", expected_blens[rx_id][txp]);
                                $display("Tx packet: %h", expected_pkts[rx_id][txp]);
                            end
                        end
                        $display("");
                        $error("Rx packet not found in Tx capture.");
                    end else if (packets_are_equal(rx_packet, rx_blen, expected_pkts[rx_id][pkt], expected_blens[rx_id][pkt])) begin
                        packet_received[rx_id][pkt] <= 1'b1;
                        break;
                    end
                end
            end
        end
    end

endmodule
