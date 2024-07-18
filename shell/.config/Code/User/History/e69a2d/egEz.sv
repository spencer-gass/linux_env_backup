// CONFIDENTIAL
// Copyright (c) 2019-2021 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`default_nettype none

`include "board_hsd_config.svh"

`define DEFINED(A) `ifdef A 1 `else 0 `endif


// Auto-calculated defines (based on the ENABLES).

`define N_PL_SATA 0 /* unless redefined below */

/*
 * SATA_FIFO_ADDRESS_WIDTH determines the size of the SATA buffers:
 * 4 * 2**SATA_FIFO_ADDRESS_WIDTH words. SATA_FIFO_ADDRESS_WIDTH==11 (2048 dwords = 8KiB)
 * is the nysa-sata default. Anything larger requires data to be sent over multiple SATA frames.
 */
`define SATA_0_FIFO_ADDRESS_WIDTH 13
`define SATA_1_2_3_FIFO_ADDRESS_WIDTH 12
`ifdef ENABLE_SSD_CTRL
    `undef N_PL_SATA

    `ifdef ENABLE_UPPER_SSDS
        `define N_PL_SATA 3
    `else
        `define N_PL_SATA 1
    `endif

    `define REQUIRE_GTH230_CLK 1
    `define REQUIRE_GTH230_LANES 1
    `define GTH230_LANES_TOP (`N_PL_SATA-1)
    `define GTH230_LANES_BOTTOM 0
`endif

// Verilog doesn't have 0-length arrays. If `N_PL_SATA == 0, then this macro helps us make
// a [0:0] array instead of a [-1:0] array.
`define PL_SATA_ARRAY_DEF [UTIL_INTS::S_INT_MAX(0, `N_PL_SATA-1) : 0]


import BOARD_HSD_CTRL_PARAMS::*;

/**
 * Top-level for HSD.
 */
module board_hsd_top (
    // External clocks
    input   var logic               PIN33M_PL_CLK,

    // Power enables. Normally high-impedance. Pull strongly to change from power-on condition.
    inout   tri  logic              EN_1V2PSDDR,
    inout   tri  logic              EN_ADC1,
    inout   tri  logic              EN_ADC2,
    inout   tri  logic              EN_CLK_CHIP,
    inout   tri  logic              EN_DAC,
    inout   tri  logic              EN_MGTAVCC,
    inout   tri  logic              EN_PLDDR,
    inout   tri  logic              EN_PLETH,
    inout   tri  logic              EN_PS1V8,
    inout   tri  logic              EN_PSETH,
    inout   tri  logic              EN_PSFP,
    inout   tri  logic              EN_PSFP2,
    inout   tri  logic              EN_PSLP,
    output  var  logic              SHUT_DOWN_N,

    // Power-good signals
    inout  tri   logic              DAC_VCC0V9_PG,
    inout  tri   logic              DAC_VCC3V3_PG,
    inout  tri   logic              MGTAVCC_0V9_PG,
    inout  tri   logic              VCC1V12_PG,
    inout  tri   logic              VCC1V8LDO_PG,
    inout  tri   logic              VCC1V8_PG,
    inout  tri   logic              VCC1V95_PG,
    inout  tri   logic              VCC2V5_PG,
    inout  tri   logic              VCC3V5_PG,
    inout  tri   logic              VCC5V_PG,
    inout  tri   logic              VCCA1V2_PG,
    inout  tri   logic              VCCDDR_PG,

    // Power monitors
    inout   tri  logic              POWSENSE_SCL,
    inout   tri  logic              POWSENSE_SCL2,
    inout   tri  logic              POWSENSE_SDA,
    inout   tri  logic              POWSENSE_SDA2,
    input   var  logic              ALERT_CORE,
    input   var  logic              ALERT_DDR,
    input   var  logic              ALERT_IO,
    input   var  logic              ALERT_LDO,

    // 3.3V SPI master
    inout   tri  logic              SCLK_3V3,
    inout   tri  logic              MOSI_3V3,
    inout   tri  logic              CS_CLK,
    inout   tri  logic              CS_TMP1,
    inout   tri  logic              CS_TMP2,

    // 1.8V SPI master
    inout   tri  logic              SCLK_1V8,
    inout   tri  logic              MOSI_1V8,
    inout   tri  logic              MISO_1V8,
    inout   tri  logic              CS_DAC,
    inout   tri  logic              CS_1_ADC,
    inout   tri  logic     [2:1]    CS_1_VGA,
    inout   tri  logic              CS_2_ADC,
    inout   tri  logic     [2:1]    CS_2_VGA,

    // Front-end bank 1
    inout   tri  logic    [22:1]    FE1_IO,
    inout   tri  logic              FE1_IO23_N,
    inout   tri  logic              FE1_IO23_P,
    inout   tri  logic              FE1_IO24_N,
    inout   tri  logic              FE1_IO24_P,
    inout   tri  logic              FE1_PRST,       // FE presence detect
    input   var  logic              VCC1_SEL,       // FE voltage level detect

    // Front-end bank 2
    inout   tri  logic    [22:1]    FE2_IO,
    inout   tri  logic              FE2_IO23_N,
    inout   tri  logic              FE2_IO23_P,
    inout   tri  logic              FE2_IO24_N,
    inout   tri  logic              FE2_IO24_P,
    inout   tri  logic              FE2_PRST,       // FE presence detect
    input   var  logic              VCC2_SEL,       // FE voltage level detect



    // Clock chip stuff?
    inout   tri  logic              CLK_RESET,
    inout   tri  logic              CLK_SYNC,

    // Other IO. (We don't do actual PCIe in this design.)
    input   var  logic              PCIE_RST_N,     // global reset
    input   var  logic              PCIE_WAKE,      // secondary-detect
    inout   tri  logic    [20:1]    LVDS_PCIE_N,
    inout   tri  logic    [20:1]    LVDS_PCIE_P,

`ifdef REQUIRE_GTH230_CLK
    // Reference clock for SATA lanes
    input   var  logic              DCLKOUT2_N,
    input   var  logic              DCLKOUT2_P,
`endif // REQUIRE_GTH230_CLK
`ifdef REQUIRE_GTH230_LANES
    input   var  logic  [`GTH230_LANES_TOP:`GTH230_LANES_BOTTOM]    GTH230_PCIE_RX_N,
    input   var  logic  [`GTH230_LANES_TOP:`GTH230_LANES_BOTTOM]    GTH230_PCIE_RX_P,
    output  var  logic  [`GTH230_LANES_TOP:`GTH230_LANES_BOTTOM]    PCIE_TX_N,
    output  var  logic  [`GTH230_LANES_TOP:`GTH230_LANES_BOTTOM]    PCIE_TX_P,
`endif // REQUIRE_GTH230_LANES

    // PL Ethernet
    output  var  logic              ENET_GTX_CLK,
    output  var  logic              ENET_RESET_N,
    input   var  logic              ENET_RX_CLK,
    input   var  logic              ENET_RX_CTRL,
    input   var  logic     [3:0]    ENET_RX_D,
    output  var  logic              ENET_TX_CTRL,
    output  var  logic     [3:0]    ENET_TX_D,
    output  var  logic              ENET_MDC,
    inout   tri  logic              ENET_MDIO,

    // PL-DDR
`ifdef ENABLE_PL_DDR
    input   var  logic              CLK_DDR_PL_N,
    input   var  logic              CLK_DDR_PL_P,
    output  var  logic              PL_1V8_DDR_RST_N,
    output  var  logic    [16:0]    PL_DDR_A,
    output  var  logic              PL_DDR_ACT_N,
    output  var  logic     [1:0]    PL_DDR_BA,
    output  var  logic              PL_DDR_BG0,
    output  var  logic              PL_DDR_CK0_N,
    output  var  logic              PL_DDR_CK0_P,
    output  var  logic              PL_DDR_CKE0,
    output  var  logic              PL_DDR_CS_N0,
    inout   tri  logic     [1:0]    PL_DDR_DM,
    inout   tri  logic    [15:0]    PL_DDR_DQ,
    inout   tri  logic     [1:0]    PL_DDR_DQS_N,
    inout   tri  logic     [1:0]    PL_DDR_DQS_P,
    output  var  logic              PL_DDR_ODT,
    // PL_DDR_PARITY is not actually used in DD4, instantiating it breaks the MIG
//  output  logic                   PL_DDR_PARITY,
`endif // ENABLE_PL_DDR

    // The KAD5512p50 ADCs
    input   var  logic    [11:0]    ADC1_DATA_N,
    input   var  logic    [11:0]    ADC1_DATA_P,
    inout   tri  logic              ADC1_DVGA_PD,
    input   var  logic              ADC1_OCLK_N,
    input   var  logic              ADC1_OCLK_P,
    input   var  logic              ADC1_OR_N,
    input   var  logic              ADC1_OR_P,
    inout   tri  logic              ADC1_RESETN,
    input   var  logic    [11:0]    ADC2_DATA_N,
    input   var  logic    [11:0]    ADC2_DATA_P,
    inout   tri  logic              ADC2_DVGA_PD,
    input   var  logic              ADC2_OCLK_N,
    input   var  logic              ADC2_OCLK_P,
    input   var  logic              ADC2_OR_N,
    input   var  logic              ADC2_OR_P,
    inout   tri  logic              ADC2_RESETN,

    inout   tri  logic              DAC_ALARM,
    inout   tri  logic              DAC_RESETB,
`ifdef ENABLE_TX_SDR
`ifdef TXDAC_1200MSPS
    output  var  logic     [7:0]    DAC_RX_N,
    output  var  logic     [7:0]    DAC_RX_P,
`else
    output  var  logic     [3:0]    DAC_RX_N,
    output  var  logic     [3:0]    DAC_RX_P,
`endif
`endif
    input   var  logic              DAC_SOC_CLK_N,
    input   var  logic              DAC_SOC_CLK_P,
    input   var  logic              DAC_SOC_SYSREF_N,
    input   var  logic              DAC_SOC_SYSREF_P,
    inout   tri  logic              DAC_SYNC_N,
    inout   tri  logic              DAC_SYNC_N_AB,
    inout   tri  logic              DAC_SYNC_N_CD,
    inout   tri  logic              DAC_SYNC_P,
    inout   tri  logic              DAC_TXENABLE,

    // OBC signals
    output  var  logic     [1:0]    OBC_GPIO,
    inout   tri  logic    [14:1]    MARK,

    // System Monitor Pins
    input   var  logic              VP,
    input   var  logic              VN
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    import MMI_ADDRS_HSD::*;
    import BOARD_HSD_SATA_MUX_INDICES::*;
    import BOARD_HSD_DDR::*;
    import BOARD_HSD_BB_DEVICES::*;
    import BOARD_HSD_ETH_PKG::*;
    import BOARD_HSD_SPI_MUX_PKG::*;

    localparam int      DSPNBITS = 16;

    // The size of the SATA block as seen by the simpletoga interface (i.e. not
    // accounting for FEC); should be equal to the lesser of RX,TX packet size
    localparam int SIMPLETOGA_SMALLER_PKTSIZE = UTIL_INTS::U_INT_MIN(`SIMPLETOGA_RX_PKTSIZE, `SIMPLETOGA_TX_PKTSIZE);
    localparam int SIMPLETOGA_LARGER_PKTSIZE = UTIL_INTS::U_INT_MAX(`SIMPLETOGA_RX_PKTSIZE, `SIMPLETOGA_TX_PKTSIZE);
    // Note: MMIoE max packet size is set by SIMPLETOGA_TX_PKTSIZE, TDI max pkt size is hard-coded to 512 bytes
    // TODO: It would be cleaner to have the MMIoE and TDI max packet sizes set separately in board_hsd_config
    localparam int MAX_PKTSIZE = `DEFINED(ENABLE_RFOE) ? UTIL_INTS::U_INT_MAX(SIMPLETOGA_LARGER_PKTSIZE, `RFOE_PAYLOAD_BYTES)
                                             : SIMPLETOGA_LARGER_PKTSIZE;

    localparam int BLOCK_EXPONENT = ($clog2(SIMPLETOGA_SMALLER_PKTSIZE/512) > 3) ?
                                     3 : $clog2(SIMPLETOGA_SMALLER_PKTSIZE/512);

    // clksys is driven by the PS.
    // Set this parameter equal to the frequency configured in the BD
    localparam CLKSYS_FREQ      = 125_000_000;

    // Peripheral bus frequencies
    localparam MDIO_FREQ        =   2_500_000;
    localparam SYS_SPI_FREQ     =     400_000;
    localparam SDR_SPI_FREQ     =     400_000;
    localparam HDR_SPI_FREQ     =     200_000;
    localparam KAS_SPI_3V3_FREQ =     200_000;  // AD5601 DAC: 30 MHz max, LMX2592 Synth (x2): 100 MHz max
    localparam KAS_SPI_1V8_FREQ =     200_000;  // ADMV1013 MOD: 50 MHz max
    localparam KAS_IOEXP_FREQ   =     200_000;  // SN74LV595: 50 MHz max
    localparam KAS_I2C_FREQ     =     100_000;  // INA230 (x7): , TODO: list the rest
    localparam BP_I2C_FREQ      =     100_000;  //

    // Peripheral bus clock dividers
    localparam MDIO_CLKDIV           = CLKSYS_FREQ / MDIO_FREQ;
    localparam SYS_SPI_CLKDIV        = 2 * (CLKSYS_FREQ / (2 * SYS_SPI_FREQ));      // Multiple of 2
    localparam SDR_SPI_CLKDIV        = 2 * (CLKSYS_FREQ / (2 * SDR_SPI_FREQ));      // Multiple of 2
    localparam HDR_SPI_CLKDIV        = 2 * (CLKSYS_FREQ / (2 * HDR_SPI_FREQ));      // Multiple of 2
    localparam KAS_SPI_3V3_CLKDIV    = 2 * (CLKSYS_FREQ / (2 * KAS_SPI_3V3_FREQ));  // Multiple of 2
    localparam KAS_SPI_1V8_CLKDIV    = 2 * (CLKSYS_FREQ / (2 * KAS_SPI_1V8_FREQ));  // Multiple of 2
    localparam KAS_IOEXP_HALF_CLKDIV = CLKSYS_FREQ / (2 * KAS_IOEXP_FREQ);
    localparam KAS_I2C_CLKDIV        = 4 * (CLKSYS_FREQ / (4 * KAS_I2C_FREQ));      // Multiple of 4
    localparam BP_I2C_CLKDIV         = 4 * (CLKSYS_FREQ / (4 * BP_I2C_FREQ));       // Multiple of 4

    // Indicies of MMI bus masters. Lower values have higher priority.
    typedef enum {
        MMI_MASTER_SPI,
        MMI_MASTER_ZYNQ,
        MMI_MASTER_MMIOE,
        NUM_MMI_MASTERS
    } mmi_masters_t;

    // Status bits for MMI firewall
    // 0 = output, 1:NUM_MMI_MASTERS = inputs
    logic   [3:0]   mmi_fw_violations   [NUM_MMI_MASTERS:0];
    logic   [3:0]   zynq_fw_violations  [BOARD_HSD_MMI32_PARAMS::MMI32_NDEVS:0];

    // Indices for clock divider setting
    typedef enum {
        I2C_CLK_DIV_SYSTEM_IDX,
        I2C_CLK_DIV_BP_IDX,
        I2C_CLK_DIV_HDR_IDX,
        I2C_CLK_DIV_KAS_IDX,
        NUM_I2C_CLK_DIV_IDX
    } i2c_clk_divider_idx_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elab checks for the config defines


    // TXDAC JESD features can only be enabled if the DAC is enabled
    `ELAB_CHECK_LE(`DEFINED(TXDAC_JESD204C), `DEFINED(ENABLE_TX_SDR));
    `ELAB_CHECK_LE(`DEFINED(TXDAC_1200MSPS), `DEFINED(ENABLE_TX_SDR));

    // No more than one radio front-end can be present
    `ELAB_CHECK_LE(`DEFINED(ENABLE_HDR)+`DEFINED(ENABLE_KAS), 1);

    // Only 1 demodulator should be enabled
    `ELAB_CHECK_LE(`DEFINED(ENABLE_RXDVBS2)+`DEFINED(ENABLE_DSSS_RX), 1);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    // Replacements for ports that can be ifdef'd out:
`ifndef REQUIRE_GTH230_CLK
    logic                           DCLKOUT2_N;
    logic                           DCLKOUT2_P;
    assign                          DCLKOUT2_N = 1'bX;
    assign                          DCLKOUT2_P = 1'bX;
`endif
`ifndef ENABLE_SSD_CTRL
    logic       `PL_SATA_ARRAY_DEF  fake_ssd_RX_N;
    logic       `PL_SATA_ARRAY_DEF  fake_ssd_RX_P;
    logic       `PL_SATA_ARRAY_DEF  fake_ssd_TX_N;
    logic       `PL_SATA_ARRAY_DEF  fake_ssd_TX_P;
    assign                          fake_ssd_RX_N = 'X;
    assign                          fake_ssd_RX_P = 'X;
    assign                          fake_ssd_TX_N = 'X;
    assign                          fake_ssd_TX_P = 'X;
`endif
`ifndef ENABLE_TX_SDR
    logic      [7:0]        DAC_RX_N, DAC_RX_P;
`endif


    // Clocks and resets.
    logic   pl_clk0_sys_drv, pl_clk1_300_drv, pl_clk2_125_drv, pl_clk3_200_drv;

    logic   clk_lpd;        // Clock for LPD AXI interface

    logic   clksys_pl, sresetn_pl;
    logic   clksys_drv, sresetn;

    logic   global_alarm_irq;   // An input to the OBC IRQ controller

    // AXI4 LPD bus (ARM master)
    AXI4_int #(
        .DATALEN    ( 32 ),
        .ADDRLEN    ( 40 )
    ) axi_lpd_m (
        .clk        ( clk_lpd       ),
        .sresetn    ( sresetn       )
    );

    // AXI4 LPD bus (FPGA master)
    AXI4_int #(
        .DATALEN    ( 32 ),
        .ADDRLEN    ( 40 ),
        .WIDLEN     ( 6 ),
        .RIDLEN     ( 6 )
    ) axi_lpd_s (
        .clk        ( clk_lpd       ),
        .sresetn    ( sresetn       )
    );


    // The AXI bus is 32-bits wide. PSU registers only seems to respond correctly to 32-bit wide reads.
    // (The AXI protocol permits unaligned and narrow transfers, but devices are not required to support them.)
    // Therefore, we use a 32-bit wide mmi_lpd_s, so that we are generating 32-bit accesses on axi_lpd_s.
    //TODO: Would it work if we allowed the transfers we generate as master to be "modifiable"?
    MemoryMap_int #(
        .DATALEN    ( 32 ),
        .ADDRLEN    ( 38 )
    ) mmi_lpd_s ();

    // The init_ctrl output side of mmi_lpd_s.
    MemoryMap_int #(
        .DATALEN    ( 32 ),
        .ADDRLEN    ( 38 )
    ) mmi_lpd_init_s ();

    // Demuxed MMI32 interfaces
    MemoryMap_int #(
        .DATALEN ( BOARD_HSD_MMI32_PARAMS::MMI32_DEV_DATALEN ),
        .ADDRLEN ( BOARD_HSD_MMI32_PARAMS::MMI32_DEV_ADDRLEN )
    ) mmi32_dev [BOARD_HSD_MMI32_PARAMS::MMI32_NDEVS-1:0] ();

    PhaseLockedLoop_int # (.CLKIN_PERIOD(8), .CLKFB_MULT_F(8), .N_CLKS(1), .DIVIDE ('{4}), .DEVICE_TYPE (2) )
        rgmii_idelay_pll  ( .clk(pl_clk2_125_drv), .reset_n (rgmii_ctrl.sresetn));

    MDIO_IO_int #(
        .CLK_DIVIDE     ( MDIO_CLKDIV )  // MDIO runs on a 2.5 MHz clock
    ) pl_eth_mdio_io ();


    PowerCtrl_int #(
        .NUM_EN     ( PWR_PKG_HSD::NUM_EN   ),
        .NUM_PG     ( PWR_PKG_HSD::NUM_PG   ),
        .INITIAL_ENABLE_VALUES      ( PWR_PKG_HSD::INITIAL_ENABLE_VALUES     ),
        .INITIAL_OUTENABLE_VALUES   ( PWR_PKG_HSD::INITIAL_OUTENABLE_VALUES  )
    ) pwr_ctrl ();

    Sysmon_Zynq_int #(
        .CONFIG          (SYSMON4_INT_PKG::CONFIG),
        .SEQUENCE        (SYSMON4_INT_PKG::SEQUENCE),
        .ALARM_LIMIT     (SYSMON4_INT_PKG::ALARM_LIMIT),
        .USER_ALARMS     (SYSMON4_INT_PKG::USER_ALARMS)
    ) sysmon ( .clk (clksys_drv), .sresetn(sresetn) );

    SPIIO_int #( .SSNLEN( 1 ) ) obc_spi ();
    // multiple MMI masters
    MemoryMap_int #(
        .DATALEN( MMI_DATALEN ),
        .ADDRLEN( MMI_ADDRLEN )
    ) mmi_masters   [NUM_MMI_MASTERS-1:0]   ();

    logic   [NUM_MMI_MASTERS-1:0]   mmi_masters_read_arb_lock;
    logic   [NUM_MMI_MASTERS-1:0]   mmi_masters_write_arb_lock;


    // output of MMI master arbiter; input to MMI device demux
    MemoryMap_int #(
        .DATALEN( MMI_DATALEN ),
        .ADDRLEN( MMI_ADDRLEN )
    ) mmi_demux_in ();

    // memory Demux from devices side write
    MemoryMap_int #(
        .DATALEN( MMI_DATALEN ),
        .ADDRLEN( MMI_ADDRLEN )
    ) mmi_dev [MMI_NDEVS-1:0] ();

    logic clk_ddr;
    logic sreset_ddr;

    // Inputs to the MMI_DDR arbiter
    MemoryMap_int #(
        .DATALEN( MMI_DDR_DATALEN ),
        .ADDRLEN( MMI_DDR_ADDRLEN )
    ) mmi_ddr_arbiter_in [DDR_NUM_INDICES-1:0] ();

    // Output from the MMI_DDR arbiter
    MemoryMap_int #(
        .DATALEN( MMI_DDR_DATALEN ),
        .ADDRLEN( MMI_DDR_ADDRLEN )
    ) mmi_ddr_arbiter_out ();

    // Interfaces for SPI and I2C
    SPIIO_int # (.SSNLEN (3),                       .CLK_DIVIDE(SYS_SPI_CLKDIV))      sys_spi ();
    SPIIO_int # (.SSNLEN (7),                       .CLK_DIVIDE(SDR_SPI_CLKDIV))      sdr_spi ();
    SPIIO_int # (.SSNLEN (3),                       .CLK_DIVIDE(HDR_SPI_CLKDIV))      hdr_spi ();
    SPIIO_int # (.SSNLEN (KAS_SPI_3V3_NUM_SLAVES),  .CLK_DIVIDE(KAS_SPI_3V3_CLKDIV))  kas_spi_3v3 ();
    SPIIO_int # (.SSNLEN (KAS_SPI_1V8_NUM_DEVICES), .CLK_DIVIDE(KAS_SPI_1V8_CLKDIV))  kas_spi_1v8 ();

    I2CIO_int sys_i2c [1:0] ();
    I2CIO_int hdr_i2c       ();
    I2CIO_int kas_i2c       ();
    I2CIO_int bp_i2c        ();

    IOEXP_SerialOut_int kas_ioexp ();

    // All the controller interfaces are instantiated here
    SDR_Ctrl_int #( .STATELEN (1) ) cpm_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) lmk_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) temp_ctrl           ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) rx0_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) tx_ctrl             ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) hdr_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) kas_ctrl            ( .clk ( clksys_drv ) );
    var logic kas_vstby_initdone; // TODO (cbrown): handle this properly
    SDR_Ctrl_int #( .STATELEN (32) )hdrpa_ctrl          ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) bp_ctrl             ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) nic_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) ssd_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) qspi_ctrl           ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) rgmii_ctrl          ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) ddr_ctrl            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) upi_poll            ( .clk ( clksys_drv ) );
    SDR_Ctrl_int #( .STATELEN (1) ) dsss_ctrl           ( .clk ( clksys_drv ) );

    //Control interface for the block devices
    BlockSoftCtrl_int qspi_bctrl ();

    // The peripheral interfaces
    IRQ_IO_int obc_irq_io ();
    // The IRQ enums are defined in board_hsd_ctrl_params.sv.
    logic   [NUM_OBC_IRQS-1:0]  obc_irq_in;
    logic   [NUM_ZYNQ_IRQS-1:0] zynq_irq_in;

    CLK_LMK04828_int # (
        .NUMSPISTEPS    ( CLK_LMK04828_HSD::NUMSPISTEPS    ),
        .SPI_INITREG    ( CLK_LMK04828_HSD::SPI_INITREG    ),
        .SPI_INITVAL    ( CLK_LMK04828_HSD::SPI_INITVAL    ),
        .BLINK_LED_ADDR ( CLK_LMK04828_HSD::BLINK_LED_ADDR ),
        .BLINK_LED_ON   ( CLK_LMK04828_HSD::BLINK_LED_ON   ),
        .BLINK_LED_OFF  ( CLK_LMK04828_HSD::BLINK_LED_OFF  )
    ) lmk ();

    // Same limits as board_pch_*, since the PCH hardware is identical to the ones used in Alderaan
    CPM_INA23x_int #(
        .NUM_MONITORS  ( CPM_INA230_PCH_SYS0::NUM_MONITORS    ),
        .CTRL_CLOCK_FREQ(CPM_INA230_PCH_SYS0::CTRL_CLOCK_FREQ ),
        .POLL_PERIOD   ( CPM_INA230_PCH_SYS0::POLL_PERIOD     ),
        .POLL_MASK     ( CPM_INA230_PCH_SYS0::POLL_MASK       ),
        .VAL_CONF00    ( CPM_INA230_PCH_SYS0::VAL_CONF00      ),
        .VAL_CAL05     ( CPM_INA230_PCH_SYS0::VAL_CAL05       ),
        .VAL_MASKEN06  ( CPM_INA230_PCH_SYS0::VAL_MASKEN06    ),
        .VAL_ALIMIT07  ( CPM_INA230_PCH_SYS0::VAL_ALIMIT07    ),
        .I2C_ADDRESS   ( CPM_INA230_PCH_SYS0::I2C_ADDRESS     ),
        .OVER_VOLT_INIT( CPM_INA230_PCH_SYS0::OVER_VOLT_INIT  )
    ) sys_0_cpm ();

    // Same limits as board_pch_*, since the PCH hardware is identical to the ones used in Alderaan
    CPM_INA23x_int #(
        .NUM_MONITORS  ( CPM_INA230_PCH_SYS1::NUM_MONITORS   ),
        .CTRL_CLOCK_FREQ(CPM_INA230_PCH_SYS1::CTRL_CLOCK_FREQ ),
        .POLL_PERIOD   ( CPM_INA230_PCH_SYS1::POLL_PERIOD    ),
        .POLL_MASK     ( CPM_INA230_PCH_SYS1::POLL_MASK      ),
        .VAL_CONF00    ( CPM_INA230_PCH_SYS1::VAL_CONF00     ),
        .VAL_CAL05     ( CPM_INA230_PCH_SYS1::VAL_CAL05      ),
        .VAL_MASKEN06  ( CPM_INA230_PCH_SYS1::VAL_MASKEN06   ),
        .VAL_ALIMIT07  ( CPM_INA230_PCH_SYS1::VAL_ALIMIT07   ),
        .I2C_ADDRESS   ( CPM_INA230_PCH_SYS1::I2C_ADDRESS    ),
        .OVER_VOLT_INIT( CPM_INA230_PCH_SYS1::OVER_VOLT_INIT )
    ) sys_1_cpm ();

`ifdef LBAND
    `define CPM_INA230_HSD_HDR CPM_INA230_HSD_L_HDR
`else
    `define CPM_INA230_HSD_HDR CPM_INA230_HSD_KU_HDR
`endif
    CPM_INA23x_int #(
        .NUM_MONITORS  ( `CPM_INA230_HSD_HDR::NUM_MONITORS      ),
        .CTRL_CLOCK_FREQ(`CPM_INA230_HSD_HDR::CTRL_CLOCK_FREQ   ),
        .POLL_PERIOD   ( `CPM_INA230_HSD_HDR::POLL_PERIOD       ),
        .POLL_MASK     ( `CPM_INA230_HSD_HDR::POLL_MASK         ),
        .VAL_CONF00    ( `CPM_INA230_HSD_HDR::VAL_CONF00        ),
        .VAL_CAL05     ( `CPM_INA230_HSD_HDR::VAL_CAL05         ),
        .VAL_MASKEN06  ( `CPM_INA230_HSD_HDR::VAL_MASKEN06      ),
        .VAL_ALIMIT07  ( `CPM_INA230_HSD_HDR::VAL_ALIMIT07      ),
        .I2C_ADDRESS   ( `CPM_INA230_HSD_HDR::I2C_ADDRESS       ),
        .OVER_VOLT_INIT( `CPM_INA230_HSD_HDR::OVER_VOLT_INIT    )
    ) hdr_cpm ();

    CPM_INA23x_int #(
        .NUM_MONITORS  ( CPM_INA230_HSD_KAS::NUM_MONITORS      ),
        .CTRL_CLOCK_FREQ(CPM_INA230_HSD_KAS::CTRL_CLOCK_FREQ   ),
        .POLL_PERIOD   ( CPM_INA230_HSD_KAS::POLL_PERIOD       ),
        .POLL_MASK     ( CPM_INA230_HSD_KAS::POLL_MASK         ),
        .VAL_CONF00    ( CPM_INA230_HSD_KAS::VAL_CONF00        ),
        .VAL_CAL05     ( CPM_INA230_HSD_KAS::VAL_CAL05         ),
        .VAL_MASKEN06  ( CPM_INA230_HSD_KAS::VAL_MASKEN06      ),
        .VAL_ALIMIT07  ( CPM_INA230_HSD_KAS::VAL_ALIMIT07      ),
        .I2C_ADDRESS   ( CPM_INA230_HSD_KAS::I2C_ADDRESS       ),
        .OVER_VOLT_INIT( CPM_INA230_HSD_KAS::OVER_VOLT_INIT    )
    ) kas_cpm ();

    `define BP_CPM_PKG CPM_INA230_HSD_GLU

    CPM_INA23x_int #(
        .NUM_MONITORS  ( `BP_CPM_PKG::NUM_MONITORS      ),
        .CTRL_CLOCK_FREQ(`BP_CPM_PKG::CTRL_CLOCK_FREQ   ),
        .POLL_PERIOD   ( `BP_CPM_PKG::POLL_PERIOD       ),
        .POLL_MASK     ( `BP_CPM_PKG::POLL_MASK         ),
        .VAL_CONF00    ( `BP_CPM_PKG::VAL_CONF00        ),
        .VAL_CAL05     ( `BP_CPM_PKG::VAL_CAL05         ),
        .VAL_MASKEN06  ( `BP_CPM_PKG::VAL_MASKEN06      ),
        .VAL_ALIMIT07  ( `BP_CPM_PKG::VAL_ALIMIT07      ),
        .I2C_ADDRESS   ( `BP_CPM_PKG::I2C_ADDRESS       ),
        .OVER_VOLT_INIT( `BP_CPM_PKG::OVER_VOLT_INIT    )
    ) bp_cpm ();


`define DAC_DAC38J84_HSD DAC_DAC38J84_HSD_KU // Define an default so svlint can parse
`ifdef ENABLE_HDR
    `ifdef TXDAC_1200MSPS
        `define DAC_DAC38J84_HSD DAC_DAC38J84_PCH_1200MSPS
    `elsif LBAND
        `define DAC_DAC38J84_HSD DAC_DAC38J84_HSD_LB
        // Assertions to check whether the L-band package was correctly derived from the Ku-band package.
        initial DAC_DAC38J84_HSD_LB::check_spi_initreg();
    `else
        `define DAC_DAC38J84_HSD DAC_DAC38J84_HSD_KU
    `endif
`endif
`ifdef ENABLE_KAS
    `ifdef TXDAC_1200MSPS
        `define DAC_DAC38J84_HSD DAC_DAC38J84_HSD_KAS_1200MSPS
    `else
        `define DAC_DAC38J84_HSD DAC_DAC38J84_HSD_KAS
        // Assertions to check whether the Ka-band package was correctly derived from the Ku-band package.
        initial DAC_DAC38J84_HSD_KAS::check_spi_initreg();
    `endif
`endif


    DAC_DAC3xj8x_int #(
        .DEVICE_TYPE           ( 2                                       ),
        .JESD_L                ( `DAC_DAC38J84_HSD::JESD_L               ),
        .JESD_M                ( `DAC_DAC38J84_HSD::JESD_M               ),
        .JESD_F                ( `DAC_DAC38J84_HSD::JESD_F               ),
        .JESD_K                ( `DAC_DAC38J84_HSD::JESD_K               ),
        .JESD_S                ( `DAC_DAC38J84_HSD::JESD_S               ),
        .JESD_N                ( `DAC_DAC38J84_HSD::JESD_N               ),
        .JESD_N_PRIME          ( `DAC_DAC38J84_HSD::JESD_N_PRIME         ),
        .JESD_CS               ( `DAC_DAC38J84_HSD::JESD_CS              ),
        .JESD_HD               ( `DAC_DAC38J84_HSD::JESD_HD              ),
        .JESD_EN_SCRAMBLING    ( `DAC_DAC38J84_HSD::JESD_EN_SCRAMBLING   ),
        .JESD_F1_FRAMECLK_DIV  ( `DAC_DAC38J84_HSD::JESD_F1_FRAMECLK_DIV ),
        .JESD_F2_FRAMECLK_DIV  ( `DAC_DAC38J84_HSD::JESD_F2_FRAMECLK_DIV ),
        .NUMSPISTEPS           ( `DAC_DAC38J84_HSD::NUMSPISTEPS          ),
        .NUMSTATUSREGS         ( `DAC_DAC38J84_HSD::NUMSTATUSREGS        ),
        .NUMJESDSTEPS          ( `DAC_DAC38J84_HSD::NUMJESDSTEPS         ),
        .SYSREF_INDEX          ( `DAC_DAC38J84_HSD::SYSREF_INDEX         ),
        .SPI_JESDVAL           ( `DAC_DAC38J84_HSD::SPI_JESDVAL          ),
        .MEM_STATUSREGS        ( `DAC_DAC38J84_HSD::MEM_STATUSREGS       ),
        .MEM_STATUSVALS        ( `DAC_DAC38J84_HSD::MEM_STATUSVALS       ),
        .SPI_INITREG           ( `DAC_DAC38J84_HSD::SPI_INITREG          ),
        .SPI_INITVAL           ( `DAC_DAC38J84_HSD::SPI_INITVAL          )
    ) tx_dac ();

    ADC_KAD5512_int #(
        .NB         ( 12        ),
        .FLIP_MASK  ( 12'hfff   ),
        .DEVICE_TYPE( 2         )
    ) rx0_adc (
        .ctrl_clk ( rx0_ctrl.clk)
    );
    ADC_KAD5512_int #(
        .NB         ( 12        ),
        .FLIP_MASK  ( 12'hfff   ),
        .DEVICE_TYPE( 2         )
    ) rx1_adc (
        .ctrl_clk ( rx0_ctrl.clk) // TODO: rx1_ctrl does not exist yet
    );
    AMP_LMH6401_int #( .NAMPS (2)         ) rx0_amp ();
    AMP_LMH6401_int #( .NAMPS (2)         ) rx1_amp ();
    AMP_LMH6401_int #( .NAMPS (1)         ) tx_amp ();
    HSD_System_int                          system ( .clk ( clksys_drv ), .sresetn (sresetn) );
    RGMII_int                               rgmii  ( .clk125 ( pl_clk2_125_drv ) );
    HDR_int                                 hdr ();
    KaS_int                                 kas ();

    // From the Rx PLL we need the register clock, the sample rate clock, a clock for the FEC, and
    // a clock for the demod core.
    localparam int     FEC_CLK_DIV      = 3 * `DEMOD_N_PARALLEL;
    localparam int     DEMOD_CLK_DIV    = 2 * `DEMOD_N_PARALLEL;
    logic rx_pll_resetn;
    PhaseLockedLoop_int # ( .CLKIN_PERIOD(4.167), .CLKFB_MULT_F(4), .N_CLKS(5), .DIVIDE('{2, 8, FEC_CLK_DIV, DEMOD_CLK_DIV, 16}), .PHASE_F('{0, 0, 0, 0, 0}), .DEVICE_TYPE(2) )
        rx0_pll ( .clk(rx0_adc.clk_p), .reset_n (rx_pll_resetn) );
    SampleStream_int    # (.N_CHANNELS(1), .N_PARALLEL(4), .NB(12), .NB_FRAC(0), .PAUSABLE (0) )
        rx0_ssi ( .clk(rx0_pll.clk_out[1]), .sresetn(rx0_pll.sresetn[1]));

    logic tx_ssi_sresetn; // tx_ctrl.sresetn, xclocked to tx_ssi.clk
    xclock_resetn_sync #(
        .INPUT_REG  ( 1                 )
    ) xclock_tx_ssi_sresetn (
        .tx_clk     ( tx_ctrl.clk       ),
        .resetn_in  ( tx_ctrl.sresetn   ),
        .rx_clk     ( tx_ssi.clk        ),
        .resetn_out ( tx_ssi_sresetn    )
    );

    // TXSDR runs at the DAC reference frequency (150 MHz), but we operate the
    // DAC at 300 MSPS. For this reason, we generate a clock at twice the DAC
    // clock frequency, which we use when interpolating the 150 MSPS tx_ssi stream
    // to 2-parallel SSI at 150 MHz.
    //
    // We also generate another clock at 150 MHz (tx_pll.clk_out[1]) for TXSDR,
    // rather than using tx_dac.clk directly, to guarantee that it is rising-edge
    // aligned with the 300 MHz clock. This allows us to use more efficient
    // multicycle-path-based CDC structures to go between the 150 and 300 MHz
    // clocks.
    //
    // We also generate a 240 MHz clock to run the DVB-S2 modulator core.

    /*
    // 300 MSym
    PhaseLockedLoop_int # (.CLKIN_PERIOD(6.667), .CLKFB_MULT_F(8), .N_CLKS(3), .DIVIDE ('{4, 8, 5}), .DEVICE_TYPE (2) )
        tx_pll ( .clk(tx_dac.clk), .reset_n (tx_dac.sresetn));
    SampleStream_int    # (.N_CHANNELS(4), .N_PARALLEL(2), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi_ext_ins [TXSDR_PKG::EXTERNAL_SSI_SRC_NUM_INDICES-1:0] ( .clk(tx_pll.clk_out[1]), .sresetn(tx_ssi_sresetn));
    SampleStream_int    # (.N_CHANNELS(4), .N_PARALLEL(2), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi ( .clk(tx_pll.clk_out[1]), .sresetn(tx_ssi_sresetn));
    SampleStream_int    # (.N_CHANNELS(2), .N_PARALLEL(8), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi_1200msps ( .clk(tx_pll.clk_out[1]), .sresetn(tx_ssi_sresetn));

    // 1 channel IQ
    SampleStream_int    # (.N_CHANNELS(2), .N_PARALLEL(1), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        rfoe_ssi_out ( .clk(tx_pll.clk_out[1]), .sresetn(tx_ssi_sresetn));
    */

    // 400 Msym
    PhaseLockedLoop_int # (.CLKIN_PERIOD(6.667), .CLKFB_MULT_F(8), .N_CLKS(4), .DIVIDE ('{3, 6, 5, 8}), .DEVICE_TYPE (2) )
        tx_pll ( .clk(tx_dac.clk), .reset_n (tx_dac.sresetn));
    SampleStream_int    # (.N_CHANNELS(4), .N_PARALLEL(2), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi_ext_ins [TXSDR_PKG::EXTERNAL_SSI_SRC_NUM_INDICES-1:0] ( .clk(tx_pll.clk_out[3]), .sresetn(tx_ssi_sresetn));
    SampleStream_int    # (.N_CHANNELS(4), .N_PARALLEL(2), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi ( .clk(tx_pll.clk_out[3]), .sresetn(tx_ssi_sresetn));
    SampleStream_int    # (.N_CHANNELS(2), .N_PARALLEL(8), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        tx_ssi_1200msps ( .clk(tx_pll.clk_out[3]), .sresetn(tx_ssi_sresetn));

    // 1 channel IQ
    SampleStream_int    # (.N_CHANNELS(2), .N_PARALLEL(1), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
        rfoe_ssi_out ( .clk(tx_pll.clk_out[3]), .sresetn(tx_ssi_sresetn));



    WatchdogAction_int acm_modcod_watchdog_action ();

    // Definitions for the RXSDR module and the TXSDR module
    SDR_Ctrl_int #( .STATELEN (1) ) sdr_rxsdr ( .clk (rx0_ctrl.clk) );
    SDR_Ctrl_int #( .STATELEN (1) ) sdr_txsdr ( .clk (tx_ctrl.clk ) );

    assign sdr_rxsdr.sresetn = rx0_ctrl.sresetn;
    assign sdr_txsdr.sresetn = tx_ctrl.sresetn;

    // Backplane
    IOEXP_PCAL6524_int bp_ioexp ();
    IOEXP_PCAL6524_int sec_ioexp ();
    logic               bp_hdr_present_n;
    logic   [3:0]       pl_ssd_present_n;
    logic   [1:0]       ps_ssd_present_n;
    logic   [3:0]       en_pl_ssd;
    logic   [1:0]       en_ps_ssd;
    logic               bp_en_tempsns;
    logic               bp_fast_alert_n;

    // Main Rx and Tx data channels to/from various sources: these all carry Ethernet frames
    logic eth_resetn;

    // The reset is asserted only if all of the possible endpoints are held in reset
    always_ff @(posedge clksys_drv) begin
        if (!sresetn) begin
            eth_resetn <= 1'b0;
        end else begin
            eth_resetn <= nic_ctrl.sresetn
                    || rgmii_ctrl.sresetn
                    || sdr_rxsdr.sresetn
                    || sdr_txsdr.sresetn
                    || dsss_ctrl.sresetn;
        end
    end

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) eth_src [NUM_ETH_SRC_INDICES-1:0] (
        .clk    (clksys_drv),
        .sresetn(eth_resetn)
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) eth_sink [NUM_ETH_SINK_INDICES-1:0] (
        .clk    (clksys_drv),
        .sresetn(eth_resetn)
    );

    // RGMII External PL DDR FIFO
    logic ext_rx_fifo_clk, ext_rx_fifo_rst;

    AXIS_int #( .DATA_BYTES (1) ) rgmii_ext_fifo_to_ddr  ( .clk (ext_rx_fifo_clk), .sresetn(~ext_rx_fifo_rst));
    AXIS_int #( .DATA_BYTES (1) ) rgmii_ext_fifo_from_ddr ( .clk (ext_rx_fifo_clk), .sresetn(~ext_rx_fifo_rst));

    //QSPI-NIC interface
    BlockByteCtrl_int qspi_bb_ctrls [ZYNQ_QSPI_HSD::BB_QSPI_NUM-1:0] (.backend_ready(1'b1)); // backend always ready: PS comes up before FPGA
    AXIS_int #(.DATA_BYTES(1)) qspi_bb_writes [ZYNQ_QSPI_HSD::BB_QSPI_NUM-1:0] (.clk(qspi_ctrl.clk), .sresetn(qspi_ctrl.sresetn));
    AXIS_int #(.DATA_BYTES(1)) qspi_bb_reads [ZYNQ_QSPI_HSD::BB_QSPI_NUM-1:0] (.clk(qspi_ctrl.clk), .sresetn(qspi_ctrl.sresetn));

    // UPI Rx bus
    // Indices of UPI Rx bus masters. Lower values have higher priority.
    typedef enum {
        UPI_RX_MASTER_MAIN, // our main MMI bus (driven by SPI, MMIoE, etc.)
        UPI_RX_MASTER_POLL, // the mmi_upi_poll module
        NUM_UPI_RX_MASTERS
    } upi_rx_masters_t;

    // The UPI Rx bus
    MemoryMap_int #(
        .ADDRLEN    ( RXSDR_DVBS2_240MHZ_PKG::UPI_ADDRLEN ),
        .DATALEN    ( RXSDR_DVBS2_240MHZ_PKG::UPI_DATALEN )
    ) mmi_upi_rx ();

    // UPI Rx bus masters
    MemoryMap_int #(
        .ADDRLEN    ( RXSDR_DVBS2_240MHZ_PKG::UPI_ADDRLEN ),
        .DATALEN    ( RXSDR_DVBS2_240MHZ_PKG::UPI_DATALEN )
    ) mmi_upi_rx_masters    [NUM_UPI_RX_MASTERS-1:0]    ();

    // SSD interfaces
    // --------------
    SataIO_int sata_io `PL_SATA_ARRAY_DEF ();

    logic `PL_SATA_ARRAY_DEF ssd_backend_ready;
    // Arbiter output:
    BlockByteCtrl_int ssd_byte_ctrl           ( .backend_ready  ( ssd_backend_ready[0] ));
    AXIS_int #(.DATA_BYTES(1)) ssd_byte_write ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
    AXIS_int #(.DATA_BYTES(1)) ssd_byte_read  ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
    // Arbiter inputs:
    BlockByteCtrl_int ssd_byte_ctrls           [SSD_NUM_INDICES-1:0]
        ( .backend_ready  ( ssd_backend_ready[0] ));
    AXIS_int #(.DATA_BYTES(1)) ssd_byte_writes [SSD_NUM_INDICES-1:0]
        ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
    AXIS_int #(.DATA_BYTES(1)) ssd_byte_reads  [SSD_NUM_INDICES-1:0]
        ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );

    // DDR BlockByte device interfaces
    // -------------------------------
    logic ddr_bb_backend_ready;
    BlockByteCtrl_int ddr_bb_ctrls            [DDR_BB_NUM_INDICES-1:0]
        ( .backend_ready  ( ddr_bb_backend_ready ));
    AXIS_int #(.DATA_BYTES(1)) ddr_bb_writes  [DDR_BB_NUM_INDICES-1:0]
        ( .clk ( clksys_drv ), .sresetn ( ddr_ctrl.sresetn ) );
    AXIS_int #(.DATA_BYTES(1)) ddr_bb_reads   [DDR_BB_NUM_INDICES-1:0]
        ( .clk ( clksys_drv ), .sresetn ( ddr_ctrl.sresetn ) );

    // Monitor Interfaces
    // ------------------
    // PCH system temperature sensors: same limits as board_pch_* since it's the same PCH hardware as Alderaan
    MonitorLimits_int #(
        .NUM_SIGNALS    ( TEMPERATURE_LIMITS_PCH_SYS::NUM_SIGNALS ),
        .DATALEN        ( TEMPERATURE_LIMITS_PCH_SYS::DATALEN ),
        .INITIAL_LIMITS ( TEMPERATURE_LIMITS_PCH_SYS::INITIAL_LIMITS ),
        .VAL_SIGNED     ( TEMPERATURE_LIMITS_PCH_SYS::VAL_SIGNED )
    ) temp_limits_sys ();

    // HDR temperature sensors: same limits as board_pch_* since it's the same HDR hardware as Alderaan
`ifdef LBAND
    `define TEMPERATURE_LIMITS_PCH_HDR TEMPERATURE_LIMITS_PCH_L_HDR
`else
    `define TEMPERATURE_LIMITS_PCH_HDR TEMPERATURE_LIMITS_PCH_KU_HDR
`endif
    MonitorLimits_int #(
        .NUM_SIGNALS    ( `TEMPERATURE_LIMITS_PCH_HDR::NUM_SIGNALS ),
        .DATALEN        ( `TEMPERATURE_LIMITS_PCH_HDR::DATALEN ),
        .INITIAL_LIMITS ( `TEMPERATURE_LIMITS_PCH_HDR::INITIAL_LIMITS ),
        .VAL_SIGNED     ( `TEMPERATURE_LIMITS_PCH_HDR::VAL_SIGNED )
    ) temp_limits_hdr ();

    MonitorLimits_int #(
        .NUM_SIGNALS    ( TEMPERATURE_LIMITS_HSD_KAS::NUM_SIGNALS ),
        .DATALEN        ( TEMPERATURE_LIMITS_HSD_KAS::DATALEN ),
        .INITIAL_LIMITS ( TEMPERATURE_LIMITS_HSD_KAS::INITIAL_LIMITS ),
        .VAL_SIGNED     ( TEMPERATURE_LIMITS_HSD_KAS::VAL_SIGNED )
    ) temp_limits_kas ();

    // Add temperature limit interfaces for frontends here, etc.


    // I2C clock divider control
    // -------------------------
    logic [15:0]                    i2c_clk_divide, i2c_clk_divide_pre_trim;
    logic [NUM_I2C_CLK_DIV_IDX-1:0] i2c_clk_divide_stb;


    // KaS debug
    logic kas_debugi2c_en;
    logic kas_debugi2c_scl_in;
    logic kas_debugi2c_scl_out;
    logic kas_debugi2c_scl_hiz;
    logic kas_debugi2c_sda_in;
    logic kas_debugi2c_sda_out;
    logic kas_debugi2c_sda_hiz;

    logic  kas_debugspi1v8_en;
    logic  kas_debugspi1v8_sclk_in;
    logic  kas_debugspi1v8_sclk_out;
    logic  kas_debugspi1v8_sclk_hiz;
    logic  kas_debugspi1v8_mosi_in;
    logic  kas_debugspi1v8_mosi_out;
    logic  kas_debugspi1v8_mosi_hiz;
    logic  kas_debugspi1v8_ssn_in;
    logic  kas_debugspi1v8_ssn_out;
    logic  kas_debugspi1v8_ssn_hiz;

    logic  kas_debugspi3v3_en;
    logic  kas_debugspi3v3_dacssn_in;
    logic  kas_debugspi3v3_dacssn_out;
    logic  kas_debugspi3v3_dacssn_hiz;

    logic  kas_debugio19_en;
    logic  kas_debugio19_in;
    logic  kas_debugio19_out;
    logic  kas_debugio19_hiz;

    logic  kas_debugio21_en;
    logic  kas_debugio21_in;
    logic  kas_debugio21_out;
    logic  kas_debugio21_hiz;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Top-Level Assignments


    // clk_lpd must be the same as pl_clk0_sys_drv, which is what the PS AXI buses run at.
    // Our IO module makes that assignment.
    assign  clk_lpd     = clksys_pl;
    assign  clksys_drv  = clksys_pl;
    assign  sresetn     = sresetn_pl;

    assign lmk.syncreq  = (tx_dac.ctrl_sysref_req & tx_dac.start_sysref) || (!(`DEFINED(ENABLE_TX_SDR)));


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Modules


    // Zynq signals
    logic [95:0] zynq_emio_tri_i, zynq_emio_tri_o, zynq_emio_tri_t;

    assign zynq_emio_tri_i[0]       = system.pps;
    assign zynq_emio_tri_i[95:1]    = '0;

    assign zynq_irq_in[ZYNQ_IRQ_30:ZYNQ_IRQ_8] = '0;    // currently unused
    assign zynq_irq_in[ZYNQ_IRQ_7]             = 1'b0;  // used in PCH (secondary QSPI soft block controller) but not HSD
    assign zynq_irq_in[ZYNQ_IRQ_1]             = 1'b0;  // used in PCH (Kamino UARTLite) but not HSD

    board_hsd_zynq_wrapper #(
        .AXIS_ETH_FIFO_ADDR_WIDTH   ( $clog2(MAX_PKTSIZE) + 2 )
    ) zynq_inst (
        .rtl_aresetn    ( sresetn_pl                        ),
        .pl_clk0_sys    ( pl_clk0_sys_drv                   ),
        .pl_clk1_300    ( pl_clk1_300_drv                   ),
        .pl_clk2_125    ( pl_clk2_125_drv                   ),
        .pl_clk3_200    ( pl_clk3_200_drv                   ),
        .pl_ps_irc_in   ( zynq_irq_in                       ),
        .zynq_emio_tri_i( zynq_emio_tri_i                   ),
        .zynq_emio_tri_o( zynq_emio_tri_o                   ),
        .zynq_emio_tri_t( zynq_emio_tri_t                   ), // set by CPU
        .pspl_eth_tx    ( eth_sink[ETH_IDX_PSPLETH2_SINK:ETH_IDX_PSPLETH0_SINK] ), // packets to send to the PS
        .pspl_eth_rx    ( eth_src[ETH_IDX_PSPLETH2_SRC:ETH_IDX_PSPLETH0_SRC]    ), // packets received from the PS
        .axi_lpd_m      ( axi_lpd_m.Master                  ),
        .axi_lpd_s      ( axi_lpd_s.Slave                   )
    );

    irq_simple_test_mmi #(
        .N ( 1 )
    ) pl_ps_irc_test_inst (
        .clk        ( clksys_drv ),
        .sresetn    ( sresetn_pl ),
        .mmi        ( mmi_dev[MMI_ZYNQ_IRQ_TEST] ),
        .irq_out    ( zynq_irq_in[ZYNQ_IRQ_TEST] )
    );

    // ARM master -> FPGA slave
    axi4_to_narrow_mmi #(
        .ALLOW_MISMATCHED_ADDRLEN ( 1 ) // Our MMI space is much smaller than the whole MPSoC memory space.
    ) axi_slave_inst (
        .axi    ( axi_lpd_m.Slave ),
        .mmi    ( mmi_masters[MMI_MASTER_ZYNQ] )
    );

    // SPI master
    spi_slave #(
        .ADDR_LEN( MMI_ADDRLEN  ),
        .DATA_LEN( MMI_DATALEN  ),
        .PRE_MMI_READ_LOCK      ( 1 ),  // use arbitration locking and dummy reads
        .PRE_MMI_WRITE_LOCK     ( 1 ),  // use arbitration lock and dummy writes
        .PRE_MMI_SPI_EARLY_BIT  ( 4 ),  // lock and dummy read 4 SPI bit periods early
        .PRE_MMI_READ_ADDR      ( 6 ),  // dummy read of the CONFIG_CHECK register
        .PRE_MMI_WRITE_ADDR     ( 6 ),  // dummy write to the CONFIG_CHECK register (which is read-only; harmless)
        .PRE_MMI_WRITE_DATA     ( 0 )
    ) spi_slave_inst (
        .clk            ( clksys_drv       ),
        .reset_n        ( sresetn          ),
        .sclk           ( obc_spi.sclk     ),
        .mosi           ( obc_spi.mosi_out ),
        .miso           ( obc_spi.miso     ),
        .ss_n           ( obc_spi.ss_n     ),
        .mmi            ( mmi_masters[MMI_MASTER_SPI] ),
        .read_arb_lock  ( mmi_masters_read_arb_lock[MMI_MASTER_SPI] ),
        .write_arb_lock ( mmi_masters_write_arb_lock[MMI_MASTER_SPI] )
    );
    assign obc_spi.mosi_in = 1'bX;  // unused; spi_slave is 4-wire, not 3-wire


    // MMI master arbiter
    generate
        for (genvar i = 0; i < NUM_MMI_MASTERS; i++) begin
            if (i != MMI_MASTER_SPI) begin
                assign mmi_masters_read_arb_lock[i]  = 1'b0;
                assign mmi_masters_write_arb_lock[i] = 1'b0;
            end
        end
    endgenerate

    mmi_firewalled_arbiter #(
        .N                          ( NUM_MMI_MASTERS   ),
        .ARB_TYPE                   ( "priority"        ),
        .HIGHEST                    ( 0                 ),// lower numbers have higher priority
        .WVALID_WREADY_MAX_WAIT     ( `MMI_FIREWALL_TIMEOUTS ),
        .ARVALID_ARREADY_MAX_WAIT   ( `MMI_FIREWALL_TIMEOUTS ),
        .RVALID_RREADY_MAX_WAIT     ( `MMI_FIREWALL_TIMEOUTS ),
        .RH_RVALID_MAX_WAIT         ( `MMI_FIREWALL_TIMEOUTS ),
        .FIREWALL_INPUTS            ( `DEFINED(ENABLE_MMI_FIREWALL) ),
        .FIREWALL_OUTPUT            ( `DEFINED(ENABLE_MMI_FIREWALL) )
    ) mmi_master_arbiter_inst (
        .clk                ( clksys_drv                    ),
        .sresetn            ( sresetn                       ),
        .mmi_in             ( mmi_masters             ),
        .read_arb_lock      ( mmi_masters_read_arb_lock     ),
        .write_arb_lock     ( mmi_masters_write_arb_lock    ),
        .mmi_out            ( mmi_demux_in.Master           ),
        .read_active_mask   (                               ),
        .write_active_mask  (                               ),
`ifdef ENABLE_MMI_FIREWALL
        .timeout_violation  ( mmi_fw_violations )
`else
        .timeout_violation  ( )
`endif
    );
`ifndef ENABLE_MMI_FIREWALL
    assign mmi_fw_violations = '{default: '0};
`endif

    generate
        if (`DEFINED(ENABLE_MMI_FIREWALL) && (`MMI_FW_EVENT_LOG_ENTRIES > 0)) begin: gen_mmi_fw_event_logger
            // Log details of firewall violations to a FIFO buffer.
            mmi_fw_arb_monitor #(
                .N          ( NUM_MMI_MASTERS       ),
                .FIFO_DEPTH ( `MMI_FW_EVENT_LOG_ENTRIES )
            ) mmi_arb_fw_logger_inst (
                .clk        ( clksys_drv            ),
                .sresetn    ( sresetn               ),
                .mmi_in     ( mmi_masters           ),
                .mmi_out    ( mmi_demux_in.Monitor  ),
                .timeout_violation  ( mmi_fw_violations ),
                .mmi        ( mmi_dev[MMI_MMI_FW_EVENTS] )
            );
        end else begin: gen_no_mmi_fw_event_logger
            mmi_nul_slave no_mmi_fw_logger ( .mmi(mmi_dev[MMI_MMI_FW_EVENTS]) );
        end
    endgenerate


    // MMI device demux
    mmi_demux #(
        .N_DEVS     ( MMI_NDEVS     ),
        .ADDRLEN    ( MMI_ADDRLEN   ),
        .DEV_OFFSET ( DEV_OFFSET    ),
        .DEV_WIDTH  ( DEV_WIDTH     )
    ) mmi_demux_inst(
        .clk          ( clksys_drv       ),
        .reset_n      ( sresetn          ),
        .mmi_in       ( mmi_demux_in.Slave    ),
        .mmi_out      ( mmi_dev               )
    );

    // Firewall status bits
    mmi_roregfile_latched #(
        .NVALS      ( NUM_MMI_MASTERS+BOARD_HSD_MMI32_PARAMS::MMI32_NDEVS+2 ),
        .DWIDTH     ( 4                     )
    ) mmi_fw_status_inst (
        .clk        ( clksys_drv            ),
        .rst        ( ~sresetn              ),
        .latch_clear_stb ( 1'b0             ),
        .latch_en   ( 1'b1                  ),
        .mmi        ( mmi_dev[MMI_MMI_FW] ),
        .vals       ( {zynq_fw_violations, mmi_fw_violations} ),
        .gpout      (                       ),
        .gpout_stb  (                       )
    );

    // Instantiate the system monitor
    sysmon_ctrl_zynq zynq_sysmon_inst (
        .sysmon ( sysmon.Module             ),
        .mmi    ( mmi_dev[MMI_SYSMON] )
    );

    // Instantiate the chip ID module
    logic [95:0] chip_id;
    sysmon_id_xilinx #(
        .FAMILY     ( "UltraScale"      )
    ) chip_id_inst (
        .clk        ( system.clk        ),
        .sresetn    ( system.sresetn    ),
        .id         ( chip_id           ),
        .initdone   (                   ) // wait for 1ms after reset
    );

    // Instantiate the controller module that holds the main state machine
    board_hsd_ctrl #(
        .FORCE_MMI_CTRL  (`DEFINED(FORCE_MMI_CTRL)     ),
        .CLK_EN          (`DEFINED(ENABLE_CLK_CTRL)    ),
        .CPM_EN          (`DEFINED(ENABLE_CPM_CTRL)    ),
        .TEMP_EN         (`DEFINED(ENABLE_TEMP_CTRL)   ),
        .NIC_EN          (`DEFINED(ENABLE_NIC_CTRL)    ),
        .QSPI_EN         (`DEFINED(ENABLE_QSPI_CTRL)   ),
        .HDR_EN          (`DEFINED(ENABLE_HDR)         ),
        .PA_EN           (`DEFINED(ENABLE_PA)          ),
        .RX0SDR_EN       (`DEFINED(ENABLE_RX0_SDR)     ),
        .RX1SDR_EN       (`DEFINED(ENABLE_RX1_SDR)     ),
        .TXSDR_EN        (`DEFINED(ENABLE_TX_SDR)      ),
        .SSD_EN          (`DEFINED(ENABLE_SSD_CTRL)    ),
        .RGMII_EN        (`DEFINED(ENABLE_RGMII)       ),
        .DDR4_EN         (`DEFINED(ENABLE_PL_DDR)      ),
        .LB_EN           (`DEFINED(LBAND)              ),
        .BP_EN           (`DEFINED(ENABLE_BACKPLANE)   ),
        .DSSS_EN         (`DEFINED(ENABLE_DSSS_RX)     ),
        .KAS_EN          (`DEFINED(ENABLE_KAS)         )
    ) ctrl_inst (
        .system             ( system.Ctrl                 ),
        .hdr                ( hdr.Ctrl                    ),
        .qspi_bctrl         ( qspi_bctrl.Client           ),
        .cpm_ctrl           ( cpm_ctrl.Controller         ),
        .temp_ctrl          ( temp_ctrl.Controller        ),
        .lmk_ctrl           ( lmk_ctrl.Controller         ),
        .rx0_ctrl           ( rx0_ctrl.Controller         ),
        .tx_ctrl            ( tx_ctrl.Controller          ),
        .hdr_ctrl           ( hdr_ctrl.Controller         ),
        .hdrpa_ctrl         ( hdrpa_ctrl.Controller       ),
        .bp_ctrl            ( bp_ctrl.Controller          ),
        .nic_ctrl           ( nic_ctrl.Controller         ),
        .rgmii_ctrl         ( rgmii_ctrl.Controller       ),
        .qspi_ctrl          ( qspi_ctrl.Controller        ),
        .pwr_ctrl           ( pwr_ctrl.Controller         ),
        .ssd_ctrl           ( ssd_ctrl.Controller         ),
        .ddr_ctrl           ( ddr_ctrl.Controller         ),
        .dsss_ctrl          ( dsss_ctrl.Controller        ),
        .mmi                ( mmi_dev[MMI_HSDCTRL]        ),
        .global_alarm       ( global_alarm_irq            ),
        .chip_id            ( chip_id                     ),
        .kas                ( kas.Ctrl                    ),
        .kas_ctrl           ( kas_ctrl.Controller         ),
        .kas_vstby_initdone ( kas_vstby_initdone          ),

        .kas_debugi2c_en        ( kas_debugi2c_en      ),
        .kas_debugi2c_scl_in    ( kas_debugi2c_scl_in  ),
        .kas_debugi2c_scl_out   ( kas_debugi2c_scl_out ),
        .kas_debugi2c_scl_hiz   ( kas_debugi2c_scl_hiz ),
        .kas_debugi2c_sda_in    ( kas_debugi2c_sda_in  ),
        .kas_debugi2c_sda_out   ( kas_debugi2c_sda_out ),
        .kas_debugi2c_sda_hiz   ( kas_debugi2c_sda_hiz ),

        .kas_debugspi1v8_en        (kas_debugspi1v8_en        ),
        .kas_debugspi1v8_sclk_in   (kas_debugspi1v8_sclk_in   ),
        .kas_debugspi1v8_sclk_out  (kas_debugspi1v8_sclk_out  ),
        .kas_debugspi1v8_sclk_hiz  (kas_debugspi1v8_sclk_hiz  ),
        .kas_debugspi1v8_mosi_in   (kas_debugspi1v8_mosi_in   ),
        .kas_debugspi1v8_mosi_out  (kas_debugspi1v8_mosi_out  ),
        .kas_debugspi1v8_mosi_hiz  (kas_debugspi1v8_mosi_hiz  ),
        .kas_debugspi1v8_ssn_in    (kas_debugspi1v8_ssn_in    ),
        .kas_debugspi1v8_ssn_out   (kas_debugspi1v8_ssn_out   ),
        .kas_debugspi1v8_ssn_hiz   (kas_debugspi1v8_ssn_hiz   ),

        .kas_debugspi3v3_en        (kas_debugspi3v3_en        ),
        .kas_debugspi3v3_dacssn_in (kas_debugspi3v3_dacssn_in ),
        .kas_debugspi3v3_dacssn_out(kas_debugspi3v3_dacssn_out),
        .kas_debugspi3v3_dacssn_hiz(kas_debugspi3v3_dacssn_hiz),

        .kas_debugio19_en        (kas_debugio19_en  ),
        .kas_debugio19_in        (kas_debugio19_in  ),
        .kas_debugio19_out       (kas_debugio19_out ),
        .kas_debugio19_hiz       (kas_debugio19_hiz ),

        .kas_debugio21_en        (kas_debugio21_en  ),
        .kas_debugio21_in        (kas_debugio21_in  ),
        .kas_debugio21_out       (kas_debugio21_out ),
        .kas_debugio21_hiz       (kas_debugio21_hiz )
    );


    board_hsd_alarms #(
        .ENABLE_MON_ALARM_CTRL  ( `DEFINED(ENABLE_MON_ALARM_CTRL) )
    ) alarm_inst (
        .clk                ( clksys_drv ),
        .sresetn            ( sresetn ),
        .mmi                ( mmi_dev[MMI_GLOBAL_ALARM] ),
        .global_alarm_irq   ( global_alarm_irq ),
        .sysmon             ( sysmon.Monitor ),
        .sys_0_cpm          ( sys_0_cpm.Monitor ),
        .sys_1_cpm          ( sys_1_cpm.Monitor ),
        .bp_cpm             ( bp_cpm.Monitor ),
        .hdr_cpm            ( hdr_cpm.Monitor ),
        .kas_cpm            ( kas_cpm.Monitor ),
        .temp_limits_sys    ( temp_limits_sys.Monitor ),
        .temp_limits_hdr    ( temp_limits_hdr.Monitor ),
        .temp_limits_kas    ( temp_limits_kas.Monitor )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: FPGA as PS Bus Master


    mmi_to_wide_axi4 #(
        .ALLOW_MISMATCHED_ADDRLEN   ( 0 )   // If it changes, I want to know about it.
    ) mmi_to_axi_lpd_s (
        .mmi    ( mmi_lpd_init_s.Slave ),
        .axi    ( axi_lpd_s.Master )    // FPGA master, ARM slave
    );

    mmi_init_ctrl #(
        .MMI_DATALEN    ( mmi_lpd_s.DATALEN ),
        .MMI_ADDRLEN    ( mmi_lpd_s.ADDRLEN ),
        .INIT_NUMREGS   ( BOARD_HSD_AXI4_INIT_PKG::INIT_NUMREGS ),
        .INIT_ADDR      ( BOARD_HSD_AXI4_INIT_PKG::INIT_ADDR ),
        .INIT_VALS      ( BOARD_HSD_AXI4_INIT_PKG::INIT_VALS )
    ) mmi_to_axi_lpd_init_inst (
        .clk            ( clksys_drv            ),
        .reset_n        ( sresetn               ),
        .mmi            ( mmi_lpd_s.Slave       ),
        .mmi_s          ( mmi_lpd_init_s.Master ),
        .start          ( 1'b1                  ),
        .initdone       (                       )
    );

    mmi_to_mmi #(
        .MMI_ADDRLEN    ( MMI_ADDRLEN ),
        .MMI_DATALEN    ( MMI_DATALEN ),
        .MMI_S_ADDRLEN  ( BOARD_HSD_MMI32_PARAMS::MMI32_DEV_ADDRLEN ),
        .MMI_S_DATALEN  ( BOARD_HSD_MMI32_PARAMS::MMI32_DEV_DATALEN )
    ) mmi32_bridge (
        .clk        ( clksys_drv ),
        .reset_n    ( sresetn ),
        .mmi        ( mmi_dev[MMI_PS_MASTER] ),
        .mmi_s      ( mmi32_dev[BOARD_HSD_MMI32_PARAMS::MMI32_OBC] )
    );

    // Both the OBC and the zynq_qspi block device need access to the PS bus, so
    // we arbitrate between their MMI interfaces.
    mmi_firewalled_arbiter #(
        .N                  ( BOARD_HSD_MMI32_PARAMS::MMI32_NDEVS   ),
        .ARB_TYPE           ( "priority"                            ),
        .HIGHEST            ( 0                                     ),
        .WVALID_WREADY_MAX_WAIT     ( `MMI_ZYNQ_FIREWALL_TIMEOUTS   ),
        .ARVALID_ARREADY_MAX_WAIT   ( `MMI_ZYNQ_FIREWALL_TIMEOUTS   ),
        .RVALID_RREADY_MAX_WAIT     ( `MMI_ZYNQ_FIREWALL_TIMEOUTS   ),
        .RH_RVALID_MAX_WAIT         ( `MMI_ZYNQ_FIREWALL_TIMEOUTS   ),
        .FIREWALL_INPUTS            ( `DEFINED(ENABLE_ZYNQ_FIREWALL)),
        .FIREWALL_OUTPUT            ( `DEFINED(ENABLE_ZYNQ_FIREWALL))
    ) mmi32_arbiter_inst (
        .clk                ( clksys_drv        ),
        .sresetn            ( sresetn           ),
        .mmi_in             ( mmi32_dev         ),
        .read_arb_lock      ( '0                ),
        .write_arb_lock     ( '0                ),
        .mmi_out            ( mmi_lpd_s.Master  ),
        .read_active_mask   (                   ),
        .write_active_mask  (                   ),
`ifdef ENABLE_ZYNQ_FIREWALL
        .timeout_violation  ( zynq_fw_violations )
`else
        .timeout_violation  ( )
`endif
    );
`ifndef ENABLE_ZYNQ_FIREWALL
    assign zynq_fw_violations = '{default: '0};
`endif

    generate
        if (`DEFINED(ENABLE_ZYNQ_FIREWALL) && (`ZYNQ_FW_EVENT_LOG_ENTRIES > 0)) begin: gen_zynq_fw_event_logger
            // Log details of firewall violations to a FIFO buffer.
            mmi_fw_arb_monitor #(
                .N          ( BOARD_HSD_MMI32_PARAMS::MMI32_NDEVS ),
                .FIFO_DEPTH ( `ZYNQ_FW_EVENT_LOG_ENTRIES )
            ) zynq_arb_fw_logger_inst (
                .clk        ( clksys_drv            ),
                .sresetn    ( sresetn               ),
                .mmi_in     ( mmi32_dev             ),
                .mmi_out    ( mmi_lpd_s.Monitor     ),
                .timeout_violation  ( zynq_fw_violations ),
                .mmi        ( mmi_dev[MMI_ZYNQ_FW_EVENTS] )
            );
        end else begin: gen_no_zynq_fw_event_logger
            mmi_nul_slave no_zynq_fw_logger ( .mmi(mmi_dev[MMI_ZYNQ_FW_EVENTS]) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Free-running Microsecond Counter


    // This is a free-running microsecond counter on clksys_drv.
    // This can be used by various other modules to perform performance timing:
    // us_count is the number of microseconds since reset.
    // us_pulse pulses once every microsecond.
    // NOTE: us_pulse can be used as the ext_event input for other util_stopwatch modules
    // with .CLOCK_SOURCE(-2). This prevents logic duplication inside util_stopwatch. (The other
    // util_stopwatch modules won't need their own clock divider.)
    logic   [63:0]      us_count;
    logic               us_pulse;   // pulses once every microsecond
    logic               ms_pulse;   // pulses once every millisecond

    util_stopwatch #(
        .CLOCK_SOURCE       ( CLKSYS_FREQ / 1000000 ),
        .COUNT_WIDTH        ( 64 ),
        .AUTO_START         ( 1 )
    ) free_us_counter_inst (
        .clk                ( clksys_drv ),
        .rst                ( ~sresetn ),
        .start_stb          ( 1'b0 ),
        .reset_stb          ( 1'b0 ),
        .stop_stb           ( 1'b0 ),
        .count              ( us_count ),
        .overflow           ( ),
        .latched_count      ( ),
        .latched_overflow   ( ),
        .ext_event          ( ),
        .count_pulse_out    ( us_pulse )
    );

    // Also generate millisecond pulses. Since we don't currently need a ms count, we've left off
    // that output.
    util_stopwatch #(
        .CLOCK_SOURCE       ( CLKSYS_FREQ / 1000 ),
        .COUNT_WIDTH        ( 32 ),
        .AUTO_START         ( 1 )
    ) ms_pulses_inst (
        .clk                ( clksys_drv ),
        .rst                ( ~sresetn ),
        .start_stb          ( 1'b0 ),
        .reset_stb          ( 1'b0 ),
        .stop_stb           ( 1'b0 ),
        .count              ( ),
        .overflow           ( ),
        .latched_count      ( ),
        .latched_overflow   ( ),
        .ext_event          ( ),
        .count_pulse_out    ( ms_pulse )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Zynq QSPI Block Device


`ifdef ENABLE_QSPI_CTRL
    zynq_qspi_frontend #(
        .NUM_BB             ( ZYNQ_QSPI_HSD::BB_QSPI_NUM ),
        .TARGET_NUM         ( 0                          ) // native QSPI
    ) zynq_qspi_inst (
        .qspi_ctrl          ( qspi_ctrl.Slave                                                   ),
        .bctrl              ( qspi_bctrl.Provider                                               ),
        .mmi_soft_ctrl      ( mmi_dev[MMI_ZYNQ_SOFT_QSPI]                                 ),
        .mmi_bb             ( mmi_dev[MMI_QSPI_BB]                                        ),
        .mmi_traffic        ( mmi_dev[MMI_QSPI_TRAFFIC_GEN]                               ),
        .mmi_perf           ( mmi_dev[MMI_QSPI_PERF]                                      ),
        .us_pulse           ( us_pulse                                                          ),
        .bb_ctrls           ( qspi_bb_ctrls                                            ),
        .bb_writes          ( qspi_bb_writes                                           ),
        .bb_reads           ( qspi_bb_reads                                            )
    );

    assign zynq_irq_in[ZYNQ_IRQ_SOFT_QSPI] = qspi_bctrl.irq;

`else   // !ENABLE_QSPI_CTRL
    assign zynq_irq_in[ZYNQ_IRQ_SOFT_QSPI] = 1'b0;
    mmi_nul_slave   no_qspi_soft    ( .mmi(mmi_dev[MMI_ZYNQ_SOFT_QSPI]) );
    mmi_nul_slave   no_qspi_bb      ( .mmi(mmi_dev[MMI_QSPI_BB]) );
    mmi_nul_slave   no_qspi_traffic ( .mmi(mmi_dev[MMI_QSPI_TRAFFIC_GEN]) );
    mmi_nul_slave   no_qspi_perf    ( .mmi(mmi_dev[MMI_QSPI_PERF]) );
    sdr_ctrl_nul_slave no_qspi_ctrl (.ctrl(qspi_ctrl.Slave) );
    block_soft_ctrl_nul_provider no_qspi_bctrl(.bctrl(qspi_bctrl.Provider) );

    generate
        for (genvar i = 0; i < ZYNQ_QSPI_HSD::BB_QSPI_NUM; i++) begin : gen_no_qspi_providers
            bb_nul_provider no_qspi_provider_i  ( .bbctrl(qspi_bb_ctrls[i]) );
            axis_nul_src    no_qspi_reads_i     ( .axis(qspi_bb_reads[i]) );
            axis_nul_sink   no_qspi_writes_i    ( .axis(qspi_bb_writes[i]) );
        end
    endgenerate
`endif  // !ENABLE_QSPI_CTRL


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: The module for peripherals on the PCH


    board_hsd_system #(
        .ENABLE_CLK_CTRL        ( `DEFINED(ENABLE_CLK_CTRL)     ),
        .ENABLE_CPM_CTRL        ( `DEFINED(ENABLE_CPM_CTRL)     ),
        .CPM_TRANS_DEPTH        ( `DEFINED(ENABLE_CPM_TRANS_PCH) ? `CPM_TRANS_BUFFER_DEPTH : 0),
        .ENABLE_TEMP_CTRL       ( `DEFINED(ENABLE_TEMP_CTRL)    ),
        .ENABLE_HEARTBEAT_BLINK ( `DEFINED(CLK_HEARTBEAT_BLINK) )
    ) board_hsd_system_inst (
        .sdr_lmk            ( lmk_ctrl.Slave                                        ),
        .sdr_cpm            ( cpm_ctrl.Slave                                        ),
        .sdr_temp           ( temp_ctrl.Slave                                       ),
        .lmk                ( lmk.Ctrl                                              ),
        .cpm_0              ( sys_0_cpm                                             ),
        .cpm_1              ( sys_1_cpm                                             ),
        .spi_io             ( sys_spi.Driver                                        ),
        .i2c_io             ( sys_i2c                                               ),
        .i2c_clk_divide     ( i2c_clk_divide                                        ),
        .i2c_clk_divide_stb ( i2c_clk_divide_stb[I2C_CLK_DIV_SYSTEM_IDX]            ),
        .temp_limits        ( temp_limits_sys                                       ),
        .mmi_lmk            ( mmi_dev[MMI_LMKCLK]                             ),
        .mmi_lm71           ( mmi_dev[MMI_LM71CTRL1:MMI_LM71CTRL0]            ),
        .mmi_cpm            ( mmi_dev[MMI_CPMCTRL1:MMI_CPMCTRL0]              ),
        .mmi_cpm_alarm      ( mmi_dev[MMI_CPMCTRL1_VLIM:MMI_CPMCTRL0_VLIM]    ),
        .mmi_cpm_maxval     ( mmi_dev[MMI_CPMCTRL1_MAXVAL:MMI_CPMCTRL0_MAXVAL]),
        .mmi_cpm_trans      ( mmi_dev[MMI_ITRANS_SYS1:MMI_ITRANS_SYS0]        ),
        .mmi_temp_limits    ( mmi_dev[MMI_PCH_TEMP_LIMIT]                     ),
        .us_count           ( us_count[27:0]                                        )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: IRQ Controller


`ifdef ENABLE_IRQ_CTRL
    // IRQ controller for the OBC
    irq_mmi_ctrl #(
        .NUM_IRQS       ( NUM_OBC_IRQS ),
        .DEFAULT_MASK   ( DEFAULT_OBC_IRQ_MASK )
    ) obc_irq_ctrl_inst (
        .clk            ( clksys_drv ),
        .sresetn        ( sresetn ),
        .mmi            ( mmi_dev[MMI_IRQCTRL] ),
        .irq_status_in  ( obc_irq_in ),
        .irq_io         ( obc_irq_io.Ctrl )
    );

    irq_simple_test_mmi #( .N(2) ) irq_test_inst (
        .clk            ( clksys_drv ),
        .sresetn        ( sresetn ),
        .mmi            ( mmi_dev[MMI_IRQ_TEST] ),
        .irq_out        ( {obc_irq_in[OBC_IRQ_TEST_1], obc_irq_in[OBC_IRQ_TEST_0]} )
    );
`else
    mmi_nul_slave   no_obc_irq_mmi  ( .mmi(mmi_dev[MMI_IRQCTRL]) );
    mmi_nul_slave   no_zynq_irq_mmi ( .mmi(mmi_dev[MMI_PSIRQCTRL]) );
    assign obc_irq_in[OBC_IRQ_TEST_0] = 1'b0;
    assign obc_irq_in[OBC_IRQ_TEST_1] = 1'b0;
    assign obc_irq_io.irq_hi = 1'b0;
    assign obc_irq_io.irq_lo = 1'b0;
`endif
    assign obc_irq_in[OBC_IRQ_31:OBC_IRQ_18]   = '0;    // unused
    assign obc_irq_in[OBC_IRQ_15:OBC_IRQ_14]   = '0;    // unused
    assign obc_irq_in[OBC_IRQ_1]               = 1'b0;  // present in PCH (OBC request for TARS) but not HSD
    assign obc_irq_in[OBC_IRQ_10]              = 1'b0;  // present in PCH (Sec QSPI read file ready) but not HSD
    assign obc_irq_in[OBC_IRQ_11]              = 1'b0;  // present in PCH (Sec QSPI read buffer ready) but not HSD
    assign obc_irq_in[OBC_IRQ_12]              = 1'b0;  // present in PCH (Sec QSPI write ready) but not HSD
    assign obc_irq_in[OBC_IRQ_13]              = 1'b0;  // present in PCH (Sec QSPI write buffer ready) but not HSD

    assign obc_irq_in[OBC_IRQ_GLOBAL_ALARM]         = global_alarm_irq;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: RX SDR Interface


    logic        [15:0] nco_phase_increment [3:0];
    logic signed [15:0] nco_phase_offset    [3:0];

`ifdef ENABLE_RX0_SDR
`ifdef ENABLE_RX1_SDR
    `FATAL_ERROR("ENABLE_RX0_SDR and ENABLE_RX1_SDR cannot both be defined at the same time.");
    // Both together would be too large for the FPGAs we have available.
    // Also, we only have MMI addresses defined for one.
`endif
`endif

    amp_lmh6401_no_ctrl      no_rx1_amp_ctrl  ( .amp( rx1_amp.AmpCtrl  ) );
    amp_lmh6401_no_gain_ctrl no_rx1_gain_ctrl ( .amp( rx1_amp.GainCtrl ) );
    adc_kad5512_nul_ctrl     no_rx1_adc_ctrl  ( .adc( rx1_adc.Ctrl     ) );
    adc_kad5512_nul_data     no_rx1_adc_data  ( .adc( rx1_adc.Data     ) );

    assign tx_dac.qmc_offset[0] = hdr.pa_dac_ctrlval[0];
    assign tx_dac.qmc_offset[1] = hdr.pa_dac_ctrlval[1];
    assign tx_dac.qmc_offset[2] = 0;
    assign tx_dac.qmc_offset[3] = 0;
    board_hsd_sdrbe #(
        .RX0SDR_EN ( `DEFINED(ENABLE_RX0_SDR)       ),
        .TXSDR_EN  ( `DEFINED(ENABLE_TX_SDR)        ),
        .TXDAC_JESD204C ( `DEFINED(TXDAC_JESD204C)  ),
        .TXDAC_1200MSPS ( `DEFINED(TXDAC_1200MSPS)  ),
        .USE_1200MSPS_DAC_INPUT (`DEFINED (ENABLE_TXDVBS2X))
    ) board_hsd_sdrbe_inst (
        .system       ( system.Backend               ),
        .sdr_rx       ( rx0_ctrl.Slave               ),
        .sdr_tx       ( tx_ctrl.Slave                ),
        .ssi_adc      ( rx0_ssi.Source               ),
        .ssi_dac      ( tx_ssi.Sink                  ),
        .ssi_dac_1200msps (tx_ssi_1200msps.Sink      ),
        .pll_adc      ( rx0_pll.Provider             ),
        .pll_dac      ( tx_pll.Provider              ),
        .adc          ( rx0_adc                      ),
        .amp          ( rx0_amp.AmpCtrl              ),
        .dac          ( tx_dac                       ),
        .spi_io       ( sdr_spi.Driver               ),
        .mmi_adc_ctrl ( mmi_dev[MMI_RXADC]     ),
        .mmi_adc_data ( mmi_dev[MMI_RXADCDATA] ),
        .mmi_amp_ctrl ( mmi_dev[MMI_RXAMP]     ),
        .mmi_dac_ctrl ( mmi_dev[MMI_TXDAC]     ),
        .mmi_dac_data ( mmi_dev[MMI_TXDAC_JESD]),
        .rx_pll_resetn( rx_pll_resetn                )
    );

    generate
        if (`DEFINED(ENABLE_RX0_SDR) || `DEFINED(ENABLE_RX1_SDR)) begin: gen_enable_rxsdr
            // No RXSDR capture on HSD: solely used to tie off the port
            SampleStream_int    # (.N_CHANNELS(2), .N_PARALLEL(1), .NB(12), .NB_FRAC(0), .PAUSABLE (0))
                rx_ssi_for_capture ( .clk(rx0_ssi.clk), .sresetn(rx0_ssi.sresetn));

            // TODO: enable some sort of a switch so that we can get ssi from either RX peripheral
            rxsdr # (
                .ENABLE_RXDSP                  ( `DEFINED(ENABLE_RXDSP)                              ),
                .ENABLE_RXDVBS2                ( `DEFINED(ENABLE_RXDVBS2)                            ),
                .RXFIFO_BYTEDEPTH              ( `DEFINED(ENABLE_RXFIFO) ? `HDR_RXFIFO_BUF_BYTES : 0 ),
                .DEMOD_N_PARALLEL              ( `DEMOD_N_PARALLEL                                   ),
                .PLL_SAMPLE_INDEX              ( 0                                                   ),
                .PLL_FEC_INDEX                 ( 2                                                   ),
                .PLL_DEMOD_INDEX               ( 3                                                   ),
                .INTER_AMP_PATH_LOSS           ( 6                                                   ),
                .ENABLE_SSD_CAPTURE            ( 1'b0                                                ),
                .ENABLE_SSI_BACKPRESSURE_COUNT ( 1'b1                                                ),
                .ENABLE_RX_BB_FRAME_COUNTER    ( 1'b1                                                ),
                .ENABLE_RX_BB_ERROR_COUNTER    ( 1'b0                                                )
            ) rxsdr_inst (
                .sdr                  ( sdr_rxsdr.Slave                   ),
                .ssi                  ( rx0_ssi.Sink                      ),
                .ssi_for_capture      ( rx_ssi_for_capture.Source         ),
                .axis                 ( eth_src[ETH_IDX_RXSDR_SRC]        ),
                .pll                  ( rx0_pll.User                      ),
                .mmi_rxdsp            ( mmi_dev[MMI_RXDSP]                ),
                .mmi_rxdata           ( mmi_dev[MMI_RXDATA]               ),
                .mmi_rxdata_bbfilt    ( mmi_dev[MMI_RX_BBFILT]            ),
                .mmi_rxdvbs2          ( mmi_upi_rx.Slave                  ),
                .mmi_rxfifo           ( mmi_dev[MMI_RXFIFO]               ),
                .mmi_pwr_pre_filter   ( mmi_dev[MMI_RX_PWR_PREFILT]       ),
                .mmi_pwr_post_filter  ( mmi_dev[MMI_RX_PWR_POSTFILT]      ),
                .mmi_bb_frame_counter ( mmi_dev[MMI_RX_BB_FRAME_COUNTER]  ),
                .mmi_bb_error_counter ( mmi_dev[MMI_RX_BB_ERROR_COUNTER]  ),
                .amp                  ( rx0_amp.GainCtrl                  ),
                .nco_phase_increment  ( nco_phase_increment               ),
                .nco_phase_offset     ( nco_phase_offset                  )
            );

            mmi_firewalled_arbiter #(
                .N              ( NUM_UPI_RX_MASTERS ),
                .ARB_TYPE       ( "priority"    ),
                .HIGHEST        ( 0             )
            ) upi_rx_bus_arb (
                .clk                ( clksys_drv                ),
                .sresetn            ( sdr_rxsdr.sresetn         ),
                .mmi_in             ( mmi_upi_rx_masters        ),
                .read_arb_lock      ( '0                        ),
                .write_arb_lock     ( '0                        ),
                .mmi_out            ( mmi_upi_rx.Master         ),
                .read_active_mask   (                           ),
                .write_active_mask  (                           ),
                .timeout_violation  (                           )
            );

            mmi_for_upi mmi_upi_rx_inst (
                .clk                ( clksys_drv                                    ),
                .sresetn            ( sdr_rxsdr.sresetn                             ),
                .mmi_from_master    ( mmi_dev[MMI_UPI_RXDEMOD]                ),
                .mmi_to_upi         ( mmi_upi_rx_masters[UPI_RX_MASTER_MAIN] )
            );

            mmi_upi_poll #(
                .N_ADDRS        ( MMI_UPI_POLL_PKG::N_ADDRS     ),
                .UPI_ADDRS      ( MMI_UPI_POLL_PKG::UPI_ADDRS   ),
                .POLL_PERIOD    ( MMI_UPI_POLL_PKG::POLL_PERIOD )
            ) mmi_upi_poll_inst (
                .sdr_ctrl       ( upi_poll.Slave                                ),
                .upi_initdone   ( sdr_rxsdr.initdone                            ),
                .mmi_out        ( mmi_dev[MMI_UPI_POLL]                   ),
                .mmi_upi        ( mmi_upi_rx_masters[UPI_RX_MASTER_POLL] )
            );
            assign upi_poll.sresetn = sdr_rxsdr.sresetn;

        end else begin : no_enable_rxsdr
            mmi_nul_slave   no_rxfifo         ( .mmi( mmi_dev[MMI_RXFIFO])                );
            mmi_nul_slave   no_rxpwr_prefilt  ( .mmi( mmi_dev[MMI_RX_PWR_PREFILT])        );
            mmi_nul_slave   no_rxpwr_postfilt ( .mmi( mmi_dev[MMI_RX_PWR_POSTFILT])       );
            mmi_nul_slave   no_upi_poll_slave ( .mmi( mmi_dev[MMI_UPI_POLL])              );

            amp_lmh6401_no_gain_ctrl no_rx0_gain_ctrl ( .amp( rx0_amp.GainCtrl ) );

            mmi_nul_slave   no_upi_rx_slave  ( .mmi(mmi_upi_rx.Slave) );
            mmi_nul_master  no_upi_rx_master ( .mmi(mmi_upi_rx.Master) );
            for (genvar i = 0; i < NUM_UPI_RX_MASTERS; i++) begin : no_upi_rx_i
                mmi_nul_slave   no_upi_rx_slv_i ( .mmi(mmi_upi_rx_masters[i]) );
            end
            mmi_nul_master  no_upi_rx_mst_main ( .mmi(mmi_upi_rx_masters[UPI_RX_MASTER_MAIN]) );
            mmi_nul_master  no_upi_rx_mst_poll ( .mmi(mmi_upi_rx_masters[UPI_RX_MASTER_POLL]) );

            axis_nul_src    no_rxsdr_axis_out ( .axis ( eth_src[ETH_IDX_RXSDR_SRC] ) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: DSSS Demodulator

    generate
        if (`DEFINED(ENABLE_DSSS_RX)) begin: gen_enable_dsss_rx
            // All interfaces are tied off internally if unused
            board_hsd_dsss_rx board_hsd_dsss_rx_inst (
                .sdr_ctrl            ( dsss_ctrl.Slave               ),
                .us_count            ( us_count                      ),
                .clk_60              ( rx0_pll.clk_out[4]            ),
                .clk_480             ( rx0_pll.clk_out[0]            ),
                .ssi_in              ( rx0_ssi.Sink                  ),
                .axis_out            ( eth_src[ETH_IDX_DSSS_SRC]     ),
                .mmi_dsss_rx_ctrl    ( mmi_dev[MMI_DSSS_RX_CTRL]     ),
                .mmi_dsss_demod      ( mmi_dev[MMI_DSSS_DEMODULATOR] ),
                .mmi_fec_dec         ( mmi_dev[MMI_DSSS_FEC_DECODER] ),
                .nco_phase_increment ( nco_phase_increment           ),
                .nco_phase_offset    ( nco_phase_offset              )
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: TX SDR Interface


    localparam int DEFAULT_TX_MUX_SEL = TXSDR_PKG::INTERNAL_SSI_SRC_IDX_DVB_S2;

    generate
        if (`DEFINED(ENABLE_TX_SDR) ) begin: gen_enable_txsdr

            AXIS_int #(.DATA_BYTES(4), .NB(16), .N_CHANNELS(2), .N_PARALLEL(1), .ALIGNED(1) )
                tx_axis_iq_tunnel ( .clk(tx_pll.clk_out[1]), .sresetn(tx_ssi_sresetn));

            AXIS_int #(
                .DATA_BYTES ( eth_sink[ETH_IDX_TXSDR_SINK].DATA_BYTES   )
            ) axis_txsdr (
                .clk        ( eth_sink[ETH_IDX_TXSDR_SINK].clk          ),
                .sresetn    ( eth_sink[ETH_IDX_TXSDR_SINK].sresetn      )
            );

            // This FIFO solves lost data packets on simpletoga GETs.
            // See https://keplercomm.atlassian.net/jira/software/projects/SD/issues/SD-712
            // TODO: (cbrown): consider moving this into txsdr
            // TODO: (cbrown): determine if the NIC FIFO can be eliminated
            if ( ! `DEFINED(ENABLE_NIC_CTRL) ) begin: gen_txsdr_fifo_no_nic
                axis_fifo_wrapper #(
                    .DEPTH              ( 2*MAX_PKTSIZE ),
                    .KEEP_ENABLE        ( 0             ),
                    .LAST_ENABLE        ( 1             ),
                    .ID_ENABLE          ( 0             ),
                    .DEST_ENABLE        ( 0             ),
                    .USER_ENABLE        ( 0             ),
                    .FRAME_FIFO         ( 1             ),
                    .FILL_LEVEL_ENABLE  ( 0             )
                ) axis_txsdr_fifo (
                    .axis_in            ( eth_sink[ETH_IDX_TXSDR_SINK]  ),
                    .axis_out           ( axis_txsdr                    ),
                    .reset_read_ptr     ( 0                             ),
                    .status_overflow    (),
                    .status_bad_frame   (),
                    .status_good_frame  (),
                    .fill_level         ()
                );
            end
            else begin
                axis_connect axis_txsdr_fifo_connect (
                    .axis_in    ( eth_sink[ETH_IDX_TXSDR_SINK] ),
                    .axis_out   ( axis_txsdr                   )
                );
            end

            // Tie off txsdr.axis_iq_tunnel_in, unused in HSD
            axis_nul_src no_tx_axis_iq_tunnel ( .axis(tx_axis_iq_tunnel.Master) );

            txsdr #(
                .DEFAULT_TX_MUX_SEL     ( DEFAULT_TX_MUX_SEL                                    ),
                .DEFAULT_TX_GAIN0       ( `DEFINED(ENABLE_KAS) ? 16'd13500 : 16'h3A00           ),
                .DEFAULT_TX_GAIN1       ( 16'h0000                                              ),
                .ENABLE_TXDVBS2         ( `DEFINED(ENABLE_TXDVBS2)                              ),
                .ENABLE_TXDVBS2X        ( `DEFINED(ENABLE_TXDVBS2X)                             ),
                .ENABLE_TXREPLAY        ( `DEFINED(TXREPLAY)                                    ),
                .ENABLE_TXREPLAY_BUF    ( `DEFINED(TXREPLAY_BUF)                                ),
                .ENABLE_RFOE            ( `DEFINED(ENABLE_RFOE)                                 ),
                .TXFIFO_DEPTH_MMI_WORDS ( `DEFINED(ENABLE_TXFIFO) ? `HDR_TXFIFO_BUF_BYTES/2 : 0 ),
                .TXDVBS2_FIFO_DEPTH     ( 2*MAX_PKTSIZE                                         ),
                .BLOCK_SIZE_EXPONENT    ( BLOCK_EXPONENT+9                                      ),
                .MMI_ADDRLEN            ( MMI_ADDRLEN                                           ),
                .MMI_DATALEN            ( MMI_DATALEN                                           ),
                .MOD_400MSYM            ( 1                                                     )
            ) txsdr_inst (
                /*
                // 300 Msym
                .clk_300                    ( tx_pll.clk_out[0]                    ), // 300 MHz clock, rising-edge aligned to ssi.clk
                .clk_mod                    ( tx_pll.clk_out[2]                    ), // 240 MHz clock
                */

                // 400 Msym
                .clk_300                    ( tx_pll.clk_out[0]                    ), // 400 MHz clock
                .clk_mod                    ( tx_pll.clk_out[1]                    ), // 200 MHz clock

                .sdr                        ( sdr_txsdr.Slave                      ),
                .ssi_ins                    ( tx_ssi_ext_ins                       ),
                .axis_iq_tunnel_in          ( tx_axis_iq_tunnel.Slave              ),
                .ssi_out                    ( tx_ssi.Source                        ), // 150 MHz clocked, rising-edge aligned to clk_300
                .ssi_out_dvbs2x             ( tx_ssi_1200msps.Source               ),
                .axis                       ( axis_txsdr                           ),
                .ms_pulse                   ( ms_pulse                             ),
                .acm_modcod_watchdog_action ( acm_modcod_watchdog_action.Watchdog  ),
                .bb_ctrl_replay             ( ssd_byte_ctrls[SSD_IDX_TXREPLAY]     ),
                .bb_read_replay             ( ssd_byte_reads[SSD_IDX_TXREPLAY]     ),
                .bb_ctrl_replay_buf         ( ddr_bb_ctrls[DDR_BB_IDX_TXREPLAY]    ),
                .bb_read_replay_buf         ( ddr_bb_reads[DDR_BB_IDX_TXREPLAY]    ),
                .bb_write_replay_buf        ( ddr_bb_writes[DDR_BB_IDX_TXREPLAY]   ),
                .mmi_dvbs2_data             ( mmi_dev[MMI_TXDATA]                  ),
                .mmi_dvbs2x_data            ( mmi_dev[MMI_TX_DVBS2X_DATA_FRAMER]   ),
                .mmi_dsp                    ( mmi_dev[MMI_TXDSP]                   ),
                .mmi_dvbs2_mod              ( mmi_dev[MMI_UPI_TXMOD]               ),
                .mmi_dvbs2x_mod             ( mmi_dev[MMI_TX_DVBS2X_MOD]           ),
                .mmi_buf                    ( mmi_dev[MMI_TXSDR_TXBUF]             ),
                .mmi_replay                 ( mmi_dev[MMI_TXREPLAY]                ),
                .mmi_nco                    ( mmi_dev[MMI_TXNCO]                   ),
                .mmi_symb_rate_div          ( mmi_dev[MMI_TX_DVBS2X_SYMB_RATE_DIV] ),
                .mmi_coeff_real             ( mmi_dev[MMI_TX_EQ_REAL]              ),
                .mmi_coeff_imag             ( mmi_dev[MMI_TX_EQ_IMAG]              )
            );

            // Null source for unused DSSS inputs
            ssi_nul_source no_dsss_tx ( .ssi(tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_DSSS]) );
        end else begin: gen_disable_txsdr
            sdr_ctrl_nul_slave no_sdr_tx                    ( .ctrl   ( sdr_txsdr.Slave                             ) );
            ssi_nul_source     no_tx_ssi                    ( .ssi    ( tx_ssi.Source                               ) );
            ssi_nul_source     no_tx_ssi_1200msps           ( .ssi    ( tx_ssi_1200msps.Source                      ) );
            mmi_nul_slave      no_txsdr_mmi_buf             ( .mmi    ( mmi_dev[MMI_TXSDR_TXBUF]              ) );
            mmi_nul_slave      no_txsdr_mmi_replay          ( .mmi    ( mmi_dev[MMI_TXREPLAY]                 ) );
            mmi_nul_slave      no_txsdr_mmi_nco             ( .mmi    ( mmi_dev[MMI_TXNCO]                    ) );
            bb_nul_client      no_bb_ctrl_replay            ( .bbctrl ( ssd_byte_ctrls[SSD_IDX_TXREPLAY]     ) );
            axis_nul_sink      no_bb_read_replay            ( .axis   ( ssd_byte_reads[SSD_IDX_TXREPLAY]      ) );
            bb_nul_client      no_bb_ctrl_replay_buf        ( .bbctrl ( ddr_bb_ctrls[DDR_BB_IDX_TXREPLAY]  ) );
            axis_nul_sink      no_bb_read_replay_buf        ( .axis   ( ddr_bb_reads[DDR_BB_IDX_TXREPLAY]   ) );
            axis_nul_src       no_bb_write_replay_buf       ( .axis   ( ddr_bb_writes[DDR_BB_IDX_TXREPLAY] ) );
            axis_nul_sink      no_txsdr_axis_in             ( .axis   ( eth_sink[ETH_IDX_TXSDR_SINK]          ) );
            mon_watchdog_action_nul    no_acm_watchdog_act  ( .watchdog ( acm_modcod_watchdog_action.Watchdog ) );
        end
    endgenerate

    // txreplay does not use a write stream
    axis_nul_src txsdr_replay_no_write ( .axis(ssd_byte_writes[SSD_IDX_TXREPLAY]) );

`ifdef ENABLE_RX0_SDR
    `define HAVE_MMI_RX 1   // RXDSP, RXDATA, UPI_RXDEMOD
`endif
`ifdef ENABLE_RX1_SDR
    `define HAVE_MMI_RX 1   // RXDSP, RXDATA, UPI_RXDEMOD
`endif
`ifdef ENABLE_TX_SDR
    `define HAVE_MMI_TXDATA 1
    `define HAVE_MMI_TXDSP 1
    `define HAVE_MMI_UPI_TXMOD 1
`endif


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: SSD Control


`ifdef ENABLE_SSD_CTRL

    SDR_Ctrl_int #(1) ssd_ctrl_slaves `PL_SATA_ARRAY_DEF ( .clk(clksys_drv) );

    sata_init_ctrl_mmi #(
        .N_SATA                ( `N_PL_SATA               ),
        .DEFAULT_ENABLES_VAL   ( `PL_SATA_ENABLE_INIT_VAL ),
        .CLK_FREQ              ( CLKSYS_FREQ              ),
        .RETRY_TIMEOUT_SECONDS ( 2                        ),
        .RESET_PULSE_CYCLES    ( 10                       )
    ) sata_init_ctrl_mmi_inst  (
        .board_sresetn    ( sresetn                         ),
        .ssd_present_n    ( pl_ssd_present_n                ),
        .sata_ctrl_master ( ssd_ctrl.Slave                  ),
        .sata_ctrl_slaves ( ssd_ctrl_slaves                 ),
        .sata_enables     ( en_pl_ssd                       ),
        .mmi              ( mmi_dev[MMI_SATA_INIT_CTRL]     )
    );

    sata_ps_ssd_pwr_ctrl_mmi #(
        .N_SATA                 ( 2 )
    ) ps_ssd_pwr_ctrl_inst (
        .clk                ( clksys_drv                ),
        .sresetn            ( sresetn                   ),
        .en_ps_ssd          ( en_ps_ssd                 ),
        .ps_ssd_present_n   ( ps_ssd_present_n          ),
        .mmi                ( mmi_dev[MMI_PS_SSD_CTRL]  )
    );

    // SSD0: The SATA stack, block layer, and block_byte layer:
    sata #(
        .TRANSCEIVER_FAMILY      ( "GTH-US"                   ),
        .USE_FEC                 ( `DEFINED(FEC_ON_SSD)       ),
        .SATA_FIFO_ADDRESS_WIDTH ( `SATA_0_FIFO_ADDRESS_WIDTH )
    ) sata0_inst (
        .sysclk                 ( clksys_drv                                ),
        .rst                    ( ~ssd_ctrl_slaves[0].sresetn               ),
        .ssd_initdone           ( ssd_ctrl_slaves[0].initdone               ),
        .us_pulse               ( us_pulse                                  ),
        .sata_io                ( sata_io[0]                           ),
        .mmi_ctrl               ( mmi_dev[MMI_SATA_CTRL]              ),
        .mmi_drp                ( mmi_dev[MMI_SATA_DRP]               ),
        .mmi_perf               ( mmi_dev[MMI_SATA_PERF]              ),
        .mmi_block_traffic      ( mmi_dev[MMI_SATA_BLOCK_TRAFFIC_GEN] ),
        .backend_ready          ( ssd_backend_ready[0]                      ),
        .byte_ctrl              ( ssd_byte_ctrl.Provider                    ),
        .axis_byte_write        ( ssd_byte_write.Slave                      ),
        .axis_byte_read         ( ssd_byte_read.Master                      ),
        .byte_ctrl_for_mmi      ( ssd_byte_ctrls[SSD_IDX_MMI]       ),
        .axis_byte_write_for_mmi( ssd_byte_writes[SSD_IDX_MMI]       ),
        .axis_byte_read_for_mmi ( ssd_byte_reads[SSD_IDX_MMI]       )
    );

    // The arbiter.
    // Note that we use ARB_TYPE = "priority". This means lower priority values can
    // starve out higher interfaces. We have arranged the order so that the lower enum
    // values in sata_mux_indices are the ones that have tighter time requirements.
    bb_arbiter #(
        .N                  ( SSD_NUM_INDICES   ),
        .ARB_TYPE           ( "priority"        ),  // "priority" or "round-robin"
        .HIGHEST            ( 0                 )   // lower indices are higher priority
    ) sata_arbiter_inst (
        .clk                ( clksys_drv                    ),
        .rst                ( ~ssd_ctrl.sresetn             ),
        .ctrl_in            ( ssd_byte_ctrls                ),
        .ctrl_out           ( ssd_byte_ctrl.Client          ),
        .byte_write_in      ( ssd_byte_writes               ),
        .byte_write_out     ( ssd_byte_write.Master         ),
        .byte_read_out      ( ssd_byte_reads                ),
        .byte_read_in       ( ssd_byte_read.Slave           )
    );

    // Generate SATA instances that are currently just looped back for testing
    generate
        if (`N_PL_SATA > 1) begin: gen_sata1
            // SSD1: The SATA stack, block layer, and block_byte layer:
            // Loopback for testing
            BlockByteCtrl_int ssd1_byte_ctrl           ( .backend_ready  ( ssd_backend_ready[1] ));
            AXIS_int #(.DATA_BYTES(1)) ssd1_byte_write ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
            AXIS_int #(.DATA_BYTES(1)) ssd1_byte_read  ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );

            sata #(
                .TRANSCEIVER_FAMILY      ( "GTH-US"                       ),
                .USE_FEC                 ( `DEFINED(FEC_ON_SSD)           ),
                .SATA_FIFO_ADDRESS_WIDTH ( `SATA_1_2_3_FIFO_ADDRESS_WIDTH )
            ) sata1_inst (
                .sysclk                 ( clksys_drv                                 ),
                .rst                    ( ~ssd_ctrl_slaves[1].sresetn                ),
                .ssd_initdone           ( ssd_ctrl_slaves[1].initdone                ),
                .us_pulse               ( us_pulse                                   ),
                .sata_io                ( sata_io[1]                            ),
                .mmi_ctrl               ( mmi_dev[MMI_SATA1_CTRL]              ),
                .mmi_drp                ( mmi_dev[MMI_SATA1_DRP]               ),
                .mmi_perf               ( mmi_dev[MMI_SATA1_PERF]              ),
                .mmi_block_traffic      ( mmi_dev[MMI_SATA1_BLOCK_TRAFFIC_GEN] ),
                .backend_ready          ( ssd_backend_ready[1]                       ),
                .byte_ctrl              ( ssd1_byte_ctrl.Provider                    ),
                .axis_byte_write        ( ssd1_byte_write.Slave                      ),
                .axis_byte_read         ( ssd1_byte_read.Master                      ),
                .byte_ctrl_for_mmi      ( ssd1_byte_ctrl.Client                      ),
                .axis_byte_write_for_mmi( ssd1_byte_write.Master                     ),
                .axis_byte_read_for_mmi ( ssd1_byte_read.Slave                       )
            );
        end else begin: no_sata1
            mmi_nul_slave no_mmi_sata1_ctrl ( .mmi(mmi_dev[MMI_SATA1_CTRL]));
            mmi_nul_slave no_mmi_sata1_drp  ( .mmi(mmi_dev[MMI_SATA1_DRP] ));
            mmi_nul_slave no_mmi_sata1_perf ( .mmi(mmi_dev[MMI_SATA1_PERF]));
        end

        if (`N_PL_SATA > 2) begin: gen_sata2
            // SSD2: The SATA stack, block layer, and block_byte layer:
            // Loopback for testing
            BlockByteCtrl_int ssd2_byte_ctrl           ( .backend_ready  ( ssd_backend_ready[2] ));
            AXIS_int #(.DATA_BYTES(1)) ssd2_byte_write ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
            AXIS_int #(.DATA_BYTES(1)) ssd2_byte_read  ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );

            sata #(
                .TRANSCEIVER_FAMILY      ( "GTH-US"                       ),
                .USE_FEC                 ( `DEFINED(FEC_ON_SSD)           ),
                .SATA_FIFO_ADDRESS_WIDTH ( `SATA_1_2_3_FIFO_ADDRESS_WIDTH )
            ) sata2_inst (
                .sysclk                 ( clksys_drv                                 ),
                .rst                    ( ~ssd_ctrl_slaves[2].sresetn                ),
                .ssd_initdone           ( ssd_ctrl_slaves[2].initdone                ),
                .us_pulse               ( us_pulse                                   ),
                .sata_io                ( sata_io[2]                            ),
                .mmi_ctrl               ( mmi_dev[MMI_SATA2_CTRL]              ),
                .mmi_drp                ( mmi_dev[MMI_SATA2_DRP]               ),
                .mmi_perf               ( mmi_dev[MMI_SATA2_PERF]              ),
                .mmi_block_traffic      ( mmi_dev[MMI_SATA2_BLOCK_TRAFFIC_GEN] ),
                .backend_ready          ( ssd_backend_ready[2]                       ),
                .byte_ctrl              ( ssd2_byte_ctrl.Provider                    ),
                .axis_byte_write        ( ssd2_byte_write.Slave                      ),
                .axis_byte_read         ( ssd2_byte_read.Master                      ),
                .byte_ctrl_for_mmi      ( ssd2_byte_ctrl.Client                      ),
                .axis_byte_write_for_mmi( ssd2_byte_write.Master                     ),
                .axis_byte_read_for_mmi ( ssd2_byte_read.Slave                       )
            );
        end else begin: no_sata2
            mmi_nul_slave no_mmi_sata2_ctrl ( .mmi(mmi_dev[MMI_SATA2_CTRL]));
            mmi_nul_slave no_mmi_sata2_drp  ( .mmi(mmi_dev[MMI_SATA2_DRP] ));
            mmi_nul_slave no_mmi_sata2_perf ( .mmi(mmi_dev[MMI_SATA2_PERF]));
        end

        if (`N_PL_SATA > 3) begin: gen_sata3
            // SSD3: The SATA stack, block layer, and block_byte layer:
            // Loopback for testing
            BlockByteCtrl_int ssd3_byte_ctrl           ( .backend_ready  ( ssd_backend_ready[3] ));
            AXIS_int #(.DATA_BYTES(1)) ssd3_byte_write ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );
            AXIS_int #(.DATA_BYTES(1)) ssd3_byte_read  ( .clk ( clksys_drv ), .sresetn ( ssd_ctrl.sresetn ) );

            sata #(
                .TRANSCEIVER_FAMILY      ( "GTH-US"                       ),
                .USE_FEC                 ( `DEFINED(FEC_ON_SSD)           ),
                .SATA_FIFO_ADDRESS_WIDTH ( `SATA_1_2_3_FIFO_ADDRESS_WIDTH )
            ) sata3_inst (
                .sysclk                 ( clksys_drv                                 ),
                .rst                    ( ~ssd_ctrl_slaves[3].sresetn                ),
                .ssd_initdone           ( ssd_ctrl_slaves[3].initdone                ),
                .us_pulse               ( us_pulse                                   ),
                .sata_io                ( sata_io[3]                            ),
                .mmi_ctrl               ( mmi_dev[MMI_SATA3_CTRL]              ),
                .mmi_drp                ( mmi_dev[MMI_SATA3_DRP]               ),
                .mmi_perf               ( mmi_dev[MMI_SATA3_PERF]              ),
                .mmi_block_traffic      ( mmi_dev[MMI_SATA3_BLOCK_TRAFFIC_GEN] ),
                .backend_ready          ( ssd_backend_ready[3]                       ),
                .byte_ctrl              ( ssd3_byte_ctrl.Provider                    ),
                .axis_byte_write        ( ssd3_byte_write.Slave                      ),
                .axis_byte_read         ( ssd3_byte_read.Master                      ),
                .byte_ctrl_for_mmi      ( ssd3_byte_ctrl.Client                      ),
                .axis_byte_write_for_mmi( ssd3_byte_write.Master                     ),
                .axis_byte_read_for_mmi ( ssd3_byte_read.Slave                       )
            );
        end else begin: no_sata3
            mmi_nul_slave no_mmi_sata3_ctrl ( .mmi(mmi_dev[MMI_SATA3_CTRL]));
            mmi_nul_slave no_mmi_sata3_drp  ( .mmi(mmi_dev[MMI_SATA3_DRP] ));
            mmi_nul_slave no_mmi_sata3_perf ( .mmi(mmi_dev[MMI_SATA3_PERF]));
        end
    endgenerate

    generate
        for (genvar i = 0; i < UTIL_INTS::S_INT_MAX(1, `N_PL_SATA); i++) begin
            assign ssd_ctrl_slaves[i].state = 'X;   // unused
        end
    endgenerate
`else   // !ENABLE_SSD_CTRL
    generate
        // If N_PL_SATA == 0 then sata_io is [0:0]. In that case, to get rid of undriven pin warnings,
        // we still want to tie off sata_io[0]. The 1 parameter to S_INT_MAX statement makes sure we
        // enter the loop at least once.
        for (genvar i = 0; i < UTIL_INTS::S_INT_MAX(1, `N_PL_SATA); i++) begin: no_sata_io
            assign sata_io[i].TXN_OUT = 1'b0;
            assign sata_io[i].TXP_OUT = 1'b0;
        end
    endgenerate

    // Tie off all the interfaces that would otherwise be provided by sata and bb_arbiter.
    mmi_nul_slave   no_mmi_sata_ctrl    ( .mmi(mmi_dev[MMI_SATA_CTRL])                );
    mmi_nul_slave   no_mmi_sata_drp     ( .mmi(mmi_dev[MMI_SATA_DRP] )                );
    mmi_nul_slave   no_mmi_sata_perf    ( .mmi(mmi_dev[MMI_SATA_PERF])                );
    mmi_nul_slave   no_mmi_block_traf   ( .mmi(mmi_dev[MMI_SATA_BLOCK_TRAFFIC_GEN])   );
    bb_nul_provider no_ssd_provider     ( .bbctrl(ssd_byte_ctrl.Provider)                   );
    bb_nul_client   no_ssd_client       ( .bbctrl(ssd_byte_ctrl.Client)                     );
    axis_nul_sink   no_ssd_byte_write_s ( .axis(ssd_byte_write.Slave)                       );
    axis_nul_src    no_ssd_byte_write_m ( .axis(ssd_byte_write.Master)                      );
    axis_nul_sink   no_ssd_byte_read_s  ( .axis(ssd_byte_read.Slave)                        );
    axis_nul_src    no_ssd_byte_read_m  ( .axis(ssd_byte_read.Master)                       );
    bb_nul_client   no_ssd_mmi          ( .bbctrl(ssd_byte_ctrls[SSD_IDX_MMI])       );
    axis_nul_src    no_ssd_mmi_write    ( .axis(ssd_byte_writes[SSD_IDX_MMI])       );
    axis_nul_sink   no_ssd_mmi_read     ( .axis(ssd_byte_reads[SSD_IDX_MMI])       );

    mmi_nul_slave   no_mmi_sata1_ctrl   ( .mmi(mmi_dev[MMI_SATA1_CTRL])               );
    mmi_nul_slave   no_mmi_sata1_drp    ( .mmi(mmi_dev[MMI_SATA1_DRP] )               );
    mmi_nul_slave   no_mmi_sata1_perf   ( .mmi(mmi_dev[MMI_SATA1_PERF])               );
    mmi_nul_slave   no_mmi_sata1_b_traf ( .mmi(mmi_dev[MMI_SATA1_BLOCK_TRAFFIC_GEN])  );

    mmi_nul_slave   no_mmi_sata2_ctrl   ( .mmi(mmi_dev[MMI_SATA2_CTRL])               );
    mmi_nul_slave   no_mmi_sata2_drp    ( .mmi(mmi_dev[MMI_SATA2_DRP] )               );
    mmi_nul_slave   no_mmi_sata2_perf   ( .mmi(mmi_dev[MMI_SATA2_PERF])               );
    mmi_nul_slave   no_mmi_sata2_b_traf ( .mmi(mmi_dev[MMI_SATA2_BLOCK_TRAFFIC_GEN])  );

    mmi_nul_slave   no_mmi_sata3_ctrl   ( .mmi(mmi_dev[MMI_SATA3_CTRL])               );
    mmi_nul_slave   no_mmi_sata3_drp    ( .mmi(mmi_dev[MMI_SATA3_DRP])                );
    mmi_nul_slave   no_mmi_sata3_perf   ( .mmi(mmi_dev[MMI_SATA3_PERF])               );
    mmi_nul_slave   no_mmi_sata3_b_traf ( .mmi(mmi_dev[MMI_SATA3_BLOCK_TRAFFIC_GEN])  );

    mmi_nul_slave   no_mmi_sata_init    ( .mmi(mmi_dev[MMI_SATA_INIT_CTRL])           );
    mmi_nul_slave   no_mmi_ps_ssd_ctrl  ( .mmi(mmi_dev[MMI_PS_SSD_CTRL])              );

    generate
        for (genvar i = 0; i < SSD_NUM_INDICES; i++) begin : gen_no_ssd_providers
            bb_nul_provider no_ssd_provider_i   ( .bbctrl(ssd_byte_ctrls[i]) );
            axis_nul_src    no_ssd_reads_i      ( .axis(ssd_byte_reads[i]) );
            axis_nul_sink   no_ssd_writes_i     ( .axis(ssd_byte_writes[i]) );
        end
    endgenerate

    assign ssd_backend_ready    = '0;
    assign en_pl_ssd            = '0;
    assign en_ps_ssd            = '0;
    sdr_ctrl_nul_slave #(.REPORT_INITDONE ( 1 )) no_ssd_ctrl (.ctrl(ssd_ctrl.Slave));

`endif  // !ENABLE_SSD_CTRL

    board_hsd_ssd_apps #(
        .EN_SSD             ( `DEFINED(ENABLE_SSD_CTRL) ),
        .EN_TRAFFIC_TEST    ( `DEFINED(BB_TRAFFIC_TEST) )
    ) ssd_apps_inst (
        // OBC/SSD bulk transfer
        .mmi_obc_read       ( mmi_dev[MMI_OBC_SSD_READ] ),
        .bb_ctrl_obc_read   ( ssd_byte_ctrls[SSD_IDX_OBC_READ] ),
        .bb_read_obc_read   ( ssd_byte_reads[SSD_IDX_OBC_READ] ),
        .mmi_obc_write      ( mmi_dev[MMI_OBC_SSD_WRITE] ),
        .bb_ctrl_obc_write  ( ssd_byte_ctrls[SSD_IDX_OBC_WRITE] ),
        .bb_write_obc_write ( ssd_byte_writes[SSD_IDX_OBC_WRITE] ),

        // SSD test traffic generator
        .mmi_traffic        ( mmi_dev[MMI_SATA_TRAFFIC_GEN] ),
        .bb_ctrl_traffic    ( ssd_byte_ctrls[SSD_IDX_TRAFFIC_TEST] ),
        .bb_read_traffic    ( ssd_byte_reads[SSD_IDX_TRAFFIC_TEST] ),
        .bb_write_traffic   ( ssd_byte_writes[SSD_IDX_TRAFFIC_TEST] ),

        .irq_out            ( obc_irq_in[OBC_IRQ_SSD_WRITE_BUFFER_READY:OBC_IRQ_SSD_READ_FILE_READY] )
    );
    axis_nul_src    obc_ssd_buf_read_no_write ( .axis (ssd_byte_writes[SSD_IDX_OBC_READ]) );
    axis_nul_sink   obc_ssd_buf_write_no_read ( .axis (ssd_byte_reads[SSD_IDX_OBC_WRITE]) );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: HDR Module


    generate
        if (`DEFINED(ENABLE_HDR)) begin : gen_hdr
            board_hsd_hdr # (
                .LBAND           ( `DEFINED(LBAND)  ),
                .CPM_TRANS_DEPTH ( `DEFINED(ENABLE_CPM_TRANS_HDR) ? `CPM_TRANS_BUFFER_DEPTH : 0)
            ) hdr_inst (
                .sdr                ( hdr_ctrl.Slave                          ),
                .sdr_pa             ( hdrpa_ctrl.Slave                        ),
                .hdr                ( hdr.Module                              ),
                .cpm                ( hdr_cpm                                 ),
                .spi_io             ( hdr_spi.Driver                          ),
                .i2c_io             ( hdr_i2c.Driver                          ),
                .i2c_clk_divide     ( i2c_clk_divide                          ),
                .i2c_clk_divide_stb ( i2c_clk_divide_stb[I2C_CLK_DIV_HDR_IDX] ),
                .temp_limits        ( temp_limits_hdr                         ),
                .mmi_synth_rx       ( mmi_dev[MMI_FE_SYNTHRX]                 ),
                .mmi_synth_tx       ( mmi_dev[MMI_FE_SYNTHTX]                 ),
                .mmi_adc            ( mmi_dev[MMI_FE_ADC]                     ),
                .mmi_cpm            ( mmi_dev[MMI_HDR_CPM]                    ),
                .mmi_cpm_alarm      ( mmi_dev[MMI_HDR_CPM_VLIM]               ),
                .mmi_cpm_maxval     ( mmi_dev[MMI_HDR_CPM_MAXVAL]             ),
                .mmi_cpm_trans      ( mmi_dev[MMI_ITRANS_HDR]                 ),
                .mmi_temp_limits    ( mmi_dev[MMI_HDR_TEMP_LIMIT]             ),
                .us_count           ( us_count[27:0]                          )
            );
        end else begin : no_hdr
            sdr_ctrl_nul_slave      no_ctrl                ( .ctrl   ( hdr_ctrl.Slave                 ));
            sdr_ctrl_nul_slave      no_fepa                ( .ctrl   ( hdrpa_ctrl.Slave               ));
            assign hdr.pa_dac_ctrlval[0]  = '0;
            assign hdr.pa_dac_ctrlval[1]  = '0;
            assign hdr_cpm.alert_valid    = '0;
            cpm_nul_ctrl            no_cpm                 ( .cpm    ( hdr_cpm.Ctrl                   ));
            cpm_nul_vbus_alarms     no_cpm_vbus            ( .cpm    ( hdr_cpm.VBusAlerts             ));
            mon_limits_nul_src      no_temp_limits_src     ( .src    ( temp_limits_hdr.Source         ));
            mon_limits_nul_sink     no_temp_limits_sink    ( .sink   ( temp_limits_hdr.Sink           ));
            mmi_nul_slave           no_adc_mmi_inst        ( .mmi    ( mmi_dev[MMI_FE_ADC]            ));
            mmi_nul_slave           no_cpm_mmi_inst        ( .mmi    ( mmi_dev[MMI_HDR_CPM]           ));
            mmi_nul_slave           no_cpm_alarm_inst      ( .mmi    ( mmi_dev[MMI_HDR_CPM_VLIM]      ));
            mmi_nul_slave           no_cpm_maxval_inst     ( .mmi    ( mmi_dev[MMI_HDR_CPM_MAXVAL]    ));
            mmi_nul_slave           no_cpm_trans_mmi       ( .mmi    ( mmi_dev[MMI_ITRANS_HDR]        ));
            mmi_nul_slave           no_temp_lim_mmi        ( .mmi    ( mmi_dev[MMI_HDR_TEMP_LIMIT]    ));
            spi_nul_io_driver       no_hdr_spi_inst        ( .drv    ( hdr_spi.Driver                 ));
            i2c_nul_io_drv          no_hdr_i2c_inst        ( .drv    ( hdr_i2c.Driver                 ));
            mmi_nul_slave           no_synth_rx_mmi_inst   ( .mmi    ( mmi_dev[MMI_FE_SYNTHRX]        ));
            mmi_nul_slave           no_synth_tx_mmi_inst   ( .mmi    ( mmi_dev[MMI_FE_SYNTHTX]        ));
        end
    endgenerate

    generate
        if (`DEFINED(ENABLE_KAS)) begin : gen_kas
            board_hsd_kas # (
                .MMI_ADDRLEN        ( MMI_ADDRLEN ),
                .MMI_DATALEN        ( MMI_DATALEN ),
                .SDR_CLK_FREQ       ( CLKSYS_FREQ ),
                .I2C_CLK_DIV        ( KAS_I2C_CLKDIV ),
                .IOEXP_HALF_CLK_DIV ( KAS_IOEXP_HALF_CLKDIV ),
                .CPM_TRANS_DEPTH    ( `DEFINED(ENABLE_CPM_TRANS_KAS) ? `CPM_TRANS_BUFFER_DEPTH : 0)
            ) kas_inst (
                .sdr                ( kas_ctrl.Slave                          ),
                .vstby_initdone     ( kas_vstby_initdone                      ),
                .kas                ( kas.Module                              ),
                .spi_3v3_io         ( kas_spi_3v3.Driver                      ),
                .spi_1v8_io         ( kas_spi_1v8.Driver                      ),
                .i2c_io             ( kas_i2c.Driver                          ),
                .ioexp_io           ( kas_ioexp.Driver                        ),
                .cpm                ( kas_cpm                                 ),
                .i2c_clk_divide     ( i2c_clk_divide                          ),
                .i2c_clk_divide_stb ( i2c_clk_divide_stb[I2C_CLK_DIV_KAS_IDX] ),
                .temp_limits        ( temp_limits_kas                         ),
                .mmi_synth_rx       ( mmi_dev[MMI_KAS_SYNTHRX]                ),
                .mmi_synth_tx       ( mmi_dev[MMI_KAS_SYNTHTX]                ),
                .mmi_iqmod          ( mmi_dev[MMI_KAS_IQMOD]                  ),
                .mmi_dac            ( mmi_dev[MMI_KAS_DAC]                    ),
                .mmi_adc            ( mmi_dev[MMI_KAS_ADC]                    ),
                .mmi_i2c            ( mmi_dev[MMI_KAS_I2C]                    ),
                .mmi_cpm            ( mmi_dev[MMI_KAS_CPM]                    ),
                .mmi_cpm_alarm      ( mmi_dev[MMI_KAS_CPM_VLIM]               ),
                .mmi_cpm_maxval     ( mmi_dev[MMI_KAS_CPM_MAXVAL]             ),
                .mmi_cpm_trans      ( mmi_dev[MMI_ITRANS_KAS]                 ),
                // .mmi_nano_dac       ( mmi_dev[MMI_KAS_NANO_DAC]               ),
                .mmi_temp_limits    ( mmi_dev[MMI_KAS_TEMP_LIMIT]             ),
                .mmi_tx_alc         ( mmi_dev[MMI_TX_ALC]                     ),
                .us_count           ( us_count[27:0]                          )
            );
        end else begin : no_kas
            sdr_ctrl_nul_slave              no_ctrl              ( .ctrl                 ( kas_ctrl.Slave               ));
            assign kas_cpm.alert_valid= '0;
            cpm_nul_ctrl                    no_cpm               ( .cpm                  ( kas_cpm.Ctrl                 ));
            cpm_nul_vbus_alarms             no_cpm_vbus          ( .cpm                  ( kas_cpm.VBusAlerts           ));
            mon_limits_nul_src              no_temp_limits_src   ( .src                  ( temp_limits_kas.Source       ));
            mon_limits_nul_sink             no_temp_limits_sink  ( .sink                 ( temp_limits_kas.Sink         ));
            mmi_nul_slave                   no_i2c_mmi_inst      ( .mmi                  ( mmi_dev[MMI_KAS_I2C]         ));
            mmi_nul_slave                   no_cpm_mmi_inst      ( .mmi                  ( mmi_dev[MMI_KAS_CPM]         ));
            mmi_nul_slave                   no_cpm_alarm_inst    ( .mmi                  ( mmi_dev[MMI_KAS_CPM_VLIM]    ));
            mmi_nul_slave                   no_cpm_maxval_inst   ( .mmi                  ( mmi_dev[MMI_KAS_CPM_MAXVAL]  ));
            mmi_nul_slave                   no_cpm_trans_mmi     ( .mmi                  ( mmi_dev[MMI_ITRANS_KAS]      ));
            mmi_nul_slave                   no_temp_lim_mmi      ( .mmi                  ( mmi_dev[MMI_KAS_TEMP_LIMIT]  ));
            ioexp_serial_out_nul_driver     no_kas_ioexp_inst    ( .ioexp_serial_out     ( kas_ioexp.Driver             ));
            spi_nul_io_driver               no_kas_spi_3v3_inst  ( .drv                  ( kas_spi_3v3.Driver           ));
            spi_nul_io_driver               no_kas_spi_1v8_inst  ( .drv                  ( kas_spi_1v8.Driver           ));
            i2c_nul_io_drv                  no_kas_i2c_inst      ( .drv                  ( kas_i2c.Driver               ));
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Backplane Module


    board_hsd_bp # (
        .ENABLE_BACKPLANE       ( `DEFINED(ENABLE_BACKPLANE)                       ),
        .BP_CPM_TRANS_DEPTH     ( `DEFINED(ENABLE_CPM_TRANS_BP)  ? `CPM_TRANS_BUFFER_DEPTH : 0),
        .I2C_CTRL_CLOCK_FREQ_HZ ( CLKSYS_FREQ ),
        .DEFAULT_I2C_CLK_DIVIDE ( BP_I2C_CLKDIV )
    ) bp_inst (
        .sdr_bp                 ( bp_ctrl.Slave                             ),
        .bp_ioexp               ( bp_ioexp.Ctrl                             ),
        .sec_ioexp              ( sec_ioexp.Ctrl                            ),
        .bp_cpm                 ( bp_cpm                                    ),
        .bp_i2c                 ( bp_i2c.Driver                             ),
        .i2c_clk_divide         ( i2c_clk_divide                            ),
        .i2c_clk_divide_stb     ( i2c_clk_divide_stb[I2C_CLK_DIV_BP_IDX]    ),
        .mmi_bp_cpm             ( mmi_dev[MMI_BP_CPM]                 ),
        .mmi_bp_ioexp           ( mmi_dev[MMI_BP_IO]                  ),
        .mmi_sec_ioexp          ( mmi_dev[MMI_BP_IO_SEC]              ),
        .mmi_cpm_alarm_bp       ( mmi_dev[MMI_BP_CPM_VLIM]            ),
        .mmi_cpm_maxval_bp      ( mmi_dev[MMI_BP_CPM_MAXVAL]          ),
        .mmi_cpm_trans_bp       ( mmi_dev[MMI_ITRANS_BP]              ),
        .us_count               ( us_count[27:0]                            )
    );


    //TODO: Hook up the "alert" pin of bp_cpm.

    assign bp_en_tempsns = temp_ctrl.sresetn;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: NIC Module


    generate
        if (`DEFINED(ENABLE_NIC_CTRL)) begin: gen_enable_nic_ctrl
            // 4 channel IQ: currently solely used as a tie-off (comes from LDR in PCH)
            SampleStream_int    # (.N_CHANNELS(8), .N_PARALLEL(1), .NB(16), .NB_FRAC(0), .PAUSABLE (0) )
                rfoe_ssi_in  ( .clk(rx0_ssi.clk), .sresetn(rx0_ssi.sresetn));

            board_hsd_nic #(
                .MMI_DATALEN           ( MMI_DATALEN                                ),
                .SIMPLETOGA_RX_PKTSIZE (`SIMPLETOGA_RX_PKTSIZE                      ),
                .SIMPLETOGA_TX_PKTSIZE (`SIMPLETOGA_TX_PKTSIZE                      ),
                .ENABLE_MMIOE          (`DEFINED(NIC_MMIOE)                         ),
                .ENABLE_RFOE           (`DEFINED(ENABLE_RFOE)                       ),
                .DBUF_MMI_DEV_WIDTH    (DEV_WIDTH[MMI_TDI_TXDBUF]                   ),
                .RFOE_SINK_SAMPLE_FIFO_DEPTH_EXP(`RFOE_SINK_SAMPLE_FIFO_DEPTH_EXP   ),
                .RFOE_SRC_SAMPLE_FIFO_DEPTH_EXP (`RFOE_SRC_SAMPLE_FIFO_DEPTH_EXP    ),
                .RFOE_PAYLOAD_BYTES    (`RFOE_PAYLOAD_BYTES                         )
            ) nic_sdr_inst (
                .sdr                 ( nic_ctrl.Slave                                              ),
                .mmi_nic             ( mmi_dev[MMI_NIC_SDR]                                        ),
                .mmi_udphdr          ( mmi_dev[MMI_NICHDR_CTRL]                                    ),
                .mmi_rxbuf           ( mmi_dev[MMI_TDI_RXDBUF]                                     ),
                .mmi_txbuf           ( mmi_dev[MMI_TDI_TXDBUF]                                     ),
                .mmi_rfoe            ( mmi_dev[MMI_RFOE_CTRL]                                      ),
                .mmi_out             ( mmi_masters[MMI_MASTER_MMIOE]                               ),
                .axis_tx             ( eth_src[ETH_IDX_NIC_SRC]                                    ),
                .axis_rx             ( eth_sink[ETH_IDX_NIC_SINK]                                  ),
                .bb_ctrl_simpletoga  ( ssd_byte_ctrls [SSD_IDX_SIMPLETOGA]                         ),
                .bb_write_simpletoga ( ssd_byte_writes[SSD_IDX_SIMPLETOGA]                         ),
                .bb_read_simpletoga  ( ssd_byte_reads [SSD_IDX_SIMPLETOGA]                         ),
                .bb_ctrl_qspi        ( qspi_bb_ctrls[ZYNQ_QSPI_HSD::BB_QSPI_NIC]                   ),
                .bb_write_qspi       ( qspi_bb_writes[ZYNQ_QSPI_HSD::BB_QSPI_NIC]                  ),
                .bb_read_qspi        ( qspi_bb_reads[ZYNQ_QSPI_HSD::BB_QSPI_NIC]                   ),
                .rfoe_ssi_in         ( rfoe_ssi_in.Sink                                            ),
                .rfoe_ssi_out        ( rfoe_ssi_out.Source                                         ),
                .acm_watchdog_action ( acm_modcod_watchdog_action.Petter                           ),
                .irq_out             ( obc_irq_in[OBC_IRQ_TX_BUFFER_READY:OBC_IRQ_RX_PACKET_READY] )
            );

            // Duplicate rfoe_ssi_out to both pairs of TX channels, and zero-pad to 2-parallel (this all-zeros dimension will
            // be ignored in txsdr)
            always_comb begin
                for (int i=0; i<4; i++) begin
                    tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE].data[i][0] = rfoe_ssi_out.data[i%2][0];
                    tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE].data[i][1] = '{default: '0};
                end
                tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE].valid      = rfoe_ssi_out.valid;
                tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE].center_ref = rfoe_ssi_out.center_ref;
            end

            ssi_nul_source     no_rfoe_ssi_in   ( .ssi (rfoe_ssi_in.Source));
        end else if (`DEFINED(ENABLE_MPLS_NIC)) begin: gen_mpls_nic_ctrl

            AXIS_int #(
                .DATA_BYTES ( eth_sink[ETH_IDX_NIC_SINK].DATA_BYTES   )
            ) eth_nic_sink_buffered (
                .clk        ( eth_sink[ETH_IDX_NIC_SINK].clk          ),
                .sresetn    ( eth_sink[ETH_IDX_NIC_SINK].sresetn      )
            );

            // This FIFO prevents the mpls_router from becoming deadlocked by mpls_simpletoga
            axis_fifo_wrapper #(
                .DEPTH              ( 16*MAX_PKTSIZE ), // determined experimentally
                .KEEP_ENABLE        ( 0              ),
                .LAST_ENABLE        ( 1              ),
                .ID_ENABLE          ( 0              ),
                .DEST_ENABLE        ( 0              ),
                .USER_ENABLE        ( 0              ),
                .FRAME_FIFO         ( 1              ),
                .FILL_LEVEL_ENABLE  ( 0              ),
                .DROP_WHEN_FULL     ( 1              )
            ) eth_nic_sink_fifo (
                .axis_in            ( eth_sink[ETH_IDX_NIC_SINK]  ),
                .axis_out           ( eth_nic_sink_buffered       ),
                .reset_read_ptr     ( 0                           ),
                .status_overflow    (),
                .status_bad_frame   (),
                .status_good_frame  (),
                .fill_level         ()
            );

            mpls_simpletoga mpls_simpletoga_inst (
                .axis_in   ( eth_nic_sink_buffered               ),
                .axis_out  ( eth_src[ETH_IDX_NIC_SRC]            ),
                .bb_ctrl   ( ssd_byte_ctrls [SSD_IDX_SIMPLETOGA] ),
                .bb_write  ( ssd_byte_writes[SSD_IDX_SIMPLETOGA] ),
                .bb_read   ( ssd_byte_reads [SSD_IDX_SIMPLETOGA] ),
                .mmi       ( mmi_dev[MMI_MPLS_SIMPLETOGA]        )
            );

            mmi_nul_slave      no_mmi_nic1      ( .mmi(mmi_dev[MMI_NICHDR_CTRL]) );
            mmi_nul_slave      no_mmi_nic0      ( .mmi(mmi_dev[MMI_NIC_SDR]) );
            mmi_nul_slave      no_mmi_nic2      ( .mmi(mmi_dev[MMI_TDI_RXDBUF]) );
            mmi_nul_slave      no_mmi_nic3      ( .mmi(mmi_dev[MMI_TDI_TXDBUF]) );
            mmi_nul_slave      no_mmi_rfoe      ( .mmi(mmi_dev[MMI_RFOE_CTRL]) );
            mmi_nul_master     no_mmioe_master  ( .mmi      (mmi_masters[MMI_MASTER_MMIOE]) );
            sdr_ctrl_nul_slave no_ctrl_nic_0    ( .ctrl ( nic_ctrl ) );
            bb_nul_client      no_qspi_nic      ( .bbctrl (qspi_bb_ctrls [ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            axis_nul_src       no_nic_axis_4    ( .axis (qspi_bb_writes[ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            axis_nul_sink      no_nic_axis_5    ( .axis (qspi_bb_reads[ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            ssi_nul_source     no_rfoe_ssi_out  ( .ssi (rfoe_ssi_out.Source));
            ssi_nul_source     no_ext_ssi       ( .ssi (tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE]));
            mon_watchdog_action_always_pet disable_modcod_fallback_inst ( .watchdog(acm_modcod_watchdog_action.Petter) );
            assign obc_irq_in[OBC_IRQ_TX_BUFFER_READY:OBC_IRQ_RX_PACKET_READY] = '0;
        end else begin: gen_disable_nic_ctrl
            mmi_nul_slave      no_mmi_nic0      ( .mmi(mmi_dev[MMI_NIC_SDR]) );
            mmi_nul_slave      no_mmi_nic1      ( .mmi(mmi_dev[MMI_NICHDR_CTRL]) );
            mmi_nul_slave      no_mmi_nic2      ( .mmi(mmi_dev[MMI_TDI_RXDBUF]) );
            mmi_nul_slave      no_mmi_nic3      ( .mmi(mmi_dev[MMI_TDI_TXDBUF]) );
            mmi_nul_slave      no_mmi_rfoe      ( .mmi(mmi_dev[MMI_RFOE_CTRL]) );
            mmi_nul_master     no_mmioe_master  ( .mmi      (mmi_masters[MMI_MASTER_MMIOE]) );
            sdr_ctrl_nul_slave no_ctrl_nic_0    ( .ctrl ( nic_ctrl ) );
            axis_nul_sink      no_axis_nic_in   ( .axis (eth_sink[ETH_IDX_NIC_SINK] ) );
            axis_nul_src       no_axis_nic_out  ( .axis (eth_src[ETH_IDX_NIC_SRC]  ) );
            axis_nul_sink      no_nic_axis_1    ( .axis ( ssd_byte_reads [SSD_IDX_SIMPLETOGA] ) );
            axis_nul_src       no_nic_axis_3    ( .axis ( ssd_byte_writes[SSD_IDX_SIMPLETOGA] ) );
            bb_nul_client      no_ssd_nic_b     ( .bbctrl (ssd_byte_ctrls [SSD_IDX_SIMPLETOGA]) );
            bb_nul_client      no_qspi_nic      ( .bbctrl (qspi_bb_ctrls [ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            axis_nul_src       no_nic_axis_4    ( .axis (qspi_bb_writes[ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            axis_nul_sink      no_nic_axis_5    ( .axis (qspi_bb_reads[ZYNQ_QSPI_HSD::BB_QSPI_NIC]));
            ssi_nul_source     no_rfoe_ssi_out  ( .ssi (rfoe_ssi_out.Source));
            ssi_nul_source     no_ext_ssi       ( .ssi (tx_ssi_ext_ins[TXSDR_PKG::EXTERNAL_SSI_SRC_IDX_RFOE]));
            mon_watchdog_action_always_pet disable_modcod_fallback_inst ( .watchdog(acm_modcod_watchdog_action.Petter) );
            assign obc_irq_in[OBC_IRQ_TX_BUFFER_READY:OBC_IRQ_RX_PACKET_READY] = '0;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Ethernet AXIS Connections


    board_hsd_eth #(
        .DIRECT_PS      (`DEFINED(ETHERNET_DIRECT_PS)       ),
        .HUB            (`DEFINED(ETHERNET_HUB)             ),
        .FORWARD        (`DEFINED(ETHERNET_P4_FORWARD)      ),
        .MPLS           (`DEFINED(ETHERNET_MPLS_ROUTER)     ),
        .PL_RGMII_MODEM (`DEFINED(ETHERNET_PL_RGMII_MODEM)  ),
        .DSSS           (`DEFINED(ENABLE_DSSS_RX)           )
    ) board_hsd_eth_inst (
        .eth_src    ( eth_src                  ),
        .eth_sink   ( eth_sink                 ),
        .mmi_p4     ( mmi_dev[MMI_P4_FWD]      ),
        .mmi_router ( mmi_dev[MMI_MPLS_ROUTER] ),
        .clk        ( clksys_drv               ),
        .rst        (~sresetn                  )
        // .mmi_bad_fcs_dn( mmi_dev[MMI_ETH_BAD_FCS_DN] ),
        // .mmi_bad_fcs_up( mmi_dev[MMI_ETH_BAD_FCS_UP] )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: RGMII Ethernet PHY


    // Workaround to send a parameter from Verilog to TCL: conditionally define a variable with
    // KEEP="TRUE", so the TCL can use "llength [get_nets USE_OLD_ENET_RX]" to detect PCH_PRE_V3.
`ifdef PCH_PRE_V3
    (* KEEP = "TRUE" *) logic USE_OLD_ENET_RX;
    // This signal is never used in RTL, so tie it off to avoid an undriven pin warning.
    assign USE_OLD_ENET_RX = 1'b0;
`endif

    generate
        if (`DEFINED(ENABLE_RGMII)) begin: gen_enable_rgmii
            board_hsd_rgmii #(
                // must be large enough to buffer the largest packet size
                .RGMII_ADDR_WIDTH ( $clog2(MAX_PKTSIZE) + 2                                     ),
                .PCH_PRE_V3       ( `DEFINED(PCH_PRE_V3)                                        ),
                .EXTERNAL_RX_FIFO ( `DEFINED(ENABLE_PL_DDR) && `DEFINED(RGMII_PL_DDR_RX_BUFFER) ),
                // Don't drop when using MPLS otherwise Simpletoga will timeout on large files
                .TX_DROP_WHEN_FULL( `DEFINED(ENABLE_MPLS_NIC) ? 0 : 1                           )
            ) rgmii_inst (
                .sdr            ( rgmii_ctrl.Slave                  ),
                .rgmii          ( rgmii.Module                      ),
                .mdio_io        ( pl_eth_mdio_io.Driver             ),
                .axis_sink      ( eth_sink[ETH_IDX_RGMII_SINK]      ),
                .axis_src       ( eth_src[ETH_IDX_RGMII_SRC]        ),
                .mmi            ( mmi_dev[MMI_RGMII]                ),
                .mmi_mdio       ( mmi_dev[MMI_MDIO_CTRL]            ),
                .pll_idelay     ( rgmii_idelay_pll.Provider         ),
                .ext_rx_fifo_clk( ext_rx_fifo_clk                   ),
                .ext_rx_fifo_rst( ext_rx_fifo_rst                   ),
                .ext_rx_fifo_out( rgmii_ext_fifo_to_ddr.Master      ),
                .ext_rx_fifo_in ( rgmii_ext_fifo_from_ddr.Slave     )
            );

        end else begin: gen_no_rgmii
            sdr_ctrl_nul_slave  no_sdr_ctrl ( .ctrl ( rgmii_ctrl.Slave ) );
            mmi_nul_slave       no_mmi      ( .mmi  ( mmi_dev[MMI_RGMII]) );
            mmi_nul_slave       no_mmi_mdio ( .mmi  ( mmi_dev[MMI_MDIO_CTRL] ) );
            axis_nul_sink       no_axis_rgmii_in   ( .axis (eth_sink[ETH_IDX_RGMII_SINK] ) );
            axis_nul_src        no_axis_rgmii_out  ( .axis (eth_src[ETH_IDX_RGMII_SRC]  ) );
            axis_nul_src        no_rgmii_ext_fifo_to_ddr   ( .axis ( rgmii_ext_fifo_to_ddr.Master ) );
            axis_nul_sink       no_rgmii_ext_fifo_from_ddr ( .axis ( rgmii_ext_fifo_from_ddr.Slave) );
            assign rgmii.io_reset_n         = 1'b0;
            assign rgmii.io_tx_clk          = '0;
            assign rgmii.io_tx_ctrl         = '0;
            assign rgmii.io_tx_d            = '0;
            assign pl_eth_mdio_io.MDC      = 1'b0;
            assign pl_eth_mdio_io.MDIO_out = 1'b0;
            assign pl_eth_mdio_io.MDIO_oe  = 1'b0;
            assign ext_rx_fifo_clk         = 1'b0;
            assign ext_rx_fifo_rst         = 1'b1;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Rx & Tx Tie-offs


`ifndef HAVE_MMI_RX
    mmi_nul_slave no_rxdsp_mmi  ( .mmi(mmi_dev[MMI_RXDSP]) );
    mmi_nul_slave no_rxdata_mmi ( .mmi(mmi_dev[MMI_RXDATA]) );
    mmi_nul_slave no_rxdata_bbfilt_mmi ( .mmi(mmi_dev[MMI_RX_BBFILT]) );
    mmi_nul_slave no_rxdvbs2_mmi( .mmi(mmi_dev[MMI_UPI_RXDEMOD]) );
`endif
`ifndef HAVE_MMI_TXDATA
    mmi_nul_slave no_mmi_txdata ( .mmi(mmi_dev[MMI_TXDATA]) );
`endif
`ifndef HAVE_MMI_TXDSP
    mmi_nul_slave no_mmi_txdsp  ( .mmi(mmi_dev[MMI_TXDSP]) );
`endif
`ifndef HAVE_MMI_UPI_TXMOD
    mmi_nul_slave no_mmi_upi_txmod ( .mmi(mmi_dev[MMI_UPI_TXMOD]) );
`endif


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: SEM


    sem_ultrascale_mmi sem_inst (
        .mmi_clk    ( clksys_drv ),
        .icap_clk   ( pl_clk3_200_drv ),
        .mmi_sresetn( sresetn ),
        .mmi        ( mmi_dev[MMI_SEMCTRL] )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Scratch registers


    mmi_regfile #(
        .ADDRWIDTH              ( 4 ),
        .FIRST_REG_REPORTS_SIZE ( 1 )
    ) scratch_regs_inst (
        .clk        ( clksys_drv ),
        .sresetn    ( sresetn ),
        .mmi        ( mmi_dev[MMI_SCRATCH] )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: DDR4


    `ifdef ENABLE_PL_DDR // Must be an ifdef to remove the pin references when not used
        generate
            if (1) begin: gen_enable_ddr // Required for enable detection in constraints
                ddr4_ctrl ddr4_ctrl_inst (
                    .clkddr4_drv     (clk_ddr                  ),
                    .clkddr4_sync_rst(sreset_ddr               ),
                    .ddr4_act_n      (PL_DDR_ACT_N             ),
                    .ddr4_adr        (PL_DDR_A                 ),
                    .ddr4_ba         (PL_DDR_BA                ),
                    .ddr4_bg         (PL_DDR_BG0               ),
                    .ddr4_cke        (PL_DDR_CKE0              ),
                    .ddr4_odt        (PL_DDR_ODT               ),
                    .ddr4_cs_n       (PL_DDR_CS_N0             ),
                    .ddr4_ck_t       (PL_DDR_CK0_P             ),
                    .ddr4_ck_c       (PL_DDR_CK0_N             ),
                    .ddr4_reset_n    (PL_1V8_DDR_RST_N         ),
                    .ddr4_dm_dbi_n   (PL_DDR_DM                ),
                    .ddr4_dq         (PL_DDR_DQ                ),
                    .ddr4_dqs_c      (PL_DDR_DQS_N             ),
                    .ddr4_dqs_t      (PL_DDR_DQS_P             ),
                    .sys_clk_p       (CLK_DDR_PL_P             ),
                    .sys_clk_n       (CLK_DDR_PL_N             ),
                    .mmi_ram         (mmi_ddr_arbiter_out.Slave),
                    .ddr_ctrl        (ddr_ctrl.Slave           )
                );

                mmi_arbiter #(
                    .N       (DDR_NUM_INDICES),
                    .ARB_TYPE("round-robin"  ),
                    .HIGHEST (1'b0           )
                ) ddr4_mmi_arbiter_inst (
                    .clk                ( clk_ddr                    ),
                    .sresetn            (~sreset_ddr                 ),
                    .mmi_in             ( mmi_ddr_arbiter_in         ),
                    .read_arb_lock      ( '0                         ),
                    .write_arb_lock     ( '0                         ),
                    .mmi_out            ( mmi_ddr_arbiter_out.Master ),
                    .read_active_mask   (                            ),
                    .write_active_mask  (                            )
                );

                board_hsd_ddr_apps #(
                    .EN_DDR                                     ( `DEFINED(ENABLE_PL_DDR) ),
                    .EN_RGMII_EXT_FIFO                          ( `DEFINED(RGMII_PL_DDR_RX_BUFFER) ),
                    .EN_BLOCKDEV                                ( 1'b1 ),
                    .RGMII_EXT_FIFO_READ_BUFFER_DEPTH_EXPONENT  ( $clog2(`SIMPLETOGA_RX_PKTSIZE) + 1 ),
                    .RGMII_EXT_FIFO_WRITE_BUFFER_DEPTH_EXPONENT ( $clog2(`SIMPLETOGA_RX_PKTSIZE) + 1 )
                ) board_hsd_ddr_apps_inst (
                    .ddr_ctrl               ( ddr_ctrl.Monitor ),
                    .mmi_top                ( mmi_dev[MMI_DDR_CTRL] ),
                    .clk_arbiter            ( clk_ddr ),
                    .sresetn_arbiter        ( ~sreset_ddr ),
                    .mmi_arbiter_in         ( mmi_ddr_arbiter_in ),
                    .rgmii_ext_fifo_axis_in ( rgmii_ext_fifo_to_ddr.Slave ),
                    .rgmii_ext_fifo_axis_out( rgmii_ext_fifo_from_ddr.Master ),
                    .mmi_bb_traffic_gen     ( mmi_dev[MMI_DDR_BB_TRAFFIC] ),
                    .mmi_bb_perf            ( mmi_dev[MMI_DDR_BB_PERF] ),
                    .bb_ctrls               ( ddr_bb_ctrls ),
                    .bb_writes              ( ddr_bb_writes ),
                    .bb_reads               ( ddr_bb_reads ),
                    .us_pulse               ( us_pulse )
                );
            end
        endgenerate
    `else
        mmi_nul_slave no_ddr4_mmi_slave    (.mmi(mmi_dev[MMI_DDR_CTRL]));
        sdr_ctrl_nul_slave no_ddr_ctrl     (.ctrl(ddr_ctrl.Slave)            );
        axis_nul_sink no_axis_rgmii_ext_fifo_to_ddr   ( .axis(rgmii_ext_fifo_to_ddr.Slave) );
        axis_nul_src  no_axis_rgmii_ext_fifo_from_ddr ( .axis(rgmii_ext_fifo_from_ddr.Master) );
        for (genvar i = 0; i < DDR_BB_NUM_INDICES; i++) begin: ddr_bb_ctrls_tie_off
            bb_nul_provider no_ddr_bb_ctrls_i   ( .bbctrl(ddr_bb_ctrls[i]) );
            axis_nul_sink   no_ddr_bb_writes_i  ( .axis  (ddr_bb_writes[i])   );
            axis_nul_src    no_ddr_bb_reads_i   ( .axis  (ddr_bb_reads[i])   );
        end
    `endif
    assign ddr_bb_backend_ready = ddr_ctrl.initdone;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Inter-Device Copy


    generate
        if (`DEFINED(ENABLE_SSD_CTRL) || `DEFINED(ENABLE_PL_DDR) || `DEFINED(ENABLE_QSPI_CTRL)) begin: gen_inter_dev_copy
            logic idevcpy_sresetn;

            // Virtual interfaces can't be synthesized, so we actually need to create an array
            // of interfaces here and hook it up.
            logic idevcpy_backend_readys                    [NUM_BB_COPY_DEVS-1:0];
            logic idevcpy_sresetns                          [NUM_BB_COPY_DEVS-1:0];
            BlockByteCtrl_int   idevcpy_bctrls              [NUM_BB_COPY_DEVS-1:0] (
                .backend_ready(idevcpy_backend_readys)
            );
            AXIS_int #(.DATA_BYTES(1)) idevcpy_writes [NUM_BB_COPY_DEVS-1:0] (
                .clk     ( clksys_drv ),
                .sresetn ( idevcpy_sresetns )
            );
            AXIS_int #(.DATA_BYTES(1)) idevcpy_reads  [NUM_BB_COPY_DEVS-1:0] (
                .clk     ( clksys_drv ),
                .sresetn ( idevcpy_sresetns )
            );
            BlockByteCopier_int #(
                .IDX_WIDTH  ( $clog2(NUM_BB_COPY_DEVS) )
            ) idevcpy_ctrl ();

            always_ff @(posedge clksys_drv) begin
                if (~sresetn) begin
                    idevcpy_sresetn <= 1'b0;
                end else begin
                    idevcpy_sresetn <= (ssd_ctrl.sresetn  || !`DEFINED(ENABLE_SSD_CTRL))
                                     & (ddr_ctrl.sresetn  || !`DEFINED(ENABLE_PL_DDR))
                                     & (qspi_ctrl.sresetn || !`DEFINED(ENABLE_QSPI_CTRL));
                end
            end

            assign idevcpy_backend_readys[BB_COPY_SSD0]           = ssd_backend_ready;
            assign idevcpy_backend_readys[BB_COPY_SSD1]           = 1'b0; // needs multi-ssd support
            assign idevcpy_backend_readys[BB_COPY_SSD2]           = 1'b0; // needs multi-ssd support
            assign idevcpy_backend_readys[BB_COPY_SSD3]           = 1'b0; // needs multi-ssd support
            assign idevcpy_backend_readys[BB_COPY_DDR]            = ddr_bb_backend_ready;
            assign idevcpy_backend_readys[BB_COPY_QSPI]           = 1'b1; // PS comes up before FPGA

            assign idevcpy_sresetns[BB_COPY_SSD0] = ssd_ctrl.sresetn;
            assign idevcpy_sresetns[BB_COPY_SSD1] = 1'b0;
            assign idevcpy_sresetns[BB_COPY_SSD2] = 1'b0;
            assign idevcpy_sresetns[BB_COPY_SSD3] = 1'b0;
            assign idevcpy_sresetns[BB_COPY_DDR]  = ddr_ctrl.sresetn;
            assign idevcpy_sresetns[BB_COPY_QSPI] = qspi_ctrl.sresetn;

            // Connect the control interfaces
            bb_connect idevcpy_connect_bctrl_ssd0 (
                .bb_in  ( ssd_byte_ctrls[SSD_IDX_BB_COPY] ),
                .bb_out ( idevcpy_bctrls[BB_COPY_SSD0] )
            );
            // The other SSDs will come with multi-SSD support:
            bb_nul_provider notyet_idevcpy_bctrl_ssd1 (.bbctrl(idevcpy_bctrls[BB_COPY_SSD1]) );
            bb_nul_provider notyet_idevcpy_bctrl_ssd2 (.bbctrl(idevcpy_bctrls[BB_COPY_SSD2]) );
            bb_nul_provider notyet_idevcpy_bctrl_ssd3 (.bbctrl(idevcpy_bctrls[BB_COPY_SSD3]) );
            bb_connect idevcpy_connect_bctrl_ddr (
                .bb_in  ( ddr_bb_ctrls[DDR_BB_IDX_COPY]  ),
                .bb_out ( idevcpy_bctrls[BB_COPY_DDR]  )
            );
            bb_connect idevcpy_connect_bctrl_qspi (
                .bb_in  ( qspi_bb_ctrls[ZYNQ_QSPI_HSD::BB_QSPI_COPY] ),
                .bb_out ( idevcpy_bctrls[BB_COPY_QSPI]             )
            );

            // Connect the write streams
            axis_connect idevcpy_connect_write_ssd0 (
                .axis_in    ( idevcpy_writes[BB_COPY_SSD0]        ),
                .axis_out   ( ssd_byte_writes[SSD_IDX_BB_COPY]   )
            );
            axis_nul_sink notyet_idevcpy_write_ssd1 ( .axis(idevcpy_writes[BB_COPY_SSD1]) );
            axis_nul_sink notyet_idevcpy_write_ssd2 ( .axis(idevcpy_writes[BB_COPY_SSD2]) );
            axis_nul_sink notyet_idevcpy_write_ssd3 ( .axis(idevcpy_writes[BB_COPY_SSD3]) );
            axis_connect idevcpy_connect_write_ddr (
                .axis_in    ( idevcpy_writes[BB_COPY_DDR]    ),
                .axis_out   ( ddr_bb_writes[DDR_BB_IDX_COPY])
            );
            axis_connect idevcpy_connect_write_qspi (
                .axis_in    ( idevcpy_writes[BB_COPY_QSPI]                ),
                .axis_out   ( qspi_bb_writes[ZYNQ_QSPI_HSD::BB_QSPI_COPY])
            );

            // Connect the read streams
            axis_connect idevcpy_connect_read_ssd0 (
                .axis_in    ( ssd_byte_reads[SSD_IDX_BB_COPY]     ),
                .axis_out   ( idevcpy_reads[BB_COPY_SSD0]        )
            );
            axis_nul_src    notyet_idevcpy_read_ssd1    ( .axis(idevcpy_reads[BB_COPY_SSD1]) );
            axis_nul_src    notyet_idevcpy_read_ssd2    ( .axis(idevcpy_reads[BB_COPY_SSD2]) );
            axis_nul_src    notyet_idevcpy_read_ssd3    ( .axis(idevcpy_reads[BB_COPY_SSD3]) );
            axis_connect idevcpy_connect_read_ddr (
                .axis_in    ( ddr_bb_reads[DDR_BB_IDX_COPY] ),
                .axis_out   ( idevcpy_reads[BB_COPY_DDR]   )
            );
            axis_connect idevcpy_connect_read_qspi (
                .axis_in    ( qspi_bb_reads[ZYNQ_QSPI_HSD::BB_QSPI_COPY] ),
                .axis_out   ( idevcpy_reads[BB_COPY_QSPI]               )
            );

            bb_copier #(
                .N                      ( NUM_BB_COPY_DEVS ),
                .LOG2_READ_FIFO_DEPTH   ( 12 )  // FIFO size on copy source, to absorb some of the SSD command latency
            ) inter_dev_copy_inst (
                .clk            ( clksys_drv            ),
                .sresetn        ( idevcpy_sresetn       ),
                .copy_ctrl      ( idevcpy_ctrl.Provider ),
                .bctrls         ( idevcpy_bctrls        ),
                .byte_writes    ( idevcpy_writes        ),
                .byte_reads     ( idevcpy_reads         )
            );

            bb_copier_mmi inter_dev_copy_mmi_inst (
                .clk            ( clksys_drv                    ),
                .sresetn        ( idevcpy_sresetn               ),
                .copy_ctrl      ( idevcpy_ctrl.Client           ),
                .mmi            ( mmi_dev[MMI_IDEV_COPY]  )
            );
        end else begin: no_inter_dev_copy
            mmi_nul_slave no_idevcpy_mmi            ( .mmi(mmi_dev[MMI_IDEV_COPY])                        );

            bb_nul_client no_idevcpy_bctrl_ssd0     ( .bbctrl(ssd_byte_ctrls[SSD_IDX_BB_COPY])           );
            // TODO: ssd1-3
            bb_nul_client no_idevcpy_bctrl_ddr      ( .bbctrl(ddr_bb_ctrls[DDR_BB_IDX_COPY])             );
            bb_nul_client no_idevcpy_bctrl_qspi     ( .bbctrl(qspi_bb_ctrls[ZYNQ_QSPI_HSD::BB_QSPI_COPY]));

            axis_nul_src  no_idevcpy_writes_ssd0    ( .axis(ssd_byte_writes[SSD_IDX_BB_COPY])            );
            // TODO: ssd1-3
            axis_nul_src  no_idevcpy_writes_ddr     ( .axis(ddr_bb_writes[DDR_BB_IDX_COPY])              );
            axis_nul_src  no_idevcpy_writes_qspi    ( .axis(qspi_bb_writes[ZYNQ_QSPI_HSD::BB_QSPI_COPY]) );

            axis_nul_sink no_idevcpy_reads_ssd0     ( .axis(ssd_byte_reads[SSD_IDX_BB_COPY])              );
            // TODO: ssd1-3
            axis_nul_sink no_idevcpy_reads_ddr      ( .axis(ddr_bb_reads[DDR_BB_IDX_COPY])                );
            axis_nul_sink no_idevcpy_reads_qspi     ( .axis(qspi_bb_reads[ZYNQ_QSPI_HSD::BB_QSPI_COPY])   );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: I2C clock divider controller


    mmi_woregfile #(
        .NREGS      ( NUM_I2C_CLK_DIV_IDX   ),
        .DWIDTH     ( 16                    )
    ) i2c_clk_div_ctrl (
        .clk        ( clksys_pl                         ),
        .rst        (~sresetn_pl                        ),
        .mmi        ( mmi_dev[MMI_I2C_CLK_DIV]    ),
        .output_val ( i2c_clk_divide_pre_trim           ),
        .output_stb ( i2c_clk_divide_stb                ),
        .gpout      (                                   ),
        .gpout_stb  (                                   )
    );

    // ensure that the i2c clock divider value is always valid: must be
    // divisible by 4 and >= 8
    assign i2c_clk_divide = (i2c_clk_divide_pre_trim[15:2] == '0) ? 16'h8 :
                                {i2c_clk_divide_pre_trim[15:2], 2'b0};


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Ethernet profilers


    axis_profile_mmi_wrapper eth_nic_src_profiler       (   .axis_monitor   ( eth_src[ETH_IDX_NIC_SRC]             ),
                                                            .mmi            ( mmi_dev[MMI_ETH_NIC_SRC_PROFILER]    ));
    axis_profile_mmi_wrapper eth_nic_sink_profiler      (   .axis_monitor   ( eth_sink[ETH_IDX_NIC_SINK]           ),
                                                            .mmi            ( mmi_dev[MMI_ETH_NIC_SINK_PROFILER]   ));

    axis_profile_mmi_wrapper eth_rgmii_src_profiler     (   .axis_monitor   ( eth_src[ETH_IDX_RGMII_SRC]           ),
                                                            .mmi            ( mmi_dev[MMI_ETH_RGMII_SRC_PROFILER]  ));
    axis_profile_mmi_wrapper eth_rgmii_sink_profiler    (   .axis_monitor   ( eth_sink[ETH_IDX_RGMII_SINK]         ),
                                                            .mmi            ( mmi_dev[MMI_ETH_RGMII_SINK_PROFILER] ));

    axis_profile_mmi_wrapper eth_rxsdr_src_profiler     (   .axis_monitor   ( eth_src[ETH_IDX_RXSDR_SRC]           ),
                                                            .mmi            ( mmi_dev[MMI_ETH_RXSDR_SRC_PROFILER]  ));
    axis_profile_mmi_wrapper eth_txsdr_sink_profiler    (   .axis_monitor   ( eth_sink[ETH_IDX_TXSDR_SINK]         ),
                                                            .mmi            ( mmi_dev[MMI_ETH_TXSDR_SINK_PROFILER] ));


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: I/O


    board_hsd_io #(
        .ENABLE_DDR           ( `DEFINED(ENABLE_PL_DDR)        ),
        .ENABLE_DAC           ( `DEFINED(ENABLE_TX_SDR)        ),
        .ENABLE_BACKPLANE     ( `DEFINED(ENABLE_BACKPLANE)     ),
        .ENABLE_HDR           ( `DEFINED(ENABLE_HDR)           ),
        .ENABLE_KAS           ( `DEFINED(ENABLE_KAS)           ),
        .ENABLE_SSD_CTRL      ( `DEFINED(ENABLE_SSD_CTRL)      ),
        .N_PL_SATA            ( `N_PL_SATA                     ),
        .PCH_PRE_V3           ( `DEFINED(PCH_PRE_V3)           )
    ) board_hsd_io_inst (
        .PIN33M_PL_CLK   ( PIN33M_PL_CLK   ),
        .pl_clk0_sys_drv ( pl_clk0_sys_drv ),
        .pl_clk1_300_drv ( pl_clk1_300_drv ),
        .pl_clk2_125_drv ( pl_clk2_125_drv ),
        .pl_clk3_200_drv ( pl_clk3_200_drv ),
        .EN_1V2PSDDR     ( EN_1V2PSDDR     ),
        .EN_ADC1         ( EN_ADC1         ),
        .EN_ADC2         ( EN_ADC2         ),
        .EN_CLK_CHIP     ( EN_CLK_CHIP     ),
        .EN_DAC          ( EN_DAC          ),
        .EN_MGTAVCC      ( EN_MGTAVCC      ),
        .EN_PLDDR        ( EN_PLDDR        ),
        .EN_PLETH        ( EN_PLETH        ),
        .EN_PS1V8        ( EN_PS1V8        ),
        .EN_PSETH        ( EN_PSETH        ),
        .EN_PSFP         ( EN_PSFP         ),
        .EN_PSFP2        ( EN_PSFP2        ),
        .EN_PSLP         ( EN_PSLP         ),
        .SHUT_DOWN_N     ( SHUT_DOWN_N     ),
        .DAC_VCC0V9_PG   ( DAC_VCC0V9_PG   ),
        .DAC_VCC3V3_PG   ( DAC_VCC3V3_PG   ),
        .MGTAVCC_0V9_PG  ( MGTAVCC_0V9_PG  ),
        .VCC1V12_PG      ( VCC1V12_PG      ),
        .VCC1V8LDO_PG    ( VCC1V8LDO_PG    ),
        .VCC1V8_PG       ( VCC1V8_PG       ),
        .VCC1V95_PG      ( VCC1V95_PG      ),
        .VCC2V5_PG       ( VCC2V5_PG       ),
        .VCC3V5_PG       ( VCC3V5_PG       ),
        .VCC5V_PG        ( VCC5V_PG        ),
        .VCCA1V2_PG      ( VCCA1V2_PG      ),
        .VCCDDR_PG       ( VCCDDR_PG       ),
        .POWSENSE_SCL    ( POWSENSE_SCL    ),
        .POWSENSE_SCL2   ( POWSENSE_SCL2   ),
        .POWSENSE_SDA    ( POWSENSE_SDA    ),
        .POWSENSE_SDA2   ( POWSENSE_SDA2   ),
        .ALERT_CORE      ( ALERT_CORE      ),
        .ALERT_DDR       ( ALERT_DDR       ),
        .ALERT_IO        ( ALERT_IO        ),
        .ALERT_LDO       ( ALERT_LDO       ),
        .SCLK_3V3        ( SCLK_3V3        ),
        .MOSI_3V3        ( MOSI_3V3        ),
        .CS_CLK          ( CS_CLK          ),
        .CS_TMP1         ( CS_TMP1         ),
        .CS_TMP2         ( CS_TMP2         ),
        .SCLK_1V8        ( SCLK_1V8        ),
        .MOSI_1V8        ( MOSI_1V8        ),
        .MISO_1V8        ( MISO_1V8        ),
        .CS_DAC          ( CS_DAC          ),
        .CS_1_ADC        ( CS_1_ADC        ),
        .CS_1_VGA        ( CS_1_VGA        ),
        .CS_2_ADC        ( CS_2_ADC        ),
        .CS_2_VGA        ( CS_2_VGA        ),
        .FE1_IO          ( FE1_IO          ),
        .FE1_IO23_N      ( FE1_IO23_N      ),
        .FE1_IO23_P      ( FE1_IO23_P      ),
        .FE1_IO24_N      ( FE1_IO24_N      ),
        .FE1_IO24_P      ( FE1_IO24_P      ),
        .FE1_PRST        ( FE1_PRST        ),
        .VCC1_SEL        ( VCC1_SEL        ),
        .FE2_IO          ( FE2_IO          ),
        .FE2_IO23_N      ( FE2_IO23_N      ),
        .FE2_IO23_P      ( FE2_IO23_P      ),
        .FE2_IO24_N      ( FE2_IO24_N      ),
        .FE2_IO24_P      ( FE2_IO24_P      ),
        .FE2_PRST        ( FE2_PRST        ),
        .VCC2_SEL        ( VCC2_SEL        ),
        .CLK_RESET       ( CLK_RESET       ),
        .CLK_SYNC        ( CLK_SYNC        ),
        .PCIE_RST_N      ( PCIE_RST_N      ),
        .PCIE_WAKE       ( PCIE_WAKE       ),
        .LVDS_PCIE_N     ( LVDS_PCIE_N     ),
        .LVDS_PCIE_P     ( LVDS_PCIE_P     ),
        .ENET_GTX_CLK    ( ENET_GTX_CLK    ),
        .ENET_RESET_N    ( ENET_RESET_N    ),
        .ENET_RX_CLK     ( ENET_RX_CLK     ),
        .ENET_RX_CTRL    ( ENET_RX_CTRL    ),
        .ENET_RX_D       ( ENET_RX_D       ),
        .ENET_TX_CTRL    ( ENET_TX_CTRL    ),
        .ENET_TX_D       ( ENET_TX_D       ),
        .ENET_MDC        ( ENET_MDC        ),
        .ENET_MDIO       ( ENET_MDIO       ),
        .ADC1_DATA_N     ( ADC1_DATA_N     ),
        .ADC1_DATA_P     ( ADC1_DATA_P     ),
        .ADC1_DVGA_PD    ( ADC1_DVGA_PD    ),
        .ADC1_OCLK_N     ( ADC1_OCLK_N     ),
        .ADC1_OCLK_P     ( ADC1_OCLK_P     ),
        .ADC1_OR_N       ( ADC1_OR_N       ),
        .ADC1_OR_P       ( ADC1_OR_P       ),
        .ADC1_RESETN     ( ADC1_RESETN     ),
        .ADC2_DATA_N     ( ADC2_DATA_N     ),
        .ADC2_DATA_P     ( ADC2_DATA_P     ),
        .ADC2_DVGA_PD    ( ADC2_DVGA_PD    ),
        .ADC2_OCLK_N     ( ADC2_OCLK_N     ),
        .ADC2_OCLK_P     ( ADC2_OCLK_P     ),
        .ADC2_OR_N       ( ADC2_OR_N       ),
        .ADC2_OR_P       ( ADC2_OR_P       ),
        .ADC2_RESETN     ( ADC2_RESETN     ),
        .DAC_ALARM       ( DAC_ALARM       ),
        .DAC_RESETB      ( DAC_RESETB      ),
        .DAC_RX_N        ( DAC_RX_N        ),
        .DAC_RX_P        ( DAC_RX_P        ),
        .DAC_SOC_CLK_N   ( DAC_SOC_CLK_N   ),
        .DAC_SOC_CLK_P   ( DAC_SOC_CLK_P   ),
        .DAC_SOC_SYSREF_N( DAC_SOC_SYSREF_N),
        .DAC_SOC_SYSREF_P( DAC_SOC_SYSREF_P),
        .DAC_SYNC_N      ( DAC_SYNC_N      ),
        .DAC_SYNC_N_AB   ( DAC_SYNC_N_AB   ),
        .DAC_SYNC_N_CD   ( DAC_SYNC_N_CD   ),
        .DAC_SYNC_P      ( DAC_SYNC_P      ),
        .DAC_TXENABLE    ( DAC_TXENABLE    ),
        .OBC_GPIO        ( OBC_GPIO        ),
        .MARK            ( MARK            ),
        .VP              ( VP              ),
        .VN              ( VN              ),
        .DCLKOUT2_N      ( DCLKOUT2_N      ),
        .DCLKOUT2_P      ( DCLKOUT2_P      ),
`ifdef ENABLE_SSD_CTRL
        .SSD_LANES_RX_N  ( GTH230_PCIE_RX_N `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_RX_P  ( GTH230_PCIE_RX_P `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_TX_N  ( PCIE_TX_N `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_TX_P  ( PCIE_TX_P `PL_SATA_ARRAY_DEF ),
`else
        .SSD_LANES_RX_N  ( fake_ssd_RX_N `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_RX_P  ( fake_ssd_RX_N `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_TX_N  ( fake_ssd_TX_N `PL_SATA_ARRAY_DEF ),
        .SSD_LANES_TX_P  ( fake_ssd_TX_P `PL_SATA_ARRAY_DEF ),
`endif

        .clksys_pl       ( clksys_pl          ),
        .sresetn_pl      ( sresetn_pl         ),
        .system          ( system.IO          ),
        .sysmon          ( sysmon.IO          ),
        .obc_spi         ( obc_spi.Driver     ),
        .obc_irq_io      ( obc_irq_io.IO      ),
        .sys_spi         ( sys_spi.IO         ),
        .sys_i2c         ( sys_i2c            ),
        .sdr_spi         ( sdr_spi.IO         ),
        .hdr_spi         ( hdr_spi.IO         ),
        .hdr_i2c         ( hdr_i2c.IO         ),
        .kas_spi_3v3     ( kas_spi_3v3.IO     ),
        .kas_spi_1v8     ( kas_spi_1v8.IO     ),
        .kas_i2c         ( kas_i2c.IO         ),
        .rgmii           ( rgmii.IO           ),
        .bp_i2c          ( bp_i2c.IO          ),
        .pwr_ctrl        ( pwr_ctrl           ),
        .lmk             ( lmk.IO             ),
        .sys_0_cpm       ( sys_0_cpm.IO       ),
        .sys_1_cpm       ( sys_1_cpm.IO       ),
        .hdr_cpm         ( hdr_cpm.IO         ),
        .kas_cpm         ( kas_cpm.IO         ),
        .bp_cpm          ( bp_cpm.IO          ),
        .rx0_adc         ( rx0_adc.IO         ),
        .rx1_adc         ( rx1_adc.IO         ),
        .rx0_amp         ( rx0_amp.IO         ),
        .rx1_amp         ( rx1_amp.IO         ),
        .tx_dac          ( tx_dac.IO          ),
        .hdr             ( hdr.IO             ),
        .kas             ( kas.IO             ),
        .kas_ioexp       ( kas_ioexp.IO       ),
        .bp_ioexp        ( bp_ioexp.IO        ),
        .sec_ioexp       ( sec_ioexp.IO       ),
        .bp_hdr_present_n       ( bp_hdr_present_n       ),
        .pl_ssd_present_n       ( pl_ssd_present_n       ),
        .ps_ssd_present_n       ( ps_ssd_present_n       ),
        .en_pl_ssd              ( en_pl_ssd              ),
        .en_ps_ssd              ( en_ps_ssd              ),
        .bp_en_tempsns          ( bp_en_tempsns          ),
        .bp_fast_alert_n        ( bp_fast_alert_n        ),
        .sata_io                ( sata_io                ),
        .eth_mdio_io            ( pl_eth_mdio_io.IO      ),

        .kas_debugi2c_en        ( kas_debugi2c_en      ),
        .kas_debugi2c_scl_in    ( kas_debugi2c_scl_in  ),
        .kas_debugi2c_scl_out   ( kas_debugi2c_scl_out ),
        .kas_debugi2c_scl_hiz   ( kas_debugi2c_scl_hiz ),
        .kas_debugi2c_sda_in    ( kas_debugi2c_sda_in  ),
        .kas_debugi2c_sda_out   ( kas_debugi2c_sda_out ),
        .kas_debugi2c_sda_hiz   ( kas_debugi2c_sda_hiz ),

        .kas_debugspi1v8_en        (kas_debugspi1v8_en        ),
        .kas_debugspi1v8_sclk_in   (kas_debugspi1v8_sclk_in   ),
        .kas_debugspi1v8_sclk_out  (kas_debugspi1v8_sclk_out  ),
        .kas_debugspi1v8_sclk_hiz  (kas_debugspi1v8_sclk_hiz  ),
        .kas_debugspi1v8_mosi_in   (kas_debugspi1v8_mosi_in   ),
        .kas_debugspi1v8_mosi_out  (kas_debugspi1v8_mosi_out  ),
        .kas_debugspi1v8_mosi_hiz  (kas_debugspi1v8_mosi_hiz  ),
        .kas_debugspi1v8_ssn_in    (kas_debugspi1v8_ssn_in    ),
        .kas_debugspi1v8_ssn_out   (kas_debugspi1v8_ssn_out   ),
        .kas_debugspi1v8_ssn_hiz   (kas_debugspi1v8_ssn_hiz   ),

        .kas_debugspi3v3_en        (kas_debugspi3v3_en        ),
        .kas_debugspi3v3_dacssn_in (kas_debugspi3v3_dacssn_in ),
        .kas_debugspi3v3_dacssn_out(kas_debugspi3v3_dacssn_out),
        .kas_debugspi3v3_dacssn_hiz(kas_debugspi3v3_dacssn_hiz),

        .kas_debugio19_en        (kas_debugio19_en  ),
        .kas_debugio19_in        (kas_debugio19_in  ),
        .kas_debugio19_out       (kas_debugio19_out ),
        .kas_debugio19_hiz       (kas_debugio19_hiz ),

        .kas_debugio21_en        (kas_debugio21_en  ),
        .kas_debugio21_in        (kas_debugio21_in  ),
        .kas_debugio21_out       (kas_debugio21_out ),
        .kas_debugio21_hiz       (kas_debugio21_hiz )
    );

endmodule

`undef PL_SATA_ARRAY_DEF

`default_nettype wire
