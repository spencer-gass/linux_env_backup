// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * IPv4 Checksum Test Bench Package
**/

`default_nettype none

package ipv4_checksum_tb_pkg;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    localparam bit [3:0] IPV4_VERSION   = 4'h4;
    localparam bit [3:0] IPV4_IHL       = 4'h5;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Type Definitions


    localparam int IPV4_ETHER_TYPE = 15'h0800;

    typedef struct packed {
        bit [47:0] mac_da;
        bit [47:0] mac_sa;
        bit [15:0] ether_type;
    } eth_header_t;

    localparam int ETH_HEADER_BYTES = $bits(eth_header_t) / 8;

    typedef struct packed {
        bit [3:0]   version;  // Version (4 for IPv4)
        bit [3:0]   hdr_len;  // Header length in 32b words
        bit [7:0]   tos;      // Type of service
        bit [15:0]  length;   // Total packet length (header + data) in octets
        bit [15:0]  id;       // Identification
        bit [2:0]   flags;    // Flags
        bit [12:0]  offset;   // Fragment offset
        bit [7:0]   ttl;      // Time to live
        bit [7:0]   protocol; // Next protocol
        bit [15:0]  hdr_chk;  // Header checksum
        bit [31:0]  src;      // Source address
        bit [31:0]  dst;      // Destination address
    } ipv4_header_t;

    localparam int IPV4_HEADER_BYTES = $bits(ipv4_header_t) / 8;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    function bit [15:0] add1c16b;
        input [15:0] a, b;
        bit [16:0] t;
        begin
            t = a+b;
            add1c16b = t[15:0] + t[16];
        end
    endfunction

    function automatic logic [15:0] checksum_update_func(
        input logic [15:0] hc,
        input logic [15:0] m,
        input logic [15:0] m_prime
    );
        automatic logic [15:0] sum;
        sum = add1c16b(~hc, ~m);
        sum = add1c16b(sum, m_prime);
        sum = ~sum;
        return sum;
    endfunction

    function automatic logic [15:0] ipv4_checksum_gen_func(
        input var ipv4_header_t ip_hdr
    );
        automatic logic [19:0] sum;

        sum = {ip_hdr.version, ip_hdr.hdr_len, ip_hdr.tos} +
               ip_hdr.length +
               ip_hdr.id +
               {ip_hdr.flags, ip_hdr.offset} +
               {ip_hdr.ttl, ip_hdr.protocol} +
               ip_hdr.src[31:16] +
               ip_hdr.src[15: 0] +
               ip_hdr.dst[31:16] +
               ip_hdr.dst[15: 0];

        sum = sum[15:0] + sum[19:16];
        sum = sum[15:0] + sum[16];
        return ~sum[15:0];

    endfunction

    function automatic logic ipv4_checksum_verify_func(
        input  var ipv4_header_t ip_hdr
    );
        automatic logic [15:0] sum;

        sum = ipv4_checksum_gen_func(ip_hdr);
        return ~|(~sum[15:0] + ip_hdr.hdr_chk);

    endfunction

endpackage
