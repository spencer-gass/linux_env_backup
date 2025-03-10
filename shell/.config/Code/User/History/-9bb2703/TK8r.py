'''
This module is used to create the guts of an SDR class.
This module must do nothing but return a table (list of lists) where
each row is of the form:
[wrap_name, class, args]

wrap_name: the name prefix for the wrapper. The member variable will be "self._wrap_name".
class: the class to instantiate
*args: arguments to pass to the class constructor

Each row will cause the following to happen:
- The sdr object will get a member variable named "_wrap_name" assigned to
  an object of type 'class'. The arguments, if present, will be passed
  to its constructor.
'''

# pylint: disable=too-many-lines

from enum import IntEnum
from typing import Any, Dict

from kepler.fpga.devices.avmm_addrs_pcuecp import AVMM_OFFSETS  # pylint: disable=unused-import  # will be used when we add devices
from kepler.fpga.devices.avmm_addrs_pcuecp import SYSTEM as AVMM_SYSTEM

from kepler.fpga.devices import aurora_drp
from kepler.fpga.devices import aurora_mmi
from kepler.fpga.devices import avmm_ctrl_shim
from kepler.fpga.devices import avmm_rom
from kepler.fpga.devices import avmm_to_avmm
from kepler.fpga.devices import bb_perf
from kepler.fpga.devices import block_byte_mmi
from kepler.fpga.devices import block_mmi
from kepler.fpga.devices import block_or_bb_traffic_gen
from kepler.fpga.devices import eyescan_drp
from kepler.fpga.devices import git_info_avmm_rom
from kepler.fpga.devices import lmk0482x_mmi
from kepler.fpga.devices import mmi
from kepler.fpga.devices.mmi_legacy_padding import mmi_legacy_entries
# TODO: for mdio, optionally derive a class for DP83826E vendor extensions
from kepler.fpga.devices import mmi_mdio
from kepler.fpga.devices import mmi_regs
from kepler.fpga.devices import mmi_to_mmi
from kepler.fpga.devices import mpsoc_bridge
from kepler.fpga.devices import ppl_ctrl_mmi
from kepler.fpga.devices import prbs_axis_src_sink_mmi
from kepler.fpga.devices import sata_init_ctrl_mmi
from kepler.fpga.devices import sem_ultrascale_avmm
from kepler.fpga.devices import p4_router_avmm
from kepler.fpga.devices import vnp4_avmm
from kepler.fpga.devices import tiny_bcam_avmm
from kepler.fpga.devices import network_packet_generator_avmm

# This MUST match the module/board name.
BOARD_NAME = "pcuecp"

# There is only one ECP variant, so the only board type is the empty string
BOARD_TYPES = set([""])

LOCAL_CONNECTION_TYPE = "pi_avmm"

# There is no secondary ECP
SECONDARY_DICT = {}  # type: Dict[str, Dict[str, Any]]

# Each platform needs to know some information about how to connect to this board.
# There's no way to separate board and platform information completely, because how a board connects
# is platform-specific. If a platform is not listed here, then this board will not be supported
# on that platform. ('dummy', 'pyro', and 'pyro-tunnelled' don't need to be listed)

PLATFORM_CONFIG = {'rpi': {}}  # type: Dict[str, Dict[str, Any]]
PLATFORM_CONFIG['rpi'][''] = {  # The ECP does not have board subtypes
        'spidev': (0,
                   1),
        'qspidev': (0,
                    0),
        'qspidev_spi_kwargs': {
                # ECP requires cpha,cpol == (1,1), TODO: debug why needed
                # TODO: might not actually be necessary: pch_qspi sets both to 0 and has worked
                'cpha': 1,
                'cpol': 1,
        },
        'flash_offsets': {
                '.boot': 0x0,
                '.ub': 0x4040000,
        },
        # Release the blade's PMBus sequencer's reset (active-low reset, so active-high to enable),
        # then power the blade on
        'pwr_gpio': [('direct', 496), ('direct', 23),],
        # As of blade-tester v1, these are controllable by the RPi. Note that these go through an
        # IO expander, but since the Linux driver is configured for it, they appear as direct GPIOs
        'bootmode3': ('direct', 481),
        'bootmode2': ('direct', 482),
        'bootmode1': ('direct', 483),
        'bootmode0': ('direct', 484),
        'por_b': ('direct-od', 485),
        # For setups using the blade tester, ps_done is routed to on-board sequencer
}

MMI_DATA_BYTES = (AVMM_SYSTEM.DATA_LEN + 7) // 8
MMI_ADDR_BYTES = (AVMM_SYSTEM.ADDR_LEN + 7) // 8

# Pre-class configuration

# Nicknames for common boot sources.
BOOT_ALIASES = {
        'jtag': mpsoc_bridge.BootSource.PSJTAG,
        'qspi': mpsoc_bridge.BootSource.QSPI32,
        'sd': mpsoc_bridge.BootSource.SD1,
}


class Bootmode(IntEnum):
    """
    Bootmode pin settings corresponding to different boot sources.
    """
    JTAG = 0
    QSPI = 2  # 32-bit mode
    SD0 = 3
    SD1 = 5
    EMMC = 6

def _create_tiny_bcam_entries():
    CAM_NAMES = [
        'intf_map',
        'lfib',
        'ipv4_fib_ingress',
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
    CAM_KEY_BITS = [
        10,
        20,
        64,
        74,
        58,
        12
    ]
    CAM_ACTION_ID_BITS = [
        2,
        3,
        3,
        2,
        2,
        2
    ]
    CAM_ACTION_PARAM_BITS = [
        46,
        161,
        149,
        14,
        14,
        12
    ]
    CAM_NUM_ROWS = [
        32,
        32,
        32,
        32,
        32,
        32
    ]

# yapf: disable
# pylint: disable=line-too-long

# Layer names and bytes per transfer for the SATA stack
SATA_LAYER_MAP = [("BBA_BLOCK", 4), ("BBA_BYTE", 1), ("BLOCK_TRAFFIC", 4), ("BLOCK_ARB_OUT", 4)]

# Note: A few classes need to refer to other member variables. (For example, SDRController
# needs self._alarm.) Because "self" doesn't exist yet, those have to be set elsewhere.
# That is what post_init is for, below.
CLASS_CONFIG = [
    #[wrap_name,                                class,                                                    args]
    # Note: Put "mmi" first. Everything after that should be alphabetized.
    ["mmi",                                     mmi.MMI,                                                  (AVMM_SYSTEM.ADDR_LEN, AVMM_SYSTEM.DATA_LEN, AVMM_SYSTEM.BYTE_ADDRESSED)],
    ["avmm_rom",                                avmm_rom.AvmmRomMemoryMap,                                (AVMM_OFFSETS.ADDRS_ROM,)],
    ["ctrl",                                    avmm_ctrl_shim.AvmmCtrlShim,                              (AVMM_OFFSETS.ADDRS_ROM,)],
    ["git_info",                                git_info_avmm_rom.GitInfoAvmmRom,                         (AVMM_OFFSETS.GIT_INFO,)],
    *mmi_legacy_entries("ddr",                  mmi_to_mmi.MMItoMMI,                                      (AVMM_OFFSETS.DDR_CTRL, 8, 4)),
    ["ps_bridge",                               avmm_to_avmm.AvmmToAvmm,                                  (AVMM_OFFSETS.PS_MASTER,)],
    ["ps",                                      mpsoc_bridge.MPSoC,                                       (None,),],
    ["sem",                                     sem_ultrascale_avmm.SemAvmm,                              (AVMM_OFFSETS.SEM,)],
    ["p4_router",                               p4_router_avmm.P4RouterAvmm,                              (AVMM_OFFSETS.P4_ROUTER,)],
    ["vnp4",                                    vnp4_avmm.VNP4Avmm,                                       (AVMM_OFFSETS.VNP4)],
    ["vnp4_intf_map",                           tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0x2000, 10, 2, 46, 32)],
    ["vnp4_lfib",                               tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0x4000, 20, 3, 161, 32)],
    ["vnp4_ipv4_fib_ingress",                   tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0x6000, 64, 3, 149, 32)],
    ["vnp4_cmp_ipv4_fib",                       tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0x8000, 74, 2, 14, 32)],
    ["vnp4_cmp_mac_fib",                        tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0xA000, 58, 2, 14, 32)],
    ["vnp4_vlan_map",                           tiny_bcam_avmm.TinyBcamAvmm,                              (AVMM_OFFSETS.VNP4 + 0xC000, 12, 2, 12, 32)],
    ["pkt_gen",                                 network_packet_generator_avmm.NetworkPacketGeneratorAvmm, (AVMM_OFFSETS.PKT_GEN,)],
    *mmi_legacy_entries("ppl_aur_ctrl",         aurora_mmi.AuroraMMI,                                     (AVMM_OFFSETS.PPL_AUR_CTRL,)),
    *mmi_legacy_entries("ppl_aur_drp",          aurora_drp.AuroraDRP,                                     (AVMM_OFFSETS.PPL_AUR_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4, 156.25e6)),
    *mmi_legacy_entries("ppl_ctrl",             ppl_ctrl_mmi.PPLControl,                                  (AVMM_OFFSETS.PPL_CTRL,)),
    *mmi_legacy_entries("ppl_prbs",             prbs_axis_src_sink_mmi.PrbsAxisSrcSink,                   (AVMM_OFFSETS.PPL_PRBS,)),
    *mmi_legacy_entries("sata_init",            sata_init_ctrl_mmi.SATAInitCtrl,                          (AVMM_OFFSETS.SATA_INIT_CTRL,)),
    *mmi_legacy_entries("sata0bb",              block_byte_mmi.BlockByte,                                 (AVMM_OFFSETS.SATA0_CTRL, "sata0bb")),
    *mmi_legacy_entries("sata1bb",              block_byte_mmi.BlockByte,                                 (AVMM_OFFSETS.SATA1_CTRL, "sata1bb")),
    *mmi_legacy_entries("sata2bb",              block_byte_mmi.BlockByte,                                 (AVMM_OFFSETS.SATA2_CTRL, "sata2bb")),
    *mmi_legacy_entries("sata0bl",              block_mmi.Block,                                          (AVMM_OFFSETS.SATA0_CTRL, "sata0bl")),
    *mmi_legacy_entries("sata1bl",              block_mmi.Block,                                          (AVMM_OFFSETS.SATA1_CTRL, "sata1bl")),
    *mmi_legacy_entries("sata2bl",              block_mmi.Block,                                          (AVMM_OFFSETS.SATA2_CTRL, "sata2bl")),
    *mmi_legacy_entries("sata0drp",             eyescan_drp.EyescanDRP,                                   (AVMM_OFFSETS.SATA0_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4, 156.25e6)),
    *mmi_legacy_entries("sata1drp",             eyescan_drp.EyescanDRP,                                   (AVMM_OFFSETS.SATA1_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4, 156.25e6)),
    *mmi_legacy_entries("sata2drp",             eyescan_drp.EyescanDRP,                                   (AVMM_OFFSETS.SATA2_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4, 156.25e6)),
    *mmi_legacy_entries("sata0perf",            bb_perf.BBPerf,                                           (AVMM_OFFSETS.SATA0_PERF, SATA_LAYER_MAP,)),
    *mmi_legacy_entries("sata1perf",            bb_perf.BBPerf,                                           (AVMM_OFFSETS.SATA1_PERF, SATA_LAYER_MAP,)),
    *mmi_legacy_entries("sata2perf",            bb_perf.BBPerf,                                           (AVMM_OFFSETS.SATA2_PERF, SATA_LAYER_MAP,)),
    *mmi_legacy_entries("sata0blocktraffic",    block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (AVMM_OFFSETS.SATA0_BLOCK_TRAFFIC,)),
    *mmi_legacy_entries("sata0bytetraffic",     block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (AVMM_OFFSETS.SATA0_BYTE_TRAFFIC,)),
    *mmi_legacy_entries("sgmii_phy_mdio",       mmi_mdio.MmiMdioCommon,                                   (AVMM_OFFSETS.SGMII_PHY_MDIO, 0x00)),
    *mmi_legacy_entries("sgmii_mac_drp",        eyescan_drp.EyescanDRP,                                   (AVMM_OFFSETS.SGMII_MAC_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4, 156.25e6)),
    *mmi_legacy_entries("sgmii_mac_mdio",       mmi_mdio.MmiMdioCommon,                                   (AVMM_OFFSETS.SGMII_MAC_MDIO, 0x00)),
    *mmi_legacy_entries("ecp_fe_clk",           lmk0482x_mmi.LMK0482X,                                    (AVMM_OFFSETS.LMKCLK,)),
]

# yapf: enable


def post_init(self):
    # pylint: disable=protected-access,no-self-use,unused-argument
    '''
    post_init is also run during the SDR class constructor.
    This happens after all variables from CLASS_CONFIG have been created.
    '''
    self._ddr.set_mmi_bridge(self._legacy_bridge_ddr)
    self._ppl_aur_ctrl.set_mmi_bridge(self._legacy_bridge_ppl_aur_ctrl)
    self._ppl_aur_drp.set_mmi_bridge(self._legacy_bridge_ppl_aur_drp)
    self._ppl_ctrl.set_mmi_bridge(self._legacy_bridge_ppl_ctrl)
    self._ppl_prbs.set_mmi_bridge(self._legacy_bridge_ppl_prbs)
    self._ps.set_mmi_bridge(self._ps_bridge, 0)
    self._sata_init.set_mmi_bridge(self._legacy_bridge_sata_init)
    self._sata0bb.set_mmi_bridge(self._legacy_bridge_sata0bb)
    self._sata1bb.set_mmi_bridge(self._legacy_bridge_sata1bb)
    self._sata2bb.set_mmi_bridge(self._legacy_bridge_sata2bb)
    self._sata0bl.set_mmi_bridge(self._legacy_bridge_sata0bl)
    self._sata1bl.set_mmi_bridge(self._legacy_bridge_sata1bl)
    self._sata2bl.set_mmi_bridge(self._legacy_bridge_sata2bl)
    self._sata0drp.set_mmi_bridge(self._legacy_bridge_sata0drp)
    self._sata1drp.set_mmi_bridge(self._legacy_bridge_sata1drp)
    self._sata2drp.set_mmi_bridge(self._legacy_bridge_sata2drp)
    self._sata0perf.set_mmi_bridge(self._legacy_bridge_sata0perf)
    self._sata1perf.set_mmi_bridge(self._legacy_bridge_sata1perf)
    self._sata2perf.set_mmi_bridge(self._legacy_bridge_sata2perf)
    self._sata0blocktraffic.set_mmi_bridge(self._legacy_bridge_sata0blocktraffic)
    self._sata0bytetraffic.set_mmi_bridge(self._legacy_bridge_sata0bytetraffic)
    self._sgmii_phy_mdio.set_mmi_bridge(self._legacy_bridge_sgmii_phy_mdio)
    self._sgmii_mac_drp.set_mmi_bridge(self._legacy_bridge_sgmii_mac_drp)
    self._sgmii_mac_mdio.set_mmi_bridge(self._legacy_bridge_sgmii_mac_mdio)
    self._ecp_fe_clk.set_mmi_bridge(self._legacy_bridge_ecp_fe_clk)
