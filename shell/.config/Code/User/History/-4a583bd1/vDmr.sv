// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

/**
 * Instantiation and connection of high-level blocks for the MPCU.
 */
module board_mpcut1_system
    import AVMM_ADDRS_MPCUT1::*;
    import BOARD_MPCUT1_PPL_SGMII_PKG::*;
    import AETHER_PKG::*;
    import BOARD_MPCUT1_ETH_PKG::*;
#(
    parameter bit [BLADE_SLOTS_NUM_INDICES - 1 : 0][1:0]  GTH_ENABLE_SLOT_MASK      = '0,
    parameter bit [BLADE_SLOTS_NUM_INDICES - 1 : 0] PPL_DUAL_LANE_SLOT_MASK         = '0,
    parameter bit [BLADE_SLOTS_NUM_INDICES - 1 : 0][1:0] SGMII_GTH_LANE_SLOT_MASK   = '0,
    parameter bit [BLADE_SLOTS_NUM_INDICES - 1 : 0][1:0] PPL_GTH_LANE_SLOT_MASK     = '0,
    parameter int HDR_SLOT_INDEXES  [1:0]                                           = '{default: BG_SLOT_NONE},
    parameter int OISL_SLOT_INDEXES [1:0]                                           = '{default: BG_SLOT_NONE},
    parameter bit ENABLE_MSU_SATA = 1'b0,
    parameter bit FEC_ON_SSD = 1'b0,
    parameter bit DEBUG_ILA = 1'b0
) (

    //
    // TODO: replace hardcoded clock frequencies with e.g. clk_ifc_main_out.SOURCE_FREQUENCY
    //

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: External async reset in


    Reset_int   aresetn_ifc_external_in,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clock and reset outputs from the Zynq block


    // Note: These clock outputs do not use the .Output modport because they're also used
    // internally within this module to drive .Input modports of sub-modules. If you use
    // the .Output modport here, then Vivado 2021 will treat the internal .Input version as
    // undriven, and all of the modules that use it will have no clock.
    Clock_int.Output    clk_ifc_main_out,
    Clock_int.Output    clk_ifc_50_out,
    Clock_int.Output    clk_ifc_1g_enet_out,
    Clock_int.Input     clk_ifc_elmer_refclk,
    Clock_int.Output    clk_ifc_blade_ext_spi_out,

    Reset_int.ResetOut  sreset_ifc_main_peripheral_out,
    Reset_int.ResetOut  sreset_ifc_main_interconnect_out,
    Reset_int.ResetOut  sresetn_ifc_main_peripheral_out,
    Reset_int.ResetOut  sresetn_ifc_main_interconnect_out,
    Reset_int.ResetOut  sreset_ifc_1g_enet_peripheral_out,
    Reset_int.ResetOut  sreset_ifc_1g_enet_interconnect_out,
    Reset_int.ResetOut  sresetn_ifc_1g_enet_peripheral_out,
    Reset_int.ResetOut  sresetn_ifc_1g_enet_interconnect_out,
    Reset_int.ResetOut  sreset_ifc_elmer_refclk_peripheral_out,
    Reset_int.ResetOut  sreset_ifc_elmer_refclk_interconnect_out,
    Reset_int.ResetOut  sresetn_ifc_elmer_refclk_peripheral_out,
    Reset_int.ResetOut  sresetn_ifc_elmer_refclk_interconnect_out,
    Reset_int.ResetOut  sreset_ifc_50_peripheral_out,
    Reset_int.ResetOut  sreset_ifc_50_interconnect_out,
    Reset_int.ResetOut  sresetn_ifc_50_peripheral_out,
    Reset_int.ResetOut  sresetn_ifc_50_interconnect_out,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MPCU Interface


    SPIIO_int mpcu_spi,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PL DDR


    input  var logic        clk_ddr_pl_n,
    input  var logic        clk_ddr_pl_p,
    output var logic [16:0] pl_ddr_a,
    output var logic        pl_ddr_act_n,
    output var logic  [1:0] pl_ddr_ba,
    output var logic        pl_ddr_bg0,
    output var logic        pl_ddr_ck0_n,
    output var logic        pl_ddr_ck0_p,
    output var logic        pl_ddr_cke0,
    output var logic        pl_ddr_cs_n0,
    inout  tri logic  [1:0] pl_ddr_dm,
    inout  tri logic [15:0] pl_ddr_dq,
    inout  tri logic  [1:0] pl_ddr_dqs_n,
    inout  tri logic  [1:0] pl_ddr_dqs_p,
    output var logic        pl_ddr_odt,
    output var logic        pl_1v8_ddr_rst_n,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK


    SPIIO_int.Driver lmk_spi_io,
    CLK_LMK04828_int lmk,




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Peripherals


    output var logic    [9:0]   aocs_uart_soc_tx,
    input  var logic    [9:0]   aocs_uart_soc_rx,
    output var logic    [8:6]   aocs_uart_dr_upper,     // DE/REn for RS-485 interfaces
    output var logic    [3:2]   aocs_uart_dr_lower,     // DE/REn for RS-485 interfaces

    output var logic    [2:0]   msp_uart_soc_tx,        // 0=SUP, 1=CSI, 2=SKY
    input  var logic    [2:0]   msp_uart_soc_rx,        // 0=SUP, 1=CSI, 2=SKY

    input  var logic    [7:3]   aocs_i2c_scl_i,
    output var logic    [7:3]   aocs_i2c_scl_o,
    output var logic    [7:3]   aocs_i2c_scl_t,
    input  var logic    [7:3]   aocs_i2c_sda_i,
    output var logic    [7:3]   aocs_i2c_sda_o,
    output var logic    [7:3]   aocs_i2c_sda_t,

    input  var logic            aocs_pmbus_i2c_scl_i,
    output var logic            aocs_pmbus_i2c_scl_o,
    output var logic            aocs_pmbus_i2c_scl_t,
    input  var logic            aocs_pmbus_i2c_sda_i,
    output var logic            aocs_pmbus_i2c_sda_o,
    output var logic            aocs_pmbus_i2c_sda_t,
    input  var logic            aocs_pmbus_alert_n,
    inout  tri logic            aocs_pmbus_ctrl,

    input  var logic    [3:0]   bg_pmbus_i2c_scl_i,
    output var logic    [3:0]   bg_pmbus_i2c_scl_o,
    output var logic    [3:0]   bg_pmbus_i2c_scl_t,
    input  var logic    [3:0]   bg_pmbus_i2c_sda_i,
    output var logic    [3:0]   bg_pmbus_i2c_sda_o,
    output var logic    [3:0]   bg_pmbus_i2c_sda_t,

    input  var logic            mpcu_pmbus_i2c_scl_i,
    output var logic            mpcu_pmbus_i2c_scl_o,
    output var logic            mpcu_pmbus_i2c_scl_t,
    input  var logic            mpcu_pmbus_i2c_sda_i,
    output var logic            mpcu_pmbus_i2c_sda_o,
    output var logic            mpcu_pmbus_i2c_sda_t,

    input  var logic            elmer_pmbus_i2c_scl_i,
    output var logic            elmer_pmbus_i2c_scl_o,
    output var logic            elmer_pmbus_i2c_scl_t,
    input  var logic            elmer_pmbus_i2c_sda_i,
    output var logic            elmer_pmbus_i2c_sda_o,
    output var logic            elmer_pmbus_i2c_sda_t,
    input  var logic            elmer_pmbus_alert_n,


    output var logic            aocs_gps_rst_n,
    input  var logic            gps_pv,                     // GPS position valid input
    input  var logic            gps_pps_in,
    inout  tri logic            aocs_msp_test,
    inout  tri logic            aocs_msp_trst_n,            // open-drain
    input  var logic    [1:5]   aocs_rw_fault_n,
    inout  tri logic    [1:5]   aocs_rw_rst_n,
    output var logic    [1:2]   aocs_spacewire_en,

    input  var logic            hdrm_inhib_n,               // monitors hold-down release mechanism inhibit
    input  var logic            ttc_tx_inhib_n,             // TX inhibit signal from umbilical
    input  var logic            umb_prsnt_n,                // umbilical present

    input  var logic            hpio66_sgmii_refclk_n,
    input  var logic            hpio66_sgmii_refclk_p,

    input  var logic            umbilical_dummy_port,
    input  var logic            umbilical_sgmii_rx_n,
    input  var logic            umbilical_sgmii_rx_p,
    output var logic            umbilical_sgmii_tx_n,
    output var logic            umbilical_sgmii_tx_p,

    output var logic    [2:0]   blade_spi_mux_ctrl_a,       // blade SPI mux control address bits
    output var logic            blade_spi_mux_bg01_en_n,    // OEn for the SPI mux for blade groups 0 and 1
    output var logic            blade_spi_mux_bg2_en_n,     // OEn for the SPI mux for blade group 2
    input  var logic    [2:0]   blade_pmbus_alert_n,        // PMbus alert inputs for BG0, 1, 2
    input  var logic            mpcu_pmbus_alert_n,         // PMbus alert input for the PCU's PMbus
    inout  tri logic            mpcu_pmbus_ctrl,            // PMbus "ctrl" signal for MPCU's PMbus
    output var logic            mpcu_pmbus_level_shift_en,  // level shifter for accessing MPCU's own PMbus
    inout  tri logic            elmer_seq_rst_n,

    inout  tri logic    [1:0]   blade_spi_clk,
    inout  tri logic    [1:0]   blade_spi_mosi,
    inout  tri logic    [1:0]   blade_spi_miso,
    inout  tri logic    [1:0]   blade_spi_ss_n_0,
    inout  tri logic    [1:0]   blade_spi_ss_n_1,

    output var logic            sky_en,                     // Skywalker enable
    inout  tri logic            sky_msp_test,
    inout  tri logic            sky_msp_trst_n,             // open-drain

    output var logic            gth_sata_refclk_oe,         // enables the 150 MHz reference clock for SATA SSDs

    output var logic            fake_pps,                    // fake PPS signal generated from clk_ifc_elmer_refclk for test purposes

    SataIO_int.Ctrl             sata_io[3:0],

    SpaceWire_int.IO            spacewire[1:0],

    input var logic             refclk_p,
    input var logic             refclk_n,

    MDIO_IO_int.Driver          elmer_phy_mdio,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Interfaces to blades


    IO_int.Driver               blade_gpio [2:0][3:0][1:0][1:0],         // index: [blade group][blade][lane][0=N, 1=P]
    IO_int.Driver               blade_spare_gpio[2:0][3:0],              // index: [blade group][blade]

    output var logic    [3:0]   ecg_uart_soc_tx,
    input  var logic    [3:0]   ecg_uart_soc_rx,

    output var logic    [3:0]   ecg_rst_n,
    input  var logic    [3:0]   ecg_int,
    input  var logic    [3:0]   ecg_gpx,


    input  var logic    [1:0]   oisl_dummy_port,

    XcvrIO_int.IO               oisl_data_xfi               [1:0],
    XcvrIO_int.IO               oisl_tmtc_sgmii             [1:0],
    XcvrIO_int.IO               oisl_prog_sgmii             [1:0],
    MDIO_IO_int.PassThrough     oisl_tmtc_prog_phy_mdio     [1:0],
    MDIO_IO_int.PassThrough     oisl_aqr_phy_mdio           ,

    XcvrIO_int.IO               ecg_xfi                     ,

    MPCUT1_blade_xcvr_int.MPCU  blade_xcvrs,                             // transceivers to blades

    XcvrIO_int.IO               hdr_aurora [0:0]

);

    import BOARD_MPCUT1_CLOCK_RESET_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters


    localparam int MMI_ADDRLEN = AVMM_ADDRLEN - 2;
    localparam int MMI_DATALEN = 16;

    localparam int MAX_PKTSIZE    = 8192;  // approx 4096 byte simpletoga payload + simpletoga command overhead + UDP/IP/Ethernet overhead


    localparam int ENABLE_PPL =  |PPL_GTH_LANE_SLOT_MASK;

    localparam int AURORA_XCVR_INDEXES[0:0][0:0] = '{0:'{0}};


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    // Verify polarities of resets
    `ELAB_CHECK_EQUAL(sreset_ifc_main_peripheral_out.ACTIVE_HIGH,          1);
    `ELAB_CHECK_EQUAL(sreset_ifc_main_interconnect_out.ACTIVE_HIGH,        1);
    `ELAB_CHECK_EQUAL(sresetn_ifc_main_peripheral_out.ACTIVE_HIGH,         0);
    `ELAB_CHECK_EQUAL(sresetn_ifc_main_interconnect_out.ACTIVE_HIGH,       0);
    `ELAB_CHECK_EQUAL(sreset_ifc_1g_enet_peripheral_out.ACTIVE_HIGH,       1);
    `ELAB_CHECK_EQUAL(sreset_ifc_1g_enet_interconnect_out.ACTIVE_HIGH,     1);
    `ELAB_CHECK_EQUAL(sresetn_ifc_1g_enet_peripheral_out.ACTIVE_HIGH,      0);
    `ELAB_CHECK_EQUAL(sresetn_ifc_1g_enet_interconnect_out.ACTIVE_HIGH,    0);
    `ELAB_CHECK_EQUAL(sreset_ifc_elmer_refclk_peripheral_out.ACTIVE_HIGH,   1);
    `ELAB_CHECK_EQUAL(sreset_ifc_elmer_refclk_interconnect_out.ACTIVE_HIGH, 1);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Clocks and Resets


    Clock_int #(
        .CLOCK_GROUP_ID   (XCVR_B228_GROUP_ID),
        .NUM              (1                 ),
        .DEN              (1                 ),
        .PHASE_ID         (0                 ),
        .SOURCE_FREQUENCY (156_250_000       )
    ) gth228_ref_clk_ifc [0:0] ();

    Clock_int #(
        .CLOCK_GROUP_ID   (PS_1G_ENET_GROUP_ID           ),
        .NUM              (PS_IOPLL_PL_MMCM_80M_NUM      ),
        .DEN              (PS_IOPLL_PL_MMCM_80M_DEN      ),
        .PHASE_ID         (PS_IOPLL_PL_MMCM_80M_PHASE_ID ),
        .SOURCE_FREQUENCY (PS_IOPLL_125M_OUTPUT_FREQUENCY)
    ) spacewire_clk_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   (PS_1G_ENET_GROUP_ID            ),
        .NUM              (PS_IOPLL_PL_MMCM_80M_NUM       ),
        .DEN              (PS_IOPLL_PL_MMCM_80M_DEN       ),
        .PHASE_ID         (PS_IOPLL_PL_MMCM_80M_B_PHASE_ID),
        .SOURCE_FREQUENCY (PS_IOPLL_125M_OUTPUT_FREQUENCY )
    ) spacewire_clk_b_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( spacewire_clk_ifc.CLOCK_GROUP_ID ),
        .NUM            ( spacewire_clk_ifc.NUM            ),
        .DEN            ( spacewire_clk_ifc.DEN            ),
        .PHASE_ID       ( spacewire_clk_ifc.PHASE_ID       ),
        .ACTIVE_HIGH    ( 1                             ),
        .SYNC           ( 1                             )
    ) spacewire_srst_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( spacewire_clk_ifc.CLOCK_GROUP_ID ),
        .NUM            ( spacewire_clk_ifc.NUM            ),
        .DEN            ( spacewire_clk_ifc.DEN            ),
        .PHASE_ID       ( spacewire_clk_ifc.PHASE_ID       ),
        .ACTIVE_HIGH    ( 0                                ),
        .SYNC           ( 1                                )
    ) spacewire_srstn_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [63:0]    us_count_on_clk_1g_enet;    // free-running microsecond count
    logic [63:0]    us_count_on_clk_main;       // free-running microsecond count; slightly lags us_count_on_clk_1g_enet
    logic           us_pulse_on_clk_1g_enet;    // pulses once every microsecond
    logic           us_pulse_on_clk_main;       // pulses once every microsecond; slightly lags us_pulse_on_clk_1g_enet


    logic [31:0]  aocs_ctrl_gpio_i;
    logic [31:0]  aocs_ctrl_gpio_o;
    logic [31:0]  aocs_ctrl_gpio_t;

    logic [63:0]  elmer_ctrl_gpio_i;
    logic [63:0]  elmer_ctrl_gpio_o;
    logic [63:0]  elmer_ctrl_gpio_t;
    logic [63:0]  blade_ctrl_gpio_i;
    logic [63:0]  blade_ctrl_gpio_o;
    logic [63:0]  blade_ctrl_gpio_t;
    logic [95:0]  emio_gpio_i;
    logic [95:0]  emio_gpio_o;
    logic [95:0]  emio_gpio_t;

    logic [1:0][4:0]  blade_spi_ios_i;    // two controllers; [4:0] = {ss1, ss0, miso, mosi, clk}
    logic [1:0][4:0]  blade_spi_ios_o;
    logic [1:0][4:0]  blade_spi_ios_t;

    logic [2:0]  oisl_aqr_phy_mdio_spi_ios_i;    // {miso/io1, mosi/io0, clk}
    logic [2:0]  oisl_aqr_phy_mdio_spi_ios_o;
    logic [2:0]  oisl_aqr_phy_mdio_spi_ios_t;


    logic [31:0] avmm_gpio_out [0:0];
    logic [31:0] avmm_gpio_in  [0:0];


    MDIO_IO_int oisl_tmtc_prog_phy_mdio_drv [1:0] ();
    logic oisl_aqr_phy_select;


    vitis_net_p4_forward_2022 vnp4_inst (
        .s_axis_aclk               ( clk_ifc_main_out.clk ),
        .s_axis_aresetn            ( sresetn_ifc_main_interconnect_out.reset ),
        .s_axi_aclk                ( clk_ifc_main_out.clk ),
        .s_axi_aresetn             ( sresetn_ifc_main_interconnect_out.reset ),
        .cam_mem_aclk              ( clk_ifc_main_out.clk ),
        .cam_mem_aresetn           ( sresetn_ifc_main_interconnect_out.reset ),
        .user_metadata_in          (  ),
        .user_metadata_in_valid    (  ),
        .user_metadata_out         (  ),
        .user_metadata_out_valid   (  ),
        .s_axi_awaddr              ( '0  ),
        .s_axi_awvalid             ( '0 ),
        .s_axi_awready             ( '0 ),
        .s_axi_wdata               ( '0 ),
        .s_axi_wstrb               ( '0 ),
        .s_axi_wvalid              ( '0 ),
        .s_axi_wready              (  ),
        .s_axi_bresp               (  ),
        .s_axi_bvalid              (  ),
        .s_axi_bready              ( '0 ),
        .s_axi_araddr              ( '0 ),
        .s_axi_arvalid             ( '0 ),
        .s_axi_arready             (  ),
        .s_axi_rdata               (  ),
        .s_axi_rvalid              (  ),
        .s_axi_rready              ( '0 ),
        .s_axi_rresp               (  ),
        //.irq                      (\<const0> ),
        .m_axis_tdata              ( hdr_aur_axis_tx[0].tdata  ),
        .m_axis_tkeep              ( hdr_aur_axis_tx[0].tkeep  ),
        .m_axis_tvalid             ( hdr_aur_axis_tx[0].tvalid ),
        .m_axis_tlast              ( hdr_aur_axis_tx[0].tlast  ),
        .m_axis_tready             ( hdr_aur_axis_tx[0].tready ),
        .s_axis_tdata              ( hdr_aur_axis_rx[0].tdata   ),
        .s_axis_tkeep              ( hdr_aur_axis_rx[0].tkeep   ),
        .s_axis_tvalid             ( hdr_aur_axis_rx[0].tvalid  ),
        .s_axis_tlast              ( hdr_aur_axis_rx[0].tlast   ),
        .s_axis_tready             ( hdr_aur_axis_rx[0].tready  )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SPI to AVMM


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_spi_to_avmm_loopback (
        .clk     ( clk_ifc_main_out.clk                    ),
        .sresetn ( sresetn_ifc_main_interconnect_out.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq Data Busses


    // AXI4 LPD bus (FPGA master)
    AXI4_int #(
        .DATALEN ( 32 ),
        .ADDRLEN ( 40 ),
        .WIDLEN  ( 6  ),
        .RIDLEN  ( 6  )
    ) axi_lpd_s (
        .clk     ( clk_ifc_main_out.clk                    ),
        .sresetn ( sresetn_ifc_main_interconnect_out.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SDR Interfaces


    // TODO: Remove when AVMM startup control is added
    SDR_Ctrl_int #( .STATELEN (1) ) ddr_ctrl    ( .clk ( clk_ifc_main_out.clk ) );
    SDR_Ctrl_int #( .STATELEN (1) ) lmk_ctrl    ( .clk ( clk_ifc_main_out.clk ) );
    SDR_Ctrl_int #( .STATELEN (1) ) ppl_aur_ctrl_bg0( .clk ( clk_ifc_main_out.clk ) );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Interfaces


    // Indicies of AVMM bus masters. Lower values have higher priority.
    typedef enum {
        AVMM_MASTER_SPI,
        AVMM_MASTER_ZYNQ,
        NUM_AVMM_MASTERS
    } avmm_masters_t;


    // AVMM Masters to Arbiter Interface
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 11           ),
        .BURST_CAPABLE ( 1'b1         )
    ) avmm_masters_to_arbiter_ifc [NUM_AVMM_MASTERS-1:0] (); // spi_to_avmm, and amm bridge (zynq)

    // AVMM Arbiter to Unburst Interface
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 11           ),
        .BURST_CAPABLE ( 1'b1         )
    ) avmm_arbiter_to_unburst_ifc ();

    // AVMM Unburst to Demux Interface
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) avmm_unburst_to_demux_ifc ();

    // AVMM Demux to Device Interfaces
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) avmm_dev_ifc [AVMM_NDEVS:0] (); // not AVMM_NDEVS-1, avmm_dev_ifc[AVMM_NDEVS] is the necessary bad address responder

    AvalonMM_int #(
        .DATALEN ( 32 ),
        .ADDRLEN ( 49 )
    ) avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc ();

    AvalonMM_int #(
        .DATALEN ( 32 ),
        .ADDRLEN ( 49 )
    ) avmm_init_ctrl_to_ps_master_ifc ();

    avmm_init_ctrl_int #(
        .DATALEN       ( 32 ),
        .ADDRLEN       ( 49 ),
        .NUM_INIT_REGS ( 1  )
    ) avmm_init_ctrl_ps_master_init_values_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK


    SPIDriver_int #(
        .MAXLEN ( 32 ),
        .SSNLEN ( 1  )
    ) lmk_spi_drv_ifc [0:0] (
        .clk     ( clk_ifc_main_out.clk                  ),
        .sresetn ( sresetn_ifc_main_peripheral_out.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DDR controller


    logic clk_ddr, sreset_ddr;

    // The MMI interface to ddr4_ctrl, on clk_100_free_running
    MemoryMap_int #(
        .ADDRLEN ( 27 ),
        .DATALEN ( 64 )
    ) mmi_ddr_mmiclk ();

    // The MMI interface to ddr4_ctrl, on clk_ddr
    MemoryMap_int #(
        .ADDRLEN ( 27 ),
        .DATALEN ( 64 )
    ) mmi_ddr ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PPL


    AuroraCtrl_int #(.NUM_LANES(1))  hdr_aur_phys [1 : 0]();
    XcvrDebug_int #(.NUM_LANES(1)) hdr_aur_gt_debug [1: 0] ();

    DRP_int hdr_aur_drp [1:0][0:0] ();

    logic [1 : 0] hdr_aurora_axis_clk;
    logic [1 : 0] hdr_aurora_axis_rst_n;


    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) hdr_aur_axis_tx [1:0] (
        .clk     ( hdr_aurora_axis_clk   ),
        .sresetn ( hdr_aurora_axis_rst_n )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) hdr_aur_axis_rx [1:0](
        .clk     ( hdr_aurora_axis_clk   ),
        .sresetn ( hdr_aurora_axis_rst_n )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) ppl_axis_tx_bg0 [1:0][0:0][EXTERNAL_PPL_AXIS_TX_NUM_INDICES-1:0] (
        .clk     ( hdr_aurora_axis_clk   ),
        .sresetn ( hdr_aurora_axis_rst_n )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) ppl_axis_rx_bg0 [1:0][0:0][EXTERNAL_PPL_AXIS_RX_NUM_INDICES-1:0] (
        .clk     ( hdr_aurora_axis_clk   ),
        .sresetn ( hdr_aurora_axis_rst_n )
    );


    XcvrIO_int #(
        .NUM_LANES (1                                           ),
        .LOCS      ('{blade_xcvrs.XCVRS_LOCS[HDR_SLOT_INDEXES[1]][0]})
    ) hdr_xcvrs1 ();

    XcvrIO_int #(
        .NUM_LANES (1                                           ),
        .LOCS      ('{blade_xcvrs.XCVRS_LOCS[HDR_SLOT_INDEXES[0]][0]})
    ) hdr_xcvrs0 ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI Ethernet


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) blade_eth_src [NUM_BLADE_ETH_SRC_INDICES-1:0] (
        .clk    (clk_ifc_1g_enet_out.clk ),
        .sresetn(sresetn_ifc_1g_enet_peripheral_out.reset)
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) blade_eth_sink [NUM_BLADE_ETH_SINK_INDICES-1:0] (
        .clk    (clk_ifc_1g_enet_out.clk ),
        .sresetn(sresetn_ifc_1g_enet_peripheral_out.reset)
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) hdrs_virtual_eth_src [1:0] (
        .clk    (clk_ifc_1g_enet_out.clk ),
        .sresetn(sresetn_ifc_1g_enet_peripheral_out.reset)
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) hdrs_virtual_eth_sink [1:0] (
        .clk    (clk_ifc_1g_enet_out.clk ),
        .sresetn(sresetn_ifc_1g_enet_peripheral_out.reset)
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Spacewire


    // Spacewire packets from PS to PL (Originating from PS)
    AXIS_int #(.DATA_BYTES(1)) spacewire_axis_tx [1:0] (
        .clk     (spacewire_clk_ifc.clk    ),
        .sresetn (spacewire_srstn_ifc.reset)
    );

    // Spacewire packets from PL to PS (Originating from outside)
    AXIS_int #(.DATA_BYTES(1)) spacewire_axis_rx [1:0] (
        .clk     (spacewire_clk_ifc.clk    ),
        .sresetn (spacewire_srstn_ifc.reset)
    );


    logic [1:0] spacewire_interrupt;
    logic [1:0] spacewire_axis_tx_aresetn;
    logic [1:0] spacewire_axis_rx_aresetn;
    logic spacewire_mmcm_locked;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Module Declarations and Connections


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SPI to AVMM


    spi_to_avmm #(
        .ENABLE_AXIS                ( 0      ),
        .STREAM_IN_FIFO_BYTE_DEPTH  ( 1024   ),
        .STREAM_OUT_FIFO_BYTE_DEPTH ( 1024   ),
        .STREAM_IDLE_CHAR           ( 8'hC0  ),
        .PARITY_SUPPORT             ( 0      ),
        .PARITY_ENABLED_DEFAULT     ( 0      ),
        .SPI_CPHA                   ( 0      ),
        .SPI_CPOL                   ( 0      )
    ) spi_to_avmm_inst (
        .avmm_out        ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_SPI] ),
        .clock_ifc_avmm  ( clk_ifc_main_out                 ),
        .sreset_ifc_avmm ( sreset_ifc_main_interconnect_out ),
        .clock_ifc_axis  ( clk_ifc_main_out                 ),
        .sreset_ifc_axis ( sreset_ifc_main_interconnect_out ),

        .axis_out ( axis_spi_to_avmm_loopback.Master ), // TODO: Loopback for now
        .axis_in  ( axis_spi_to_avmm_loopback.Slave  ),

        .spi_slave_io ( mpcu_spi )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Arbiter


    avmm_arbiter #(
        .N             ( NUM_AVMM_MASTERS ),
        .ARB_TYPE      ( "round-robin"    ),
        .HIGHEST       (  0               ),
        .ILA_DEBUG_IDX ( -1               )
    ) avmm_arbiter_inst (
        .clk_ifc                 ( clk_ifc_main_out ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm_in                 ( avmm_masters_to_arbiter_ifc ),
        .avmm_out                ( avmm_arbiter_to_unburst_ifc.Master ),
        .read_active_mask        ( ),
        .write_active_mask       ( )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Unburst Adapter
    // TODO: We want burst support for some slaves. Divide the bus into burst and non-burst capable segments.


    avmm_unburst #(
        .ADDRESS_INCREMENT ( 0 )
    ) avmm_unburst_spi_to_demux (
        .clk_ifc                 ( clk_ifc_main_out ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm_in                 ( avmm_arbiter_to_unburst_ifc.Slave ),
        .avmm_out                ( avmm_unburst_to_demux_ifc.Master  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Demux


    avmm_demux #(
        .NUM_DEVICES        ( AVMM_NDEVS      ),
        .ADDRLEN            ( AVMM_ADDRLEN    ),
        .DEVICE_ADDR_OFFSET ( DEV_OFFSET      ),
        .DEVICE_ADDR_WIDTH  ( DEV_WIDTH       )
    ) avmm_demux_inst (
        .clk_ifc                 ( clk_ifc_main_out ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm_in                 ( avmm_unburst_to_demux_ifc.Slave ),
        .avmm_out                ( avmm_dev_ifc                    )
    );

    avmm_bad avmm_bad_inst (
        .clk_ifc                 ( clk_ifc_main_out ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm                    ( avmm_dev_ifc[AVMM_NDEVS]       )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM ROM


    avmm_rom #(
        .MODULE_VERSION ( 1 ),
        .MODULE_ID      ( AVMM_ADDRS_ROM+1 ),
        .ROM_FILE_NAME  ( "board_mpcut1_avmm_addrs_rom_init.hex" ),
        .ROM_DEPTH      ( AVMM_ROM_DEPTH )
    ) avmm_rom_inst (
        .clk_ifc                 ( clk_ifc_main_out ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_ADDRS_ROM] )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM GIT INFO


    avmm_rom #(
        .MODULE_VERSION ( 1                                                ),
        .MODULE_ID      ( AVMM_GIT_INFO + 1                                ),
        .ROM_FILE_NAME  ( {"../../avmm/", GIT_INFO_ROM_PKG::ROM_FILE_NAME} ),
        .ROM_DEPTH      ( GIT_INFO_ROM_PKG::ROM_DEPTH                      ),
        .DEBUG_ILA      ( 0                                                )
    ) git_info_avmm_rom_inst (
        .clk_ifc                 ( clk_ifc_main_out                 ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_GIT_INFO]      )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DDR controller


    assign ddr_ctrl.sresetn = 1'b1;

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(ddr_mmi_to_mmi_ifc, avmm_dev_ifc[AVMM_DDR_CTRL], 1, AVMM_DDR_CTRL+1, 14,  clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, 1);

    // Put the DDR behind an mmi_to_mmi, since MMI only has a 15-bit address
    mmi_to_mmi #(
        .MMI_ADDRLEN    ( MMI_ADDRLEN       ),
        .MMI_DATALEN    ( MMI_DATALEN       ),
        .MMI_S_ADDRLEN  ( mmi_ddr.ADDRLEN   ),
        .MMI_S_DATALEN  ( mmi_ddr.DATALEN   )
    ) ddr_mmi_to_mmi_inst (
        .clk    ( clk_ifc_main_out.clk                  ),
        .reset_n( sresetn_ifc_main_peripheral_out.reset ),
        .mmi    ( ddr_mmi_to_mmi_ifc                    ),
        .mmi_s  ( mmi_ddr_mmiclk.Master                 )
    );

    xclock_mmi xclock_mmi_ddr_inst (
        .m_clk      ( clk_ifc_main_out.clk                  ),
        .m_resetn   ( sresetn_ifc_main_peripheral_out.reset ),
        .m_mmi      (  mmi_ddr_mmiclk.Slave                 ),
        .s_clk      (  clk_ddr                              ),
        .s_resetn   ( ~sreset_ddr                           ),
        .s_mmi      (  mmi_ddr.Master                       )
    );

    ddr4_ctrl ddr4_ctrl_inst (
        .clkddr4_drv     ( clk_ddr                  ),
        .clkddr4_sync_rst( sreset_ddr               ),
        .ddr4_act_n      ( pl_ddr_act_n             ),
        .ddr4_adr        ( pl_ddr_a                 ),
        .ddr4_ba         ( pl_ddr_ba                ),
        .ddr4_bg         ( pl_ddr_bg0               ),
        .ddr4_cke        ( pl_ddr_cke0              ),
        .ddr4_odt        ( pl_ddr_odt               ),
        .ddr4_cs_n       ( pl_ddr_cs_n0             ),
        .ddr4_ck_t       ( pl_ddr_ck0_p             ),
        .ddr4_ck_c       ( pl_ddr_ck0_n             ),
        .ddr4_reset_n    ( pl_1v8_ddr_rst_n         ),
        .ddr4_dm_dbi_n   ( pl_ddr_dm                ),
        .ddr4_dq         ( pl_ddr_dq                ),
        .ddr4_dqs_c      ( pl_ddr_dqs_n             ),
        .ddr4_dqs_t      ( pl_ddr_dqs_p             ),
        .sys_clk_p       ( clk_ddr_pl_p             ),
        .sys_clk_n       ( clk_ddr_pl_n             ),
        .mmi_ram         ( mmi_ddr.Slave            ),
        .ddr_ctrl        ( ddr_ctrl.Slave           )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK controller


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_lmkclk_ifc, avmm_dev_ifc[AVMM_LMKCLK], 1, AVMM_LMKCLK+1, 14, clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, 1);

    assign lmk_ctrl.sresetn = sresetn_ifc_main_peripheral_out.reset; // TODO: software control, dependency chain

    clk_lmk0482x_ctrl #(
        .MMI_DATALEN ( MMI_DATALEN  ),
        .SPI_SS_BIT  ( 0      ),
        .INIT_HEARTBEAT_TOGGLE ( 1 ),
        .HEARTBEAT_HALF_PERIOD ( clk_ifc_main_out.get_int_frequency() / 4 ) // blink twice a second
    ) clk_lmk0482x_ctrl_inst (
        .sdr ( lmk_ctrl              ),
        .lmk ( lmk               ),
        .mmi ( mmi_lmkclk_ifc.Slave),
        .spi ( lmk_spi_drv_ifc[0] )
    );
    assign lmk.syncreq = 1'b0;  // For MPCU,we configure LMK to ignore this.

    spi_mux #(
        .N      ( 1 ),
        .MAXLEN ( 32 )
    ) lmk_spi_mux (
        .spi_in ( lmk_spi_drv_ifc        ),
        .spi_io ( lmk_spi_io             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Free-running counters


    /*
     * clk_ifc_main_out is 156.25 MHz. We cannot generate an exact 1 microsecond clock from that.
     * Instead, we generate the "main" microsecond counter and pulse train using clk_ifc_1g_enet_out,
     * which is 125 MHz, and then cross-clock the pulse train and count values to clk_ifc_main_out.
     * This means the counter on our "main" clock domain will lag the one on our "1g_enet" domain
     * by a couple of clock cycles. The error is only a few percent, and the clock will be the correct
     * frequency on average.
     *
     * Note that we cross-clock the count, rather than using the crossed pulse train, because that
     * ensures that the values line up better. Otherwise, the "main" count would probably lag the "1g_enet"
     * count by one microsecond count.
     */


     // Generate 1 us counter and pulse train on clk_ifc_1g_enet_out.
    util_stopwatch #(
        .CLOCK_SOURCE   ( clk_ifc_1g_enet_out.get_int_frequency() / 1000000 ),
        .COUNT_WIDTH    ( 64 ),
        .AUTO_START     ( 1 )
    ) free_us_counter_1g_enet_inst (
        .clk                ( clk_ifc_1g_enet_out.clk ),
        .rst                ( sreset_ifc_1g_enet_interconnect_out.reset ),
        .start_stb          ( 1'b0 ),
        .reset_stb          ( 1'b0 ),
        .stop_stb           ( 1'b0 ),
        .count              ( us_count_on_clk_1g_enet ),
        .overflow           ( ),
        .latched_count      ( ),
        .latched_overflow   ( ),
        .ext_event          ( 1'b0 ),
        .count_pulse_out    ( us_pulse_on_clk_1g_enet )
    );

    // Cross-clock the count and pulse train.
    /*
     * Because we tie out_ready to 1, out_data will only be high for one cycle; ie. it will be a pulse.
     * We are not supposed to send a new input until we see in_complete. However, we are making the
     * assumption that the time between pulses is much greater than the cross-clock handshake time.
     * (The time between pulses should be >= 100 input clock cycles; the cross-clock time should be
     * a few clock cycles.)
     */
    xclock_handshake #(
        .DATA_WIDTH     ( 64 ),
        .LATCH_INPUT    ( 0 ),  // not necessary, since it's already latched
        .LATCH_OUTPUT   ( 1 ),  // hold the output until the next value
        .INITIAL_VALUE  ( '0 )
    ) free_us_counter_main_inst (
        .in_clk             ( clk_ifc_1g_enet_out.clk ),
        .in_resetn          ( sresetn_ifc_1g_enet_interconnect_out.reset ),
        .in_start           ( us_pulse_on_clk_1g_enet ),
        .in_data            ( us_count_on_clk_1g_enet ),
        .in_complete        ( ),
        .out_clk            ( clk_ifc_main_out.clk ),
        .out_resetn         ( sresetn_ifc_main_interconnect_out.reset ),
        .out_data_enable    ( us_pulse_on_clk_main ),
        .out_data           ( us_count_on_clk_main ),
        .out_ready          ( 1'b1 )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Peripherals


    // In -1LV, the max SEM clock is 125 MHz, which is the same as our clk_ifc_1g_enet_out.
    `ELAB_CHECK_LE(clk_ifc_1g_enet_out.get_int_frequency(), 125000000);

    sem_ultrascale_avmm #(
        .MODULE_ID          ( AVMM_SEM+1 )
    ) sem_ultrascale_avmm_inst (
        .avmm_clk_ifc       ( clk_ifc_main_out                  ),
        .icap_clk_ifc       ( clk_ifc_1g_enet_out               ),
        .avmm_sreset_ifc    ( sreset_ifc_main_interconnect_out  ),
        .avmm_in            ( avmm_dev_ifc[AVMM_SEM]            )
    );


    avmm_to_avmm #(
        .MODULE_VERSION ( 1                ),
        .MODULE_ID      ( AVMM_PS_MASTER+1 ),
        .DEBUG_ILA      ( 0                )
    ) avmm_to_avmm_ps_master_inst (
        .clk_ifc                 ( clk_ifc_main_out                                    ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out                    ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_PS_MASTER]                        ),
        .avmm_out                ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Master )
    );

    assign avmm_init_ctrl_ps_master_init_values_ifc.init_regs = '{
        '{49'hFFCA3008, 32'h0000, '1, '0 } // Set pcap_pr field to ICAP/MCAP for SEM
    };

    avmm_init_ctrl #(
        .ILA_DEBUG ( 0 )
    ) avmm_init_ctrl_ps_master_inst (
        .clk_ifc                 ( clk_ifc_main_out                                   ),
        .interconnect_sreset_ifc ( sreset_ifc_main_interconnect_out                   ),
        .avmm_upstream           ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Slave ),
        .avmm_downstream         ( avmm_init_ctrl_to_ps_master_ifc.Master             ),
        .avmm_init_ctrl_ifc      ( avmm_init_ctrl_ps_master_init_values_ifc           ),
        .pre_req                 ( 1'b1                                               ),
        .initdone                (                                                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MSU/SSDs


    // TODO: Provide register control of gth_sata_refclk_oe. This should be part of a proper
    // transceiver power-up/power-down sequence.
    assign gth_sata_refclk_oe = 1'b1;   // For now, always enable.


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq


    board_mpcut1_zynq_wrapper #(
        .AXIS_BLADE_ETH_FIFO_ADDR_WIDTH ( $clog2(MAX_PKTSIZE) + 2   ),
        .DEBUG_ILA                      ( 0                         ),
        .DEBUG_BLADE_ETH_ILA            ( 0                         )
    ) zynq_inst (
        .clk_ifc_main_out           ( clk_ifc_main_out          ),
        .clk_ifc_1g_enet_out        ( clk_ifc_1g_enet_out       ),
        .clk_ifc_50_out             ( clk_ifc_50_out            ),
        .clk_ifc_elmer_refclk       ( clk_ifc_elmer_refclk   ),
        .clk_ifc_blade_ext_spi_out  ( clk_ifc_blade_ext_spi_out ),

        .aresetn_ifc_external_in                   ( aresetn_ifc_external_in                   ),
        .sreset_ifc_main_peripheral_out            ( sreset_ifc_main_peripheral_out            ),
        .sreset_ifc_main_interconnect_out          ( sreset_ifc_main_interconnect_out          ),
        .sresetn_ifc_main_peripheral_out           ( sresetn_ifc_main_peripheral_out           ),
        .sresetn_ifc_main_interconnect_out         ( sresetn_ifc_main_interconnect_out         ),
        .sreset_ifc_1g_enet_peripheral_out         ( sreset_ifc_1g_enet_peripheral_out         ),
        .sreset_ifc_1g_enet_interconnect_out       ( sreset_ifc_1g_enet_interconnect_out       ),
        .sresetn_ifc_1g_enet_peripheral_out        ( sresetn_ifc_1g_enet_peripheral_out        ),
        .sresetn_ifc_1g_enet_interconnect_out      ( sresetn_ifc_1g_enet_interconnect_out      ),
        .sreset_ifc_elmer_refclk_peripheral_out    ( sreset_ifc_elmer_refclk_peripheral_out    ),
        .sreset_ifc_elmer_refclk_interconnect_out  ( sreset_ifc_elmer_refclk_interconnect_out  ),
        .sresetn_ifc_elmer_refclk_peripheral_out   ( sresetn_ifc_elmer_refclk_peripheral_out   ),
        .sresetn_ifc_elmer_refclk_interconnect_out ( sresetn_ifc_elmer_refclk_interconnect_out ),
        .sreset_ifc_50_peripheral_out              ( sreset_ifc_50_peripheral_out              ),
        .sreset_ifc_50_interconnect_out            ( sreset_ifc_50_interconnect_out            ),
        .sresetn_ifc_50_peripheral_out             ( sresetn_ifc_50_peripheral_out             ),
        .sresetn_ifc_50_interconnect_out           ( sresetn_ifc_50_interconnect_out           ),

        .hpio66_sgmii_refclk_n ( hpio66_sgmii_refclk_n ),
        .hpio66_sgmii_refclk_p ( hpio66_sgmii_refclk_p ),

        .umbilical_dummy_port ( umbilical_dummy_port ),
        .umbilical_sgmii_rx_n ( umbilical_sgmii_rx_n ),
        .umbilical_sgmii_rx_p ( umbilical_sgmii_rx_p ),
        .umbilical_sgmii_tx_n ( umbilical_sgmii_tx_n ),
        .umbilical_sgmii_tx_p ( umbilical_sgmii_tx_p ),

        .oisl_dummy_port      ( oisl_dummy_port      ),

        .oisl_tmtc_sgmii_rx_n ( {oisl_tmtc_sgmii[1].rx_n, oisl_tmtc_sgmii[0].rx_n} ),
        .oisl_tmtc_sgmii_rx_p ( {oisl_tmtc_sgmii[1].rx_p, oisl_tmtc_sgmii[0].rx_p} ),
        .oisl_tmtc_sgmii_tx_n ( {oisl_tmtc_sgmii[1].tx_n, oisl_tmtc_sgmii[0].tx_n} ),
        .oisl_tmtc_sgmii_tx_p ( {oisl_tmtc_sgmii[1].tx_p, oisl_tmtc_sgmii[0].tx_p} ),
        .oisl_prog_sgmii_rx_n ( {oisl_prog_sgmii[1].rx_n, oisl_prog_sgmii[0].rx_n} ),
        .oisl_prog_sgmii_rx_p ( {oisl_prog_sgmii[1].rx_p, oisl_prog_sgmii[0].rx_p} ),
        .oisl_prog_sgmii_tx_n ( {oisl_prog_sgmii[1].tx_n, oisl_prog_sgmii[0].tx_n} ),
        .oisl_prog_sgmii_tx_p ( {oisl_prog_sgmii[1].tx_p, oisl_prog_sgmii[0].tx_p} ),


        .oisl_data_refclk_n        ({blade_xcvrs.refclk_n[B128_MGTREFCLK0], blade_xcvrs.refclk_n[B230_MGTREFCLK0]}),
        .oisl_data_refclk_p        ({blade_xcvrs.refclk_p[B128_MGTREFCLK0], blade_xcvrs.refclk_p[B230_MGTREFCLK0]}),
        .oisl_data_rx_p            ({{oisl_data_xfi[1].rx_p}, {oisl_data_xfi[0].rx_p}}),
        .oisl_data_rx_n            ({{oisl_data_xfi[1].rx_n}, {oisl_data_xfi[0].rx_n}}),
        .oisl_data_tx_p            ({{oisl_data_xfi[1].tx_p}, {oisl_data_xfi[0].tx_p}}),
        .oisl_data_tx_n            ({{oisl_data_xfi[1].tx_n}, {oisl_data_xfi[0].tx_n}}),

        .blade_eth_tx ( blade_eth_sink ), // packets to send to the PS
        .blade_eth_rx ( blade_eth_src  ), // packets received from the PS

        .msp_uart_soc_tx ( msp_uart_soc_tx ),
        .msp_uart_soc_rx ( msp_uart_soc_rx ),

        .ecg_uart_tx      ( ecg_uart_soc_tx ),
        .ecg_uart_rx      ( ecg_uart_soc_rx ),

        .aocs_uart_soc_tx ( aocs_uart_soc_tx ),
        .aocs_uart_soc_rx ( aocs_uart_soc_rx ),
        .aocs_i2c_scl_i   ( aocs_i2c_scl_i   ),
        .aocs_i2c_scl_o   ( aocs_i2c_scl_o   ),
        .aocs_i2c_scl_t   ( aocs_i2c_scl_t   ),
        .aocs_i2c_sda_i   ( aocs_i2c_sda_i   ),
        .aocs_i2c_sda_o   ( aocs_i2c_sda_o   ),
        .aocs_i2c_sda_t   ( aocs_i2c_sda_t   ),

        .aocs_ctrl_gpio_i ( aocs_ctrl_gpio_i ),
        .aocs_ctrl_gpio_o ( aocs_ctrl_gpio_o ),
        .aocs_ctrl_gpio_t ( aocs_ctrl_gpio_t ),

        .aocs_pmbus_i2c_scl_i ( aocs_pmbus_i2c_scl_i ),
        .aocs_pmbus_i2c_scl_o ( aocs_pmbus_i2c_scl_o ),
        .aocs_pmbus_i2c_scl_t ( aocs_pmbus_i2c_scl_t ),
        .aocs_pmbus_i2c_sda_i ( aocs_pmbus_i2c_sda_i ),
        .aocs_pmbus_i2c_sda_o ( aocs_pmbus_i2c_sda_o ),
        .aocs_pmbus_i2c_sda_t ( aocs_pmbus_i2c_sda_t ),

        .bg_pmbus_i2c_scl_i ( bg_pmbus_i2c_scl_i ),
        .bg_pmbus_i2c_scl_o ( bg_pmbus_i2c_scl_o ),
        .bg_pmbus_i2c_scl_t ( bg_pmbus_i2c_scl_t ),
        .bg_pmbus_i2c_sda_i ( bg_pmbus_i2c_sda_i ),
        .bg_pmbus_i2c_sda_o ( bg_pmbus_i2c_sda_o ),
        .bg_pmbus_i2c_sda_t ( bg_pmbus_i2c_sda_t ),

        .mpcu_pmbus_i2c_scl_i ( mpcu_pmbus_i2c_scl_i ),
        .mpcu_pmbus_i2c_scl_o ( mpcu_pmbus_i2c_scl_o ),
        .mpcu_pmbus_i2c_scl_t ( mpcu_pmbus_i2c_scl_t ),
        .mpcu_pmbus_i2c_sda_i ( mpcu_pmbus_i2c_sda_i ),
        .mpcu_pmbus_i2c_sda_o ( mpcu_pmbus_i2c_sda_o ),
        .mpcu_pmbus_i2c_sda_t ( mpcu_pmbus_i2c_sda_t ),

        .elmer_pmbus_i2c_scl_i ( elmer_pmbus_i2c_scl_i ),
        .elmer_pmbus_i2c_scl_o ( elmer_pmbus_i2c_scl_o ),
        .elmer_pmbus_i2c_scl_t ( elmer_pmbus_i2c_scl_t ),
        .elmer_pmbus_i2c_sda_i ( elmer_pmbus_i2c_sda_i ),
        .elmer_pmbus_i2c_sda_o ( elmer_pmbus_i2c_sda_o ),
        .elmer_pmbus_i2c_sda_t ( elmer_pmbus_i2c_sda_t ),

        .elmer_ctrl_gpio_i ( elmer_ctrl_gpio_i ),
        .elmer_ctrl_gpio_o ( elmer_ctrl_gpio_o ),
        .elmer_ctrl_gpio_t ( elmer_ctrl_gpio_t ),
        .blade_ctrl_gpio_i ( blade_ctrl_gpio_i ),
        .blade_ctrl_gpio_o ( blade_ctrl_gpio_o ),
        .blade_ctrl_gpio_t ( blade_ctrl_gpio_t ),

        .blade_spi_ios_i ( blade_spi_ios_i ),
        .blade_spi_ios_o ( blade_spi_ios_o ),
        .blade_spi_ios_t ( blade_spi_ios_t ),

        .oisl_aqr_phy_mdio_spi_ios_i ( oisl_aqr_phy_mdio_spi_ios_i ),
        .oisl_aqr_phy_mdio_spi_ios_o ( oisl_aqr_phy_mdio_spi_ios_o ),
        .oisl_aqr_phy_mdio_spi_ios_t ( oisl_aqr_phy_mdio_spi_ios_t ),

        .emio_gpio_i        ( emio_gpio_i ),
        .emio_gpio_o        ( emio_gpio_o ),
        .emio_gpio_t        ( emio_gpio_t ),

        .avmm_lpd_m ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_ZYNQ] ),

        .savmm_wrapper_in ( avmm_init_ctrl_to_ps_master_ifc.Slave ),

        .spacewire_axis_rx                     (spacewire_axis_rx),
        .spacewire_axis_tx                     (spacewire_axis_tx),
        .spacewire_interrupt                   (spacewire_interrupt),
        .spacewire_axis_tx_aresetn             (spacewire_axis_tx_aresetn),
        .spacewire_axis_rx_aresetn             (spacewire_axis_rx_aresetn),
        .spacewire_srst_ifc                    (spacewire_srst_ifc),
        .spacewire_srstn_ifc                   (spacewire_srstn_ifc),
        .spacewire_mmcm_locked                 (spacewire_mmcm_locked),
        .spacewire_clk_ifc                     (spacewire_clk_ifc),
        .spacewire_clk_b_ifc                   (spacewire_clk_b_ifc),
        .ecg_refclk_p                          (blade_xcvrs.refclk_p[B228_MGTREFCLK0]),
        .ecg_refclk_n                          (blade_xcvrs.refclk_n[B228_MGTREFCLK0]),
        .gt_refclk_b128_out                    (gth228_ref_clk_ifc[0].clk ),

        .ecg_rx_p            (ecg_xfi.rx_p),
        .ecg_rx_n            (ecg_xfi.rx_n),
        .ecg_tx_p            (ecg_xfi.tx_p),
        .ecg_tx_n            (ecg_xfi.tx_n)

    );



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq Peripherals


    // Although the controller provides tristate control, we know which direction most of these should be.
    // For those, we only connect the pins in the "correct" direction and ignore the _t outputs.

    // inputs
    assign aocs_ctrl_gpio_i[4:0]     = aocs_rw_rst_n;
    assign aocs_ctrl_gpio_i[6:5]     = aocs_ctrl_gpio_o[6:5];    // output read-back
    assign aocs_ctrl_gpio_i[7]       = '0;
    assign aocs_ctrl_gpio_i[12:8]    = aocs_ctrl_gpio_o[12:8];   // output read-back
    assign aocs_ctrl_gpio_i[14:13]   = '0;
    assign aocs_ctrl_gpio_i[15]      = aocs_ctrl_gpio_o[15];     // output read-back
    assign aocs_ctrl_gpio_i[20:16]   = aocs_rw_fault_n;
    assign aocs_ctrl_gpio_i[22:21]   = '0;
    assign aocs_ctrl_gpio_i[23]      = fake_pps;
    assign aocs_ctrl_gpio_i[27:24]   = '0;
    assign aocs_ctrl_gpio_i[28]      = ttc_tx_inhib_n;
    assign aocs_ctrl_gpio_i[29]      = umb_prsnt_n;
    assign aocs_ctrl_gpio_i[30]      = gps_pv;
    assign aocs_ctrl_gpio_i[31]      = gps_pps_in;

    assign elmer_ctrl_gpio_i[2:0]    = elmer_ctrl_gpio_o[2:0];   // output read-back
    assign elmer_ctrl_gpio_i[7:3]    = '0;
    assign elmer_ctrl_gpio_i[9:8]    = elmer_ctrl_gpio_o[9:8];   // output read-back
    assign elmer_ctrl_gpio_i[31:10]  = '0;
    assign elmer_ctrl_gpio_i[34:32]  = blade_pmbus_alert_n[2:0];
    assign elmer_ctrl_gpio_i[35]     = mpcu_pmbus_alert_n;
    assign elmer_ctrl_gpio_i[36]     = mpcu_pmbus_ctrl;
    assign elmer_ctrl_gpio_i[37]     = elmer_ctrl_gpio_o[37];    // output read-back
    assign elmer_ctrl_gpio_i[38]     = elmer_seq_rst_n;
    assign elmer_ctrl_gpio_i[39]     = aocs_pmbus_alert_n;
    assign elmer_ctrl_gpio_i[40]     = aocs_pmbus_ctrl;
    assign elmer_ctrl_gpio_i[41]     = elmer_pmbus_alert_n;
    assign elmer_ctrl_gpio_i[44:42]  = '0;
    assign elmer_ctrl_gpio_i[45]     = elmer_ctrl_gpio_o[45];    // output read-back
    assign elmer_ctrl_gpio_i[46]     = sky_msp_test;
    assign elmer_ctrl_gpio_i[47]     = sky_msp_trst_n;
    assign elmer_ctrl_gpio_i[48]     = aocs_msp_test;
    assign elmer_ctrl_gpio_i[49]     = aocs_msp_trst_n;
    assign elmer_ctrl_gpio_i[54:50]  = '0;
    assign elmer_ctrl_gpio_i[55]     = fake_pps;
    assign elmer_ctrl_gpio_i[57:56]  = '0;
    assign elmer_ctrl_gpio_i[58]     = gps_pps_in;
    assign elmer_ctrl_gpio_i[59]     = hdrm_inhib_n;
    assign elmer_ctrl_gpio_i[60]     = ttc_tx_inhib_n;
    assign elmer_ctrl_gpio_i[61]     = umb_prsnt_n;
    assign elmer_ctrl_gpio_i[62]     = gps_pv;
    assign elmer_ctrl_gpio_i[63]     = gps_pps_in;


    // HP (ECG) GPIOs

    generate
        for (genvar i = 0; i < 4; i++) begin
            assign emio_gpio_i[0+i*8]            = emio_gpio_o[i];        // output read-back (ECG RST_n)
            assign emio_gpio_i[1+i*8]            = ecg_int[i];            // output read-back (ECG INT)
            assign emio_gpio_i[2+i*8]            = ecg_gpx[i];            // output read-back (ECG GPX)
            assign emio_gpio_i[(i+1)*8-1-:4]     = '0;
            assign ecg_rst_n[i]                  = emio_gpio_o[0+i*8];    // ECG 0 RST_n
        end
    endgenerate

    assign emio_gpio_i[95:32]        = '0;


    // bi-directional (output part here; input part above)
    assign mpcu_pmbus_ctrl = elmer_ctrl_gpio_t[36] ? 1'bZ : elmer_ctrl_gpio_o[36];
    assign aocs_pmbus_ctrl = elmer_ctrl_gpio_t[40] ? 1'bZ : elmer_ctrl_gpio_o[40];

    // open-drain outputs (drive Z or 0)
    assign elmer_seq_rst_n = (elmer_ctrl_gpio_t[38] | elmer_ctrl_gpio_o[38]) ? 1'bZ : 1'b0;



    // outputs

    generate
        for (genvar i = 0; i < 5; i++) begin: gen_aocs_rw_rst_io
            assign aocs_rw_rst_n[5-i] = aocs_ctrl_gpio_t[i] ? 1'bZ : aocs_ctrl_gpio_o[i];
        end
    endgenerate
    assign aocs_spacewire_en         = aocs_ctrl_gpio_o[6:5];
    assign aocs_uart_dr_upper[8:6]   = aocs_ctrl_gpio_o[10:8];
    assign aocs_uart_dr_lower[3:2]   = aocs_ctrl_gpio_o[12:11];
    assign aocs_gps_rst_n            = aocs_ctrl_gpio_o[15];

    assign blade_spi_mux_ctrl_a[2:0] = elmer_ctrl_gpio_o[2:0];
    assign blade_spi_mux_bg01_en_n   = elmer_ctrl_gpio_o[8];
    assign blade_spi_mux_bg2_en_n    = elmer_ctrl_gpio_o[9];
    assign mpcu_pmbus_level_shift_en = elmer_ctrl_gpio_o[37];
    assign sky_en                    = elmer_ctrl_gpio_o[45];

    /**
     * AOCS_MSP_TEST/TRST_n and SKY_MSP_TEST/TRST_n pins need special care.
     * These pins can be driven from either the MPCU or an external MSP, and have external pull
     * resistors. To avoid multiple drivers, TEST should only be driven 1 and RST_n should only
     * be driven 0.
     */
    assign sky_msp_test    = (~elmer_ctrl_gpio_t[46] &  elmer_ctrl_gpio_o[46]) ? 1'b1 : 1'bZ;  // drive strong 1, else Z
    assign sky_msp_trst_n  = (~elmer_ctrl_gpio_t[47] & ~elmer_ctrl_gpio_o[47]) ? 1'b0 : 1'bZ;  // drive strong 0, else Z
    assign aocs_msp_test   = (~elmer_ctrl_gpio_t[48] &  elmer_ctrl_gpio_o[48]) ? 1'b1 : 1'bZ;  // drive strong 1, else 0
    assign aocs_msp_trst_n = (~elmer_ctrl_gpio_t[49] & ~elmer_ctrl_gpio_o[49]) ? 1'b0 : 1'bZ;  // drive strong 0, else Z


    // Blade GPIOs
    generate
        for (genvar bg = 0; bg < 3; bg++) begin: gen_blade_gpios_bg
            for (genvar blade = 0; blade < 4; blade++) begin: gen_blade
                for (genvar lane = 0; lane < 2; lane++) begin: gen_lane
                    for (genvar polarity = 0; polarity < 2; polarity++) begin: gen_pn
                        assign blade_gpio[bg][blade][lane][polarity].out = blade_ctrl_gpio_o[bg*16 + blade*4 + lane*2 + polarity];
                        assign blade_gpio[bg][blade][lane][polarity].oe  = ~blade_ctrl_gpio_t[bg*16 + blade*4 + lane*2 + polarity];
                        assign blade_ctrl_gpio_i[bg*16 + blade*4 + lane*2 + polarity] = blade_gpio[bg][blade][lane][polarity].in;
                    end
                end
                // the single-ended "spare" GPIOs start at bit 48
                assign blade_spare_gpio[bg][blade].out = blade_ctrl_gpio_o[bg*4 + blade + 48];
                assign blade_spare_gpio[bg][blade].oe  = ~blade_ctrl_gpio_t[bg*4 + blade + 48];
                assign blade_ctrl_gpio_i[bg*4 + blade + 48] = blade_spare_gpio[bg][blade].in;
            end
        end
    endgenerate


    // Blade SPI controllers
    generate
        for (genvar i = 0; i < 2; i++) begin: gen_blade_spi
            assign blade_spi_ss_n_0[i] = blade_spi_ios_t[i][3] ? 1'bZ : blade_spi_ios_o[i][3]; // 3 = SS_n[0]

            assign blade_spi_ss_n_1[i] = blade_spi_ios_t[i][4] ? 1'bZ : blade_spi_ios_o[i][4]; // 4 = SS_n[1]
            assign blade_spi_clk[i]    = blade_spi_ios_t[i][0] ? 1'bZ : blade_spi_ios_o[i][0]; // 0 = CLK
            assign blade_spi_miso[i]   = blade_spi_ios_t[i][2] ? 1'bZ : blade_spi_ios_o[i][2]; // 2 = MISO
            assign blade_spi_mosi[i]   = blade_spi_ios_t[i][1] ? 1'bZ : blade_spi_ios_o[i][1]; // 1 = MOSI

            assign blade_spi_ios_i[i][0] = blade_spi_clk[i];    // 0 = CLK
            assign blade_spi_ios_i[i][1] = blade_spi_mosi[i];   // 1 = MOSI
            assign blade_spi_ios_i[i][2] = blade_spi_miso[i];   // 2 = MISO
            assign blade_spi_ios_i[i][3] = blade_spi_ss_n_0[i]; // 3 = SS_n[0]
            assign blade_spi_ios_i[i][4] = blade_spi_ss_n_1[i]; // 4 = SS_n[1]
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MPCU - HDR PCU-PCU Link


    generate
        if ((HDR_SLOT_INDEXES[0] != BG_SLOT_NONE) ) begin: gen_hdr_ppl

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_ctrl_ifc_bg0, avmm_dev_ifc[AVMM_PPL_CTRL_BG0], 1, AVMM_PPL_CTRL_BG0+1, 16+20, clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, ENABLE_PPL );
            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_prbs_ifc_bg0, avmm_dev_ifc[AVMM_PPL_PRBS_BG0], 1, AVMM_PPL_PRBS_BG0+1, 16+24, clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, ENABLE_PPL );
            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_ctrl_ifc_bg0, avmm_dev_ifc[AVMM_PPL_AUR_CTRL_BG0], 1, AVMM_PPL_AUR_CTRL_BG0+1, 16+20, clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, ENABLE_PPL );
            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_drp_ifc_bg0, avmm_dev_ifc[AVMM_PPL_AUR_DRP_BG0], 1, AVMM_PPL_AUR_DRP_BG0+1, 16+64, clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, ENABLE_PPL );

            assign ppl_aur_ctrl_bg0.sresetn = sresetn_ifc_main_peripheral_out.reset; // TODO: Move to allow software to control over AVMM


            for (genvar i = 0; i < 1; i++) begin : gen_hdr_ifc_assign
                assign hdr_aurora_axis_clk[i]   = hdr_aur_phys[i].user_clk;
                assign hdr_aurora_axis_rst_n[i] = hdr_aur_phys[i].sresetn_user_clk;

                axis_connect bg0_rx_inst (
                    .axis_in  (blade_eth_src[BLADE_ETH_IDX_PSPLETH0_BRIDGE_SRC+i]),
                    .axis_out (hdrs_virtual_eth_src[i]                           )
                );

                axis_connect bg0_tx_inst (
                    .axis_in  (hdrs_virtual_eth_sink[i]                            ),
                    .axis_out (blade_eth_sink[BLADE_ETH_IDX_PSPLETH0_BRIDGE_SINK+i])
                );
            end

            ethernet_ppl_fifo #(
                .ENABLE_PPL   (ENABLE_PPL ),
                .MAX_PKTSIZE  (MAX_PKTSIZE),
                .DEBUG_ILA    (1'b0       ),
                .NUM_CHANNELS (1          ),
                .NUM_QUADS    (1          ),
                .NUM_STREAMS  (1          )
            ) ethernet_ppl_fifo_bg0 (
                .clk_eth_ifc     (clk_ifc_1g_enet_out               ),
                .sresetn_eth_ifc (sresetn_ifc_1g_enet_peripheral_out),
                .eth_sink        (hdrs_virtual_eth_src[0:0]         ),
                .eth_src         (hdrs_virtual_eth_sink[0:0]        ),
                .ppl_axis_tx     (ppl_axis_tx_bg0[0:0]              ),
                .ppl_axis_rx     (ppl_axis_rx_bg0[0:0]              )
            );

            // temporarily loopback PSPL ethernet bridge in BD since we have only one HDR supported
            axis_connect connect_rx_data_inst (
                .axis_in  ( hdrs_virtual_eth_src[1]  ),
                .axis_out ( hdrs_virtual_eth_sink[1] )
            );

            board_mpcut1_ppl_quad #(
                .ENABLE_PRBS             (1'b1     ),
                .SYSCLK_FREQ             (156250000),
                .AUR_RX_FRAME_FIFO_DEPTH (128      ), // number of 64-bit words
                .DEBUG_AUR_ILA_MASK      (1'b0     ),
                .DEBUG_PRBS_ILA          (1'b0     ),
                .DEBUG_DATA_ILA          (1'b0     ),
                .NUM_QUADS               (1        ),
                .NUM_CHANNELS            (1        ),
                .NUM_LANES               (1        )
            ) board_mpcu_hdr_ppl_inst (
                .aur_sdr_ctrl     (ppl_aur_ctrl_bg0          ),
                .phy_drp          (hdr_aur_drp[0:0]          ),
                .phy_ctrl         (hdr_aur_phys[0:0]         ),
                .phy_axis_rx      ( hdr_aur_axis_rx[1:1]    ), // SRG
                .phy_axis_tx      ( hdr_aur_axis_tx[1:1]     ),
                .phy_gt_debug     (hdr_aur_gt_debug[0:0]     ),
                .us_counter       (us_count_on_clk_main[47:0]),
                .axis_ins         (ppl_axis_tx_bg0[0:0]      ),
                .axis_outs        (ppl_axis_rx_bg0[0:0]      ),
                .mmi_ppl_ctrl     (mmi_ppl_ctrl_ifc_bg0      ),
                .mmi_ppl_aur_ctrl (mmi_ppl_aur_ctrl_ifc_bg0  ),
                .mmi_ppl_aur_drp  (mmi_ppl_aur_drp_ifc_bg0   ),
                .mmi_ppl_prbs     (mmi_ppl_prbs_ifc_bg0      )
            );

            xcvr_quad #(
                .AURORA_LINE_RATE    (10e9                ),
                .TOTAL_MAX_LANES     (1                   ),
                .AURORA_NUM_CHANNELS (1                   ),
                .AURORA_MAX_LANES    (1                   ),
                .AURORA_NUM_LANES    ('{default:1}        ),
                .AURORA_TYPES        ('{default:"ppl_10g"}),
                .AURORA_XCVR_INDEXES (AURORA_XCVR_INDEXES )
            ) xcvr_quad0_bg0 (
                .gt_ref_clk_ifc           (gth228_ref_clk_ifc      ),
                .aurora_qpll_ref_clk_addr (1'b0                    ),
                .init_clk_ifc             (clk_ifc_main_out        ),
                .xcvrs                    (hdr_xcvrs0              ),
                .aurora_gt_debug          (hdr_aur_gt_debug[0:0]   ),
                .aurora_drp               (hdr_aur_drp[0:0]        ),
                .aurora_phys              (hdr_aur_phys[0:0]       ),
                .aurora_axis_tx           (hdr_aur_axis_tx[0:0]    ),
                .aurora_axis_rx           (hdr_aur_axis_rx[0:0]    )
            );

            assign hdr_aurora[0].tx_p[0] = hdr_xcvrs0.tx_p[0];
            assign hdr_aurora[0].tx_n[0] = hdr_xcvrs0.tx_n[0];
            assign hdr_xcvrs0.rx_p[0]    = hdr_aurora[0].rx_p[0];
            assign hdr_xcvrs0.rx_n[0]    = hdr_aurora[0].rx_n[0];


        end
    endgenerate


    // SPI for OISL AQR PHY MDIO
    // The Linux driver for the AXI QSPI peripheral does not support 3-wire mode. So, we have to
    // create it ourselves by tying MOSI and MISO together and treating them as open-drain. This
    // requires an external pull-up on the line.

    // Drive MDC as the peripheral requests. We expect it to drive push-pull during transfers.

    assign oisl_aqr_phy_mdio.MDC          = oisl_aqr_phy_mdio_spi_ios_t [0] ? 1'bZ : oisl_aqr_phy_mdio_spi_ios_o [0];
    assign oisl_aqr_phy_mdio_spi_ios_i[0] = oisl_aqr_phy_mdio.MDC;         // 0 = MDC

    // Drive MDIO=0 low when MOSI==0; set MDIO=Z when MOSI==1.
    assign oisl_aqr_phy_mdio.MDIO         = oisl_aqr_phy_mdio_spi_ios_o[1]  ? 1'bZ : 1'b0; // 1 = MDIO

    // Provide MISO readback on both io0_i and io1_i.
    assign oisl_aqr_phy_mdio_spi_ios_i[1] = oisl_aqr_phy_mdio.MDIO; // 1 = 4-wire MOSI
    assign oisl_aqr_phy_mdio_spi_ios_i[2] = oisl_aqr_phy_mdio.MDIO; // 2 = 4-wire MISO


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Fake PPS


    clkdiv_asym #(
        .PERIOD    (clk_ifc_elmer_refclk.get_int_frequency()                               ),
        .HIGH_TIME (UTIL_INTS::U_INT_CEIL_DIV(clk_ifc_elmer_refclk.get_int_frequency(), 10))
    ) fake_pps_inst (
        .clk_in  (clk_ifc_elmer_refclk.clk                ),
        .sreset  (sreset_ifc_elmer_refclk_peripheral_out.reset),
        .clk_out (fake_pps                                   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SATA


    SDR_Ctrl_int #( .STATELEN (1) ) ssd_ctrl               ( .clk( clk_ifc_main_out.clk ) );
    SDR_Ctrl_int #( .STATELEN (1) ) ssd_ctrl_slaves [3:0]  ( .clk( clk_ifc_main_out.clk ) );

    logic us_pulse;

    assign ssd_ctrl.sresetn = sresetn_ifc_main_interconnect_out.reset;

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
        mmi_sata_init_ctrl_ifc,
        avmm_dev_ifc[AVMM_SATA_INIT_CTRL],
        1,
        AVMM_SATA_INIT_CTRL+1,
        23-16,
        clk_ifc_main_out,
        sreset_ifc_main_interconnect_out,
        sreset_ifc_main_peripheral_out.reset,
        1
    );

    // In PCH this module controls the SSD enable lines and reads initdone
    // Here, SSD enables are controlled with Linux so this module is only for reading initdone
    sata_init_ctrl_mmi #(
        .N_SATA                ( 4                        ),
        .DEFAULT_ENABLES_VAL   ( {4{ENABLE_MSU_SATA}}     ),
        .CLK_FREQ              ( 156250000                ),
        .RETRY_TIMEOUT_SECONDS ( 2                        ),
        .RESET_PULSE_CYCLES    ( 10                       )
    ) sata_init_ctrl_mmi_inst  (
        .board_sresetn    ( sresetn_ifc_main_interconnect_out.reset ),
        .ssd_present_n    ( '0                                      ), // Assume all SSDs are present
        .sata_ctrl_master ( ssd_ctrl.Slave                          ),
        .sata_ctrl_slaves ( ssd_ctrl_slaves                         ),
        .sata_enables     (                                         ), // driven by PMBus
        .mmi              ( mmi_sata_init_ctrl_ifc                  )
    );

    generate
        if (ENABLE_MSU_SATA) begin: gen_enable_msu_sata
            for (genvar i = 0; i < 4; i++) begin : gen_sata_channel
                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                    mmi_sata_ctrl_ifc,
                    avmm_dev_ifc[AVMM_SATA0_CTRL+i],
                    1,
                    AVMM_SATA0_CTRL+i+1,
                    48-16,
                    clk_ifc_main_out,
                    sreset_ifc_main_interconnect_out,
                    sreset_ifc_main_peripheral_out.reset,
                    ENABLE_MSU_SATA
                );

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                    mmi_sata_drp_ifc,
                    avmm_dev_ifc[AVMM_SATA0_DRP+i],
                    1,
                    AVMM_SATA0_DRP+i+1,
                    22-16,
                    clk_ifc_main_out,
                    sreset_ifc_main_interconnect_out,
                    sreset_ifc_main_peripheral_out.reset,
                    ENABLE_MSU_SATA
                );

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                    mmi_sata_perf_ifc,
                    avmm_dev_ifc[AVMM_SATA0_PERF+i],
                    1,
                    AVMM_SATA0_PERF+i+1,
                    22-16,
                    clk_ifc_main_out,
                    sreset_ifc_main_interconnect_out,
                    sreset_ifc_main_peripheral_out.reset,
                    ENABLE_MSU_SATA
                );

                // TODO: (cbrown) conditionally include this based on a parameter.
                // The traffic generator (specifically PRBS) has difficulty meeting timing at 156.25 MHz.
                //
                // `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                //     mmi_sata_block_traffic_ifc,
                //     avmm_dev_ifc[AVMM_SATA_BLOCK_TRAFFIC_GEN+i],
                //     1,
                //     AVMM_SATA_BLOCK_TRAFFIC_GEN+i+1,
                //     39-16,
                //     clk_ifc_main_out,
                //     sreset_ifc_main_interconnect_out,
                //     sreset_ifc_main_peripheral_out.reset,
                //     ENABLE_MSU_SATA
                // );

                localparam SATA_FIFO_ADDRESS_WIDTH = 13;

                logic ssd_backend_ready;

                BlockByteCtrl_int #()
                ssd_byte_ctrl (
                    .backend_ready  ( ssd_backend_ready )
                );

                AXIS_int #(
                    .DATA_BYTES(1)
                ) ssd_byte_write (
                    .clk ( clk_ifc_main_out.clk ),
                    .sresetn ( ssd_ctrl.sresetn )
                );

                AXIS_int #(
                    .DATA_BYTES(1)
                ) ssd_byte_read  (
                    .clk ( clk_ifc_main_out.clk ),
                    .sresetn ( ssd_ctrl.sresetn )
                );


                MemoryMap_int mmi_sata_block_traffic_ifc();
                mmi_nul_master nul_block_traffic ( .mmi(mmi_sata_block_traffic_ifc)  );


                sata #(
                    .TRANSCEIVER_FAMILY      ( "GTH-US"                     ),
                    .USE_FEC                 ( FEC_ON_SSD                   ),
                    .SATA_FIFO_ADDRESS_WIDTH ( SATA_FIFO_ADDRESS_WIDTH      )
                ) sata_inst (
                    .sysclk                 ( clk_ifc_main_out.clk          ),
                    .rst                    ( ~ssd_ctrl_slaves[i].sresetn   ),
                    .ssd_initdone           ( ssd_ctrl_slaves[i].initdone   ),
                    .us_pulse               ( us_pulse_on_clk_main          ),
                    .sata_io                ( sata_io[i]                    ),
                    .mmi_ctrl               ( mmi_sata_ctrl_ifc             ),
                    .mmi_drp                ( mmi_sata_drp_ifc              ),
                    .mmi_perf               ( mmi_sata_perf_ifc             ),
                    .mmi_block_traffic      ( mmi_sata_block_traffic_ifc    ),
                    .backend_ready          ( ssd_backend_ready             ),
                    .byte_ctrl              ( ssd_byte_ctrl.Provider        ),
                    .axis_byte_write        ( ssd_byte_write.Slave          ),
                    .axis_byte_read         ( ssd_byte_read.Master          ),
                    .byte_ctrl_for_mmi      ( ssd_byte_ctrl.Client          ),
                    .axis_byte_write_for_mmi( ssd_byte_write.Master         ),
                    .axis_byte_read_for_mmi ( ssd_byte_read.Slave           )
                );

            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SpaceWire


    spacewire_wrapper #(
        .BITRATE        (80_000_000       ),
        .MODULE_ID      (AVMM_SPACEWIRE0+1),
        .MODULE_VERSION (1                ),
        .DEBUG_ILA      (0                )
    ) spacewire0_inst (
        .avmm            (avmm_dev_ifc[AVMM_SPACEWIRE0] ),
        .clock_avmm_ifc  (clk_ifc_main_out              ),
        .sreset_avmm_ifc (sreset_ifc_main_peripheral_out),
        .sreset_spw_ifc  (spacewire_srst_ifc            ),
        .clk_spw_ifc     (spacewire_clk_ifc             ),
        .clk_b_spw_ifc   (spacewire_clk_b_ifc           ),
        .axis_out        (spacewire_axis_rx[0]          ),
        .axis_in         (spacewire_axis_tx[0]          ),
        .interrupt       (spacewire_interrupt[0]        ),
        .mmcm_locked     (spacewire_mmcm_locked         ),
        .spacewire       (spacewire[0]                  )
    );

    spacewire_wrapper #(
        .BITRATE        (80_000_000       ),
        .MODULE_ID      (AVMM_SPACEWIRE1+1),
        .MODULE_VERSION (1                ),
        .DEBUG_ILA      (0                )
    ) spacewire1_inst (
        .avmm            (avmm_dev_ifc[AVMM_SPACEWIRE1]       ),
        .clock_avmm_ifc  (clk_ifc_main_out                    ),
        .sreset_avmm_ifc (sreset_ifc_main_peripheral_out      ),
        .sreset_spw_ifc  (spacewire_srst_ifc                  ),
        .clk_spw_ifc     (spacewire_clk_ifc                   ),
        .clk_b_spw_ifc   (spacewire_clk_b_ifc                 ),
        .axis_out        (spacewire_axis_rx[1]                ),
        .axis_in         (spacewire_axis_tx[1]                ),
        .interrupt       (spacewire_interrupt[1]              ),
        .mmcm_locked     (spacewire_mmcm_locked               ),
        .spacewire       (spacewire[1]                        )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MDIO Control


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_elmer_phy_ifc, avmm_dev_ifc[AVMM_ELMER_PHY_MDIO], 1, AVMM_ELMER_PHY_MDIO+1, 4,  clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, 1);

    mdio_mmi mdio_elmer_phy (
        .clk     (clk_ifc_main_out.clk                ),
        .rst     (sreset_ifc_main_peripheral_out.reset),
        .mdio_io (elmer_phy_mdio                      ),
        .mmi     (mdio_mmi_elmer_phy_ifc              )
    );

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_oisl_tmtc_prog_phy_ifc, avmm_dev_ifc[AVMM_OISL1_TMTC_PROG_PHY_MDIO], 1, AVMM_OISL1_TMTC_PROG_PHY_MDIO+1, 4,  clk_ifc_main_out, sreset_ifc_main_interconnect_out, sreset_ifc_main_peripheral_out.reset, 1);

    mdio_mmi mdio_oisl_tmtc_prog_phy (
        .clk     (clk_ifc_main_out.clk                ),
        .rst     (sreset_ifc_main_peripheral_out.reset),
        .mdio_io (    oisl_tmtc_prog_phy_mdio_drv[1]                      ),
        .mmi     (mdio_mmi_oisl_tmtc_prog_phy_ifc              )
    );



    assign oisl_aqr_phy_select   = avmm_gpio_out[0][8];
    assign avmm_gpio_in[0][8]    = oisl_aqr_phy_select;

    avmm_gpio #(
        .MODULE_VERSION      (1           ),
        .MODULE_ID           (1           ),
        .DATALEN             (32          ),
        .NUM_INPUT_REGS      (1           ),
        .NUM_OUTPUT_REGS     (1           ),
        .DEFAULT_OUTPUT_VALS ('{default:0})
    ) avmm_gpio_counts_inst (
        .clk_ifc                 (clk_ifc_main_out                ),
        .peripheral_sreset_ifc   (sreset_ifc_main_peripheral_out  ),
        .interconnect_sreset_ifc (sreset_ifc_main_interconnect_out),
        .avmm                    (avmm_dev_ifc[AVMM_OISL_GPIO]    ),
        .input_vals              (avmm_gpio_in                    ),
        .output_vals             (avmm_gpio_out                   )
    );

    mdio_nul_drv oisl1_mdio_nul ( .drv(oisl_tmtc_prog_phy_mdio_drv[0]) );

    generate
        for (genvar i = 0; i < 2; i++) begin
            assign oisl_tmtc_prog_phy_mdio[i].MDC  = oisl_tmtc_prog_phy_mdio_drv[i].MDC;
            assign oisl_tmtc_prog_phy_mdio[i].MDIO = oisl_tmtc_prog_phy_mdio_drv[i].MDIO_oe ?
                oisl_tmtc_prog_phy_mdio_drv[i].MDIO_out : 1'bZ;
            assign oisl_tmtc_prog_phy_mdio_drv[i].MDIO_in = oisl_tmtc_prog_phy_mdio[i].MDIO;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Debug


    `ifndef MODEL_TECH

        generate
            if (DEBUG_ILA) begin: gen_system_ila
                ila_debug mpcu_system_ila_main_clk_inst (
                    .clk    ( clk_ifc_main_out.clk ),
                    .probe0 ( {sreset_ifc_main_interconnect_out.reset, sresetn_ifc_main_interconnect_out.reset,
                            sreset_ifc_main_peripheral_out.reset, sresetn_ifc_main_peripheral_out.reset} ),
                    .probe1 ( us_count_on_clk_main[63:32] ),
                    .probe2 ( us_count_on_clk_main[31:0] ),
                    .probe3 ( elmer_ctrl_gpio_i[31:0] ),
                    .probe4 ( elmer_ctrl_gpio_i[63:32] ),
                    .probe5 ( elmer_ctrl_gpio_o[31:0] ),
                    .probe6 ( elmer_ctrl_gpio_o[63:32] ),
                    .probe7 ( elmer_ctrl_gpio_t[31:0] ),
                    .probe8 ( elmer_ctrl_gpio_t[63:32] ),
                    .probe9 ( aocs_ctrl_gpio_i ),
                    .probe10( aocs_ctrl_gpio_o ),
                    .probe11( aocs_ctrl_gpio_t ),
                    .probe12( {bg_pmbus_i2c_scl_i, bg_pmbus_i2c_scl_o, bg_pmbus_i2c_scl_t,
                               bg_pmbus_i2c_sda_i, bg_pmbus_i2c_sda_o, bg_pmbus_i2c_sda_t} ),
                    .probe13( {mpcu_pmbus_i2c_scl_i, mpcu_pmbus_i2c_scl_o, mpcu_pmbus_i2c_scl_t,
                               mpcu_pmbus_i2c_sda_i, mpcu_pmbus_i2c_sda_o, mpcu_pmbus_i2c_sda_t} ),
                    .probe14( {aocs_spacewire_en} ),
                    .probe15( 0 )
                );

                ila_debug mpcu_system_ila_1g_enet_clk_inst (
                    .clk    ( clk_ifc_1g_enet_out.clk ),
                    .probe0 ( {sreset_ifc_1g_enet_interconnect_out.reset, sresetn_ifc_1g_enet_interconnect_out.reset,
                            sreset_ifc_1g_enet_peripheral_out.reset, sresetn_ifc_1g_enet_peripheral_out.reset} ),
                    .probe1 ( us_count_on_clk_1g_enet[63:32] ),
                    .probe2 ( us_count_on_clk_1g_enet[31:0] ),
                    .probe3 ( 0 ),
                    .probe4 ( 0 ),
                    .probe5 ( 0 ),
                    .probe6 ( 0 ),
                    .probe7 ( 0 ),
                    .probe8 ( 0 ),
                    .probe9 ( 0 ),
                    .probe10( 0 ),
                    .probe11( 0 ),
                    .probe12( 0 ),
                    .probe13( 0 ),
                    .probe14( 0 ),
                    .probe15( 0 )
                );
            end
        endgenerate
    `endif // !MODEL_TECH
endmodule

`default_nettype wire
