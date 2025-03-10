import yaml

class FlowDef():
    """
    Flow Definition class
    """
    MAC_DA_WIDTH = 48
    MAC_SA_WIDTH = 48
    ETHER_TYPE_WIDTH = 16
    VLAN_VALID_WIDTH = 1
    VLAN_TAG_WIDTH = 32
    NUM_MPLS_LABELS_WIDTH = 2
    MPLS_LABEL0_WIDTH = 32
    MPLS_LABEL1_WIDTH = 32
    IP_VERSION_WIDTH = 4
    IP_IHL_WIDTH = 4
    IP_DSCP_WIDTH = 6
    IP_ECN_WIDTH = 2
    IP_LENGTH_WIDTH = 16
    IP_ID_WIDTH = 16
    IP_FLAGS_WIDTH = 3
    IP_FRAG_OFS_WIDTH = 13
    IP_TTL_WIDTH = 7
    IP_PROT_WIDTH = 7
    IP_HDR_CHK_WIDTH = 16
    IP_SA_WIDTH = 32
    IP_DA_WIDTH = 32
    PKT_BLEN_MODE_WIDTH = 2
    PKT_BLEN_MIN_WIDTH = 14
    PKT_BLEN_MAX_WIDTH = 14
    PAYLOAD_MODE_WIDTH = 2
    PAYLOAD_VALUE_WIDTH = 8

    def __init__(self, flow_def_dict=None):

        if flow_def_dict is None:
            self.mac_da = 0
            self.mac_sa = 0
            self.ether_type = 0
            self.vlan_valid = 0
            self.vlan_tag = 0
            self.num_mpls_labels = 0
            self.mpls_label0 = 0
            self.mpls_label1 = 0
            self.ip_version = 0
            self.ip_ihl = 0
            self.ip_dscp = 0
            self.ip_ecn = 0
            self.ip_length = 0
            self.ip_id = 0
            self.ip_flags = 0
            self.ip_frag_ofs = 0
            self.ip_ttl = 0
            self.ip_prot = 0
            self.ip_hdr_chk = 0
            self.ip_sa = 0
            self.ip_da = 0
            self.pkt_blen_mode = 0
            self.pkt_blen_min = 0
            self.pkt_blen_max = 0
            self.payload_mode = 0
            self.payload_value = 0
        else:
            self.mac_da = flow_def_dict["header"]["mac_da"]
            self.mac_sa = flow_def_dict["header"]["mac_sa"]
            self.ether_type = flow_def_dict["header"]["ether_type"]
            self.vlan_valid = flow_def_dict["header"]["vlan_valid"]
            self.vlan_tag = flow_def_dict["header"]["vlan_tag"]
            self.num_mpls_labels = flow_def_dict["header"]["num_mpls_labels"]
            self.mpls_label0 = flow_def_dict["header"]["mpls_label0"]
            self.mpls_label1 = flow_def_dict["header"]["mpls_label1"]
            self.ip_version = flow_def_dict["header"]["ip_version"]
            self.ip_ihl = flow_def_dict["header"]["ip_ihl"]
            self.ip_dscp = flow_def_dict["header"]["ip_dscp"]
            self.ip_ecn = flow_def_dict["header"]["ip_ecn"]
            self.ip_length = flow_def_dict["header"]["ip_length"]
            self.ip_id = flow_def_dict["header"]["ip_id"]
            self.ip_flags = flow_def_dict["header"]["ip_flags"]
            self.ip_frag_ofs = flow_def_dict["header"]["ip_frag_ofs"]
            self.ip_ttl = flow_def_dict["header"]["ip_ttl"]
            self.ip_prot = flow_def_dict["header"]["ip_prot"]
            self.ip_hdr_chk = flow_def_dict["header"]["ip_hdr_chk"]
            self.ip_sa = flow_def_dict["header"]["ip_sa"]
            self.ip_da = flow_def_dict["header"]["ip_da"]
            self.pkt_blen_mode = flow_def_dict["pkt_blen_mode"]
            self.pkt_blen_min = flow_def_dict["pkt_blen_min"]
            self.pkt_blen_max = flow_def_dict["pkt_blen_max"]
            self.payload_mode = flow_def_dict["payload_mode"]
            self.payload_value = flow_def_dict["payload_value"]

    def get_fields(self):
        return [
                self.mac_da,
                self.mac_sa,
                self.ether_type,
                self.vlan_valid,
                self.vlan_tag,
                self.num_mpls_labels,
                self.mpls_label0,
                self.mpls_label1,
                self.ip_version,
                self.ip_ihl,
                self.ip_dscp,
                self.ip_ecn,
                self.ip_length,
                self.ip_id,
                self.ip_flags,
                self.ip_frag_ofs,
                self.ip_ttl,
                self.ip_prot,
                self.ip_hdr_chk,
                self.ip_sa,
                self.ip_da,
                self.pkt_blen_mode,
                self.pkt_blen_min,
                self.pkt_blen_max,
                self.payload_mode,
                self.payload_value
        ]


def get_flow_def_field_widths():
    return [
            FlowDef.MAC_DA_WIDTH,
            FlowDef.MAC_SA_WIDTH,
            FlowDef.ETHER_TYPE_WIDTH,
            FlowDef.VLAN_VALID_WIDTH,
            FlowDef.VLAN_TAG_WIDTH,
            FlowDef.NUM_MPLS_LABELS_WIDTH,
            FlowDef.MPLS_LABEL0_WIDTH,
            FlowDef.MPLS_LABEL1_WIDTH,
            FlowDef.IP_VERSION_WIDTH,
            FlowDef.IP_IHL_WIDTH,
            FlowDef.IP_DSCP_WIDTH,
            FlowDef.IP_ECN_WIDTH,
            FlowDef.IP_LENGTH_WIDTH,
            FlowDef.IP_ID_WIDTH,
            FlowDef.IP_FLAGS_WIDTH,
            FlowDef.IP_FRAG_OFS_WIDTH,
            FlowDef.IP_TTL_WIDTH,
            FlowDef.IP_PROT_WIDTH,
            FlowDef.IP_HDR_CHK_WIDTH,
            FlowDef.IP_SA_WIDTH,
            FlowDef.IP_DA_WIDTH,
            FlowDef.PKT_BLEN_MODE_WIDTH,
            FlowDef.PKT_BLEN_MIN_WIDTH,
            FlowDef.PKT_BLEN_MAX_WIDTH,
            FlowDef.PAYLOAD_MODE_WIDTH,
            FlowDef.PAYLOAD_VALUE_WIDTH
    ]


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

flow_def_objs = []
for k in flow_def.keys():
    flow_def_objs.append(FlowDef(flow_defs[k]))

print(flow_def_objs)
