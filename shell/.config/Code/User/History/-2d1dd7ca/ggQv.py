"""
Python interface to Xilinx TinyBCAM IP.
"""

import logging

import time

from enum import IntEnum

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit, MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)

# TODO(sgass): This class assumes that multi-word keys/values are big endian, but the
# documentation is unclear and it has not been tested in hardware. Confirm this whenever it comes
# time to use a TinyBCAM with a multi-word key/value.
BIG_ENDIAN = True


class TinyBcamAvmmAddrs(IntEnum):
    """
    AVMM register addresses for Xilinx Tiny BCAM IP
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


class TinyBcamAvmm(AvmmCommonCtrl):
    """
    An interface to Xilinx Tiny BCAM IP
    """

    cam_ctrl = MMIDesc(name="cam_ctrl", addr=TinyBcamAvmmAddrs.CAM_CTRL)
    rd_flag = MMIDescBit(
            name="rd_flag",
            addr=TinyBcamAvmmAddrs.CAM_CTRL,
            bit=TinyBcamAvmmAddrs.CTRL_RD_BIT
    )
    wr_flag = MMIDescBit(
            name="wr_flag",
            addr=TinyBcamAvmmAddrs.CAM_CTRL,
            bit=TinyBcamAvmmAddrs.CTRL_WR_BIT
    )
    reset = MMIDescBit(
            name="reset",
            addr=TinyBcamAvmmAddrs.CAM_CTRL,
            bit=TinyBcamAvmmAddrs.CTRL_RST_BIT
    )
    entry_in_use = MMIDescBit(
            name="entry_in_use",
            addr=TinyBcamAvmmAddrs.CAM_CTRL,
            bit=TinyBcamAvmmAddrs.CTRL_ENTRY_IN_USE_BIT
    )

    entry_id = MMIDesc(name="entry_id", addr=TinyBcamAvmmAddrs.CAM_ENTRY_ID)
    emulation_mode = MMIDesc(name="emulation_mode", addr=TinyBcamAvmmAddrs.CAM_EMULATION_MODE)
    lookup_count = MMIDesc(name="lookup_count", addr=TinyBcamAvmmAddrs.CAM_LOOKUP_COUNT)
    hit_count = MMIDesc(name="hit_count", addr=TinyBcamAvmmAddrs.CAM_HIT_COUNT)
    miss_count = MMIDesc(name="miss_count", addr=TinyBcamAvmmAddrs.CAM_MISS_COUNT)

    def __init__(self, sdr_host, offset, key_bits, action_id_bits, action_param_bits, num_rows):
        self.sdr = sdr_host
        self.offset = offset

        self.key_bits = key_bits
        # Rounding up
        self.words_per_key = (key_bits + 31) // 32
        # The action ID and params must be written to the registers starting from
        # TinyBcamAvmmAddrs.CAM_DATA0 + 2*words_per_key, where the factor of 2 comes from
        # leaving room for both the key and the mask (which is unused in the BCAM,
        # as opposed to TCAM)
        self.value_offset = 2 * self.words_per_key

        self.action_id_bits = action_id_bits
        self.action_param_bits = action_param_bits
        # Rounding up
        self.words_per_value = (action_id_bits + action_param_bits + 31) // 32

        self.num_rows = num_rows

    def _validate_row_idx(self, row_idx):
        if row_idx < 0 or row_idx >= self.num_rows:
            raise ValueError(
                    "Row index %d is out of bounds, must lie between 0 and %d." %
                    (row_idx,
                     self.num_rows)
            )

    def read_table_row(self, row_idx, timeout_s=0.01):
        """
        Read back a row of the table and return the raw values.
        Params:
            row_idx (int): Row index to read.
            timeout_s (float): Max number of seconds to allow for a read to complete.
        Returns:
            int: Key read from the row.
            int: Action ID read from the row.
            int: Action params read from the row.
        Raises:
            ValueError: If the row index is out of bounds.
            TimeoutError: If the read does not complete in timeout_s seconds.
        """
        self._validate_row_idx(row_idx)

        # Initiate a read
        self.entry_id = row_idx
        self.rd_flag = 1

        # Poll for rd_flag to go low, indicating that the read has completed
        read_success = 0
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.rd_flag == 0:
                read_success = 1
                break

        if not read_success:
            raise TimeoutError("CAM read took more than %f seconds." % timeout_s)

        # Read back key
        key = self.sdr.mmi_mw_read(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0,
                self.words_per_key,
                big_endian=BIG_ENDIAN
        ) & (2**(self.key_bits) - 1)

        # Read back action
        value = self.sdr.mmi_mw_read(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0 + self.value_offset,
                self.words_per_value,
                big_endian=BIG_ENDIAN
        )
        action_id = value & (2**self.action_id_bits - 1)
        action_params = (value >> self.action_id_bits) & (2**self.action_param_bits - 1)

        return key, action_id, action_params

    def write_table_row(self, row_idx, key, action_id, action_params, timeout_s=0.01):
        """
        Write a row of the table.
        Params:
            row_idx (int): Row index to write to.
            key (int): Key to write to the row.
            action_id (int): Index of the action associated with this key.
            action_params (int): Parameters to pass to the action associated with this key.
            timeout_s (float): Max number of seconds to allow for a write to complete.
        Raises:
            ValueError: If the row index is out of bounds or row_value is not the correct length.
            RuntimeError: If the row is already occupied.
            TimeoutError: If the write does not complete in timeout_s seconds.
        """
        self._validate_row_idx(row_idx)

        # Check if this entry is already occupied
        self.entry_id = row_idx
        self.rd_flag = 1
        if self.entry_in_use:
            raise RuntimeError("Table entry %d is already occupied!" % row_idx)

        # Set the key
        self.sdr.mmi_mw_write(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0,
                self.words_per_key,
                key,
                big_endian=BIG_ENDIAN
        )

        # Set the value: action ID and parameters
        value = (action_params << self.action_id_bits) | action_id
        self.sdr.mmi_mw_write(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0 + self.value_offset,
                self.words_per_value,
                value,
                big_endian=BIG_ENDIAN
        )

        # Write the row
        self.entry_in_use = 1
        self.wr_flag = 1

        # Poll for wr_flag to go low, indicating that the write has completed
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.wr_flag == 0:
                return

        # If we reach this point, the write timed out
        raise TimeoutError("CAM write took more than %f seconds." % timeout_s)

    def clear_table_row(self, row_idx, timeout_s=0.01):
        """
        Clear a row of the table.
        Params:
            row_idx (int): Row index to clear.
            timeout_s (float): Max number of seconds to allow for a write to complete.
        Raises:
            ValueError: If the row index is out of bounds, or if the row is already unoccupied.
            TimeoutError: If the write does not complete in timeout_s seconds.
        """
        self._validate_row_idx(row_idx)

        # Check if this entry is already occupied
        self.entry_id = row_idx
        self.rd_flag = 1
        if not self.entry_in_use:
            raise ValueError("Table entry %d is not already occupied!" % row_idx)

        self.entry_in_use = 0

        # Issue a write to clear the entry
        self.wr_flag = 1
        # Poll for wr_flag to go low, indicating that the read has completed
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.wr_flag == 0:
                return

        # If we reach this point, the write timed out
        raise TimeoutError("CAM write took more than %f seconds." % timeout_s)
