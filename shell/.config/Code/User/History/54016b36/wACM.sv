// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Policer
 * Leaky bucket policer - bucket accumulator decrements at a configurable rate and increments by input packet byte length.
 * If the bucket occupancy crosses the configurable threshold, packets are marked to drop.
 * This module does not drop packets. It asserts the drop mark in metadata to instruct the congestion manager to drop them.
 * One bucket per ingress port to implement ingress shapers.
 * This module works like a virtual ingress queue where the leaky bucket represents packets in the virtual ingress queue.
 *
 * Bucket and decrement are fixed point numbers with enough precision to shape in units of Mbps.
 * Could revise to reduce presision if it isn't needed.
 *
 * bucket_decrement is in units of bytes/clock
 * to convert from Mbps:
 *  Mbits/Sec -> bits/us * 1 bytes / 8 bits * 1 us / 1000ns * CLOCK_PERIOD ns / 1 clock = bytes/clock
 * CLOCK_PERIOD_NS should be provided as a RO register so that software can convert a provisioned Mbps CIR to bytes/cycle.
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_policer
    import p4_router_pkg::*;
#(
    parameter int MTU_BYTES = 2000,
    parameter int NUM_ING_PORTS = 0
) (

    input var logic [NUM_ING_PORTS-1:0] enable,
    AXI4Lite_int.Master table_config,

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


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    vnp4_wrapper_metadata_t   packet_in_metadata;
    vnp4_wrapper_metadata_t   packet_in_metadata_d;

    bucket_decrement_t        bucket_decrement       [NUM_ING_PORTS-1:0],
    bucket_depth_threshold_t  bucket_depth_threshold [NUM_ING_PORTS-1:0],

    bucket_t bucket [NUM_ING_PORTS-1:0];
    logic    policer_drop_mark;
    logic    packet_in_sop;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Leaky Bucket

    assign packet_in_metadata = packet_in.tuser;

    always_ff @(posedge packet_in.clk) begin
        if(!packet_in.sresetn) begin
            bucket <= '{default: '0};
            policer_drop_mark <= 1'b0;
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
                            bucket[ing_port] <= bucket[ing_port] + (packet_in_metadata.byte_length << $size(bucket_decrement[ing_port].fraction)) - bucket_decrement[ing_port];
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

    always_ff @(posedge table_config.clk) begin
        if (!table_config.sresetn) begin

        end else begin

        end
    end
        assign awready = 1'b1;
        assign wready  = 1'b1;

        input               awaddr,
        input               awprot,
        input               awvalid,
        input               wdata,
        input               wstrb,
        input               wvalid,
        output              bresp,
        output              bvalid,
        input               bready,
        input               araddr,
        input               arprot,
        input               arvalid,
        output              arready,
        output              rdata,
        output              rresp,
        output              rvalid,
        input               rready

endmodule

`default_nettype wire
