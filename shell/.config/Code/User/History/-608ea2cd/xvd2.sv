// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for p4_router_scheculer
 */

module p4_router_scheduler_tb();

    parameter int NUM_EGR_PHYS_PORTS = 9;

    parameter int QUEUE_MEM_URAM_DEPTH = 8;
    parameter int MTU_BYTES = 1500;
    parameter int PACKET_MAX_BLEN = MTU_BYTES;     // Maximum packet size in BYTES
    parameter int PACKET_MIN_BLEN = 64;            // Minimum packet size in BYTES
    parameter int VNP4_DATA_BYTES = 64;
    parameter int BYTES_PER_PAGE = 4096;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Constants

    localparam int NUM_EGR_PHYS_PORTS_LOG = $clog2(NUM_EGR_PHYS_PORTS);
    localparam int NUM_QUEUES = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);

    localparam int DQ_NOTE_DATA_BYTES = U_INT_CEIL_DIV($clog2(VNP4_DATA_BYTES)+1, 8);
    localparam int SCHED_DQ_REQ_BYTES = U_INT_CEIL_DIV(NUM_QUEUES_LOG, 8);

    localparam int DQ_PIPE_DEPTH = 2;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces

    int num_packets_to_send;

    bit [NUM_EGR_PHYS_PORTS-1:0] pkt_in_progress;

    // Sim Model
    bit [NUM_QUEUES-1:0] queue_empty;
    int queue_mem [NUM_QUEUES-1:0] [$];
    int queue_size [NUM_QUEUES-1:0];
    int queue_head [NUM_QUEUES-1:0];

    int                     dequeue_req;
    bit                     dequeue_req_valid;
    int                     dequeue_req_pipe    [DQ_PIPE_DEPTH-1:0];
    bit [DQ_PIPE_DEPTH-1:0] dequeue_req_valid_pipe;

    logic [NUM_EGR_PHYS_PORTS-1:0]     egr_buf_ready;
    logic [NUM_EGR_PHYS_PORTS_LOG-1:0] dequeue_notification_egr_port;

    bit test_in_progress;
    bit [NUM_EGR_PHYS_PORTS-1:0] tvalid;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) phys_port_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) phys_port_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces

    AXIS_int #(
        .DATA_BYTES ( DQ_NOTE_DATA_BYTES ),
        .USER_WIDTH ( NUM_QUEUES_LOG ),
        .ALLOW_BACKPRESSURE ( 0      )
    ) dequeue_notification (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    `MAKE_AXIS_MONITOR(dequeue_notification_monitor, dequeue_notification);

    AXIS_int #(
        .DATA_BYTES ( SCHED_DQ_REQ_BYTES  ),
        .ALLOW_BACKPRESSURE ( 0           )
    ) sched_dequeue_req (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );


    //////////////////////////////////////////////////////////////////////////
    // Logic Implemenatation

    // simulation clock
    always #(CORE_CLK_PERIOD/2)         core_clk_ifc.clk <= ~core_clk_ifc.clk;
    always #(PHYS_PORT_CLK_PERIOD/2)    phys_port_clk_ifc.clk <= ~phys_port_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Model the Rest of the Queue System

    always_ff @(posedge core_clk_ifc.clk ) begin
        automatic string err_str;
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            sched_dequeue_req.tready <= 1'b0;
        end else begin
            sched_dequeue_req.tready <= 1'b1;
            dequeue_req_pipe       <= {dequeue_req_pipe[DQ_PIPE_DEPTH-2:0], sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0]};
            dequeue_req_valid_pipe <= {dequeue_req_valid_pipe[DQ_PIPE_DEPTH-2:0], sched_dequeue_req.tvalid};

            dequeue_notification.tvalid <= dequeue_req_valid_pipe[DQ_PIPE_DEPTH-1];
            dequeue_notification.tlast <= 1'b0;
            if (dequeue_req_valid_pipe[DQ_PIPE_DEPTH-1]) begin
                dequeue_notification.tuser <= dequeue_req_pipe[DQ_PIPE_DEPTH-1];
                if (queue_mem[dequeue_req_pipe[DQ_PIPE_DEPTH-1]][0] <= VNP4_DATA_BYTES) begin
                    dequeue_notification.tdata <= queue_mem[dequeue_req_pipe[DQ_PIPE_DEPTH-1]].pop_front();
                    dequeue_notification.tlast <= 1'b1;
                end else begin
                    dequeue_notification.tdata <= VNP4_DATA_BYTES;
                    queue_mem[dequeue_req_pipe[DQ_PIPE_DEPTH-1]][0] <= queue_mem[dequeue_req_pipe[DQ_PIPE_DEPTH-1]][0] - VNP4_DATA_BYTES;
                end
            end

            if (sched_dequeue_req.tvalid) begin
                $sformat(err_str, "Requesting a dequeue from empty queue %d", sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0]);
                `CHECK_EQUAL(queue_empty[sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0]], 0, err_str);
            end
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Verify Strict Prio

    always_ff @(posedge core_clk_ifc.clk) begin
        automatic string err_str;
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            pkt_in_progress <= '0;
        end else begin
            if (sched_dequeue_req.tvalid) begin
                pkt_in_progress[sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0]] <= 1'b1;
            end else if (dequeue_notification.tlast) begin
                pkt_in_progress[dequeue_notification.tuser[NUM_QUEUES_LOG-1:0]] <= 1'b0;
            end
            if (sched_dequeue_req.tvalid && !pkt_in_progress[sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0]]) begin
                for (int q=NUM_QUEUES_PER_EGR_PORT-1; q > -1; q--) begin
                    if (!queue_empty[{sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:NUM_QUEUES_PER_EGR_PORT_LOG], q[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}]) begin
                        $sformat(err_str, "Dequeued from %d when higher priority queue %d is non-empty", sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:0], {sched_dequeue_req.tdata[NUM_QUEUES_LOG-1:NUM_QUEUES_PER_EGR_PORT_LOG], q[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]});
                        `CHECK_EQUAL(q[NUM_QUEUES_PER_EGR_PORT_LOG-1:0], sched_dequeue_req.tdata[NUM_QUEUES_PER_EGR_PORT_LOG-1:0], err_str);
                        break;
                    end
                end
            end

        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT

    p4_router_scheduler #(
        .NUM_EGR_PORTS  ( NUM_EGR_PHYS_PORTS ),
        .NUM_QUEUES     ( NUM_QUEUES         ),
        .MTU_BYTES      ( MTU_BYTES          )
    ) dut (
        .queue_empty            ( queue_empty                   ),
        .egr_buf_ready          ( egr_buf_ready                 ),
        .dequeue_notification   ( dequeue_notification_monitor  ),
        .dequeue_req            ( sched_dequeue_req             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue Mem Sim Model

    always_comb begin
        for (int q=0; q<NUM_QUEUES; q++) begin
            queue_size[q] = queue_mem[q].size();
            queue_head[q] = queue_mem[q][0];
            queue_empty[q] = (queue_mem[q].size()) ? 1'b0 : 1'b1;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress Buffer Models

    assign dequeue_notification_egr_port = dequeue_notification.tuser[NUM_QUEUES_PER_EGR_PORT_LOG +: NUM_EGR_PHYS_PORTS_LOG];

    AXIS_int #(
        .DATA_BYTES ( VNP4_DATA_BYTES  )
    ) egr_demuxed [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXIS_int #(
        .DATA_BYTES ( 8  )
    ) egr_phys_ports [NUM_EGR_PHYS_PORTS-1:0] (
        .clk     (phys_port_clk_ifc.clk                                      ),
        .sresetn (phys_port_sreset_ifc.reset != phys_port_sreset_ifc.ACTIVE_HIGH  )
    );

    p4_router_egress_port_array_adapt #(
        .NUM_EGR_PHYS_PORTS         ( NUM_EGR_PHYS_PORTS        ),
        .EGR_BUS_DATA_BYTES         ( VNP4_DATA_BYTES           ),
        .PHYS_PORT_DATA_BYTES       ( 8                         ),
        .MTU_BYTES                  ( MTU_BYTES                 ),
        .EGR_COUNTERS_WIDTH         ( 32                        )
    ) egress_port_array_adapt_64b (
        .egr_phys_ports_demuxed     ( egr_demuxed       ),
        .egr_phys_ports             ( egr_phys_ports    ),
        .egr_phys_ports_enable      ( '1                ),
        .egr_cnts_clear             ( '0                ),
        .egr_cnts                   (                   ),
        .egr_ports_connected        (                   ),
        .egr_buf_full_drop          (                   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress Demuxed Drivers

    generate
        for (genvar port=0; port<NUM_EGR_PHYS_PORTS; port++) begin : egr_demuxed_driver


            logic [egr_demuxed[port].DATA_BYTES-1:0] keep_comb;

            assign egr_buf_ready[port]     = egr_demuxed[port].tready;
            assign egr_demuxed[port].tdata = '0;
            assign egr_demuxed[port].tid   = '0;
            assign egr_demuxed[port].tstrb = '1;
            assign egr_demuxed[port].tdest = '0;
            assign egr_demuxed[port].tuser = '0;

            always_comb begin
                keep_comb = '0;
                for(int i=0; i<$size(keep_comb); i++) begin
                    if (i < dequeue_notification.tdata) begin
                        keep_comb[i] = 1'b1;
                    end
                end
            end

            always_ff @(posedge core_clk_ifc.clk) begin
                automatic string err_str;
                if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
                    egr_demuxed[port].tvalid <= 1'b0;
                    egr_demuxed[port].tkeep  <= '1;
                    egr_demuxed[port].tlast   <= 1'b0;
                end else begin
                    if (dequeue_notification.tvalid && dequeue_notification_egr_port == port) begin
                        egr_demuxed[port].tvalid <= 1'b1;
                        egr_demuxed[port].tkeep  <= keep_comb;
                        egr_demuxed[port].tlast   <= dequeue_notification.tlast;
                        $sformat(err_str, "egress port %d received a dequeued word when it wasn't ready", port);
                        `CHECK_EQUAL(egr_demuxed[port].tready, 1'b1 , err_str);
                    end else begin
                        egr_demuxed[port].tvalid <= 1'b0;
                        egr_demuxed[port].tkeep  <= '1;
                        egr_demuxed[port].tlast   <= 1'b0;
                    end
                end
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Egress Physical Port Sinks

    generate
        for (genvar port=0; port<NUM_EGR_PHYS_PORTS; port++) begin : egr_phys_port_sink

            logic shaper_ready;
            real shaper_accum;
            // 10G ethernet = 64-bit * 156.25
            localparam real SHAPER_DEC = 8;
            localparam int ETH_OVERHEAD = 20;
            int blen_comb;

            assign shaper_ready = (shaper_accum < 0) ? 1'b1 : 1'b0;
            assign egr_phys_ports[port].tready = shaper_ready;
            assign tvalid[port] = egr_phys_ports[port].tvalid;

            always_comb begin
                blen_comb = 0;
                for (int i=0; i<egr_phys_ports[port].DATA_BYTES; i++) begin
                    blen_comb += egr_phys_ports[port].tkeep[i];
                end
            end

            always_ff @( posedge phys_port_clk_ifc.clk ) begin
                if (phys_port_sreset_ifc.reset == phys_port_sreset_ifc.ACTIVE_HIGH) begin
                    shaper_accum <= -1.0;
                end else begin
                    if (egr_phys_ports[port].tvalid && egr_phys_ports[port].tready && egr_phys_ports[port].tlast) begin
                        shaper_accum <= shaper_accum + blen_comb + ETH_OVERHEAD - SHAPER_DEC;
                    end else if (egr_phys_ports[port].tvalid &&egr_phys_ports[port].tready) begin
                        shaper_accum <= shaper_accum + blen_comb - SHAPER_DEC;
                    end else if (shaper_accum >= 0) begin
                        shaper_accum <= shaper_accum - SHAPER_DEC;
                    end
                end
            end

            // logic valid_start;
            // logic valid_end;

            // always_ff @(posedge phys_port_clk_ifc.clk) begin
            //     automatic string err_str;
            //     if (phys_port_sreset_ifc.reset == phys_port_sreset_ifc.ACTIVE_HIGH || !scheduler_line_rate_test) begin
            //         valid_start <= 1'b0;
            //         valid_end <= 1'b0;
            //     end else begin
            //         if (egr_phys_ports[port].tvalid && egr_phys_ports[port].tready) begin
            //             valid_start <= 1'b1;
            //         end
            //         if (!egr_phys_ports[port].tvalid && valid_start) begin
            //             valid_end <= 1'b1;
            //         end
            //         $sformat(err_str, "Egress buffer %d emptied due to insufficient shaper dequeue rate.", port);
            //         `CHECK_EQUAL(valid_start & valid_end & egr_phys_ports[port].tvalid, 0, err_str);
            //     end
            // end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Tasks

    task enqueue_packet(
        input int queue,
        input int blen
    );
        queue_mem[queue].push_back(blen);
    endtask

    task check_line_rate(
        input int port
    );
        automatic string err_str;
        wait (tvalid[port] === 1'b1);
        #1;
        wait (~tvalid[port]);
        #1;
        while (test_in_progress) begin
            @(posedge phys_port_clk_ifc.clk);
            #1;
            $sformat(err_str, "Egress buffer %d emptied due to insufficient shaper dequeue rate.", port);
            `CHECK_EQUAL(tvalid[port], 1'b0, err_str);
        end
    endtask

    // Load fixed sized packets on the first queue of each egress port.
    // In this scenario, the scheduler should be able to keep the egress buffer output ready until the last word of the last packet.
    task line_rate_test(
        input int num_ports;
    );
            num_packets_to_send = 1000;

            // Load Packets
            for (int pkt=0; pkt<num_packets_to_send; pkt ++) begin
                enqueue_packet($urandom() % num_ports * NUM_QUEUES_PER_EGR_PORT, 1000);
            end

            // Lanch line-rate checker threads
            for (int phys_port_thread=0; phys_port_thread<NUM_EGR_PHYS_PORTS; phys_port_thread++ ) begin
                automatic int port = phys_port_thread;
                fork
                    begin
                        check_line_rate(port);
                    end
                join_none
            end

            // Wait for the test to complete.
            @(posedge core_clk_ifc.clk);
            wait (&queue_empty);
            wait (~|tvalid);
            test_in_progress = 1'b0;
    endtask

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            core_clk_ifc.clk        <= 1'b0;
            phys_port_clk_ifc.clk   <= 1'b0;
        end

        `TEST_CASE_SETUP begin
            num_packets_to_send = 0;
            test_in_progress = 1'b1;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            phys_port_sreset_ifc.reset = phys_port_sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge core_clk_ifc.clk);
            #1
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;
            @(posedge phys_port_clk_ifc.clk);
            #1;
            phys_port_sreset_ifc.reset = ~phys_port_sreset_ifc.ACTIVE_HIGH;
        end

        `TEST_CASE("base_test") begin
            num_packets_to_send = 1000;
            for (int pkt=0; pkt<num_packets_to_send; pkt ++) begin
                enqueue_packet($urandom() % NUM_QUEUES, $urandom_range(PACKET_MIN_BLEN, PACKET_MAX_BLEN));
            end
            @(posedge core_clk_ifc.clk);
            wait (&queue_empty);
            wait (~|tvalid);
        end


        `TEST_CASE("line_rate_test_single_port") begin
            line_rate_test(1);
        end

        `TEST_CASE("line_rate_test_all_ports") begin
            line_rate_test(NUM_EGR_PHYS_PORTS);
        end
    end

    `WATCHDOG(1ms);
endmodule
