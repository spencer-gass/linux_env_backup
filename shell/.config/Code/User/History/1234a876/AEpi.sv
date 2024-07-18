
 package mpls_ingress_tb_pkg;

    class axis_packet_formatter #(
        int BYTES_PER_WORD = 1,
        int MAX_PKT_WLEN = 1,
        int MTU_BYTES = 1500
    );
        static task get_packet_data (
            input  logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            output logic [MTU_BYTES*8-1:0] packet_data
        ); begin
            for (integer b = 0; b<packet_byte_length; b++) begin
                packet_data[b*8 +: 8] = b % 256;
            end
        end
        endtask

        static task get_packet (
            input logic [$clog2(MTU_BYTES)-1:0] packet_byte_length,
            ref logic   [BYTES_PER_WORD*8-1:0] packet_word_array [MAX_PKT_WLEN-1:0]
        ); begin
            automatic logic [MTU_BYTES*8-1:0] packet_data;
            get_packet_data(packet_byte_length, packet_data);
            for (integer w = 0; w*BYTES_PER_WORD < packet_byte_length; w++) begin
                automatic logic [BYTES_PER_WORD*8-1:0] next_word = 0;
                packet_word_array[w] = packet_data[w*BYTES_PER_WORD*8 +: BYTES_PER_WORD*8];
            end
        end
        endtask

    endclass

endpackage