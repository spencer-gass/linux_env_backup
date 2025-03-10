// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Encapsulate packet gens into a module so that there can be one parameterized module instantiation per
 * axis array ranther than four instances of nearly identical logic.
 */

`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_array_packet_generator
#(
    parameter int NUM_PORTS       = 0,
    parameter int MTU_BYTES       = 1500,
    parameter bit AXIS_BIG_ENDIAN = 1'b0

) (
    AXIS_int.Master axis_packet_out [NUM_PORTS-1:0],

    output var logic [NUM_PORTS-1:0]                        busy,
    input  var logic [NUM_PORTS-1:0]                        send_packet_req,
    input  var int                                          packet_byte_length  [NUM_PORTS-1:0],
    input  var logic [axis_packet_out[0].USER_WIDTH-1:0]    packet_user         [NUM_PORTS-1:0],
    input  var logic [0:MTU_BYTES*8-1]                      packet_data         [NUM_PORTS-1:0]
);

    `ELAB_CHECK_GT(NUM_PORTS, 0);

    generate
        for (genvar port=0; port < NUM_PORTS; port++) begin : axis_packet_generators
            axis_packet_generator #(
                .MTU_BYTES          ( MTU_BYTES         ),
                .AXIS_BIG_ENDIAN    ( AXIS_BIG_ENDIAN   )
            ) packet_generator (
                .axis_packet_out     ( axis_packet_out[port]    ),
                .busy                ( busy[port]               ),
                .send_packet_req     ( send_packet_req[port]    ),
                .packet_byte_length  ( packet_byte_length[port] ),
                .packet_user         ( packet_user[port]        ),
                .packet_data         ( packet_data[port]        )
            );
        end
    endgenerate

endmodule
