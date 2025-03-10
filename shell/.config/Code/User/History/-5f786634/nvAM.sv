// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for p4_router_policer
 */

module p4_router_policer_tb();

    parameter int NUM_ING_PHYS_PORTS = 11;
    parameter int NUM_EGR_PHYS_PORTS = 11;

    parameter int MTU_BYTES = 1500;
    parameter int PACKET_MAX_BLEN = MTU_BYTES;
    parameter int PACKET_MIN_BLEN = 64;
    parameter int VNP4_DATA_BYTES = 64;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);
    localparam int MAX_PKT_WLEN = U_INT_CEIL_DIV(PACKET_MAX_BLEN, VNP4_DATA_BYTES);
    localparam int VNP4_DATA_BYTES_LOG = $clog2(VNP4_DATA_BYTES);
    localparam int AVERAGE_PKT_BLEN = (PACKET_MAX_BLEN+PACKET_MIN_BLEN)/2;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces

    int                     send_packet_byte_length;
    logic [MTU_BYTES*8-1:0] send_packet_data;
    vnp4_wrapper_metadata_t send_packet_user;
    logic                   send_packet_req;
    logic                   send_packet_busy;
    int                     send_packet_count;

    logic [NUM_ING_PHYS_PORTS-1:0] dut_enable;
    bucket_decrement_t             dut_bucket_decrement         [NUM_ING_PHYS_PORTS-1:0];
    bucket_depth_threshold_t       dut_bucket_depth_threshold   [NUM_ING_PHYS_PORTS-1:0];

    vnp4_wrapper_metadata_t  packet_in_metadata_queue [$];
    policer_metadata_t       expected_packet_out_metadata_queue [$];
    int                      cycles_to_empty_queue [$];
    int                      cycles_to_near_empty_queue [$];

    vnp4_wrapper_metadata_t  packet_in_metadata;
    policer_metadata_t       packet_out_metadata;

    int timer;
    bit timer_reset;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: clocks and resets

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS interfaces

    AXIS_int #(
        .USER_WIDTH ( VNP4_WRAPPER_METADATA_WIDTH  ),
        .DATA_BYTES ( VNP4_DATA_BYTES               )
    ) dut_packet_in (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( POLICER_METADATA_WIDTH  ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_packet_out (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interfaces

    AXI4Lite_int #(
        .DATALEN    ( 32 ),
        .ADDRLEN    ( NUM_ING_PHYS_PORTS_LOG    )
    ) table_config (
        .clk     ( core_clk_ifc.clk     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    //////////////////////////////////////////////////////////////////////////
    // Logic implemenatation

    // simulation clock
    always #(CORE_CLK_PERIOD/2)      core_clk_ifc.clk <= ~core_clk_ifc.clk;

    always_ff @(posedge core_clk_ifc.clk) begin
        if (timer_reset) begin
            timer <= 0;
        end else begin
            timer <= timer + 1;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: A4L Config Driver

    AXI4Lite_master #(
        .DATALEN ( 32             ),
        .ADDRLEN ( NUM_ING_PHYS_PORTS_LOG )
    ) config_master (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_master_module config_master_inst (
        .control  ( config_master ),
        .o        ( table_config  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet generators

    axis_packet_generator #(
        .MTU_BYTES (MTU_BYTES)
    ) packet_generator (
        .axis_packet_out     (dut_packet_in),
        .busy                (send_packet_busy),
        .send_packet_req     (send_packet_req),
        .packet_byte_length  (send_packet_byte_length),
        .packet_user         (send_packet_user),
        .packet_data         (send_packet_data)
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_policer #(
        .NUM_ING_PORTS  ( NUM_ING_PHYS_PORTS ),
        .MTU_BYTES      ( MTU_BYTES          )
    ) dut (
        .enable                 ( dut_enable                 ),
        .table_config           ( table_config               ),
        .packet_in              ( dut_packet_in              ),
        .packet_out             ( dut_packet_out             )
    );

    assign packet_in_metadata  = dut_packet_in.tuser;
    assign packet_out_metadata = dut_packet_out.tuser;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sinks & Data Validation

    assign dut_packet_out.tready = (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) ? 1'b0 : 1'b1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks

    task automatic send_packet (
        input policer_metadata_t send_packet_metadata,
        input int payload_type
    ); begin

        send_packet_byte_length = send_packet_metadata.byte_length[MTU_BYTES_LOG-1:0];
        send_packet_user        = send_packet_metadata;

        // Wait till we can send data
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
        axis_packet_formatter #( VNP4_DATA_BYTES,  MAX_PKT_WLEN , MTU_BYTES)::get_packet(payload_type, send_packet_metadata.byte_length[MTU_BYTES_LOG-1:0], send_packet_data);
        #0
        send_packet_req = 1'b1;
        // Wait till its received
        while(!send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_req = 1'b0;
        // Wait till its finished
        while(send_packet_busy) @(posedge core_clk_ifc.clk);
        send_packet_count++;
    end
    endtask;

    task automatic check_metadata (
        input policer_metadata_t expected_packet_out_metadata [$]
    );
        automatic policer_metadata_t expected_metadata;
        automatic string err_str;
        automatic int pkt_cnt = 0;
        while (expected_packet_out_metadata.size()) begin
            @(posedge core_clk_ifc.clk);
            #1;
            if (dut_packet_out.tvalid && dut_packet_out.tlast) begin
                expected_metadata = expected_packet_out_metadata.pop_front();
                $sformat(err_str, "Packet %d, ingress port %d, had unexpected metadata output", pkt_cnt, packet_out_metadata.ingress_port);
                `CHECK_EQUAL(packet_out_metadata.ingress_port,      expected_metadata.ingress_port,       err_str);
                `CHECK_EQUAL(packet_out_metadata.egress_port,       expected_metadata.egress_port,        err_str);
                `CHECK_EQUAL(packet_out_metadata.prio,              expected_metadata.prio,               err_str);
                `CHECK_EQUAL(packet_out_metadata.byte_length,       expected_metadata.byte_length,        err_str);
                `CHECK_EQUAL(packet_out_metadata.policer_drop_mark, expected_metadata.policer_drop_mark,  err_str);
                pkt_cnt++;
            end
        end
    endtask

    task automatic write_table(
        input int table_index,
        input int ing_port,
        input int data
    );
        automatic logic [1:0] resp;
        automatic qsys_table_id_t table_id;
        table_id.select = table_index;
        table_id.address = ing_port;
        config_master.write_data(
            .addr ( table_id ),
            .data ( data ),
            .resp ( resp )
        );
    endtask

    task automatic write_cir_table(
        input int ing_port,
        input int cir
    );
        write_table(ING_POLICER_CIR_TABLE, ing_port, cir);
    endtask

    task automatic write_cbs_table(
        input int ing_port,
        input int cbs
    );
        write_table(ING_POLICER_CBS_TABLE, ing_port, cbs);
    endtask

    task automatic run_test(
        input vnp4_wrapper_metadata_t packet_in_metadata [$],
        input policer_metadata_t      expected_packet_out_metadata [$]
    );
        fork
            begin // Send Packets
                while(packet_in_metadata.size()) begin
                    send_packet(
                        .send_packet_metadata ( packet_in_metadata.pop_front() ),
                        .payload_type         ( RAND                           )
                    );
                end
                $display("Send Packets Completed");
            end

            begin
                check_metadata(expected_packet_out_metadata);
                $display("Receive Packets Completed");
            end

        join
    endtask

    task automatic run_cir_test(
        input vnp4_wrapper_metadata_t packet_in_metadata_queue [$],
        input policer_metadata_t      expected_packet_out_metadata_queue [$],
        input int                     cycles_to_empty_queue [$],
        input int                     cycles_to_near_empty_queue [$]
    );
        automatic vnp4_wrapper_metadata_t packet_in_metadata;
        automatic int cycles_to_empty;
        automatic int cycles_to_near_empty;
        automatic bit test_complete = 1'b0;

        fork
            begin // Send Packets
                while(packet_in_metadata_queue.size()) begin

                    packet_in_metadata = packet_in_metadata_queue.pop_front();
                    cycles_to_empty = cycles_to_empty_queue.pop_front();
                    cycles_to_near_empty = cycles_to_near_empty_queue.pop_front();

                    @(posedge core_clk_ifc.clk);
                    #1;
                    timer_reset = 1;
                    @(posedge core_clk_ifc.clk);
                    #1;
                    timer_reset = 0;

                    // Send packet 1 to fill the bucket
                    send_packet(
                        .send_packet_metadata ( packet_in_metadata ),
                        .payload_type         ( RAND               )
                    );

                    // Wait until the bucket is nearly empty and send packet 2
                    // expect a drop mark
                    wait (timer >= cycles_to_near_empty);

                    send_packet(
                        .send_packet_metadata ( packet_in_metadata ),
                        .payload_type         ( RAND               )
                    );

                    // Wait untill the bucket is empty and send packet 3
                    // expect no drop mark
                    wait (timer >= cycles_to_empty);

                    send_packet(
                        .send_packet_metadata ( packet_in_metadata ),
                        .payload_type         ( RAND               )
                    );
                end
                test_complete = 1'b1;
                $display("Send Packets Completed");
            end

            begin
                check_metadata(expected_packet_out_metadata_queue);
                $display("Receive Packets Completed");
            end

        join
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            core_clk_ifc.clk        <= 1'b0;
            send_packet_req         <= 1'b0;
            send_packet_count       <= 0;
        end

        `TEST_CASE_SETUP begin

            dut_enable = '0;
            dut_bucket_decrement        = '{default: '0};
            dut_bucket_depth_threshold  = '{default: '0};
            packet_in_metadata_queue.delete();
            expected_packet_out_metadata_queue.delete();
            cycles_to_empty_queue.delete();
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

        end

        // Set CIR and CBS to min so that all packets are drop marked
        `TEST_CASE("drop_mark_all_packets") begin

            automatic vnp4_wrapper_metadata_t metadata_in;
            automatic policer_metadata_t expected_metadata_out;

            localparam int NUM_PACKETS_TO_SEND = 1000;

            // Set drop thresholds
            for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                dut_enable[i] = 1'b1;
                dut_bucket_decrement[i]        = '0;
                dut_bucket_depth_threshold[i]  = '0;
                write_cir_table(i, dut_bucket_decrement[i]);
                write_cbs_table(i, dut_bucket_depth_threshold[i]);
            end

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata_in.ingress_port = $urandom() % NUM_ING_PHYS_PORTS;
                metadata_in.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                metadata_in.prio = $urandom;
                metadata_in.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                packet_in_metadata_queue.push_back(metadata_in);

                expected_metadata_out = add_policer_drop_mark_to_metadata(1'b1, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
            end

            // Test task
            run_test(
                .packet_in_metadata           (packet_in_metadata_queue          ),
                .expected_packet_out_metadata (expected_packet_out_metadata_queue)
            );

            // Wait for all the packets to be received
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        // Set CIR and CBS to max so that all packets are accepted
        `TEST_CASE("accept_all_packets") begin

            automatic vnp4_wrapper_metadata_t metadata_in;
            automatic policer_metadata_t expected_metadata_out;

            localparam int NUM_PACKETS_TO_SEND = 1000;

            // Set drop thresholds
            for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                dut_enable[i] = 1'b1;
                dut_bucket_decrement[i]        = '1;
                dut_bucket_depth_threshold[i]  = '1;
                write_cir_table(i, dut_bucket_decrement[i]);
                write_cbs_table(i, dut_bucket_depth_threshold[i]);
            end

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata_in.ingress_port = $urandom() % NUM_ING_PHYS_PORTS;
                metadata_in.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                metadata_in.prio = $urandom;
                metadata_in.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                packet_in_metadata_queue.push_back(metadata_in);

                expected_metadata_out = add_policer_drop_mark_to_metadata(1'b0, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
            end

            // Test task
            run_test(
                .packet_in_metadata           (packet_in_metadata_queue          ),
                .expected_packet_out_metadata (expected_packet_out_metadata_queue)
            );

            // Wait for all the packets to be received
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        // Set CIR to 0, set CBS randomly, send random sized packets and verify that packets start getting drop marked at CBS
        `TEST_CASE("cbs_test") begin

            automatic vnp4_wrapper_metadata_t metadata_in;
            automatic policer_metadata_t expected_metadata_out;
            automatic int expected_bucket [NUM_ING_PHYS_PORTS-1:0];
            automatic bit expected_drop_mark;

            localparam int NUM_PACKETS_TO_SEND = 1000;

            // Set drop thresholds
            for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                dut_enable[i] = 1'b1;
                dut_bucket_decrement[i]        = '0;
                dut_bucket_depth_threshold[i]  = $urandom() % (AVERAGE_PKT_BLEN * NUM_PACKETS_TO_SEND / NUM_ING_PHYS_PORTS);
                write_cir_table(i, dut_bucket_decrement[i]);
                write_cbs_table(i, dut_bucket_depth_threshold[i]);
            end

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata_in.ingress_port = $urandom() % NUM_ING_PHYS_PORTS;
                metadata_in.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                metadata_in.prio = $urandom;
                metadata_in.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                packet_in_metadata_queue.push_back(metadata_in);


                if (metadata_in.byte_length + expected_bucket[metadata_in.ingress_port] > dut_bucket_depth_threshold[metadata_in.ingress_port]) begin
                    expected_drop_mark = 1'b1;
                    $display("Packet %d, blen %d, bucket %d, threshold %d, drop %d", pkt, metadata_in.byte_length, expected_bucket[metadata_in.ingress_port], dut_bucket_depth_threshold[metadata_in.ingress_port], expected_drop_mark);
                end else begin
                    expected_drop_mark = 1'b0;
                    expected_bucket[metadata_in.ingress_port] += metadata_in.byte_length;
                    $display("Packet %d, blen %d, bucket %d, threshold %d, drop %d", pkt, metadata_in.byte_length, expected_bucket[metadata_in.ingress_port], dut_bucket_depth_threshold[metadata_in.ingress_port], expected_drop_mark);
                end

                expected_metadata_out = add_policer_drop_mark_to_metadata(expected_drop_mark, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
            end

            // Test task
            run_test(
                .packet_in_metadata           (packet_in_metadata_queue          ),
                .expected_packet_out_metadata (expected_packet_out_metadata_queue)
            );

            // Wait for all the packets to be received
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        // Set CBS to a fixed depth, set packet size to CBS and send just before and just after the bucket should empty
        `TEST_CASE("cir_test") begin

            automatic vnp4_wrapper_metadata_t metadata_in;
            automatic policer_metadata_t expected_metadata_out;
            automatic int expected_bucket [NUM_ING_PHYS_PORTS-1:0];
            automatic bit expected_drop_mark;
            automatic int cycles_to_bucket_empty;
            automatic int cycles_to_bucket_near_empty;

            localparam int NUM_PACKETS_TO_SEND = NUM_ING_PHYS_PORTS;
            localparam int FIXED_PACKET_SIZE = 1000;

            // Set drop thresholds
            for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                dut_enable[i] = 1'b1;
                dut_bucket_decrement[i]        = $urandom();
                dut_bucket_depth_threshold[i]  = FIXED_PACKET_SIZE;
                write_cir_table(i, dut_bucket_decrement[i]);
                write_cbs_table(i, dut_bucket_depth_threshold[i]);
            end

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata_in.ingress_port = pkt % NUM_ING_PHYS_PORTS; // increment through ingress ports so that two packets to the same ingress port don't interfeir with eachother
                metadata_in.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                metadata_in.prio = $urandom();
                metadata_in.byte_length = FIXED_PACKET_SIZE;
                packet_in_metadata_queue.push_back(metadata_in);

                // set near empty to ~8 bytes left in the bucket to avoid getting too close to zero and going over by one cycle and getting a false positive.
                cycles_to_bucket_near_empty = U_INT_CEIL_DIV((FIXED_PACKET_SIZE-8) << $size(dut_bucket_decrement[metadata_in.ingress_port].fraction) , dut_bucket_decrement[metadata_in.ingress_port]);
                cycles_to_bucket_empty = U_INT_CEIL_DIV(FIXED_PACKET_SIZE << $size(dut_bucket_decrement[metadata_in.ingress_port].fraction) , dut_bucket_decrement[metadata_in.ingress_port]);
                cycles_to_empty_queue.push_back(cycles_to_bucket_empty);
                cycles_to_near_empty_queue.push_back(cycles_to_bucket_near_empty);
                $display("Packet %d, cycles to near empty %d, cycles to empty %d, dec whole %d", pkt, cycles_to_bucket_near_empty, cycles_to_bucket_empty, dut_bucket_decrement[metadata_in.ingress_port].whole);

                // For CIR test, three packets get generated per configured packet 1) fills the bucket 2) gets dropped 3) gets accepted
                expected_metadata_out = add_policer_drop_mark_to_metadata(1'b0, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
                expected_metadata_out = add_policer_drop_mark_to_metadata(1'b1, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
                expected_metadata_out = add_policer_drop_mark_to_metadata(1'b0, metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
            end

            // Test task
            run_cir_test(
                .packet_in_metadata_queue           (packet_in_metadata_queue          ),
                .expected_packet_out_metadata_queue (expected_packet_out_metadata_queue),
                .cycles_to_empty_queue              (cycles_to_empty_queue             ),
                .cycles_to_near_empty_queue         (cycles_to_near_empty_queue        )
            );

            // Wait for all the packets to be received
            repeat (8) @(posedge core_clk_ifc.clk);
        end

        // enable/disable random policers and verify that the enable one assert drop mark and the disabled ones don't
        `TEST_CASE("disable_test") begin

            automatic vnp4_wrapper_metadata_t metadata_in;
            automatic policer_metadata_t expected_metadata_out;

            localparam int NUM_PACKETS_TO_SEND = 1000;

            // Set drop thresholds
            for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                dut_enable[i] = $urandom();
                dut_bucket_decrement[i]        = '0;
                dut_bucket_depth_threshold[i]  = '0;
                write_cir_table(i, dut_bucket_decrement[i]);
                write_cbs_table(i, dut_bucket_depth_threshold[i]);
            end

            for (int pkt=0; pkt<NUM_PACKETS_TO_SEND; pkt++ ) begin
                // Define packet profile
                metadata_in.ingress_port = $urandom() % NUM_ING_PHYS_PORTS;
                metadata_in.egress_port = $urandom() % NUM_EGR_PHYS_PORTS;
                metadata_in.prio = $urandom;
                metadata_in.byte_length = $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN);
                packet_in_metadata_queue.push_back(metadata_in);

                expected_metadata_out = add_policer_drop_mark_to_metadata(dut_enable[metadata_in.ingress_port], metadata_in);
                expected_packet_out_metadata_queue.push_back(expected_metadata_out);
            end

            // Test task
            run_test(
                .packet_in_metadata           (packet_in_metadata_queue          ),
                .expected_packet_out_metadata (expected_packet_out_metadata_queue)
            );

            // Wait for all the packets to be received
            repeat (8) @(posedge core_clk_ifc.clk);
        end
    end

    `WATCHDOG(500us);

endmodule
