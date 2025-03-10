// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Encapsulate AXIS_driver and exposes and send packet request interface
 */

`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

module axis_pkt_gen
#(
    parameter MTU_BYTES = 1500

) (
    AXIS_int.Master axis_packet_out,

    output var logic                                    busy,
    input  var logic                                    send_packet_req,
    input  var int                                      packet_byte_length,
    input  var logic [axis_packet_out.USER_WIDTH-1:0]   packet_user,
    input  var logic [MTU_BYTES*8-1:0]                  packet_data
);

    AXIS_driver # (
        .DATA_BYTES ( axis_packet_out.DATA_BYTES  ),
        .ID_WIDTH   ( axis_packet_out.ID_WIDTH    ),
        .DEST_WIDTH ( axis_packet_out.DEST_WIDTH  ),
        .USER_WIDTH ( axis_packet_out.USER_WIDTH  )
    ) driver_interface_inst (
        .clk (axis_packet_out.clk),
        .sresetn(axis_packet_out.sresetn)
    );

    AXIS_driver_module driver_module_inst (
        .control (driver_interface_inst),
        .o ( axis_packet_out )
    );

    logic [axis_packet_out.DATA_BYTES-1:0]   keep_vec;

    always_comb begin
        keep_vec = '0;
        for (int b=0; b<axis_packet_out.DATA_BYTES; b++) begin
            if (packet_byte_length % axis_packet_out.DATA_BYTES == 0) begin
                keep_vec[b] = 1'b1;
            end else if (b < packet_byte_length % axis_packet_out.DATA_BYTES) begin
                keep_vec[b] = 1'b1;
            end
        end
    end

    always_ff @(posedge axis_packet_out.clk) begin
        if (!axis_packet_out.sresetn) begin
            busy = 1'b0;
        end else begin
            if (send_packet_req && !busy) begin
                automatic logic [axis_packet_out.DATA_BYTES*8-1:0]     data [$] = {};
                automatic logic                                        last [$] = {};
                automatic logic [axis_packet_out.DATA_BYTES-1:0]       keep [$] = {};
                automatic logic [axis_packet_out.DATA_BYTES-1:0]       strb [$] = {};
                automatic logic [axis_packet_out.ID_WIDTH-1:0]         id   [$] = {};
                automatic logic [axis_packet_out.DEST_WIDTH-1:0]       dest [$] = {};
                automatic logic [axis_packet_out.USER_WIDTH-1:0]       user [$] = {};
                busy = 1'b1;

                for (integer w = 0; w * axis_packet_out.DATA_BYTES < packet_byte_length; w++) begin
                    data.push_back(packet_data[w*axis_packet_out.DATA_BYTES*8 +: axis_packet_out.DATA_BYTES*8]);
                    strb.push_back('1);
                    id.push_back('0);
                    dest.push_back('0);
                    user.push_back(packet_user);
                    if ((w+1)*axis_packet_out.DATA_BYTES >= packet_byte_length) begin
                        last.push_back(1'b1);
                        keep.push_back(keep_vec);
                    end else begin
                        last.push_back(1'b0);
                        keep.push_back('1);
                    end
                end
                driver_interface_inst.write_queue_ext(
                    .input_data(data),
                    .input_last(last),
                    .input_keep(keep),
                    .input_strb(strb),
                    .input_id(id),
                    .input_dest(dest),
                    .input_user(user)
                );
                busy = 1'b0;
            end
        end
    end

endmodule
