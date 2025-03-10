"""
Python interface to Xilinx TinyBCAM IP.
"""

import logging

import time

from enum import IntEnum

import yaml

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIDesc, MMIDescBit

logger = logging.getLogger(__name__)

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

    CTRL_RD_BIT = 0
    CTRL_WR_BIT = 1
    CTRL_RST_BIT = 2
    CTRL_ENTRY_IN_USE_BIT = 31


def bits_to_bytes(bits):
    return (bits + 7) / 8


def bytes_to_words(bytes):
    return (bytes + TinyBcamAvmmAddrs.REG_WIDTH_BYTES - 1) // TinyBcamAvmmAddrs.REG_WIDTH_BYTES


def cat_fields(fields):
    '''
    Args:
        fields (list of dicts): list of dict where each dict had a "bits" and "value" field
    '''
    value = 0
    for f in fields:
        value = (value << f["bits"]) | f["value"]
    return value


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

    def __init__(
            self,
            sdr_host,
            offset,
            table_name,
            key_bits,
            action_id_bits,
            action_param_bits,
            num_rows
    ):
        """
        TinyBCAM constructor
        Params:
            sdr_host (sdr)
            offset (int): base address
            table_name (str): table name, used to import appropriate config from yaml load
            key_bits (int): number of bits in the key
            action_id_bits (int): number of bits in the action id
            action_param_bits (int): number of bits in each action param
            num_row (int): number of table entries
        """
        super().__init__(sdr_host, offset)

        self.table_name = table_name
        self.key_bits = key_bits
        self.bytes_per_key = bits_to_bytes(key_bits)
        self.words_per_key = bytes_to_words(self.bytes_per_key)
        # TinyBCAM register data registers starting from data0 consists of
        # KEY_BYTES of key, KEY_BYTES of read-only mask which in the TinyBCAM case is
        # all ones, action_id, action_params
        self.value_byte_offset = 2 * self.byte_per_key
        self.value_word_offset = 2 * self.value_byte_offset // TinyBcamAvmmAddrs.REG_WIDTH_BYTES
        self.action_id_bits = action_id_bits
        self.action_param_bits = action_param_bits
        self.bytes_per_value = bits_to_bytes(action_id_bits + action_param_bits)
        self.words_per_value = bytes_to_words(self.bytes_per_value)
        self.bytes_per_entry = (2 * self.bytes_per_key + self.bytes_per_value)
        self.words_per_entry = bytes_to_words(self.bytes_per_entry)
        self.num_rows = num_rows

    def print_config(self):
        """
            Print object configuration.
        """
        print(f"Offset:            {self.offset:X}")
        print(f"Key Bits:          {self.key_bits:d}")
        print(f"Action ID Bits:    {self.action_id_bits:d}")
        print(f"Action Param Bits: {self.action_param_bits:d}")
        print(f"Number of Rows:    {self.num_rows:d}")

    def _validate_row_idx(self, row_idx):
        if row_idx < 0 or row_idx >= self.num_rows:
            raise ValueError(
                    "Row index %d is out of bounds, must lie between 0 and %d." %
                    (row_idx,
                     self.num_rows)
            )

    def _foramt_entry(self, key, action_id, action_params):
        value = (action_params << self.action_id_bits) | action_id
        entry = (value << (2 * self.byte_per_key * 8)) | key
        return entry

    def _decode_entry(self, entry):
        key = entry & 2**self.key_bits - 1
        entry = entry >> (2 * self.bytes_per_key * 8)
        action_id = entry & 2**self.action_id_bits - 1
        entry = entry >> self.action_id_bits
        action_params = entry & 2**self.action_param_bits - 1
        return [key, action_id, action_params]

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
        entry = self.sdr.mmi_mw_read(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0,
                self.words_per_entry,
                big_endian=BIG_ENDIAN
        )

        key, action_id, action_params = self._decode_entry(entry)

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

        # Set entry data
        self.sdr.mmi_mw_write(
                self.offset + TinyBcamAvmmAddrs.CAM_DATA0,
                self.words_per_entry,
                self._foramt_entry(key,
                                   action_id,
                                   action_params),
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

    def load_config_from_dict(self, dict):
        '''
        Args:
            dict (dict): configuration dictionary from yaml parser
        '''
        for row_idx in range(self.num_rows):
            self.clear_table_row(row_idx)
        for row_idx, entry_dict in enumerate(dict):
            action_params = cat_fields(reversed(entry_dict["action_params"]))
            key = cat_fields(entry_dict["keys"])
            self.write_table_row(
                    row_idx,
                    key,
                    entry_dict["action_id"]["value"],
                    action_params,
            )

    def load_cam_config_from_yaml(self, fname):
        '''
        Args:
            fname (str): file name to read config from
        '''
        with open(fname, 'r', encoding="utf-8") as file:
            cam_config_dict = yaml.safe_load(file)
        if self.table_name not in cam_config_dict.keys():
            raise Exception(f"{self.table_name} wasn't found in yaml config.")
        self.load_config_from_dict(cam_config_dict[self.table_name])


def create_cam_config_yaml_template(fname):
    """
    Args:
        fname (str): file to write template to.
    """
    cam_config = '''
intf_map:
  - keys:
    - name: ingres_port
      value: 1
      bits: 10
    action_id:
      value : 0
      bits: 2
    action_params:
    - name: vrf_id
      value: 0x00000001
      bits: 32
    - name: vlan_id
      value: 0x064
      bits: 12
  - keys:
    - name: ingres_port
      value: 2
      bits: 10
    action_id:
      value : 0
      bits: 2
    action_params:
    - name: vrf_id
      value: 0x00000002
      bits: 32
    - name: vlan_id
      value: 0x065
      bits: 12
lfib
  - keys:
    - name: mpls_label
      value: 0x12345
      bits: 20
    action_id:
      value: 0
      bits: 3
    action_params:
    - name: mpls_label
      value: 0xAABBC
      bits: 20
    - name: mac_sa
      value: 0x303030303030
      bits: 48
    - name: mac_da
      value: 0x404040404040
      bits: 48
    - name: vrf_id
      value: 0x00000001
      bits: 32
    - name: egress_port
      value: 1
      bits: 10
  - keys:
    - name: mpls_label
      value: 0x6789A
      bits: 20
    action_id:
      value: 0
      bits: 3
    action_params:
    - name: mpls_label
      value: 0x11223
      bits: 20
    - name: mac_sa
      value: 0x505050505050
      bits: 48
    - name: mac_da
      value: 0x606060606060
      bits: 48
    - name: vrf_id
      value: 0x00000002
      bits: 32
    - name: egress_port
      value: 2
      bits: 10
ipv4_fib_ingress
  - keys:
    - name: ip_da
      value: 0xC0A80001
      bits: 32
    - name: vrf_id
      value: 0x00000001
      bits: 32
    action_id:
      value: 0
      bits: 3
    action_params:
    - name: mac_sa
      value: 0x303030303030
      bits: 48
    - name: mac_da
      value: 0x404040404040
      bits: 48
    - name: egress_port
      value: 1
      bits: 10
  - keys:
    - name: ip_da
      value: 0xC0A80001
      bits: 32
    - name: vrf_id
      value: 0x00000002
      bits: 32
    action_id:
      value: 0
      bits: 3
    action_params:
    - name: mac_sa
      value: 0x505050505050
      bits: 48
    - name: mac_da
      value: 0x606060606060
      bits: 48
    - name: egress_port
      value: 2
      bits: 10
cmp_ipv4_fib
  - keys:
    - name: ingress_port
      value: 1
      bits: 10
    - name: ip_da
      value: 0xC0A80001
      bits: 32
    - name: vrf
      value: 0x00000001
      bits: 32
    action_id:
      value: 0
      bits: 2
    action_params:
    - name: vlan_id
      value: 0x064
      bits: 12
cmp_mac_fib
  - keys:
    - name: ingress_port
      value: 1
      bits: 10
    - name: mac_da
      value: 0x101111111111
      bits: 48
    action_id:
      value: 0
      bits: 2
    action_params:
    - name: vlan_id
      value: 0x064
      bits: 12
vlan_map
  - keys:
    - name: vlan_id
      value: 0x064
      bits: 12
    action_id:
      value:
      bits: 2
    action_params:
    - name: egress_port
      value: 1
      bits: 10

'''
    with open(fname, 'w', encoding="utf-8") as file:
        file.write(cam_config)
