"""
Python interface to p4_router_avmm_regs.sv
"""

import logging

from enum import IntEnum

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit, MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)


class P4RouterAvmmAddrs(IntEnum):
    """
    AVMM register addresses for p4_router_avmm_regs.sv
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4

    # AVMM common register 0-15
    # p4_router_avmm_regs 16+
    ADDR_PARAMS0 = REG_WIDTH_BYTES * 16
    ADDR_PARAMS1 = REG_WIDTH_BYTES * 17
    ADDR_ING_PORT_ENABLE_CON = REG_WIDTH_BYTES * 18
    ADDR_EGR_PORT_ENABLE_CON = REG_WIDTH_BYTES * 19
    ADDR_ING_PORT_ENABLE_STATE = REG_WIDTH_BYTES * 20
    ADDR_EGR_PORT_ENABLE_STATE = REG_WIDTH_BYTES * 21
    ADDR_ING_COUNTER_CON = REG_WIDTH_BYTES * 22
    ADDR_EGR_COUNTER_CON = REG_WIDTH_BYTES * 23
    ADDR_ING_COUNTERS_START = REG_WIDTH_BYTES * 24


class P4RouterAvmm(AvmmCommonCtrl):
    """
    An interface to p4_router_avmm_regs.sv
    """

    num_ing_phys_ports = MMIRODesc(
        name="num_ing_phys_ports",
        addr=P4RouterAvmmAddrs.ADDR_PARAMS0,
        msb=7,
        lsb=0
    )

    num_egr_phys_ports = MMIRODesc(
        name="num_egr_phys_ports",
        addr=P4RouterAvmmAddrs.ADDR_PARAMS0,
        msb=15,
        lsb=7
    )

    vnp4_data_bytes = MMIRODesc(
        name="vnp4_data_bytes",
        addr=P4RouterAvmmAddrs.ADDR_PARAMS0,
        msb=23,
        lsb=16
    )

    mtu_bytes = MMIRODesc(
        name="mtu_bytes",
        addr=P4RouterAvmmAddrs.ADDR_PARAMS1,
        msb=15,
        lsb=0
    )

    ing_port_enable_con = MMIDesc(
        name="ing_port_enable_con",
        addr=P4RouterAvmmAddrs.ADDR_ING_PORT_ENABLE_CON,
        msb=31,
        lsb=0
    )

    egr_port_enable_con = MMIDesc(
        name="egr_port_enable_con",
        addr=P4RouterAvmmAddrs.ADDR_EGR_PORT_ENABLE_CON,
        msb=31,
        lsb=0
    )

    ing_port_enable_state = MMIDesc(
        name="ing_port_enable_state",
        addr=P4RouterAvmmAddrs.ADDR_ING_PORT_ENABLE_STATE,
        msb=31,
        lsb=0
    )

    egr_port_enable_state = MMIDesc(
        name="egr_port_enable_state",
        addr=P4RouterAvmmAddrs.ADDR_EGR_PORT_ENABLE_STATE,
        msb=31,
        lsb=0
    )

    ing_counter_con = MMIDesc(
        name="ing_counter_con",
        addr=P4RouterAvmmAddrs.ADDR_ING_COUNTER_CON,
        msb=31,
        lsb=0
    )

    egr_counter_con = MMIDesc(
        name="egr_counter_con",
        addr=P4RouterAvmmAddrs.ADDR_EGR_COUNTER_CON,
        msb=31,
        lsb=0
    )

    # operating_mode = MMIDesc(
    #         name="dac_operating_mode",
    #         addr=P4RouterAvmmAddrs.ADDR_DAC_REG,
    #         msb=15,
    #         lsb=14
    # )

    # data = MMIDesc(name="data", addr=P4RouterAvmmAddrs.ADDR_DAC_REG, msb=13, lsb=6)

    # en_avmm_ctrl = MMIRODescBit(
    #         name="en_avmm_ctrl",
    #         addr=P4RouterAvmmAddrs.ADDR_EN_AVMM_CTRL,
    #         bit=0
    # )

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the aurora_frontend module.
        """
        super().__init__(sdr_host, offset)
        self.NUM_COUNTERS_PER_ING_PORT = 5
        self.NUM_COUNTERS_PER_EGR_PORT = 4
        self.PKT_CNT_INDEX = 0
        self.BYTE_CNT_INDEX = 1
        self.ERR_CNT_INDEX = 2
        self.ING_ASYNC_FIFO_OVF_CNT_INDEX = 3
        self.ING_BUF_OVF_CNT_INDEX = 4
        self.EGR_BUF_OVF_CNT_INDEX = 4


        self.ingress_packet_counts = []
        self.ingress_byte_counts = []
        self.ingress_error_counts = []
        self.ingress_async_fifo_overflow_counts = []
        self.ingress_buffer_overflow_counters = []
        for port in range(num_ing_phys_ports):
            d = MMIRODesc(
                    name="ingress_port{}_packet_count",
                    addr=P4RouterAvmmAddrs.ADDR_ING_COUNTERS_START+self.NUM_COUNTERS_PER_ING_PORT*port+self.PKT_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.ingress_packet_counts.append(d)

            d = MMIRODesc(
                    name="ingress_port{}_byte_count",
                    addr=P4RouterAvmmAddrs.ADDR_ING_COUNTERS_START+self.NUM_COUNTERS_PER_ING_PORT*port+self.BYTE_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.ingress_byte_counts.append(d)

            d = MMIRODesc(
                    name="ingress_port{}_error_count",
                    addr=P4RouterAvmmAddrs.ADDR_ING_COUNTERS_START+self.NUM_COUNTERS_PER_ING_PORT*port+self.ERR_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.ingress_error_counts.append(d)

            d = MMIRODesc(
                    name="ingress_port{}_async_fifo_overflow_count",
                    addr=P4RouterAvmmAddrs.ADDR_ING_COUNTERS_START+self.NUM_COUNTERS_PER_ING_PORT*port+self.ING_ASYNC_FIFO_OVF_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.ingress_async_fifo_overflow_counts.append(d)

            d = MMIRODesc(
                    name="ingress_port{}_buffer_overflow_count",
                    addr=P4RouterAvmmAddrs.ADDR_ING_COUNTERS_START+self.NUM_COUNTERS_PER_ING_PORT*port+self.ING_BUF_OVF_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.ingress_buffer_overflow_counts.append(d)

        self.egress_packet_counts = []
        self.egress_byte_counts = []
        self.egress_error_counts = []
        self.egress_async_fifo_overflow_counts = []
        self.egress_buffer_overflow_counters = []
        self.ADDR_EGR_COUNTERS_START = self.ADDR_ING_COUNTERS_START + self.num_ing_phys_ports * self.NUM_COUNTERS_PER_ING_PORT
        for port in range(num_egr_phys_ports):
            d = MMIRODesc(
                    name="egress_port{}_packet_count",
                    addr=self.ADDR_EGR_COUNTERS_START+self.NUM_COUNTERS_PER_EGR_PORT*port+self.PKT_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.egress_packet_counts.append(d)

            d = MMIRODesc(
                    name="egress_port{}_byte_count",
                    addr=self.ADDR_EGR_COUNTERS_START+self.NUM_COUNTERS_PER_EGR_PORT*port+self.BYTE_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.egress_byte_counts.append(d)

            d = MMIRODesc(
                    name="egress_port{}_error_count",
                    addr=self.ADDR_EGR_COUNTERS_START+self.NUM_COUNTERS_PER_EGR_PORT*port+self.ERR_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.egress_error_counts.append(d)

            d = MMIRODesc(
                    name="egress_port{}_async_fifo_overflow_count",
                    addr=self.ADDR_EGR_COUNTERS_START+self.NUM_COUNTERS_PER_EGR_PORT*port+self.EGR_ASYNC_FIFO_OVF_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.egress_async_fifo_overflow_counts.append(d)

            d = MMIRODesc(
                    name="egress_port{}_buffer_overflow_count",
                    addr=self.ADDR_EGR_COUNTERS_START+self.NUM_COUNTERS_PER_EGR_PORT*port+self.EGR_BUF_OVF_CNT_INDEX,
                    msb=31,
                    lsb=0
                )
            self.egress_buffer_overflow_counts.append(d)


    # Port Enable / Disable Setters

    def enable_ingress_port(self, port):
        self.ing_port_enable_con |= (1 << port)

    def enable_egress_port(self, port):
        self.ing_port_enable_con |= (1 << port)

    def disable_ingress_port(self, port):
        self.ing_port_enable_con &= ~(1 << port)

    def disable_egress_port(self, port):
        self.egr_port_enable_con &= ~(1 << port)

    def enable_all_ingress_ports(self):
        for port in range(self.num_ing_phys_ports):
            self.enable_ingress_port(port)

    def disable_all_ingress_ports(self):
        for port in range(self.num_ing_phys_ports):
            self.disable_ingress_port(port)

    def enable_all_egress_ports(self):
        for port in range(self.num_egr_phys_ports):
            self.enable_egress_port(port)

    def disable_all_egress_ports(self):
        for port in range(self.num_egr_phys_ports):
            self.disable_egress_port(port)

    def enable_all_ports(self):
        self.enable_all_ingress_ports()
        self.enable_all_egress_ports()

    def disable_all_ports(self):
        self.disable_all_ingress_ports()
        self.disable_ingress_port()

    # Port State Getters

    def get_ingress_port_state(self, port):
        return (self.ing_port_enable_state >> port) & 1

    def get_egress_port_state(self, port):
        return (self.egr_port_enable_state >> port) & 1

    # Counter Methods

    def sample_ingress_counters(self, port):
        self.ing_counter_con &= ~(1 << port)
        self.ing_counter_con |= (1 << port)
        self.ing_counter_con &= ~(1 << port)

    def sample_egress_counters(self,port):
        self.egr_counter_con &= ~(1 << port)
        self.egr_counter_con |= (1 << port)
        self.egr_counter_con &= ~(1 << port)