// CONFIDENTIAL
// Copyright (c) 2019 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`default_nettype none

`define PL_SATA_ARRAY_DEF [UTIL_INTS::S_INT_MAX(0, N_PL_SATA-1) : 0]

/**
 * IO Pin mapping for the Ku/KaS Terminal PCH board.
 */
module board_hsd_io # (
    parameter bit     ENABLE_DDR           = 0,
    parameter bit     ENABLE_DAC           = 1,
    parameter bit     ENABLE_BACKPLANE     = 0,
    parameter bit     ENABLE_HDR           = 0,
    parameter bit     ENABLE_KAS           = 0,
    parameter bit     ENABLE_SSD_CTRL      = 0,
    parameter int     N_PL_SATA            = 1,
    parameter bit     PCH_PRE_V3           = 0,
    parameter bit     DEBUG_ILA            = 0
) (
    // External clocks
    input   var logic               PIN33M_PL_CLK,
    input   var logic               pl_clk0_sys_drv,
    input   var logic               pl_clk1_300_drv,
    input   var logic               pl_clk2_125_drv,
    input   var logic               pl_clk3_200_drv,

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
    inout   tri  logic              DAC_VCC0V9_PG,
    inout   tri  logic              DAC_VCC3V3_PG,
    inout   tri  logic              MGTAVCC_0V9_PG,
    inout   tri  logic              VCC1V12_PG,
    inout   tri  logic              VCC1V8LDO_PG,
    inout   tri  logic              VCC1V8_PG,
    inout   tri  logic              VCC1V95_PG,
    inout   tri  logic              VCC2V5_PG,
    inout   tri  logic              VCC3V5_PG,
    inout   tri  logic              VCC5V_PG,
    inout   tri  logic              VCCA1V2_PG,
    inout   tri  logic              VCCDDR_PG,

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

    // PL PCIe stuff?
    input   var  logic              PCIE_RST_N,
    input   var  logic              PCIE_WAKE,
    inout   tri  logic    [20:1]    LVDS_PCIE_N,
    inout   tri  logic    [20:1]    LVDS_PCIE_P,

    // Ethernet
    output  var  logic              ENET_GTX_CLK,
    output  var  logic              ENET_RESET_N,
    input   var  logic              ENET_RX_CLK,
    input   var  logic              ENET_RX_CTRL,
    input   var  logic     [3:0]    ENET_RX_D,
    output  var  logic              ENET_TX_CTRL,
    output  var  logic     [3:0]    ENET_TX_D,
    output  var  logic              ENET_MDC,
    inout   tri  logic              ENET_MDIO,

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
    output  var  logic     [7:0]    DAC_RX_N,
    output  var  logic     [7:0]    DAC_RX_P,
    input   var  logic              DAC_SOC_CLK_N,
    input   var  logic              DAC_SOC_CLK_P,
    input   var  logic              DAC_SOC_SYSREF_N,
    input   var  logic              DAC_SOC_SYSREF_P,
    inout   tri  logic              DAC_SYNC_N,
    inout   tri  logic              DAC_SYNC_N_AB,
    inout   tri  logic              DAC_SYNC_N_CD,
    inout   tri  logic              DAC_SYNC_P,
    inout   tri  logic              DAC_TXENABLE,

    output  var  logic     [1:0]    OBC_GPIO,
    inout   tri  logic    [14:1]    MARK,

    input   var  logic              VP,
    input   var  logic              VN,

    input   var  logic                          DCLKOUT2_N,
    input   var  logic                          DCLKOUT2_P,
    input   var  logic    `PL_SATA_ARRAY_DEF    SSD_LANES_RX_N,
    input   var  logic    `PL_SATA_ARRAY_DEF    SSD_LANES_RX_P,
    output  var  logic    `PL_SATA_ARRAY_DEF    SSD_LANES_TX_N,
    output  var  logic    `PL_SATA_ARRAY_DEF    SSD_LANES_TX_P,

    output  var  logic              clksys_pl,
    output  var  logic              sresetn_pl,

    // System IOs
    HSD_System_int.IO               system,

    // The System Monitor system
    Sysmon_Zynq_int.IO              sysmon,

    // The SPI interface coming from the OBC
    SPIIO_int.Driver                obc_spi,

    // IRQ outputs
    IRQ_IO_int.IO                   obc_irq_io,

    // I2C and SPI Master interfaces
    SPIIO_int.IO                    sys_spi,
    I2CIO_int.IO                    sys_i2c  [1:0],
    SPIIO_int.IO                    sdr_spi,
    SPIIO_int.IO                    hdr_spi,
    I2CIO_int.IO                    hdr_i2c,
    SPIIO_int.IO                    kas_spi_3v3,
    SPIIO_int.IO                    kas_spi_1v8,
    I2CIO_int.IO                    kas_i2c,
    I2CIO_int.IO                    bp_i2c,

    // Power control pins
    PowerCtrl_int.IO                pwr_ctrl,

    // Device IO interfaces
    CLK_LMK04828_int.IO             lmk,
    CPM_INA23x_int.IO               sys_0_cpm,
    CPM_INA23x_int.IO               sys_1_cpm,
    CPM_INA23x_int.IO               hdr_cpm,
    CPM_INA23x_int.IO               kas_cpm,
    CPM_INA23x_int.IO               bp_cpm,
    ADC_KAD5512_int.IO              rx0_adc,
    ADC_KAD5512_int.IO              rx1_adc,
    AMP_LMH6401_int.IO              rx0_amp,
    AMP_LMH6401_int.IO              rx1_amp,
    DAC_DAC3xj8x_int.IO             tx_dac,
    HDR_int.IO                      hdr,
    KaS_int.IO                      kas,
    IOEXP_SerialOut_int.IO          kas_ioexp,
    RGMII_int.IO                    rgmii,

    // IO Expanders
    IOEXP_PCAL6524_int.IO           bp_ioexp,
    IOEXP_PCAL6524_int.IO           sec_ioexp,

    // Pins from the BP IO expander
    output var  logic               bp_hdr_present_n,
    output var  logic   [3:0]       pl_ssd_present_n,
    output var  logic   [1:0]       ps_ssd_present_n,
    input  var  logic   [3:0]       en_pl_ssd,
    input  var  logic   [1:0]       en_ps_ssd,
    input  var  logic               bp_en_tempsns,
    // BP IO expander alert pins:
    // Only bp_fast_alert_n is fast. It comes from the expander's interrupt output,
    // formed by logically combining all the other alert pins.
    // The other individual BP alert values are slow, because they must come over I2C.
    output var  logic               bp_fast_alert_n,

    // SATA IOs
    SataIO_int.IO                   sata_io `PL_SATA_ARRAY_DEF,

    // Ethernet MDIO IOs
    MDIO_IO_int.IO                  eth_mdio_io,     // PL-side ethernet MDIO


    input   var logic               kas_debugi2c_en,
    output  var logic               kas_debugi2c_scl_in,
    input   var logic               kas_debugi2c_scl_out,
    input   var logic               kas_debugi2c_scl_hiz,
    output  var logic               kas_debugi2c_sda_in,
    input   var logic               kas_debugi2c_sda_out,
    input   var logic               kas_debugi2c_sda_hiz,

    input   var logic               kas_debugspi1v8_en,
    output  var logic               kas_debugspi1v8_sclk_in,
    input   var logic               kas_debugspi1v8_sclk_out,
    input   var logic               kas_debugspi1v8_sclk_hiz,
    output  var logic               kas_debugspi1v8_mosi_in,
    input   var logic               kas_debugspi1v8_mosi_out,
    input   var logic               kas_debugspi1v8_mosi_hiz,
    output  var logic               kas_debugspi1v8_ssn_in,
    input   var logic               kas_debugspi1v8_ssn_out,
    input   var logic               kas_debugspi1v8_ssn_hiz,

    input   var logic               kas_debugspi3v3_en,
    output  var logic               kas_debugspi3v3_dacssn_in,
    input   var logic               kas_debugspi3v3_dacssn_out,
    input   var logic               kas_debugspi3v3_dacssn_hiz,

    input   var logic               kas_debugio19_en,
    output  var logic               kas_debugio19_in,
    input   var logic               kas_debugio19_out,
    input   var logic               kas_debugio19_hiz,

    input   var logic               kas_debugio21_en,
    output  var logic               kas_debugio21_in,
    input   var logic               kas_debugio21_out,
    input   var logic               kas_debugio21_hiz
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters

    import BOARD_HSD_SPI_MUX_PKG::*;

    localparam BANK_44_IOSTANDARD   = "LVCMOS33"; // This is FE1 connector
    localparam BANK_47_IOSTANDARD   = "LVCMOS33"; // This is FE2 connector
    localparam BANK_48_IOSTANDARD   = "LVCMOS33";
    localparam BANK_49_IOSTANDARD   = "LVCMOS33";
    localparam BANK_50_IOSTANDARD   = "LVCMOS33";
    localparam BANK_65_IOSTANDARD   = "LVCMOS18";
    localparam BANK_66_IOSTANDARD   = "LVCMOS18";
    localparam BANK_67_IOSTANDARD   = "LVCMOS18";


    // For debugigng purposes, we can swap the order of SSD lanes.
    localparam int SSD_LANE_ORDER[0:3]  = '{0, 1, 2, 3};


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Clocking and Reset Logic


    localparam int RESET_SYNC_STAGES    = 4;

    xclock_resetn # (
        .FF_CASCADE ( RESET_SYNC_STAGES )
    ) sresetn_pcie (
        .tx_clk(1'b0),
        .resetn_in(PCIE_RST_N), // asynchronous
        .rx_clk(clksys_pl),
        .resetn_out(sresetn_pl)
    );

    assign clksys_pl  = pl_clk0_sys_drv;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Power Control Pins


    assign SHUT_DOWN_N = 1'b1;

    // The power-enables are tristateable outputs. Create an OBUFT for each.
`define PWR_CTRL_IO(pin)  OBUFT # (.DRIVE(12), .IOSTANDARD(BANK_48_IOSTANDARD), .SLEW("SLOW") ) \
    pwr_en_``pin``_inst (.T(~pwr_ctrl.outenable[PWR_PKG_HSD::PWR_``pin]), .I( pwr_ctrl.enable[PWR_PKG_HSD::PWR_``pin]), .O(pin));

    `PWR_CTRL_IO(EN_1V2PSDDR);
    `PWR_CTRL_IO(EN_ADC1);
    `PWR_CTRL_IO(EN_ADC2);
    `PWR_CTRL_IO(EN_CLK_CHIP);
    `PWR_CTRL_IO(EN_DAC);
    `PWR_CTRL_IO(EN_MGTAVCC);
    `PWR_CTRL_IO(EN_PLDDR);
    `PWR_CTRL_IO(EN_PLETH);
    `PWR_CTRL_IO(EN_PS1V8);
    `PWR_CTRL_IO(EN_PSETH);
    `PWR_CTRL_IO(EN_PSFP);
    `PWR_CTRL_IO(EN_PSFP2);
    `PWR_CTRL_IO(EN_PSLP);
`undef PWR_CTRL_IO


`define PWR_GOOD_IO(pin) IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_48_IOSTANDARD), .SLEW("SLOW") ) \
    pwr_gd_``pin``_inst (.T(~pwr_ctrl.pg_forcelow[PWR_PKG_HSD::PWR_``pin]), .I('0), .O(pwr_ctrl.good[PWR_PKG_HSD::PWR_``pin]), .IO(pin));

    `PWR_GOOD_IO(DAC_VCC0V9_PG);
    `PWR_GOOD_IO(DAC_VCC3V3_PG);
    `PWR_GOOD_IO(MGTAVCC_0V9_PG);
    `PWR_GOOD_IO(VCC1V12_PG);
    `PWR_GOOD_IO(VCC1V8LDO_PG);
    `PWR_GOOD_IO(VCC1V8_PG);
    `PWR_GOOD_IO(VCC1V95_PG);
    `PWR_GOOD_IO(VCC2V5_PG);
    `PWR_GOOD_IO(VCC3V5_PG);
    `PWR_GOOD_IO(VCC5V_PG);
    `PWR_GOOD_IO(VCCA1V2_PG);
    `PWR_GOOD_IO(VCCDDR_PG);
`undef PWR_GOOD_IO


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Clock and System IO Pins


    logic en_clk;
    assign en_clk = pwr_ctrl.enable[PWR_PKG_HSD::PWR_EN_CLK_CHIP];

    // LMK04828B pins
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) lmk_clk_reset_obuf    (.I(lmk.reset),         .O(),                   .T(~en_clk),            .IO(CLK_RESET));
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) lmk_clk_sync_obuf     (.I(lmk.sync ),         .O(),                   .T(~en_clk),            .IO(CLK_SYNC ));

    // I2C Pins
    OBUFT # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) sysi2c_scl_buf_0      (.I(1'b0),              .O(POWSENSE_SCL),       .T(sys_i2c[0].scl));
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) sysi2c_sda_buf_0      (.I(1'b0),              .O(sys_i2c[0].sda_in),  .T(sys_i2c[0].sda_out), .IO(POWSENSE_SDA));
    OBUFT # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) sysi2c_scl_buf_1      (.I(1'b0),              .O(POWSENSE_SCL2),      .T(sys_i2c[1].scl));
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) sysi2c_sda_buf_1      (.I(1'b0),              .O(sys_i2c[1].sda_in),  .T(sys_i2c[1].sda_out), .IO(POWSENSE_SDA2));

    // SPI_3V3 Pins: these are for clock jitter cleaner and temperature sensors
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) clk_cs_buf            (.I(sys_spi.ss_n[0]),   .O(),                   .T(~en_clk),            .IO(CS_CLK));
    assign CS_TMP1  = sys_spi.ss_n[1];
    assign CS_TMP2  = sys_spi.ss_n[2];
    assign SCLK_3V3 = sys_spi.sclk;
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_49_IOSTANDARD), .SLEW("SLOW") ) clk_mosi_iobuf        (.I(sys_spi.mosi_out),  .O(sys_spi.mosi_in),    .T(sys_spi.hiz),        .IO(MOSI_3V3));
    assign sys_spi.miso = '1;

    generate
        if (PCH_PRE_V3) begin : gen_no_pps
            assign system.pps = 1'b0;
        end else begin : gen_pps_sync
            xclock_sig pps_sync (
                .tx_clk     ( 1'b0              ), // async
                .sig_in     ( LVDS_PCIE_P[18]   ),
                .rx_clk     ( system.clk        ),
                .sig_out    ( system.pps        )
            );
        end
    endgenerate

    assign sysmon.vn = VN;
    assign sysmon.vp = VP;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: SPI 1V8 Pins


    logic en_dac;
    assign en_dac = pwr_ctrl.enable[PWR_PKG_HSD::PWR_EN_DAC];
    // these SPI lines are for the HDR ADC, DAC, and variable gain amplifiers, all located on the PCH
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_66_IOSTANDARD), .SLEW("SLOW") ) dac_cs_buf     (.I(sdr_spi.ss_n[0]), .O(),                .T(~en_dac),    .IO(CS_DAC));
    assign CS_1_ADC     = sdr_spi.ss_n[1];
    assign CS_1_VGA[1]  = sdr_spi.ss_n[2];
    assign CS_1_VGA[2]  = sdr_spi.ss_n[3];
    assign CS_2_ADC     = sdr_spi.ss_n[4];
    assign CS_2_VGA[1]  = sdr_spi.ss_n[5];
    assign CS_2_VGA[2]  = sdr_spi.ss_n[6];
    assign SCLK_1V8     = sdr_spi.sclk;
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_66_IOSTANDARD), .SLEW("SLOW") ) sdr_mosi_iobuf (.I(sdr_spi.mosi_out),.O(sdr_spi.mosi_in), .T(sdr_spi.hiz),.IO(MOSI_1V8));
    assign sdr_spi.miso = MISO_1V8;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: CPM Alarm Pins


    // Many of these pins are wired-OR together.
    assign sys_0_cpm.alert_pins[0]   = ALERT_CORE;  // VCC_BAT_0V72
    assign sys_0_cpm.alert_pins[1]   = ALERT_CORE;  // VCC_BAT_0V85
    assign sys_0_cpm.alert_pins[2]   = ALERT_LDO;   // DAC_VCC0V9
    assign sys_0_cpm.alert_pins[3]   = ALERT_CORE;  // MGTVCCAUX
    assign sys_0_cpm.alert_pins[4]   = ALERT_CORE;  // VPS_MGTRAVTT
    assign sys_0_cpm.alert_pins[5]   = ALERT_IO;    // VCC2V5
    assign sys_0_cpm.alert_pins[6]   = ALERT_LDO;   // VCC3V3
    assign sys_0_cpm.alert_pins[7]   = ALERT_IO;    // PS1V8
    assign sys_0_cpm.alert_pins[8]   = ALERT_LDO;   // DAC_VCC3V3
    assign sys_0_cpm.alert_pins[9]   = ALERT_IO;    // VCC5V
    assign sys_0_cpm.alert_pins[10]  = ALERT_IO;    // PL1V8
    assign sys_0_cpm.alert_pins[11]  = ALERT_CORE;  // VCC_BAT
    assign sys_1_cpm.alert_pins[0]   = ALERT_LDO;   // DAC_VCC1V8
    assign sys_1_cpm.alert_pins[1]   = ALERT_LDO;   // ADC2_VCC1V8
    assign sys_1_cpm.alert_pins[2]   = ALERT_LDO;   // ADC1_VCC1V8
    assign sys_1_cpm.alert_pins[3]   = ALERT_IO;    // PS1V0
    assign sys_1_cpm.alert_pins[4]   = ALERT_IO;    // VCC1V8
    assign sys_1_cpm.alert_pins[5]   = ALERT_IO;    // PL1V0
    assign sys_1_cpm.alert_pins[6]   = ALERT_CORE;  // MGTAVCC_0V9
    assign sys_1_cpm.alert_pins[7]   = ALERT_CORE;  // VCC_PSPLL
    assign sys_1_cpm.alert_pins[8]   = ALERT_DDR;   // VCC_PL_DDR
    assign sys_1_cpm.alert_pins[9]   = ALERT_CORE;  // VMGTAVTT
    assign sys_1_cpm.alert_pins[10]  = ALERT_DDR;   // VCC_PS_DDR


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Ethernet Pins


    // PL-side ethernet MDIO
    OBUF  # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) pl_enet_mdc_obuf   (.I(eth_mdio_io.MDC), .O(ENET_MDC));
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) pl_enet_mdio_iobuf (.I(eth_mdio_io.MDIO_out), .O(eth_mdio_io.MDIO_in), .T(~eth_mdio_io.MDIO_oe), .IO(ENET_MDIO));
    OBUF  # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) pl_enet_rstn_obuf  (.I(rgmii.io_reset_n), .O(ENET_RESET_N));

    assign ENET_GTX_CLK = rgmii.io_tx_clk;
    assign ENET_TX_CTRL = rgmii.io_tx_ctrl;
    assign ENET_TX_D    = rgmii.io_tx_d;

    assign rgmii.io_rx_ctrl = ENET_RX_CTRL;
    assign rgmii.io_rx_d    = ENET_RX_D;

    assign rgmii.io_rx_clk = ENET_RX_CLK;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: OBC SPI Interface


    // Enable the output of mosi when the chip select is low
    IOBUF # (.DRIVE(12), .IOSTANDARD(BANK_67_IOSTANDARD), .SLEW("SLOW") ) obc_miso_iobuf ( .IO (LVDS_PCIE_N[10]), .I(obc_spi.miso), .O( ), .T(obc_spi.ss_n) );
    assign obc_spi.sclk     = LVDS_PCIE_N[9];
    assign obc_spi.mosi_out = LVDS_PCIE_P[9];
    assign obc_spi.ss_n     = LVDS_PCIE_P[10];
    assign obc_spi.hiz      = 1'b0;  // unused by spi_slave


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: HDR ADC Pins


    logic rx1_adc_clk_p, rx0_adc_clk_p;
    OBUF # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) rx0_adc_rstn_buf ( .I(rx0_adc.reset_n),   .O(ADC1_RESETN) );
    OBUF # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) rx1_adc_rstn_buf ( .I(rx1_adc.reset_n),   .O(ADC2_RESETN) );
    OBUF # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) rx0_amp_pd_buf   ( .I(rx0_amp.pd),        .O(ADC1_DVGA_PD));
    OBUF # (.DRIVE(12), .IOSTANDARD(BANK_65_IOSTANDARD), .SLEW("SLOW") ) rx1_amp_pd_buf   ( .I(rx0_amp.pd),        .O(ADC2_DVGA_PD));

    IBUFDS rx0_buf_inst_or (.I(ADC1_OR_P), .IB(ADC1_OR_N), .O(rx0_adc.or_io ));
    IBUFDS rx1_buf_inst_or (.I(ADC2_OR_P), .IB(ADC2_OR_N), .O(rx1_adc.or_io ));

    IBUFDS_DIFF_OUT rx1_clk_inst (.I(ADC2_OCLK_N), .IB(ADC2_OCLK_P), .O(), .OB(rx1_adc_clk_p) );
    IBUFDS_DIFF_OUT rx0_clk_inst (.I(ADC1_OCLK_N), .IB(ADC1_OCLK_P), .O(), .OB(rx0_adc_clk_p) );

    // Clock enables are unneeded on this BUFG, since the only thing that's clocked by
    // rx0_adc.clk_p is rx0_pll, which already has a reset signal (rx0_ctrl.sresetn) which is only
    // released 100 ms after the ADC is powered on. Previously we used BUFGCE's here, but this led
    // to CDC-13 warnings on the asynchronous CE signal, and attempts to synchronize it led to
    // builds which consistently failed timing.
    BUFG bufg_rx1_clk_inst ( .O(rx1_adc.clk_p), .I(rx1_adc_clk_p) );
    BUFG bufg_rx0_clk_inst ( .O(rx0_adc.clk_p), .I(rx0_adc_clk_p) );

    // The negative pins are unused
    assign rx0_adc.clk_n = 1'b0;
    assign rx1_adc.clk_n = 1'b0;

    generate
        for (genvar i = 0; i < 12; i = i + 1) begin : GEN_IBUFDS_DATA_RXADC
            IBUFDS_DIFF_OUT rx0_buf_inst (.I( ADC1_DATA_P[i] ), .IB( ADC1_DATA_N[i] ),   .O(rx0_adc.data_p[i]), .OB(rx0_adc.data_n[i]));
            // N and P are swapped on some indices of ADC2_DATA:
            if (i == 0) begin: gen_rxadc_flipped
                IBUFDS_DIFF_OUT rx1_buf_inst (.I( ADC2_DATA_N[i] ), .IB( ADC2_DATA_P[i] ),   .O(rx1_adc.data_p[i]), .OB(rx1_adc.data_n[i]));
            end else begin: gen_rxadc_not_flipped
                IBUFDS_DIFF_OUT rx1_buf_inst (.I( ADC2_DATA_P[i] ), .IB( ADC2_DATA_N[i] ),   .O(rx1_adc.data_p[i]), .OB(rx1_adc.data_n[i]));
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: HDR DAC Pins


    assign tx_dac.jesd_clkref_p = DAC_SOC_CLK_P;
    assign tx_dac.jesd_clkref_n = DAC_SOC_CLK_N;

    IBUF   # (            .IOSTANDARD(BANK_67_IOSTANDARD)                ) tx_dacalrm_buf ( .O(tx_dac.io_alarm),    .I (DAC_ALARM    ) );
    IOBUF  # (.DRIVE(12), .IOSTANDARD(BANK_67_IOSTANDARD), .SLEW("SLOW") ) tx_dacrst_buf  ( .I(tx_dac.io_resetn  ), .IO(DAC_RESETB   ), .O(), .T(~en_dac) );
    IOBUF  # (.DRIVE(12), .IOSTANDARD(BANK_67_IOSTANDARD), .SLEW("SLOW") ) tx_dactxenb_buf( .I(tx_dac.io_txenable), .IO(DAC_TXENABLE ), .O(), .T(~en_dac) );

    IBUFDS dac_sync_buf (.I(DAC_SYNC_P), .IB(DAC_SYNC_N), .O(tx_dac.jesd_sync_n) );
    logic dac_sysref;
    IBUFDS_GTE4 #(.REFCLK_HROW_CK_SEL ('0)) gtx_sysref  (.I(DAC_SOC_SYSREF_P), .IB(DAC_SOC_SYSREF_N), .O(), .CEB(~tx_dac.io_resetn), .ODIV2(dac_sysref));
    BUFG_GT sysref_buf_gt_inst (
        .O(tx_dac.jesd_sysref),//1-bitoutput:Buffer
        .CE(tx_dac.io_resetn),//1-bitinput:Bufferenable
        .CEMASK(1),//1-bitinput:CEMask
        .CLR(0),//1-bitinput:Asynchronousclear
        .CLRMASK(0),//1-bitinput:CLRMask
        .DIV(0),//3-bitinput:DynamicdivideValue
        .I(dac_sysref)//1-bitinput:Buffer
    );

    /*
     * TODO: BE CAREFUL HERE: The DAC lanes which have their polarity flipped here are also flipped in pch_pins.tcl, so
     * flipping them again here only serves to cancel this out. HOWEVER:
     *  1) When using the JESD204b core, failing to cancel out this flip will cause an error "Place 30-510" during
     *     implementation, with a message (which should be ignored) about the GTH_COMMON block not being in the same quad as
     *     the GTH_CHANNELs.
     *  2) When using the JESD204c core, any reassignment here or in pch_pins.tcl is completely ignored, and the TX lanes of
     *     GTH228-229 are all used in order, with polarities un-flipped.
     *
     * In either case, the polarity flips are not compensated for here, so they need to be inverted by setting bits 7:0 of
     * register 0x3F on the DAC38J84.
     */
    generate
        for (genvar i = 0; i < tx_dac.JESD_L; i = i + 1) begin : GEN_DAC_RX_XCVR
            if (i == 1 || i == 3 || i == 5 || i == 7) begin : gen_txdac_flipped
                // The following pins are flipped N and P
                assign DAC_RX_P[i] = tx_dac.jesd_xcvr_n[i];
                assign DAC_RX_N[i] = tx_dac.jesd_xcvr_p[i];
            end else begin : gen_txdac_not_flipped
                assign DAC_RX_P[i] = tx_dac.jesd_xcvr_p[i];
                assign DAC_RX_N[i] = tx_dac.jesd_xcvr_n[i];
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: SSD enables/presence detect pins


    logic [5:0] bp_en_ssd;
    logic [5:0] bp_ssd_present_n;
    generate
        // HSD has connections for 5 SSD's, with SSD's 2:0 connected to the PL
        // (FPGA) and SSD's 4:3 connected to the PS (ARM CPU)
        for (genvar i = 0; i < 3; i++) begin
            assign bp_en_ssd[i]         = en_pl_ssd[SSD_LANE_ORDER[i]];
        end
        assign bp_en_ssd[4:3]           = en_ps_ssd[1:0];
        assign bp_en_ssd[5]             = 1'b0;
        assign pl_ssd_present_n[2:0]    = bp_ssd_present_n[2:0];
        assign pl_ssd_present_n[3]      = 1'b1;
        assign ps_ssd_present_n[1:0]    = bp_ssd_present_n[4:3];
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: HDR Pins

    logic kas_ioexp_serial_data_loopback;


    generate
        if (ENABLE_HDR) begin: gen_hdr
            assign FE1_IO[4] = hdr_i2c.scl      ? 1'bZ : 1'b0;

            assign FE1_IO[2] = hdr_i2c.sda_out  ? 1'bZ : 1'b0;
            assign hdr_i2c.sda_in = FE1_IO[2];

            assign FE1_IO[3] = hdr_spi.sclk;

            assign FE1_IO[6] = hdr_spi.hiz ? 1'bZ : hdr_spi.mosi_out;
            assign hdr_spi.mosi_in = FE1_IO[6];
            assign hdr_spi.miso = FE1_IO[1];
            // SPI chip-select for the RX synth
            assign FE1_IO[5] = hdr_spi.ss_n[0];
            // SPI chip-select for the TX synth
            assign FE1_IO[9] = hdr_spi.ss_n[1];

            assign FE1_IO[19] = hdr.enable_rx;
            assign FE1_IO23_N = hdr.enable_tx;

            assign hdr.synth_tx_locked    = FE1_IO[11];
            assign hdr.synth_rx_locked    = FE1_IO[12];
            assign hdr.present            = FE1_PRST;

            assign FE1_IO[21] = hdr.enable_digital;
            assign FE1_IO[22] = hdr.enable_pa;
            assign FE1_IO[15] = hdr.tx_select;
            assign FE1_IO[16] = hdr.rx_select;
            // SPI chip-select for the FE ADS1118
            assign FE1_IO[10] = hdr_spi.ss_n[2];
            assign FE1_IO24_N = hdr.enable_synth;

            // Note: signal names on the schematic are a bit misleading.
            // The name shown first is the one at the INA sense input.
            // The second name (in brackets) is the signal as it connects to the FE LSHM connector.
            // The latter seem wrong. Maybe they are copied from a different front-end?
            assign hdr_cpm.alert_pins[0] = FE1_IO[20];  // 3V7_RX (ALERT_TX_3V3)
            assign hdr_cpm.alert_pins[1] = FE1_IO[13];  // 5V4 (RX_ALM)
            assign hdr_cpm.alert_pins[2] = FE1_IO[18];  // 3V7_LO (SYNTH_ALM)
            assign hdr_cpm.alert_pins[3] = FE1_IO[13];  // 3V7_ALLSON_5V4 (RX_ALM)
            assign hdr_cpm.alert_pins[4] = FE1_IO[14];  // 5V4_TX (TX_ALM)
            assign hdr_cpm.alert_pins[5] = FE1_IO[8];   // 3V3_DIG (DIG_ALM)
            assign hdr_cpm.alert_pins[6] = FE1_IO[17];  // 6V4 (PA_ALM)
        end else begin: no_hdr
            assign hdr_spi.mosi_in      = '1;
            assign hdr_spi.miso         = '1;
            assign hdr_i2c.sda_in       = '1;
            assign hdr.synth_tx_locked  = '0;
            assign hdr.synth_rx_locked  = '0;
            assign hdr.present          = '0;
            assign hdr_cpm.alert_pins   = '1;
        end
    endgenerate


    generate

        assign kas_spi_3v3.miso = '1;

        if (ENABLE_KAS) begin: gen_kas

            assign kas.present = FE1_PRST;

            assign FE1_IO[1]  = kas.en_3v8;
            assign FE1_IO[2]  = kas.en_3v3_vstby;
            assign FE1_IO[3]  = kas.en_6v5;
            assign FE1_IO[4]  = kas.lna2_byp;
            assign FE1_IO[5]  = kas_spi_3v3.ss_n[KAS_SPI_3V3_TXLO];
            assign FE1_IO[6]  = kas_ioexp.serial_data;       // Note: net is incorrectly labeled FE_IN_SHIFT_SET on KAS-FE schematic
            assign FE1_IO[7]  = kas_spi_3v3.sclk;
            assign FE1_IO[8]  = kas_spi_3v3.hiz ? 1'bZ : kas_spi_3v3.mosi_out;
            assign kas_spi_3v3.mosi_in = FE1_IO[8];
            assign FE1_IO[9]  = ~kas.en_3v3_vstby
                              ?  1'bZ
                              : (kas.ioexp_oe_n || kas_ioexp.output_enable_n);
            assign FE1_IO[10] = kas_ioexp.latch;             // Note: net is incorrectly labeled FE_IN_SHIFT_DATA on KAS-FE schematic


            //assign FE1_IO[11] = kas_spi_3v3.ss_n[KAS_SPI_3V3_DAC]; // non-debug version
            assign FE1_IO[11] = kas_debugspi3v3_en
                              ? (kas_debugspi3v3_dacssn_hiz ? 1'bZ : kas_debugspi3v3_dacssn_out)
                              : kas_spi_3v3.ss_n[KAS_SPI_3V3_DAC];
            assign kas_debugspi3v3_dacssn_in = FE1_IO[11];


            assign kas.tx_lock = FE1_IO[12];                 // Note: net is incorrectly labelled FE_OUT_RX_LOCK on KAS-FE schematic
            assign FE1_IO[13] = kas_ioexp.serial_clock;
            assign kas_ioexp_serial_data_loopback = FE1_IO[14];
            assign FE1_IO[15] = kas_spi_3v3.ss_n[KAS_SPI_3V3_RXLO];
            assign kas.rx_lock = FE1_IO[16];                 // Note: net is incorrectly labelled FE_OUT_TX_LOCK on KAS-FE schematic

            assign FE1_IO[17] = kas_debugi2c_en
                              ? (kas_debugi2c_scl_hiz ? 1'bZ : kas_debugi2c_scl_out)
                              : (kas_i2c.scl ? 1'bZ : 1'b0);
            assign kas_debugi2c_scl_in = FE1_IO[17];

            assign FE1_IO[18] = kas_debugi2c_en
                              ? (kas_debugi2c_sda_hiz ? 1'bZ : kas_debugi2c_sda_out)
                              : (kas_i2c.sda_out ? 1'bZ : 1'b0);
            assign kas_debugi2c_sda_in = FE1_IO[18];
            assign kas_i2c.sda_in = FE1_IO[18];


            // Ka/S-FE v0: originally 100k pulldown, modified to be PA_EN
            // Ka/S-FE v1: not connected, but can be PA_EN_N if a 0R resistor is installed
            /*
            assign FE1_IO[19] = kas_debugio19_en
                              ? (kas_debugio19_hiz ? 1'bZ : kas_debugio19_out)
                              : 1'bZ;
            assign kas_debugio19_in = FE1_IO[19];
            */
            assign FE1_IO[19]   = (kas.version == 0) ? ~kas.pa_en_n
                                : (kas.version == 1) ?  kas.pa_en_n
                                : 1'bZ;


            assign kas_cpm.alert_pins = {7{FE1_IO[20]}};

            // Ka/S-FE v0: 100k pulldown
            // Ka/S-FE v1: DRVOFF
            /*
            assign FE1_IO[21] = kas_debugio21_en
                              ? (kas_debugio21_hiz ? 1'bZ : kas_debugio21_out)
                              : 1'bZ;
            assign kas_debugio21_in = FE1_IO[21];
            */
            assign FE1_IO[21] = (kas.version == 1) ? kas.drv_off : 1'bZ;


            assign FE1_IO[22] = kas.i2c_en;

            // assign FE1_IO23_N = kas_spi_1v8.sclk; // non-debug version
            assign FE1_IO23_N = kas_debugspi1v8_en
                              ? (kas_debugspi1v8_sclk_hiz ? 1'bZ : kas_debugspi1v8_sclk_out)
                              : kas_spi_1v8.sclk;
            assign kas_debugspi1v8_sclk_in = FE1_IO23_N;

            assign kas_spi_1v8.miso = FE1_IO23_P;


            // assign FE1_IO24_N = kas_spi_1v8.ss_n[KAS_SPI_1V8_MOD];  // non-debug version
            assign FE1_IO24_N = kas_debugspi1v8_en
                              ? (kas_debugspi1v8_ssn_hiz ? 1'bZ : kas_debugspi1v8_ssn_out)
                              : kas_spi_1v8.ss_n[KAS_SPI_1V8_MOD];
            assign kas_debugspi1v8_ssn_in = FE1_IO24_N;


            // assign FE1_IO24_P = kas_spi_1v8.hiz ? 1'bZ : kas_spi_1v8.mosi_out;  // non-debug version
            assign FE1_IO24_P = kas_debugspi1v8_en
                              ? (kas_debugspi1v8_mosi_hiz ? 1'bZ : kas_debugspi1v8_mosi_out)
                              : kas_spi_1v8.mosi_out;
            assign kas_debugspi1v8_mosi_in = FE1_IO24_P;
            assign kas_spi_1v8.mosi_in = FE1_IO24_P;

        end else begin: no_kas
            assign kas.present                    = '0;
            assign kas_spi_3v3.mosi_in            = '1;
            assign kas.rx_lock                    = '0;
            assign kas.tx_lock                    = '0;
            assign kas_i2c.sda_in                 = '1;
            assign kas_spi_1v8.miso               = '1;
            assign kas_spi_1v8.mosi_in            = '1;
            assign kas_ioexp_serial_data_loopback = '0;
            assign kas_cpm.alert_pins             = '1;
        end
    endgenerate




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Backplane


    generate
        if (ENABLE_BACKPLANE) begin: gen_enable_bp_i2c
            // bp_i2c.scl/sda_out=0 pulls down the pin, otherwise it's an input
            assign LVDS_PCIE_N[5]   = bp_i2c.scl      ? 1'bZ : 1'b0;
            assign bp_i2c.sda_in    = LVDS_PCIE_P[5];

            assign LVDS_PCIE_P[5]   = bp_i2c.sda_out  ? 1'bZ : 1'b0;
        end else begin
            assign bp_i2c.sda_in    = '1;
            assign LVDS_PCIE_N[5]   = 1'bZ;
            assign LVDS_PCIE_P[5]   = 1'bZ;
        end
    endgenerate

    generate
        if (ENABLE_BACKPLANE) begin: gen_enable_bp
            // Connect physical pins

            // both IO expanders share an interrupt pin
            assign bp_ioexp.int_n_pin   = LVDS_PCIE_N[4];
            assign sec_ioexp.int_n_pin  = LVDS_PCIE_N[4];

            // This IO expander only has inputs for HSD
            assign sec_ioexp.output_pins    = 'X;

            // Connect inputs/outputs that are controlled through the IO expander.
            assign LVDS_PCIE_N[1]           = bp_ioexp.reset_n_pin;
            assign bp_ssd_present_n[4:0]    = bp_ioexp.input_pins[4:0];
            assign bp_ssd_present_n[5]      = 1'b1; // HSD supports up to 5 SSDs

            // Unused alerts are tied off to 1, since the alert pin is active-low (see VAL_MASKEN06 in the corresponding CPM
            // package)
            assign bp_cpm.alert_pins[0] = sec_ioexp.input_pins[19];  // ALERT_3V3_MMU
            assign bp_cpm.alert_pins[1] = sec_ioexp.input_pins[17];  // ALERT_BATT_HDR
            assign bp_cpm.alert_pins[2] = sec_ioexp.input_pins[18];  // ALERT_3V3_HDR
            assign bp_cpm.alert_pins[3] = 1'b1;                      // ALERT_BATT_PCH_S in Alderaan GEN1.3 primary
            assign bp_cpm.alert_pins[4] = 1'b1;                      // ALERT_3V3_PCH_S in Alderaan GEN1.3 primary
            assign bp_cpm.alert_pins[5] = sec_ioexp.input_pins[22];  // ALERT_3V3_PCH
            assign bp_cpm.alert_pins[6] = sec_ioexp.input_pins[23];  // ALERT_BATT_AUX
            assign bp_cpm.alert_pins[7] = bp_ioexp.input_pins[19];   // ALERT_TEMPSNS1
            assign bp_cpm.alert_pins[8] = bp_ioexp.input_pins[20];   // ALERT_TEMPSNS2

            assign bp_hdr_present_n     = bp_ioexp.input_pins[5];

            // Assign X to pins only used as input or N.C., to avoid "undriven pin" warnings.
            assign bp_ioexp.output_pins[7:0]    = 'X;
            assign bp_ioexp.output_pins[12:8]   = bp_en_ssd[4:0];
            assign bp_ioexp.output_pins[17:13]  = 'X;
            assign bp_ioexp.output_pins[18]     = bp_en_tempsns;
            assign bp_ioexp.output_pins[23:19]  = 'X;

            assign bp_fast_alert_n = bp_ioexp.interrupt_n;

        end else begin: gen_disable_bp
            // Tie offs to prevent undriven pin warnings.
            assign bp_ioexp.int_n_pin       = 1'b1;
            assign bp_ioexp.output_pins     = 'X;
            assign sec_ioexp.int_n_pin      = 1'b1;
            assign bp_cpm.alert_pins        = '1;
            assign bp_hdr_present_n         = 1'b1;
            assign bp_fast_alert_n          = 1'b1;
            assign bp_ssd_present_n         = '1;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: IRQ


    assign OBC_GPIO[0] = obc_irq_io.irq_lo;
    assign OBC_GPIO[1] = obc_irq_io.irq_hi;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: SATA


    logic gth230_refclk;
    generate
        if (ENABLE_SSD_CTRL) begin : gen_enable_gth_refclk
            // Set up the user clock network.
            IBUFDS_GTE4 #(
                .REFCLK_HROW_CK_SEL ( 2'b10 )   // ODIV2 = 1'b0 (i.e. disable the output ODIV2)
            ) gtrefclk1_buf_inst (
                .I      ( DCLKOUT2_P  ),
                .IB     ( DCLKOUT2_N  ),
                .O      ( gth230_refclk ),
                .ODIV2  (             ),
                .CEB    ( 1'b0        )
            );
        end

        if (ENABLE_SSD_CTRL && (N_PL_SATA > 0)) begin: gen_enable_ssd
            for (genvar i = 0; i < N_PL_SATA; i++) begin
                assign sata_io[i].gtrefclk               = gth230_refclk;
                assign sata_io[i].REF_CLK_P_IN           = 1'b0; // Unused on Ultrascale
                assign sata_io[i].REF_CLK_N_IN           = 1'b0; // Unused on Ultrascale
                assign sata_io[i].RXN_IN                 = SSD_LANES_RX_N[SSD_LANE_ORDER[i]];
                assign sata_io[i].RXP_IN                 = SSD_LANES_RX_P[SSD_LANE_ORDER[i]];
                assign sata_io[i].DEVICE_PRESENT_N       = bp_ssd_present_n[SSD_LANE_ORDER[i]];
                assign SSD_LANES_TX_N[SSD_LANE_ORDER[i]] = sata_io[i].TXN_OUT;
                assign SSD_LANES_TX_P[SSD_LANE_ORDER[i]] = sata_io[i].TXP_OUT;
            end
        end else begin : gen_disable_ssd
            // If N_PL_SATA == 0 then sata_io is [0:0]. In that case, to get rid of undriven pin warnings,
            // we still want to tie off sata_io[0]. The 1 parameter to S_INT_MAX statement makes sure we
            // enter the loop at least once.
            for (genvar i = 0; i < UTIL_INTS::S_INT_MAX(1, N_PL_SATA); i++) begin
                assign sata_io[i].gtrefclk               = 1'b0;
                assign sata_io[i].REF_CLK_P_IN           = 1'b0;
                assign sata_io[i].REF_CLK_N_IN           = 1'b0;
                assign sata_io[i].RXN_IN                 = 1'b0;
                assign sata_io[i].RXP_IN                 = 1'b0;
                assign sata_io[i].DEVICE_PRESENT_N       = 1'b1;
                assign SSD_LANES_TX_N[SSD_LANE_ORDER[i]] = 1'b0;
                assign SSD_LANES_TX_P[SSD_LANE_ORDER[i]] = 1'b0;
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Debug


    var kas_i2c_scl_ff;
    var kas_i2c_scl_rise;
    var kas_i2c_scl_fall;
    always_ff @(posedge clksys_pl) kas_i2c_scl_ff <= kas_i2c.scl;
    assign kas_i2c_scl_rise = kas_i2c.scl == 1 && kas_i2c_scl_ff == 0;
    assign kas_i2c_scl_fall = kas_i2c.scl == 0 && kas_i2c_scl_ff == 1;

    var kas_ioexp_serial_clock_ff;
    var kas_ioexp_serial_clock_rise;
    var kas_ioexp_serial_clock_fall;
    always_ff @(posedge clksys_pl) kas_ioexp_serial_clock_ff <= kas_ioexp.serial_clock;
    assign kas_ioexp_serial_clock_rise = kas_ioexp.serial_clock == 1 && kas_ioexp_serial_clock_ff == 0;
    assign kas_ioexp_serial_clock_fall = kas_ioexp.serial_clock == 0 && kas_ioexp_serial_clock_ff == 1;


    var kas_rx_lock;
    var kas_tx_lock;
    always_ff @(posedge clksys_pl) kas_rx_lock <= kas.rx_lock;
    always_ff @(posedge clksys_pl) kas_tx_lock <= kas.tx_lock;

    var logic [15:0] debug = 0;
    always_ff @(posedge clksys_pl) debug <= debug + 1;
    var logic sample_1_in_2;
    var logic sample_1_in_4;
    var logic sample_1_in_8;
    var logic sample_1_in_16;
    var logic sample_1_in_32;
    var logic sample_1_in_64;
    var logic sample_1_in_128;
    var logic sample_1_in_256;
    var logic sample_1_in_512;
    var logic sample_1_in_1024;
    assign sample_1_in_2    = (debug[0]   == 0);
    assign sample_1_in_4    = (debug[1:0] == 0);
    assign sample_1_in_8    = (debug[2:0] == 0);
    assign sample_1_in_16   = (debug[3:0] == 0);
    assign sample_1_in_32   = (debug[4:0] == 0);
    assign sample_1_in_64   = (debug[5:0] == 0);
    assign sample_1_in_128  = (debug[6:0] == 0);
    assign sample_1_in_256  = (debug[7:0] == 0);
    assign sample_1_in_512  = (debug[8:0] == 0);
    assign sample_1_in_1024 = (debug[9:0] == 0);


    generate
        if (DEBUG_ILA) begin : dbg_ila_enabled
            ila_debug dbg_board_hsd_io (
                .clk    ( clksys_pl ),
                .probe0 ( sresetn_pl ),
                .probe1 ( '0 ),
                .probe2 ({bp_ssd_present_n,
                          bp_hdr_present_n,
                          bp_fast_alert_n}),
                .probe3 ( bp_cpm.alert_pins ),
                .probe4 ({obc_spi.ss_n,
                          obc_spi.sclk,
                          obc_spi.miso,
                          obc_spi.mosi_out,
                          sys_spi.sclk,
                          sys_spi.miso,
                          sys_spi.hiz,
                          sys_spi.mosi_out,
                          sys_spi.ss_n,
                          sdr_spi.sclk,
                          sdr_spi.miso,
                          sdr_spi.hiz,
                          sdr_spi.mosi_out,
                          sdr_spi.ss_n,
                          sys_i2c[0].scl,
                          sys_i2c[0].sda_out,
                          sys_i2c[0].sda_in,
                          sys_i2c[1].scl,
                          sys_i2c[1].sda_out,
                          sys_i2c[1].sda_in } ),
                .probe5 ( {bp_ssd_present_n, bp_en_ssd} ),
                .probe6 ( '0 ),
                .probe7 ( { system.pps } ),
                .probe8 ( { hdr_spi.mosi_out,
                            hdr_spi.mosi_in,
                            hdr_spi.miso,
                            hdr_spi.sclk,
                            hdr_i2c.sda_in,
                            hdr_i2c.sda_out,
                            hdr_i2c.scl,
                            hdr.enable_rx,
                            hdr.enable_tx,
                            hdr.enable_pa,
                            hdr.enable_digital,
                            hdr.enable_synth,
                            hdr.synth_tx_locked,
                            hdr.synth_rx_locked,
                            hdr.rx_select,
                            hdr.tx_select,
                            hdr.present,
                            hdr_cpm.alert_pins,
                            VCC1_SEL } ),
                .probe9 ( { kas.en_3v8,
                            kas.en_3v3_vstby,
                            kas.en_6v5,
                            kas.i2c_en,
                            kas.present,
                            kas.lna2_byp,
                            kas.ioexp_oe_n,
                            kas.rx_lock,
                            kas.tx_lock,
                            kas_rx_lock,
                            kas_tx_lock } ),
                .probe10( { kas_cpm.alert_pins,
                            kas_spi_3v3.ss_n,
                            kas_spi_3v3.sclk,
                            kas_spi_3v3.miso,
                            kas_spi_3v3.mosi_out,
                            kas_spi_3v3.mosi_in,
                            kas_spi_1v8.ss_n,
                            kas_spi_1v8.sclk,
                            kas_spi_1v8.miso,
                            kas_spi_1v8.mosi_out,
                            kas_spi_1v8.mosi_in,
                            kas_i2c.scl,
                            kas_i2c.sda_out,
                            kas_i2c.sda_in,
                            kas_i2c_scl_rise,
                            kas_i2c_scl_fall } ),
                .probe11( { kas_ioexp.serial_clock,
                            kas_ioexp.serial_data,
                            kas_ioexp.latch,
                            kas_ioexp.output_enable_n,
                            kas_ioexp_serial_data_loopback,
                            kas_ioexp_serial_clock_rise,
                            kas_ioexp_serial_clock_fall } ),
                .probe12( { kas_debugi2c_en,
                            kas_debugi2c_scl_in,
                            kas_debugi2c_scl_out,
                            kas_debugi2c_scl_hiz,
                            kas_debugi2c_sda_in,
                            kas_debugi2c_sda_out,
                            kas_debugi2c_sda_hiz,
                            kas_debugspi1v8_en,
                            kas_debugspi1v8_sclk_in,
                            kas_debugspi1v8_sclk_out,
                            kas_debugspi1v8_sclk_hiz,
                            kas_debugspi1v8_mosi_in,
                            kas_debugspi1v8_mosi_out,
                            kas_debugspi1v8_mosi_hiz,
                            kas_debugspi1v8_ssn_in,
                            kas_debugspi1v8_ssn_out,
                            kas_debugspi1v8_ssn_hiz,
                            kas_debugspi3v3_en,
                            kas_debugspi3v3_dacssn_in,
                            kas_debugspi3v3_dacssn_out,
                            kas_debugspi3v3_dacssn_hiz  } ),
                .probe13( 0 ),
                .probe14( 0 ),
                .probe15( { sample_1_in_2,
                            sample_1_in_4,
                            sample_1_in_8,
                            sample_1_in_16,
                            sample_1_in_32,
                            sample_1_in_64,
                            sample_1_in_128,
                            sample_1_in_256,
                            sample_1_in_512,
                            sample_1_in_1024 } )
            );
        end
    endgenerate
endmodule

`undef PL_SATA_ARRAY_DEF

`default_nettype wire
