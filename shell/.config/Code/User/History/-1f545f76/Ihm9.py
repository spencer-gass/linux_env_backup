import yaml

flow_def0 = {
        "header": {
                "mac_da"          : 0,
                "mac_sa"          : 0,
                "ether_type"      : 0,
                "vlan_valid"      : 0,
                "vlan_tag"        : 0,
                "num_mpls_labels" : 0,
                "mpls_label0"     : 0,
                "mpls_label1"     : 0,
                "ip_version"      : 0,
                "ip_ihl"          : 0,
                "ip_dscp"         : 0,
                "ip_ecn"          : 0,
                "ip_length"       : 0,
                "ip_id"           : 0,
                "ip_flags"        : 0,
                "ip_frag_ofs"     : 0,
                "ip_ttl"          : 0,
                "ip_prot"         : 0,
                "ip_hdr_chk"      : 0,
                "ip_sa"           : 0,
                "ip_da"           : 0,
        }
        "pkt_blen_mode"   : 0,
        "pkt_blen_min"    : 0,
        "pkt_blen_max"    : 0,
        "payload_mode"    : 0,
        "payload_value"   : 0
}

with open('./default_flow_defs.yaml', 'w') as file:
    yaml.dump(flow_def0, file)
    yaml.dump(flow_def0, file)