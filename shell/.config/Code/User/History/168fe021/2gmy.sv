// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

`include "board_pcuecp_config.svh"

`define DEFINED(A) `ifdef A 1 `else 0 `endif

/**
 * Instantiation and connection of high-level blocks for the S-UE-SDR
 */
module board_pcuecp_system
    import BOARD_PCUECP_CLOCK_RESET_PKG::*;
    import AVMM_ADDRS_PCUECP::*;
    import BOARD_PCUECP_PPL_PKG::*;
#(
    parameter bit   ENABLE_PPL    = 1'b0,
    parameter bit   PPL_DUAL_LANE = 1'b0
) (



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks coming out of PS


    Clock_int.Output clk_ifc_ps_156_25_out, // TODO: Check parameters from higher up match
    Clock_int.Input  clk_ifc_ps_156_25_in,  // TODO: Check parameters from higher up match
    Clock_int.Output clk_ifc_ps_125_out,
    Clock_int.Output clk_ifc_ps_200_out,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: General Controls


    input   var logic [4:0] card_id,
    input   var logic blade_sync_in,
    output  var logic blade_sync_out,
    input   var logic gps_pps,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MPCU Interface


    SPIIO_int mpcu_spi,

    input  var logic    blade_pmbus_i2c_scl_i,
    output var logic    blade_pmbus_i2c_scl_o,
    output var logic    blade_pmbus_i2c_scl_t,
    input  var logic    blade_pmbus_i2c_sda_i,
    output var logic    blade_pmbus_i2c_sda_o,
    output var logic    blade_pmbus_i2c_sda_t,
    input  var logic    blade_pmbus_alert_n,
    input  var logic    blade_pmbus_ctrl,       // input because we don't use it; only monitor the pin
    output var logic    blade_pmbus_reset_n,    // should be driven as open-drain

    input  var logic    cal_eeprom_i2c_scl_i,
    output var logic    cal_eeprom_i2c_scl_o,
    output var logic    cal_eeprom_i2c_scl_t,
    input  var logic    cal_eeprom_i2c_sda_i,
    output var logic    cal_eeprom_i2c_sda_o,
    output var logic    cal_eeprom_i2c_sda_t,

    input  var logic    id_eeprom_i2c_scl_i,
    output var logic    id_eeprom_i2c_scl_o,
    output var logic    id_eeprom_i2c_scl_t,
    input  var logic    id_eeprom_i2c_sda_i,
    output var logic    id_eeprom_i2c_sda_o,
    output var logic    id_eeprom_i2c_sda_t,
    output var logic    id_eeprom_isolator_en,  // set 1 to connect id_eeprom_i2c to the bus


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PL DDR


    input   var  logic              clk_ddr_pl_n,
    input   var  logic              clk_ddr_pl_p,
    output  var  logic    [16:0]    pl_ddr_a,
    output  var  logic              pl_ddr_act_n,
    output  var  logic     [1:0]    pl_ddr_ba,
    output  var  logic              pl_ddr_bg0,
    output  var  logic              pl_ddr_ck0_n,
    output  var  logic              pl_ddr_ck0_p,
    output  var  logic              pl_ddr_cke0,
    output  var  logic              pl_ddr_cs_n0,
    inout   tri  logic     [1:0]    pl_ddr_dm,
    inout   tri  logic    [15:0]    pl_ddr_dq,
    inout   tri  logic     [1:0]    pl_ddr_dqs_n,
    inout   tri  logic     [1:0]    pl_ddr_dqs_p,
    output  var  logic              pl_ddr_odt,
    output  var  logic              pl_1v8_ddr_rst_n,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK


    SPIIO_int.Driver lmk_spi_io,
    CLK_LMK04828_int lmk,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transceiver based SGMII pins


    MDIO_IO_int.Driver sgmii_mdio,

    input  var logic sgmii_xcvr_refclk_p,
    input  var logic sgmii_xcvr_refclk_n,
    input  var logic sgmii_xcvr_rx_p,
    input  var logic sgmii_xcvr_rx_n,
    output var logic sgmii_xcvr_tx_p,
    output var logic sgmii_xcvr_tx_n,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transceiver based Aurora PPL pins


    input  var logic ppl_xcvr_refclk_p,
    input  var logic ppl_xcvr_refclk_n,
    input  var logic ppl_xcvr_rx_p,
    input  var logic ppl_xcvr_rx_n,
    output var logic ppl_xcvr_tx_p,
    output var logic ppl_xcvr_tx_n

);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters


    localparam int MMI_ADDRLEN = AVMM_ADDRLEN - 2;
    localparam int MMI_DATALEN = 16;
    localparam int MAX_PKTSIZE = 5000;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Global Clocks and Resets


    /* External reset
     */


    Reset_int #(
        .CLOCK_GROUP_ID ( -1 ),
        .NUM            (  1 ),
        .DEN            (  1 ),
        .PHASE_ID       (  0 ),
        .ACTIVE_HIGH    (  0 ),
        .SYNC           (  0 )
    ) aresetn_ifc_external ();


    /* Zynq output clocks/resets
     */


    Clock_int #(
        .CLOCK_GROUP_ID   ( PS_IOPLL_125M_OUTPUT_GROUP_ID     ),
        .NUM              ( PS_IOPLL_PL_MMCM_156M25_NUM       ),
        .DEN              ( PS_IOPLL_PL_MMCM_156M25_DEN       ),
        .PHASE_ID         ( PS_IOPLL_PL_MMCM_156M25_PHASE_ID  ),
        .SOURCE_FREQUENCY ( PS_IOPLL_125M_OUTPUT_FREQUENCY    )
    ) clk_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_156_25.CLOCK_GROUP_ID  ),
        .NUM            ( clk_ifc_ps_156_25.NUM             ),
        .DEN            ( clk_ifc_ps_156_25.DEN             ),
        .PHASE_ID       ( clk_ifc_ps_156_25.PHASE_ID        ),
        .ACTIVE_HIGH    ( 1                                 ),
        .SYNC           ( 1                                 )
    ) peripheral_sreset_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_156_25.CLOCK_GROUP_ID  ),
        .NUM            ( clk_ifc_ps_156_25.NUM             ),
        .DEN            ( clk_ifc_ps_156_25.DEN             ),
        .PHASE_ID       ( clk_ifc_ps_156_25.PHASE_ID        ),
        .ACTIVE_HIGH    ( 0                                 ),
        .SYNC           ( 1                                 )
    ) peripheral_sresetn_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_156_25.CLOCK_GROUP_ID  ),
        .NUM            ( clk_ifc_ps_156_25.NUM             ),
        .DEN            ( clk_ifc_ps_156_25.DEN             ),
        .PHASE_ID       ( clk_ifc_ps_156_25.PHASE_ID        ),
        .ACTIVE_HIGH    ( 1                                 ),
        .SYNC           ( 1                                 )
    ) interconnect_sreset_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_156_25.CLOCK_GROUP_ID  ),
        .NUM            ( clk_ifc_ps_156_25.NUM             ),
        .DEN            ( clk_ifc_ps_156_25.DEN             ),
        .PHASE_ID       ( clk_ifc_ps_156_25.PHASE_ID        ),
        .ACTIVE_HIGH    ( 0                                 ),
        .SYNC           ( 1                                 )
    ) interconnect_sresetn_ifc_ps_156_25 ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( PS_IOPLL_125M_OUTPUT_GROUP_ID  ),
        .NUM              ( PS_IOPLL_PL_MMCM_125M_NUM      ),
        .DEN              ( PS_IOPLL_PL_MMCM_125M_DEN      ),
        .PHASE_ID         ( PS_IOPLL_PL_MMCM_125M_PHASE_ID ),
        .SOURCE_FREQUENCY ( PS_IOPLL_125M_OUTPUT_FREQUENCY )
    ) clk_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_125.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_125.NUM            ),
        .DEN            ( clk_ifc_ps_125.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_125.PHASE_ID       ),
        .ACTIVE_HIGH    ( 1                             ),
        .SYNC           ( 1                             )
    ) peripheral_sreset_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_125.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_125.NUM            ),
        .DEN            ( clk_ifc_ps_125.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_125.PHASE_ID       ),
        .ACTIVE_HIGH    ( 0                             ),
        .SYNC           ( 1                             )
    ) peripheral_sresetn_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_125.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_125.NUM            ),
        .DEN            ( clk_ifc_ps_125.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_125.PHASE_ID       ),
        .ACTIVE_HIGH    ( 1                             ),
        .SYNC           ( 1                             )
    ) interconnect_sreset_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_125.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_125.NUM            ),
        .DEN            ( clk_ifc_ps_125.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_125.PHASE_ID       ),
        .ACTIVE_HIGH    ( 0                             ),
        .SYNC           ( 1                             )
    ) interconnect_sresetn_ifc_ps_125 ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( PS_OSC_GROUP_ID       ),
        .NUM              ( PS_DPLL_200M_NUM      ),
        .DEN              ( PS_DPLL_200M_DEN      ),
        .PHASE_ID         ( PS_DPLL_200M_PHASE_ID ),
        .SOURCE_FREQUENCY ( PS_OSC_FREQUENCY      )
    ) clk_ifc_ps_200 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_200.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_200.NUM            ),
        .DEN            ( clk_ifc_ps_200.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_200.PHASE_ID       ),
        .ACTIVE_HIGH    ( 1                             ),
        .SYNC           ( 1                             )
    ) peripheral_sreset_ifc_ps_200 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_200.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_200.NUM            ),
        .DEN            ( clk_ifc_ps_200.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_200.PHASE_ID       ),
        .ACTIVE_HIGH    ( 0                             ),
        .SYNC           ( 1                             )
    ) peripheral_sresetn_ifc_ps_200 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_200.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_200.NUM            ),
        .DEN            ( clk_ifc_ps_200.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_200.PHASE_ID       ),
        .ACTIVE_HIGH    ( 1                             ),
        .SYNC           ( 1                             )
    ) interconnect_sreset_ifc_ps_200 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( clk_ifc_ps_200.CLOCK_GROUP_ID ),
        .NUM            ( clk_ifc_ps_200.NUM            ),
        .DEN            ( clk_ifc_ps_200.DEN            ),
        .PHASE_ID       ( clk_ifc_ps_200.PHASE_ID       ),
        .ACTIVE_HIGH    ( 0                             ),
        .SYNC           ( 1                             )
    ) interconnect_sresetn_ifc_ps_200 ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( PS_OSC_GROUP_ID      ),
        .NUM              ( PS_DPLL_50M_NUM      ),
        .DEN              ( PS_DPLL_50M_DEN      ),
        .PHASE_ID         ( PS_DPLL_50M_PHASE_ID ),
        .SOURCE_FREQUENCY ( PS_OSC_FREQUENCY     )
    ) clk_ifc_ps_50 ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Other Signals


    logic [63:0] us_count_on_ps_clk_156_25, us_count_on_ps_clk_125;  // free-running microsecond counter
    logic        us_pulse_on_ps_clk_156_25, us_pulse_on_ps_clk_125;  // pulses once every microsecond


    logic   [31:0]  linux_gpio_i;
    logic   [31:0]  linux_gpio_o;
    logic   [31:0]  linux_gpio_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SPI to AVMM


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_spi_to_avmm_loopback (
        .clk     ( clk_ifc_ps_156_25.clk                   ),
        .sresetn ( interconnect_sresetn_ifc_ps_156_25.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PPL

    logic gth128_refclk;
    AuroraCtrl_int ppl_aur ();
    AuroraIO_int ppl_aur_io ();

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) ppl_axis_tx [EXTERNAL_PPL_AXIS_TX_NUM_INDICES-1:0] (
        .clk     ( ppl_aur.user_clk         ),
        .sresetn ( ppl_aur.sresetn_user_clk )
    );

    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) ppl_axis_rx [EXTERNAL_PPL_AXIS_RX_NUM_INDICES-1:0] (
        .clk     ( ppl_aur.user_clk         ),
        .sresetn ( ppl_aur.sresetn_user_clk )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq Data Busses


    // Ethernet frames from PS to MPCU in PL (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) mpcu_ethernet_ps_to_mpcu (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from MPCU in PL to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) mpcu_ethernet_mpcu_to_ps (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from PL to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pl_ethernet_sgmii_to_ps (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames from PS to PL (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pl_ethernet_ps_to_sgmii (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_ethernet_from_ps [5:0] (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );

    // Ethernet frames (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_ethernet_to_ps [5:0] (
        .clk        (  clk_ifc_ps_125.clk                 ),
        .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SDR Interfaces


    // TODO: Remove when AVMM startup control is added
    SDR_Ctrl_int #( .STATELEN (1) ) ddr_ctrl    ( .clk ( clk_ifc_ps_156_25.clk ) );
    SDR_Ctrl_int #( .STATELEN (1) ) lmk_ctrl    ( .clk ( clk_ifc_ps_156_25.clk ) );
    SDR_Ctrl_int #( .STATELEN (1) ) ppl_aur_ctrl( .clk ( clk_ifc_ps_156_25.clk ) );

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
        .clk     (  clk_ifc_ps_156_25.clk                 ),
        .sresetn (  peripheral_sresetn_ifc_ps_156_25.reset )
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
    // SECTION: Module Declarations and Connections


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Free running microsecond counter


    util_stopwatch #(
        .CLOCK_SOURCE ( 125 ),
        .COUNT_WIDTH  ( 64  ),
        .AUTO_START   ( 1   )
    ) free_us_counter_inst (
        .clk              ( clk_ifc_ps_125.clk                 ),
        .rst              ( peripheral_sreset_ifc_ps_125.reset ),
        .start_stb        ( 1'b0                                  ),
        .reset_stb        ( 1'b0                                  ),
        .stop_stb         ( 1'b0                                  ),
        .count            ( us_count_on_ps_clk_125                ),
        .overflow         (                                       ),
        .latched_count    (                                       ),
        .latched_overflow (                                       ),
        .ext_event        (                                       ),
        .count_pulse_out  ( us_pulse_on_ps_clk_125                )
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
        .in_clk             ( clk_ifc_ps_125.clk ),
        .in_resetn          ( interconnect_sresetn_ifc_ps_125.reset ),
        .in_start           ( us_pulse_on_ps_clk_125 ),
        .in_data            ( us_count_on_ps_clk_125 ),
        .in_complete        ( ),
        .out_clk            ( clk_ifc_ps_156_25.clk ),
        .out_resetn         ( interconnect_sresetn_ifc_ps_156_25.reset ),
        .out_data_enable    ( us_pulse_on_ps_clk_156_25 ),
        .out_data           ( us_count_on_ps_clk_156_25 ),
        .out_ready          ( 1'b1 )
    );


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
        .SPI_CPOL                   ( 0      ),
        .DEBUG_ILA                  ( 0      )
    ) spi_to_avmm_inst (
        .avmm_out        ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_SPI] ),
        .clock_ifc_avmm  ( clk_ifc_ps_156_25                            ),
        .sreset_ifc_avmm ( interconnect_sreset_ifc_ps_156_25            ),
        .clock_ifc_axis  ( clk_ifc_ps_156_25                            ),
        .sreset_ifc_axis ( interconnect_sreset_ifc_ps_156_25            ),

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
        .clk_ifc                 ( clk_ifc_ps_156_25                  ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25  ),
        .avmm_in                 ( avmm_masters_to_arbiter_ifc        ),
        .avmm_out                ( avmm_arbiter_to_unburst_ifc.Master ),
        .read_active_mask        (                                    ),
        .write_active_mask       (                                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Unburst


    avmm_unburst #(
        .ADDRESS_INCREMENT ( 0 ),
        .DEBUG_ILA         ( 0 )
    ) avmm_unburst_spi_to_demux (
        .clk_ifc                 ( clk_ifc_ps_156_25                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm_in                 ( avmm_arbiter_to_unburst_ifc.Slave ),
        .avmm_out                ( avmm_unburst_to_demux_ifc.Master  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Demux


    avmm_demux #(
        .NUM_DEVICES        ( AVMM_NDEVS   ),
        .ADDRLEN            ( AVMM_ADDRLEN ),
        .DEVICE_ADDR_OFFSET ( DEV_OFFSET   ),
        .DEVICE_ADDR_WIDTH  ( DEV_WIDTH    )
    ) avmm_demux_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm_in                 ( avmm_unburst_to_demux_ifc.Slave   ),
        .avmm_out                ( avmm_dev_ifc                      )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Bad Address Responder


    avmm_bad avmm_bad_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm                    ( avmm_dev_ifc[AVMM_NDEVS]          )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM ROM


    avmm_rom #(
        .MODULE_VERSION ( 1                                      ),
        .MODULE_ID      ( AVMM_ADDRS_ROM+1                       ),
        .ROM_FILE_NAME  ( "board_pcuecp_avmm_addrs_rom_init.hex" ),
        .ROM_DEPTH      ( AVMM_ROM_DEPTH                         ),
        .DEBUG_ILA      ( 0                                      )
    ) avmm_rom_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_ADDRS_ROM]      )
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
        .clk_ifc                 ( clk_ifc_ps_156_25                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_GIT_INFO]       )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SEM AVMM


    sem_ultrascale_avmm #(
        .MODULE_ID          ( AVMM_SEM+1 ),
        .DEBUG_ILA          ( 0          ),
        .USE_BFM            ( 0          )
    ) sem_ultrascale_avmm_inst (
        .avmm_clk_ifc       ( clk_ifc_ps_156_25                 ),
        .icap_clk_ifc       ( clk_ifc_ps_125                    ),
        .avmm_sreset_ifc    ( interconnect_sreset_ifc_ps_156_25 ),
        .avmm_in            ( avmm_dev_ifc[AVMM_SEM]            )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM to AVMM


    avmm_to_avmm #(
        .MODULE_VERSION     ( 1                 ),
        .MODULE_ID          ( AVMM_PS_MASTER+1  ),
        .DEBUG_ILA          ( 0                 )
    ) avmm_to_avmm_ps_master_inst (
        .clk_ifc                    ( clk_ifc_ps_156_25                                   ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc_ps_156_25                   ),
        .avmm_in                    ( avmm_dev_ifc[AVMM_PS_MASTER]                        ),
        .avmm_out                   ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Master )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM INIT CTRL


    assign avmm_init_ctrl_ps_master_init_values_ifc.init_regs = '{
        '{49'hFFCA3008, 32'h0000, '1, '0 } // Set pcap_pr field to ICAP/MCAP for SEM
    };

    avmm_init_ctrl #(
        .ILA_DEBUG          ( 0 )
    ) avmm_init_ctrl_ps_master_inst (
        .clk_ifc                    ( clk_ifc_ps_156_25                                  ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc_ps_156_25                  ),
        .avmm_upstream              ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Slave ),
        .avmm_downstream            ( avmm_init_ctrl_to_ps_master_ifc.Master             ),
        .avmm_init_ctrl_ifc         ( avmm_init_ctrl_ps_master_init_values_ifc           ),
        .pre_req                    ( 1'b1                                               ),
        .initdone                   (                                                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq


    // TODO: Temporarily pull zynq out of reset at all times
    assign aresetn_ifc_external.reset = 1'b1;

    board_pcuecp_zynq_wrapper #(
        .AXIS_ETH_FIFO_ADDR_WIDTH ( 12 + 2 ) // TODO: Set properly later
    ) zynq_inst (
        .rtl_aresetn_in ( aresetn_ifc_external ), // TODO: Hook up to startup controller

        .clk_ifc_ps_156_25_out                 ( clk_ifc_ps_156_25                 ),
        .clk_ifc_ps_156_25_in                  ( clk_ifc_ps_156_25_in              ),
        .peripheral_sreset_ifc_ps_156_25_out   ( peripheral_sreset_ifc_ps_156_25   ),
        .peripheral_sresetn_ifc_ps_156_25_out  ( peripheral_sresetn_ifc_ps_156_25  ),
        .interconnect_sreset_ifc_ps_156_25_out ( interconnect_sreset_ifc_ps_156_25 ),
        .interconnect_sreset_ifc_ps_156_25_in  ( interconnect_sreset_ifc_ps_156_25 ),
        .interconnect_sresetn_ifc_ps_156_25_out( interconnect_sresetn_ifc_ps_156_25),

        .clk_ifc_ps_125_out                 ( clk_ifc_ps_125                 ),
        .peripheral_sreset_ifc_ps_125_out   ( peripheral_sreset_ifc_ps_125   ),
        .peripheral_sresetn_ifc_ps_125_out  ( peripheral_sresetn_ifc_ps_125  ),
        .interconnect_sreset_ifc_ps_125_out ( interconnect_sreset_ifc_ps_125 ),
        .interconnect_sresetn_ifc_ps_125_out( interconnect_sresetn_ifc_ps_125),

        .clk_ifc_ps_200_out                 ( clk_ifc_ps_200                 ),
        .peripheral_sreset_ifc_ps_200_out   ( peripheral_sreset_ifc_ps_200   ),
        .peripheral_sresetn_ifc_ps_200_out  ( peripheral_sresetn_ifc_ps_200  ),
        .interconnect_sreset_ifc_ps_200_out ( interconnect_sreset_ifc_ps_200 ),
        .interconnect_sresetn_ifc_ps_200_out( interconnect_sresetn_ifc_ps_200),

        .clk_ifc_ps_50_out ( clk_ifc_ps_50 ),


        .pspl_eth_tx_in  ( pspl_ethernet_to_ps  ), // MPCU -> PS
        .pspl_eth_rx_out ( pspl_ethernet_from_ps ), // PS -> MPCU

        .avmm_lpd_m ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_ZYNQ] ),

        .savmm_wrapper_in ( avmm_init_ctrl_to_ps_master_ifc.Slave ),


        .pl_i2c_scl_i   ( {id_eeprom_i2c_scl_i, cal_eeprom_i2c_scl_i, blade_pmbus_i2c_scl_i} ),
        .pl_i2c_scl_o   ( {id_eeprom_i2c_scl_o, cal_eeprom_i2c_scl_o, blade_pmbus_i2c_scl_o} ),
        .pl_i2c_scl_t   ( {id_eeprom_i2c_scl_t, cal_eeprom_i2c_scl_t, blade_pmbus_i2c_scl_t} ),
        .pl_i2c_sda_i   ( {id_eeprom_i2c_sda_i, cal_eeprom_i2c_sda_i, blade_pmbus_i2c_sda_i} ),
        .pl_i2c_sda_o   ( {id_eeprom_i2c_sda_o, cal_eeprom_i2c_sda_o, blade_pmbus_i2c_sda_o} ),
        .pl_i2c_sda_t   ( {id_eeprom_i2c_sda_t, cal_eeprom_i2c_sda_t, blade_pmbus_i2c_sda_t} ),


        .linux_gpio_i   ( linux_gpio_i ),
        .linux_gpio_o   ( linux_gpio_o ),
        .linux_gpio_t   ( linux_gpio_t )
    );

    assign clk_ifc_ps_156_25_out.clk = clk_ifc_ps_156_25.clk;
    assign clk_ifc_ps_125_out.clk    = clk_ifc_ps_125.clk;
    assign clk_ifc_ps_200_out.clk    = clk_ifc_ps_200.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Blade Tester SGMII


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sgmii_phy_ifc, avmm_dev_ifc[AVMM_SGMII_PHY_MDIO], 1, AVMM_SGMII_PHY_MDIO+1, 4, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, 1);

    mdio_mmi mdio_mmi_sgmii (
        .clk    ( clk_ifc_ps_156_25.clk                   ),
        .rst    ( interconnect_sreset_ifc_ps_156_25.reset ),
        .mdio_io( sgmii_mdio                              ),
        .mmi    ( mdio_mmi_sgmii_phy_ifc                  )
    );

    var logic mdio_mmi_sgmii_mac_initdone;

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sgmii_mac_ifc, avmm_dev_ifc[AVMM_SGMII_MAC_MDIO], 1, AVMM_SGMII_MAC_MDIO+1, 4, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, mdio_mmi_sgmii_mac_initdone);

    MDIO_IO_int #(
        .CLK_DIVIDE ( 80 ) // Chosen to be <= 2.5 MHz for clock freqs <= 200 MHz
    ) sgmii_mac_mdio ();

    mdio_mmi mdio_mmi_sgmii_mac_inst (
        .clk    ( clk_ifc_ps_156_25.clk                   ),
        .rst    ( interconnect_sreset_ifc_ps_156_25.reset ),
        .mdio_io( sgmii_mac_mdio                          ),
        .mmi    ( mdio_mmi_sgmii_mac_ifc                  )
    );

    ethernet_xcvr_sgmii_or_basex_to_axis #(
        .ENABLE                   (`DEFINED(ENABLE_BLADE_TESTER_SGMII) ),
        .AXIS_ETH_FIFO_ADDR_WIDTH ( 12 ) // TODO (alao): Can maybe reduce later
    ) ethernet_xcvr_sgmii_to_axis_inst (
        .rtl_areset_in        ( aresetn_ifc_external ),
        .clk_ifc_free_running ( clk_ifc_ps_50        ),

        .clk_ifc_avmm                 ( clk_ifc_ps_156_25                 ),
        .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25 ),
        .sreset_ifc_avmm_device       ( peripheral_sreset_ifc_ps_156_25   ),

        .initdone_avmm_clk ( mdio_mmi_sgmii_mac_initdone ),

        .axis_in  ( pspl_ethernet_from_ps[1] ),
        .axis_out ( pspl_ethernet_to_ps[1]   ),

        .avmm_drp ( avmm_dev_ifc[AVMM_SGMII_MAC_DRP] ),

        .mdio     ( sgmii_mac_mdio ),

        .xcvr_refclk_p ( sgmii_xcvr_refclk_p ),
        .xcvr_refclk_n ( sgmii_xcvr_refclk_n ),
        .xcvr_rx_p     ( sgmii_xcvr_rx_p     ),
        .xcvr_rx_n     ( sgmii_xcvr_rx_n     ),
        .xcvr_tx_p     ( sgmii_xcvr_tx_p     ),
        .xcvr_tx_n     ( sgmii_xcvr_tx_n     ),

        .gtrefclk    ( ),
        .pma_reset   ( ),
        .mmcm_locked ( )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DDR controller


    assign ddr_ctrl.sresetn = 1'b1;

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(ddr_mmi_to_mmi_ifc, avmm_dev_ifc[AVMM_DDR_CTRL], 1, AVMM_DDR_CTRL+1, 14, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, 1); // TODO (alao): Is there a INITDONE? Or can it be tied high?

    // Put the DDR behind an mmi_to_mmi, since MMI only has a 15-bit address
    mmi_to_mmi #(
        .MMI_ADDRLEN   ( MMI_ADDRLEN     ),
        .MMI_DATALEN   ( MMI_DATALEN     ),
        .MMI_S_ADDRLEN ( mmi_ddr.ADDRLEN ),
        .MMI_S_DATALEN ( mmi_ddr.DATALEN )
    ) ddr_mmi_to_mmi_inst (
        .clk     (  clk_ifc_ps_156_25.clk                 ),
        .reset_n (  peripheral_sresetn_ifc_ps_156_25.reset ),
        .mmi     (  ddr_mmi_to_mmi_ifc                    ),
        .mmi_s   (  mmi_ddr_mmiclk.Master                 )
    );

    xclock_mmi xclock_mmi_ddr_inst (
        .m_clk      (  clk_ifc_ps_156_25.clk                 ),
        .m_resetn   (  peripheral_sresetn_ifc_ps_156_25.reset ),
        .m_mmi      (  mmi_ddr_mmiclk.Slave                  ),
        .s_clk      (  clk_ddr                               ),
        .s_resetn   ( !sreset_ddr                            ),
        .s_mmi      (  mmi_ddr.Master                        )
    );

    ddr4_ctrl #(
        .ILA_DEBUG (0)
    ) ddr4_ctrl_inst (
        .clkddr4_drv      ( clk_ddr          ),
        .clkddr4_sync_rst ( sreset_ddr       ),
        .ddr4_act_n       ( pl_ddr_act_n     ),
        .ddr4_adr         ( pl_ddr_a         ),
        .ddr4_ba          ( pl_ddr_ba        ),
        .ddr4_bg          ( pl_ddr_bg0       ),
        .ddr4_cke         ( pl_ddr_cke0      ),
        .ddr4_odt         ( pl_ddr_odt       ),
        .ddr4_cs_n        ( pl_ddr_cs_n0     ),
        .ddr4_ck_t        ( pl_ddr_ck0_p     ),
        .ddr4_ck_c        ( pl_ddr_ck0_n     ),
        .ddr4_reset_n     ( pl_1v8_ddr_rst_n ),
        .ddr4_dm_dbi_n    ( pl_ddr_dm        ),
        .ddr4_dq          ( pl_ddr_dq        ),
        .ddr4_dqs_c       ( pl_ddr_dqs_n     ),
        .ddr4_dqs_t       ( pl_ddr_dqs_p     ),
        .sys_clk_p        ( clk_ddr_pl_p     ),
        .sys_clk_n        ( clk_ddr_pl_n     ),
        .mmi_ram          ( mmi_ddr.Slave    ),
        .ddr_ctrl         ( ddr_ctrl.Slave   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK controller


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_lmkclk_ifc, avmm_dev_ifc[AVMM_LMKCLK], 1, AVMM_LMKCLK+1, 8192, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, lmk_ctrl.initdone);

    // TODO(acichocki): Move to allow software to control over AVMM
    assign lmk_ctrl.sresetn = (peripheral_sreset_ifc_ps_156_25.reset != peripheral_sreset_ifc_ps_156_25.ACTIVE_HIGH);
    assign lmk.syncreq = 1'b0; // we configure the LMK to ignore syncreq

    clk_lmk0482x_ctrl #(
        .MMI_DATALEN           ( MMI_DATALEN ),
        .SPI_SS_BIT            ( 0           ),
        .INIT_HEARTBEAT_TOGGLE ( 1           ),
        .HEARTBEAT_HALF_PERIOD ( 50000000    )
    ) clk_lmk0482x_ctrl_inst (
        .sdr ( lmk_ctrl             ),
        .lmk ( lmk                  ),
        .mmi ( mmi_lmkclk_ifc.Slave ),
        .spi ( lmk_spi_drv_ifc[0]   )
    );

    spi_mux #(
        .N      ( 1  ),
        .MAXLEN ( 32 )
    ) lmk_spi_mux (
        .spi_in ( lmk_spi_drv_ifc           ),
        .spi_io ( lmk_spi_io                )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PS Peripherals


    // Linux GPIO inputs
    assign linux_gpio_i[4:0]    = card_id;
    assign linux_gpio_i[7:5]    = '0;
    assign linux_gpio_i[8]      = id_eeprom_isolator_en;    // read-back
    assign linux_gpio_i[9]      = blade_pmbus_alert_n;
    assign linux_gpio_i[10]     = blade_pmbus_ctrl;         // we don't drive this; only monitor the pin
    assign linux_gpio_i[11]     = blade_pmbus_reset_n;      // read-back
    assign linux_gpio_i[27:12]  = '0;
    assign linux_gpio_i[28]     = blade_sync_in;
    assign linux_gpio_i[29]     = blade_sync_out;           // read-back
    assign linux_gpio_i[30]     = 1'b0;                     // unused; reserve in case we connect GPS_PV
    assign linux_gpio_i[31]     = gps_pps;

    assign id_eeprom_isolator_en = ~linux_gpio_t[8]  & linux_gpio_o[8];     // drive 1 only if output and 1
    assign blade_pmbus_reset_n   =  linux_gpio_t[11] | linux_gpio_o[11];    // drive 0 only if output and 0 (o.d.)
    assign blade_sync_out        = ~linux_gpio_t[29] & linux_gpio_o[29];    // drive 1 only if output and 1


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MPCU Ethernet Stream via Aurora


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_ctrl_ifc, avmm_dev_ifc[AVMM_PPL_CTRL], 1, AVMM_PPL_CTRL+1, 16+20, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_prbs_ifc, avmm_dev_ifc[AVMM_PPL_PRBS], 1, AVMM_PPL_PRBS+1, 16+24, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_ctrl_ifc, avmm_dev_ifc[AVMM_PPL_AUR_CTRL], 1, AVMM_PPL_AUR_CTRL+1, 16+20, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_drp_ifc, avmm_dev_ifc[AVMM_PPL_AUR_DRP], 1, AVMM_PPL_AUR_DRP+1, 16+6, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );

    assign ppl_aur_ctrl.sresetn =  peripheral_sresetn_ifc_ps_156_25.reset; // TODO: Move to allow software to control over AVMM

    localparam ENABLE_PPL_ETHERNET_TUNNEL = ENABLE_PPL;

    board_pcuecp_ppl #(
        .ENABLE_MPCU_PPL                ( ENABLE_PPL                    ),
        .ENABLE_PRBS                    ( 1'b1                          ),
        .DEFAULT_ENABLE_ETHERNET_TUNNEL ( ENABLE_PPL_ETHERNET_TUNNEL    ),
        .SYSCLK_FREQ                    ( 156250000                     ),
        .AUR_RX_FRAME_FIFO_DEPTH        ( 2048                          ),  // number of 64-bit words
        .DEBUG_AUR_ILA                  ( 1'b0                          ),
        .DEBUG_DATA_ILA                 ( 1'b0                          ),
        .DEBUG_PRBS_ILA                 ( 1'b0                          )
    ) board_pcuecp_ppl_inst (
        .aur_sdr_ctrl     ( ppl_aur_ctrl                    ),
        .aur_io           ( ppl_aur_io.Ctrl                 ),
        .aur_ctrl         ( ppl_aur                         ),
        .us_counter       ( us_count_on_ps_clk_156_25[47:0] ),
        .axis_ins         ( ppl_axis_tx                     ),
        .axis_outs        ( ppl_axis_rx                     ),
        .mmi_ppl_ctrl     ( mmi_ppl_ctrl_ifc                ),
        .mmi_ppl_aur_ctrl ( mmi_ppl_aur_ctrl_ifc            ),
        .mmi_ppl_aur_drp  ( mmi_ppl_aur_drp_ifc             ),
        .mmi_ppl_prbs     ( mmi_ppl_prbs_ifc                )
    );

    generate
        if (ENABLE_PPL) begin : gen_ppl_aur
            assign ppl_aur_io.gtrefclk = gth128_refclk;

            assign ppl_aur_io.RXN_IN   = ppl_xcvr_rx_n;
            assign ppl_aur_io.RXP_IN   = ppl_xcvr_rx_p;
            assign ppl_xcvr_tx_n = ppl_aur_io.TXN_OUT;
            assign ppl_xcvr_tx_p = ppl_aur_io.TXP_OUT;

        end else begin : no_ppl_aur
            assign ppl_aur_io.gtrefclk = 1'b0;
            assign ppl_aur_io.RXN_IN   = 'X;
            assign ppl_aur_io.RXP_IN   = 'X;
        end

        if (ENABLE_PPL) begin : gen_enable_gth_refclk
            // Set up the user clock network.
            IBUFDS_GTE4 #(
                .REFCLK_HROW_CK_SEL ( 2'b10 )   // ODIV2 = 1'b0 (i.e. disable the output ODIV2)
            ) gtrefclk1_buf_inst (
                .I      ( ppl_xcvr_refclk_p ),
                .IB     ( ppl_xcvr_refclk_n ),
                .O      ( gth128_refclk     ),
                .ODIV2  (                   ),
                .CEB    ( 1'b0              )
            );
        end
    endgenerate

    generate
        // Create adapters and CDC for Ethernet to/from PPL
        if (ENABLE_PPL_ETHERNET_TUNNEL) begin : gen_ppl_eth_adapter

            AXIS_int #(
                .DATA_BYTES(8)
            ) axis_ppl_eth_out_wide (
                .clk        (  clk_ifc_ps_125.clk                 ),
                .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
            );

            AXIS_int #(
                .DATA_BYTES(8)
            ) axis_ppl_eth_in_wide (
                .clk        (  clk_ifc_ps_125.clk                 ),
                .sresetn    (  peripheral_sresetn_ifc_ps_125.reset )
            );

            axis_adapter_wrapper axis_adapter_ppl_eth_in (
                .axis_in  ( pspl_ethernet_from_ps[0].Slave   ),
                .axis_out ( axis_ppl_eth_in_wide.Master      )
            );

            axis_adapter_wrapper axis_adapter_ppl_eth_out (
                .axis_in  ( axis_ppl_eth_out_wide.Slave     ),
                .axis_out ( pspl_ethernet_to_ps[0].Master   )
            );

            /**
             * This FIFO must not backpressure, so it is set to drop when full. This also requires
             * that it be at least large enough to store one full packet, plus some margin.
             *
             * TODO(wkingsford): It may make sense to revert this to a small non-frame FIFO in the
             * future once ppl has its own frame FIFOs integrated (which will be necessary as part
             * of backpressure support).
             */
            axis_async_fifo_wrapper #(
                .DEPTH          ( 2*MAX_PKTSIZE/8               ),
                .KEEP_ENABLE    ( 1'b1                          ),
                .LAST_ENABLE    ( 1'b1                          ),
                .FRAME_FIFO     ( 1'b1                          ),
                .DROP_WHEN_FULL ( 1'b1                          )
            ) axis_async_fifo_wrapper_nic_to_ppl_tx (
                .axis_in             ( axis_ppl_eth_in_wide.Slave                               ),
                .axis_out            ( ppl_axis_tx [EXTERNAL_PPL_AXIS_TX_IDX_ETHERNET]   ),
                .axis_in_overflow    (),
                .axis_in_bad_frame   (),
                .axis_in_good_frame  (),
                .axis_out_overflow   (),
                .axis_out_bad_frame  (),
                .axis_out_good_frame ()
            );

            /**
             * This FIFO must not backpressure, so it is set to drop when full. This also requires
             * that it be at least large enough to store one full packet, plus some margin.
             *
             * TODO(wkingsford): It may make sense to revert this to a small non-frame FIFO in the
             * future once ppl has its own frame FIFOs integrated (which will be necessary as part
             * of backpressure support).
             */
            axis_async_fifo_wrapper #(
                .DEPTH          ( 2*MAX_PKTSIZE/8               ),
                .KEEP_ENABLE    ( 1'b1                          ),
                .LAST_ENABLE    ( 1'b1                          ),
                .FRAME_FIFO     ( 1'b1                          ),
                .DROP_WHEN_FULL ( 1'b1                          )
            ) axis_async_fifo_wrapper_nic_rx_to_rgmii (
                .axis_in             ( ppl_axis_rx [EXTERNAL_PPL_AXIS_RX_IDX_ETHERNET]    ),
                .axis_out            ( axis_ppl_eth_out_wide.Master                             ),
                .axis_in_overflow    (),
                .axis_in_bad_frame   (),
                .axis_in_good_frame  (),
                .axis_out_overflow   (),
                .axis_out_bad_frame  (),
                .axis_out_good_frame ()
            );
        end else begin : gen_no_ppl_eth_adapter
            axis_nul_sink no_axis_ppl_eth_in   ( .axis ( pspl_ethernet_from_ps[0].Slave ) );
            axis_nul_src  no_axis_ppl_eth_out  ( .axis ( pspl_ethernet_to_ps[0].Master  ) );
            axis_nul_src  no_ppl_ethernet_src  ( .axis (ppl_axis_tx [EXTERNAL_PPL_AXIS_TX_IDX_ETHERNET]) );
            axis_nul_sink no_ppl_ethernet_sink ( .axis (ppl_axis_rx [EXTERNAL_PPL_AXIS_RX_IDX_ETHERNET]) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Ethernet loopbacks for P4 testing


    axis_connect gem0to1_in (
        .axis_in  ( pspl_ethernet_from_ps[2] ),
        .axis_out ( pspl_ethernet_to_ps[3]   )
    );

    axis_connect gem0to1_out (
        .axis_in  ( pspl_ethernet_from_ps[3] ),
        .axis_out ( pspl_ethernet_to_ps[2]   )
    );


    axis_connect gem2to3_in (
        .axis_in  ( pspl_ethernet_from_ps[4] ),
        .axis_out ( pspl_ethernet_to_ps[5]   )
    );

    axis_connect gem2to3_out (
        .axis_in  ( pspl_ethernet_from_ps[5] ),
        .axis_out ( pspl_ethernet_to_ps[4]   )
    );

    module board_pcuecp_p4_router_wrapper
        .MODULE_ID          ( 0     ),
        .NUM_PS_TO_PL_LINKS ( 4     ),
        .MTU_BYTES          ( 2000  )
    ) p4_router_wrapper (
        .core_clk_ifc               (  ),
        .core_sreset_ifc            (  ),
        .cam_clk_ifc                (  ),
        .cam_sreset_ifc             (  ),
        .avmm_clk_ifc               (  ),
        .interconnect_sreset_ifc    (  ),
        .peripheral_sreset_ifc      (  ),
        .vnp4_avmm                  (  ),
        .p4_router_avmm             (  ),
        .ingress_from_ps            ( pspl_ethernet_from_ps[5:2] ),
        .egress_to_ps               ( pspl_ethernet_to_ps[5:2] ),
    );

    p4_router #(
        .MODULE_ID                  ( 0     ),
        .NUM_8B_ING_PHYS_PORTS      ( 4     ),
        .NUM_8B_EGR_PHYS_PORTS      ( 4     ),
        .VNP4_DATA_BYTES            ( 64    ),
        .ING_PORT_METADATA_WIDTH    ( 10    ),
        .EGR_SPEC_METADATA_WIDTH    ( 10    ),
        .MTU_BYTES                  ( 2000  )
    ) (
        .core_clk_ifc               (  ),
        .core_sreset_ifc            (  ),
        .cam_clk_ifc                (  ),
        .cam_sreset_ifc             (  ),
        .avmm_clk_ifc               (  ),
        .interconnect_sreset_ifc    (  ),
        .peripheral_sreset_ifc      (  ),
        .vnp4_avmm                  (  ),
        .p4_router_avmm             (  ),
        .ing_8b_phys_ports          ( pspl_ethernet_from_ps[5:2] ),
        .ing_16b_phys_ports         (  ),
        .ing_32b_phys_ports         (  ),
        .ing_64b_phys_ports         (  ),
        .egr_8b_phys_ports          ( pspl_ethernet_to_ps[5:2] ),
        .egr_16b_phys_ports         (  ),
        .egr_32b_phys_ports         (  ),
        .egr_64b_phys_ports         (  )
    );


endmodule

`default_nettype wire
