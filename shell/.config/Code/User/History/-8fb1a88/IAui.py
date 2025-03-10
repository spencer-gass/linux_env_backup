"""
Python interface to Vitis Networking P4 lookup tables.
"""

import logging

from time import sleep

from enum import IntEnum

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit, MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)


class VNP4AvmmAddrs(IntEnum):
    """
    AVMM register addresses for p4_router_avmm_regs.sv
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4

    CAM_CTRL = REG_WIDTH_BYTES * 0x00
    CAM_ENTRY_ID = REG_WIDTH_BYTES * 0x01
    CAM_EMULATION_MODE = REG_WIDTH_BYTES * 0x02
    CAM_LOOKUP_COUNT = REG_WIDTH_BYTES * 0X03
    CAM_HIT_COUNT = REG_WIDTH_BYTES * 0X04
    CAM_MISS_COUNT = REG_WIDTH_BYTES * 0X05
    CAM_DATA0 = REG_WIDTH_BYTES * 0X10

    CAM_CTRL_RD_BIT = 0
    CAM_CTRL_WR_BIT = 1
    CAM_CTRL_RST_BIT = 2
    CAM_CTRL_ENTRY_IN_USE_BIT = 31

    CAM_NAMES = [
        'intf_map',
        'lfib',
        'ipv4_fib',
        'cmp_ipv4_fib',
        'cmp_mac_fib',
        'vlan_map'
    ]
    NUM_CAMS = len(CAM_NAMES)
    CAM_OFFSETS = [
        0x2000,
        0x4000,
        0x6000,
        0x8000,
        0xA000,
        0xC000
    ]

class VNP4Avmm(AvmmCommonCtrl):
    """
    An interface to Vitis Networking P4 lookup tables.
    """

    cam_ctrl = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_cam_ctrl", addr=VNP4AvmmAddrs.CAM_CTRL + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]
    rd_flag = [MMIDescBit(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_rd_flag", addr=VNP4AvmmAddrs.CAM_CTRL + VNP4AvmmAddrs.CAM_OFFSETS[i], bit=VNP4AvmmAddrs.CAM_CTRL_RD_BIT) for i in range VNP4AvmmAddrs.NUM_CAMS]
    wr_flag = [MMIDescBit(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_wr_flag", addr=VNP4AvmmAddrs.CAM_CTRL + VNP4AvmmAddrs.CAM_OFFSETS[i], bit=VNP4AvmmAddrs.CAM_CTRL_WR_BIT) for i in range VNP4AvmmAddrs.NUM_CAMS]
    reset = [MMIDescBit(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_reset", addr=VNP4AvmmAddrs.CAM_CTRL + VNP4AvmmAddrs.CAM_OFFSETS[i], bit=VNP4AvmmAddrs.CAM_CTRL_RST_BIT) for i in range VNP4AvmmAddrs.NUM_CAMS]
    entry_in_use = [MMIDescBit(
            name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_entry_in_use",
            addr=VNP4AvmmAddrs.CAM_CTRL + VNP4AvmmAddrs.CAM_OFFSETS[i],
            bit=VNP4AvmmAddrs.CAM_CTRL_ENTRY_IN_USE_BIT
    ) for i in range VNP4AvmmAddrs.NUM_CAMS]

    entry_id = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_entry_id", addr=VNP4AvmmAddrs.CAM_ENTRY_ID + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]
    emulation_mode = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_emulation_mode", addr=VNP4AvmmAddrs.CAM_EMULATION_MODE + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]
    lookup_count = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_lookup_count", addr=VNP4AvmmAddrs.CAM_LOOKUP_COUNT + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]
    hit_count = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_hit_count", addr=VNP4AvmmAddrs.CAM_HIT_COUNT + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]
    miss_count = [MMIDesc(name=f"{VNP4AvmmAddrs.CAM_NAMES[i]}_miss_count", addr=VNP4AvmmAddrs.CAM_MISS_COUNT + VNP4AvmmAddrs.CAM_OFFSETS[i]) for i in range VNP4AvmmAddrs.NUM_CAMS]

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the aurora_frontend module.
        """
        super().__init__(sdr_host, offset)
        self.num_queues = P4RouterAvmmAddrs.NUM_QUEUES_PER_EGRESS_PORT * self.num_egr_phys_ports

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
        self.ing_cntrs_sample_con &= ~(1 << port)
        self.ing_cntrs_sample_con |= (1 << port)
        self.ing_cntrs_sample_con &= ~(1 << port)

    def sample_egress_counters(self, port):
        self.egr_cntrs_sample_con &= ~(1 << port)
        self.egr_cntrs_sample_con |= (1 << port)
        self.egr_cntrs_sample_con &= ~(1 << port)

    def read_ingress_counter(self, port, counter):
        self.ing_cntrs_rd_port_sel = port
        self.ing_cntrs_rd_cntr_sel = counter
        return self.ing_cntrs_rd_data0 + (self.ing_cntrs_rd_data1 << 32)

    def read_egress_counter(self, port, counter):
        self.egr_cntrs_rd_port_sel = port
        self.egr_cntrs_rd_cntr_sel = counter
        return self.egr_cntrs_rd_data0 + (self.egr_cntrs_rd_data1 << 32)

    def print_port_ingress_and_egress_counters(self, port, print_zeros=False):
        """
        Args:
            port (int): selects which ports's counters are read.
            print_zeros (bool): when set to false, don't print zero counters.
                Useful for printing all counters.
        """
        self.sample_ingress_counters(port)
        self.sample_egress_counters(port)
        ing_pkt_cnt = self.read_ingress_counter(port, P4RouterAvmmAddrs.PACKET_COUNT_INDEX)
        ing_byte_cnt = self.read_ingress_counter(port, P4RouterAvmmAddrs.BYTE_COUNT_INDEX)
        ing_err_cnt = self.read_ingress_counter(port, P4RouterAvmmAddrs.ERR_COUNT_INDEX)
        ing_fifo_ovf_cnt = self.read_ingress_counter(
                port,
                P4RouterAvmmAddrs.ING_ASYNC_FIFO_OVERFLOW_INDEX
        )
        ing_buf_ovf_cnt = self.read_ingress_counter(port, P4RouterAvmmAddrs.ING_BUF_OVERFLOW_INDEX)
        egr_pkt_cnt = self.read_egress_counter(port, P4RouterAvmmAddrs.PACKET_COUNT_INDEX)
        egr_byte_cnt = self.read_egress_counter(port, P4RouterAvmmAddrs.BYTE_COUNT_INDEX)
        egr_err_cnt = self.read_egress_counter(port, P4RouterAvmmAddrs.ERR_COUNT_INDEX)
        egr_buf_ovf_cnt = self.read_egress_counter(port, P4RouterAvmmAddrs.EGR_BUF_OVERFLOW_INDEX)
        if ing_pkt_cnt or ing_byte_cnt or ing_err_cnt or ing_fifo_ovf_cnt or ing_buf_ovf_cnt or \
            egr_pkt_cnt or egr_byte_cnt or egr_err_cnt or egr_buf_ovf_cnt or print_zeros:
            print('Ingress and Egress Counter for Port {}'.format(port))
            if ing_pkt_cnt or print_zeros:
                print('Ingress Packets          : {}'.format(ing_pkt_cnt))
            if ing_byte_cnt or print_zeros:
                print('Ingress Bytes            : {}'.format(ing_byte_cnt))
            if ing_err_cnt or print_zeros:
                print('Ingress Errors           : {}'.format(ing_err_cnt))
            if ing_fifo_ovf_cnt or print_zeros:
                print('Ingress Fifo Overflows   : {}'.format(ing_fifo_ovf_cnt))
            if ing_buf_ovf_cnt or print_zeros:
                print('Ingress Buffer Overflows : {}'.format(ing_buf_ovf_cnt))
            if egr_pkt_cnt or print_zeros:
                print('Egress Packets           : {}'.format(egr_pkt_cnt))
            if egr_byte_cnt or print_zeros:
                print('Egress Bytes             : {}'.format(egr_byte_cnt))
            if egr_err_cnt or print_zeros:
                print('Egress Errors            : {}'.format(egr_err_cnt))
            if egr_buf_ovf_cnt or print_zeros:
                print('Egress Buffer Overflows  : {}'.format(egr_buf_ovf_cnt))

    def print_all_ingress_and_egress_counters(self, print_zeros=False):
        for port in range(self.num_ing_phys_ports):
            self.print_port_ingress_and_egress_counters(port, print_zeros)

    def sample_all_ingress_and_egress_counters(self):
        for port in range(self.num_ing_phys_ports):
            self.sample_ingress_counters(port)
            self.sample_egress_counters(port)

    # Queue System Table Config Methods

    def _write_qsys_table(self, table, addr, data):
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

    def write_ing_policer_cir_table(self, addr, data):
        return self._write_qsys_table(P4RouterAvmmAddrs.ING_POLICER_CIR_TABLE, addr, data)

    def write_ing_policer_cbs_table(self, addr, data):
        return self._write_qsys_table(P4RouterAvmmAddrs.ING_POLICER_CBS_TABLE, addr, data)

    def write_cong_man_drop_thresh_table(self, addr, data):
        return self._write_qsys_table(P4RouterAvmmAddrs.CONG_MAN_DROP_THRESH_TABLE, addr, data)

    def config_ing_policer(self, port, cir, cbs):
        '''
        Args:
            port (int) ingress port
            cir (int) ingress shaper rate in Mbps
            cbs (int) virtual ingress buffer in bytes
        '''

        self.write_ing_policer_cbs_table(port, cbs)
        cir_bytes_per_cycle_decimal = cir / 8000.0 * self.clock_period_ps / 1000.0
        cir_bytes_per_cycle_hex = int(cir_bytes_per_cycle_decimal * 2**13)
        self.write_ing_policer_cir_table(port, cir_bytes_per_cycle_hex)

    def _read_qsys_table(self, table, addr):
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

    def read_ing_policer_cir_table(self, addr):
        return self._read_qsys_table(P4RouterAvmmAddrs.ING_POLICER_CIR_TABLE, addr)

    def read_ing_policer_cbs_table(self, addr):
        return self._read_qsys_table(P4RouterAvmmAddrs.ING_POLICER_CBS_TABLE, addr)

    def read_cong_man_drop_thresh_table(self, addr):
        return self._read_qsys_table(P4RouterAvmmAddrs.CONG_MAN_DROP_THRESH_TABLE, addr)

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
        if self.qsys_cntr_op_busy:
            raise Exception("Queue System Counter Op Timed Out.")

        self.qsys_cntr_op_req = 1

        cnt = 0
        while (self.qsys_cntr_op_busy and cnt < 10):
            cnt += 1
            sleep(0.01)
        if self.qsys_cntr_op_busy:
            raise Exception("Queue System Counter Op Timed Out.")

        if self.qsys_cntr_op_err:
            raise Exception(
                    "Queue System Counter Op Error. \
                Probably invalid queue or counter type."
            )

        return self.qsys_cntr_rd_data

    def read_drop_counter(self, queue, cntr):
        return self._drop_counter_op(queue, cntr, P4RouterAvmmAddrs.READ)

    def read_and_clear_drop_counter(self, queue, cntr):
        return self._drop_counter_op(queue, cntr, P4RouterAvmmAddrs.READ_AND_CLEAR)

    def clear_all_drop_counters(self):
        return self._drop_counter_op(0, 0, P4RouterAvmmAddrs.CLEAR_ALL)

    def print_queue_drop_counters(self, queue, print_zeros=False):
        """
        Args:
            queue (int): selects which queue's counters are read.
            print_zeros (bool): when set to false, don't print zero counters.
                Useful for printing all counters.
        """
        ing_policer_drops = self.read_and_clear_drop_counter(
                queue,
                P4RouterAvmmAddrs.ING_POLICER_DROPS
        )
        queue_full_drops = self.read_and_clear_drop_counter(
                queue,
                P4RouterAvmmAddrs.QUEUE_FULL_DROPS
        )
        malloc_drops = self.read_and_clear_drop_counter(queue, P4RouterAvmmAddrs.MALLOC_DROP)
        mem_full_drops = self.read_and_clear_drop_counter(queue, P4RouterAvmmAddrs.MEM_FULL_DROPS)
        b2b_drops = self.read_and_clear_drop_counter(queue, P4RouterAvmmAddrs.B2B_DROPS)

        if ing_policer_drops or queue_full_drops or malloc_drops or \
        mem_full_drops or b2b_drops or print_zeros:
            print("Drop Counters for Queue {}".format(queue))
            if ing_policer_drops or print_zeros:
                print("Ingress Shaper Drops     : {}".format(ing_policer_drops))
            if queue_full_drops or print_zeros:
                print("Queue Full Drops         : {}".format(queue_full_drops))
            if malloc_drops or print_zeros:
                print("Memory Allocation Drops  : {}".format(malloc_drops))
            if mem_full_drops or print_zeros:
                print("Memory Full Drops        : {}".format(mem_full_drops))
            if b2b_drops or print_zeros:
                print("Back to Back SOP Drops   : {}".format(b2b_drops))

    def print_all_drop_counters(self):
        for queue in range(self.num_queues):
            self.print_queue_drop_counters(queue)

    def sample_all_packet_counters(self):
        self.pkt_cnt_sample_req = 0
        self.pkt_cnt_sample_req = P4RouterAvmmAddrs.ALL_PKT_CNT_SAMPLE_REQ
        self.pkt_cnt_sample_req = 0

    def get_pkt_cnt(self, index):
        self.pkt_cnt_sel = index
        return (self.pkt_cnt_rd_data1 << 32) + self.pkt_cnt_rd_data0

    def print_and_clear_packet_counters(self):
        """
        Args:

        """
        ing_pkt_cnt = 0
        egr_pkt_cnt = 0
        self.sample_all_packet_counters()
        for port in range(self.num_ing_phys_ports):
            ing_pkt_cnt += self.read_ingress_counter(port, P4RouterAvmmAddrs.PACKET_COUNT_INDEX)
            egr_pkt_cnt += self.read_egress_counter(port, P4RouterAvmmAddrs.PACKET_COUNT_INDEX)

        print('Ingress Ports : {}'.format(ing_pkt_cnt))
        print("Ingress Bus   : {}".format(self.get_pkt_cnt(P4RouterAvmmAddrs.ING_BUS_DBG_CNT)))
        print("Policer       : {}".format(self.get_pkt_cnt(P4RouterAvmmAddrs.POLICER_DBG_CNT)))
        print("Enqueue       : {}".format(self.get_pkt_cnt(P4RouterAvmmAddrs.ENQUEUE_DBG_CNT)))
        print("Dequeue       : {}".format(self.get_pkt_cnt(P4RouterAvmmAddrs.DEQUEUE_DBG_CNT)))
        print('Egress Ports  : {}'.format(egr_pkt_cnt))
