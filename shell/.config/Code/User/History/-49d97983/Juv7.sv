// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/*
 * Encapsulate packet sink and checking
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_packet_checker #(
    parameter string MODULE_ID_STRING_0      = "",
    parameter int    MODULE_ID_VALUE_0       = 0,
    parameter string MODULE_ID_STRING_1      = "",
    parameter int    MODULE_ID_VALUE_1       = 0,
    parameter int    NUM_PKT_IDS             = 1,
    parameter int    NUM_PKT_IDS_LOG         = $clog2(NUM_PKT_IDS),
    parameter string PKT_ID_STRING           = "",
    parameter int    MTU_BYTES               = 1500,
    parameter int    NUM_PACKETS_BEING_SENT  = 1,
    parameter int    NUM_PACKETS_BEING_SENT_LOG = $clog2(NUM_PACKETS_BEING_SENT)
) (
    AXIS_int.Slave                                   axis_packet_in,
    input var logic [NUM_PACKETS_BEING_SENT_LOG:0]   num_tx_pkts,
    input var logic [0:MTU_BYTES*8-1]                expected_pkts  [NUM_PACKETS_BEING_SENT-1:0],
    input var logic [$clog2(MTU_BYTES)-1:0]          expected_blens [NUM_PACKETS_BEING_SENT-1:0],
    input var logic [NUM_PKT_IDS_LOG-1:0]            expected_dests   [NUM_PACKETS_BEING_SENT-1:0],
    input var int                                    max_back_pressure_latency = 0
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Import

    import UTIL_INTS::U_INT_CEIL_DIV;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION:  Elaboration Checks

    `ELAB_CHECK_GT(axis_packet_in.DATA_BYTES, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam BITS_PER_WORD = axis_packet_in.DATA_BYTES*8;
    localparam MTU_BYTES_LOG = $clog2(MTU_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function int tkeep_to_bytes(input logic [axis_packet_in.DATA_BYTES-1:0] tkeep) ;
        automatic int bytes = 0;
        for (int i=0; i<axis_packet_in.DATA_BYTES; i++) begin
            bytes += tkeep[i];
        end
        return bytes;
    endfunction

    function bit packets_are_equal(
        input logic [0:MTU_BYTES*8-1]         rx_packet,
        input int                             rx_blen,
        input int                             rx_id,
        input logic [0:MTU_BYTES*8-1]         tx_packet,
        input logic [MTU_BYTES_LOG-1:0]       tx_blen,
        input int                             tx_id
    );
        if (rx_blen != tx_blen) return 1'b0;
        if (rx_id != tx_id) return 1'b0;
        for (int b=0; b<rx_blen; b++) begin
            if (rx_packet[b*8 +: 8] !== tx_packet[b*8 +: 8]) return 1'b0;
        end
        return 1'b1;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    int                             wcnt        [NUM_PKT_IDS-1:0] = '{default: 0};
    logic [0:MTU_BYTES*8-1]         rx_packet   [NUM_PKT_IDS-1:0] = '{default: '0};
    int                             rx_id;
    int                             rx_blen;
    logic                           tlast_d;
    logic [NUM_PACKETS_BEING_SENT-1:0] packet_received [NUM_PKT_IDS-1:0] = '{default: '0};
    int                             back_pressure_cnt = 0;

    logic [axis_packet_in.DATA_BYTES*8-1:0] rx_pkt_data [$];
    logic                                   rx_pkt_last [$];
    logic [axis_packet_in.DATA_BYTES-1:0]   rx_pkt_keep [$];
    logic [axis_packet_in.DATA_BYTES-1:0]   rx_pkt_strb [$];
    logic [axis_packet_in.ID_WIDTH-1:0]     rx_pkt_id   [$];
    logic [axis_packet_in.DEST_WIDTH-1:0]   rx_pkt_dest [$];
    logic [axis_packet_in.USER_WIDTH-1:0]   rx_pkt_user [$];

    logic [axis_packet_in.DEST_WIDTH-1:0]   dest_last;
    logic [axis_packet_in.DATA_BYTES-1:0]   keep_last;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    AXIS_sink #(
        .DATA_BYTES ( axis_packet_in.DATA_BYTES ),
        .ID_WIDTH   ( axis_packet_in.ID_WIDTH   ),
        .DEST_WIDTH ( axis_packet_in.DEST_WIDTH ),
        .USER_WIDTH ( axis_packet_in.USER_WIDTH )
    ) packet_sink (
        .clk        ( axis_packet_in.clk       ),
        .sresetn    ( axis_packet_in.sresetn   )
    );

    AXIS_sink_module axis_sink_inst (
        .i          ( axis_packet_in    ),
        .control    ( packet_sink       )
    );

    initial begin
        rx_packet = '{default: '{default: '0}};
        rx_blen = 0;
        tlast_d = 1'b0;
        packet_received = '{default: '0};
        wcnt = '{default: 0};
        back_pressure_cnt = 0;
    end

int count = 0;

    always begin
        $display("pre-fork %d", count);
        count++;
        // while(1) @(posedge axis_packet_in.clk);
        fork
            begin
                $display("fork1");
                while(axis_packet_in.sresetn !== 1'b0) @(posedge axis_packet_in.clk);
            end
            begin : sink_thread
                $display("fork2");
                while(1) begin
                    packet_sink.read_queue_ext (
                        .output_data        ( rx_pkt_data    ),
                        .output_last        ( rx_pkt_last    ),
                        .output_keep        ( rx_pkt_keep    ),
                        .output_strb        ( rx_pkt_strb    ),
                        .output_id          ( rx_pkt_id      ),
                        .output_dest        ( rx_pkt_dest    ),
                        .output_user        ( rx_pkt_user    ),
                        .read_until_tlast   ( 1'b1           ),
                        .read_num_words     ( 0              ),
                        .max_latency        ( max_back_pressure_latency )
                    );

                    while (rx_pkt_data.size()) begin
                        automatic logic [axis_packet_in.DATA_BYTES*8-1:0]   data = rx_pkt_data.pop_front();
                        automatic logic [axis_packet_in.DEST_WIDTH-1:0]     dest = rx_pkt_dest.pop_front();
                        dest_last = dest;
                        keep_last = rx_pkt_keep.pop_front();
                        for (int b=0; b<axis_packet_in.DATA_BYTES; b++) begin
                            rx_packet[dest][wcnt[dest]*BITS_PER_WORD + b*8 +: 8] = data[b*8 +: 8];
                        end
                        wcnt[dest]++;
                    end
                    rx_blen = (wcnt[dest_last]-1)*axis_packet_in.DATA_BYTES + tkeep_to_bytes(keep_last);
                    wcnt[dest_last] = 0;

                    // Search for the received packet in the set of expected packets
                    for (int pkt=0; pkt<=NUM_PACKETS_BEING_SENT; pkt++) begin
                        if (pkt == num_tx_pkts) begin
                            $display("");
                            if (MODULE_ID_STRING_0 != "") $display({MODULE_ID_STRING_0, ": %d"}, MODULE_ID_VALUE_0);
                            if (MODULE_ID_STRING_1 != "") $display({MODULE_ID_STRING_1, ": %d"}, MODULE_ID_VALUE_1);
                            if (PKT_ID_STRING != "") $display({PKT_ID_STRING, ": %d"}, dest_last);
                            $display("Rx byte length: %d", rx_blen);
                            $display("Rx packet:");
                            for (int i=0; i<U_INT_CEIL_DIV(rx_blen, axis_packet_in.DATA_BYTES); i++) begin
                                $display("%h", rx_packet[dest_last][i*axis_packet_in.DATA_BYTES*8 +: axis_packet_in.DATA_BYTES*8]);
                            end
                            $display("");
                            $display("Possible tx packet matches");
                            for (int txp=0; txp<num_tx_pkts; txp++) begin
                                if (!packet_received[dest_last][txp] && expected_dests[txp] == dest_last) begin
                                    if (PKT_ID_STRING != "") $display({PKT_ID_STRING, ": %d"}, expected_dests[txp]);
                                    $display("Tx byte length: %d", expected_blens[txp]);
                                    $display("Tx packet:");
                                    for (int i=0; i<U_INT_CEIL_DIV(expected_blens[txp], axis_packet_in.DATA_BYTES); i++) begin
                                        $display("%h", expected_pkts[txp][i*axis_packet_in.DATA_BYTES*8 +: axis_packet_in.DATA_BYTES*8]);
                                    end
                                end
                            end
                            $display("");
                            $error("Rx packet not found in Tx capture.");
                        end else if (packets_are_equal(rx_packet[dest_last], rx_blen, dest_last, expected_pkts[pkt], expected_blens[pkt], expected_dests[pkt])) begin
                            packet_received[dest_last][pkt] = 1'b1;
                            break;
                        end
                    end
                end
            end
        join_any

        $display("Reset");
        disable sink_thread;
        packet_sink.stall();
        rx_packet = '{default: '{default: '0}};
        rx_blen = 0;
        tlast_d = 1'b0;
        packet_received = '{default: '0};
        wcnt = '{default: 0};
        back_pressure_cnt = 0;

        while (axis_packet_in.sresetn !== 1'b1) @(posedge axis_packet_in.clk);
        $display("Reset Released");
    end

endmodule
