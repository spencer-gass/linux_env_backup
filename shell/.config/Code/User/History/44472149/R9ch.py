"""
Python interface to network_packet_generator.sv
"""

import logging

from enum import IntEnum

from math import floor

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit, MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)


class NetworkPacketGeneratorAvmmAddrs(IntEnum):
    """
    AVMM register addresses for network_packet_generator.sv
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4
    REG_WIDTH_BITS = REG_WIDTH_BYTES * 8

    # AVMM common register 0-15
    # network packet generator regs 16+
    ADDR_PARAMS = REG_WIDTH_BYTES * 16
    ADDR_CNTR_STAT = REG_WIDTH_BYTES * 17
    ADDR_GEN_TX_PKT_CNT0 = REG_WIDTH_BYTES * 18
    ADDR_GEN_TX_PKT_CNT1 = REG_WIDTH_BYTES * 19
    ADDR_GEN_TX_BYTE_CNT0 = REG_WIDTH_BYTES * 20
    ADDR_GEN_TX_BYTE_CNT1 = REG_WIDTH_BYTES * 21
    ADDR_FLOW_TX_PKT_CNT0 = REG_WIDTH_BYTES * 22
    ADDR_FLOW_TX_PKT_CNT1 = REG_WIDTH_BYTES * 23
    ADDR_FLOW_TX_BYTE_CNT0 = REG_WIDTH_BYTES * 24
    ADDR_FLOW_TX_BYTE_CNT1 = REG_WIDTH_BYTES * 25
    ADDR_TX_CON = REG_WIDTH_BYTES * 26
    ADDR_SHAPER_CON = REG_WIDTH_BYTES * 27
    ADDR_TX_CNTR_CON = REG_WIDTH_BYTES * 28
    ADDR_FLOW_DEF_CON = REG_WIDTH_BYTES * 29
    ADDR_FLOW_DEF_WDATA = REG_WIDTH_BYTES * 30


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


class NetworkPacketGeneratorAvmm(AvmmCommonCtrl):
    """
    An interface to network_packet_generator.sv
    """

    clock_period_ps = MMIRODesc(
            name="clock_period_ps",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_PARAMS,
            msb=31,
            lsb=0
    )

    tx_counter_sample_busy = MMIRODescBit(
            name="tx_counter_sample_busy",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_CNTR_STAT,
            bit=0
    )

    generator_tx_packet_count0 = MMIRODesc(
            name="generator_tx_packet_count0",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_GEN_TX_PKT_CNT0,
            msb=31,
            lsb=0
    )

    generator_tx_packet_count1 = MMIRODesc(
            name="generator_tx_packet_count1",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_GEN_TX_PKT_CNT1,
            msb=31,
            lsb=0
    )

    generator_tx_byte_count0 = MMIRODesc(
            name="generator_tx_byte_count0",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_GEN_TX_BYTE_CNT0,
            msb=31,
            lsb=0
    )

    generator_tx_byte_count1 = MMIRODesc(
            name="generator_tx_byte_count1",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_GEN_TX_BYTE_CNT1,
            msb=31,
            lsb=0
    )

    flow_tx_packet_count0 = MMIRODesc(
            name="flow_tx_packet_count0",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_TX_PKT_CNT0,
            msb=31,
            lsb=0
    )

    flow_tx_packet_count1 = MMIRODesc(
            name="flow_tx_packet_count1",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_TX_PKT_CNT1,
            msb=31,
            lsb=0
    )

    flow_tx_byte_count0 = MMIRODesc(
            name="flow_tx_byte_count0",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_TX_BYTE_CNT0,
            msb=31,
            lsb=0
    )

    flow_tx_byte_count1 = MMIRODesc(
            name="flow_tx_byte_count1",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_TX_BYTE_CNT1,
            msb=31,
            lsb=0
    )

    tx_finite_packet_count = MMIDesc(
            name="tx_finite_packet_count",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CON,
            msb=31,
            lsb=4
    )

    transmit = MMIDescBit(name="transmit", addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CON, bit=0)

    finite_tx = MMIDescBit(
            name="finite_tx",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CON,
            bit=1
    )

    shaper_whole = MMIDesc(
            name="shaper_whole",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_SHAPER_CON,
            msb=19,
            lsb=16
    )

    shaper_frac = MMIDesc(
            name="shaper_whole",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_SHAPER_CON,
            msb=15,
            lsb=0
    )

    tx_counter_flow_sel = MMIDesc(
            name="tx_counter_flow_sel",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CNTR_CON,
            msb=15,
            lsb=4
    )

    sample_selected_flow_counters = MMIDescBit(
            name="sample_selected_flow_counters",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CNTR_CON,
            bit=2
    )

    sample_all_flow_counters = MMIDescBit(
            name="sample_all_flow_counters",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CNTR_CON,
            bit=1
    )

    sample_generator_counters = MMIDescBit(
            name="sample_generator_counters",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_TX_CNTR_CON,
            bit=0
    )

    last_flow_id = MMIDesc(
            name="last_flow_id",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_CON,
            msb=27,
            lsb=16
    )

    flow_def_flow_sel = MMIDesc(
            name="flow_def_flow_sel",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_CON,
            msb=15,
            lsb=4
    )

    flow_def_wr_enable = MMIDescBit(
            name="flow_def_wr_enable",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_CON,
            bit=0
    )

    flow_def_wr_data0 = MMIDesc(
            name="flow_def_wr_data0",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA,
            msb=31,
            lsb=0
    )

    flow_def_wr_data1 = MMIDesc(
            name="flow_def_wr_data1",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 1,
            msb=31,
            lsb=0
    )

    flow_def_wr_data2 = MMIDesc(
            name="flow_def_wr_data2",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 2,
            msb=31,
            lsb=0
    )

    flow_def_wr_data3 = MMIDesc(
            name="flow_def_wr_data3",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 3,
            msb=31,
            lsb=0
    )

    flow_def_wr_data4 = MMIDesc(
            name="flow_def_wr_data4",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 4,
            msb=31,
            lsb=0
    )

    flow_def_wr_data5 = MMIDesc(
            name="flow_def_wr_data5",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 5,
            msb=31,
            lsb=0
    )

    flow_def_wr_data6 = MMIDesc(
            name="flow_def_wr_data6",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 6,
            msb=31,
            lsb=0
    )

    flow_def_wr_data7 = MMIDesc(
            name="flow_def_wr_data7",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 7,
            msb=31,
            lsb=0
    )

    flow_def_wr_data8 = MMIDesc(
            name="flow_def_wr_data8",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 8,
            msb=31,
            lsb=0
    )

    flow_def_wr_data9 = MMIDesc(
            name="flow_def_wr_data9",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 9,
            msb=31,
            lsb=0
    )

    flow_def_wr_data10 = MMIDesc(
            name="flow_def_wr_data10",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 10,
            msb=31,
            lsb=0
    )

    flow_def_wr_data11 = MMIDesc(
            name="flow_def_wr_data11",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 11,
            msb=31,
            lsb=0
    )

    flow_def_wr_data12 = MMIDesc(
            name="flow_def_wr_data12",
            addr=NetworkPacketGeneratorAvmmAddrs.ADDR_FLOW_DEF_WDATA + 12,
            msb=31,
            lsb=0
    )

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the aurora_frontend module.
        """
        super().__init__(sdr_host, offset)
        self.flow_def_ram_empty = 1

    # Counter Methods

    def get_generator_tx_packet_count(self):
        return (self.generator_tx_packet_count1 << 32) + self.generator_tx_packet_count0

    def get_generator_tx_byte_count(self):
        return (self.generator_tx_byte_count1 << 32) + self.generator_tx_byte_count0

    def get_flow_tx_packet_count(self, flow):
        """
        Args:
            flow (int): flow id
        """
        self.tx_counter_flow_sel = flow
        return (self.flow_tx_packet_count1 << 32) + self.flow_tx_packet_count0

    def get_flow_tx_byte_count(self, flow):
        """
        Args:
            flow (int): flow id
        """
        self.tx_counter_flow_sel = flow
        return (self.flow_tx_byte_count1 << 32) + self.flow_tx_byte_count0

    def print_selected_flow_counters(self, flow):
        """
        Args:
            flow (int): flow id
        """
        self.tx_counter_flow_sel = flow
        self.sample_selected_flow_counters = 1
        self.sample_selected_flow_counters = 0
        print("Flow {}".format(flow))
        print("packet count: {}".format(self.get_flow_tx_packet_count(flow)))
        print("byte count:   {}".format(self.get_flow_tx_byte_count(flow)))

    def print_all_flow_counters(self):
        """
        Print all flow counters
        """
        self.sample_all_flow_counters = 1
        self.sample_all_flow_counters = 0
        for flow in range(self.last_flow_id):
            print("Flow {}".format(flow))
            print("packet count: {}".format(self.get_flow_tx_packet_count(flow)))
            print("byte count:   {}".format(self.get_flow_tx_byte_count(flow)))

    def print_generator_counters(self):
        """
        Print generator counters
        """
        self.sample_generator_counters = 1
        self.sample_generator_counters = 0
        print("packet count: {}".format(self.get_generator_tx_packet_count()))
        print("byte count:   {}".format(self.get_generator_tx_byte_count()))

    # Configuration and Control Methods

    def start_generator(self):
        """
        Start the generator
        """
        if not self.flow_def_ram_empty:
            self.transmit = 1
        else:
            print("(E) Can't start the generator when flow def RAM is empty.")

    def stop_generator(self):
        self.transmit = 0

    def set_finit_tx(self, num_packets):
        """
        Args:
            num_packets (int): number of packets to send in finite tx mode.
        """
        self.stop_generator()
        self.finite_tx = 1
        self.tx_finite_packet_count = num_packets

    def set_indefinite_tx(self):
        self.stop_generator()
        self.finite_tx = 0

    def set_rate_mbps(self, rate_mbps):
        """
        Args:
            rate_mbps (float): tx rate in megabits per second.
        """
        self.stop_generator()
        rate_bps = rate_mbps * 1e6
        rate_bytes_per_second = rate_bps / 8.0
        clocks_per_second = 1e12 / self.clock_period_ps
        bytes_per_clock = rate_bytes_per_second / clocks_per_second
        whole_bytes_per_clock = floor(bytes_per_clock)
        self.shaper_whole = floor(bytes_per_clock)
        self.shaper_frac = floor((bytes_per_clock - whole_bytes_per_clock) * 2**16)

    def _set_flow_def_wr_data(self, flow_def):
        """
        Args:
            flow_def (FlowDef): flow def object
        """
        reg_list = []
        wdata = 0
        remaining_bits_in_reg = NetworkPacketGeneratorAvmmAddrs.REG_WIDTH_BITS
        for field, width in zip(flow_def.get_fields(), get_flow_def_field_widths()):
            remaining_bits_in_field = width
            remaining_field = field
            while remaining_bits_in_field > 0:
                if remaining_bits_in_field < remaining_bits_in_reg:
                    wdata |= remaining_field << (remaining_bits_in_reg - remaining_bits_in_field)
                    remaining_bits_in_reg -= remaining_bits_in_field
                    remaining_bits_in_field = 0
                else:
                    wdata |= remaining_field >> (remaining_bits_in_field - remaining_bits_in_reg)
                    remaining_field &= (1 << (remaining_bits_in_field - remaining_bits_in_reg)) - 1
                    remaining_bits_in_field -= remaining_bits_in_reg
                    remaining_bits_in_reg = NetworkPacketGeneratorAvmmAddrs.REG_WIDTH_BITS
                    reg_list.append(wdata)
                    wdata = 0

        if remaining_bits_in_reg != 0:
            reg_list.append(wdata)

        self.flow_def_wr_data0 = reg_list[0]
        self.flow_def_wr_data1 = reg_list[1]
        self.flow_def_wr_data2 = reg_list[2]
        self.flow_def_wr_data3 = reg_list[3]
        self.flow_def_wr_data4 = reg_list[4]
        self.flow_def_wr_data5 = reg_list[5]
        self.flow_def_wr_data6 = reg_list[6]
        self.flow_def_wr_data7 = reg_list[7]
        self.flow_def_wr_data8 = reg_list[8]
        self.flow_def_wr_data9 = reg_list[9]
        self.flow_def_wr_data10 = reg_list[10]
        self.flow_def_wr_data11 = reg_list[11]
        self.flow_def_wr_data12 = reg_list[12]

    def _get_flow_def_rd_data(self):
        """
        Convert Flow Definition read registers to a FlowDef object
        Not yet connected to registers. Just putting the algorithm in place.
        """
        # replace flow_def_wr_data with flow_def_rd_data once implemented
        regs = [
                self.flow_def_wr_data0,
                self.flow_def_wr_data1,
                self.flow_def_wr_data2,
                self.flow_def_wr_data3,
                self.flow_def_wr_data4,
                self.flow_def_wr_data5,
                self.flow_def_wr_data6,
                self.flow_def_wr_data7,
                self.flow_def_wr_data8,
                self.flow_def_wr_data9,
                self.flow_def_wr_data10,
                self.flow_def_wr_data11,
                self.flow_def_wr_data12
        ]

        fd = FlowDef()
        fields = [0] * len(fd.get_fields())
        remaining_bits_in_reg = NetworkPacketGeneratorAvmmAddrs.REG_WIDTH_BITS
        current_reg = 0
        for i, width in enumerate(get_flow_def_field_widths()):
            remaining_bits_in_field = width
            while remaining_bits_in_field > 0:
                if remaining_bits_in_field < remaining_bits_in_reg:
                    fields[i] |= (1 << remaining_bits_in_field) - 1 & (
                            regs[current_reg] >> (remaining_bits_in_reg - remaining_bits_in_field)
                    )
                    remaining_bits_in_reg -= remaining_bits_in_field
                    remaining_bits_in_field = 0
                else:
                    fields[i] |= ((1 << remaining_bits_in_reg) - 1 & regs[current_reg]
                                  ) << (remaining_bits_in_field - remaining_bits_in_reg)
                    remaining_bits_in_field -= remaining_bits_in_reg
                    remaining_bits_in_reg = NetworkPacketGeneratorAvmmAddrs.REG_WIDTH_BITS
                    current_reg += 1

        fd.mac_da, fd.mac_sa, fd.ether_type, fd.vlan_valid, fd.vlan_tag, \
        fd.num_mpls_labels, fd.mpls_label0, fd.mpls_label1, \
        fd.ip_version, fd.ip_ihl, fd.ip_dscp, fd.ip_ecn, fd.ip_length, fd.ip_id, fd.ip_flags, \
        fd.ip_frag_ofs, fd.ip_ttl, fd.ip_prot, fd.ip_hdr_chk, fd.ip_sa, fd.ip_da, \
        fd.pkt_blen_mode, fd.pkt_blen_min, fd.pkt_blen_max, \
        fd.payload_mode, fd.payload_value = fields

        return fd

    def add_flow_def(self, flow_def):
        """
        Args:
            flow_def (FlowDef): flow def object
        """
        self.stop_generator()
        self._set_flow_def_wr_data(flow_def)

        if self.flow_def_ram_empty:
            self.flow_def_flow_sel = 0
            self.flow_def_ram_empty = 0
        else:
            next_index = self.last_flow_id + 1
            self.flow_def_flow_sel = next_index
            self.last_flow_id = next_index

        self.flow_def_wr_enable = 1
        self.flow_def_wr_enable = 0

    def clear_flow_def_ram(self):
        self.last_flow_id = 0
        self.flow_def_ram_empty = 1
