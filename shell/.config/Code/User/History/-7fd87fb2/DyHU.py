"""
Python interface to p4_router_avmm_regs.sv
"""

import logging

from time import sleep

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
    ADDR_ING_PORT_ENABLE_STAT = REG_WIDTH_BYTES * 20
    ADDR_EGR_PORT_ENABLE_STAT = REG_WIDTH_BYTES * 21
    ADDR_ING_CNTRS_SAMPLE_CON = REG_WIDTH_BYTES * 22
    ADDR_ING_CNTRS_RD_SEL = REG_WIDTH_BYTES * 23
    ADDR_ING_CNTRS_RD_DATA = REG_WIDTH_BYTES * 24
    ADDR_EGR_CNTRS_SAMPLE_CON = REG_WIDTH_BYTES * 25
    ADDR_EGR_CNTRS_RD_SEL = REG_WIDTH_BYTES * 26
    ADDR_EGR_CNTRS_RD_DATA = REG_WIDTH_BYTES * 27
    ADDR_ING_POLICER_ENABLE = REG_WIDTH_BYTES * 28
    ADDR_QSYS_TABLE_CONFIG = REG_WIDTH_BYTES * 29
    ADDR_QSYS_CONFIG_WDATA = REG_WIDTH_BYTES * 30
    ADDR_QSYS_CONFIG_RDATA = REG_WIDTH_BYTES * 31
    ADDR_QSYS_CNTR_CON = REG_WIDTH_BYTES * 32
    ADDR_QSYS_CNTR_RDATA = REG_WIDTH_BYTES * 33

    ING_POLICER_CIR_TABLE = 0
    ING_POLICER_CBS_TABLE = 1
    CONG_MAN_DROP_THRESH_TABLE = 2

    ING_POLICER_DROPS = 0
    QUEUE_FULL_DROPS = 1
    MALLOC_DROP = 2
    MEM_FULL_DROPS = 3
    B2B_DROPS = 4

    READ = 0
    READ_AND_CLEAR = 1
    CLEAR_ALL = 2

    NUM_QUEUES_PER_EGRESS_PORT = 4

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

    clock_period_ps = MMIRODesc(
            name="clock_period_ps",
            addr=P4RouterAvmmAddrs.ADDR_PARAMS1,
            msb=31,
            lsb=16
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

    ing_policer_enable = MMIDesc(
            name="ing_policer_enable",
            addr=P4RouterAvmmAddrs.ADDR_ING_POLICER_ENABLE,
            msb=31,
            lsb=0
    )

    qsys_table_wr_err = MMIRODescBit(
            name="qsys_table_wr_err",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=29
    )
    qsys_table_rd_err = MMIRODescBit(
            name="qsys_table_rd_err",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=28
    )
    qsys_table_wr_busy = MMIRODescBit(
            name="qsys_table_wr_busy",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=27
    )
    qsys_table_rd_busy = MMIRODescBit(
            name="qsys_table_rd_busy",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=26
    )

    qsys_table_wr_req = MMIDescBit(
            name="qsys_table_wr_req",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=25
    )

    qsys_table_rd_req = MMIDescBit(
            name="qsys_table_rd_req",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=24
    )

    qsys_table_sel = MMIDesc(
            name="qsys_table_sel",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            msb=17,
            lsb=16
    )

    qsys_table_addr = MMIDesc(
            name="qsys_table_addr",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            msb=15,
            lsb=0
    )

    qsys_table_wr_data = MMIDesc(
            name="qsys_table_wr_data",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CONFIG_WDATA,
            msb=31,
            lsb=0
    )

    qsys_table_rd_data = MMIRODesc(
            name="qsys_table_rd_data",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CONFIG_RDATA,
            msb=31,
            lsb=0
    )

    qsys_cntr_op_err = MMIRODescBit(
            name="qsys_cntr_op_err",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=26
    )

    qsys_cntr_op_busy = MMIRODescBit(
            name="qsys_cntr_op_busy",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=25
    )

    qsys_cntr_op_req = MMIDescBit(
            name="qsys_cntr_op_req",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_TABLE_CONFIG,
            bit=24
    )

    qsys_cntr_op_code = MMIDesc(
            name="qsys_cntr_op_code",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CNTR_CON,
            msb=21,
            lsb=20
    )

    qsys_cntr_type_sel = MMIDesc(
            name="qsys_cntr_type_sel",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CNTR_CON,
            msb=19,
            lsb=12
    )

    qsys_cntr_queue_sel = MMIDesc(
            name="qsys_cntr_queue_sel",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CNTR_CON,
            msb=11,
            lsb=0
    )

    qsys_cntr_rd_data = MMIRODesc(
            name="qsys_cntr_rd_data",
            addr=P4RouterAvmmAddrs.ADDR_QSYS_CNTR_RDATA,
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
        self.num_queues = self.NUM_QUEUES_PER_EGRESS_PORT * self.num_egr_phys_ports

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

    # Queue System Table Config Methods

    def _wr_qsys_table(self, table, addr, data):
        self.qsys_table_wr_data = data
        self.qsys_table_sel = table
        self.qsys_table_addr = addr
        self.qsys_table_wr_req = 0

        cnt = 0
        while (self.qsys_table_wr_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if (self.qsys_table_wr_busy and cnt == 10):
            raise Exception("Queue System Table Write Timed Out.")
        self.qsys_table_wr_req = 1

        cnt = 0
        while (self.qsys_table_wr_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if (self.qsys_table_wr_busy and cnt == 10):
            raise Exception("Queue System Table Write Timed Out.")

        return self.qsys_table_wr_err

    def wr_ing_policer_cir_table(self, addr, data):
        return self._wr_qsys_table(self.ING_POLICER_CIR_TABLE, addr, data)

    def wr_ing_policer_cbs_table(self, addr, data):
        return self._wr_qsys_table(self.ING_POLICER_CBS_TABLE, addr, data)

    def wr_cong_man_drop_thresh_table(self, addr, data):
        return self._wr_qsys_table(self.CONG_MAN_DROP_THRESH_TABLE, addr, data)

    def _rd_queue_sys_table(self, table, addr):
        self.qsys_table_sel = table
        self.qsys_table_addr = addr
        self.qsys_table_rd_req = 0

        cnt = 0
        while (self.qsys_table_rd_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if self.qsys_table_rd_busy and cnt == 10:
            raise Exception("Queue System Table Read Timed Out.")
        self.qsys_table_rd_req = 1

        cnt = 0
        while (self.qsys_table_rd_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if self.qsys_table_rd_busy:
            raise Exception("Queue System Table Read Timed Out.")

        return self.qsys_table_rd_data

    def rd_ing_policer_cir_table(self, addr):
        return self._rd_qsys_table(self.ING_POLICER_CIR_TABLE, addr)

    def rd_ing_policer_cbs_table(self, addr):
        return self._rd_qsys_table(self.ING_POLICER_CBS_TABLE, addr)

    def rd_cong_man_drop_thresh_table(self, addr):
        return self._rd_qsys_table(self.CONG_MAN_DROP_THRESH_TABLE, addr)

    # Queue System Counter Methods

    def _drop_counter_op(self, queue, cntr, op):
        self.qsys_cntr_op_req = 0
        self.qsys_cntr_op_code = op
        self.qsys_cntr_type_sel = cntr
        self.qsys_cntr_queue_sel = queue

        cnt = 0
        while (self.qsys_cntr_op_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if self.qsys_cntr_of_busy:
            raise Exception("Queue System Counter Op Timed Out.")

        self.qsys_cntr_op_req = 1

        cnt = 0
        while (self.qsys_cntr_op_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if self.qsys_cntr_of_busy:
            raise Exception("Queue System Counter Op Timed Out.")

        if self.qsys_cntr_op_err:
            raise Exception("Queue System Counter Op Error. \
                Probably invalid queue or counter type.")

        return self.qsys_cntr_rd_data

    def read_drop_counter(self, queue, cntr):
        return self._drop_counter_op(queue, cntr, self.READ)

    def read_and_clear_drop_counter(self, queue, cntr):
        return self._drop_counter_op(queue, cntr, self.READ_AND_CLEAR)

    def clear_all_drop_counters(self):
        return self._drop_counter_op(0, 0, self.CLEAR_ALL)

    def print_queue_drop_counters(self, queue, print_zeros=False):
        """
        Args:
            queue: selects which queue's counters are read.
            print_zeros: when set to false, don't print zero counters.
                Useful for printing all counters.
        """
        ing_policer_drops = self.read_drop_counter(queue,self.ING_POLICER_DROPS)
        queue_full_drops = self.read_drop_counter(queue,self.QUEUE_FULL_DROPS)
        malloc_drops = self.read_drop_counter(queue,self.MALLOC_DROP)
        mem_full_drops = self.read_drop_counter(queue,self.MEM_FULL_DROPS)
        b2b_drops = self.read_drop_counter(queue,self.B2B_DROPS)

        if ing_policer_drops or queue_full_drops or malloc_drops or \
        mem_full_drops or b2b_drops or print_zeros:
            print("Drop Counters for Queue {}".format(queue))
            if ing_policer_drops:
                print("Ingress Shaper Drops     : {}".format(ing_policer_drops))
            if queue_full_drops:
                print("Queue Full Drops         : {}".format(queue_full_drops))
            if malloc_drops:
                print("Memory Allocation Drops  : {}".format(malloc_drops))
            if mem_full_drops:
                print("Memory Full Drops        : {}".format(mem_full_drops))
            if b2b_drops:
                print("Back to Back SOP Drops   : {}".format(b2b_drops))

    def print_all_drop_counters(self):
        for queue in range(self.num_queues):
            self.print_queue_drop_counters(queue)
