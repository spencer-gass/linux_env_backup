// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_array_pkt_gen #(
    parameter NUM_PORTS = 0,
    parameter AXIS_DATA_BYTES = 0,
    parameter PACKET_MAX_BLEN = 16

) (
    AXIS_int.Master axis_out [NUM_PORTS-1:0],

    output var logic [NUM_PORTS-1:0]                busy,
    input  var logic [NUM_PORTS-1:0]                send_req,
    input  var logic [$clog2(PACKET_MAX_BLEN)-1:0]  packet_byte_length  [NUM_PORTS-1:0],
    input  var logic [AXIS_DATA_BYTES*8-1:0]        packet_data         [NUM_PORTS-1:0] [PACKET_MAX_BLEN/AXIS_DATA_BYTES-1:0]
);

    `ELAB_CHECK_GT(NUM_PORTS, 0);
    `ELAB_CHECK_GT(AXIS_DATA_BYTES, 0);

    generate
        for (genvar axis=0; axis < NUM_PORTS; axis++) begin

            AXIS_driver # (
                .DATA_BYTES(AXIS_DATA_BYTES)
            ) driver_interface_inst (
                .clk (axis_out[axis].clk),
                .sresetn(axis_out[axis].sresetn)
            );

            AXIS_driver_module driver_module_inst (
                .control (driver_interface_inst),
                .o ( axis_out[axis] )
            );

            always_ff @(posedge axis_out[axis].clk) begin
                busy[axis] = 1'b0;
                if (send_req[axis]) begin
                    automatic logic [AXIS_DATA_BYTES*8-1:0] data [$] = {};
                    busy[axis] = 1'b1;
                    for (integer w = 0; w * AXIS_DATA_BYTES < packet_byte_length[axis]; w++) begin
                        data.push_back(packet_data[axis][w]);
                    end
                    driver_interface_inst.write_queue(data);
                end
            end

        end
    endgenerate

endmodule