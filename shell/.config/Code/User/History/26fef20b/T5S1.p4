/* -*- P4_16 -*- */
#include <core.p4>
#include <xsa.p4> // TODO(jjardim): uncomment

typedef bit<48>  MacAddr;
typedef bit<16>  EtherType;
typedef bit<12>  VlanId;
typedef bit<20>  MplsLabel;
typedef bit<32>  IPv4Addr;
typedef bit<128> IPv6Addr;

typedef bit<32> VrfId; /* same bitwidth as FRR vrf_id_t struct */

typedef bit<8> PortId;
const PortId CPU_PORT = 0x0;

/* EtherTypes */
const bit<16> TYPE_DOT1Q = 0x8100;
const bit<16> TYPE_MPLS = 0x8847;
const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86DD;

/* Max. number of MPLS labels */
const bit<4> NUM_LABELS = 8;

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
    bit<1> ler_pop;
    bit<10> ingress_port;
    bit<8> egress_port;
    VlanId vlan_id;
    VrfId vrf_id;
}

struct chksum_update_in_t {
    bit<16>  hdr_chk;   // Header checksum
    bit<8>   old_ttl;   // Time to live
    bit<8>   new_ttl;   // Updated time to live
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

    action drop() {
        standard_metadata.drop = 1;
    }

    /*************************************************************************
    **********|  I N T E R F A C E / V L A N   M A P   A C T I O N S  ********
    *************************************************************************/

    /**
     * These actions describe the processing of traffic ingressing and egressing the PS (Processing
     * System), respectively. I.e.:
     * - Initiate user metadata, namely the VRF and VLAN ID's associated with an FPGA interface.
     * - From PS to PL (CPU originated): identify the FPGA interface based on the CPU sub-interface/
     *   VLAN ID it arrived from. Strip VLAN tag and forward to PL.
     * - From PL to PS (punted to CPU): identify the Linux sub-interface based on the FPGA interface
     *   and CPU interface IP address or a well-known MAC address. Tag accordingly with associated
     *   VLAN ID and forward to PS.
     */

    /* Interface to VLAN Mapping (CPU sub-interface VLAN and VRF) */
    action md_set (VrfId vrf_id, VlanId vlan_id) {
        meta.vrf_id = vrf_id;
        meta.vlan_id = vlan_id;
    }

    /*  */
    action strip_dot1q(PortId port) {
        /* Update Ethernet header type */
        hdr.eth.type = hdr.vlan.tpid;

        /* TX interface (FPGA interface ID)  */
        meta.egress_port = port;
    }

    action tag_dot1q (VlanId vlan_id/*, PortId port*/) {
        /* Insert VLAN header */
        hdr.vlan.cfi = 0;
        hdr.vlan.vid = vlan_id;
        hdr.vlan.tpid = hdr.eth.type;

        /* Update Ethernet header type */
        hdr.eth.type = TYPE_DOT1Q;

        /* NOTE(jjardim): assuming only IPv4 for the time being */
            hdr.vlan.pcp = hdr.ipv4.tos[7:5];
            // hdr.vlan.pcp = hdr.ipv6.tc[7:5];

        /* TX interface (CPU interface ID)  */
        meta.egress_port = CPU_PORT/*port*/;
    }

    /*************************************************************************
    **********|  M P L S   T A B L E   A C T I O N S  ************************
    *************************************************************************/

    /**
     * These actions describe the processing of MPLS traffic:
     * - Performed at the LER (Label Edge Router): label pop + tx (egressing the MPLS network) and
     *   label push (ingressing the MPLS network).
     * - Performed at the LSR (Label Switch Router): label pop/push, swap/noop (when segment routed,
     *   label ID's don't change along the path and, thus, there is no need to swap -> noop)
     */

    /* Pop label stack (transport and/or VPN) from packet at the edge of the MPLS network */
    action ler_pop (MplsLabel label_stack, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS pop (label stack (i.e., 1 or more labels) disposition) */
        /* TODO(jjardim): might not be required */
        hdr.mpls[0].label = label_stack; // NOTE(jjardim): out_label = 3 (PHP, implicit null)
        hdr.mpls[0].setInvalid(); // NOTE(jjardim): remove hdr fromm pkt? (https://opennetworking.org/wp-content/uploads/2020/12/p4-cheat-sheet.pdf)
                                  // If setInvalid, remove above line (out_label) to prevent undefined behaviour

        /* NOTE(jjardim): assuming only IPv4 for the time being */
        hdr.eth.type = TYPE_IPV4;
        // hdr.eth.type = TYPE_IPV6;

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port;  // TODO(jjardim): v1model only - remove
        meta.egress_port = port;

        /* Update metadata to perform a IPv4 FIB lookup */
        meta.ler_pop = 1;
    }

    action ler_tx (MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_MPLS;

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port;  // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /* Push label stack (transport and/or VPN) to packet at the edge of the MPLS network */
    action ler_push (MplsLabel out_stack, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_MPLS;

        /* MPLS push (label stack (i.e., 1 or more labels) imposition) */
        /* TODO(jjardim): need to figure out how to push label stack (1 or more labels) */
        hdr.mpls[0].label = out_stack; // NOTE(jjardim): single or label stack?
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = 64;

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port; // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /* Push transport label to packet traversing the MPLS network */
    action lsr_push(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS push (outermost label imposition) */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): single or label stack?
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = 64; /* TODO(jjardim): do we need to decrement the inner label(s) TTL? */

        /* NOTE(jjardim): assuming only IPv4 for the time being */
        hdr.mpls[0].exp = hdr.ipv4.tos[7:5];
        // hdr.mpls[0].exp = hdr.ipv6.tc[7:5];

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port; // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /* Pop transport label from packet traversing the MPLS network */
    action lsr_pop(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS pop (outermost label disposition) */
        /* TODO(jjardim): might not be required */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): out_label = 3 (PHP, implicit null)
        hdr.mpls[0].setInvalid(); // NOTE(jjardim): remove hdr fromm pkt? (https://opennetworking.org/wp-content/uploads/2020/12/p4-cheat-sheet.pdf)
                                  // If setInvalid, remove above line (out_label) to prevent undefined behaviour

        /* TODO(jjardim): do we need to decrement the inner label(s) TTL? */

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port; // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /* Swap transport label of the packet traversing the MPLS network */
    action lsr_swap(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS swap */
        hdr.mpls[0].label = out_label;
        // hdr.mpls[0].exp = hdr.mpls[0].exp - 1; // TODO(jjardim): do the exp bits need updating?
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port; // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /* Same as swap, however, no need to effectively swap as the in- and out-labels as the same */
    action lsr_noop(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS noop */
        hdr.mpls[0].label = out_label; // NOTE(jjardim): Segment Routing, i.e., in_label same as out_label
        // hdr.mpls[0].exp = hdr.mpls[0].exp - 1; // TODO(jjardim): do the exp bits need updating?
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        /* TX interface (FPGA interface ID)  */
        // standard_metadata.egress_spec = port; // TODO(jjardim): v1model only - remove
        meta.egress_port = port;
    }

    /*************************************************************************
    **********|  M A T C H / A C T I O N   T A B L E S  **********************
    *************************************************************************/

    table intf_map {
        key = {
            meta.ingress_port: exact; // FPGA interface ID (incoming)
        }
        actions = {
            md_set;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* Control/Mgmt. Plane (CPU originated - controller PacketOut) */
    table vlan_map {
        key = {
            hdr.vlan.vid: exact;
        }
        actions = {
            strip_dot1q;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* Control/Mgmt. Plane, or CMP (CPU punted - controller PacketIn) */
    // table cmp_mac_fib {
    //     key = {
    //         meta.ingress_port: exact;
    //         hdr.eth.dst: exact;
    //     }
    //     actions = {
    //         tag_dot1q;
    //         drop;
    //         NoAction;
    //     }
    //     size = 1024;
    //     default_action = drop();
    // }

    table cmp_ipv4_fib {
        key = {
            hdr.ipv4.dst: lpm;
            meta.vrf_id: exact;
        }
        actions = {
            tag_dot1q;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* LER Ingress FIB (Forwarding Info Base) */
    table ipv4_fib_ingress {
        key = {
            hdr.ipv4.dst: lpm;
            meta.vrf_id: exact;
        }
        actions = {
            tag_dot1q;
            ler_push;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* LER Egress FIB (Forwarding Info Base) */
    table ipv4_fib_egress {
        key = {
            hdr.ipv4.dst: lpm;
            meta.vrf_id: exact;
        }
        actions = {
            ler_tx;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* MPLS LSR LFIB (Label Forwarding Info Base) */
    table lfib {
        key = {
            hdr.mpls[0].label: exact;
        }
        actions = {
            ler_pop;
            lsr_push;
            lsr_pop;
            lsr_swap;
            lsr_noop;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    chksum_update_in_t chksum_update_in;
    bit<1> checksum_valid;

    UserExtern<ipv4_t,bit<1>>(3) UserIPv4ChkVerify;
    UserExtern<chksum_update_in_t,bit<16>>(1) UserIPv4ChkUpdate;

    apply {
        /* Initialize user-defined metadata */
        meta.ler_pop = 0;
        intf_map.apply();

        if (hdr.eth.type == TYPE_DOT1Q) {
            /* From CPU interface */
            vlan_map.apply();
        } else if (hdr.eth.type == TYPE_MPLS) {
            /* NOTE(jjardim):
             * - label types: { transport: bos=0; VPN: bos=1 }
             * - out_label values: { 0: explicit null; 3: PHP/implicit null }
             */
            lfib.apply();
        } else if (hdr.eth.type == TYPE_IPV4) {
            // if (!cmp_ipv4_fib.apply().hit) {
                ipv4_fib_ingress.apply();
            // }
        } else {
            /* Everything else, punto to CPU */
            cmp_mac_fib.apply();
        }

        if (meta.ler_pop == 1) {
            ipv4_fib_egress.apply();
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

XilinxPipeline (
FRRdplaneParser(),
FRRdplaneIngress(),
FRRdplaneDeparser()
) main;
