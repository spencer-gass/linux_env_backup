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
    parameter int    NUM_PORTS = 0,
    parameter string MODULE_ID_STRING_0 = "",
    parameter int    MODULE_ID_VALUE_0  = 0,
    parameter string MODULE_ID_STRING_1 = "",
    parameter int    NUM_PKT_IDS        = 1,
    parameter int    NUM_PKT_IDS_LOG    = $clog2(NUM_PKT_IDS),
    parameter string PKT_ID_STRING      = "",
    parameter int    AXIS_PACKET_IN_DATA_BYTES = 0,
    parameter int    AXIS_PACKET_IN_USER_WIDTH = 1,
    parameter bit    AXIS_PACKET_IN_ALLOW_BACKPRESSURE = 1'b1,
    parameter int    MTU_BYTES = 0,
    parameter int    NUM_PACKETS_BEING_SENT = 1,
    parameter int    NUM_PACKETS_BEING_SENT_LOG = $clog2(NUM_PACKETS_BEING_SENT)
) (
    AXIS_int.Slave                                   axis_packet_in [NUM_PORTS-1:0],
    input var logic [NUM_PKT_IDS_LOG-1:0]            packet_in_id   [NUM_PORTS-1:0],
    input var logic [NUM_PACKETS_BEING_SENT_LOG-1:0] num_tx_pkts    [NUM_PORTS-1:0],
    input var logic [MTU_BYTES*8-1: 0]               expected_pkts  [NUM_PORTS-1:0][NUM_PACKETS_BEING_SENT-1:0],
    input var logic [$clog2(MTU_BYTES)-1: 0]         expected_blens [NUM_PORTS-1:0][NUM_PACKETS_BEING_SENT-1:0],
    input var logic [NUM_PKT_IDS_LOG-1:0]            expected_ids   [NUM_PORTS-1:0][NUM_PACKETS_BEING_SENT-1:0]
);

    `ELAB_CHECK_GT(NUM_PORTS,0);
    `ELAB_CHECK_GT(MTU_BYTES,0);
    `ELAB_CHECK_GT(AXIS_PACKET_IN_DATA_BYTES,0);

    generate
        for (genvar axis=0; axis<NUM_PORTS; axis++) begin

            // Connect the indexed AXIS to a new AXIS to get around not being able to
            // access interface parameters from elements of an interface array in modules
            // lower in the hierarchy.
            AXIS_int #(
                .DATA_BYTES         ( AXIS_PACKET_IN_DATA_BYTES         ),
                .USER_WIDTH         ( AXIS_PACKET_IN_USER_WIDTH         ),
                .ALLOW_BACKPRESSURE ( AXIS_PACKET_IN_ALLOW_BACKPRESSURE )
            ) pkt_in (
                .clk     (axis_packet_in[axis].clk       ),
                .sresetn (axis_packet_in[axis].sresetn   )
            );

            assign pkt_in.tdata  = axis_packet_in[axis].tdata;
            assign pkt_in.tkeep  = axis_packet_in[axis].tkeep;
            assign pkt_in.tstrb  = axis_packet_in[axis].tstrb;
            assign pkt_in.tvalid = axis_packet_in[axis].tvalid;
            assign pkt_in.tlast  = axis_packet_in[axis].tlast;
            assign pkt_in.tid    = axis_packet_in[axis].tid;
            assign pkt_in.tdest  = axis_packet_in[axis].tdest;
            assign pkt_in.tuser  = axis_packet_in[axis].tuser;
            assign axis_packet_in[axis].tready = pkt_in.tready;


            axis_pkt_chk #(
                .MODULE_ID_STRING_0     ( MODULE_ID_STRING_0    ),
                .MODULE_ID_VALUE_0      ( MODULE_ID_VALUE_0     ),
                .MODULE_ID_STRING_1     ( MODULE_ID_STRING_1    ),
                .MODULE_ID_VALUE_1      ( axis                  ),
                .NUM_PKT_IDS            ( NUM_PKT_IDS           ),
                .PKT_ID_STRING          ( PKT_ID_STRING         ),
                .MTU_BYTES              ( MTU_BYTES             ),
                .NUM_PACKETS_BEING_SENT ( NUM_PACKETS_BEING_SENT )
            ) pkt_chk (
                .axis_packet_in ( pkt_in                ),
                .packet_in_id   ( packet_in_id[axis]    ),
                .num_tx_pkts    ( num_tx_pkts[axis]     ),
                .expected_pkts  ( expected_pkts[axis]   ),
                .expected_blens ( expected_blens[axis]  ),
                .expected_ids   ( expected_ids[axis]    )
            );

        end
    endgenerate

endmodule
