#!/usr/bin/env python3
"""
Utility to create packets and write them to a pcap
"""

from scapy.all import Ether, IP, Raw, wrpcap
from scapy.contrib.mpls import MPLS


def create_mpls_ipv4_packet():
    # Create an Ethernet frame
    ether = Ether()

    # Create an MPLS label
    mpls = MPLS(label=123, cos=0, s=1, ttl=255)

    # Create an IPv4 packet
    ip = IP(src="192.168.1.1", dst="192.168.1.2")

    # payload padding
    payload = Raw(load='AA' * 40)

    # Combine Ethernet, MPLS, and IP layers
    packet = ether / mpls / ip / payload

    return packet


def write_packets_to_pcap(filename, num_packets):
    packets = [create_mpls_ipv4_packet() for _ in range(num_packets)]
    wrpcap(filename, packets)
    print(f"Wrote {num_packets} packets to {filename}")


# Example usage
if __name__ == "__main__":
    num_packets = 1  # Number of packets to generate
    pcap_filename = f"mpls_ipv4_{num_packets}_pkts.pcap"
    write_packets_to_pcap(pcap_filename, num_packets)
