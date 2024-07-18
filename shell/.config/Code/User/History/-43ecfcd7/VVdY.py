# MMI registers, etc.

# pylint: disable=too-many-lines,missing-docstring,invalid-name

from collections import OrderedDict
import datetime
from enum import IntEnum
from math import ceil, log

CONFIG_CHECK_VALUES = {
        0xac53: "xk7sdr",
        0x75c1: "pch",
        0x3a17: "rsmpcu",
        0xc726: "hsd",
        0x00010001: ("mpcu",
                     "pcuecp",
                     "pcugse",
                     "pcuhdr",
                     "sue",
                     "sug",
                     "zcu111"),
}


class COMBLOCK_TURBO_CODE_DEC:
    ADDR_VERSION = 0
    ADDR_FRAME_COUNTER_1 = 1
    ADDR_FRAME_ERROR_COUNTER_1 = 3
    ADDR_CONTROL = 5
    ADDR_BURST_PAYLOAD_SIZE = 6
    ADDR_P = 7
    ADDR_W_Q = 8
    ADDR_Y_PUNCTURING_PERIOD = 9
    ADDR_Y_PUNCTURING_PATTERN_1 = 10
    ADDR_N_ITER = 12
    ADDR_FRAME_PAYLOAD_LENGTH_BITS = 13
    ADDR_FRAME_SYNC_PERIOD_BITS = 14


class COMBLOCK_TURBO_CODE_ENC:
    ADDR_VERSION = 0
    ADDR_N_PARITY_BITS = 1
    ADDR_CONTROL = 2
    ADDR_BURST_PAYLOAD_SIZE = 3
    ADDR_R = 4
    ADDR_P = 5
    ADDR_W_Q = 6
    ADDR_Y_PUNCTURING_PERIOD = 7
    ADDR_Y_PUNCTURING_PATTERN_1 = 8
    ADDR_N_FRAME_PER_SYNC = 10


class COMBLOCK_DSSS_DEMOD:
    ADDR_VERSION = 0
    ADDR_SAMPLE_RATE_3 = 1
    ADDR_SUPERFRAME_LENGTH = 5
    ADDR_SYNC_LENGTH = 6
    ADDR_SYNC_WORD_7 = 7
    ADDR_STATUS = 15
    ADDR_CIC_R = 16
    ADDR_CARRIER_FREQUENCY_ERROR1_1 = 17
    ADDR_CARRIER_FREQUENCY_ERROR2_1 = 19
    ADDR_POWER_SIGNAL_AVERAGE_1 = 21
    ADDR_POWER_NOISE_AVERAGE_1 = 23
    ADDR_SNR_1 = 25
    ADDR_BER_SYNC = 27
    ADDR_BER_ERROR_COUNT_1 = 28
    ADDR_BYTE_ERROR = 30
    ADDR_DEMOD_RESET = 31
    ADDR_DEMOD_CONTROL = 32
    ADDR_AGC_RESPONSE = 33
    ADDR_RECEIVER_CENTER_FREQ_1 = 34
    ADDR_NOMINAL_CHIP_RATE_1 = 36
    ADDR_NOMINAL_SYMBOL_RATE_1 = 38
    ADDR_CODE_PERIOD = 40
    ADDR_SPREADING_FACTOR = 41
    ADDR_CODE_SEL = 42
    ADDR_G1_1 = 43
    ADDR_G2_1 = 45
    ADDR_G2OFFSET_1 = 47
    ADDR_FRAME_LENGTH = 49


class COMBLOCK_DSSS_MOD:
    ADDR_VERSION = 0
    ADDR_SAMPLE_RATE_3 = 1
    ADDR_FIRST_PREAMBLE_EXTENSION_1 = 5
    ADDR_SYNC_LENGTH = 7
    ADDR_SYNC_WORD_7 = 8
    ADDR_SATURATION = 16
    ADDR_CONTROL = 17
    ADDR_CHIP_RATE_NDIV = 18
    ADDR_SYMBOL_RATE_1 = 19
    ADDR_CODE_PERIOD = 21
    ADDR_CODE_SEL = 22
    ADDR_G1_1 = 23
    ADDR_G2_1 = 25
    ADDR_G2OFFSET_1 = 27
    ADDR_GAIN = 29
    ADDR_CENTER_FREQ_1 = 30
    ADDR_SINE_FREQ_OFFSET_AMPLITUDE_1 = 32
    ADDR_SINE_FREQ_OFFSET_FREQUENCY_1 = 34
    ADDR_MASTER_SLAVEN = 36
    ADDR_BURST_LENGTH = 37


class DSSS_RX_CTRL:
    # Read Only
    ADDR_VERSION = 0
    ADDR_STATUS = 1
    ADDR_AXIS_IN_MICROSECOND_COUNT_START_3 = 2
    ADDR_AXIS_IN_MICROSECOND_COUNT_END_3 = 6
    ADDR_AXIS_IN_BYTE_COUNT_3 = 10
    ADDR_AXIS_IN_FRAME_COUNT_3 = 14
    ADDR_PRBS_RX_BIT_COUNT_3 = 18
    ADDR_PRBS_RX_BIT_ERRORS_3 = 22

    # Read/Write
    ADDR_CONTROL = 26

    # Read Only
    ADDR_BCC_ENABLE_MASK = 27
    ADDR_BCC_LEVEL = 28


class DSSS_TX_CTRL:
    # Read Only
    ADDR_VERSION = 0
    ADDR_STATUS = 1
    ADDR_AXIS_OUT_MICROSECOND_COUNT_START_3 = 2
    ADDR_AXIS_OUT_MICROSECOND_COUNT_END_3 = 6
    ADDR_AXIS_OUT_BYTE_COUNT_3 = 10
    ADDR_AXIS_OUT_FRAME_COUNT_3 = 14

    # Read/Write
    ADDR_CONTROL = 18
    ADDR_PRBS_FRAME_SIZE = 19


class UPI:
    # Common registers between UPI devices
    WRITE_MSB = 0x0000
    WRITE_LSB = 0x0001
    WRITE_ADDR = 0x0002
    READ_ADDR = 0x0003
    READ_MSB = 0x0004
    READ_LSB = 0x0005

    # UPI_TXMOD
    TXMOD_SYMBOL_RATE_ADDR = 0x0009


class SDR_CTRL:
    ADDR_STATE = 0
    ADDR_FORCEMMI = 1
    ADDR_PWREN = 2
    ADDR_RESETNS = 3
    ADDR_INITDONES = 4
    ADDR_VERSION = 5
    ADDR_CONFIG_CHECK = 6
    ADDR_EPS_BATV = 7
    ADDR_EPS_CURRENT = 8
    ADDR_STATUS = 9
    ADDR_ALARMS = 10
    ADDR_ADCS_TARGET_ANGLE = 11
    ADDR_ADCS_SCHED_ANGLE = 12
    ADDR_RESERVED_13 = 13
    ADDR_RESERVED_14 = 14
    ADDR_PWR_GPIO = 15
    ADDR_COMMIT0 = 16
    NUM_ADDR_COMMITS = 4  # number of consecutive ADDR_COMMIT# registers
    ADDR_CHIP_ID_START = 26
    NUM_ADDR_CHIP_ID = 6  # number of consecutive ADDR_CHIP_ID# registers

    DATE_EPOCH = datetime.datetime(2015, 6, 25)  # Kepler's date of incorporation

    class STATE(IntEnum):
        IDLE = 0
        DIGINIT = 1
        SDRINIT = 2
        INITRXTX = 3
        INITPA = 4
        COMMS = 5
        STOPRXTX = 6
        STOPSDR = 7
        OFF = 8
        USERMODE = 9
        INITSSD = 10
        INITSSD_2 = 11

    BIT_FORCEMMI = 15

    # Power enables
    BIT_PWR_FEDIG = 0
    BIT_PWR_FESYNTH = 1
    BIT_PWR_FEPA = 2
    BIT_PWR_FERX = 3
    BIT_PWR_FETX = 4
    BIT_PWR_CLK = 5
    BIT_PWR_SSD = 6
    BIT_PWR_RX0 = 7
    BIT_PWR_RX1 = 8
    BIT_PWR_TX = 9

    BIT_RESETN_CPM = 0
    BIT_RESETN_TEMP = 1
    BIT_RESETN_SSD = 2
    BIT_RESETN_FE = 3
    BIT_RESETN_CLK = 4
    BIT_RESETN_PA = 5
    BIT_RESETN_RX0 = 6
    BIT_RESETN_RX1 = 7
    BIT_RESETN_TX = 8
    BIT_RESETN_NIC = 9
    BIT_RESETN_DDR = 10
    BIT_RESETN_RGMII = 11
    BIT_RESETN_BP = 14
    BIT_RESETN_LDR = 15

    # INITDONE has the same bit layout as RESETN


class SEM_CTRL:
    ADDR_STATUS = 0
    ADDR_HEARTCOUNTER_MSB = 1
    ADDR_HEARTCOUNTER_LSB = 2
    ADDR_TXMONITOR = 3  # 7-series only
    ADDR_RXMONITOR = 4  # 7-series only
    ADDR_INJECTADDR_MSB = 5
    ADDR_INJECTADDR_LSB = 6
    ADDR_INJECTSTRB = 7  # 7-series only
    ADDR_COMMAND_STATUS = 7  # UltraScale only

    STATUS_HEARTBEAT = 0
    STATUS_INITIALIZATION = 1
    STATUS_OBSERVATION = 2
    STATUS_CORRECTION = 3
    STATUS_CLASSIFICATION = 4
    STATUS_INJECTION = 5
    STATUS_ESSENTIAL = 6
    STATUS_UNCORRECTABLE = 7
    STATUS_DIAGNOSTIC_SCAN = 8  # UltraScale only
    STATUS_DETECT_ONLY = 9  # UltraScale only

    # UltraScale only:
    CMD_BIT_STATUS_BUSY = 15
    CMD_BIT_STATUS_INVALID = 14
    COMMAND_CODE_DIRECTED_CHANGE_TO_IDLE = 0b1110
    COMMAND_CODE_ERROR_INJECT = 0b1100
    COMMAND_CODE_DIRECTED_CHANGE_TO_OBSERVATION = 0b1010
    COMMAND_CODE_DIRECTED_CHANGE_TO_DETECT_ONLY = 0b1111
    COMMAND_CODE_DIRECTED_CHANGE_TO_DIAGNOSTIC_SCAN = 0b1101
    COMMAND_CODE_SOFTWARE_RESET = 0b1011


class IRQ_CTRL:
    # Bits in the CONTROL register
    CONTROL_GLOBAL_MASK = 0
    CONTROL_IRQ_HI_MASK = 1
    CONTROL_IRQ_LO_MASK = 2
    CONTROL_NUMWORDS_LSb = 13
    CONTROL_NUMWORDS_MSb = 15

    # Note: These register numbers might not correspond directly to addresses,
    # because each register spans N address, where
    #   N = 2**(register_0[CONTROL_NUMWORDS_MSb:CONTROL_NUMWORDS_LSb])

    # CONTROL also spans N registers, but only register CONTROL+0  is used.
    # CONTROL+1 to CONTROL+N-1 are unused and read as 0.
    MMI_CONTROL = 0

    # The remaining multi-word registers are in network endian order,
    # so their MSW is at register+0, and their LSW is at register+N-1.
    MMI_IRQ_GROUP = 1
    MMI_STATUS = 2
    MMI_PENDING = 3
    MMI_MASK = 4
    MMI_MASK_SET = 5
    MMI_MASK_CLEAR = 6


class OBC_BAL_REQUEST:
    # Register offsets
    OBC_STATUS = 0
    OBC_CONTROL = 1
    OBC_RESPONSE_MSB = 2
    OBC_RESPONSE_LSB = 3
    OBC_ID = 4
    OBC_FIRST_ROW = 5
    OBC_LAST_ROW = 6
    OBC_BUF_SIZE = 7
    OBC_BUF = 8
    OBC_BUF_READ_OFFSET = 9
    OBC_BUF_WRITE_OFFSET = 10

    PAYLOAD_STATUS = 16
    PAYLOAD_CONTROL = 17
    PAYLOAD_RESPONSE_MSB = 18
    PAYLOAD_RESPONSE_LSB = 19
    PAYLOAD_ID = 20
    PAYLOAD_FIRST_ROW = 21
    PAYLOAD_LAST_ROW = 22
    PAYLOAD_BUF_SIZE = 23
    PAYLOAD_BUF = 24
    PAYLOAD_BUF_READ_OFFSET = 25
    PAYLOAD_BUF_WRITE_OFFSET = 26

    MAX_BUF_SIZE = 31

    # Bit fields
    STATUS_REQ_PENDING = 0
    STATUS_IS_ACTION = 1
    STATUS_GET_NSET = 2
    STATUS_RESIZE = 3

    CONTROL_REQ_COMPLETE = 0  # OBC only
    CONTROL_CANCEL_COMMAND = 15  # payload only


class LMX_SYNTH_CTRL:
    # byte. 1 byte reg address, 2 byte data
    TRANSMISSION_SIZE = 3

    OSC_2X_ADDR = 9  # 0x09
    OSC_2X_BIT = 11

    CP_I_ADDR = 14  # 0xE
    CP_IDN_LSB = 7
    CP_IUP_LSB = 2
    CP_ICOARSE_LSB = 0

    VCO_2X_EN_ADDR = 30  # 0x1E
    VCO_2X_EN_BIT = 0

    DIST_PD_ADDR = 31  # 0x1F
    VCO_DISTB_PD_BIT = 10
    VCO_DISTA_PD_BIT = 9
    CHDIV_DIST_PD_BIT = 7

    CHDIV_EN_ADDR = 34  # 0x22
    CHDIV_EN_BIT = 5

    CHDIV_SEG2_ADDR = 35  # 0x23
    CHDIV_SEG2_MSB = 12
    CHDIV_SEG2_LSB = 9

    CHDIV_SEG3_EN_ADDR = 35  # 0x23
    CHDIV_SEG3_EN_BIT = 8

    CHDIV_SEG2_EN_ADDR = 35  # 0x23
    CHDIV_SEG2_EN_BIT = 7

    CHDIV_SEG1_ADDR = 35  # 0x23
    CHDIV_SEG1_BIT = 2

    CHDIV_SEG1_EN_ADDR = 35  # 0x23
    CHDIV_SEG1_EN_BIT = 1

    CHDIV_DISTB_EN_ADDR = 36  # 0x24
    CHDIV_DISTB_EN_BIT = 11

    CHDIV_DISTA_EN_ADDR = 36  # 0x24
    CHDIV_DISTA_EN_BIT = 10

    CHDIV_SEG_SEL_ADDR = 36  # 0x24
    CHDIV_SEG_SEL_MSB = 6
    CHDIV_SEG_SEL_LSB = 4

    CHDIV_SEG3_ADDR = 36  # 0x24
    CHDIV_SEG3_MSB = 3
    CHDIV_SEG3_LSB = 0

    PLL_N_PRE_ADDR = 37  # 0x25
    PLL_N_PRE_BIT = 12

    # (type, 12 bits. Default: 27)
    PLL_N_ADDR = 38  # 0x26
    PLL_N_MSB = 12
    PLL_N_LSB = 1

    PLL_DEN_ADDR = 40  # 0x28

    PLL_NUM_ADDR = 44  # 0x2C

    OUTA_POW_ADDR = 46  # 0x2E
    OUTA_POW_MSB = 13
    OUTA_POW_LSB = 8

    OUTB_PD_ADDR = 46  # 0x2E
    OUTB_PD_BIT = 7

    OUTA_PD_ADDR = 46  # 0x2E
    OUTA_PD_BIT = 6

    MASH_ORDER_ADDR = 46  # 0x2E
    MASH_ORDER_MSB = 2
    MASH_ORDER_LSB = 0

    OUTA_MUX_ADDR = 47  # 0x2F
    OUTA_MUX_MSB = 12
    OUTA_MUX_LSB = 11
    OUTB_POW_MSB = 5
    OUTB_POW_LSB = 0

    # synth_lmx2592_ctrl: NSYNTHREGS = 65, MMI_REQ_WORDS = 5
    NSYNTHREGS = 65
    REQ_WORDS = (NSYNTHREGS - 1) // 16 + 1  # 5
    ADDR_RDREQUEST = NSYNTHREGS  # 0x41
    ADDR_WRREQUEST = ADDR_RDREQUEST + REQ_WORDS  # 0x46
    ADDR_WAIT_OFFSET = ADDR_WRREQUEST + REQ_WORDS  # 0x4B
    PLL_LOCKED_ADDR = ADDR_WAIT_OFFSET + 2  # 0x4D

    PLL_LOCKED_BIT = 4

    STATE_ADDR = 77  # 0x4D
    STATE_MSB = 3
    STATE_LSB = 0
    STATE_IDLE = 0
    STATE_WAITLOCK = 6
    STATE_RUN = 8


class MON_ALARM_CTRL:
    # TODO: Phase out hardcoded values
    NUM_CPM_MONITORS = 16
    NUM_TEMP_MONITORS = 5

    OVER_VOLT_LIMIT_SPACE = int(2**ceil(log(NUM_CPM_MONITORS, 2)))
    OVER_TEMP_LIMIT_SPACE = int(2**ceil(log(NUM_TEMP_MONITORS, 2)))

    OFFSET_OVER_VOLT = 0
    OFFSET_OVER_TEMP = OVER_VOLT_LIMIT_SPACE
    OFFSET_CTRL = OFFSET_OVER_TEMP + OVER_TEMP_LIMIT_SPACE

    REG_GLOBAL_STATUS_MASK = OFFSET_CTRL
    REG_GLOBAL_STATUS_LATCHED = OFFSET_CTRL + 1
    REG_OCUR_MASK = OFFSET_CTRL + 2
    REG_OCUR_VALUES = OFFSET_CTRL + 3
    REG_OCUR_LATCHED = OFFSET_CTRL + 4
    REG_MALF_MASK = OFFSET_CTRL + 5
    REG_MALF_VALUES = OFFSET_CTRL + 6
    REG_MALF_LATCHED = OFFSET_CTRL + 7
    REG_OVOLT_MASK = OFFSET_CTRL + 8
    REG_OVOLT_VALUES = OFFSET_CTRL + 9
    REG_OVOLT_LATCHED = OFFSET_CTRL + 10
    REG_OTEMP_MASK = OFFSET_CTRL + 11
    REG_OTEMP_VALUES = OFFSET_CTRL + 12
    REG_OTEMP_LATCHED = OFFSET_CTRL + 13


class MON_ALARM_CTRL_V2:
    GLOBAL_ALARM_RONLY = 0
    OCURR_ALARM = 1
    OVOLT_ALARM = 2
    MALF_ALARM = 3
    OTEMP_ALARM = 4
    SYSMON_ALARM = 5
    OCURR_MASK = 6
    OVOLT_MASK = 7
    MALF_MASK = 8
    OTEMP_MASK = 9
    SYSMON_MASK = 10
    GLOBAL_ALARM_RONLY_LATCHED = 11
    OCURR_LATCHED = 12
    OVOLT_LATCHED = 13
    MALF_LATCHED = 14
    OTEMP_LATCHED = 15
    SYSMON_LATCHED = 16


class TXSDR_DSP:
    CLK_FREQUENCY = 150e6
    RESETN = 0x0000
    TX_MUX_SEL = 0x0003
    FIR_RESETN = 0x0004
    DIG_GAIN_0 = 0x0005
    DIG_OFFSET0 = 0x0006
    DIG_OFFSET1 = 0x0007
    DIG_GAIN_1 = 0x0008
    DIG_OFFSET2 = 0x0009
    DIG_OFFSET3 = 0x000A

    BIT_AXISBUF_RESETN = 0
    BIT_MOD_RESETN = 1


class TXSDR_DVBS2:
    CLK_FREQUENCY = 240e6
    CLK_FREQUENCY_OLD = 150e6


class TXSDR_DATA:
    BB_MATYPE = 0x0000
    BB_MODCOD = 0x0001
    BERT_CTRL = 0x0002
    BERT_PRBS = 0x0003
    BERT_FRAME = 0x0004
    FIFO_RESETN = 0x0005
    STATUS_CTRL = 0x0006
    STATUS_CNT2 = 0x0007
    STATUS_CNT1 = 0x0008
    STATUS_CNT0 = 0x0009
    ACM_CTRL = 0x000A
    ACM_DATA = 0x000B
    RATE_NUM = 0x000C
    ALARM_TIMEOUT_MS = 0x000D

    # For src_sel bit
    class SRC_SEL(IntEnum):
        BERT = 0
        DATA = 1

    BIT_BERTCTRL_EN = 0
    BIT_BERTCTRL_INV = 1
    BIT_BERTCTRL_SRC = 2

    BIT_STATUS_SAMPLE = 0
    BIT_STATUS_CLEAR = 1

    BIT_ACMCTRL_REQ = 12
    BIT_ACMCTRL_RDY = 13
    BIT_ACMCTRL_PREV_REQ = 14
    BIT_ACMCTRL_ACPT = 15


class TXREPLAY:
    CTRLWORD = 0x0
    ERRORWORD = 0x1
    START_ADDR = 0x2
    FILE_LENGTH = 0x5
    BUF_START_ADDR = 0x8
    BUF_ERRORWORD = 0xB
    COPY_ERRORWORD = 0xC
    COPY_STATUSWORD = 0xD

    BIT_START = 0
    BIT_REPEAT = 1
    BIT_STOP = 2
    BIT_RESET_ERR = 3

    BIT_COPY_IN_PROGRESS = 0


class RXADC_CTRL:
    ADDR_TESTMODE = 0x0007
    ADDR_STATUS = 0x000C

    STATUS_ADC_RESETN_BIT = 15
    STATUS_PLL_LOCKED_BIT = 14
    STATUS_ADC_OR_BIT = 13
    STATUS_ADC_STATE_MSB = 3
    STATUS_ADC_STATE_LSB = 0

    TEST_OFF = 0
    TEST_MS = 1  # mid-scale
    TEST_PFS = 2  # positive full-scale
    TEST_NFS = 3  # negative full-scale
    TEST_CHECK = 4  # checkerboard
    TEST_OZ = 7  # one/zero
    TEST_USER = 8  # user pattern (need to set pattern registers)
    # All other test values are reserved and should not be set


class RXADC_DATA:
    ADC_NBITS = 12

    ADDR_DLY_CTRL = 0
    ADDR_DLY_RDY = 1
    ADDR_DLY_TAP_OFFSET = 2

    BIT_DLY_CTRL_RESETN = 0
    BIT_DLY_CTRL_MMICTRL = 1
    BIT_DLY_CTRL_START = 2


class LMH6401_CTRL:
    AMP0_REVISION_ID = 0x0000
    AMP0_PRODUCT_ID = 0x0001
    AMP0_GAIN_CTRL = 0x0002
    AMP0_THERM_FDBK_GAIN = 0x0004
    AMP0_THERM_FDBK_FREQ = 0x0005
    AMP1_REVISION_ID = 0x0006
    AMP1_PRODUCT_ID = 0x0007
    AMP1_GAIN_CTRL = 0x0008
    AMP1_THERM_FDBK_GAIN = 0x000A
    AMP1_THERM_FDBK_FREQ = 0x000B

    RD_REQUEST = 0x000C
    WR_REQUEST = 0x000E
    MMICTRL = 0x0010
    VERSION = 0x0011

    BIT_MMICTRL = 0
    BIT_INITDONE = 1

    REGS_PER_AMP = 6

    MAX_GAIN_DB = 26


class RXSDR_DSP:
    DSP_CTRL = 0x0000
    AGC_CTRL = 0x0001
    AGC_CTRLVAL = 0x0002
    AGC_PERIODMSB = 0x0003
    AGC_PERIODLSB = 0x0004
    AGC_DEFGAIN = 0x0005
    AGC_CURGAIN = 0x0006
    AGC_DIVSTEP = 0x0007
    AGC_BITSHIFT = 0x0008
    NCO_PHASEINC = 0x0009
    NCO_PHASEOFF = 0x000A
    LOCK_PERIODMSB = 0x000B
    LOCK_PERIODLSB = 0x000C
    LOCK_STATE3 = 0x000D
    LOCK_STATE2 = 0x000E
    LOCK_STATE1 = 0x000F
    LOCK_STATE0 = 0x0010

    DISABLE_FILTERS = 0x0011
    MODCOD_TYPE = 0x0012

    AGC_TARGET_PREFILT3 = 0x0013
    AGC_TARGET_PREFILT2 = 0x0014
    AGC_TARGET_PREFILT1 = 0x0015
    AGC_TARGET_PREFILT0 = 0x0016
    AGC_TARGET_POSTFILT3 = 0x0017
    AGC_TARGET_POSTFILT2 = 0x0018
    AGC_TARGET_POSTFILT1 = 0x0019
    AGC_TARGET_POSTFILT0 = 0x001A

    BACKPRESSURE_COUNT_SAMPLE = 0x001B
    BACKPRESSURE_COUNT_SELECT = 0x001C
    BACKPRESSURE_COUNT1 = 0x001D
    BACKPRESSURE_COUNT0 = 0x001E

    DEMOD_N_PARALLEL = 0x001F

    BIT_DISABLE_FILTERS = 0

    BIT_DSP_AGCRESETN = 0
    BIT_DSP_DDCRESETN = 1
    BIT_DSP_DMDRESETN = 2
    BIT_DSP_LOCKMUX = 4

    class LOCKMUX(IntEnum):
        MMI = 0
        FPGA = 1

    # Bits of AGC_CTRL register
    BIT_AGC_EN_VGA = 0
    BIT_AGC_EN_DIG = 1

    # Clock frequency of rxsdr_dsp (as opposed to rxsdr_dvbs2)
    CLK_FREQ = 120e6


class RXSDR_DATA:
    BB_MATYPE = 0x0000
    BB_DFL = 0x0001
    BB_PKTLEN = 0x0002
    BB_ROLLOFF = 0x0003
    SINK_CTRL = 0x0004
    BERT_CTRL = 0x0005
    BERT_STATUS = 0x0006
    BERT_PRBS = 0x0007
    BERT_ERRCNT3 = 0x0008
    BERT_ERRCNT2 = 0x0009
    BERT_ERRCNT1 = 0x000A
    BERT_ERRCNT0 = 0x000B
    BERT_BITCNT3 = 0x000C
    BERT_BITCNT2 = 0x000D
    BERT_BITCNT1 = 0x000E
    BERT_BITCNT0 = 0x000F
    GSE_CTRL = 0x0010
    GSE_PKTCNT2 = 0x0011
    GSE_PKTCNT1 = 0x0012
    GSE_PKTCNT0 = 0x0013
    GSE_ERRCNT2 = 0x0014
    GSE_ERRCNT1 = 0x0015
    GSE_ERRCNT0 = 0x0016
    GSE_ERRORS = 0x0017
    GSE_PROTOCOL = 0x0018

    BIT_SINK_SEL = 0

    class SINK_SEL(IntEnum):
        BERT = 0
        DATA = 1

    BIT_BERTCTRL_READ = 0
    BIT_BERTCTRL_CLEAR = 1

    BIT_GSECTRL_SAMPLE = 0
    BIT_GSECTRL_CLEAR = 1

    BIT_BBROLLOFF_ROLLOFF = 0
    BIT_BBROLLOFF_CRCERR = 3
    BIT_BBROLLOFF_BBSYNC = 8

    BIT_BERTSTAT_ERROR = 0
    BIT_BERTSTAT_SYNC = 1
    BIT_BERTSTAT_SYNCLOSS = 2
    BIT_BERTSTAT_SYNCNFND = 3

    # bits in the GSE_ERRORS regiseter
    GSE_ERR_BIT_OUT_FIFO_OVERFLOW = 0
    GSE_ERR_BIT_PROTOCOL_MISMATCH = 1
    GSE_ERR_BIT_UNEXPECTED_GSE_START = 2
    GSE_ERR_BIT_EXPECTED_CONTINUATION = 3
    GSE_ERR_BIT_UNEXPECTED_CONTINUATION = 4
    GSE_ERR_BIT_FRAG_ID_MISMATCH = 5
    GSE_ERR_BIT_CRC = 6
    GSE_ERR_BIT_IN_FIFO_OVERFLOW = 7  # generated in rxsdr_data


class FE_DPM_CTRL:
    OFFSET_RDAC1 = 0
    OFFSET_RDAC2 = 1

    # 2 words
    OFFSET_WR_REQ = 4


class FEADC_CTRL:
    OFFSET_AIN0_AIN1_V = 0x0
    OFFSET_AIN2_GND_V = 0x1
    OFFSET_AIN3_GND_V = 0x2
    OFFSET_ADC_TEMP = 0x3
    OFFSET_DELAY_MSB = 0x4
    OFFSET_DELAY_LSB = 0x5
    OFFSET_RECC_SETTLINGDELAY_MSB = 0x6


class FEDAC_CTRL:
    OFFSET_DAC_A_VALUE = 0x0
    OFFSET_DAC_B_VALUE = 0x1
    OFFSET_RESERVED_2 = 0x2
    OFFSET_RESERVED_3 = 0x3
    OFFSET_CONTROL = 0x4


class LDR_UTIL_ADC:
    CTRLWORD0_0 = 0x00
    CTRLWORD0_1 = 0x01
    CTRLWORD0_2 = 0x02
    CTRLWORD0_3 = 0x03
    CTRLWORD1_0 = 0x04
    CTRLWORD1_1 = 0x05
    CTRLWORD1_2 = 0x06
    CTRLWORD1_3 = 0x07
    ADCVAL0_0 = 0x08
    ADCVAL0_1 = 0x09
    ADCVAL0_2 = 0x0A
    ADCVAL0_3 = 0x0B
    ADCVAL1_0 = 0x0C
    ADCVAL1_1 = 0x0D
    ADCVAL1_2 = 0x0E
    ADCVAL1_3 = 0x0F
    POLL_PERIOD_MSB = 0x10
    POLL_PERIOD_LSB = 0x11


class FFI_MMI_SINK:
    PAYLOAD_PTR = 0x00
    RXCTRL = 0x01
    MAXPAYLOAD_SZ = 0x02
    PAYLOAD_SZ = 0x03
    MAXHEADER_SZ = 0x04
    HEADER_SZ = 0x05
    RXCOUNT_MSB = 0x06
    RXCOUNT_LSB = 0x07
    RESERVED_8 = 0x08
    RESERVED_9 = 0x09
    RESERVED_10 = 0x0A
    RESERVED_11 = 0x0B
    RESERVED_12 = 0x0C
    RESERVED_13 = 0x0D
    RESERVED_14 = 0x0E
    RESERVED_15 = 0x0F


class FFI_MMI_SRC:
    PAYLOAD_PTR = 0x00
    TXCTRL = 0x01
    MAXPAYLOAD_SZ = 0x02
    PAYLOAD_SZ = 0x03
    MAXHEADER_SZ = 0x04
    HEADER_SZ = 0x05
    TXCOUNT_MSB = 0x06
    TXCOUNT_LSB = 0x07
    RESERVED_8 = 0x08
    RESERVED_9 = 0x09
    RESERVED_10 = 0x0A
    RESERVED_11 = 0x0B
    RESERVED_12 = 0x0C
    RESERVED_13 = 0x0D
    RESERVED_14 = 0x0E
    RESERVED_15 = 0x0F
    HEADER_PTR = 0x10


class FFI_RGMII_MMI:
    STATUS = 0x00
    STATUS_REG = 0x01
    SPEED = 0x02
    IFGDELAY = 0x03
    RXCOUNT_MSB = 0x04
    RXCOUNT_LSB = 0x05
    TXCOUNT_MSB = 0x06
    TXCOUNT_LSB = 0x07

    STATUS_TX_FIFO_OVERFLOW_BIT = 0x0
    STATUS_TX_FIFO_BADFRAME_BIT = 0x1
    STATUS_TX_FIFO_GOODFRAME_BIT = 0x2
    STATUS_RX_ERR_BADFRAME_BIT = 0x3
    STATUS_RX_ERR_BADFCS_BIT = 0x4
    STATUS_RX_FIFO_OVERFLOW_BIT = 0x5
    STATUS_RX_FIFO_BADFRAME_BIT = 0x6
    STATUS_RX_FIFO_GOODFRAME_BIT = 0x7
    STATUS_PLL_LOCKED = 0x8
    STATUS_COUNT_SAMPLE = 0x9
    STATUS_COUNT_CLEAR = 0xA


class MMI_AXIS_DBUF_READ:
    # Register indices
    STATUS = 0X00
    CONTROL = 0X01
    BUFFER_SIZE = 0X02
    ID = 0X03
    DATA_SIZE_MSB = 0X04
    DATA_SIZE_LSB = 0X05
    BUF_OFFSET_MSB = 0X06
    BUF_OFFSET_LSB = 0X07
    BUF_RADDR = 0X08
    BUF_RDATA = 0X09

    # Status register bits
    STATUS_FILE_READY = 0
    STATUS_IN_PROGRESS = 1
    STATUS_BUFFER_READY = 2

    # Control register bits
    CONTROL_CONSUME_BUFFER = 0


class MMI_AXIS_DBUF_WRITE:
    # Register indices
    STATUS = 0X00
    CONTROL = 0X01
    BUFFER_SIZE = 0X02
    ID = 0X03
    DATA_SIZE_MSB = 0X04
    DATA_SIZE_LSB = 0X05
    BUF_OFFSET_MSB = 0X06
    BUF_OFFSET_LSB = 0X07
    BUF_WADDR = 0X08
    BUF_WDATA = 0X09

    # Status register bits
    STATUS_RECV_READY = 0
    STATUS_IN_PROGRESS = 1
    STATUS_BUFFER_READY = 2

    # Control register bits
    CONTROL_COMMIT_BUFFER = 0


class BB_MMI_DBUF_WRITE:
    # This module encapsulates an MMI_AXIS_DBUF_WRITE at address 0,
    # and then adds new control registers starting at this offset:
    BB_CTRL_OFFSET = 16

    STATUS = BB_CTRL_OFFSET + 0
    ADDR2 = BB_CTRL_OFFSET + 1
    ADDR1 = BB_CTRL_OFFSET + 2
    ADDR0 = BB_CTRL_OFFSET + 3
    CONTROL = BB_CTRL_OFFSET + 4
    RESERVED5 = BB_CTRL_OFFSET + 5
    COUNT1 = BB_CTRL_OFFSET + 6
    COUNT0 = BB_CTRL_OFFSET + 7

    # Bits in STATUS:
    STATUS_BACKEND_READY = 0
    STATUS_BUSY = 1
    STATUS_ERR_BAD_REQUEST = 2

    # Bits in CONTROL
    CONTROL_BEGIN_WRITE = 0
    CONTROL_FLUSH = 1


class BB_MMI_DBUF_READ:
    # This module encapsulates an MMI_AXIS_DBUF_READ at address 0,
    # and then adds new control registers starting at this offset:
    BB_CTRL_OFFSET = 16

    STATUS = BB_CTRL_OFFSET + 0
    ADDR2 = BB_CTRL_OFFSET + 1
    ADDR1 = BB_CTRL_OFFSET + 2
    ADDR0 = BB_CTRL_OFFSET + 3
    CONTROL = BB_CTRL_OFFSET + 4
    RESERVED5 = BB_CTRL_OFFSET + 5
    COUNT1 = BB_CTRL_OFFSET + 6
    COUNT0 = BB_CTRL_OFFSET + 7

    # Bits in STATUS:
    STATUS_BACKEND_READY = 0
    STATUS_BUSY = 1
    STATUS_ERR_BAD_REQUEST = 2

    # Bits in CONTROL
    CONTROL_BEGIN_READ = 0


class BLOCK_OR_BB_TRAFFIC_GEN:
    STATUS = 0
    CONTROL = 1
    # These values are each in consecutive 3-word big endian registers:
    START_ADDR2 = 3
    CHUNK_SIZE2 = 7
    NUM_CHUNKS2 = 11
    PRBS_BIT_ERRS3 = 14
    CUR_CHUNK2 = 19
    LAYER_TYPE = 22

    STATE_IDLE = 0
    STATE_READ = 1
    STATE_WRITE = 2
    CONTROL_LOOP_BIT = 8


class BB_COPIER:
    # MMI register offsets
    STATUS_COMMAND = 0
    ERROR = 1
    SRC = 2
    DST = 3
    SRC_ADDR_2 = 5
    DST_ADDR_2 = 9
    COUNT_2 = 13
    LATCH_PROGRESS = 16
    PROGRESS_2 = 17

    # error bits
    class B2CErrBits(IntEnum):
        SRC_INVALID = 0
        DST_INVALID = 1
        COMBO_INVALID = 2
        SRC_RANGE_INVALID = 3
        DST_RANGE_INVALID = 4
        COUNT_INVALID = 5
        SRC_ERR = 6
        DST_ERR = 7
        SRC_NOT_READY = 8
        DST_NOT_READY = 9


class TFTP_MMI:
    FTC_CTRL = 0x00
    CHANNEL_ID = 0x01
    FILE_SZ_MSB = 0x02
    FILE_SZ_LSB = 0x03
    FILE_PTR_MSB = 0x04
    FILE_PTR_LSB = 0x05
    FILE_DATA = 0x06
    TIMEOUT_MSB = 0x07
    TIMEOUT_LSB = 0x08


class TSTP_MMI:
    # Control registers
    FTC_CTRL = 0x00
    CHANNEL_ID = 0x01
    FILE_SZ_MSB = 0x02
    FILE_SZ_LSB = 0x03
    FILE_PTR_MSB = 0x04
    FILE_PTR_LSB = 0x05
    FILE_DATA = 0x06
    RESERVED_7 = 0x07
    RESERVED_8 = 0x08
    FILE_ADDR_2 = 0x09
    FILE_ADDR_1 = 0x0A
    FILE_ADDR_0 = 0x0B
    FILL_LEVEL_MSB = 0x0C
    FILL_LEVEL_LSB = 0x0D
    LOW_FILL_LEVEL_MSB = 0x0E
    LOW_FILL_LEVEL_LSB = 0x0F
    PAD_SZ_MSB = 0x10
    PAD_SZ_LSB = 0x11

    # Bit fields in FTC_CTRL
    FILE_READY = 0
    XFER_DONE = 1
    PREPARE_FILE = 2
    BYTE_SWAP = 3
    XFER_FAILED = 4
    BUFFERING = 5
    WORD_SWAP = 6
    AUTO_ZERO_PAD = 7


# Assuming all IP addresses are 2 words and big-endian
# TODO - clarify why there are two sets
class NIC_HDR_CTRL:
    TDI_DEST_PORT_1 = 0
    TDI_SRC_PORT_1 = 1
    TDI_DEST_IP_1 = 2
    TDI_SRC_IP_1 = 4
    TFTP_DEST_PORT_1 = 6
    TFTP_SRC_PORT_1 = 7
    TFTP_DEST_IP_1 = 8
    TFTP_SRC_IP_1 = 10

    TDI_DEST_PORT_2 = 12
    TDI_SRC_PORT_2 = 13
    TDI_DEST_IP_2 = 14
    TDI_SRC_IP_2 = 16
    TFTP_DEST_PORT_2 = 18
    TFTP_SRC_PORT_2 = 19
    TFTP_DEST_IP_2 = 20
    TFTP_SRC_IP_2 = 22


class NIC_MMI:
    NIC_CTRL = 0x00
    ETH_FLAGS = 0x01
    IP_FLAGS = 0x02
    UDP_FLAGS = 0x03
    MACADDR2 = 0x04
    MACADDR1 = 0x05
    MACADDR0 = 0x06
    IPADDR_MSB = 0x07
    IPADDR_LSB = 0x08
    GWADDR_MSB = 0x09
    GWADDR_LSB = 0x0A
    NETMASK_MSB = 0x0B
    NETMASK_LSB = 0x0C
    SAMPLE_CNT = 0x0D
    CLEAR_CNT = 0x0E
    ETHRX_PKT_CNT1 = 0x0F
    ETHRX_PKT_CNT0 = 0x10
    ETHTX_PKT_CNT1 = 0x11
    ETHTX_PKT_CNT0 = 0x12
    IPRX_PKT_CNT1 = 0x13
    IPRX_PKT_CNT0 = 0x14
    IPTX_PKT_CNT1 = 0x15
    IPTX_PKT_CNT0 = 0x16
    UDPRX_PKT_CNT1 = 0x17
    UDPRX_PKT_CNT0 = 0x18
    UDPTX_PKT_CNT1 = 0x19
    UDPTX_PKT_CNT0 = 0x1A
    ETHRX_ERR_CNT1 = 0x1B
    ETHRX_ERR_CNT0 = 0x1C
    ETHTX_ERR_CNT1 = 0x1D
    ETHTX_ERR_CNT0 = 0x1E
    IPRX_ERR_CNT1 = 0x1F
    IPRX_ERR_CNT0 = 0x20
    IPTX_ERR_CNT1 = 0x21
    IPTX_ERR_CNT0 = 0x22
    UDPRX_ERR_CNT1 = 0x23
    UDPRX_ERR_CNT0 = 0x24
    UDPTX_ERR_CNT1 = 0x25
    UDPTX_ERR_CNT0 = 0x26
    ETHFIFO_PKT_CNT1 = 0x27
    ETHFIFO_PKT_CNT0 = 0x28
    ETHFIFO_ERR_CNT1 = 0x29
    ETHFIFO_ERR_CNT0 = 0x2A
    ETHFIFO_FILLLEVEL = 0x2B
    IPRX_IP_MATCH_CNT1 = 0x2C
    IPRX_IP_MATCH_CNT0 = 0x2D
    IPRX_MAC_MATCH_CNT1 = 0x2E
    IPRX_MAC_MATCH_CNT0 = 0x2F
    UDPRX_IP_MATCH_CNT1 = 0x30
    UDPRX_IP_MATCH_CNT0 = 0x31
    UDPRX_MAC_MATCH_CNT1 = 0x32
    UDPRX_MAC_MATCH_CNT0 = 0x33
    AXIS_TX_RATE_NUMERATOR = 0x34

    CNTBIT_ETHRX_PKT = 0x00
    CNTBIT_ETHTX_PKT = 0x01
    CNTBIT_IPRX_PKT = 0x02
    CNTBIT_IPTX_PKT = 0x03
    CNTBIT_UDPRX_PKT = 0x04
    CNTBIT_UDPTX_PKT = 0x05
    CNTBIT_ETHRX_ERR = 0x06
    CNTBIT_ETHTX_ERR = 0x07
    CNTBIT_IPRX_ERR = 0x08
    CNTBIT_IPTX_ERR = 0x09
    CNTBIT_UDPRX_ERR = 0x0A
    CNTBIT_UDPTX_ERR = 0x0B
    CNTBIT_FIFO_PKT = 0x0C
    CNTBIT_FIFO_ERR = 0x0D
    CNTBIT_IP_MATCH = 0x0E
    CNTBIT_MAC_MATCH = 0x0F
    CNTBIT_NCOUNTS = 0x10

    # flags
    ETH_FLAG_NAMES = {0: "eth_rx_busy", 1: "eth_tx_busy", 2: "eth_rx_err_het"}
    IP_FLAG_NAMES = {
            0: "ip_rx_busy",
            1: "ip_tx_busy",
            2: "ip_rx_err_het",
            3: "ip_rx_err_pet",
            4: "ip_rx_err_invhdr",
            5: "ip_rx_err_invcs",
            6: "ip_tx_err_pet",
            7: "ip_tx_err_arp"
    }
    UDP_FLAG_NAMES = {
            0: "udp_rx_busy",
            1: "udp_tx_busy",
            2: "udp_rx_err_het",
            3: "udp_rx_err_pet",
            4: "udp_tx_err_pet"
    }


class TINY_CAM:
    # Note that these are all word-addressed (for the MMI side), while AXI is byte-addressed, so
    # multiply these by 4 to get values that match the user guide.
    CAM_CTRL = 0x00
    CAM_ENTRY_ID = 0x01
    CAM_EMULATION_MODE = 0x02
    CAM_LOOKUP_COUNT = 0X03
    CAM_HIT_COUNT = 0X04
    CAM_MISS_COUNT = 0X05
    CAM_DATA0 = 0X10

    CTRL_RD_BIT = 0
    CTRL_WR_BIT = 1
    CTRL_RST_BIT = 2
    CTRL_ENTRY_IN_USE_BIT = 31


class DDR_CTRL:
    DDR_CTRL = 0x00
    DDR_WADDR = 0x01
    DDR_WDATA = 0x03
    DDR_RADDR = 0x07
    DDR_RDATA = 0x09
    DDR_SELECT = 0x0D

    CTRL_WR_BIT = 0x00
    CTRL_RD_BIT = 0x01


class MMI_TO_MMI:
    CTRL_WR_BIT = 0
    CTRL_RD_BIT = 1


class MMI_TO_MMI_V2:
    MMI_STATUS = 0
    MMI_BUF_SIZE = 1
    MMI_BUF_IDX = 2
    MMI_BUF_DATA = 3
    MMI_WRITE_LEN = 4
    MMI_READ_LEN = 5
    MMI_ADDR0 = 6

    MMI_STATUS_BUSY_BIT = 0
    MMI_STATUS_INVALID_BIT = 1


class LM71_CTRL:
    OFFSET_DATA = 0
    OFFSET_POLL_PERIOD_MSB = 1
    OFFSET_POLL_PERIOD_LSB = 2
    OFFSET_STATUS = 3


class PWR_DETECTOR:
    STATUS = 0
    MAX_DEPTH = 1
    PERIOD = 2
    CHANNEL_ID = 3
    ACCUM_LATCH_3 = 4
    ACCUM_POWER_3 = 8
    MAX_POWER_SAMPLE_PERIOD = 12

    STATUS_FIFO_PRESENT = 0
    STATUS_FIFO_FULL = 1


class MMI_FIFOBUF:
    FTC_CTRL = 0x00
    CHANNEL_ID = 0x01
    FILE_SZ_MSB = 0x02
    FILE_SZ_LSB = 0x03
    FILE_PTR_MSB = 0x04
    FILE_PTR_LSB = 0x05
    FILE_DATA = 0x06
    STORE_SZ_MSB = 0x07
    STORE_SZ_LSB = 0x08

    CTRLBIT_FIFORDY = 0
    CTRLBIT_XFERDONE = 1
    CTRLBIT_FFIACPT = 2
    CTRLBIT_FFIERR = 3
    CTRLBIT_STORE = 4
    CTRLBIT_STOP = 5


class AXIS_MMIBUF:
    MMI_CTRL = 0x00
    CHANNEL_ID = 0x01
    RAM_PTR_MSB = 0x02
    RAM_PTR_LSB = 0x03
    RAM_DATA = 0x04
    READSZ_MSB = 0x05
    READSZ_LSB = 0x06

    CTRLBIT_START = 0
    CTRLBIT_STOP = 1
    CTRLBIT_REPEAT = 2
    CTRLBIT_TLAST = 3


class DRP_MMI:
    DRP_TYPE_UNSPECIFIED = 0  # unspecified DRP device
    DRP_TYPE_KINTEX7_GTX = 1  # Kintex7 GTX transceiver
    DRP_TYPE_ULTRASCALEPLUS_GTH4 = 2  # UltraScale+ GTH4 transceiver

    MMI_STATUS = 0
    MMI_WADDR = 1
    MMI_RADDR = 2
    MMI_DATA = 3
    MMI_GPIO_IN = 4
    MMI_GPIO_OUT = 5
    MMI_DRP_TYPE_ID = 6
    MMI_REF_CLK_COUNT = 7

    CTRLBIT_BUSY = 0
    CTRLBIT_ERR = 8
    GT_LOOPBACK_MSB = 10
    GT_LOOPBACK_LSB = 8


class DRP_EYESCAN:
    # Registers maps are different for each DRP device.
    # Eyescan control registers for devices we support are defined here as tuples:
    # (offset, lsb, msb)
    # lsb=msb=None means the whole word is used

    # yapf: disable

    REGS = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: {
            # Control registers
            'RX_DATA_WIDTH':    (0x011, 11, 13),
            'RX_INT_DATAWIDTH': (0x011, 14, 14),
            'ES_QUAL_MASK0':    (0x031,  None, None),
            'ES_QUAL_MASK1':    (0x032,  None, None),
            'ES_QUAL_MASK2':    (0x033,  None, None),
            'ES_QUAL_MASK3':    (0x034,  None, None),
            'ES_QUAL_MASK4':    (0x035,  None, None),
            'ES_SDATA_MASK0':   (0x036,  None, None),
            'ES_SDATA_MASK1':   (0x037,  None, None),
            'ES_SDATA_MASK2':   (0x038,  None, None),
            'ES_SDATA_MASK3':   (0x039,  None, None),
            'ES_SDATA_MASK4':   (0x03A,  None, None),
            'ES_PRESCALE':      (0x03B, 11, 15),
            'ES_VERT_OFFSET':   (0x03B,  0,  8),
            'ES_HORZ_OFFSET':   (0x03C,  0, 11),
            'ES_CONTROL_RUN':   (0x03D,  0,  0),
            'ES_CONTROL_ARM':   (0x03D,  1,  1),
            'ES_CONTROL_STATE_TRIGGER': (0x03D,  2, 5),
            'ES_EYE_SCAN_EN':   (0x03D,  8,  8),
            'ES_EYE_SCAN_EN2':  (0x082,  5,  5), # PMA_RSV2[5], needed on Kintex-7 GTX only
            'ES_ERRDET_EN':     (0x03D,  9,  9),
            'RXOUT_DIV':        (0x088,  0,  2),
            # Kintex-7 does not support asynchronous gearbox, so we have no need for
            # either of the two GEARBOX registers.

            # Read-only registers
            'ES_ERROR_COUNT':   (0x14F,  0, 15),
            'ES_SAMPLE_COUNT':  (0x150,  0, 15),
            'ES_CONTROL_STATUS_DONE':   (0x151,  0,  0),
            'ES_CONTROL_STATUS_STATE':  (0x151,  1,  3),
        },
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: {
            # Control registers
            'RX_DATA_WIDTH':    (0x0003,  5,  8),
            'RX_INT_DATAWIDTH': (0x0066,  0,  1),
            'ES_QUAL_MASK0':    (0x0044, None, None),   # followed by 1-4 at consecutive addresses
            'ES_SDATA_MASK0':   (0x0049, None, None),   # followed by 1-4 at consecutive addresses
            'ES_PRESCALE':      (0x003C,  0,  4),
            'ES_VERT_OFFSET':   (0x0097,  2, 10),
            'ES_VS_RANGE':      (0x0097,  0,  1),
            'ES_HORZ_OFFSET':   (0x004F,  4, 15),
            'ES_CONTROL_RUN':   (0x003C, 10, 10),
            'ES_CONTROL_ARM':   (0x003C, 11, 11),
            'ES_CONTROL_STATE_TRIGGER': (0x003C, 12, 15),
            'ES_EYE_SCAN_EN':   (0x003C,  8,  8),
            'ES_ERRDET_EN':     (0x003C,  9,  9),
            'RXOUT_DIV':        (0x0063,  0,  2),
            'RXGEARBOX_EN':     (0x0064,  0,  0),
            'GEARBOX_MODE_ASYNC': (0x0099, 15, 15),  # GEARBOX_MODE is [15:11]
            #                                        # the MSb indicates async(1)/sync(0)

            # Read-only registers
            'ES_ERROR_COUNT':   (0x0251,  0, 15),
            'ES_SAMPLE_COUNT':  (0x0252,  0, 15),
            'ES_CONTROL_STATUS_DONE':   (0x0253,  0,  0),
            'ES_CONTROL_STATUS_STATE':  (0x0253,  1,  3),
        }
    }
    ES_QUAL_MASK_REGS = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: [0x031, 0x032, 0x033, 0x034, 0x035],
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: [0x0044, 0x0045, 0x0046, 0x0047, 0x0048,
                                                  0x00EC, 0x00ED, 0x00EE, 0x00EF, 0x00F0],
    }
    ES_SDATA_MASK_REGS = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: [0x036, 0x037, 0x038, 0x039, 0x03A],
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: [0x0049, 0x004A, 0x004B, 0x004C, 0x004D,
                                                  0x00F1, 0x00F2, 0x00F3, 0x00F4, 0x00F5],
    }
    SDATA_MASK_VALUE_LENGTHS = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: 80,
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: 160,
    }
    SDATA_MASK_VALUES = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: {
            # See ES_SDATA_MASK in Table 4-27 of ug476.
            40: int(40*"1" + 40*"0", 2),
            32: int(40*"1" + 32*"0" + 8*"1", 2),
            20: int(40*"1" + 20*"0" + 20*"1", 2),
            16: int(40*"1" + 16*"0" + 24*"1", 2)
        },
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: {
            # See ES_SDATA_MASK in Table 4-20 of ug576.
            80: int(80*"1" + 80*"0", 2),
            64: int(80*"1" + 64*"0" + 16*"1", 2),
            40: int(80*"1" + 40*"0" + 40*"1", 2),
            32: int(80*"1" + 32*"0" + 48*"1", 2),
            20: int(80*"1" + 20*"0" + 60*"1", 2),
            16: int(80*"1" + 16*"0" + 64*"1", 2)
        }
    }
    VERT_UNITS = {
        DRP_MMI.DRP_TYPE_KINTEX7_GTX: {
            # 7-series not measured in mV; full scale is +/- 0.5 UT
            'per_div': 0.5/127,
            'units': ""
        },
        DRP_MMI.DRP_TYPE_ULTRASCALEPLUS_GTH4: {
            # US+ GTH: adjustable, but we always set it to the max
            'per_div': 2.8,
            'units': "mV"
        }
    }

    # yapf: enable

    class EsState:  # values for ES_CONTROL_STATUS_STATE
        WAIT = 0b000
        RESET = 0b001
        COUNT = 0b011
        END = 0b010
        ARMED = 0b101
        READ = 0b100


class SATA_INIT_CTRL:
    MMI_STATUS = 0
    MMI_N_SATA = 1
    MMI_SSD_PRESENTS = 2
    MMI_INITDONES = 3
    MMI_ENABLES = 4
    MMI_RETRY_COUNTER_SELECT = 5
    MMI_RETRY_COUNTER = 6

    BIT_STATUS_NRESET = 0  # Status bit: resetn from sdr controller
    BIT_STATUS_INITDONE = 1  # Status bit: initdone to sdr controller


class SATA_LL_CTRL:
    MODULE_ID_SATA_LOWLEVEL = 0x534c  # = ASCII "SL" (for Sata Low-level)
    REG_FILE_BIT = 4

    # C&C registers
    MMI_MODULE_ID = 0
    MMI_STATUS_CTRL = 1
    MMI_COMMAND = 2
    MMI_FEATURES = 3
    MMI_COUNT = 4
    MMI_ADDR0 = 5
    MMI_ADDR1 = 6
    MMI_ADDR2 = 7
    MMI_HDSTATUS = 8
    MMI_D2H_LBA0 = 9
    MMI_D2H_LBA1 = 10
    MMI_D2H_LBA2 = 11
    MMI_D2H_SECTOR_COUNT = 12
    MMI_BLOCK_WORDS = 13
    MMI_EVENT_TIME_LSB = 14
    MMI_EVENT_TIME_MSB = 15

    # Buffer registers
    MMI_BUF_WADDR = 2**REG_FILE_BIT + 0
    MMI_BUF_RADDR = 2**REG_FILE_BIT + 1
    MMI_BUF_WSECTORS = 2**REG_FILE_BIT + 2
    MMI_BUF_RSECTORS = 2**REG_FILE_BIT + 3
    MMI_BUF_DATA = 2**REG_FILE_BIT + 4

    # bits of the STATUS_CTRL register
    STATUS_NRESET = 1 << 0  # status bit (for now: read-only, from SDR control, will always read 1)
    STATUS_INITDONE = 1 << 1  # reserved: 0 for now
    STATUS_CTRL_BUSY = 1 << 2  # Cross-clock command interface is busy. Do not write to MMI_COMMAND.
    STATUS_CTRL_ERR = 1 << 3  # A write to MMI_COMMAND was attempted while STATUS_CTRL_BUSY was set.
    # The write was ignored. Write 1 to this field to clear this flag.
    STATUS_CMD_COMPLETE = 1 << 4
    # 0 after a command has been issued; 1 when the device responds with d2h_reg_stb
    STATUS_DATA_COMPLETE = 1 << 5
    # 0 after a command has been issued; 1 when the device responds with d2h_data_stb
    STATUS_WBUF_BUSY = 1 << 6  # transferring data from write buffer to write fifo
    STATUS_RBUF_BUSY = 1 << 7  # transferring data from read buffer to read fifo
    STATUS_STACK_READY = 1 << 8
    STATUS_STACK_BUSY = 1 << 9
    STATUS_PLATFORM_READY = 1 << 10
    STATUS_PLATFORM_ERROR = 1 << 11
    STATUS_LINKUP = 1 << 12
    STATUS_HD_ERROR = 1 << 13
    STATUS_SEND_SYNC_ESCAPE = 1 << 14  # Write 1 to this field to pulse the send_sync_escape line.
    STATUS_DEV_PRESENT = 1 << 15

    # Status bits
    STATUS_NRESET_BIT = 0
    STATUS_INITDONE_BIT = 1
    STATUS_CTRL_BUSY_BIT = 2
    STATUS_CTRL_ERR_BIT = 3
    STATUS_CMD_COMPLETE_BIT = 4
    STATUS_DATA_COMPLETE_BIT = 5
    STATUS_WBUF_BUSY_BIT = 6
    STATUS_RBUF_BUSY_BIT = 7
    STATUS_STACK_READY_BIT = 8
    STATUS_STACK_BUSY_BIT = 9
    STATUS_PLATFORM_READY_BIT = 10
    STATUS_PLATFORM_ERROR_BIT = 11
    STATUS_LINKUP_BIT = 12
    STATUS_HD_ERROR_BIT = 13
    STATUS_SEND_SYNC_ESCAPE_BIT = 14
    STATUS_DEV_PRESENT_BIT = 15

    # bits of the d2h_status field, from the SATA spec
    HDSTATUS_ERROR = 1 << 0
    HDSTATUS_SENSE_DATA_AVAILABLE = 1 << 1
    HDSTATUS_ALIGNMENT_ERROR = 1 << 2
    HDSTATUS_DATA_REQUEST = 1 << 3
    HDSTATUS_DEFERRED_WRITE_ERROR = 1 << 4
    HDSTATUS_DEVICE_FAULT = 1 << 5  # or STREAM ERROR
    HDSTATUS_DEVICE_READY = 1 << 6
    HDSTATUS_BUSY = 1 << 7

    # HDStatus bits
    HDSTATUS_ERROR_BIT = 0
    HDSTATUS_SENSE_DATA_AVAILABLE_BIT = 1
    HDSTATUS_ALIGNMENT_ERROR_BIT = 2
    HDSTATUS_DATA_REQUEST_BIT = 3
    HDSTATUS_DEFERRED_WRITE_ERROR_BIT = 4
    HDSTATUS_DEVICE_FAULT_BIT = 5  # or STREAM ERROR
    HDSTATUS_DEVICE_READY_BIT = 6
    HDSTATUS_BUSY_BIT = 7

    # bits of the d2h_error field, from the SATA spec
    HDERROR_CCTO = 1 << 0  # command completion timeoout / CFA error bit
    HDERROR_ABORT = 1 << 2
    HDERROR_ID_NOT_FOUND = 1 << 4
    HDERROR_UNCORRECTABLE_ERROR = 1 << 6
    HDERROR_INTERFACE_CRC = 1 << 7
    HDERROR_OBSOLETE_MASK = 0x2A  # these bits are all obsolete

    # HDError bits (in the status register, shifted 8 left)
    HDERROR_CCTO_BIT = 8  # command completion timeoout / CFA error bit
    HDERROR_ABORT_BIT = 10
    HDERROR_ID_NOT_FOUND_BIT = 12
    HDERROR_UNCORRECTABLE_ERROR_BIT = 14
    HDERROR_INTERFACE_CRC_BIT = 15

    # SATA commands
    CMD_NOP = 0x00  # command is always aborted
    CMD_DATA_SET_MANAGEMENT = 0x06  # if features[0], this executes TRIM
    CMD_READ_DMA_EXT = 0x25
    CMD_WRITE_DMA_EXT = 0x35
    CMD_FLUSH_CACHE_EXT = 0xEA  # non-data
    CMD_IDENTIFY_DEVICE = 0xEC  # non-data; does not send D2H_REG FIS
    CMD_CHECK_POWER_MODE = 0xE5  # non-data
    CMD_READ_NATIVE_MAX_ADDRESS_EXT = 0x27  # non-data


# SATA BL
class BLOCK_CTRL:
    MODULE_IDs = {
            0x5342: "SATA Block Layer",
            0x5142: "Zynq QSPI Block Layer",
            # others can be added here
    }

    # Registers
    MMI_MODULE_ID = 0  # read-only.
    # Should be unique per module instance, to verify what you're talking to.
    MMI_STATUS_CTRL = 1  # status bits (see mmi_status_bits enum)
    MMI_COMMAND = 2  # Writing to this register issues a command to the block layer.
    MMI_ADDR0 = 3  # the value sector_address[15:0] to send when MMI_COMMAND is written
    MMI_ADDR1 = 4  # the value sector_address[31:16] to send when MMI_COMMAND is written
    MMI_ADDR2 = 5  # the value sector_address[47:32] to send when MMI_COMMAND is written
    MMI_BLOCK_COUNT = 6  # [4:0] the number of blocks to read/write, max 16; [15:4] reserved
    MMI_LAST_BLOCK0 = 7  # last_block[15:0], highest usable block address
    MMI_LAST_BLOCK1 = 8  # last_block[31:16], highest usable block address
    MMI_LAST_BLOCK2 = 9  # last_block[47:32], highest usable block address
    MMI_BUF_DATA = 10  # Writing to this register causes the data to be stored in the write buffer
    # at offset WADDR. After the write, WADDR is incremented by one.
    # Reading from this retrieves a word from the read buffer at offset RADDR.
    # After the read, RADDR is incremented by one.
    MMI_BUF_WADDR = 11  # Offset within the write buffer at which the next write will occur.
    MMI_BUF_RADDR = 12  # Offset within the read buffer from which the next read will occur.
    MMI_BLOCK_WORDS = 13  # The number of 16-bit words in a block.
    MMI_EVENT_TIME_LSB = 14  # Together with MMI_EVENT_TIME_MSB, measures the number
    # of microseconds the last took to execute - i.e. the time between when MMI_COMMAND
    # was written to the later of when STATUS_CMD_COMPLETE or STATUS_DATA_COMPLETE goes high.
    MMI_EVENT_TIME_MSB = 15
    MMI_IF_MAX_XFR_BLOCKS = 16  # max number of blocks per transfer supported by the block layer
    MMI_BUF_MAX_XFR_BLOCKS = 17  # max number of blocks in this module's buffers
    MMI_ID_BUF = 18

    # bits of the STATUS_CTRL register
    STATUS_BACKEND_READY = 1 << 0  # the back-end layer is ready (e.g. 'linkup' for SATA)
    STATUS_INITDONE = 1 << 1  # block layer initialization is complete
    STATUS_BUSY = 1 << 2  # busy executing a command
    STATUS_DEVICE_PRESENT = 1 << 3  # drive is physically present
    STATUS_ERR_INVALID = 1 << 8  # the last command was invalid
    STATUS_ERR_BACKEND = 1 << 9  # the backend reported an error (e.g. the SATA device)
    STATUS_ERR_ADAPTER_SIZE = 1 << 10  # image compiled with invalid settings
    STATUS_ERR_INTERNAL = 1 << 11  # internal error (probably RTL bug)
    STATUS_ERROR_MASK = 0xFF00  # error bits in the MMI_STATUS_CTRL register
    STATUS_ERRORS_MSB = 15
    STATUS_ERRORS_LSB = 8

    BACKEND_READY_BIT = 0
    INITDONE_BIT = 1
    BUSY_BIT = 2
    DEVICE_PRESENT_BIT = 3
    ERR_INVALID_BIT = 8
    ERR_BACKEND_BIT = 9
    ERR_ADAPTER_SIZE_BIT = 10
    ERR_INTERNAL_BIT = 11

    # Block commands
    BLOCK_CMD_READ_BLOCKS = 0  # Read one or more sectors from the block device.
    BLOCK_CMD_WRITE_BLOCKS = 1  # Write one or more sectors to the block device.
    BLOCK_CMD_TRIM_BLOCKS = 2  # Trim one or more blocks.
    # If the device does not support trim, this command does nothing.
    BLOCK_CMD_ZERO_BLOCKS = 3  # Zero the data in one or more blocks. If RZAT is supported,
    # it will be used; otherwise, block writes will be used.
    BLOCK_CMD_FLUSH = 4  # Flush the cache. This may take a long time (30 seconds) to complete.


# SATA BB
class BLOCK_BYTE_CTRL:
    MODULE_IDs = {
            0x5362: "SATA Block Byte Layer",
            0x5162: "Zynq QSPI Block Byte Layer",
            # others can be added here
    }

    # Registers
    MMI_MODULE_ID = 0
    MMI_STATUS_CTRL = 1
    MMI_COMMAND = 2
    MMI_BUFSIZE = 3
    MMI_LAST_BYTE0 = 4
    MMI_LAST_BYTE1 = 5
    MMI_LAST_BYTE2 = 6
    MMI_LAST_BYTE3 = 7
    MMI_ADDR0 = 8
    MMI_ADDR1 = 9
    MMI_ADDR2 = 10
    MMI_ADDR3 = 11
    MMI_BYTE_COUNT = 12
    MMI_BUF_DATA = 13
    MMI_EVENT_TIME_LSB = 14
    MMI_EVENT_TIME_MSB = 15
    MMI_BUF_WADDR = 16
    MMI_BUF_RADDR = 17
    MMI_ERR_COUNTER = 18
    MMI_BYTE_COUNT_TRIM1 = 19
    MMI_BYTE_COUNT_TRIM2 = 20
    MMI_BYTE_COUNT_TRIM3 = 21
    MMI_LOG_BLOCK_SIZE = 22
    MMI_ID_BUF = 23

    # bits of the STATUS_CTRL register
    STATUS_BACKEND_READY = 1 << 0  # the back-end layer is ready (e.g. 'linkup' for SATA)
    STATUS_INITDONE = 1 << 1  # block layer initialization is complete
    STATUS_BUSY = 1 << 2  # busy executing a command
    STATUS_DEVICE_PRESENT = 1 << 3  # drive is physically present
    STATUS_ERR_INVALID = 1 << 8  # the last command was invalid
    STATUS_ERR_BACKEND = 1 << 9  # the backend reported an error (e.g. the SATA device)
    STATUS_ERR_ADAPTER_SIZE = 1 << 10  # image compiled with invalid settings
    STATUS_ERR_INTERNAL = 1 << 11  # internal error (probably RTL bug)
    CTRL_MMI_ACTIVE = 1 << 15  # switch between MMI(1) and SDR internal(0) control
    STATUS_ERROR_MASK = 0x7F00  # error bits in the MMI_STATUS_CTRL register
    STATUS_ERRORS_MSB = 14
    STATUS_ERRORS_LSB = 8

    # Status
    BACKEND_READY_BIT = 0
    INITDONE_BIT = 1
    BUSY_BIT = 2
    DEVICE_PRESENT_BIT = 3
    ERR_INVALID_BIT = 8
    ERR_BACKEND_BIT = 9
    ERR_ADAPTER_SIZE_BIT = 10
    ERR_INTERNAL_BIT = 11
    # Control
    MMI_ACTIVE_BIT = 15

    # Block commands
    BLOCK_CMD_READ = 0
    BLOCK_CMD_WRITE = 1
    BLOCK_CMD_TRIM = 2
    BLOCK_CMD_ZERO = 3
    BLOCK_CMD_FLUSH = 4


class BLOCK_BYTE_ALT_CTRL:
    MODULE_IDs = {0x624f: "OBC SSD Interface"}

    # Registers
    MMI_MODULE_ID = 0
    MMI_STATUS_CTRL = 1
    MMI_COMMAND = 2
    MMI_BUFSIZE = 3
    MMI_LAST_BYTE0 = 4
    MMI_LAST_BYTE1 = 5
    MMI_LAST_BYTE2 = 6
    MMI_LAST_BYTE3 = 7
    MMI_ADDR0 = 8
    MMI_ADDR1 = 9
    MMI_ADDR2 = 10
    MMI_ADDR3 = 11
    MMI_BYTE_COUNT0 = 12
    MMI_BYTE_COUNT1 = 13
    MMI_BYTE_COUNT2 = 14
    MMI_BYTE_COUNT3 = 15

    # bits of the STATUS register
    STATUS_BACKEND_READY = 1 << 0  # r: the back-end layer is ready (e.g. 'linkup' for SATA)
    STATUS_INITDONE = 1 << 1  # r: block layer initialization is complete
    STATUS_BUSY = 1 << 2  # r: busy executing a command
    STATUS_DEVICE_PRESENT = 1 << 3  # r: drive is physically present
    CTRL_BYTE_SWAP = 1 << 7  # r/w: byte swap data bytes on mmi_data interface
    STATUS_ERR_INVALID = 1 << 8  # r: the last command was invalid
    STATUS_ERR_BACKEND = 1 << 9  # r: the backend reported an error (e.g. the SATA device)
    STATUS_ERR_ADAPTER_SIZE = 1 << 10  # r: image compiled with invalid settings
    STATUS_ERR_INTERNAL = 1 << 11  # r: internal error (probably RTL bug)
    STATUS_ERROR_MASK = 0x7F00  # error bits in the MMI_STATUS register

    # Block commands
    BLOCK_CMD_READ = 0
    BLOCK_CMD_WRITE = 1
    BLOCK_CMD_TRIM = 2
    BLOCK_CMD_ZERO = 3
    BLOCK_CMD_FLUSH = 4


class MMI_ROREGFILE:
    MMI_GPOUT = 0
    MMI_RADDR = 1
    MMI_RDATA0 = 2


class MMI_WOREGFILE:
    MMI_GPOUT = 0
    MMI_WADDR = 1
    MMI_WDATA0 = 2


class MMI_SATA_PERF:
    CTRL_BIT_CLEAR = 0  # clear counts and times
    CTRL_BIT_ACCUMULATE = 1  # 1=accumulate times; 0=show last event time

    COMMAND_LIST = ["READ", "WRITE", "TRIM", "ZERO", "FLUSH"]


class DAC3XJ8X_CTRL:
    # The internal registers are just named config0 - config127 (matches address)

    ADDR_QMC_ENA = 0x00
    QMC_OFFSETAB_ENA_BIT = 15
    QMC_OFFSETCD_ENA_BIT = 14
    QMC_CORRAB_ENA_BIT = 13
    QMC_CORRCD_ENA_BIT = 12

    ADDR_INTERP = 0x00
    INTERP_MSB = 11
    INTERP_LSB = 8

    ADDR_INV_SINC = 0x00
    INV_SINC_AB_ENA_BIT = 1
    INV_SINC_CD_ENA_BIT = 0

    ADDR_DAC_COMPLIMENT = 0x01
    DACA_COMPLIMENT_BIT = 7
    DACB_COMPLIMENT_BIT = 6
    DACC_COMPLIMENT_BIT = 5
    DACD_COMPLIMENT_BIT = 4

    ADDR_MIXER_CFG = 0x02
    MIXER_ENA_BIT = 6
    MIXER_GAIN_BIT = 5

    ADDR_NCO_ENA = 0x02
    NCO_ENA_BIT = 4

    ADDR_COARSE_DAC = 0x03
    COARSE_DAC_MSB = 15
    COARSE_DAC_LSB = 12

    ADDR_QMC_OFFSETA = 0x08
    QMC_OFFSETA_MSB = 12
    QMC_OFFSETA_LSB = 0

    ADDR_QMC_OFFSETB = 0x09
    QMC_OFFSETB_MSB = 12
    QMC_OFFSETB_LSB = 0

    ADDR_QMC_OFFSETC = 0x0A
    QMC_OFFSETC_MSB = 12
    QMC_OFFSETC_LSB = 0

    ADDR_QMC_OFFSETD = 0x0B
    QMC_OFFSETD_MSB = 12
    QMC_OFFSETD_LSB = 0

    ADDR_QMC_GAINA = 0x0C
    QMC_GAINA_MSB = 10
    QMC_GAINA_LSB = 0

    ADDR_CMIX = 0x0D
    CMIX_MSB = 15
    CMIX_LSB = 12

    ADDR_QMC_GAINB = 0x0D
    QMC_GAINB_MSB = 10
    QMC_GAINB_LSB = 0

    ADDR_QMC_GAINC = 0x0E
    QMC_GAINC_MSB = 10
    QMC_GAINC_LSB = 0

    ADDR_QMC_GAIND = 0x0F
    QMC_GAIND_MSB = 10
    QMC_GAIND_LSB = 0

    ADDR_QMC_PHASEAB = 0x10
    QMC_PHASEAB_MSB = 11
    QMC_PHASEAB_LSB = 0

    ADDR_QMC_PHASECD = 0x11
    QMC_PHASECD_MSB = 11
    QMC_PHASECD_LSB = 0

    ADDR_PHASEOFFSETAB = 0x12
    ADDR_PHASEOFFSETCD = 0x13

    ADDR_PHASEADDAB = 0x14
    ADDR_PHASEADDCD = 0x17

    ADDR_SIF_SYNC = 0x1F
    SIF_SYNC_BIT = 1

    ADDR_PATH_SEL = 0x22
    PATHA_IN_SEL_MSB = 15
    PATHA_IN_SEL_LSB = 14
    PATHB_IN_SEL_MSB = 13
    PATHB_IN_SEL_LSB = 12
    PATHC_IN_SEL_MSB = 11
    PATHC_IN_SEL_LSB = 10
    PATHD_IN_SEL_MSB = 9
    PATHD_IN_SEL_LSB = 8
    PATHA_OUT_SEL_MSB = 7
    PATHA_OUT_SEL_LSB = 6
    PATHB_OUT_SEL_MSB = 5
    PATHB_OUT_SEL_LSB = 4
    PATHC_OUT_SEL_MSB = 3
    PATHC_OUT_SEL_LSB = 2
    PATHD_OUT_SEL_MSB = 1
    PATHD_OUT_SEL_LSB = 0

    ADDR_CLKJESD_DIV = 0x25
    CLKJESD_DIV_MSB = 15
    CLKJESD_DIV_LSB = 13

    ADDR_SERDES_REFCLK_DIV = 0x3B
    SERDES_REFCLK_DIV_MSB = 14
    SERDES_REFCLK_DIV_LSB = 11

    ADDR_INIT_STATE = 0x4A
    INIT_STATE_MSB = 4
    INIT_STATE_LSB = 1

    ADDR_JESD_RESET_N = 0x4A
    JESD_RESET_N_BIT = 0
    LANE_ENA_LSB = 8  # lane 0 enable bit
    LANE_ENA_MSB = 15  # lane 7 enable bit

    # There are 8 alarm registers starting at 0x64.
    # Within each register, bits 7:4 are reserved and read as 0.
    # Bits 3:0 indicate FIFO errors. Bits [15:8] indicate other transceiver errors.
    ADDR_ALARM_LANE_0 = 0x64
    NUM_ALARM_LANE_REGS = 8

    # dac_dac3xj8x_ctrl.sv: NUMDACREGS = 128
    ADDR_WRREQUEST = 128
    ADDR_RDREQUEST = 136

    ADDR_DACCONTROL = 144
    QMC_IOCTRL_BIT = 3

    ADDR_POLLSTATUS = 145
    ADDR_DACSTATUS = 147


# From clk_lmk0482x_ctrl.sv
# MMI_REQ_WORDS = 11
class LMK0482X_CTRL:
    # For enabling/disabling clocks 4 and 5: LDR ADC clk and SYSREF on GLU, BUC ref clk and
    # PCIE_CLK on UTMO
    ADDR_CLKOUT4_5_PD = 0x116
    BIT_CLKOUT4_5_PD = 3

    ADDR_CLKCTRL = 0x2000 + 0
    ADDR_RDREQUEST = 0x2000 + 1
    ADDR_WRREQUEST = 0x2000 + 12


class MDIO_CTRL:
    # PHY addresses on Enclustra moduels:
    Enclustra_PHY_0_ADDR = 0b00011
    Enclustra_PHY_1_ADDR = 0b00111

    MMI_STATUS = 0
    MMI_ADDR = 1
    MMI_WDATA = 2
    MMI_RDATA = 3

    MASK_ADDR_READ = (1 << 15)  # bit 15 of MMI_ADDR: 1=read, 0=write

    # MMI_STATUS bits:
    BIT_STATUS_BUSY = 0  # Busy. Cannot write to ADDR until clear.
    BIT_STATUS_BUSY_ERROR = 1  # Attempted write to ADDR while busy.

    MDIO_REGCR = 0x0D
    MDIO_ADDAR = 0x0E

    REGCR_OP_ADDR = (0x00) << 14  # address
    REGCR_OP_DATA = (0x01) << 14  # data, no post-increment
    REGCR_OP_DATA_POSTINC_RW = (0x02) << 14  # data, post-increment address on read/write
    REGCR_OP_DATA_POSTINC_WO = (0x03) << 14  # data, post-increment address only on write


class AXIS_PROFILE:
    BIT_GPOUT_CLEAR_COUNTS = 1
    BIT_GPOUT_ENABLE_COUNTS = 2

    # yapf: disable
    COUNTS = OrderedDict([
                ('ERRORC', 6),
                ('FRAMEC', 5),
                ('BACKPRESSURE', 4),
                ('STALL', 3),
                ('ACTIVE', 2),
                ('IDLE', 1),
                ('DATAC', 0)])
    # yapf: enable


class MMI_PROFILE:
    BIT_GPOUT_CLEAR_COUNTS = 1
    BIT_GPOUT_ENABLE_COUNTS = 2

    # yapf: disable
    COUNTS = OrderedDict([
            ('ACTIVE_WRITE', 5),
            ('ACTIVE_READ', 4),
            ('IDLE_WRITE', 3),
            ('IDLE_READ', 2),
            ('WRITE_TRANSACTIONS_COUNT', 1),
            ('READ_TRANSACTION_COUNT', 0)])
    # yapf: enable


class AD9361_CTRL:
    ADDR_IO_OUT = 1
    ADDR_IO_IN = ADDR_IO_OUT + 1
    ADDR_RDREQUEST = ADDR_IO_IN + 1
    ADDR_WRREQUEST = ADDR_RDREQUEST + 64  # MMI_REQ_WORDS is 64

    # AD9361_CTRL
    BIT_CTRL_STATE0 = 0
    BIT_CTRL_STATE1 = 1
    BIT_CTRL_STATE2 = 2
    BIT_CTRL_STATE3 = 3
    BIT_CTRL_SPI_MODE = 4
    BIT_CTRL_SPI_INVSCLK = 5

    # AD9361_CTRL + ADDR_IO_OUT
    BIT_IO_OUT_RESETN = 0
    BIT_IO_OUT_SYNC = 1
    BIT_IO_OUT_TXNRX = 2  # Pulled up on transceiver
    BIT_IO_OUT_ENABLE = 3  # Pulled up on transceiver
    BIT_IO_OUT_EN_AGC = 4

    BIT_RSVD = 5
    BIT_RSVD = 6
    BIT_RSVD = 7

    # Connected to IO expander
    BIT_IO_OUT_GP0 = 8
    BIT_IO_OUT_GP1 = 9
    BIT_IO_OUT_GP2 = 10
    BIT_IO_OUT_GP3 = 11
    BIT_IO_OUT_GP4 = 12
    BIT_IO_OUT_GP5 = 13
    BIT_IO_OUT_GP6 = 14
    BIT_IO_OUT_GP7 = 15


class PCAL6524:
    MODULE_IDs = {
            0xF0F0: "Default module ID, please assign a unique value to the SV parameter",
            0x0001: "PCH Backplane",
            0x0002: "PCH TTC Front-End",
            0x0003: "PCH LDR Back-end",
            0x0004: "Alderaan Primary-to-Secondary",
    }

    OUTPUT0 = 0
    OUTPUT1 = 1
    INPUT0 = 2
    INPUT1 = 3
    STATCTRL = 4
    MODULEID = 5


class ADS52J90_CTRL:
    ADDR_CTRL = 0
    ADDR_IO_OUT = 1
    ADDR_WRREQUEST = 2

    # CTRL
    BIT_CTRL_STATE0 = 0
    BIT_CTRL_STATE1 = 1
    BIT_CTRL_STATE2 = 2
    BIT_CTRL_STATE3 = 3
    BIT_CTRL_SPI_MODE = 4
    BIT_CTRL_SPI_INVSCLK = 5
    BIT_CTRL_SPI_STALL_SCLK_N = 6
    BIT_CTRL_PLL_LOCKED = 8
    BIT_CTRL_JESD_RDY = 9
    BIT_CTRL_START_SYSREF = 10

    # IO OUT
    BIT_IO_OUT_RESET = 0
    BIT_IO_OUT_PWRDWN_GBL = 1
    BIT_IO_OUT_PWRDWN_FAST = 2
    BIT_IO_OUT_TXTRIG = 3
    BIT_IO_OUT_CTRLRDY = 4


class PCH_SDR_CTRL:
    ADDR_STATE = 0
    ADDR_FORCEMMI = 1
    ADDR_POWEREN = 2
    ADDR_RESETNS_0 = 3
    ADDR_INITDONES_0 = 4
    ADDR_VERSION = 5
    ADDR_CONFIG_CHECK = 6
    ADDR_PRESENCE = 7
    ADDR_LDREN = 8
    ADDR_HDREN = 9
    ADDR_ALARMS = 10
    ADDR_RESETNS_1 = 11
    ADDR_INITDONES_1 = 12
    ADDR_POWERGOODS = 13
    ADDR_PGFORCELOW = 14
    ADDR_POWEROUTENABLE = 15
    ADDR_COMMIT0 = 16
    NUM_ADDR_COMMITS = 4  # number of consecutive ADDR_COMMIT# registers
    ADDR_BLOCK = 22
    ADDR_HRZN = 23
    ADDR_RESERVED_24 = 24
    ADDR_RESERVED_25 = 25
    ADDR_CHIP_ID_START = 26
    NUM_ADDR_CHIP_ID = 6  # number of consecutive ADDR_CHIP_ID# registers

    DATE_EPOCH = datetime.datetime(2015, 6, 25)  # Kepler's date of incorporation

    class STATE(IntEnum):
        IDLE = 0
        DIGINIT = 1
        SDRINIT = 2
        INITRXTX = 3
        INITPA = 4
        COMMS = 5
        STOPRXTX = 6
        STOPSDR = 7
        OFF = 8
        USERMODE = 9
        INITSSD = 10

    BIT_FORCEMMI = 15

    BIT_RESETN0_CPM = 0
    BIT_RESETN0_TEMP = 1
    BIT_RESETN0_SSD = 2
    BIT_RESETN0_HDR = 3
    BIT_RESETN0_CLK = 4
    BIT_RESETN0_PA = 5
    BIT_RESETN0_RX0 = 6
    BIT_RESETN0_RX1 = 7
    BIT_RESETN0_TX = 8
    BIT_RESETN0_NIC = 9
    BIT_RESETN0_DDR = 10
    BIT_RESETN0_RGMII = 11
    BIT_RESETN0_QSPI = 12
    BIT_RESETN0_BP = 14
    BIT_RESETN0_LDR = 15
    BIT_RESETN1_HRZN = 0
    BIT_RESETN1_PPL_AUR = 1
    BIT_RESETN1_ISL = 2

    # INITDONE has the same bit layout as RESETN

    BIT_PRESENCE_HDR = 0
    BIT_PRESENCE_HORIZON = 1
    BIT_PRESENCE_LDR = 2
    BIT_PRESENCE_HDR_BYP = 4

    BIT_LDR_PWREN = 0
    BIT_LDR_DIGEN = 1
    BIT_LDR_ADCSYNEN = 2
    BIT_LDR_TXEN = 3
    BIT_LDR_RXAEN = 4
    BIT_LDR_RXBEN = 5

    BIT_HDR_DIGEN = 0
    BIT_HDR_RXEN = 1
    BIT_HDR_TXEN = 2
    BIT_HDR_SYNTHEN = 3
    BIT_HDR_PAEN = 4
    BIT_HDR_RXSEL = 5
    BIT_HDR_TXSEL = 6

    BIT_BLOCK_QSPI_EBW = 0
    BIT_BLOCK_SEC_QSPI_EBW = 1
    BIT_BLOCK_ISL_QSPI_EBW = 2

    BIT_HRZN_GLOBAL_PWR = 0
    BIT_HRZN_GLOBAL_RSTN = 1
    BIT_PG_1V2 = 4
    BIT_PG_2V8 = 5
    BIT_HRZN_CAM_PWR_0 = 8
    BIT_HRZN_CAM_PWR_1 = 9
    BIT_HRZN_CAM_PWR_2 = 10
    BIT_HRZN_CAM_PWR_3 = 11


class RSMPCU_SDR_CTRL:
    ADDR_STATE = 0
    ADDR_FORCEMMI = 1
    ADDR_RSVD_2 = 2
    ADDR_RESETNS = 3
    ADDR_INITDONES = 4
    ADDR_VERSION = 5
    ADDR_CONFIG_CHECK = 6
    ADDR_COMMIT0 = 7
    NUM_ADDR_COMMITS = 4  # number of consecutive ADDR_COMMIT# registers
    ADDR_CHIP_ID_START = 11
    NUM_ADDR_CHIP_ID = 6  # number of consecutive ADDR_CHIP_ID# registers
    ADDR_PERIPH_CFG = 17  # see PERIPHERAL_CONFIG enum

    DATE_EPOCH = datetime.datetime(2015, 6, 25)  # Kepler's date of incorporation

    class STATE(IntEnum):
        IDLE = 0
        INIT_CLK = 1
        INIT_DDR = 2
        INIT_ETHERNET = 3
        INIT_NIC = 4
        RUNNING = 5

    BIT_FORCEMMI = 15

    BIT_RESETN_CLK = 0
    BIT_RESETN_NIC = 1
    BIT_RESETN_DDR = 2
    BIT_RESETN_MII_PHY = 3
    BIT_RESETN_MII_MAC = 4
    BIT_RESETN_SGMII_PHY = 5
    BIT_RESETN_SGMII_MAC = 6

    # INITDONE has the same bit layout as RESETN

    class PERIPHERAL_CONFIG(IntEnum):
        I2C0_MUX_MMI = 0  # write 0 for AXI IIC, 1 for mmi_to_i2c


class JESD204_CTRL:
    ADDR_RESET = 0x1  # byte address: 0x004
    ADDR_ILA_SUPPORT = 0x2  # byte address: 0x008
    ADDR_SCRAMBLING = 0x3  # byte address: 0x00C
    ADDR_SYSREF = 0x4  # byte address: 0x010
    ADDR_TEST_MODES = 0x6  # byte address: 0x018
    ADDR_LINK_ERR_STAT = 0x7  # byte address: 0x01C
    ADDR_OCTETS_PER_FRAME = 0x8  # byte address: 0x020
    ADDR_FRAMES_PER_MULTIFRAME = 0x9  # byte address: 0x024
    ADDR_LANES_IN_USE = 0xA  # byte address: 0x028
    ADDR_SUBCLASS_MODE = 0xB  # byte address: 0x02C
    ADDR_RX_BUF_DLY = 0xC  # byte address: 0x030
    ADDR_ERROR_REPORT = 0xD  # byte address: 0x034
    ADDR_SYNC_STAT = 0xE  # byte address: 0x038
    ADDR_DEBUG_STAT = 0xF  # byte address: 0x03C

    BIT_RESET_SLFCLR = 0
    BIT_RESET_FIX = 1
    BIT_RESET_WATCHDOG = 16

    BIT_ILA_SUPPORT = 0

    BIT_SCRAMBLING = 0

    BIT_SYSREF_ALWAYS = 0
    BIT_SYSREF_DELAY = 8
    BIT_SYSREF_RQD_RESYNC = 16

    BIT_TEST_MODES = 0

    BIT_LINK_ERR_STAT_LANES = 0
    BIT_LINK_ERR_STAT_RXBUF_OVRFLW = 29
    BIT_LINK_ERR_STAT_LMFC_ALRM = 30
    BIT_LINK_ERR_STAT_LANEALIGN = 31

    BIT_OCTETS_PER_FRAME = 0

    BIT_FRAMES_PER_MULTIFRAME = 0

    BIT_LANES_IN_USE = 0

    BIT_SUBCLASS_MODE = 0

    BIT_RX_BUF_DLY = 0

    BIT_ERROR_REPORT_CNTEN = 0
    BIT_ERROR_REPORT_SYNCEN = 8

    BIT_SYNC_STAT = 0
    BIT_SYNC_STAT_SYSREF_CAP = 16

    BIT_DEBUG_STAT = 0


class AXIS_BB_WRITER_MMI:
    STATUS_CTRL = 0
    SESS_START_ADDR = 1
    NCO_PHASE_INCR = 4
    NCO_PHASE_OFF = 5
    MAX_WRITE_LEN = 6

    BIT_ENABLE = 0
    BIT_BUSY = 1


class MMI_TO_I2C:
    ADDR_CTRL = 0
    ADDR_SLAVE_ADDR = 1
    ADDR_RX_ACK = 2
    MMI_NUM_CTRL_REGS = 3

    BIT_CTRL_START = 0
    BIT_CTRL_RDY = 1
    BIT_CTRL_READ = 2
    BIT_CTRL_USE_STOP = 3
    ADDR_CTRL_N_BYTES_MSB = 7
    ADDR_CTRL_N_BYTES_LSB = 4
    ADDR_CTRL_IDX_ACTIVE_MSB = 15
    ADDR_CTRL_IDX_ACTIVE_LSB = 8

    ADDR_SLAVE_ADDR_MSB = 6
    ADDR_SLAVE_ADDR_LSB = 0


class SECONDARY_CTRL:
    ADDR_CTRL = 0
    ADDR_IRQ = 1
    ADDR_SECONDARY_DETECT = 2

    BIT_POR_B = 0
    BIT_PS_DONE = 1
    BIT_PS_ERR_OUT = 2
    BIT_BOOTMODE = 3
    BIT_RESET_N = 7
    BIT_PWR_EN = 8


class ZYNQ_SYSMON:
    TEMP = 0x00
    VCC_INT = 0x01
    VCC_AUX = 0x02
    VREF_P = 0x04
    VREF_N = 0x05
    VCC_BRAM = 0x06
    VCC_PSINTLP = 0x0D
    VCC_PSINTFP = 0x0E
    VCC_PSAUX = 0x0F
    FLAG = 0x3E


class UPI_POLL:
    ADDR_CTRL_OLD = 0x0
    ADDR_CTRL = 0x1
    ADDR_POLL_PERIOD = 0x2
    ADDR_REG_OFFSET = 0x4
    BIT_ENABLE = 0
    BIT_IS_POLLING = 1
    UPI_RX_INITDONE = 2


class MMI_TO_SPI:
    ADDR_CTRL = 0
    ADDR_SPI_MAXLEN = 1
    ADDR_SPI_CLKS = 2
    ADDR_MOSI_DATA = 3
    ADDR_MOSI_RADDR = 4
    ADDR_MOSI_WADDR = 5
    ADDR_MISO_DATA = 6
    ADDR_MISO_RADDR = 7
    ADDR_MISO_WADDR = 8
    ADDR_VERSION = 9
    ADDR_SPI_CONFIG = 10
    ADDR_START_DELAY = 11

    # CTRL bits
    BIT_BUSY = 0
    BIT_START = 0

    # SPI_CONFIG bits
    BIT_CPOL = 0
    # bit 1: CPHA is not implemented; it's always 0
    BIT_STALL_CLK = 2


class PPL_CTRL:
    # Register indices
    MMI_STATUS = 0
    MMI_CTRL = 1
    MMI_TX_CH_SWITCH_EARLY_CYCLES = 2
    MMI_TX_NUM_CH = 3
    MMI_RX_NUM_CH = 4
    MMI_TX_CH_REG_SEL = 5
    MMI_RX_CH_REG_SEL = 6
    MMI_TX_CH_CTRL = 7
    MMI_TX_CH_RESERVED_CYCLES = 8
    MMI_RX_CH_CTRL = 9
    MMI_RX_CH_OVERFLOW_LIMIT = 10
    MMI_RX_CH_OVERFLOW_COUNT = 11
    MMI_TX_BIT_COUNT_2 = 13
    MMI_TX_BIT_COUNT_1 = 14
    MMI_TX_BIT_COUNT_0 = 15
    MMI_RX_BIT_COUNT_2 = 17
    MMI_RX_BIT_COUNT_1 = 18
    MMI_RX_BIT_COUNT_0 = 19

    # MMI Status bits
    MMI_STATUS_CHANNEL_UP = 0
    MMI_STATUS_RX_GLOBAL_OVERFLOW_FLAG = 1
    MMI_STATUS_LANES_UP_MSB = 7
    MMI_STATUS_LANES_UP_LSB = 4

    # MMI Control bits
    MMI_CTRL_TX_GLOBAL_ENABLE = 0
    MMI_CTRL_RX_GLOBAL_ENABLE = 1
    MMI_CTRL_RX_GLOBAL_OVERFLOW_COUNT_RESET = 2
    MMI_CTRL_RX_TX_BIT_COUNT_SAMPLE_STB = 3
    MMI_CTRL_RX_TX_BIT_COUNT_RESET_STB = 4

    # MMI TX Channel Control bits
    MMI_TX_CH_CTRL_ENABLE = 0

    # MMI RX Channel Control bits
    MMI_RX_CH_CTRL_ENABLE = 0


class PPL_BACKPRESSURE:
    MMI_LATENCY = 0
    MMI_OVERFLOW = 1
    MMI_TX_NUM_CH = 5
    MMI_RX_NUM_CH = 6
    MMI_DBG_BP = 7


class PRBS_AXIS_SRC_SINK:
    # Register indices
    MMI_CTRL = 0
    MMI_N_CH = 1
    MMI_CH_REG_SEL = 2
    MMI_CH_CTRL = 3
    MMI_CH_TX_FRAME_WORDS = 4
    MMI_CH_TX_BITS_2 = 9
    MMI_CH_TX_BITS_1 = 10
    MMI_CH_TX_BITS_0 = 11
    MMI_CH_RX_BITS_2 = 13
    MMI_CH_RX_BITS_1 = 14
    MMI_CH_RX_BITS_0 = 15
    MMI_CH_RX_BIT_ERRS_2 = 17
    MMI_CH_RX_BIT_ERRS_1 = 18
    MMI_CH_RX_BIT_ERRS_0 = 19
    MMI_CH_RX_TIME_US_2 = 21
    MMI_CH_RX_TIME_US_1 = 22
    MMI_CH_RX_TIME_US_0 = 23

    # MMI Control bits
    MMI_CTRL_TX_EN = 0
    MMI_CTRL_RX_EN = 1
    MMI_CTRL_TX_CLEAR = 2
    MMI_CTRL_RX_CLEAR = 3
    MMI_CTRL_SAMPLE = 4

    # MMI Channel Control bits
    MMI_CH_CTRL_TX_EN = 0
    MMI_CH_CTRL_RX_EN = 1


class AUR_MMI:
    # Register indices
    MMI_STATUS = 0
    MMI_CTRL = 1
    MMI_BERT_FRAME_WORDS = 2
    MMI_RX_FIFO_SIZE = 3
    MMI_BERT_TX_BITS_2 = 5
    MMI_BERT_TX_BITS_1 = 6
    MMI_BERT_TX_BITS_0 = 7
    MMI_BERT_RX_BITS_2 = 9
    MMI_BERT_RX_BITS_1 = 10
    MMI_BERT_RX_BITS_0 = 11
    MMI_BERT_RX_BIT_ERRS_2 = 13
    MMI_BERT_RX_BIT_ERRS_1 = 14
    MMI_BERT_RX_BIT_ERRS_0 = 15
    MMI_BERT_RX_TIME_US_2 = 17
    MMI_BERT_RX_TIME_US_1 = 18
    MMI_BERT_RX_TIME_US_0 = 19

    # STATUS register bits
    STATUS_INITDONE = 0
    STATUS_RESET_IN_PROGRESS = 1
    STATUS_REF_PLL_LOCK = 2
    STATUS_LANE0_UP = 3
    STATUS_CHANNEL_UP = 7
    STATUS_HARD_ERR_LATCHED = 8
    STATUS_SOFT_ERR_LATCHED = 9
    STATUS_CRC_ERR_LATCHED = 10
    STATUS_RX_BACKPRESSURE = 11

    # CTRL register bits
    CTRL_CLEAR_LATCHED = 0
    CTRL_BERT_TX_EN = 8
    CTRL_BERT_RX_EN = 9
    CTRL_BERT_TX_CLEAR = 10
    CTRL_BERT_RX_CLEAR = 11
    CTRL_BERT_SAMPLE = 12


class TXNCO:
    # Register indices
    MMI_CTRL = 0
    MMI_PHASE_INC = 1
    MMI_PHASE_OFF = 2
    MMI_SAMPLE_RATE_HI = 3
    MMI_SAMPLE_RATE_LO = 4

    # CTRL register bits
    CTRL_NCO_EN_BIT = 0
    CTRL_I_EN_BIT = 1
    CTRL_Q_EN_BIT = 2


class ISL_KAM_CTRL_MMI:
    # Register indices
    PCH_STATUS_CTRL = 0
    DELEGATE_STATUS_CTRL = 1
    DELEGATE_COMMAND = 2
    DELEGATE_RESPONSE = 3
    GPIO_VAL = 4
    RESERVED_5 = 5
    POWERON_TIMEOUT_S = 6
    POWERON_REMAINING_S = 7
    RESERVED_8 = 8
    BOOTLOAD_ADDR_2 = 9
    BOOTLOAD_ADDR_1 = 10
    BOOTLOAD_ADDR_0 = 11
    RESERVED_12 = 12
    BOOTLOAD_LEN_2 = 13
    BOOTLOAD_LEN_1 = 14
    BOOTLOAD_LEN_0 = 15
    RESERVED_16 = 16
    INSTRUCTION_ADDR_2 = 17
    INSTRUCTION_ADDR_1 = 18
    INSTRUCTION_ADDR_0 = 19
    RESERVED_20 = 20
    INSTRUCTION_LEN_2 = 21
    INSTRUCTION_LEN_1 = 22
    INSTRUCTION_LEN_0 = 23
    RESERVED_24 = 24
    RESULT_ADDR_2 = 25
    RESULT_ADDR_1 = 26
    RESULT_ADDR_0 = 27
    RESERVED_28 = 28
    RESULT_LEN_2 = 29
    RESULT_LEN_1 = 30
    RESULT_LEN_0 = 31

    # PCH status ctrl register bits
    KAMINO_EN = 0
    STARTUP_COMPLETE = 1
    MASTER_EN = 2
    RESET = 3
    DIAGNOSTICS = 4
    PWR_FAULT_UNFILTERED = 5
    PWR_FAULT_FILTERED = 6
    PRESENT = 15

    # Delegate status ctrl register bits
    INITDONE = 0
    IRQ_BUSY = 1
    DONE = 2

    # Delegate command register bits
    DO_BOOTLOADER = 0
    DO_COMMAND = 1

    # GPIO val register bits
    BUSY = 0
    GPIO1 = 1
    GPIO2 = 2
    GPIO3 = 3
    GPIO4 = 4
    GPIO5 = 5
    GPIO6 = 6
    SS = 7
    BOOT0 = 8
    BOOT1 = 9


class ISL_SUE_CTRL_MMI:
    # Register indices:
    PCH_STATUS_CTRL = 0
    COMMAND = 1
    RESPONSE = 2
    GPIO_VAL = 4
    POWERON_TIMEOUT_S = 6
    POWERON_REMAINING_S = 7

    # PCH status ctrl register bits
    BIT_MASTER_EN = 0
    BIT_USER_RESET = 1
    BIT_QSPI_MUX_CTRL = 2
    BIT_GLOBAL_FAULT = 8
    BIT_PRESENT = 15


class RFOE_CTRL:
    # Register indices
    VERSION = 0
    CTRL_STATUS = 1
    OVERFLOW = 2
    TRAILER_MISSING = 3
    REF_TIMESTAMP_SECONDS = 4
    REF_TIMESTAMP_SAMPLE_COUNT = 6
    SINK_TIMESTAMP_SECONDS = 10
    SINK_TIMESTAMP_SAMPLE_COUNT = 12
    SRC_TIMESTAMP_SECONDS = 16
    SRC_TIMESTAMP_SAMPLE_COUNT = 18
    SRC_UDP_IN_ERR = 22
    SINK_PKT_COUNT = 23
    SRC_GOOD_PKT_COUNT = 25
    SRC_BAD_PKT_COUNT = 27
    SRC_LATE_PKT_COUNT = 29
    SRC_PADDING_COUNT = 31
    SINK_SAMPLE_RATE = 33
    SRC_SAMPLE_RATE = 35

    # ctrl_status bits
    CTRL_SINK_SSI_IN_EN = 0
    CTRL_SINK_UDP_OUT_EN = 1
    CTRL_SRC_SSI_OUT_EN = 2
    CTRL_SRC_UDP_IN_EN = 3
    CTRL_REF_TIMESTAMP_VALID = 4
    CTRL_REF_TIMESTAMP_MMICTRL = 5
    CTRL_SINK_TIMESTAMP_VALID = 6
    CTRL_SRC_TIMESTAMP_VALID = 7
    CTRL_CLEAR_PKT_COUNTS_STB = 8

    # overflow bits
    OVERFLOW_SINK_SAMPLE_FIFO_OVERFLOW = 0
    OVERFLOW_SRC_FRAME_FIFO_OVERFLOW = 1
    OVERFLOW_SRC_SAMPLE_FIFO_UNDERFLOW = 2
    OVERFLOW_SRC_SAMPLE_FIFO_OVERFLOW = 3

class DAC_AD5601_CTRL_MMI:
    ADDR_MODULE_ID = 0
    ADDR_MODULE_VERSION = 1
    ADDR_DAC_REG = 2
    ADDR_EN_MMI_CTRL = 3
