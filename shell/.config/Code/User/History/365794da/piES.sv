// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Encapsulate packet gens into a module so that there can be one perameterized module instantiatoin per
 * axis array ranther than four instances of nearly identical logic.
 */

`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_array_pkt_gen
#(
    parameter NUM_PORTS = 0,
    parameter MTU_BYTES = 1500

) (
    AXIS_int.Master axis_packet_out [NUM_PORTS-1:0],

    output var logic [NUM_PORTS-1:0]                    busy,
    input  var logic [NUM_PORTS-1:0]                    send__packet_req,
    input  var int                                      packet_byte_length  [NUM_PORTS-1:0],
    input  var logic [axis_packet_out.USER_WIDTH-1:0]   packet_user         [NUM_PORTS-1:0],
    input  var logic [MTU_BYTES*8-1:0]                  packet_data         [NUM_PORTS-1:0]
);

    `ELAB_CHECK_GT(NUM_PORTS, 0);

    generate
        for (genvar port=0; axis < NUM_PORTS; axis++) begin
            axis_pkt_gen
            #(
                .MTU_BYTES (MTU_BYTES)
            ) pkt_gen (
                .axis_packet_out     (axis_packet_out[port]),
                .busy                (send_packet_busy[port]),
                .send_packet_req     (send_packet_req[port]),
                .packet_byte_length  (send_packet_byte_length[port]),
                .packet_user         (send_packet_user[port]),
                .packet_data         (send_packet_vec[port])
            );
            // AXIS_driver # (
            //     .DATA_BYTES ( AXIS_DATA_BYTES            ),
            //     .ID_WIDTH   ( axis_out[axis].ID_WIDTH    ),
            //     .DEST_WIDTH ( axis_out[axis].DEST_WIDTH  ),
            //     .USER_WIDTH ( axis_out[axis].USER_WIDTH  )
            // ) driver_interface_inst (
            //     .clk (axis_out[axis].clk),
            //     .sresetn(axis_out[axis].sresetn)
            // );

            // AXIS_driver_module driver_module_inst (
            //     .control (driver_interface_inst),
            //     .o ( axis_out[axis] )
            // );

            // logic [AXIS_DATA_BYTES-1:0]   keep_vec;
            // always_comb begin
            //     keep_vec = '0;
            //     for (int b=0; b<AXIS_DATA_BYTES; b++) begin
            //         if (packet_byte_length[axis] % AXIS_DATA_BYTES == 0) begin
            //             keep_vec = '1;
            //         end else if (b < packet_byte_length[axis] % AXIS_DATA_BYTES) begin
            //             keep_vec[b] = 1'b1;
            //         end
            //     end
            // end

            // always_ff @(posedge axis_out[axis].clk) begin
            //     busy[axis] = 1'b0;
            //     if (send_req[axis]) begin
            //         automatic logic [AXIS_DATA_BYTES*8-1:0]         data [$] = {};
            //         automatic logic                                 last [$] = {};
            //         automatic logic [AXIS_DATA_BYTES-1:0]           keep [$] = {};
            //         automatic logic [AXIS_DATA_BYTES-1:0]           strb [$] = {};
            //         automatic logic [axis_out[axis].ID_WIDTH-1:0]   id   [$] = {};
            //         automatic logic [axis_out[axis].DEST_WIDTH-1:0] dest [$] = {};
            //         automatic logic [axis_out[axis].USER_WIDTH-1:0] user [$] = {};
            //         busy[axis] = 1'b1;
            //         for (integer w = 0; w * AXIS_DATA_BYTES < packet_byte_length[axis]; w++) begin
            //             data.push_back(packet_data[axis][w]);
            //             strb.push_back('1);
            //             id.push_back('0);
            //             dest.push_back('0);
            //             user.push_back('0);
            //             if ((w+1)*AXIS_DATA_BYTES >= packet_byte_length[axis]) begin
            //                 last.push_back(1'b1);
            //                 keep.push_back(keep_vec);
            //             end else begin
            //                 last.push_back(1'b0);
            //                 keep.push_back('1);
            //             end
            //         end
            //         driver_interface_inst.write_queue_ext(data, last, keep, strb, id, dest, user);
            //     end
            // end

        end
    endgenerate

endmodule
