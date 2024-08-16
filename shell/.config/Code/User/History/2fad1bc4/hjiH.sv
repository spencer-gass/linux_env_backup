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


    // in this test bench, packets consist of incrementing bytes
    // check data valid by comparing data byte to it's byte index
    task automatic validate_output_packet(
        input int blen,
        input [MTU_BYTES*8-1:0] pkt
    );
        for (int b=0; b<blen; b++) begin
            `CHECK_EQUAL(pkt[b*8 +: 8], b % 256);
        end
    endtask

    generate
        for (genvar port=0; port<NUM_PORTS; port++) begin

            int                             wrw_ptr;
            logic [MTU_BYTES*8-1:0]   output_buf;
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
