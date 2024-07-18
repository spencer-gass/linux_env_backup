#include <core.p4>
#include <xsa.p4>

typedef bit<48>  MacAddr;
typedef bit<32>  IPv4Addr;

const bit<16> VLAN_TYPE  = 0x8100;
const bit<16> IPV4_TYPE  = 0x0800;

// ****************************************************************************** //
// *************************** H E A D E R S  *********************************** //
// ****************************************************************************** //

header eth_mac_t {
    MacAddr dmac; // Destination MAC address
    MacAddr smac; // Source MAC address
    bit<16> type; // Tag Protocol Identifier
}

header vlan_t {
    bit<3>  pcp;  // Priority code point
    bit<1>  cfi;  // Drop eligible indicator
    bit<12> vid;  // VLAN identifier
    bit<16> tpid; // Tag protocol identifier
}

header ipv4_t {
    bit<4>   version;  // Version (4 for IPv4)
    bit<4>   hdr_len;  // Header length in 32b words
    bit<8>   tos;      // Type of Service
    bit<16>  length;   // Packet length in 32b words
    bit<16>  id;       // Identification
    bit<3>   flags;    // Flags
    bit<13>  offset;   // Fragment offset
    bit<8>   ttl;      // Time to live
    bit<8>   protocol; // Next protocol
    bit<16>  hdr_chk;  // Header checksum
    IPv4Addr src;      // Source address
    IPv4Addr dst;      // Destination address
}

// ****************************************************************************** //
// ************************* S T R U C T U R E S  ******************************* //
// ****************************************************************************** //

// header structure
struct headers {
    eth_mac_t    eth;
    vlan_t[4]    vlan;
    ipv4_t       ipv4;
}

// User metadata structure
struct metadata {
    bit<9> port;
}

struct chksum_update_in_t {
    bit<16>  hdr_chk;  // Header checksum
    bit<8>   old_ttl;  // Time to live
    bit<8>   new_ttl;  // Updated time to live
}

// ****************************************************************************** //
// *************************** P A R S E R  ************************************* //
// ****************************************************************************** //

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t smeta) {

    state start {
        transition parse_eth;
    }

    state parse_eth {
        packet.extract(hdr.eth);
        transition select(hdr.eth.type) {
            VLAN_TYPE : parse_vlan;
            IPV4_TYPE : parse_ipv4;
            default   : accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan.next);
        transition select(hdr.vlan.last.tpid) {
            VLAN_TYPE : parse_vlan;
            IPV4_TYPE : parse_ipv4;
            default   : accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

}

// ****************************************************************************** //
// **************************  P R O C E S S I N G   **************************** //
// ****************************************************************************** //

control MyProcessing(inout headers hdr,
                     inout metadata meta,
                     inout standard_metadata_t smeta) {

    chksum_update_in_t chksum_update_in;
    bit<16> ipv4_hdr_chk = 0;

    // Checksum<bit<16>>(HashAlgorithm_t.ONES_COMPLEMENT16) IPv4ChkVerify;
    // Checksum<bit<16>>(HashAlgorithm_t.ONES_COMPLEMENT16) IPv4ChkUpdate;

    // UserExtern<ipv4_t,bit<16>>(1) UserIPv4ChkVerify;
    UserExtern<chksum_update_in_t,bit<16>>(1) UserIPv4ChkUpdate;

    action forwardPacket(bit<9> port) {
        meta.port = port;
    }

    apply {
            forwardPacket(1);
            chksum_update_in.hdr_chk = hdr.ipv4.hdr_chk;
            chksum_update_in.old_ttl = hdr.ipv4.ttl;
            chksum_update_in.new_ttl = hdr.ipv4.ttl - 1;
            UserIPv4ChkUpdate.apply(chksum_update_in, hdr.ipv4.hdr_chk);
            hdr.ipv4.ttl = chksum_update_in.new_ttl;
            return;
    }
}

// ****************************************************************************** //
// ***************************  D E P A R S E R  ******************************** //
// ****************************************************************************** //

control MyDeparser(packet_out packet,
                   in headers hdr,
                   inout metadata meta,
                   inout standard_metadata_t smeta) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.vlan);
        packet.emit(hdr.ipv4);
    }
}

// ****************************************************************************** //
// *******************************  M A I N  ************************************ //
// ****************************************************************************** //

XilinxPipeline(
    MyParser(),
    MyProcessing(),
    MyDeparser()
) main;
