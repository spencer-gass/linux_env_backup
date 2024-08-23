"""
Python interface to p4_router_avmm_regs.sv
"""

import logging

from enum import IntEnum

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIRODesc

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
    ADDR_ING_PORT_ENABLE_STAT = REG_WIDTH_BYTES * 20
    ADDR_EGR_PORT_ENABLE_STAT = REG_WIDTH_BYTES * 21
    ADDR_ING_CNTRS_SAMPLE_CON = REG_WIDTH_BYTES * 22
    ADDR_ING_CNTRS_RD_SEL = REG_WIDTH_BYTES * 23
    ADDR_ING_CNTRS_RD_DATA = REG_WIDTH_BYTES * 24
    ADDR_EGR_CNTRS_SAMPLE_CON = REG_WIDTH_BYTES * 25
    ADDR_EGR_CNTRS_RD_SEL = REG_WIDTH_BYTES * 26
    ADDR_EGR_CNTRS_RD_DATA = REG_WIDTH_BYTES * 27


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

    mtu_bytes = MMIRODesc(name="mtu_bytes", addr=P4RouterAvmmAddrs.ADDR_PARAMS1, msb=15, lsb=0)

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

    ing_port_enable_stat = MMIDesc(
            name="ing_port_enable_stat",
            addr=P4RouterAvmmAddrs.ADDR_ING_PORT_ENABLE_STAT,
            msb=31,
            lsb=0
    )

    egr_port_enable_stat = MMIDesc(
            name="egr_port_enable_stat",
            addr=P4RouterAvmmAddrs.ADDR_EGR_PORT_ENABLE_STAT,
            msb=31,
            lsb=0
    )

    ing_cntrs_sample_con = MMIDesc(
            name="ing_cntrs_sample_con",
            addr=P4RouterAvmmAddrs.ADDR_ING_CNTRS_SAMPLE_CON,
            msb=31,
            lsb=0
    )

    ing_cntrs_rd_port_sel = MMIDesc(
            name="ing_cntrs_rd_port_sel",
            addr=P4RouterAvmmAddrs.ADDR_ING_CNTRS_RD_SEL,
            msb=15,
            lsb=8
    )

    ing_cntrs_rd_cntr_sel = MMIDesc(
            name="ing_cntrs_rd_cntr_sel",
            addr=P4RouterAvmmAddrs.ADDR_ING_CNTRS_RD_SEL,
            msb=7,
            lsb=0
    )

    ing_cntrs_rd_data = MMIRODesc(
            name="ing_cntrs_rd_data",
            addr=P4RouterAvmmAddrs.ADDR_ING_CNTRS_RD_DATA,
            msb=31,
            lsb=0
    )

    egr_cntrs_sample_con = MMIDesc(
            name="egr_cntrs_sample_con",
            addr=P4RouterAvmmAddrs.ADDR_EGR_CNTRS_SAMPLE_CON,
            msb=31,
            lsb=0
    )

    egr_cntrs_rd_port_sel = MMIDesc(
            name="egr_cntrs_rd_port_sel",
            addr=P4RouterAvmmAddrs.ADDR_EGR_CNTRS_RD_SEL,
            msb=15,
            lsb=8
    )

    egr_cntrs_rd_cntr_sel = MMIDesc(
            name="egr_cntrs_rd_cntr_sel",
            addr=P4RouterAvmmAddrs.ADDR_EGR_CNTRS_RD_SEL,
            msb=7,
            lsb=0
    )

    egr_cntrs_rd_data = MMIRODesc(
            name="egr_cntrs_rd_data",
            addr=P4RouterAvmmAddrs.ADDR_EGR_CNTRS_RD_DATA,
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
        self.ing_pkt_cnt_index = 0
        self.ing_byte_cnt_index = 1
        self.ing_err_cnt_index = 2
        self.ing_async_fifo_ovf_cnt_index = 3
        self.ing_buf_ovf_cnt_index = 4
        self.egr_pkt_cnt_index = 0
        self.egr_byte_cnt_index = 1
        self.egr_err_cnt_index = 2
        self.egr_buf_ovf_cnt_index = 4

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
        self.disable_all_egress_port()

    # Port Status Getters

    def get_ingress_port_stat(self, port):
        return (self.ing_port_enable_stat >> port) & 1

    def get_egress_port_stat(self, port):
        return (self.egr_port_enable_stat >> port) & 1

    # Counter Methods

    def sample_ingress_counters(self, port):
        self.ing_counter_con &= ~(1 << port)
        self.ing_counter_con |= (1 << port)
        self.ing_counter_con &= ~(1 << port)

    def sample_egress_counters(self, port):
        self.egr_counter_con &= ~(1 << port)
        self.egr_counter_con |= (1 << port)
        self.egr_counter_con &= ~(1 << port)

    def read_ingress_counter(self, port, counter):
        self.ing_cntrs_rd_port_sel = port
        self.ing_cntrs_rd_cntr_sel = counter
        return self.ing_cntrs_rd_data

    def read_egress_counter(self, port, counter):
        self.egr_cntrs_rd_port_sel = port
        self.egr_cntrs_rd_cntr_sel = counter
        return self.egr_cntrs_rd_data
