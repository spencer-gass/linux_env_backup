"""
Python interface to dac_ad5601_ctrl_mmi
"""

import logging

from kepler.fpga.devices.mmi import MMIDesc, MMIRODesc, MMIRODescBit
from kepler.fpga.devices.mmi_regs import DAC_AD5601_CTRL_MMI as DACAD5601MMIAdders

logger = logging.getLogger(__name__)


class DACAD5601MMI:
    """
    An interface to dac_ad5601_ctrl_mmi.sv
    """

    module_id = MMIRODesc(
            name="module_id",
            addr=DACAD5601MMIAdders.ADDR_MODULE_ID,
    )

    module_version = MMIRODesc(
            name="module_version",
            addr=DACAD5601MMIAdders.ADDR_MODULE_VERSION
    )

    operating_mode = MMIDesc(
            name="dac_operating_mode",
            addr=DACAD5601MMIAdders.ADDR_DAC_REG,
            msb=15,
            lsb=14
    )

    dac_data = MMIDesc(name="dac_data", 
            addr=DACAD5601MMIAdders.ADDR_DAC_REG, 
            msb=13, 
            lsb=6
    )

    en_mmi_ctrl = MMIRODescBit(
            name="en_avmm_ctrl",
            addr=DACAD5601MMIAdders.ADDR_EN_MMI_CTRL,
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
