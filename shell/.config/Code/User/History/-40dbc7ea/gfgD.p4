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

    action forwardPacket(bit<9> port) {
        meta.port = port;
    }

    action dropPacket() {
        smeta.drop = 1;
    }

    action IPv4ChkVerify() {
        bit<20> chksum = 0;
        bit<16> zero_pad = 0; // I had a hard time finding an simple way to zero extend that the Xilinx compiler would accept. This was the best I could find.
        bit<1> is_not_equal = 0;

        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.version ++ hdr.ipv4.hdr_len ++ hdr.ipv4.tos);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.length);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.id);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.flags ++ hdr.ipv4.offset);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.ttl ++ hdr.ipv4.protocol);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.src[31:16]);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.src[15:0]);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.dst[31:16]);
        chksum = chksum + (zero_pad[3:0] ++ hdr.ipv4.dst[15:0]);

        chksum = zero_pad[2:0] ++ ((zero_pad[0:0] ++ chksum[15:0]) + (zero_pad[12:0] ++ chksum[19:16]));
        chksum = zero_pad[3:0] ++ (chksum[15:0] + (zero_pad[14:0] ++ chksum[16:16]));

        chksum = ~chksum;

        // If-statements aren't supported by pre-production p4 compiler
        // if (chksum[15:0] != hdr.ipv4.hdr_chk) {
        //     dropPacket();
        // }

        // Loops don't exist in p4...
        // Drop if the calculated checksum doesn't match the one in the header
        chksum[15:0] = checksum[15:0] ^ hdr.ipv4.hdr_chk;
        is_not_equal = is_not_equal | chksum[0:0];
        is_not_equal = is_not_equal | chksum[1:1];
        is_not_equal = is_not_equal | chksum[2:2];
        is_not_equal = is_not_equal | chksum[3:3];
        is_not_equal = is_not_equal | chksum[4:4];
        is_not_equal = is_not_equal | chksum[5:5];
        is_not_equal = is_not_equal | chksum[6:6];
        is_not_equal = is_not_equal | chksum[7:7];
        is_not_equal = is_not_equal | chksum[8:8];
        is_not_equal = is_not_equal | chksum[9:9];
        is_not_equal = is_not_equal | chksum[10:10];
        is_not_equal = is_not_equal | chksum[11:11];
        is_not_equal = is_not_equal | chksum[12:12];
        is_not_equal = is_not_equal | chksum[13:13];
        is_not_equal = is_not_equal | chksum[14:14];
        is_not_equal = is_not_equal | chksum[15:15];
        smeta.drop = is_not_equal;
    }

    action IPv4TtlAndChksumUpdate(){
            // Update Time-to-live
            hdr.ipv4.ttl = hdr.ipv4.ttl - 1;

            // Update IPv4 header checksum since ttl changed
            // Don't need to recompute the whole checksum
            // See RFC1624 https://www.rfc-editor.org/rfc/rfc1624 for details
            hdr.ipv4.hdr_chk = hdr.ipv4.hdr_chk + 1;
            if (hdr.ipv4.hdr_chk == 0xFFFF) {
                hdr.ipv4.hdr_chk = 0x0000;
            }
    }

    apply {
            IPv4ChkVerify();

            // if (smeta.drop == 0){
            forwardPacket(1);
            IPv4TtlAndChksumUpdate();
            // }

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
