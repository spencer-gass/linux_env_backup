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
}

/* User metadata struct */
struct user_metadata {
    bit<14> byte_length;
    bit<1>    eth_is_valid;
    MacAddr   mac_da;
    MacAddr   mac_sa;
    EtherType ether_type;
    bit<1>    ip_is_valid;
    bit<4>    ip_version;
    bit<4>    ip_hdr_len;
    bit<8>    ip_tos;
    bit<16>   ip_length;
    bit<16>   ip_id;
    bit<3>    ip_flags;
    bit<13>   ip_offset;
    bit<8>    ip_ttl;
    bit<8>    ip_protocol;
    bit<16>   ip_hdr_chk;
    IPv4Addr  ip_sa;
    IPv4Addr  ip_da;
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
            default: accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan);
        transition parse_ipv4;
    }

    state parse_mpls {
        packet.extract(hdr.mpls.next);
        transition select(hdr.mpls.last.bos) {
            0: parse_mpls; // parse_label;
            1: parse_ipv4;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
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

    chksum_update_in_t chksum_update_in;
    bit<1> checksum_valid;

    UserExtern<ipv4_t,bit<1>>(3) UserIPv4ChkVerify;
    UserExtern<chksum_update_in_t,bit<16>>(1) UserIPv4ChkUpdate;

    apply {

        meta.eth_is_valid = hdr.eth.isValid();
        if (hdr.eth.isValid()) {
            mac_da      hdr.eth.dst;
            mac_sa      hdr.eth.src;
            ether_type  hdr.eth.ether_type;
        }

        meta.ip_is_valid = hdr.ipv4.isValid();
        if (hdr.ipv4.isValid()) {

            // Populate metadata
            meta.ip_version   hdr.ipv4.version;
            meta.ip_hdr_len   hdr.ipv4.hdr_len;
            meta.ip_tos       hdr.ipv4.tos;
            meta.ip_length    hdr.ipv4.length;
            meta.ip_id        hdr.ipv4.id;
            meta.ip_flags     hdr.ipv4.flags;
            meta.ip_offset    hdr.ipv4.offset;
            meta.ip_ttl       hdr.ipv4.ttl;
            meta.ip_protocol  hdr.ipv4.protocol;
            meta.ip_hdr_chk   hdr.ipv4.hdr_chk;
            meta.ip_sa        hdr.ipv4.src;
            meta.ip_da        hdr.ipv4.dst;

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
