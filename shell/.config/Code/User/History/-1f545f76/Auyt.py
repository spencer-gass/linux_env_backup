# import yaml

# flow_def = {
#         "flow_def" : {
#                 "name" : "IPv4",
#                 "header": {
#                         "mac_da"          : 0x101111111111,
#                         "mac_sa"          : 0x202222222222,
#                         "ether_type"      : 0x0800,
#                         "vlan_valid"      : 0,
#                         "vlan_tag"        : 0,
#                         "num_mpls_labels" : 0,
#                         "mpls_label0"     : 0,
#                         "mpls_label1"     : 0,
#                         "ip_version"      : 4,
#                         "ip_ihl"          : 5,
#                         "ip_dscp"         : 0,
#                         "ip_ecn"          : 0,
#                         "ip_length"       : 64,
#                         "ip_id"           : 0,
#                         "ip_flags"        : 0,
#                         "ip_frag_ofs"     : 0,
#                         "ip_ttl"          : 255,
#                         "ip_prot"         : 0x11,
#                         "ip_hdr_chk"      : 0,
#                         "ip_sa"           : 0xC0A80002,
#                         "ip_da"           : 0xC0A80001,
#                 },
#                 "pkt_blen_mode"   : 0,
#                 "pkt_blen_min"    : 0,
#                 "pkt_blen_max"    : 0,
#                 "payload_mode"    : 0,
#                 "payload_value"   : 0
#         }
# }

# # with open('./default_flow_defs.yaml', 'w') as file:
# #     yaml.dump(flow_def, file)
# #     yaml.dump(flow_def, file)

# with open('./default_flow_defs.yaml', 'r') as file:
#     flow_def = yaml.safe_load(file)

# print(flow_def)

flow_def = '''
flow_def:
  header:
    ether_type: 0x101111111111
    ip_da: 0x202222222222
    ip_dscp: 0x0800
    ip_ecn: 0
    ip_flags: 0
    ip_frag_ofs: 0
    ip_hdr_chk: 0
    ip_id: 0
    ip_ihl: 4
    ip_length: 5
    ip_prot: 0
    ip_sa: 0
    ip_ttl: 64
    ip_version: 0
    mac_da: 0
    mac_sa: 0
    mpls_label0: 255
    mpls_label1: 0x11
    num_mpls_labels: 0
    vlan_tag: 0xC0A80002
    vlan_valid: 0xC0A80001
  name: IPv4
  payload_mode: 0
  payload_value: 0xAA
  pkt_blen_max: 100
  pkt_blen_min: 100
  pkt_blen_mode: 0
'''
with open(fname, 'w') as file:
    fname.write(flow_def)