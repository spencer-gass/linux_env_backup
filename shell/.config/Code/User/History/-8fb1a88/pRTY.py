"""
Python interface to Vitis Networking P4 Configuration Registers
"""

import logging

from enum import IntEnum

from kepler.fpga.devices.avmm_common import AvmmCommonCtrl

# Uses MMI descriptors even though it is AVMM because we wrote a
# temporary adapter in the underlying Python.
from kepler.fpga.devices.mmi import MMIRODesc, MMIRODescBit

logger = logging.getLogger(__name__)


class VNP4AvmmAddrs(IntEnum):
    """
    AVMM register addresses for Vitis Networking P4 Configuration Registers
    """

    # Registers are 32 bits wide.
    REG_WIDTH_BYTES = 4

    ADDR_VERSION = REG_WIDTH_BYTES * 0
    ADDR_INST_CONFG = REG_WIDTH_BYTES * 1
    ADDR_ECC_CONFIG_IP = REG_WIDTH_BYTES * 2


class VNP4Avmm(AvmmCommonCtrl):
    """
    An interface to Vitis Networking P4 Configuration Registers
    """

    ip_core_revision = MMIRODesc(
            name="ip_core_revision",
            addr=VNP4AvmmAddrs.ADDR_VERSION,
            msb=23,
            lsb=16
    )

    ip_core_minor_version = MMIRODesc(
            name="num_eip_core_minor_versiongr_phys_ports",
            addr=VNP4AvmmAddrs.ADDR_VERSION,
            msb=15,
            lsb=8
    )

    ip_core_major_version = MMIRODesc(
            name="ip_core_major_version",
            addr=VNP4AvmmAddrs.ADDR_VERSION,
            msb=7,
            lsb=0
    )

    axis_clock_mhz = MMIRODesc(
            name="axis_clock_mhz",
            addr=VNP4AvmmAddrs.ADDR_INST_CONFG,
            msb=29,
            lsb=20
    )

    cam_clock_mhz = MMIRODesc(
            name="cam_clock_mhz",
            addr=VNP4AvmmAddrs.ADDR_INST_CONFG,
            msb=19,
            lsb=10
    )

    packet_rate_mpps = MMIRODesc(
            name="packet_rate_mpps",
            addr=VNP4AvmmAddrs.ADDR_INST_CONFG,
            msb=9,
            lsb=0
    )

    packet_fifo_ecc_1bit_error = MMIRODescBit(
            name="packet_fifo_ecc_1bit_error",
            addr=VNP4AvmmAddrs.ADDR_ECC_CONFIG_IP,
            bit=0
    )

    packet_fifo_ecc_2bit_error = MMIRODescBit(
            name="packet_fifo_ecc_2bit_error",
            addr=VNP4AvmmAddrs.ADDR_ECC_CONFIG_IP,
            bit=1
    )

    metadata_fifo_ecc_1bit_error = MMIRODescBit(
            name="metadata_fifo_ecc_1bit_error",
            addr=VNP4AvmmAddrs.ADDR_ECC_CONFIG_IP,
            bit=2
    )

    metadata_fifo_ecc_2bit_error = MMIRODescBit(
            name="metadata_fifo_ecc_2bit_error",
            addr=VNP4AvmmAddrs.ADDR_ECC_CONFIG_IP,
            bit=3
    )

    def print_config(self):
        """
            Prints formatted config registers
        """
        print("Revision:                {:X}".format(self.ip_core_revision))
        print("Major Version:           {:X}".format(self.ip_core_major_version))
        print("Minor Version:           {:X}".format(self.ip_core_minor_version))
        print("AXIS Clock (MHz):        {:d}".format(self.axis_clock_mhz))
        print("CAM Clock (MHz):         {:d}".format(self.cam_clock_mhz))
        print("Packet Rate (Mpkts/s):   {:d}".format(self.packet_rate_mpps))

        if self.packet_fifo_ecc_2bit_error:
            print("Packet FIFO ECC double-bit error functionality.")
        elif self.packet_fifo_ecc_1bit_error:
            print("Packet FIFO ECC single-bit error functionality.")

        if self.metadata_fifo_ecc_2bit_error:
            print("Metadata FIFO ECC double-bit error functionality.")
        elif self.metadata_fifo_ecc_1bit_error:
            print("Metadata FIFO ECC single-bit error functionality.")
