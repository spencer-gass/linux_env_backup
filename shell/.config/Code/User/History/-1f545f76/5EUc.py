from enum import IntEnum

from math import floor

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

    def __init__(self):
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

    def get_fields(self):
        return [self.mac_da, \
                self.mac_sa, \
                self.ether_type, \
                self.vlan_valid, \
                self.vlan_tag, \
                self.num_mpls_labels, \
                self.mpls_label0, \
                self.mpls_label1, \
                self.ip_version, \
                self.ip_ihl, \
                self.ip_dscp, \
                self.ip_ecn, \
                self.ip_length, \
                self.ip_id, \
                self.ip_flags, \
                self.ip_frag_ofs, \
                self.ip_ttl, \
                self.ip_prot, \
                self.ip_hdr_chk, \
                self.ip_sa, \
                self.ip_da, \
                self.pkt_blen_mode, \
                self.pkt_blen_min, \
                self.pkt_blen_max, \
                self.payload_mode, \
                self.payload_value]

    def get_field_widths(self):
        return [FlowDef.MAC_DA_WIDTH, \
                FlowDef.MAC_SA_WIDTH, \
                FlowDef.ETHER_TYPE_WIDTH, \
                FlowDef.VLAN_VALID_WIDTH, \
                FlowDef.VLAN_TAG_WIDTH, \
                FlowDef.NUM_MPLS_LABELS_WIDTH, \
                FlowDef.MPLS_LABEL0_WIDTH, \
                FlowDef.MPLS_LABEL1_WIDTH, \
                FlowDef.IP_VERSION_WIDTH, \
                FlowDef.IP_IHL_WIDTH, \
                FlowDef.IP_DSCP_WIDTH, \
                FlowDef.IP_ECN_WIDTH, \
                FlowDef.IP_LENGTH_WIDTH, \
                FlowDef.IP_ID_WIDTH, \
                FlowDef.IP_FLAGS_WIDTH, \
                FlowDef.IP_FRAG_OFS_WIDTH, \
                FlowDef.IP_TTL_WIDTH, \
                FlowDef.IP_PROT_WIDTH, \
                FlowDef.IP_HDR_CHK_WIDTH, \
                FlowDef.IP_SA_WIDTH, \
                FlowDef.IP_DA_WIDTH, \
                FlowDef.PKT_BLEN_MODE_WIDTH, \
                FlowDef.PKT_BLEN_MIN_WIDTH, \
                FlowDef.PKT_BLEN_MAX_WIDTH, \
                FlowDef.PAYLOAD_MODE_WIDTH, \
                FlowDef.PAYLOAD_VALUE_WIDTH]

def _set_flow_def_wr_data(flow_def):
    reg_list = []
    wdata = 0
    remaining_bits_in_reg = 32
    for field, width in zip(flow_def.get_fields(), flow_def.get_field_widths()):
        remaining_bits_in_field = width
        remaining_field = field
        while (remaining_bits_in_field > 0):
            #print("remaining_field {:X}, remaining bits {}, bit ptr {}".format(remaining_field, remaining_bits_in_field, remaining_bits_in_reg))
            if (remaining_bits_in_field < remaining_bits_in_reg):
                wdata |= remaining_field << (remaining_bits_in_reg - remaining_bits_in_field)
                remaining_bits_in_reg -= remaining_bits_in_field
                remaining_bits_in_field = 0
            else:
                wdata |= remaining_field >> (remaining_bits_in_field - remaining_bits_in_reg)
                remaining_field &= (1 << (remaining_bits_in_field - remaining_bits_in_reg)) - 1
                remaining_bits_in_field -= remaining_bits_in_reg
                remaining_bits_in_reg = 32

                #print(" wreg {:X}".format(wdata))
                reg_list.append(wdata)
                wdata = 0
            #print(" wdata {:X}".format(wdata))

    if remaining_bits_in_reg != 0:
        reg_list.append(wdata)

    print("{:X}".format(reg_list[0]))
    print("{:X}".format(reg_list[1]))
    print("{:X}".format(reg_list[2]))
    print("{:X}".format(reg_list[3]))
    print("{:X}".format(reg_list[4]))
    print("{:X}".format(reg_list[5]))
    print("{:X}".format(reg_list[6]))
    print("{:X}".format(reg_list[7]))
    print("{:X}".format(reg_list[8]))
    print("{:X}".format(reg_list[9]))
    print("{:X}".format(reg_list[10]))
    print("{:X}".format(reg_list[11]))
    print("{:X}".format(reg_list[12]))
    print()
    return reg_list

def _get_flow_def_rd_data(regs):
    f = FlowDef()
    fields = [0] * len(f.get_fields())
    remaining_bits_in_reg = 32
    current_reg = 0
    for i, width in enumerate(f.get_field_widths()):
        remaining_bits_in_field = width
        while (remaining_bits_in_field > 0):
            print("remaining_reg {:X}, remaining bits {}, bit ptr {}".format(regs[current_reg], remaining_bits_in_field, remaining_bits_in_reg))
            if (remaining_bits_in_field < remaining_bits_in_reg):
                fields[i] |= (1 << remaining_bits_in_field) - 1 & (regs[current_reg] >> (remaining_bits_in_reg - remaining_bits_in_field))
                remaining_bits_in_reg -= remaining_bits_in_field
                remaining_bits_in_field = 0
            else:
                fields[i] |= regs[current_reg] << (remaining_bits_in_field - remaining_bits_in_reg)
                remaining_bits_in_field -= remaining_bits_in_reg
                remaining_bits_in_reg = 32
                current_reg += 1
                print(" field {:X}".format(fields[i]))

    f.mac_da = fields[0]
    f.mac_sa = fields[1]
    f.ether_type = fields[2]
    f.vlan_valid = fields[3]
    f.vlan_tag = fields[4]
    f.num_mpls_labels = fields[5]
    f.mpls_label0 = fields[6]
    f.mpls_label1 = fields[7]
    f.ip_version = fields[8]
    f.ip_ihl = fields[9]
    f.ip_dscp = fields[10]
    f.ip_ecn = fields[11]
    f.ip_length = fields[12]
    f.ip_id = fields[13]
    f.ip_flags = fields[14]
    f.ip_frag_ofs = fields[15]
    f.ip_ttl = fields[16]
    f.ip_prot = fields[17]
    f.ip_hdr_chk = fields[18]
    f.ip_sa = fields[19]
    f.ip_da = fields[20]
    f.pkt_blen_mode = fields[21]
    f.pkt_blen_min = fields[22]
    f.pkt_blen_ma0x = fields[23]
    f.payload_mode = fields[24]
    f.payload_value = fields[25]

    for field in fields:
        print("{:X}".format(field))


f = FlowDef()
f.mac_da = 0xAAAAAAAAAAAA
f.mac_sa = 0xBBBBBBBBBBBB
f.ether_type = 0xCCCC
f.vlan_valid = 1
f.vlan_tag = 0x8100AAAA
f.num_mpls_labels = 2
f.mpls_label0 = 0xBBBBBBBB
f.mpls_label1 = 0xCCCCCCCC
f.ip_version = 4
f.ip_ihl = 20
f.ip_dscp = 1
f.ip_ecn = 1
f.ip_length = 1
f.ip_id = 1
f.ip_flags = 1
f.ip_frag_ofs = 1
f.ip_ttl = 1
f.ip_prot = 1
f.ip_hdr_chk = 1
f.ip_sa = 0xDDDDDDDD
f.ip_da = 0xEEEEEEEE
f.pkt_blen_mode = 1
f.pkt_blen_min = 64
f.pkt_blen_ma0x = 1500
f.payload_mode = 1
f.payload_value = 0xFF

regs = _set_flow_def_wr_data(f)
_get_flow_def_rd_data(regs)