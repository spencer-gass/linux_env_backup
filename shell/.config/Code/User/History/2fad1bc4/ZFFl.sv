// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/*
 * Encapsulate packet checking into a module so that there can be one perameterized module instantiatoin per
 * axis array ranther than four instances of nearly identical logic.
 */

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_array_pkt_chk #(
    parameter int NUM_PORTS = 0,
    parameter int MTU_BYTES = 0,
    parameter int DATA_BYTES = 0,
    parameter int NUM_PACKETS_TO_SEND = 1
) (
    AXIS_int.Monitor         axis_in [NUM_PORTS],
    logic [MTU_BYTES*8-1: 0] expected_pkts [NUM_PACKETS_TO_SEND-1:0];
);

    `ELAB_CHECK_GT(NUM_PORTS,0);
    `ELAB_CHECK_GT(MTU_BYTES,0);
    `ELAB_CHECK_GT(DATA_BYTES,0);

    localparam WORD_BIT_WIDTH = DATA_BYTES*8;

    function int tkeep_to_bytes(input logic [CONVERGED_AXIS_DATA_BYTES-1:0] tkeep) ;
        automatic int bytes = 0;
        for (int i=0; i<CONVERGED_AXIS_DATA_BYTES; i++) begin
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

    // `MAKE_AXIS_MONITOR(ing_bus_monitor, ing_bus);

    // always_ff @(posedge core_clk_ifc.clk) begin
    //     if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
    //         packet_received    <= '{default: '{default: '0}};
    //         rx_packet_buf      <= '0;
    //         rx_packet          <= '0;
    //         rx_wcnt            <= 0;
    //         rx_blen            <= 0;
    //         rx_ing_port        <= 0;
    //     end else begin
    //         rx_validate <= ing_bus_monitor.tlast & ing_bus_monitor.tvalid & ing_bus_monitor.tready;
    //         if (ing_bus_monitor.tvalid && ing_bus_monitor.tready) begin
    //             rx_packet_buf[rx_wcnt*CONVERGED_AXIS_DATA_BYTES*8 +: CONVERGED_AXIS_DATA_BYTES*8] <= ing_bus_monitor.tdata;
    //             rx_wcnt <= rx_wcnt +1;
    //             if (ing_bus_monitor.tlast) begin
    //                 rx_blen <= rx_wcnt*CONVERGED_AXIS_DATA_BYTES + tkeep_to_bytes(ing_bus_monitor.tkeep);
    //                 rx_ing_port <= ing_bus_monitor.tuser;
    //                 rx_packet <= rx_packet_buf;
    //                 rx_packet[rx_wcnt*CONVERGED_AXIS_DATA_BYTES*8 +: CONVERGED_AXIS_DATA_BYTES*8] <= ing_bus_monitor.tdata;
    //                 rx_wcnt <= 0;
    //                 rx_packet_buf <= '0;
    //             end
    //         end
    //         if (rx_validate) begin
    //
    //         end
    //     end
    // end

    // in this test bench, packets consist of incrementing bytes
    // check data valid by comparing data byte to it's byte index
    task automatic validate_output_packet(
        input int rx_blen,
        input [MTU_BYTES*8-1:0] rx_packket
    );
        for (int pkt=0; pkt<=NUM_PACKETS_TO_SEND; pkt++) begin
            if (pkt == NUM_PACKETS_TO_SEND) begin
                $display("");
                $display("rx ingress port: %d", port);
                $display("rx byte length: %d", rx_blen);
                $display("rx packet: %h", rx_packet);
                $display("");
                $display("possible tx packet matches");
                for (int txp=0; txp<tx_snoop_wr_ptr[rx_ing_port]; txp++) begin
                    if (!packet_received[rx_ing_port][txp]) begin
                        $display("tx byte length: %d", tx_snoop_blen_buf[rx_ing_port][txp]);
                        $display("tx packet: %h", tx_snoop_data_buf[rx_ing_port][txp]);
                    end
                end
                $display("");
                $error("RX packet not found in TX snoop buffer.");
            end else if (packets_are_equal(rx_packet, rx_blen, expected_pkts[pkt], expected_blens[pkt])) begin
                packet_received[rx_ing_port][pkt] <= 1'b1;
                break;
            end
        end
    endtask

    generate
        for (genvar port=0; port<NUM_PORTS; port++) begin

            int                             wr_word_ptr;
            logic [MTU_BYTES*8-1:0]   output_buf;
            int                             output_packet_blen;
            int                             byte_cnt;
            logic                           tlast_d;
            logic [NUM_PACKETS_TO_SEND-1:0] packet_received;

            always_ff @(posedge axis_in[port].clk) begin : packet_data_checker
                if (!axis_in[port].sresetn) begin
                    output_buf <= '{default: 0};
                    output_packet_blen <= 0;
                    tlast_d <= 0;
                    packet_received <= '0;
                end else begin

                    // Validate data
                    tlast_d <= axis_in[port].tlast;
                    if (tlast_d) begin
                        validate_output_packet(output_packet_blen, output_buf);
                    end

                    // Convert output packet from a sequence of words to a single logic vector
                    if (axis_in[port].tvalid & axis_in[port].tready) begin
                        output_buf[wr_word_ptr*WORD_BIT_WIDTH +: WORD_BIT_WIDTH] <= axis_in[port].tdata;
                        if (axis_in[port].tlast) begin
                            wr_word_ptr <= 0;
                            byte_cnt <= 0;
                            // add bytes from partial word to byte length
                            output_packet_blen <= byte_cnt + tkeep_to_bytes(axis_in[port].tkeep);
                        end else begin
                            byte_cnt <= byte_cnt + axis_in[port].DATA_BYTES;
                            wr_word_ptr++;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule