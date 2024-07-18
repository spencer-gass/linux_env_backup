"""
Python interface to dac_ad5601_ctrl_avmm
"""

import logging

from enum import IntEnum

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit, MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)


class DACAD5601AvmmAddrs(IntEnum):
    """
    AVMM register addresses for dac_ad5061_ctrl.sv
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4

    # Read only registers
    ADDR_COMMON_VERSION_ID = REG_WIDTH_BYTES * 0
    AVMM_COMMON_STATUS_NUM_DEVICE_REGS = REG_WIDTH_BYTES * 1
    AVMM_COMMON_STATUS_DEVICE_STATE = REG_WIDTH_BYTES * 2
    AVMM_COMMON_STATUS_PREREQ_MET = REG_WIDTH_BYTES * 3
    AVMM_COMMON_STATUS_COREQ_MET = REG_WIDTH_BYTES * 4
    # Read/write registers
    AVMM_COMMON_CONTROL_PRETEND_UP = REG_WIDTH_BYTES * 5
    AVMM_COMMON_CONTROL_IGNORE_PREREQ = REG_WIDTH_BYTES * 6
    AVMM_COMMON_CONTROL_IGNORE_COREQ = REG_WIDTH_BYTES * 7
    # 8-15 inclusive, reserved
    ADDR_DAC_REG = REG_WIDTH_BYTES * 16
    ADDR_EN_AVMM_CTRL = REG_WIDTH_BYTES * 17


class DACAD5601Avmm:
    """
    An interface to dac_ad5601_ctrl.sv
    """

    module_version = MMIRODesc(
            name="module_version",
            addr=DACAD5601AvmmAddrs.ADDR_COMMON_VERSION_ID,
            msb=31,
            lsb=16
    )

    module_id = MMIRODesc(
            name="module_id",
            addr=DACAD5601AvmmAddrs.ADDR_COMMON_VERSION_ID,
            msb=15,
            lsb=0
    )

    num_device_regs = MMIRODesc(
            name="num_device_regs",
            addr=DACAD5601AvmmAddrs.AVMM_COMMON_STATUS_NUM_DEVICE_REGS
    )

    up = MMIRODescBit(name="up", addr=DACAD5601AvmmAddrs.AVMM_COMMON_STATUS_DEVICE_STATE, bit=0)

    device_reset = MMIRODescBit(
            name="device_reset",
            addr=DACAD5601AvmmAddrs.AVMM_COMMON_STATUS_DEVICE_STATE,
            bit=1
    )

    prereq_met = MMIRODesc(name="prereq_met", addr=DACAD5601AvmmAddrs.AVMM_COMMON_STATUS_PREREQ_MET)

    coreq_met = MMIRODesc(name="coreq_met", addr=DACAD5601AvmmAddrs.AVMM_COMMON_STATUS_COREQ_MET)

    pretend_up = MMIDescBit(
            name="pretend_up",
            addr=DACAD5601AvmmAddrs.AVMM_COMMON_CONTROL_PRETEND_UP,
            bit=0
    )

    ignore_prereq = MMIDesc(
            name="ignore_prereq",
            addr=DACAD5601AvmmAddrs.AVMM_COMMON_CONTROL_IGNORE_PREREQ
    )

    ignore_coreq = MMIDesc(
            name="ignore_coreq",
            addr=DACAD5601AvmmAddrs.AVMM_COMMON_CONTROL_IGNORE_COREQ
    )

    operating_mode = MMIDesc(
            name="dac_operating_mode",
            addr=DACAD5601AvmmAddrs.ADDR_DAC_REG,
            msb=15,
            lsb=14
    )

    data = MMIDesc(name="data", addr=DACAD5601AvmmAddrs.ADDR_DAC_REG, msb=13, lsb=6)

    en_avmm_ctrl = MMIRODescBit(
            name="en_avmm_ctrl",
            addr=DACAD5601AvmmAddrs.ADDR_EN_AVMM_CTRL,
            bit=0
    )

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the aurora_frontend module.
        """
        self.sdr = sdr_host
        self.offset = offset
