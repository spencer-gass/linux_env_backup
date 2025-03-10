// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 *
 * IP Checksum Generator
 *
 * AXIS backpressure is not allowed. tready should always be 1'b1
 *
 * ipv4_header AXIS interface tdata is expected to be in the following format:
 *   ipv4_header.tdata[159:156] = ip_version
 *   ipv4_header.tdata[155:152] = ip_ihl
 *   ipv4_header.tdata[151:146] = ip_dscp
 *   ipv4_header.tdata[145:144] = ip_ecn
 *   ipv4_header.tdata[143:128] = ip_length
 *   ipv4_header.tdata[127:112] = ip_identification
 *   ipv4_header.tdata[111:109] = ip_flags
 *   ipv4_header.tdata[108:96]  = ip_fragment_offset
 *   ipv4_header.tdata[95:88]   = ip_ttl
 *   ipv4_header.tdata[87:80]   = ip_protocol
 *   ipv4_header.tdata[79:64]   = ip_hdr_chksum
 *   ipv4_header.tdata[63:32]   = ip_source_ip
 *   ipv4_header.tdata[31:0]    = ip_dest_ip
 *
**/
module ipv4_checksum_gen (
    AXIS_int.Slave  ipv4_header,
    AXIS_int.Master ipv4_checksum
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: localparams


    localparam int IPV4_HEADER_NUM_BITS          = 160;
    localparam int IPV4_HEADER_CHECKSUM_NUM_BITS = 16;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_EQUAL(ipv4_header.DATA_BYTES, IPV4_HEADER_NUM_BITS/8);
    `ELAB_CHECK_EQUAL(ipv4_checksum.DATA_BYTES, IPV4_HEADER_CHECKSUM_NUM_BITS/8);
    `ELAB_CHECK_EQUAL(ipv4_header.ALLOW_BACKPRESSURE, 1'b0);
    `ELAB_CHECK_EQUAL(ipv4_checksum.ALLOW_BACKPRESSURE, 1'b0);


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

    // Unused AXIS interface signals
    assign ipv4_header.tready     = 1'b1;
    assign ipv4_checksum.tstrb    = '1;  // if unused, set to '1
    assign ipv4_checksum.tkeep    = '1;  // if unused, set to '1
    assign ipv4_checksum.tid      = '0;  // if unused, set to '0
    assign ipv4_checksum.tdest    = '0;  // if unused, set to '0
    assign ipv4_checksum.tuser    = '0;  // if unused, set to '0

    always_ff @(posedge ipv4_header.clk) begin
        // Stage 1
        tvalid_d <= ipv4_header.tvalid;
        hdr_sum_1 <= {ip_version, ip_ihl, ip_dscp, ip_ecn}
                    + ip_length
                    + ip_identification
                    + {ip_flags, ip_fragment_offset}
                    + {ip_ttl, ip_protocol}
                    + ip_source_ip[31:16]
                    + ip_source_ip[15: 0]
                    + ip_dest_ip[31:16]
                    + ip_dest_ip[15: 0];

        // Stage 2
        ipv4_checksum.tlast  <= tvalid_d;
        ipv4_checksum.tvalid <= tvalid_d;
        ipv4_checksum.tdata  <= hdr_sum_2[15:0];
    end

    always_comb begin
        hdr_sum_2 = hdr_sum_1[15:0] + hdr_sum_1[19:16];
        hdr_sum_2 = hdr_sum_2[15:0] + hdr_sum_2[16];
        hdr_sum_2 = ~hdr_sum_2;
    end

endmodule

`default_nettype wire
