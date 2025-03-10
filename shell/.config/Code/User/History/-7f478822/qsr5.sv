// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/*
 * Encapsulate packet sink and checking
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_pkt_chk #(
    parameter string ID_STRING_0             = "",
    parameter int    ID_VALUE_0              = 0,
    parameter string ID_STRING_1             = "",
    parameter int    ID_VALUE_1              = 0,
    parameter int    MTU_BYTES               = 1500,
    parameter int    NUM_PACKETS_TO_SEND     = 1,
    parameter int    NUM_PACKETS_TO_SEND_LOG = $clog2(NUM_PACKETS_TO_SEND)
) (
    AXIS_int.Slave                                axis_packet_in ,
    input var logic [NUM_PACKETS_TO_SEND_LOG-1:0] num_tx_pkts    ,
    input var logic [MTU_BYTES*8-1: 0]            expected_pkts  [NUM_PACKETS_TO_SEND-1:0],
    input var logic [$clog2(MTU_BYTES)-1: 0]      expected_blens [NUM_PACKETS_TO_SEND-1:0]
);

    `ELAB_CHECK_GT(axis_packet_in.DATA_BYTES, 0);

    localparam WORD_BIT_WIDTH = axis_packet_in.DATA_BYTES*8;
    localparam MTU_BYTES_LOG = $clog2(MTU_BYTES);

    function int tkeep_to_bytes(input logic [axis_packet_in[0].axis_packet_in.DATA_BYTES-1:0] tkeep) ;
        automatic int bytes = 0;
        for (int i=0; i<axis_packet_in[0].axis_packet_in.DATA_BYTES; i++) begin
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

    AXIS_sink #(
        .DATA_BYTES  ( axis_packet_in.DATA_BYTES    ),
        .ID_WIDTH    ( axis_packet_in.ID_WIDTH      ),
        .DEST_WIDTH  ( axis_packet_in.DEST_WIDTH    ),
        .USER_WIDTH  ( axis_packet_in.USER_WIDTH    ),
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

    generate
        for (genvar port=0; port<NUM_PORTS; port++) begin

            int                             wr_word_ptr;
            logic [MTU_BYTES*8-1:0]         rx_packet;
            int                             rx_blen;
            int                             byte_cnt;
            logic                           tlast_d;
            logic [NUM_PACKETS_TO_SEND-1:0] packet_received;

            always_ff @(posedge axis_packet_in_monitor[port].clk) begin : packet_data_checker
                if (!axis_packet_in_monitor[port].sresetn) begin
                    rx_packet <= '{default: 0};
                    rx_blen <= 0;
                    tlast_d <= 0;
                    packet_received <= '0;
                end else begin

                    // Convert output packet from a sequence of words to a single logic vector
                    if (axis_packet_in_monitor[port].tvalid & axis_packet_in_monitor[port].tready) begin
                        rx_packet[wr_word_ptr*WORD_BIT_WIDTH +: WORD_BIT_WIDTH] <= axis_packet_in_monitor[port].tdata;
                        if (axis_packet_in_monitor[port].tlast) begin
                            wr_word_ptr <= 0;
                            byte_cnt <= 0;
                            // add bytes from partial word to byte length
                            rx_blen <= byte_cnt + tkeep_to_bytes(axis_packet_in_monitor[port].tkeep);
                        end else begin
                            byte_cnt <= byte_cnt + axis_packet_in_monitor[port].axis_packet_in_monitor.DATA_BYTES;
                            wr_word_ptr++;
                        end
                    end

                    // Validate data
                    tlast_d <= axis_packet_in_monitor[port].tlast;
                    if (tlast_d) begin
                        for (int pkt=0; pkt<=NUM_PACKETS_TO_SEND; pkt++) begin
                            if (pkt == NUM_PACKETS_TO_SEND) begin
                                $display("");
                                if (ID_STRING_0 != "") $display({ID_STRING_0, ": %d"}, ID_VALUE_0);
                                if (ID_STRING_1 != "") $display({ID_STRING_1, ": %d"}, ID_VALUE_1);
                                $display("rx byte length: %d", rx_blen);
                                $display("rx packet: %h", rx_packet);
                                $display("");
                                $display("possible tx packet matches");
                                for (int txp=0; txp<num_tx_pkts[port]; txp++) begin
                                    if (!packet_received[txp]) begin
                                        $display("tx byte length: %d", expected_blens[port][txp]);
                                        $display("tx packet: %h", expected_pkts[port][txp]);
                                    end
                                end
                                $display("");
                                $error("RX packet not found in TX snoop buffer.");
                            end else if (packets_are_equal(rx_packet, rx_blen, expected_pkts[port][pkt], expected_blens[port][pkt])) begin
                                packet_received[pkt] <= 1'b1;
                                break;
                            end
                        end
                    end
                end
            end
        end
    endgenerate

endmodule
