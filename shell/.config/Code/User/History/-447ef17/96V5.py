"""
Python interface to both dvbs2x_tx_symb_rate_divider
"""

import logging

from enum import IntEnum

from kepler.fpga.devices.mmi import MMIDesc, MMIRODesc

logger = logging.getLogger(__name__)


class Dvbs2xTxSymbRateAvmmAddrs(IntEnum):
    """
    AVMM register addresses for dvbs2x_tx_symb_rate_divider
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4

    ADDR_TX_SYMB_RATE_SEL = REG_WIDTH_BYTES * 16
    ADDR_TX_SYMB_RATE_DIV = REG_WIDTH_BYTES * 17


class Dvbs2xTxSymbRateAvmm():
    """
    An interface to dvbs2x_tx_symb_rate_divider.
    """

    _symb_rate_sel = MMIDesc(
            name="_symb_rate_sel",
            addr=Dvbs2xTxSymbRateAvmmAddrs.ADDR_TX_SYMB_RATE_SEL,
            msb=1,
            lsb=0
    )

    _symb_rate_div = MMIRODesc(
            name="_symb_rate_div",
            addr=Dvbs2xTxSymbRateAvmmAddrs.ADDR_TX_SYMB_RATE_DIV
    )

    def __init__(self, sdr_host, offset):
        """
        Args:
            sdr_host (SDR): The SDR object on which we're performing MMI commands.
            offset (int): The base address for the dvbs2x_tx_symb_rate_divider module AVMM slave
        """
        self.sdr = sdr_host
        self.offset = offset

    @property
    def factor_list(self):
        symb_rate_div = self._symb_rate_div
        return [1 / (4 * symb_rate_div), 1 / (2 * symb_rate_div), 1 / symb_rate_div]

    @property
    def factor(self):
        """
        Returns:
            float: Current TX symbol rate as a factor of the max_sample_rate/symbol_rate_div
        """
        return self.factor_list[self._symb_rate_sel]

    @factor.setter
    def factor(self, rate_factor):
        """
        Args:
            rate_factor (int): the TX rate as a factor of max symbol rate. Possible
                options defined by factor_list
        Raises:
            ValueError: If the selected TX symbol rate is not in the factor_list
        """
        if rate_factor not in self.factor_list:
            raise ValueError("TX symbol rate must be in factor_list: " + str(self.factor_list))
        self._symb_rate_sel = self.factor_list.index(rate_factor)
