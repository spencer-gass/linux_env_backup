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

typedef bit<9>  egressSpec_t;
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
    bit<10> ingress_port;
    bit<9> egress_spec;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser FRRdplaneParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
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

    state parse_mpls_payload {
        transition select(packet.lookahead<ipv4_t>().version) {
            4: parse_ipv4;
            6: parse_ipv6;
            default: accept;
        }
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

control FRRdplaneVerifyChecksum(inout headers hdr, inout metadata meta) {
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

    action fwd_port(egressSpec_t port) {
        user_meta.egress_spec = port;
    }

    action punt_to_cpu() {
        user_meta.egress_spec = CPU_OUT_PORT;
    }

    /* No-op when the in-label is the same as the out-label (SR label) */
    action mpls_noop(ip4Addr_t nexthop, /*mplsLabel_t out_label, */macAddr_t src_addr, macAddr_t dst_addr, egressSpec_t port) {
        /* TODO(jjardim): SR In-label same as Out-label */
        hdr.ipv4.dstAddr = nexthop;
        // hdr.mpls[0].label = out_label;
        hdr.ethernet.srcAddr = src_addr;
        hdr.ethernet.dstAddr = dst_addr;
        user_meta.egress_spec = port;

        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        hdr.mpls[0].exp = hdr.mpls[0].exp - 1;
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;
    }

    action mpls_push(ip4Addr_t nexthop, mplsLabel_t out_label, macAddr_t src_addr, macAddr_t dst_addr, egressSpec_t port) {
        /* Push MPLS label */
        hdr.ipv4.dstAddr = nexthop;
        hdr.mpls[0].label = out_label;
        hdr.ethernet.srcAddr = src_addr;
        hdr.ethernet.dstAddr = dst_addr;
        user_meta.egress_spec = port;

        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = 64;
    }

    action mpls_pop(ip4Addr_t nexthop, /*mplsLabel_t out_label, */macAddr_t src_addr, macAddr_t dst_addr, egressSpec_t port) {
        /* Pop MPLS label */
        hdr.ipv4.dstAddr = nexthop;
        // hdr.mpls[0].label = out_label;
        hdr.ethernet.srcAddr = src_addr;
        hdr.ethernet.dstAddr = dst_addr;
        user_meta.egress_spec = port;

        hdr.mpls[0].exp = hdr.mpls[0].exp - 1;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action mpls_swap(ip4Addr_t nexthop, mplsLabel_t out_label, macAddr_t src_addr, macAddr_t dst_addr, egressSpec_t port) {
        /* Swap MPLS label */
        hdr.ipv4.dstAddr = nexthop;
        hdr.mpls[0].label = out_label;
        hdr.ethernet.srcAddr = src_addr;
        hdr.ethernet.dstAddr = dst_addr;
        user_meta.egress_spec = port;

        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        hdr.mpls[0].exp = hdr.mpls[0].exp - 1;
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;
    }

    table port_map {
        key = {
            user_meta.ingress_port: exact;
        }
        actions = {
            fwd_port;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* Mgmt Plane */
    /* TODO(jjardim): Do we need this table, or just need the 'punt' action? */
    //table cmp {
    //    actions = {
    //        punt_to_cpu;
    //    }
    //    default_action = punt_to_cpu;
    //}

    /* Label Edge Routing table
     * Match key fields below can be ommitted ("don't care" matches)
     */
    table mpls_ler_fib {
        key = {
            hdr.mpls[0].label: exact; /* VPN label for egress traffic (destined for a customer) */
            hdr.ipv4.dstAddr: lpm;  /* Map destination IP addr to a VPN label (ingress traffic) */
        }
        actions = {
            mpls_push; /* Customer VPN label (ingress => from customer to network) */
            mpls_pop; /* Customer VPN label (egress => from network to customer) */
            // mpls_egress;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    /* Label-Switch Routing table */
    table mpls_lsr_fib {
        key = {
            hdr.mpls[0].label: exact;
        }
        actions = {
            mpls_push; /* Transport/SR label */
            mpls_pop; /* Transport/SR label */
            mpls_swap; /* Transport/SR label */
            mpls_noop; /* Transport/SR label */
            // mpls_egress;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        //(jjardim) transport label (bos=0)
        // - out_label = 0 (explicit null)
        // - out_label = 3 (PHP, implicit null)

        /* Ingress ports are customer ports.
         * Maybe maintain an array of known customer ports and look-up ingress port in array.
         */
        // if (user_meta.ingress_port == ) {
        // }

        if (hdr.ethernet.etherType == TYPE_MPLS) {
            /* MPLS packet */
            if (hdr.mpls[0].bos == 0) { /* Check if topmost MPLS packet is not the bottom-of-stack */
                /* There is a transport label (in addition to VPN label), i.e., not MPLS bottom-of-the-stack */
                mpls_lsr_fib.apply();
            } else {
                if (hdr.mpls[0].label >= BGP_GLOBAL.min && hdr.mpls[0].label <= BGP_GLOBAL.max) {
                    /* MPLS Bottom-of-stack and VPN label only (BGP origin) */
                    mpls_ler_fib.apply();
                } else if ((hdr.mpls[0].label >= ISIS_LOCAL.min && hdr.mpls[0].label <= ISIS_LOCAL.max)
                || (hdr.mpls[0].label >= ISIS_GLOBAL.min && hdr.mpls[0].label <= ISIS_GLOBAL.max)) {
                    /* MPLS Bottom-of-stack and transport label only (IS-IS origin) */
                    mpls_lsr_fib.apply();
                }
            }
        } else {
            /* Non-MPLS packet */
            port_map.apply();
            // cmp.apply();
        }
        // // if ipv4 packet, do this
        // } else if (hdr.ethernet.etherType == TYPE_IPV4) {
        //     port_map.apply();
        // } else if (hdr.ethernet.etherType == TYPE_IPV6) {
        //     port_map.apply();
        // } else {
        //     drop();
        // }


        // if packet is mpls
        //   if it is bottom of stack
        //     lookup route table X from mpls vpn label
        //     lookup lpm on dst IP address in route table X
        //     build outgoing packet metadata (could be setting VLAN ID if customer interface requires VLAN tagging)
        //   else
        //     lookup in mpls table
        //     build outgoing packet metadata

        // if packet is not mpls, then do the following
        //   if dst IP address is a CPU address
        //     punt to CPU (apply correct VLAN ID and send to CPU port)
        // else
        //     process as customer ingress traffic

    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control FRRdplaneEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control FRRdplaneComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
        // update_checksum(
        // hdr.ipv4.isValid(),
        //     { hdr.ipv4.version,
        //       hdr.ipv4.ihl,
        //       hdr.ipv4.diffserv,
        //       hdr.ipv4.totalLen,
        //       hdr.ipv4.identification,
        //       hdr.ipv4.flags,
        //       hdr.ipv4.fragOffset,
        //       hdr.ipv4.ttl,
        //       hdr.ipv4.protocol,
        //       hdr.ipv4.srcAddr,
        //       hdr.ipv4.dstAddr },
        //     hdr.ipv4.hdrChecksum,
        //     HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control FRRdplaneDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);

        // if (packet.mpls.isValid()) {
        packet.emit(hdr.mpls);
        // }

        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

XilinxPipeline(
FRRdplaneParser(),
FRRdplaneVerifyChecksum(),
FRRdplaneIngress(),
FRRdplaneEgress(),
FRRdplaneComputeChecksum(),
FRRdplaneDeparser()
) main;
