/* -*- P4_16 -*- */
#include <core.p4>
#include <xsa.p4>

typedef bit<32> VRFId; /* same bitwidth as FRR vrf_id_t struct */

typedef bit<48>  MacAddr;
typedef bit<16>  EtherType;
typedef bit<12>  VlanId;
typedef bit<20>  MplsLabel;
typedef bit<32>  IPv4Addr;
typedef bit<128> IPv6Addr;

typedef bit<8> EgressSpec;
typedef bit<8> PortId;

/* EtherTypes */
const bit<16> TYPE_DOT1Q = 0x8100;
const bit<16> TYPE_MPLS = 0x8847;
const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86DD;

/* Max. number of MPLS labels */
const bit<4> NUM_LABELS = 8;

/* MPLS Label Types (BGP, IS-IS) */
const bit<20> BGP_LABEL = 20w0x0;
const bit<20> ISIS_LABEL = 20w0x0;

/* MPLS Label Range Struct */
struct LabelRange {
    bit<20> min;
    bit<20> max;
}

/* Local Adjacency and Global Label ID ranges for both BGP and IS-IS */
const LabelRange BGP_GLOBAL = { 20w100, 20w999 };
const LabelRange ISIS_LOCAL = { 20w15000, 20w15999 };
const LabelRange ISIS_GLOBAL = { 20w16000, 20w23999 };

const bit<2> pad2 = 0;

/*************************************************************************
**********|  H E A D E R S  **********************************************
*************************************************************************/

header eth_mac_t {
    MacAddr   dst;      // Destination address
    MacAddr   src;      // Source address
    EtherType type;     // Payload protocol type
}

header vlan_t {
    bit<3>    pcp;      // Priority code point
    bit<1>    cfi;      // Drop eligible indicator
    VlanId    vid;      // VLAN identifier
    bit<16>   tpid;     // Tag protocol identifier
}

/* Raw header to extract labels from the MPLS label stack */
header label_raw_t {
    bit<32> label;      // Multiple of 8w
}

header mpls_t {
    MplsLabel label;    // MPLS label value
    bit<3>    exp;      // Experimental bits/traffic class
    bit<1>    bos;      // Bottom-of-Stack
    bit<8>    ttl;      // Time to live
}

/* Raw Byte header to extract IP version (raw 4 bits) of unknown IP header type (IPv4 or IPv6) */
header ip_raw_t {
    bit<4> version;
    bit<4> other;
}

header ipv4_t {
    bit<4>    version;  // Version (4 for IPv4)
    bit<4>    hdr_len;  // Header length in 32b words
    bit<8>    tos;      // Type of service
    bit<16>   length;   // Total packet length (header + data) in octets
    bit<16>   id;       // Identification
    bit<3>    flags;    // Flags
    bit<13>   offset;   // Fragment offset
    bit<8>    ttl;      // Time to live
    bit<8>    protocol; // Next protocol
    bit<16>   hdr_chk;  // Header checksum
    IPv4Addr  src;      // Source address
    IPv4Addr  dst;      // Destination address
}

header ipv6_t {
    bit<4>    version;  // Version (6 for IPv6)
    bit<8>    tc;       // Traffic class
    bit<20>   label;    // Packet flow label
    bit<16>   data_len; // Payload length in octets
    bit<8>    nxt_hdr;  // Next header type
    bit<8>    limit;    // Hop limit
    IPv6Addr  src;      // Source address
    IPv6Addr  dst;      // Destination address
}

/*************************************************************************
**********|  S T R U C T U R E S  ****************************************
*************************************************************************/

/* Headers struct */
struct headers {
    eth_mac_t eth;
    vlan_t    vlan;     // Single VLAN header/tag (IEEE 802.1q)
    mpls_t[NUM_LABELS] mpls; // Max. 8 MPLS headers
    label_raw_t[NUM_LABELS] labels; // MPLS label stack
    ip_raw_t  raw_byte; // Only used to extract the IP header version
    ipv4_t    ipv4;     // NOTE(jjardim): take a look at 'header_union'
    ipv6_t    ipv6;     // NOTE(jjardim): take a look at 'header_union'
}

/* User metadata struct */
struct user_metadata {
    bit<8> ingress_port;
    bit<8> egress_spec;
    headers hdrs;
}


/*************************************************************************
**********|  U S E R - D E F I N E D   E R R O R S  **********************
*************************************************************************/

/* User-defined errors that may be signaled during parsing - not currently used */
error {
    IPv4OptionsNotSupported,
    IPv4IncorrectVersion,
    IPv4ChecksumError
}

/*************************************************************************
**********|  P A R S E R  ************************************************
*************************************************************************/

parser FRRdplaneParser(packet_in packet,
                       out headers hdr,
                       inout user_metadata meta,
                       inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.eth);
        transition select(hdr.eth.type) {
            TYPE_DOT1Q: parse_vlan;
            TYPE_MPLS: parse_mpls;
            TYPE_IPV4: parse_ipv4;
            TYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan);
        transition select(hdr.vlan.tpid) {
            TYPE_IPV4: parse_ipv4;
            TYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }

    state parse_mpls {
        packet.extract(hdr.mpls.next);
        transition select(hdr.mpls.last.bos) {
            0: parse_mpls; // parse_label;
            1: parse_mpls_payload;
        }
    }

    // state parse_label {
    //     packet.extract(hdr.labels.next);
    //     bit<20> label = hdr.labels.last.label[31:12];
    //     label = hdr.mpls.last.label;
    //     transition select(label) {
    //         default: parse_mpls;
    //     }
    // }

    state parse_mpls_payload {
        packet.extract(hdr.raw_byte);
        transition select(hdr.raw_byte.version) {
            4: parse_ipv4;
            6: parse_ipv6;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        // verify(hdr.ipv4.version == 4, error.IpVersionNotSupported);
        transition accept;
    }

    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition accept;
    }
}

/*************************************************************************
**********|  I N G R E S S   P R O C E S S I N G  ************************
*************************************************************************/

control FRRdplaneIngress(inout headers hdr,
                         inout user_metadata meta,
                         inout standard_metadata_t standard_metadata) {

    meta.hdrs = hdr;
}

/*************************************************************************
**********|  D E P A R S E R  ********************************************
*************************************************************************/

control FRRdplaneDeparser(packet_out packet,
                          in headers hdr,
                          inout user_metadata meta,
                          inout standard_metadata_t standard_metadata) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.vlan);
        packet.emit(hdr.mpls);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
**********|  S W I T C H  ************************************************
*************************************************************************/

XilinxPipeline(
FRRdplaneParser(),
FRRdplaneIngress(),
FRRdplaneDeparser()
) main;
