/* -*- P4_16 -*- */
#include <core.p4>
#include <xsa.p4>

typedef bit<9> PortId;
const PortId CPU_OUT_PORT = 0x1;

const bit<16> TYPE_MPLS = 0x8847;
const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86DD;

const bit<20> BGP_LABEL = 20w0x0;
const bit<20> ISIS_LABEL = 20w0x0;

/* MPLS Label Range Struct */
struct Label {
    bit<20> max;
    bit<20> min;
}

/* Local Adjacency and Global Label ID ranges for both BGP and IS-IS */
const Label BGP_GLOBAL = { 20w100, 20w999 };
const Label ISIS_LOCAL = { 20w15000, 20w15999 };
const Label ISIS_GLOBAL = { 20w16000, 20w23999 };


/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<8>  port_t;
typedef bit<48> macAddr_t;
typedef bit<16> etherType_t;
typedef bit<20> mplsLabel_t;
typedef bit<32> ip4Addr_t;
typedef bit<128> ip6Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    etherType_t etherType;
}

header mpls_t {
    bit<20> label;
    bit<3> exp;
    bit<1> bos;
    bit<8> ttl;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header ipv6_t {
    bit<4>    version;
    bit<8>    trafficClass;
    bit<20>   flowLabel;
    bit<16>   payloadLen;
    bit<8>    nextHdr;
    bit<8>    hopLimit;
    ip6Addr_t srcAddr;
    ip6Addr_t dstAddr;
}

struct headers {
    ethernet_t   ethernet;
    mpls_t[8]       mpls;
    ipv4_t          ipv4;
    ipv6_t          ipv6;
}

struct user_metadata_t {
    port_t port;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser FRRdplaneParser(packet_in packet,
                out headers hdr,
                inout user_metadata_t user_meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_MPLS: parse_mpls;
            TYPE_IPV4: parse_ipv4;
            TYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }

    state parse_mpls {
        packet.extract(hdr.mpls.next);
        transition select(hdr.mpls.last.bos) {
            0: parse_mpls;
            1: parse_mpls_payload;
        }
    }

    // Xilinx p4 compiler gives the following error message:
    // "Local variables not supported in parser"
    // lookahead function creates local variables so it isn't a feature we can use.
    //
    // state parse_mpls_payload {
    //     transition select(packet.lookahead<ipv4_t>().version) {
    //         4: parse_ipv4;
    //         6: parse_ipv6;
    //         default: accept;
    //     }
    // }

    // Treat all packets as IPv4 untill we can figure out how to get around lookahead not being supported
    state parse_mpls_payload {
        transition parse_ipv4;

    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control FRRdplaneVerifyChecksum(inout headers hdr, inout user_metadata_t user_meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control FRRdplaneIngress(inout headers hdr,
                  inout user_metadata_t user_meta,
                  inout standard_metadata_t standard_metadata) {

    /* TODO: mpls_ actions ( _push, _pop, _swap, _noop, _punt, _egress) */
    action drop() {
        standard_metadata.drop = 1;
    }

    action fwd_port(port_t port) {
        user_meta.port = port;
    }

    apply {

        if (hdr.ethernet.etherType == TYPE_IPV4) {
            fwd_port(user_meta.port);
        } else {
            fwd_port(255);
            drop()
        }
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control FRRdplaneDeparser(packet_out packet,
                          in headers hdr,
                          inout user_metadata_t user_meta,
                          inout standard_metadata_t standard_metadata) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

XilinxPipeline(
FRRdplaneParser(),
FRRdplaneIngress(),
FRRdplaneDeparser()
) main;
