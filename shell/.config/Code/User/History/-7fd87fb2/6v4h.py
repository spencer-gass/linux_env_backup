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
    ADDR_DAC_REG = REG_WIDTH_BYTES * 16
    ADDR_EN_AVMM_CTRL = REG_WIDTH_BYTES * 17

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
