"""
Python interface to dvbs2x_tx_symb_rate_divider_mmi
"""

import logging

from kepler.fpga.devices.mmi import MMIDesc
from kepler.fpga.devices.mmi_regs import DVBS2X_TX_SYMB_RATE_DIVIDER as Dvbs2xTxSymbRateAddrs

logger = logging.getLogger(__name__)


class Dvbs2xTxSymbRateMmi():
    """
    An interface to dvbs2x_tx_symb_rate_divider_mmi.
    """

    symb_rate_sel = MMIDesc(
            name="_symb_rate_sel",
            addr=Dvbs2xTxSymbRateAddrs.ADDR_SYM_RATE_SEL,
            msb=1,
            lsb=0
    )

    symb_rate_div = MMIDesc(name="_symb_rate_div", addr=Dvbs2xTxSymbRateAddrs.ADDR_SYM_RATE)

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the dvbs2x_tx_symb_rate_divider module AVMM slave
        """
        self.sdr = sdr_host
        self.offset = offset
