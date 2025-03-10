"""
Python interface to Vitis Networking P4 lookup tables.
"""

import logging

import time

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
        self.num_rows = 32

    # Offset Configuration

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

    # CAM Configuration

    def _validate_row_id(self, row_id):
        if row_id < 0 or row_id >= self.num_rows:
            raise ValueError(
                    "Row index %d is out of bounds, must lie between 0 and %d." %
                    (row_id,
                     self.num_rows)
            )

    def _validate_table_id(self, table_id):
        if table_id < 0 or table_id >= VNP4AvmmAddrs.NUM_CAMS:
            raise ValueError(
                    "Table index %d is out of bounds, must lie between 0 and %d." %
                    (tabe_id,
                     VNP4AvmmAddrs.NUM_CAMS)
            )

    def _read_table_row(self, table_id row_id, timeout_s=0.01):
        """
        Read back a row of the table and return the raw values.
        Params:
            table_id (int): Table index to read.
            row_id (int): Row index to read.
            timeout_s (float): Max number of seconds to allow for a read to complete.
        Returns:
            int: Key read from the row.
            int: Action ID read from the row.
            int: Action params read from the row.
        Raises:
            ValueError: If the row index is out of bounds.
            TimeoutError: If the read does not complete in timeout_s seconds.
        """
        self._validate_row_id(row_id)
        self._validate_table_id(table_id)

        # Initiate a read
        self.entry_id[table_id] = row_id
        self.rd_flag[table_id] = 1

        # Poll for rd_flag to go low, indicating that the read has completed
        read_success = 0
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.rd_flag[table_id] == 0:
                read_success = 1
                break

        if not read_success:
            raise TimeoutError("CAM read took more than %f seconds." % timeout_s)

        # Read back key
        key = self.sdr.mmi_mw_read(
                self.offset + TINY_CAM.CAM_DATA0,
                self.words_per_key,
                big_endian=BIG_ENDIAN
        ) & (2**(self.key_bits) - 1)

        # Read back action
        value = self.sdr.mmi_mw_read(
                self.offset + TINY_CAM.CAM_DATA0 + self.value_offset,
                self.words_per_value,
                big_endian=BIG_ENDIAN
        )
        action_id = value & (2**self.action_id_bits - 1)
        action_params = (value >> self.action_id_bits) & (2**self.action_param_bits - 1)

        return key, action_id, action_params

    def _write_table_row(self, table_id row_id, key, action_id, action_params, timeout_s=0.01):
        """
        Write a row of the table.
        Params:
            table_id (int): table index to write to.
            row_id (int): Row index to write to.
            key (int): Key to write to the row.
            action_id (int): Index of the action associated with this key.
            action_params (int): Parameters to pass to the action associated with this key.
            timeout_s (float): Max number of seconds to allow for a write to complete.
        Raises:
            ValueError: If the row index is out of bounds or row_value is not the correct length.
            RuntimeError: If the row is already occupied.
            TimeoutError: If the write does not complete in timeout_s seconds.
        """
        self._validate_row_id(row_id)
        self._validate_table_id(table_id)

        # Check if this entry is already occupied
        self.entry_id[table_id] = row_id
        self.rd_flag[table_id] = 1
        if self.entry_in_use[table_id]:
            raise RuntimeError("Table entry %d is already occupied!" % row_id)

        # Set the key
        self.sdr.mmi_mw_write(
                self.offset + TINY_CAM.CAM_DATA0,
                self.words_per_key,
                key,
                big_endian=BIG_ENDIAN
        )

        # Set the value: action ID and parameters
        value = (action_params << self.action_id_bits) | action_id
        self.sdr.mmi_mw_write(
                self.offset + TINY_CAM.CAM_DATA0 + self.value_offset,
                self.words_per_value,
                value,
                big_endian=BIG_ENDIAN
        )

        # Write the row
        self.entry_in_use[table_id] = 1
        self.wr_flag[table_id] = 1

        # Poll for wr_flag to go low, indicating that the write has completed
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.wr_flag == 0:
                return

        # If we reach this point, the write timed out
        raise TimeoutError("CAM write took more than %f seconds." % timeout_s)

    def _clear_table_row(self, table_id, row_id, timeout_s=0.01):
        """
        Clear a row of the table.
        Params:
            table_id (int): Table index to clear.
            row_id (int): Row index to clear.
            timeout_s (float): Max number of seconds to allow for a write to complete.
        Raises:
            ValueError: If the row index is out of bounds, or if the row is already unoccupied.
            TimeoutError: If the write does not complete in timeout_s seconds.
        """
        self._validate_row_id(row_id)
        self._validate_table_id(table_id)

        # Check if this entry is already occupied
        self.entry_id[table_id] = row_id
        self.rd_flag[table_id] = 1
        if not self.entry_in_use[table_id]:
            raise ValueError("Table entry %d is not already occupied!" % row_id)

        self.entry_in_use[table_id] = 0

        # Issue a write to clear the entry
        self.wr_flag[table_id] = 1
        # Poll for wr_flag to go low, indicating that the read has completed
        t_start = time.monotonic()
        while time.monotonic() - t_start < timeout_s:
            if self.wr_flag[table_id] == 0:
                return

        # If we reach this point, the write timed out
        raise TimeoutError("CAM write took more than %f seconds." % timeout_s)
