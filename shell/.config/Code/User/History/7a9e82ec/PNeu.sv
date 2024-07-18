// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * IP Checksum Generator
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module ipv4_checksum_gen (
    AXIS_int.Slave  ipv4_header,
    AXIS_int.Master ipv4_checksum,
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: localparams

    localparam int IPV4_HEADER_NUM_BITS = 160;
    localparam int IPV4_HEADER_CHECKSUM_NUM_BITS = 16;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration checks

    `ELAB_CHECK_EQUAL(ipv4_header.DATALEN, IPV4_HEADER_NUM_BITS);
    `ELAB_CHECK_EQUAL(ipv4_checksum.DATALEN, IPV4_HEADER_CHECKSUM_NUM_BITS);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations

    logic [19:0] hdr_sum_1;
    logic [16:0] hdr_sum_2;
    logic        tvalid_d;

    logic [3:0]  ip_version;
    logic [3:0]  ip_ihl;
    logic [5:0]  ip_dscp;
    logic [1:0]  ip_ecn;
    logic [15:0] ip_length;
    logic [15:0] ip_identification;
    logic [2:0]  ip_flags;
    logic [12:0] ip_fragment_offset;
    logic [7:0]  ip_ttl;
    logic [7:0]  ip_protocol;
    logic [16:0] ip_hdr_chksum;
    logic [31:0] ip_source_ip;
    logic [31:0] ip_dest_ip;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    assign ip_version          = ipv4_header.tdata[159:156];
    assign ip_ihl              = ipv4_header.tdata[155:152];
    assign ip_dscp             = ipv4_header.tdata[151:146];
    assign ip_ecn              = ipv4_header.tdata[145:144];
    assign ip_length           = ipv4_header.tdata[143:128];
    assign ip_identification   = ipv4_header.tdata[127:112];
    assign ip_flags            = ipv4_header.tdata[111:109];
    assign ip_fragment_offset  = ipv4_header.tdata[108:96];
    assign ip_ttl              = ipv4_header.tdata[95:88];
    assign ip_protocol         = ipv4_header.tdata[87:80];
    assign ip_hdr_chksum       = ipv4_header.tdata[79:64];
    assign ip_source_ip        = ipv4_header.tdata[63:32];
    assign ip_dest_ip          = ipv4_header.tdata[31:0];

    always_ff @(posedge clk) begin
        // Stage 1
        ipv4_header.tready <= '1'; // This module does not support backpressure
        tvalid_d <= ipv4_header.tvalid;
        hdr_sum_1 <= {ip_version, ip_ihl, ip_dscp, ip_ecn} +
                    ip_length +
                    ip_identification +
                    {ip_flags, ip_fragment_offset} +
                    {ip_ttl, ip_protocol} +
                    ip_source_ip[31:16] +
                    ip_source_ip[15: 0] +
                    ip_dest_ip[31:16] +
                    ip_dest_ip[15: 0];

        // Stage 2
        ipv4_checksum.tvalid <= tvalid_d;
        ipv4_checksum.tdata <= hdr_sum_2[15:0];
    end

    always_comb begin
        hdr_sum_2 = hdr_sum_1[15:0] + hdr_sum_1[19:16];
        hdr_sum_2 = hdr_sum_2[15:0] + hdr_sum_2[16];
        hdr_sum_2 = ~hdr_sum_2;
    end

endmodule

`default_nettype wire
