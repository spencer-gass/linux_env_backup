/*
P4_16
Parser for network packet geneator, analyzer and caputre.
*/

#include <core.p4>
#include <xsa.p4>

typedef bit<48>  MacAddr;
typedef bit<16>  EtherType;
typedef bit<12>  VlanId;
typedef bit<20>  MplsLabel;
typedef bit<32>  IPv4Addr;

/* EtherTypes */
const bit<16> TYPE_DOT1Q = 0x8100;
const bit<16> TYPE_MPLS = 0x8847;
const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86DD;

/* Max. number of MPLS labels */
const bit<4> NUM_LABELS = 2;

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

header ipv4_t {
    bit<4>    version;  // Version (4 for IPv4)
    bit<4>    hdr_len;  // Header length in 32b words
    bit<8>    tos;      // Type of service
    bit<16>   len;      // Total packet length (header + data) in octets
    bit<16>   id;       // Identification
    bit<3>    flags;    // Flags
    bit<13>   offset;   // Fragment offset
    bit<8>    ttl;      // Time to live
    bit<8>    protocol; // Next protocol
    bit<16>   hdr_chk;  // Header checksum
    IPv4Addr  src;      // Source address
    IPv4Addr  dst;      // Destination address
}

/*************************************************************************
**********|  S T R U C T U R E S  ****************************************
*************************************************************************/

/* Headers struct */
struct headers {
    eth_mac_t eth;
    vlan_t    vlan;
    mpls_t    mpls0;
    mpls_t    mpls1;
    ipv4_t    ipv4;
}

/* User metadata struct */
struct user_metadata {
    MacAddr   mac_da;
    MacAddr   mac_sa;
    EtherType ether_type;
    bit<1>    vlan_tag_valid;
    bit<32>   vlan;
    bit<2>    mpls_labels_valid;
    bit<32>   mpls0;
    bit<32>   mpls1;
    bit<1>    ipv4_valid;
    bit<4>    ipv4_version;
    bit<4>    ipv4_hdr_len;
    bit<8>    ipv4_tos;
    bit<16>   ipv4_len;
    bit<16>   ipv4_id;
    bit<3>    ipv4_flags;
    bit<13>   ipv4_offset;
    bit<8>    ipv4_ttl;
    bit<8>    ipv4_protocol;
    bit<16>   ipv4_hdr_chk;
    IPv4Addr  ipv4_src;
    IPv4Addr  ipv4_dst;

}

/*************************************************************************
**********|  P A R S E R  ************************************************
*************************************************************************/

parser PacketParser(packet_in packet,
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
            TYPE_MPLS: parse_mpls0;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan);
        // hdr.tpid is really ether_type.
        // tpid was parsed into hdr.ether_type.
        transition select(hdr.vlan.tpid) {
            TYPE_IPV4: parse_ipv4;
            TYPE_MPLS: parse_mpls0;
            default: accept;
        }
    }

    state parse_mpls0 {
        packet.extract(hdr.mpls0);
        transition select(hdr.mpls0.bos) {
            0: parse_mpls1; // parse_label;
            1: parse_mpls_payload;
        }
    }

    state parse_mpls1 {
        packet.extract(hdr.mpls1);
        transition parse_mpls_payload;
    }

    state parse_mpls_payload {
        transition parse_ipv4;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

/*************************************************************************
**********|  I N G R E S S   P R O C E S S I N G  ************************
*************************************************************************/

control MetadataMap(inout headers hdr,
                inout user_metadata meta,
                inout standard_metadata_t standard_metadata) {

    action drop() {
        standard_metadata.drop = 1;
    }

    apply {
        meta.mac_da = hdr.eth.dst;
        meta.mac_sa = hdr.eth.src;

        if (hdr.vlan.isValid()) {
            meta.vlan_tag_valid = 1;
            meta.vlan = hdr.eth.type ++ hdr.vlan.pcp ++ hdr.vlan.cfi ++ hdr.vlan.vid;
            meta.ether_type = hdr.vlan.tpid;
        } else {
            meta.vlan_tag_valid = 0;
            meta.ether_type = hdr.eth.type;
        }

        if (hdr.mpls0.isValid()) {
            meta.mpls_labels_valid = 1;
            meta.mpls0 = hdr.mpls0.label ++ hdr.mpls0.exp ++ hdr.mpls0.bos ++ hdr.mpls0.ttl;
        }

        if (hdr.mpls0.isValid() && hdr.mpls1.isValid()) {
            meta.mpls_labels_valid = 1;
            meta.mpls1 = hdr.mpls1.label ++ hdr.mpls1.exp ++ hdr.mpls1.bos ++ hdr.mpls1.ttl;
        }

        if (hdr.ipv4.isValid()) {
            meta.ipv4_valid     = 1;
            meta.ipv4_version   = hdr.ipv4.version;
            meta.ipv4_hdr_len   = hdr.ipv4.hdr_len;
            meta.ipv4_tos       = hdr.ipv4.tos;
            meta.ipv4_len       = hdr.ipv4.len;
            meta.ipv4_id        = hdr.ipv4.id;
            meta.ipv4_flags     = hdr.ipv4.flags;
            meta.ipv4_offset    = hdr.ipv4.offset;
            meta.ipv4_ttl       = hdr.ipv4.ttl;
            meta.ipv4_protocol  = hdr.ipv4.protocol;
            meta.ipv4_hdr_chk   = hdr.ipv4.hdr_chk;
            meta.ipv4_src       = hdr.ipv4.src;
            meta.ipv4_dst       = hdr.ipv4.dst;
        }

    }
}

/*************************************************************************
**********|  D E P A R S E R  ********************************************
*************************************************************************/

control PacketDeparser(packet_out packet,
                 in headers hdr,
                 inout user_metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.vlan);
        packet.emit(hdr.mpls0);
        packet.emit(hdr.mpls1);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
**********|  S W I T C H  ************************************************
*************************************************************************/

XilinxPipeline(
PacketParser(),
MetadataMap(),
PacketDeparser()
) main;
