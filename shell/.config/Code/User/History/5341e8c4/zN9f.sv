// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * P4 Router Policer
 * Leaky bucket policer - bucket accumulator decrements at a configurable rate and increments by input packet byte length.
 * If the bucket occupancy crosses the configurable threshold, packets are marked to drop.
 * This module does not drop packets. It asserts the drop mark in metadata to instruct the congestion manager to drop them.
 * One bucket per ingress port to implement ingress shapers.
 * This module works like a virtual ingress queue where the leaky bucket represents packets in the virtual ingress queue.
 *
 * Bucket and decrement are fixed point numbers with enough precision to shape in units of Mbps.
 * Could revise to reduce precision if it isn't needed.
 *
 * bucket_decrement is in units of bytes/clock
 * to convert from Mbps:
 *  Mbits/Sec -> bits/us * 1 bytes / 8 bits * 1 us / 1000ns * CLOCK_PERIOD ns / 1 clock = bytes/clock
 * CLOCK_PERIOD_NS should be provided as a RO register so that software can convert a provisioned Mbps CIR to bytes/cycle.
**/
module p4_router_policer
    import P4_ROUTER_PKG::*;
#(
    parameter int MTU_BYTES     = 2000,
    parameter int NUM_ING_PORTS = 0,
    parameter bit DEBUG_ILA     = 0
) (

    input var logic [NUM_ING_PORTS-1:0] enable,
    AXI4Lite_int.Slave table_config,

    AXIS_int.Slave  packet_in,
    AXIS_int.Master packet_out
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    localparam int NUM_ING_PORTS_LOG = $clog2(NUM_ING_PORTS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, packet_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_ING_PORTS, 0);
    `ELAB_CHECK_EQUAL(table_config.ADDRLEN, QSYS_TABLE_ID_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    vnp4_wrapper_metadata_t   packet_in_metadata;
    vnp4_wrapper_metadata_t   packet_in_metadata_d;

    bucket_decrement_t        bucket_decrement       [NUM_ING_PORTS-1:0] = '{default: '0};
    bucket_depth_threshold_t  bucket_depth_threshold [NUM_ING_PORTS-1:0] = '{default: '0};
    bucket_t                  bucket [NUM_ING_PORTS-1:0];
    logic                     policer_drop_mark = 1'b0;
    logic                     packet_in_sop;

    qsys_table_id_t               table_wid;
    logic [NUM_ING_PORTS_LOG-1:0] table_waddr;
    qsys_table_id_t               table_rid;
    logic [NUM_ING_PORTS_LOG-1:0] table_raddr;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Leaky Bucket


    assign packet_in_metadata = packet_in.tuser;

    always_ff @(posedge packet_in.clk) begin
        if(!packet_in.sresetn) begin
            bucket        <= '{default: '0};
            packet_in_sop <= 1'b1;
        end else begin
            for(int ing_port=0; ing_port<NUM_ING_PORTS; ing_port++) begin

                if (packet_in.tvalid) begin
                    packet_in_sop <= packet_in.tlast;
                end

                if (bucket[ing_port] > bucket_decrement[ing_port] && enable[ing_port]) begin
                    bucket[ing_port] <= bucket[ing_port] - bucket_decrement[ing_port];
                end else begin
                    bucket[ing_port] <= '0;
                end

                if (packet_in.tvalid && packet_in_sop && packet_in_metadata.ingress_port == ing_port) begin
                    if (enable[ing_port]) begin
                        if (bucket[ing_port].whole + packet_in_metadata.byte_length > bucket_depth_threshold[ing_port]) begin
                            policer_drop_mark <= 1'b1;
                        end else begin
                            policer_drop_mark <= 1'b0;
                            bucket[ing_port]  <= bucket[ing_port] + (packet_in_metadata.byte_length << $size(bucket_decrement[ing_port].fraction)) - bucket_decrement[ing_port];
                        end
                    end else begin
                        policer_drop_mark <= 1'b0;

                    end
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Data Path


    assign packet_out.tuser = add_policer_drop_mark_to_metadata(policer_drop_mark, packet_in_metadata_d);

    always_ff @(posedge packet_in.clk) begin
        if(!packet_in.sresetn) begin
            packet_out.tvalid    <= 1'b0;
            packet_in.tready     <= 1'b0;
            packet_out.tdata     <= '0;
            packet_out.tstrb     <= '1;
            packet_out.tkeep     <= '1;
            packet_out.tlast     <= 1'b0;
            packet_out.tid       <= '0;
            packet_out.tdest     <= '0;
            packet_in_metadata_d <= '{default: '0};
        end else begin
            packet_out.tvalid    <= packet_in.tvalid;
            packet_in.tready     <= packet_out.tready;
            packet_out.tdata     <= packet_in.tdata;
            packet_out.tstrb     <= packet_in.tstrb;
            packet_out.tkeep     <= packet_in.tkeep;
            packet_out.tlast     <= packet_in.tlast;
            packet_out.tid       <= packet_in.tid;
            packet_out.tdest     <= packet_in.tdest;
            packet_in_metadata_d <= packet_in_metadata;
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Table Config


    assign table_config.awready = ~table_config.bvalid;
    assign table_config.wready  = ~table_config.bvalid;
    assign table_config.arready = ~table_config.rvalid;

    assign table_wid   = table_config.awaddr;
    assign table_rid   = table_config.araddr;
    assign table_waddr = table_wid.address[NUM_ING_PORTS_LOG-1:0];
    assign table_raddr = table_rid.address[NUM_ING_PORTS_LOG-1:0];

    always_ff @(posedge table_config.clk) begin
        if (!table_config.sresetn) begin
            table_config.bvalid    <= 1'b0;
            table_config.rvalid    <= 1'b0;
        end else begin

            // Table Write
            if (table_config.awvalid && table_config.wvalid && !table_config.bvalid) begin
                table_config.bvalid <= 1'b1;
                if (table_wid.address < NUM_ING_PORTS) begin
                    table_config.bresp  <= table_config.OKAY;
                    case (table_wid.select)
                        ING_POLICER_CIR_TABLE : bucket_decrement[table_waddr]       <= table_config.wdata[CIR_TABLE_WIDTH-1:0];
                        ING_POLICER_CBS_TABLE : bucket_depth_threshold[table_waddr] <= table_config.wdata[CBS_TABLE_WIDTH-1:0];
                        default               : table_config.bresp                  <= table_config.SLVERR;
                    endcase
                end else begin
                    table_config.bresp  <= table_config.SLVERR;
                end
            end else if (table_config.bready) begin
                table_config.bvalid <= 1'b0;
            end

            // Table Read
            if (table_config.arvalid && table_config.arready) begin
                table_config.rvalid <= 1'b1;
                table_config.rdata <= '0;
                if (table_rid.address < NUM_ING_PORTS) begin
                    table_config.rresp <= table_config.OKAY;
                    case (table_rid.select)
                        ING_POLICER_CIR_TABLE : table_config.rdata[CIR_TABLE_WIDTH-1:0] <= bucket_decrement[table_raddr];
                        ING_POLICER_CBS_TABLE : table_config.rdata[CBS_TABLE_WIDTH-1:0] <= bucket_depth_threshold[table_raddr];
                        default               : table_config.rresp                      <= table_config.SLVERR;
                    endcase
                end else begin
                    table_config.rresp <= table_config.SLVERR;
                end
            end else if (table_config.rready) begin
                table_config.rvalid <= 1'b0;
            end
        end
    end

    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                ila_debug ila (
                    .clk    ( packet_in.clk                     ),
                    .probe0 ( {packet_in.tvalid,
                               packet_in.tlast,
                               packet_in_sop}                   ),
                    .probe1 ( {packet_out.tvalid,
                               packet_out.tlast}                ),
                    .probe2 ( policer_drop_mark                 ),
                    .probe3 ( bucket[0].whole                   ),
                    .probe4 ( bucket[1].whole                   ),
                    .probe5 ( bucket[2].whole                   ),
                    .probe6 ( bucket[3].whole                   ),
                    .probe7 ( bucket_depth_threshold[0]         ),
                    .probe8 ( bucket_depth_threshold[1]         ),
                    .probe9 ( bucket_depth_threshold[2]         ),
                    .probe10( bucket_depth_threshold[3]         ),
                    .probe11( bucket_decrement[0]               ),
                    .probe12( bucket_decrement[1]               ),
                    .probe13( bucket_decrement[2]               ),
                    .probe14( bucket_decrement[3]               ),
                    .probe15( {packet_in_metadata.ingress_port,
                               packet_in_metadata.byte_length}  )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
