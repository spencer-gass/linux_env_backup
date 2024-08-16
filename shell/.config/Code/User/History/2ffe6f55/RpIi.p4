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
typedef bit<8> lable_valid_t;

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
    ip_raw_t  raw_byte; // Only used to extract the IP header version
    ipv4_t    ipv4;     // NOTE(jjardim): take a look at 'header_union'
    ipv6_t    ipv6;     // NOTE(jjardim): take a look at 'header_union'
}

/* User metadata struct */
struct user_metadata {
    bit<8> ingress_port;
    bit<8> egress_spec;
    bit<32> vrf_id;
    eth_mac_t eth;
    vlan_t    vlan;     // Single VLAN header/tag (IEEE 802.1q)
    mpls_t[NUM_LABELS] mpls; // Max. 8 MPLS headers
    ipv4_t    ipv4;     // NOTE(jjardim): take a look at 'header_union'
    ipv6_t    ipv6;     // NOTE(jjardim): take a look at 'header_union'
    bit<1>  eth_valid;
    bit<1>  vlan_valid;
    lable_valid_t mpls_valid;
    lable_valid_t label_raw_valid;
    bit<1> ipv4_valid;
    bit<1> ipv6_valid;
}

struct chksum_update_in_t {
    bit<16>  hdr_chk;  // Header checksum
    bit<8>   old_ttl;  // Time to live
    bit<8>   new_ttl;  // Updated time to live
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
        // Ethernet
        hdr.eth.dst = meta.eth.dst;
        hdr.eth.src = meta.eth.src;
        hdr.eth.type = meta.eth.type;
        // VLAN
        hdr.vlan.pcp = meta.vlan.pcp;
        hdr.vlan.cfi = meta.vlan.cfi;
        hdr.vlan.vid = meta.vlan.vid;
        hdr.vlan.tpid = meta.vlan.tpid;
        // MPLS
        hdr.mpls[0].label = meta.mpls[0].label;
        hdr.mpls[0].exp = meta.mpls[0].exp;
        hdr.mpls[0].bos = meta.mpls[0].bos;
        hdr.mpls[0].ttl = meta.mpls[0].ttl;

        hdr.mpls[1].label = meta.mpls[1].label;
        hdr.mpls[1].exp = meta.mpls[1].exp;
        hdr.mpls[1].bos = meta.mpls[1].bos;
        hdr.mpls[1].ttl = meta.mpls[1].ttl;

        hdr.mpls[2].label = meta.mpls[2].label;
        hdr.mpls[2].exp = meta.mpls[2].exp;
        hdr.mpls[2].bos = meta.mpls[2].bos;
        hdr.mpls[2].ttl = meta.mpls[2].ttl;

        hdr.mpls[3].label = meta.mpls[3].label;
        hdr.mpls[3].exp = meta.mpls[3].exp;
        hdr.mpls[3].bos = meta.mpls[3].bos;
        hdr.mpls[3].ttl = meta.mpls[3].ttl;

        hdr.mpls[4].label = meta.mpls[4].label;
        hdr.mpls[4].exp = meta.mpls[4].exp;
        hdr.mpls[4].bos = meta.mpls[4].bos;
        hdr.mpls[4].ttl = meta.mpls[4].ttl;

        hdr.mpls[5].label = meta.mpls[5].label;
        hdr.mpls[5].exp = meta.mpls[5].exp;
        hdr.mpls[5].bos = meta.mpls[5].bos;
        hdr.mpls[5].ttl = meta.mpls[5].ttl;

        hdr.mpls[6].label = meta.mpls[6].label;
        hdr.mpls[6].exp = meta.mpls[6].exp;
        hdr.mpls[6].bos = meta.mpls[6].bos;
        hdr.mpls[6].ttl = meta.mpls[6].ttl;

        hdr.mpls[7].label = meta.mpls[7].label;
        hdr.mpls[7].exp = meta.mpls[7].exp;
        hdr.mpls[7].bos = meta.mpls[7].bos;
        hdr.mpls[7].ttl = meta.mpls[7].ttl;
        transition accept;
    }
}

/*************************************************************************
**********|  I N G R E S S   P R O C E S S I N G  ************************
*************************************************************************/

control FRRdplaneIngress(inout headers hdr,
                         inout user_metadata meta,
                         inout standard_metadata_t standard_metadata) {

    action drop() {
        standard_metadata.drop = 1;
    }

    /*************************************************************************
    **********|  I P v 4 / I N T E R F A C E   M A P   A C T I O N S  ********
    *************************************************************************/

    /**
     * These actions describe the processing of traffic ingressing and egressing the PS (Processing
     * System), respectively. I.e.:
     * - From PL to PS (punted to CPU): identify the Linux sub-interface based on the FPGA interface
     *   and CPU interface IP address. Tag accordingly with corresponding VLAN ID and forward to PS.
     * - From PS to PL (CPU originated): identify the FPGA interface based on the CPU interface it
     *   arrived from. Strip VLAN tag and forward to PL.
     */

    action tag_dot1q (VRFId vrf_id, /*IPv4Addr ip_prefix,*/ VlanId vlan_id, /*MacAddr src_addr, MacAddr dst_addr,*/ EgressSpec port) {
        /* Insert VLAN header */
        hdr.vlan.cfi = 0;
        hdr.vlan.vid = vlan_id;
        hdr.vlan.tpid = hdr.eth.type;

        /* Update Ethernet header type */
        hdr.eth.type = TYPE_DOT1Q;

        /* Store VRF ID in the user metadata - NOTE(jjardim): not sure if needed */
        meta.vrf_id = vrf_id;

        /* CPU interface ID (out) */
        meta.egress_spec = port;
    }

    action tag_dot1q_ipv4 (VRFId vrf_id, /*IPv4Addr ip_prefix,*/ VlanId vlan_id, /*MacAddr src_addr, MacAddr dst_addr,*/ EgressSpec port) {
        tag_dot1q(vrf_id, vlan_id, port);
        hdr.vlan.pcp = hdr.ipv4.tos[7:5];
    }

    action tag_dot1q_ipv6 (VRFId vrf_id, /*IPv4Addr ip_prefix,*/ VlanId vlan_id, /*MacAddr src_addr, MacAddr dst_addr,*/ EgressSpec port) {
        tag_dot1q(vrf_id, vlan_id, port);
        hdr.vlan.pcp = hdr.ipv6.tc[7:5];
    }

    action strip_dot1q(EgressSpec port) {
        /* Update Ethernet header type */
        hdr.eth.type = hdr.vlan.tpid;

        /* FPGA interface ID (out) */
        meta.egress_spec = port;
    }

    /*************************************************************************
    **********|  M P L S   T A B L E   A C T I O N S  ************************
    *************************************************************************/

    /**
     * These actions describe the processing of MPLS traffic:
     * - Performed at the LER (Label Edge Router): label push (ingressing the MPLS network) and pop
     *   (egressing the MPLS network)
     * - Performed at the LSR (Label Switch Router): label pop/push, swap/noop (when segment routed,
     *   label ID's don't change along the path and, thus, there is no need to swap -> noop)
     */

    action mpls_push(VRFId vrf_id, MplsLabel out_label, /*LabelStack label_stack, */MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_MPLS;

        /* MPLS push */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): single or label stack?
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = 64;

        /* Customer VRF ID in the user metadata */
        meta.vrf_id = vrf_id;

        /* TX (FPGA) interface */
        meta.egress_spec = port;
    }

    action mpls_push_ipv4(VRFId vrf_id, IPv4Addr ip_prefix, MplsLabel out_label, /*LabelStack label_stack, */MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common push opperations
        mpls_push(vrf_id, out_label, src_addr, dst_addr, port);

        // IPv4 specific opperations
        hdr.mpls[0].exp = hdr.ipv4.tos[7:5]; // TODO(jjardim): do we need to update all MPLS headers in the stack?
        hdr.ipv4.dst = ip_prefix; // TODO(jjardim): remove?
    }

    action mpls_push_ipv6(VRFId vrf_id, IPv4Addr ip_prefix, MplsLabel out_label, /*LabelStack label_stack, */MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common push opperations
        mpls_push(vrf_id, out_label, src_addr, dst_addr, port);

        // IPv6 specific opperations
        hdr.mpls[0].exp = hdr.ipv6.tc[7:5]; // TODO(jjardim): do we need to update all MPLS headers in the stack?
    }

    action mpls_pop(VRFId vrf_id, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS pop */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): out_label = 3 (PHP, implicit null)
        // hdr.mpls[0].setInvalid(); // NOTE(jjardim): remove hdr form pkt? (https://opennetworking.org/wp-content/uploads/2020/12/p4-cheat-sheet.pdf)
        //                           // If setInvalid, remove above line (out_label) to prevent undefined behaviour

        /* Customer VRF ID */
        meta.vrf_id = vrf_id;

        /* TX (FPGA) interface */
        meta.egress_spec = port;
    }

    action mpls_pop_ipv4(VRFId vrf_id, IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common pop opperations
        mpls_pop(vrf_id, out_label, src_addr, dst_addr, port);

        // IPv4 specific opperations
        hdr.eth.type = TYPE_IPV4; // NOTE(jjardim): assuming IPv4 payload, by default, when popping MPLS header(s)
        hdr.ipv4.dst = ip_prefix;
    }

    action mpls_pop_ipv6(VRFId vrf_id, IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common pop opperations
        mpls_pop(vrf_id, out_label, src_addr, dst_addr, port);

        // IPv6 specific opperations
        hdr.eth.type = TYPE_IPV6;
    }

    action mpls_swap(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS swap */
        hdr.mpls[0].label = out_label;
        // hdr.mpls[0].exp = hdr.mpls[0].exp - 1; // TODO(jjardim): do the exp bits need updating?
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        meta.egress_spec = port;
    }

    action mpls_swap_ipv4(IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common swap opperations
        mpls_swap(out_label, src_addr, dst_addr, port);

        // IPv4 specific opperations
        hdr.ipv4.dst = ip_prefix; // TODO(jjardim): remove?
    }

    action mpls_swap_ipv6(IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common swap opperations
        mpls_swap(out_label, src_addr, dst_addr, port);

        // No additional opperations for IPv6
    }

    action mpls_noop(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS noop */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): Segment Routing, i.e., in_label same as out_label
        // hdr.mpls[0].exp = hdr.mpls[0].exp - 1; // TODO(jjardim): do the exp bits need updating?
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        /* TX (FPGA) interface */
        meta.egress_spec = port; // TODO(jjardim): update with user metadata port
    }

    action mpls_noop_ipv4(IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common noop opperations
        mpls_noop(out_label, src_addr, dst_addr, port);

        // IPv4 specific opperations
        hdr.ipv4.dst = ip_prefix; // TODO(jjardim): remove?
    }

    action mpls_noop_ipv6(IPv4Addr ip_prefix, MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, EgressSpec port) {
        // Common noop opperations
        mpls_noop(out_label, src_addr, dst_addr, port);

        // No additional opperations for IPv6
    }

    /* Control/Mgmt. Plane (CPU originated) - Egress */
    table cmp_egress {
        key = {
            meta.ingress_port: exact; // CPU interface ID (incoming)
            pad2 : unused; // BCAM requires minimum 10-bit key. padding with zeros to meet the requirement.
        }
        actions = {
            strip_dot1q;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* Table which processes ingressing packets either to the CPU (punting),
     * or to the Kepler MPLS network. */
    table mpcu_ingress {
        key = {
            meta.ingress_port: exact; // FPGA interface ID (incoming)
            // meta.vrf_id: exact; // VRF ID
            hdr.ipv4.dst: lpm; // Destination IPv4 prefix, or CPU interface IP local address
        }
        actions = {
            tag_dot1q_ipv4; /* Effectively, tagging and punting to CPU */
            tag_dot1q_ipv6; /* Effectively, tagging and punting to CPU */
            mpls_push; /* Push label stack to customer traffic entering MPLS network */
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction(); // TODO(jjardim): NoAction to test/bypass; change back to drop() ?
    }

    /* Label Edge Routing table (egress) */
    table mpls_ler_egress {
        key = {
            hdr.mpls[0].label: exact; /* VPN label of customer egress traffic */
        }
        actions = {
            mpls_pop_ipv4; /* Pop customer label (stack) exiting the MPLS network */
            mpls_pop_ipv6; /* Pop customer label (stack) exiting the MPLS network */
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
            mpls_push_ipv4; /* Push transport label to packet traversing the MPLS network */
            mpls_push_ipv6; /* Push transport label to packet traversing the MPLS network */
            mpls_pop_ipv4; /* Pop transport label from packet traversing the MPLS network */
            mpls_pop_ipv6; /* Pop transport label from packet traversing the MPLS network */
            mpls_swap_ipv4; /* Swap transport label of the packet traversing the MPLS network */
            mpls_swap_ipv6; /* Swap transport label of the packet traversing the MPLS network */
            mpls_noop_ipv4; /* Same as swap, however, no need to effectively swap as the in- and out-labels as the same */
            mpls_noop_ipv6; /* Same as swap, however, no need to effectively swap as the in- and out-labels as the same */
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    chksum_update_in_t chksum_update_in;
    bit<1> checksum_valid;

    UserExtern<ipv4_t,bit<1>>(3) UserIPv4ChkVerify;
    UserExtern<chksum_update_in_t,bit<16>>(1) UserIPv4ChkUpdate;

    apply {

        if (hdr.eth.type == TYPE_DOT1Q) {
            /* From CPU interface (CMP packet egressing) */
            cmp_egress.apply();
        }

        if (hdr.eth.type == TYPE_MPLS) {
            /* NOTE(jjardim):
             * label types:
             * - transport: bos=0
             * - customer/VPN: bos=1
             * out_label values:
             * - 0: explicit null
             * - 3: PHP, implicit null
             */

            /* MPLS packet */
            if (hdr.mpls[0].bos == 0) { /* Check if topmost MPLS packet is not the bottom-of-stack */
                /* There is a transport label (in addition to VPN label), i.e., not MPLS bottom-of-the-stack */
                mpls_lsr_fib.apply();
            } else {
                if (hdr.mpls[0].label >= BGP_GLOBAL.min && hdr.mpls[0].label <= BGP_GLOBAL.max) {
                    /* MPLS Bottom-of-stack and VPN label only (BGP origin) */
                    mpls_ler_egress.apply();
                } else if ((hdr.mpls[0].label >= ISIS_LOCAL.min && hdr.mpls[0].label <= ISIS_LOCAL.max)
                || (hdr.mpls[0].label >= ISIS_GLOBAL.min && hdr.mpls[0].label <= ISIS_GLOBAL.max)) {
                    /* MPLS Bottom-of-stack and transport label only (IS-IS origin) */
                    mpls_lsr_fib.apply();
                }
            }
        } else {
            /**
             * General Non-MPLS Ingress Table for network traffic:
             * 1) From Customer interface, ingressing the MPLS/Kepler network
             * 2) ingressing the Control/Mgmt. Plane (punt to CPU)
             * 3) Any other, punt to CPU by default
             */
            mpcu_ingress.apply();
        }

        if (hdr.ipv4.isValid()) {
            // Verify Checksum
            UserIPv4ChkVerify.apply(hdr.ipv4, checksum_valid);
            if (checksum_valid == 0) {
                drop();
            }

            // Update Time-to-live
            chksum_update_in.hdr_chk = hdr.ipv4.hdr_chk;
            chksum_update_in.old_ttl = hdr.ipv4.ttl;
            chksum_update_in.new_ttl = hdr.ipv4.ttl - 1;
            UserIPv4ChkUpdate.apply(chksum_update_in, hdr.ipv4.hdr_chk);
            hdr.ipv4.ttl = chksum_update_in.new_ttl;
        }

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
