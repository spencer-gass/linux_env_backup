// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Scheduler
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_scheduler
    import p4_router_pkg::*;
#(
    parameter int NUM_EGR_PORTS = 0,
    parameter int NUM_QUEUES = NUM_EGR_PORTS * NUM_QUEUES_PER_EGR_PORT,
    parameter int MTU_BYTES = 2000
) (
    input var logic [NUM_QUEUES-1:0] queue_empty,
    AXIS_int.Monitor dequeue_notification,
    AXIS_int.Master dequeue_req
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int NUM_EGR_PORTS_LOG = $clog2(NUM_EGR_PORTS);
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_EGR_PORTS_LOG-1:0] egr_port_sel;
    logic                         egr_port_sel_valid;
    `ELAB_CHECK_LE(NUM_EGR_PORTS, 16); /// temporary restriction for this place holder implementation

    logic [NUM_EGR_PORTS-1:0] pkt_in_progress;
    logic [NUM_QUEUES_PER_EGR_PORT_LOG-1:0] active_queue [NUM_EGR_PORTS-1:0];
    logic [DQ_LATENCY-1:0] dequeue_in_flight [NUM_EGR_PORTS-1:0];

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign dequeue_req.tstrb = '1;
    assign dequeue_req.tkeep = '1;
    assign dequeue_req.tid   = '0;
    assign dequeue_req.tlast = dequeue_req.tvalid;
    assign dequeue_req.tdest  = '0;
    assign dequeue_req.tuser  = '0;

    always_ff @(posedge dequeue_req.clk) begin
        if (!dequeue_req.sresetn) begin
            egr_port_sel        <= '0;
            egr_port_sel_valid  <= 1'b0;
            pkt_in_progress     <= '0;
            dequeue_in_flight   <= '{default: '0};
        end else begin
            // Round Robbing port scheduler
            // if (egr_port_sel == 15) begin
            //     egr_port_sel <= '0;
            // end else begin
            //     egr_port_sel <= egr_port_sel+1;
            // end

            // Modified Round Robbin
            egr_port_sel_valid <= 1'b0;
            for (int port=0; port<NUM_EGR_PORTS; port++) begin
                automatic int port_rebased = (egr_port_sel + port) % NUM_EGR_PORTS;
                if (~&queue_empty[port_rebased * NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT] &&
                    ~|dequeue_in_flight[port_rebased]
                    ) begin
                    egr_port_sel <= egr_port_sel + port % NUM_EGR_PORTS;
                    egr_port_sel_valid <= 1'b1;
                    break;
                end
            end

            for (int port=0; port<NUM_EGR_PORTS; port++) begin
                dequeue_in_flight[port] <= {dequeue_in_flight[port][DQ_LATENCY-2:0], 1'b0};
            end

            // Strict Prio queue scheduler
            if (egr_port_sel_valid) begin
                dequeue_req.tvalid <= ~&queue_empty[egr_port_sel*NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT];
                dequeue_in_flight[egr_port_sel][0] <= ~&queue_empty[egr_port_sel*NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT];
                dequeue_req.tdata <= '0;
                if (pkt_in_progress[egr_port_sel]) begin
                    dequeue_req.tdata <= {egr_port_sel, active_queue[egr_port_sel]};
                end else begin
                    for (int prio=NUM_QUEUES_PER_EGR_PORT-1; prio >= 0; prio--) begin
                        if (~queue_empty[{egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}]) begin
                            dequeue_req.tdata <= {egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]};
                            active_queue[egr_port_sel] <= prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0];
                            pkt_in_progress[egr_port_sel] <= 1'b1;
                            break;
                        end
                    end
                end
            end else begin
                dequeue_req.tvalid <= 1'b0;
                dequeue_req.tdata <= '0;
            end

            if (dequeue_notification.tvalid && dequeue_notification.tlast) begin
                pkt_in_progress[dequeue_notification.tuser[NUM_QUEUES_PER_EGR_PORT_LOG +: NUM_EGR_PORTS_LOG]] <= 1'b0;
            end
        end

    end


endmodule

`default_nettype wire
