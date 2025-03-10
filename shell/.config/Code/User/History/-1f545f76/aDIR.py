import yaml

flow_def = {
        "IPv4" : {
                "header": {
                        "mac_da"          : 0x101111111111,
                        "mac_sa"          : 0x202222222222,
                        "ether_type"      : 0x0800,
                        "vlan_valid"      : 0,
                        "vlan_tag"        : 0,
                        "num_mpls_labels" : 0,
                        "mpls_label0"     : 0,
                        "mpls_label1"     : 0,
                        "ip_version"      : 4,
                        "ip_ihl"          : 5,
                        "ip_dscp"         : 0,
                        "ip_ecn"          : 0,
                        "ip_length"       : 64,
                        "ip_id"           : 0,
                        "ip_flags"        : 0,
                        "ip_frag_ofs"     : 0,
                        "ip_ttl"          : 255,
                        "ip_prot"         : 0x11,
                        "ip_hdr_chk"      : 0,
                        "ip_sa"           : 0xC0A80002,
                        "ip_da"           : 0xC0A80001,
                },
                "pkt_blen_mode"   : 0,
                "pkt_blen_min"    : 0,
                "pkt_blen_max"    : 0,
                "payload_mode"    : 0,
                "payload_value"   : 0
        },
        "IPv4_2" : {
                "header": {
                        "mac_da"          : 0x101111111111,
                        "mac_sa"          : 0x202222222222,
                        "ether_type"      : 0x0800,
                        "vlan_valid"      : 0,
                        "vlan_tag"        : 0,
                        "num_mpls_labels" : 0,
                        "mpls_label0"     : 0,
                        "mpls_label1"     : 0,
                        "ip_version"      : 4,
                        "ip_ihl"          : 5,
                        "ip_dscp"         : 0,
                        "ip_ecn"          : 0,
                        "ip_length"       : 64,
                        "ip_id"           : 0,
                        "ip_flags"        : 0,
                        "ip_frag_ofs"     : 0,
                        "ip_ttl"          : 255,
                        "ip_prot"         : 0x11,
                        "ip_hdr_chk"      : 0,
                        "ip_sa"           : 0xC0A80002,
                        "ip_da"           : 0xC0A80001,
                },
                "pkt_blen_mode"   : 0,
                "pkt_blen_min"    : 0,
                "pkt_blen_max"    : 0,
                "payload_mode"    : 0,
                "payload_value"   : 0
        }
}

with open('./default_flow_defs.yaml', 'w') as file:
    yaml.dump(flow_def, file)
    yaml.dump(flow_def, file)

with open('./default_flow_defs.yaml', 'r') as file:
    flow_defs = yaml.safe_load(file)

for k in flow_def.keys():
    print(k)

print(flow_defs)
