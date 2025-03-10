/* -*- P4_16 -*- */
#include <core.p4>

/* Enable if testing with a BMv2 target
 * Uses Standard Metadata vs. User-defined Metadata.
 * Disable if testing in production (e.g., Xilinx Vitis Networking P4).
 */
#define USE_BM 0

#if USE_BM
#include <v1model.p4>
#else
#include <xsa.p4>
#endif

typedef bit<48>  MacAddr;
typedef bit<16>  EtherType;
typedef bit<12>  VlanId;
typedef bit<20>  MplsLabel;
typedef bit<32>  IPv4Addr;
typedef bit<128> IPv6Addr;

typedef bit<32> VrfId;

#if USE_BM
typedef bit<9> PortId;
#else
typedef bit<10> PortId;
#endif
const PortId CPU_PORT = 0x000;
const VlanId DUMMY_VID = 0x03e7; /* (dummy ID: 999) */

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
    vlan_t    vlan;         // Single VLAN header/tag (IEEE 802.1Q)
    mpls_t[NUM_LABELS] mpls;// Max. 8 MPLS headers
    ip_raw_t  raw_byte;     // Only used to extract the IP header version
    ipv4_t    ipv4;         // NOTE(jjardim): take a look at 'header_union'
    ipv6_t    ipv6;         // NOTE(jjardim): take a look at 'header_union'
}

/* User metadata struct */
struct user_metadata {
    bit<10> ingress_port;    // Ingress port
    bit<10> egress_port;     // Egress port
    bit<1> bos;             // MPLS Bottom-of-Stack bit
    bit<14> byte_length;    // Byte length counter
    VlanId vlan_id;         // VLAN ID which maps to the ingress port
    VrfId vrf_id;           // VRF/Route Table ID to which the ingress port is assigned
}

struct chksum_update_in_t {
    bit<16>  hdr_chk;       // Header checksum
    bit<8>   old_ttl;       // Time-to-live
    bit<8>   new_ttl;       // Updated time-to-live
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
#if USE_BM
/*************************************************************************
**********|  C H E C K S U M   V E R I F I C A T I O N  ******************
*************************************************************************/

control FRRdplaneVerifyChecksum(inout headers hdr,
                                inout user_metadata meta) {
    apply {  }
}
#endif
/*************************************************************************
**********|  I N G R E S S   P R O C E S S I N G  ************************
*************************************************************************/

control FRRdplaneIngress(inout headers hdr,
                         inout user_metadata meta,
                         inout standard_metadata_t standard_metadata) {

    action drop() {
#if USE_BM
        mark_to_drop(standard_metadata);
#else
        standard_metadata.drop = 1;
#endif
    }

    /*************************************************************************
    **********|  I N T E R F A C E / V L A N   M A P   A C T I O N S  ********
    *************************************************************************/
    /* These actions are associated with CMP (Control and Management Plane) traffic processing. */

    /**
     * Sets/populates User-defined Metadata.
     * (PL (Programmable Logic)/FPGA interface ID to PS (Processing System) sub-interface VLAN ID
     * (and VRF/route table ID) mapping)
     */
    action md_set (VrfId vrf_id, VlanId vlan_id) {
        meta.vrf_id = vrf_id;
        meta.vlan_id = vlan_id;
    }

    /**
     * Packet-out action, i.e., when a packet is CPU-originated:
     * Strips the IEEE 802.1Q/VLAN tag from packet and forwards to associated PL/FPGA interface.
     */
    action strip_dot1q(PortId port) {
        /* Update Ethernet header type */
        hdr.eth.type = hdr.vlan.tpid;

        /* Mark dot1q header as invalid */
        hdr.vlan.setInvalid();

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Packet-in action, i.e., when a packet is punted CPU:
     * Adds a IEEE 802.1Q/VLAN tag to the packet and forwards to associated PS sub-interface.
     */
    action tag_dot1q (VlanId vlan_id) {
        /* Mark dot1q header as valid */
        hdr.vlan.setValid();

        /* Insert VLAN header */
        hdr.vlan.cfi = 0;
        hdr.vlan.vid = meta.vlan_id; /* NOTE(jjardim): using meta.vlan_id instead of the action param */
        hdr.vlan.tpid = hdr.eth.type;

        /* Update Ethernet header type */
        hdr.eth.type = TYPE_DOT1Q;

        /* NOTE(jjardim): assuming only IPv4 for the time being */
        hdr.vlan.pcp = hdr.ipv4.tos[7:5];
        // hdr.vlan.pcp = hdr.ipv6.tc[7:5];

        /* TX interface (CPU interface ID) */
#if USE_BM
        standard_metadata.egress_spec = CPU_PORT;
#else
        meta.egress_port = CPU_PORT;
#endif
    }

    /*************************************************************************
    **********|  I P v 4 / M P L S   T A B L E   A C T I O N S  **************
    *************************************************************************/
    /* These actions are associated with DP (Data Plane - IPv4 and MPLS) traffic processing. */

    /**
     * Forwards IPv4 packet locally/to directly connected interface.
     */
    action local_tx (MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_IPV4;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Pushes a single-label stack (VPN) to a packet at the edge of the MPLS network.
     */
    action ler_single_push (MplsLabel vpn_label, MplsLabel transport_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_MPLS;

        /* MPLS label push (innermost/VPN label imposition) */
        hdr.mpls[0].setValid();
        hdr.mpls[0].label = vpn_label;
        hdr.mpls[0].bos = 1;
        hdr.mpls[0].ttl = 64;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Pushes a label stack (transport and VPN) to a packet at the edge of the MPLS network.
     */
    action ler_push (MplsLabel vpn_label, MplsLabel transport_label, MacAddr src_addr, MacAddr dst_addr, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;
        hdr.eth.type = TYPE_MPLS;

        /* MPLS label push (outermost/transport label imposition) */
        hdr.mpls[0].setValid();
        hdr.mpls[0].label = transport_label;
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = 64;

        /* MPLS label push (innermost/VPN label imposition) */
        hdr.mpls[1].setValid();
        hdr.mpls[1].label = vpn_label;
        hdr.mpls[1].bos = 1;
        hdr.mpls[1].ttl = 64;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Pops an MPLS (topmost) label from a packet at or near (PHP) the edge of the MPLS network.
     */
    action mpls_pop(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, VrfId vrf_id, PortId port) {
        /* Store bottom-of-stack (BoS) bit for later */
        meta.bos = hdr.mpls[0].bos;

        /* MPLS label pop (outermost label disposition) */
        hdr.mpls[0].setInvalid();

        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* TX interface VRF ID */
        meta.vrf_id = vrf_id;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Swaps the topmost (transport) label of a packet traversing the core of the MPLS network.
     */
    action lsr_swap(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, VrfId vrf_id, PortId  port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS label swap (outermost/transport label) */
        hdr.mpls[0].label = out_label;
        hdr.mpls[0].bos = 0;
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        /* TX interface VRF ID */
        meta.vrf_id = vrf_id;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /**
     * Same as swap, however, no need to effectively swap as the in- and out-label ID are the same.
     * (segment routing case, where the label ID does not change along the path)
     */
    action lsr_noop(MplsLabel out_label, MacAddr src_addr, MacAddr dst_addr, VrfId vrf_id, PortId port) {
        /* Ethernet */
        hdr.eth.src = src_addr;
        hdr.eth.dst = dst_addr;

        /* MPLS noop */
        hdr.mpls[0].ttl = hdr.mpls[0].ttl - 1;

        /* TX interface VRF ID */
        // meta.vrf_id = vrf_id;

        /* TX interface (FPGA interface ID)  */
#if USE_BM
        standard_metadata.egress_spec = port;
#else
        meta.egress_port = port;
#endif
    }

    /*************************************************************************
    **********|  M A T C H / A C T I O N   T A B L E S  **********************
    *************************************************************************/

    /* Metadata (PL/FPGA Interface ID tp PS Sub-Interface/VLAN/ID Mapping) Table */
    table intf_map {
        key = {
#if USE_BM
            standard_metadata.ingress_port: exact;
#else
            meta.ingress_port: exact; // FPGA interface ID (incoming)
#endif
        }
        actions = {
            md_set;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    /* Control/Mgmt. Plane - CMP (CPU originated - controller PacketOut) */
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

    /* Control/Mgmt. Plane - CMP L2/MAC (CPU punted - controller PacketIn) */
    table cmp_mac_fib {
        key = {
#if USE_BM
            standard_metadata.ingress_port: exact;
#else
            meta.ingress_port: exact;
#endif
            hdr.eth.dst: exact;
        }
        actions = {
            tag_dot1q;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* Control/Mgmt. Plane - CMP L3/IPv4 (CPU punted - controller PacketIn) */
    table cmp_ipv4_fib {
        key = {
#if USE_BM
            standard_metadata.ingress_port: exact;
#else
            meta.ingress_port: exact;
#endif
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
            local_tx;
            ler_single_push;
            ler_push;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* MPLS LER/LSR LFIB (Label Forwarding Info Base) */
    table lfib {
        key = {
            hdr.mpls[0].label: exact;
        }
        actions = {
            mpls_pop;
            lsr_swap;
            lsr_noop;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

#if USE_BM == 0
    chksum_update_in_t chksum_update_in;
    bit<1> checksum_valid;
    bit<16> updated_checksum;

    UserExtern<ipv4_t,bit<1>>(3) UserIPv4ChkVerify;
    UserExtern<chksum_update_in_t,bit<16>>(1) UserIPv4ChkUpdate;
#endif

    apply {
        /* Initialize user-defined metadata */
        intf_map.apply();

        /* If ingressing packet belongs to dummy VLAN/VRF, drop */
        if (meta.vlan_id == DUMMY_VID)
            drop();

#if USE_BM
        if (standard_metadata.ingress_port != CPU_PORT) { // non-CPU originated
#else
        if (meta.ingress_port != CPU_PORT) { // non-CPU originated
#endif
            // Packet from non-CPU port, apply VLAN tagging
            if (hdr.eth.type == TYPE_MPLS) {
                lfib.apply();

                if (meta.bos == 1) {
                    ipv4_fib_ingress.apply();
                }
            } else if (hdr.eth.type == TYPE_IPV4) {
                if (!cmp_ipv4_fib.apply().hit) {
                    ipv4_fib_ingress.apply();
                }
            } else { /* Everything else, punt to CPU */
                cmp_mac_fib.apply();
            }
#if USE_BM
        } else if (standard_metadata.ingress_port == CPU_PORT) { // CPU originated
#else
        } else if (meta.ingress_port == CPU_PORT) { // CPU originated
#endif
            // Packet from CPU port with VLAN tag, strip it
            vlan_map.apply();
        }

#if USE_BM == 0
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
            UserIPv4ChkUpdate.apply(chksum_update_in, updated_checksum);
            hdr.ipv4.hdr_chk = updated_checksum;
            hdr.ipv4.ttl = chksum_update_in.new_ttl;
        }
#endif
    }
}
#if USE_BM
/*************************************************************************
**********|  E G R E S S   P R O C E S S I N G  **************************
*************************************************************************/

control FRRdplaneEgress(inout headers hdr,
                        inout user_metadata meta,
                        inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
**********|  C H E C K S U M   C O M P U T A T I O N  ********************
*************************************************************************/

control FRRdplaneComputeChecksum(inout headers  hdr,
                                 inout user_metadata meta) {
     apply {  }
}
#endif
/*************************************************************************
**********|  D E P A R S E R  ********************************************
*************************************************************************/

#if USE_BM
control FRRdplaneDeparser(packet_out packet,
                          in headers hdr)
#else
control FRRdplaneDeparser(packet_out packet,
                          in headers hdr,
                          inout user_metadata meta,
                          inout standard_metadata_t standard_metadata)
#endif
{
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

#if USE_BM
V1Switch(
FRRdplaneParser(),
FRRdplaneVerifyChecksum(),
FRRdplaneIngress(),
FRRdplaneEgress(),
FRRdplaneComputeChecksum(),
FRRdplaneDeparser()
) main;
#else
XilinxPipeline(
FRRdplaneParser(),
FRRdplaneIngress(),
FRRdplaneDeparser()
) main;
#endif
