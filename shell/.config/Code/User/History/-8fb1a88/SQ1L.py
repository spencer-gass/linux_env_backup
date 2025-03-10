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
        REG_WIDTH_BYTES * 0x2000,
        REG_WIDTH_BYTES * 0x4000,
        REG_WIDTH_BYTES * 0x6000,
        REG_WIDTH_BYTES * 0x8000,
        REG_WIDTH_BYTES * 0xA000,
        REG_WIDTH_BYTES * 0xC000
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

        self.cam_offsets = VNP4AvmmAddrs.CAM_OFFSETS

    def set_cam_offsets(self, offsets):
        self.cam_offsets = [VNP4AvmmAddrs.REG_WIDTH_BYTES * offset for offset in offsets]
        for i in range(VNP4AvmmAddrs.NUM_CAMS):
            cam_ctrl[i].addr = VNP4AvmmAddrs.CAM_CTRL + offsets[i]
            rd_flag[i].addr = VNP4AvmmAddrs.CAM_CTRL + offsets[i]
            wr_flag[i].addr = VNP4AvmmAddrs.CAM_CTRL + offsets[i]
            reset[i].addr = VNP4AvmmAddrs.CAM_CTRL + offsets[i]
            entry_in_use[i].addr = VNP4AvmmAddrs.CAM_CTRL + offsets[i]

            entry_id[i] = VNP4AvmmAddrs.CAM_ENTRY_ID + offsets[i]
            emulation_mode[i] = VNP4AvmmAddrs.CAM_EMULATION_MODE + offsets[i]
            lookup_count[i] = VNP4AvmmAddrs.CAM_LOOKUP_COUNT + offsets[i]
            hit_count[i] = VNP4AvmmAddrs.CAM_HIT_COUNT + offsets[i]
            miss_count[i] = VNP4AvmmAddrs.CAM_MISS_COUNT + offsets[i]


    def get_cam_offsets(self):
        return self.cam_offsets

    def get_cam_names(self):
        return VNP4AvmmAddrs.CAM_NAMES
