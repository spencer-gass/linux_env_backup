// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * P4 Router Scheduler
**/
module p4_router_scheduler
    import P4_ROUTER_PKG::*;
#(
    parameter int NUM_EGR_PORTS  = 1,
    parameter int NUM_QUEUES     = NUM_EGR_PORTS * NUM_QUEUES_PER_EGR_PORT,
    parameter int MTU_BYTES      = 2000,
    parameter bit DEBUG_ILA      = 1'b0
) (
    input var logic [NUM_QUEUES-1:0]    queue_empty,
    input var logic [NUM_EGR_PORTS-1:0] egr_buf_ready,
    AXIS_int.Monitor                    dequeue_notification,
    AXIS_int.Master                     dequeue_req
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    localparam int NUM_EGR_PORTS_LOG = $clog2(NUM_EGR_PORTS);
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [NUM_EGR_PORTS-1:0]     egr_port_queues_empty;
    logic [NUM_EGR_PORTS_LOG-1:0] egr_port_sel = '0;
    logic                         egr_port_sel_valid;
    logic [NUM_EGR_PORTS_LOG-1:0] egr_port_sel_comb = '0;
    logic                         egr_port_sel_valid_comb;

    logic [NUM_EGR_PORTS-1:0]               pkt_in_progress;
    logic [NUM_QUEUES_PER_EGR_PORT_LOG-1:0] active_queue [NUM_EGR_PORTS-1:0];
    logic [DQ_LATENCY:0]                    dequeue_in_progress_pipe [NUM_EGR_PORTS-1:0];
    logic                                   dequeue_in_progress [NUM_EGR_PORTS-1:0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    always_comb begin
        for (int port=0; port<NUM_EGR_PORTS; port++) begin
            dequeue_in_progress[port] = |dequeue_in_progress_pipe[port];
        end

        // Modified Round Robbin
        /// Might generate deep logic
        /// could do 1 to N steps at a time rather than considering all ports
        /// could add a pipeline stage
        egr_port_sel_valid_comb = 1'b0;
        egr_port_sel_comb = egr_port_sel;
        for (int i=0; i<NUM_EGR_PORTS; i++) begin
            automatic logic [NUM_EGR_PORTS-1:0] port = (egr_port_sel + i) >= NUM_EGR_PORTS ? egr_port_sel + i - NUM_EGR_PORTS : egr_port_sel + i;
            if (!egr_port_queues_empty[port] && !dequeue_in_progress[port] && egr_buf_ready[port]) begin
                egr_port_sel_comb       = port;
                egr_port_sel_valid_comb = 1'b1;
                break;
            end
        end
    end

    assign dequeue_req.tstrb  = '1;
    assign dequeue_req.tkeep  = '1;
    assign dequeue_req.tid    = '0;
    assign dequeue_req.tlast  = dequeue_req.tvalid;
    assign dequeue_req.tdest  = '0;
    assign dequeue_req.tuser  = '0;

    always_ff @(posedge dequeue_req.clk) begin
        if (!dequeue_req.sresetn) begin
            egr_port_sel_valid       <= 1'b0;
            pkt_in_progress          <= '0;
            dequeue_in_progress_pipe <= '{default: '0};
            egr_port_queues_empty    <= '0;
        end else begin
            for (int port=0; port<NUM_EGR_PORTS; port++) begin
                dequeue_in_progress_pipe[port] <= {dequeue_in_progress_pipe[port][DQ_LATENCY-1:0], 1'b0};
                egr_port_queues_empty[port] <= &queue_empty[port * NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT];
            end

            egr_port_sel                                   <= egr_port_sel_comb;
            egr_port_sel_valid                             <= egr_port_sel_valid_comb;
            dequeue_in_progress_pipe[egr_port_sel_comb][0] <= egr_port_sel_valid_comb;

            // Strict Prio queue scheduler
            if (egr_port_sel_valid) begin
                dequeue_req.tvalid <= ~&queue_empty[egr_port_sel*NUM_QUEUES_PER_EGR_PORT +: NUM_QUEUES_PER_EGR_PORT];
                dequeue_req.tdata  <= '0;
                if (pkt_in_progress[egr_port_sel]) begin
                    dequeue_req.tdata <= {egr_port_sel, active_queue[egr_port_sel]};
                end else begin
                    for (int prio=NUM_QUEUES_PER_EGR_PORT-1; prio >= 0; prio--) begin
                        if (~queue_empty[{egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]}]) begin
                            dequeue_req.tdata               <= {egr_port_sel, prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0]};
                            active_queue[egr_port_sel]      <= prio[NUM_QUEUES_PER_EGR_PORT_LOG-1:0];
                            pkt_in_progress[egr_port_sel]   <= 1'b1;
                            break;
                        end
                    end
                end
            end else begin
                dequeue_req.tvalid <= 1'b0;
                dequeue_req.tdata  <= '0;
            end

            if (dequeue_notification.tvalid && dequeue_notification.tlast) begin
                pkt_in_progress[dequeue_notification.tuser[NUM_QUEUES_PER_EGR_PORT_LOG +: NUM_EGR_PORTS_LOG]] <= 1'b0;
            end
        end
    end

    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                localparam QUEUE_EMPTY_LEFT = NUM_QUEUES > 32 ? 31: NUM_QUEUES-1;

                logic [31:0] dbg_cntr;
                always_ff @(posedge dequeue_notification.clk) begin
                    if (!dequeue_notification.sresetn) begin
                        dbg_cntr <= '0;
                    end else begin
                        dbg_cntr <= dbg_cntr + 1'b1;
                    end
                end

                ila_debug ila (
                    .clk    ( dequeue_notification.clk          ),
                    .probe0 ( {dequeue_notification.sresetn,
                               dequeue_req.tvalid,
                               dequeue_req.tdata,
                               dequeue_notification.tvalid,
                               egr_port_sel_valid
                               } ),
                    .probe1 ( dequeue_notification.tdata        ),
                    .probe2 ( egr_port_sel                      ),
                    .probe3 ( pkt_in_progress                   ),
                    .probe4 ( egr_buf_ready                     ),
                    .probe5 ( dequeue_in_progress               ),
                    .probe6 ( {active_queue[0], active_queue[1]}),
                    .probe7 ( queue_empty[QUEUE_EMPTY_LEFT:0]   ),
                    .probe8 ( egr_port_queues_empty             ),
                    .probe9 ( '0                                ),
                    .probe10( '0                                ),
                    .probe11( '0                                ),
                    .probe12( '0                                ),
                    .probe13( '0                                ),
                    .probe14( '0                                ),
                    .probe15( dbg_cntr                          )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
