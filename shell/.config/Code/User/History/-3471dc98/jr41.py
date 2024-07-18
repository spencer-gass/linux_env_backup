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

from collections import namedtuple
from enum import IntEnum
from typing import Any, Dict, List, Union

from kepler.fpga.devices.mmi_addrs_hsd import MMI_OFFSETS
from kepler.fpga.devices.mmi_addrs_hsd import SYSTEM as MMI_SYSTEM

from kepler.fpga.devices import ads1015_mmi
from kepler.fpga.devices import ads1118_mmi
from kepler.fpga.devices import agc_mmi
from kepler.fpga.devices import all_cpms
from kepler.fpga.devices import axis_profile_mmi
from kepler.fpga.devices import axis_sample_complex_filter
from kepler.fpga.devices import axi_to_mmi
from kepler.fpga.devices import bb_copier_mmi
from kepler.fpga.devices import bb_dbuf
from kepler.fpga.devices import bb_perf
from kepler.fpga.devices import block_or_bb_traffic_gen
from kepler.fpga.devices import block_byte_mmi
from kepler.fpga.devices import block_mmi
from kepler.fpga.devices.comblock_dsss_modem import comblock_dsss_demod_mmi
from kepler.fpga.devices.comblock_turbo_code import comblock_turbo_code_dec_wrapper_mmi
from kepler.fpga.devices import cpm_trans
from kepler.fpga.devices import dac_ad5601_mmi
from kepler.fpga.devices import dac3xj8x_mmi
from kepler.fpga.devices import demod_upi
from kepler.fpga.devices import dp83867_mdio_mmi
from kepler.fpga.devices.dsss import dsss_rx_ctrl_mmi
from kepler.fpga.devices import dvbs2x_mod_mmi
from kepler.fpga.devices import eyescan_drp
from kepler.fpga.devices import ffi_rgmii_mmi
from kepler.fpga.devices import fir_coeff_buffer
from kepler.fpga.devices import ina230_mmi
from kepler.fpga.devices import ina230_maxval_mmi
from kepler.fpga.devices import ina230_vlimits_mmi
from kepler.fpga.devices import irq_mmi
from kepler.fpga.devices import irq_simple_test_mmi
from kepler.fpga.devices import kad5512_mmi
from kepler.fpga.devices import kad5512_data_mmi
from kepler.fpga.devices.modem import pch_modem
from kepler.fpga.devices import lm71
from kepler.fpga.devices import lmh6401_mmi
from kepler.fpga.devices import lmk0482x_mmi
from kepler.fpga.devices import lmx2592_mmi
from kepler.fpga.devices import mmi
from kepler.fpga.devices import mmi_axis_dbuf
from kepler.fpga.devices import mmi_firewall
from kepler.fpga.devices import mmi_regs
from kepler.fpga.devices import mmi_to_i2c
from kepler.fpga.devices import mmi_to_mmi
from kepler.fpga.devices import mmi_to_mmi_v2
from kepler.fpga.devices import mmi_to_spi
from kepler.fpga.devices import mmi_upi_poll
from kepler.fpga.devices import mmi_woregfile
from kepler.fpga.devices import mon_alarm_v3_mmi
from kepler.fpga.devices import mpsoc_bridge
from kepler.fpga.devices import nco_signal_source
from kepler.fpga.devices import nic_hdr_mmi
from kepler.fpga.devices import nic_mmi
from kepler.fpga.devices import pcal6524_mmi
from kepler.fpga.devices import pch_selectable_temperatures
from kepler.fpga.devices import pwr_detector_mmi
from kepler.fpga.devices import rfoe_ctrl_mmi
from kepler.fpga.devices import rxdata_mmi
from kepler.fpga.devices import rxdsp_mmi
from kepler.fpga.devices import dvbs2_bb_filter
from kepler.fpga.devices import rxsdr_fifo_mmi
from kepler.fpga.devices import sata_init_ctrl_mmi
from kepler.fpga.devices import sata_ps_ssd_pwr_ctrl_mmi
from kepler.fpga.devices import sata_ll
from kepler.fpga.devices import sem_ultrascale_mmi
from kepler.fpga.devices import hsd_ctrl
from kepler.fpga.devices.power_conversion import volt_to_power_adl5902, volt_to_power_tga2535
from kepler.fpga.devices.temperature_aggregate import SelectableTemperatureSensor, \
    TemperatureSensor, TemperatureAggregate
from kepler.fpga.devices import temperature_conversion
from kepler.fpga.devices import tiny_bcam
from kepler.fpga.devices import txdata_mmi
from kepler.fpga.devices import txdsp_mmi
from kepler.fpga.devices import txfifo
from kepler.fpga.devices import txreplay_mmi
from kepler.fpga.devices import upi
from kepler.fpga.devices import ut2_config_mmi
from kepler.fpga.devices import wo_clk_div_ctrl
from kepler.fpga.devices import zynq_sysmon_mmi

# This MUST match the module/board name.
BOARD_NAME = "hsd"

BOARD_TYPES = set(["hdr", "kas"])
SECONDARY_DICT = {}  # type: Dict[str, str]

LOCAL_CONNECTION_TYPE = "pi"

# Each platform needs to know some information about how to connect to this board.
# There's no way to separate board and platform information completely, because how a board connects
# is platform-specific. If a platform is not listed here, then this board will not be supported
# on that platform. ('dummy', 'pyro', and 'pyro-tunnelled' don't need to be listed)

PLATFORM_CONFIG = {'rpi': {}}  # type: Dict[str, Dict[str, Any]]

PLATFORM_CONFIG['rpi']['hdr'] = {
        'spidev': (0,
                   0),
        'qspidev': (0,
                    1),
        'flash_offsets': {
                '.boot': 0x0,
                '.ub': 0x4040000,
        },
        'pwr_gpio': [('direct',
                      25)],
        'por_b': ('ioexp_obc-od',
                  13),
        'ps_done': ('ioexp_obc',
                    20),
        'irq0': ('ioexp_obc',
                 17),
        'irq1': ('ioexp_obc',
                 12),
        'bootmode0': ('ioexp_obc',
                      14),
        'bootmode1': ('ioexp_obc',
                      16),
        'bootmode2': ('ioexp_obc',
                      19),
        'ps_err': ('ioexp_obc',
                   15),
}

PLATFORM_CONFIG['rpi']['kas'] = dict.copy(PLATFORM_CONFIG['rpi']['hdr'])

# No config for MMIoE, but all of the primary board variants exist
PLATFORM_CONFIG['mmioe'] = {}
for key in PLATFORM_CONFIG['rpi']:
    PLATFORM_CONFIG['mmioe'][key] = {}
PLATFORM_CONFIG['mmioe_remote'] = PLATFORM_CONFIG['mmioe'].copy()

PLATFORM_CONFIG['nsp'] = {'hdr': {}, 'kas': {}}

HDR_ADC = {'volt_per_lsb': 358.97e-6, 'input_impedance': 100, 'n_parallel': 4}

LDR_ADC = {'volt_per_lsb': 488.28125e-6, 'input_impedance': 200, 'n_parallel': 1}

HDR_RXFIFO_BYTES = 4096

# 6 bytes per FFI word: 12 bits per sample, 4x parallel
HDR_RXFIFO_SAMPLES = 4 * (HDR_RXFIFO_BYTES // 6)

MMI_DATA_BYTES = (MMI_SYSTEM.DATA_LEN + 7) // 8
MMI_ADDR_BYTES = (MMI_SYSTEM.ADDR_LEN + 7) // 8

# Size of AXI bus for P4 forwarding
P4_FWD_AXI_DATA_BYTES = 4
P4_FWD_AXI_ADDR_BYTES = 2

# Size of AXI bus for axi_ad9361
AXI_AD9361_AXI_DATA_BYTES = 4
AXI_AD9361_AXI_ADDR_BYTES = 2

# Constants for the MaMa CPM
MAMA_CPM_I2C_ADDR = 0x40  # I2C address of the INA230 on the Mama
MAMA_CPM_I2C_BUS = 3  # I2C bus that the INA230 is connected to on the Mama
MAMA_CPM_RSHUNT = 0.001  # Ohms
MAMA_CPM_CURRENT_LIMIT_MA = 12e3  # mA

# Pre-class configuration

# MMI Firewall names
MMI_FW_NAMES = [
        "mmi_arb_out",
        "SPI",
        "PS",
        "MMIoE",
]

ZYNQ_FW_NAMES = [
        "zynq_arb_out",
        "OBC",
]

# IRQ names: should match BOARD_HSD_CTRL_PARAMS in board_hsd_ctrl_params.sv.
IRQ_NAMES = [
        "GLOBAL_ALARM",
        "OBC_REQUEST_PENDING",
        "RX_PACKET_READY",
        "RX_BUFFER_READY",
        "TX_READY",
        "TX_BUFFER_READY",
        "SSD_READ_FILE_READY",
        "SSD_READ_BUFFER_READY",
        "SSD_WRITE_READY",
        "SSD_WRITE_BUFFER_READY",
        "OBC_IRQ_SQSPI_READ_FILE_READY",
        "OBC_IRQ_SQSPI_READ_BUFFER_READY",
        "OBC_IRQ_SQSPI_WRITE_READY",
        "OBC_IRQ_SQSPI_WRITE_BUFFER_READY",
        "IRQ_14",
        "IRQ_15",
        "IRQ_TEST_0",
        "IRQ_TEST_1",
        "IRQ_18",
        "IRQ_19",
        "IRQ_20",
        "IRQ_21",
        "IRQ_22",
        "IRQ_23",
        "IRQ_24",
        "IRQ_25",
        "IRQ_26",
        "IRQ_27",
        "IRQ_28",
        "IRQ_29",
        "IRQ_30",
        "IRQ_31",
]

INA230_PARAMS_CPM0 = ina230_mmi.INA230Params(
        offset=MMI_OFFSETS.CPMCTRL0,
        name="cpm0",
        cpm_names=[
                "VCC_BAT_0V72",
                "VCC_BAT_0V85",
                "DAC_VCC0V9",
                "MGTVCCAUX",
                "VPS_MGTRAVTT",
                "VCC2V5",
                "VCC3V3",
                "PS1V8",
                "DAC_VCC3V3",
                "VCC5V",
                "PL1V8",
                "VCC_BAT"
        ],
        i2c_addrs=[0x40,
                   0x41,
                   0x42,
                   0x43,
                   0x44,
                   0x45,
                   0x46,
                   0x47,
                   0x48,
                   0x49,
                   0x4A,
                   0x4C],
        rshunt=[0.01] * 12
)

INA230_PARAMS_CPM1 = ina230_mmi.INA230Params(
        offset=MMI_OFFSETS.CPMCTRL1,
        name="cpm1",
        cpm_names=[
                "DAC_VCC1V8",
                "ADC2_VCC1V8",
                "ADC1_VCC1V8",
                "PS1V0",
                "VCC1V8",
                "PL1V0",
                "MGTAVCC_0V9",
                "VCC_PSPLL",
                "VCC_PL_DDR",
                "VMGTAVTT",
                "VCC_PS_DDR"
        ],
        i2c_addrs=[0x40,
                   0x41,
                   0x42,
                   0x43,
                   0x44,
                   0x45,
                   0x47,
                   0x49,
                   0x4C,
                   0x4D,
                   0x4F],
        rshunt=[0.01,
                0.01,
                0.01,
                0.01,
                0.001,
                0.01,
                0.001,
                0.01,
                0.001,
                0.001,
                0.001]
)

INA230_PARAMS_HSD_BP_CPM = ina230_mmi.INA230Params(
        offset=MMI_OFFSETS.BP_CPM,
        name="hsd_bp_cpm",
        cpm_names=[
                "BP_VCC3V3_SSD",  # BP_VCC_3V3_MMU
                "BP_VCCBATT_HDR",  # BP_VCC_BATT_HDR
                "BP_VCC3V3_HDR",  # BP_VCC_3V3_HDR
                "BP_VCC_BATT_PCH_S",  # formerly BP_VCCBATT_TTC
                "BP_VCC_3V3_PCH_S",  # formerly BP_VCC3V3_TTC
                "BP_VCC3V3_PCH",  # BP_VCC_3V3_PCH
                "BP_VCCBATT_AUX",  # BP_VCC_BATT_AUX
                "BP_TEMPSNS1",  # BP_VCC_1V8_TEMPSNS1
                "BP_TEMPSNS2",  # BP_VCC_1V8_TEMPSNS2
        ],
        i2c_addrs=[
                0x49,
                0x4B,
                0x42,
                0x47,
                0x43,
                0x4F,
                0x46,
                0x4A,
                0x4E,
        ],
        rshunt=[
                0.01,
                0.01,
                0.01,
                0.005,
                0.01,
                0.01,
                0.01,
                100,
                100,
        ]
)

INA230_PARAMS_HDR_CPM = ina230_mmi.INA230Params(
        offset=MMI_OFFSETS.HDR_CPM,
        name="hdr_cpm",
        cpm_names=[
                "HDR_3V7_RX",
                "HDR_5V4",
                "HDR_3V7_LO",
                "HDR_3V7_ALLSON_5V4",
                "HDR_5V4_TX",
                "HDR_3V3_DIG",
                "HDR_6V4"
        ],
        i2c_addrs=[0x40,
                   0x42,
                   0x49,
                   0x4A,
                   0x4C,
                   0x4D,
                   0x4E],
        rshunt=[0.01,
                0.01,
                0.01,
                0.01,
                0.01,
                0.05,
                0.01]
)

INA230_PARAMS_KAS_CPM = ina230_mmi.INA230Params(
        offset=MMI_OFFSETS.KAS_CPM,
        name="kas_cpm",
        cpm_names=[
                "KAS_VCC6V5_TX",
                "KAS_VCC3V8_RX",
                "KAS_VCC3V8_TX",
                "KAS_VCC3V8_LOR",
                "KAS_VCC3V8_LOT",
                "KAS_VCC3V8_LVDIG",
                "KAS_VCC3V8_BIAS"
        ],
        i2c_addrs=[
                0x40,
                0x44,
                0x45,
                0x46,
                0x41,
                0x42,
                0x43,
        ],
        rshunt=[0.03,
                0.2,
                0.082,
                0.2,
                0.2,
                1,
                4.3]
)

INA230_PIN_GROUPS = {
        # The groups of INA230 alarm pins that are shared on the PCH board.
        "ALERT_DDR": {"VCC_PS_DDR",
                      "VCC_PL_DDR"},
        "ALERT_IO": {"PL1V8",
                     "PS1V8",
                     "PL1V0",
                     "PS1V0",
                     "VCC2V5",
                     "VCC5V",
                     "VCC1V8"},
        "ALERT_LDO": {
                "VCC3V3",
                "DAC_VCC1V8",
                "DAC_VCC0V9",
                "DAC_VCC3V3",
                "ADC2_VCC1V8",
                "ADC1_VCC1V8"
        },
        "ALERT_CORE": {
                "VCC_BAT",
                "VMGTAVTT",
                "MGTAVCC_0V9",
                "VPS_MGTRAVTT",
                "MGTVCCAUX",
                "VCC_BAT_0V85",
                "VCC_BAT_0V72",
                "VCC_PSPLL"
        }
}

TEMPERATURE_SENSORS = [
        # These are set to match the order in global_alarms.
        # ZYNQ_SYSMON.TEMP appears here twice, because there are two alarms (OT and ALM[0])
        # associated with the same temperature reading.
        TemperatureSensor(
                "SYSMON_OT",
                temperature_conversion.TemperatureSysmon4e(),
                MMI_OFFSETS.SYSMON + mmi_regs.ZYNQ_SYSMON.TEMP,
                None
        ),
        TemperatureSensor(
                "SYSMON_TEMP",
                temperature_conversion.TemperatureSysmon4e(),
                MMI_OFFSETS.SYSMON + mmi_regs.ZYNQ_SYSMON.TEMP,
                None
        ),
        TemperatureSensor(
                "LM71_0",
                temperature_conversion.TemperatureLm71(2),
                MMI_OFFSETS.LM71CTRL0 + mmi_regs.LM71_CTRL.OFFSET_DATA,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 0
        ),
        TemperatureSensor(
                "LM71_1",
                temperature_conversion.TemperatureLm71(2),
                MMI_OFFSETS.LM71CTRL1 + mmi_regs.LM71_CTRL.OFFSET_DATA,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 1
        ),
        TemperatureSensor(
                "HDR_ADC",
                temperature_conversion.TemperatureAds1118Internal(2),
                MMI_OFFSETS.FE_ADC + mmi_regs.FEADC_CTRL.OFFSET_ADC_TEMP,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 2
        ),
        SelectableTemperatureSensor(
                "HDR_PA",
                pch_selectable_temperatures.pch_hdr_pa_temp_select,
                pch_selectable_temperatures.PCH_HDR_PA_TEMP_CONV_DICT,
                MMI_OFFSETS.FE_ADC + mmi_regs.FEADC_CTRL.OFFSET_AIN3_GND_V,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 3
        ),
        TemperatureSensor(
                "KAS_PA",
                temperature_conversion.TemperatureAds1015Tmp235(),
                MMI_OFFSETS.KAS_ADC + mmi_regs.LDR_UTIL_ADC.ADCVAL0_2,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 4
        ),
        TemperatureSensor(
                "KAS_BOARD",
                temperature_conversion.TemperatureAds1015Tmp235(),
                MMI_OFFSETS.KAS_ADC + mmi_regs.LDR_UTIL_ADC.ADCVAL0_3,
                MMI_OFFSETS.PCH_TEMP_LIMIT + 5
        ),
]  # type: List[Union[TemperatureSensor, SelectableTemperatureSensor]]


def power_detector_conv_ads1118(sdr, v_det):
    """
    Wrapper function to select the appropriate power detector conversion function for the power
    detector connected to the ADS1118 on the KuHDR/LBFE.

    Params:
        sdr (SDR object): Used to determine whether a KuHDR or L-band image is loaded.
        v_det (float): The power detector voltage from the ADC.

    Returns:
        float: The power output by the PA, in dBm.

    Raises:
        NotImplementedError: If this is called on a non-HDR image (for which there is no power
        detector).
    """
    if not sdr.ctrl_fe_en:
        raise NotImplementedError("The ADS1118 only exists on HDR frontends.")

    if sdr.ctrl_lb_en:
        # LBFE
        return volt_to_power_adl5902(v_det)

    # KuHDR
    return volt_to_power_tga2535(v_det)


# Layer names and bytes per transfer for the SATA stack
SATA_LAYER_MAP = [("BBA_BLOCK", 4), ("BBA_BYTE", 1), ("BLOCK_TRAFFIC", 4), ("BLOCK_ARB_OUT", 4)]

# Mapping from SSD name to the pin on the backplane IO expander that controls
# the corresponding power-enable, and the name of the SSD connector slot.
BpioPin = namedtuple('BpioPin', ['pin', 'ssd', 'connector'])
# yapf: disable
BPIO_PINS_SSD_ALD = [ # ALD 1.0-1.2
        BpioPin(8, "PS SSD 0", "J5"),
        BpioPin(9, "PS SSD 1", "J6"),
        BpioPin(10, "PL SSD 2", "J4"),
        BpioPin(12, "PL SSD 1", "J3"),
        BpioPin(13, "PL SSD 0", "J2"),
]

BPIO_PINS_SSD_ALD_1_3 = [
        BpioPin(8, "PL SSD 0", "J2"),
        BpioPin(9, "PL SSD 1", "J3"),
        BpioPin(10, "PL SSD 2", "J4"),
        BpioPin(11, "PS SSD 0", "J5"),
        BpioPin(12, "PS SSD 1", "J6"),
]

BPIO_PINS_SSD_TARS = [
        BpioPin(8, "PL SSD 3", "J103"),
        BpioPin(9, "PS SSD 0", "J104"),
        BpioPin(10, "PL SSD 2", "J102"),
        BpioPin(11, "PS SSD 1", "J105"),
        BpioPin(12, "PL SSD 1", "J101"),
        BpioPin(13, "PL SSD 0", "J100"),
]

# yapf: enable

CPM_ALARM_NAMES_SET_0 = INA230_PARAMS_CPM0.cpm_names \
                      + INA230_PARAMS_CPM1.cpm_names \
                      + INA230_PARAMS_HDR_CPM.cpm_names \
                      + INA230_PARAMS_HSD_BP_CPM.cpm_names \
                      + INA230_PARAMS_KAS_CPM.cpm_names
SYSMON_VCC_NAMES = [
        "SYSMON_VCC_INT",
        "SYSMON_VCC_AUX",
        "SYSMON_VCC_BRAM",
        "SYSMON_VCC_PSINTLP",
        "SYSMON_VCC_PSINTFP",
        "SYSMON_VCC_PSAUX"
]
SYSMON_TEMP_NAMES = [sensor.name for sensor in TEMPERATURE_SENSORS]
ALL_ALARMS = mon_alarm_v3_mmi.AlarmParams(
        offset=MMI_OFFSETS.GLOBAL_ALARM,
        name="alarms",
        ocur_names=SYSMON_VCC_NAMES + CPM_ALARM_NAMES_SET_0,
        ovolt_names=SYSMON_VCC_NAMES + CPM_ALARM_NAMES_SET_0,
        otemp_names=SYSMON_TEMP_NAMES,
        malf_names=SYSMON_VCC_NAMES + CPM_ALARM_NAMES_SET_0
)

# Nicknames for common boot sources.
BOOT_ALIASES = {
        'jtag': mpsoc_bridge.BootSource.PSJTAG,
        'qspi': mpsoc_bridge.BootSource.QSPI32,
        'sd': mpsoc_bridge.BootSource.SD1,
}

# The ordering here is based on the ordering of MUX_indices_t in board_pch_nic
NIC_HDR_MUX_NAMES = ["simpletoga_qspi", "simpletoga_ssd", "tdi", "mmioe", "rfoe"]
# The ordering here is based on the ordering of DEMUX_indices_t in board_pch_nic
NIC_HDR_DEMUX_NAMES = ["nul", "simpletoga_ssd", "simpletoga_qspi", "tdi", "mmioe", "rfoe"]
NIC_HDR_SETTINGS = nic_hdr_mmi.NicHdrParams(
        MMI_SYSTEM.DATA_LEN,
        6,
        NIC_HDR_MUX_NAMES,
        NIC_HDR_DEMUX_NAMES,
        rule_size=400
)

UPI_POLL_N_ADDRS = 1

# used by i2c_clkdiv
# yapf: disable
I2C_BUS_FREQS = [
        ("system", 125e6),
        ("bpldr", 125e6),
        ("hdr", 125e6),
        ("kas", 125e6),
]
# yapf: enable

TX_EQ_NUM_COEFFS = 17


class InterDevCopyDevices(IntEnum):
    """
    Device IDs for the inter-device (device-to-device) BlockByte copier.
    """
    SSD0 = 0
    SSD1 = 1
    SSD2 = 2
    SSD3 = 3
    DDR = 4
    QSPI = 5
    SEC_QSPI = 6
    # SD and EMC not yet implemented


class Bootmode(IntEnum):
    """
    Bootmode pin settings corresponding to different boot sources.
    """
    JTAG = 0
    QSPI = 2  # 32-bit mode
    SD0 = 3
    SD1 = 5
    EMMC = 6


# yapf: disable
# pylint: disable=line-too-long

# Note: A few classes need to refer to other member variables. (For example, SDRController
# needs self._alarm.) Because "self" doesn't exist yet, those have to be set elsewhere.
# That is what post_init is for, below.
CLASS_CONFIG = [
        #[wrap_name,                 class,                                                    args]
        # Note: Put "mmi" first. Everything after that should be alphabetized.
        ["mmi",                      mmi.MMI,                                                  (MMI_SYSTEM.ADDR_LEN, MMI_SYSTEM.DATA_LEN, MMI_SYSTEM.BYTE_ADDRESSED)],
        ["alarm",                    mon_alarm_v3_mmi.AlarmMonitor,                            (ALL_ALARMS,)],
        ["hsd_bp_cpm",               ina230_mmi.INA230v2,                                      (INA230_PARAMS_HSD_BP_CPM,)],
        ["hsd_bp_cpm_vlim",          ina230_vlimits_mmi.INA230VLimits,                         (MMI_OFFSETS.BP_CPM_VLIM, INA230_PARAMS_HSD_BP_CPM)],
        ["hsd_bp_cpm_max",           ina230_maxval_mmi.INA230Maxval,                           (MMI_OFFSETS.BP_CPM_MAXVAL, INA230_PARAMS_HSD_BP_CPM)],
        ["hsd_bp_cpm_itrans",        cpm_trans.CpmTrans,                                       (MMI_OFFSETS.ITRANS_BP,)],
        ["all_cpms",                 all_cpms.AllCPMs,                                         (None,)],
        ["bbcopy",                   bb_copier_mmi.BBCopier,                                   (MMI_OFFSETS.IDEV_COPY, InterDevCopyDevices,)],
        ["beclk",                    lmk0482x_mmi.LMK0482X,                                    (None,)],   # see post_init
        ["beclk_bridge",             mmi_to_mmi.MMItoMMI,                                      (MMI_OFFSETS.LMKCLK, MMI_DATA_BYTES, MMI_ADDR_BYTES)],
        ["bedac",                    dac3xj8x_mmi.DAC3xj8x,                                    (MMI_OFFSETS.TXDAC,)],
        ["bedac_jesd_bridge",        mmi_to_mmi_v2.MMItoMMIV2,                                 (MMI_OFFSETS.TXDAC_JESD, 4, 2,)],
        ["bpio",                     pcal6524_mmi.Pcal6524,                                    (MMI_OFFSETS.BP_IO,)],
        ["cpm0",                     ina230_mmi.INA230v2,                                      (INA230_PARAMS_CPM0,)],
        ["cpm0_vlim",                ina230_vlimits_mmi.INA230VLimits,                         (MMI_OFFSETS.CPMCTRL0_VLIM, INA230_PARAMS_CPM0)],
        ["cpm0_max",                 ina230_maxval_mmi.INA230Maxval,                           (MMI_OFFSETS.CPMCTRL0_MAXVAL, INA230_PARAMS_CPM0)],
        ["cpm0_itrans",              cpm_trans.CpmTrans,                                       (MMI_OFFSETS.ITRANS_SYS0,)],
        ["cpm1",                     ina230_mmi.INA230v2,                                      (INA230_PARAMS_CPM1,)],
        ["cpm1_vlim",                ina230_vlimits_mmi.INA230VLimits,                         (MMI_OFFSETS.CPMCTRL1_VLIM, INA230_PARAMS_CPM1)],
        ["cpm1_max",                 ina230_maxval_mmi.INA230Maxval,                           (MMI_OFFSETS.CPMCTRL1_MAXVAL, INA230_PARAMS_CPM1)],
        ["cpm1_itrans",              cpm_trans.CpmTrans,                                       (MMI_OFFSETS.ITRANS_SYS1,)],
        ["ctrl",                     hsd_ctrl.SDRController,                                   (MMI_OFFSETS.HSDCTRL,)],
        ["ddr",                      mmi_to_mmi.MMItoMMI,                                      (MMI_OFFSETS.DDR_CTRL, 8, 4)],
        ["ddrbb_perf",               bb_perf.BBPerf,                                           (MMI_OFFSETS.DDR_BB_PERF, [("BLOCK", 4), ("BYTE", 1)],)],
        ["ddrbb_traffic",            block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.DDR_BB_TRAFFIC,)],
        ["demod",                    demod_upi.DemodUPI,                                       (MMI_OFFSETS.UPI_RXDEMOD,)],
        ["dsss_fec_dec",             comblock_turbo_code_dec_wrapper_mmi.ComblockTurboCodeDec, (MMI_OFFSETS.DSSS_FEC_DECODER,)],
        ["dsss_demod",               comblock_dsss_demod_mmi.ComblockDsssDemod,                (MMI_OFFSETS.DSSS_DEMODULATOR,)],
        ["dsss_rx_ctrl",             dsss_rx_ctrl_mmi.DsssRxCtrl,                              (MMI_OFFSETS.DSSS_RX_CTRL,)],
        # ["eth_bad_fcs_dn",           axis_eth_fcs_check_mmi.FcsCheck,                          (MMI_OFFSETS.ETH_BAD_FCS_DN,)],
        # ["eth_bad_fcs_up",           axis_eth_fcs_check_mmi.FcsCheck,                          (MMI_OFFSETS.ETH_BAD_FCS_UP,)],
        ["eth_nic_src_profiler",     axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_NIC_SRC_PROFILER, 32)],
        ["eth_nic_sink_profiler",    axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_NIC_SINK_PROFILER, 32)],
        ["eth_rgmii_src_profiler",   axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_RGMII_SRC_PROFILER, 32)],
        ["eth_rgmii_sink_profiler",  axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_RGMII_SINK_PROFILER, 32)],
        ["eth_rxsdr_src_profiler",   axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_RXSDR_SRC_PROFILER, 32)],
        ["eth_txsdr_sink_profiler",  axis_profile_mmi.AxisProfile,                             (MMI_OFFSETS.ETH_TXSDR_SINK_PROFILER, 32)],
        ["hdr_adc",                  ads1118_mmi.ADS1118,                                      (MMI_OFFSETS.FE_ADC, power_detector_conv_ads1118, 1)],
        ["hdr_cpm",                  ina230_mmi.INA230v2,                                      (INA230_PARAMS_HDR_CPM,)],
        ["hdr_cpm_itrans",           cpm_trans.CpmTrans,                                       (MMI_OFFSETS.ITRANS_HDR,)],
        ["hdr_cpm_vlim",             ina230_vlimits_mmi.INA230VLimits,                         (MMI_OFFSETS.HDR_CPM_VLIM, INA230_PARAMS_HDR_CPM)],
        ["hdr_cpm_max",              ina230_maxval_mmi.INA230Maxval,                           (MMI_OFFSETS.HDR_CPM_MAXVAL, INA230_PARAMS_HDR_CPM)],
        ["hdr_rxsyn",                lmx2592_mmi.LMX2592,                                      (MMI_OFFSETS.FE_SYNTHRX,)],
        ["hdr_txsyn",                lmx2592_mmi.LMX2592,                                      (MMI_OFFSETS.FE_SYNTHTX,)],
        ["i2c_clkdiv",               wo_clk_div_ctrl.WoClkDiv,                                 (MMI_OFFSETS.I2C_CLK_DIV, I2C_BUS_FREQS, 4, 8)],
        ["irq",                      irq_mmi.IrqCtrl,                                          (MMI_OFFSETS.IRQCTRL, IRQ_NAMES)],
        ["irq_obc_test",             irq_simple_test_mmi.SimpleIrqTest,                        (MMI_OFFSETS.IRQ_TEST, 2)],
        ["kas_adc",                  ads1015_mmi.ADS1015,                                      (MMI_OFFSETS.KAS_ADC,)],
        ["kas_cpm",                  ina230_mmi.INA230v2,                                      (INA230_PARAMS_KAS_CPM,)],
        ["kas_cpm_itrans",           cpm_trans.CpmTrans,                                       (MMI_OFFSETS.ITRANS_KAS,)],
        ["kas_cpm_vlim",             ina230_vlimits_mmi.INA230VLimits,                         (MMI_OFFSETS.KAS_CPM_VLIM, INA230_PARAMS_KAS_CPM)],
        ["kas_cpm_max",              ina230_maxval_mmi.INA230Maxval,                           (MMI_OFFSETS.KAS_CPM_MAXVAL, INA230_PARAMS_KAS_CPM)],
        ["kas_dac",                  mmi_to_spi.MMItoSPI,                                      (MMI_OFFSETS.KAS_DAC,)],
        ["kas_i2c",                  mmi_to_i2c.MMItoI2C,                                      (MMI_OFFSETS.KAS_I2C,)],
        ["kas_iqmod",                mmi_to_spi.MMItoSPIRegisters,                             (MMI_OFFSETS.KAS_IQMOD, 1, 16, False, 17, 6, False)],
        ["kas_rxsyn",                lmx2592_mmi.LMX2592,                                      (MMI_OFFSETS.KAS_SYNTHRX,)],
        ["kas_txsyn",                lmx2592_mmi.LMX2592,                                      (MMI_OFFSETS.KAS_SYNTHTX,)],
        ["kumodem",                  pch_modem.PchKuModem,                                     ()],
        ["lbmodem",                  pch_modem.PchLBModem,                                     ()],
        ["kasmodem",                 pch_modem.PchKasModem,                                    ()],
        ["mdio",                     dp83867_mdio_mmi.MdioDP83867,                             (MMI_OFFSETS.MDIO_CTRL, 0x00)],
        ["mmifw",                    mmi_firewall.MmiFirewallStatus,                           (MMI_OFFSETS.MMI_FW, MMI_FW_NAMES + ZYNQ_FW_NAMES)],
        ["mmifw_events",             mmi_firewall.MmiFirewallArbiterMonitor,                   (MMI_OFFSETS.MMI_FW_EVENTS, MMI_FW_NAMES, MMI_SYSTEM.ADDR_LEN)],
        ["nco_source",               nco_signal_source.NcoSignalSource,                        (MMI_OFFSETS.TXNCO,)],
        ["nic",                      nic_mmi.NIC,                                              (MMI_OFFSETS.NIC_SDR,)],
        ["nichdr",                   nic_hdr_mmi.NICHDR,                                       (MMI_OFFSETS.NICHDR_CTRL, NIC_HDR_SETTINGS)],
        ["p4_fwd",                   tiny_bcam.TinyBCAM,                                       (None, 32, 1, 3, 32)],   # see post_init
        ["p4_fwd_bridge",            mmi_to_mmi_v2.MMItoMMIV2,                                 (MMI_OFFSETS.P4_FWD, P4_FWD_AXI_DATA_BYTES, P4_FWD_AXI_ADDR_BYTES)],
        ["ps_bridge",                axi_to_mmi.AXItoMMI,                                      (MMI_OFFSETS.PS_MASTER,)],
        ["ps",                       mpsoc_bridge.MPSoC,                                       (None, BOOT_ALIASES)],
        ["pwrdet",                   pwr_detector_mmi.PowerDetector,                           (MMI_OFFSETS.RX_PWR_PREFILT, HDR_ADC['volt_per_lsb'], HDR_ADC['input_impedance'], HDR_ADC['n_parallel'],)],
        ["pwrdet_postfilt",          pwr_detector_mmi.PowerDetector,                           (MMI_OFFSETS.RX_PWR_POSTFILT, HDR_ADC['volt_per_lsb'], HDR_ADC['input_impedance'], HDR_ADC['n_parallel'],)],
        ["qspi_bb",                  block_byte_mmi.BlockByte,                                 (MMI_OFFSETS.QSPI_BB, "qspi")],
        ["qspi_perf",                bb_perf.BBPerf,                                           (MMI_OFFSETS.QSPI_PERF, [("BLOCK", 4), ("BYTE", 1)],)],
        ["qspi_traffic",             block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.QSPI_TRAFFIC_GEN,)],
        ["rfoe",                     rfoe_ctrl_mmi.RFoEControl,                                (MMI_OFFSETS.RFOE_CTRL,)],
        ["rgmii",                    ffi_rgmii_mmi.FFIRGMII,                                   (MMI_OFFSETS.RGMII,)],
        ["rxadc",                    kad5512_mmi.KAD5512,                                      (MMI_OFFSETS.RXADC,)],
        ["rxadc_data",               kad5512_data_mmi.KAD5512_DATA,                            (MMI_OFFSETS.RXADCDATA,)],
        ["rxamp",                    lmh6401_mmi.LMH6401,                                      (MMI_OFFSETS.RXAMP,)],
        ["rxdata",                   rxdata_mmi.RXDATA,                                        (MMI_OFFSETS.RXDATA,)],
        ["rxbbfilter",               dvbs2_bb_filter.BBFilter,                                 (MMI_OFFSETS.RX_BBFILT,)],
        ["rxdsp",                    rxdsp_mmi.RXDSP,                                          (MMI_OFFSETS.RXDSP,)],
        ["rxfifo",                   rxsdr_fifo_mmi.RXSDRFIFO,                                 (MMI_OFFSETS.RXFIFO, True, HDR_RXFIFO_SAMPLES, 12, HDR_ADC['volt_per_lsb'],)],
        ["sata_init",                sata_init_ctrl_mmi.SATAInitCtrl,                          (MMI_OFFSETS.SATA_INIT_CTRL,)],
        ["sata_ps",                  sata_ps_ssd_pwr_ctrl_mmi.PsSsdPwrCtrl,                    (MMI_OFFSETS.PS_SSD_CTRL,)],
        ["satabb",                   block_byte_mmi.BlockByte,                                 (MMI_OFFSETS.SATA_CTRL, "sata")],
        ["satabl",                   block_mmi.Block,                                          (MMI_OFFSETS.SATA_CTRL, "sata")],
        ["satablocktraffic",         block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.SATA_BLOCK_TRAFFIC_GEN,)],
        ["satadrp",                  eyescan_drp.EyescanDRP,                                   (MMI_OFFSETS.SATA_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4)],
        ["satall",                   sata_ll.SATALowLevel,                                     (MMI_OFFSETS.SATA_CTRL,)],
        ["sataperf",                 bb_perf.BBPerf,                                           (MMI_OFFSETS.SATA_PERF, SATA_LAYER_MAP,)],
        ["satatraffic",              block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.SATA_TRAFFIC_GEN,)],
        ["sata1bb",                  block_byte_mmi.BlockByte,                                 (MMI_OFFSETS.SATA1_CTRL, "sata1")],
        ["sata1bl",                  block_mmi.Block,                                          (MMI_OFFSETS.SATA1_CTRL, "sata1")],
        ["sata1blocktraffic",        block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.SATA1_BLOCK_TRAFFIC_GEN,)],
        ["sata1drp",                 eyescan_drp.EyescanDRP,                                   (MMI_OFFSETS.SATA1_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4)],
        ["sata1ll",                  sata_ll.SATALowLevel,                                     (MMI_OFFSETS.SATA1_CTRL,)],
        ["sata1perf",                bb_perf.BBPerf,                                           (MMI_OFFSETS.SATA1_PERF, SATA_LAYER_MAP,)],
        ["sata2bb",                  block_byte_mmi.BlockByte,                                 (MMI_OFFSETS.SATA2_CTRL, "sata2")],
        ["sata2bl",                  block_mmi.Block,                                          (MMI_OFFSETS.SATA2_CTRL, "sata2")],
        ["sata2blocktraffic",        block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.SATA2_BLOCK_TRAFFIC_GEN,)],
        ["sata2drp",                 eyescan_drp.EyescanDRP,                                   (MMI_OFFSETS.SATA2_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4)],
        ["sata2ll",                  sata_ll.SATALowLevel,                                     (MMI_OFFSETS.SATA2_CTRL,)],
        ["sata2perf",                bb_perf.BBPerf,                                           (MMI_OFFSETS.SATA2_PERF, SATA_LAYER_MAP,)],
        ["sata3bb",                  block_byte_mmi.BlockByte,                                 (MMI_OFFSETS.SATA3_CTRL, "sata3")],
        ["sata3bl",                  block_mmi.Block,                                          (MMI_OFFSETS.SATA3_CTRL, "sata3")],
        ["sata3blocktraffic",        block_or_bb_traffic_gen.BlockOrBBTrafficGen,              (MMI_OFFSETS.SATA3_BLOCK_TRAFFIC_GEN,)],
        ["sata3drp",                 eyescan_drp.EyescanDRP,                                   (MMI_OFFSETS.SATA3_DRP, mmi_regs.DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4)],
        ["sata3ll",                  sata_ll.SATALowLevel,                                     (MMI_OFFSETS.SATA3_CTRL,)],
        ["sata3perf",                bb_perf.BBPerf,                                           (MMI_OFFSETS.SATA3_PERF, SATA_LAYER_MAP,)],
        ["sem",                      sem_ultrascale_mmi.SemMmi,                                (MMI_OFFSETS.SEMCTRL,)],
        ["ssd_r",                    bb_dbuf.BbDbufRead,                                       (MMI_OFFSETS.OBC_SSD_READ,)],
        ["ssd_w",                    bb_dbuf.BbDbufWrite,                                      (MMI_OFFSETS.OBC_SSD_WRITE,)],
        ["sysmon",                   zynq_sysmon_mmi.ZynqSysmonMMI,                            (MMI_OFFSETS.SYSMON,)],
        ["tdirx",                    mmi_axis_dbuf.AxisDbufRead,                               (MMI_OFFSETS.TDI_RXDBUF,)],
        ["tditx",                    mmi_axis_dbuf.AxisDbufWrite,                              (MMI_OFFSETS.TDI_TXDBUF,)],
        ["temp0",                    lm71.LM71,                                                (MMI_OFFSETS.LM71CTRL0, "temp0")],
        ["temp1",                    lm71.LM71,                                                (MMI_OFFSETS.LM71CTRL1, "temp1")],
        ["temperature",              TemperatureAggregate,                                     (TEMPERATURE_SENSORS,)],
        ["txdata",                   txdata_mmi.TXDATA,                                        (MMI_OFFSETS.TXDATA,)],
        ["txdsp",                    txdsp_mmi.TXDSP,                                          (MMI_OFFSETS.TXDSP, )],

        ["tx_alc",                   agc_mmi.AgcMMI,                                           (MMI_OFFSETS.TX_ALC, )],

        ["tx_dvbs2x_mod_bridge",     mmi_to_mmi_v2.MMItoMMIV2,                                 (MMI_OFFSETS.TX_DVBS2X_MOD, 4, 2,)],
        ["tx_dvbs2x_mod",            dvbs2x_mod_mmi.DVBS2XModMMI,                              (None,)],

        ["tx_eq",                    axis_sample_complex_filter.AxisSampleComplexFilter,       (TX_EQ_NUM_COEFFS,)],
        ["tx_eq_buf_imag",           fir_coeff_buffer.FirCoeffBuffer,                          (MMI_OFFSETS.TX_EQ_IMAG, 16, 14,)],
        ["tx_eq_buf_real",           fir_coeff_buffer.FirCoeffBuffer,                          (MMI_OFFSETS.TX_EQ_REAL, 16, 14,)],

        ["tx_nano_dac",              dac_ad5601_mmi.DACAD5601MMI,                              (MMI_OFFSETS.TX_NANO_DAC,)],

        ["tx_symb_rate",             mmi_woregfile.WoRegFile,                                  (MMI_OFFSETS.TX_DVBS2X_SYMB_RATE_DIV, 2)],

        ["txreplay",                 txreplay_mmi.TXREPLAY,                                    (MMI_OFFSETS.TXREPLAY,)],
        ["txsdrbuf",                 txfifo.TxFifoBuffer,                                      (MMI_OFFSETS.TXSDR_TXBUF, 2)],
        ["creonic_mod",              mmi_to_mmi_v2.MMItoMMIV2,                                 (MMI_OFFSETS.UPI_TXMOD,4, 2)], # TODO(mmichael): Have its own mmi offset for this bus and create a proper device
        ["upi",                      upi.UPI,                                                  (MMI_OFFSETS.UPI_TXMOD,)],
        ["upi_poll",                 mmi_upi_poll.UPIPoll,                                     (MMI_OFFSETS.UPI_POLL, UPI_POLL_N_ADDRS)],
        ["ut",                       ut2_config_mmi.UserTerminalConfigv2,                      ()], # no mmi offset - uses gpio_rf_switches
        ["zynq_irq_test",            irq_simple_test_mmi.SimpleIrqTest,                        (MMI_OFFSETS.ZYNQ_IRQ_TEST, 1)],
        ["zynqfw_events",            mmi_firewall.MmiFirewallArbiterMonitor,                   (MMI_OFFSETS.ZYNQ_FW_EVENTS, ZYNQ_FW_NAMES, MMI_SYSTEM.ADDR_LEN)],
]

# yapf: enable
# pylint: enable=line-too-long


def post_init(self):
    # pylint: disable=protected-access
    '''
    post_init is also run during the SDR class constructor.
    This happens after all variables from CLASS_CONFIG have been created.
    '''
    self._beclk.set_mmi_bridge(self._beclk_bridge, 0)
    self._p4_fwd.set_mmi_bridge(self._p4_fwd_bridge, 0)
    self._ps.set_mmi_bridge(self._ps_bridge, 0)
    self._upi.set_upi_poll(self._upi_poll)
    self._tx_dvbs2x_mod.set_mmi_bridge(self._tx_dvbs2x_mod_bridge)

    self._hsd_bp_cpm_itrans.set_cpm(self._hsd_bp_cpm)
    self._cpm0_itrans.set_cpm(self._cpm0)
    self._cpm1_itrans.set_cpm(self._cpm1)
    self._hdr_cpm_itrans.set_cpm(self._hdr_cpm)
    self._kas_cpm_itrans.set_cpm(self._kas_cpm)

    # Populate all_cpms
    # TODO(asmith): Probably better to make this a descriptor that looks up the image type too.
    # That way alarms that do not apply to the current image will not be shown.
    board_type = self.board_type
    assert board_type[0] == "hsd"
    all_cpm_params = [
            INA230_PARAMS_CPM0,
            INA230_PARAMS_CPM1,
            INA230_PARAMS_HSD_BP_CPM,
    ]
    if board_type[1] in ["hdr"]:
        all_cpm_params += [INA230_PARAMS_HDR_CPM]
    elif board_type[1] in ["kas"]:
        all_cpm_params += [INA230_PARAMS_KAS_CPM]
    else:
        raise AssertionError("Unknown HSD board subtype '%s'." % board_type[1])

    self._all_cpms.set_all_cpms(all_cpm_params)
