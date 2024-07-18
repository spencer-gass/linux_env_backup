// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

`include "board_pcuhdr_config.svh"

`define DEFINED(A) `ifdef A 1 `else 0 `endif

/**
 * Instantiation and connection of high-level blocks for the PCU HDR
 */
module board_pcuhdr_system
    import BOARD_PCUHDR_CLOCK_RESET_PKG::*;
    import AVMM_ADDRS_PCUHDR::*;
    import BOARD_PCUHDR_PPL_PKG::*;
#(
    // TODO(wkingsford): use the `define directly instead of this parameter, for consistency?
    parameter bit   ENABLE_PPL = 1'b0,
    parameter bit   DEBUG_ILA_MOD  = 1'b0
) (


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks


    input                   var   logic   gth_clk0_n,
    input                   var   logic   gth_clk0_p,
    input                   var   logic   gth_clk1_n,
    input                   var   logic   gth_clk1_p,

    SPIIO_int.Driver                      lmk_spi,
    CLK_LMK04828_int                      lmk,
    input                   var   logic   lmk_status, // TODO (wkingsford): Add to clk_lmk0482x code



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: ADC


    SPIIO_int.Driver                       vga_spi,
    output             var   logic         vga_pd,

    ADC_AD9697_int.Control                 adc_ifc,

    // TODO: merge into adc interface
    input              var   logic         adc_gpio1,
    input              var   logic         adc_gpio2,
    output             var   logic         adc_pdwn_stby,

    SPIIO_int.Driver                       adc_spi,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DAC


    SPIIO_int.Driver                             dac_spi,
    DAC_DAC3xj8x_int                             dac,
    input                    var   logic         dac_sync_n_ab, // Currently unused: using combined sync_n for both
    input                    var   logic         dac_sync_n_cd, // Currently unused: using combined sync_n for both

    output                   var   logic         dac_enable,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RX


    output   var   logic   mux_sel,

    output   var   logic   if_sel,

    output   var   logic   lna_en,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: TX


    SPIIO_int.Driver                 tx_spi,

    input              var   logic   alarm_adrf6780,
    output             var   logic   reset_adrf6780_n,

    I2CIO_int.Driver                 digpot_i2c,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LO


    SPIIO_int.Driver                 lo_tx_spi,
    output             var   logic   lo_tx_spi_ce,
    input              var   logic   lo_tx_lock_detect,

    SPIIO_int.Driver                 lo_rx_spi,
    output             var   logic   lo_rx_spi_ce,
    input              var   logic   lo_rx_lock_detect,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: EEPROMS & FRAM


    I2CIO_int.Driver                 uuid_i2c,
    output             var   logic   uuid_i2c_en,

    input              var   logic   cal_eeprom_i2c_scl_i,
    output             var   logic   cal_eeprom_i2c_scl_o,
    output             var   logic   cal_eeprom_i2c_scl_t,
    input              var   logic   cal_eeprom_i2c_sda_i,
    output             var   logic   cal_eeprom_i2c_sda_o,
    output             var   logic   cal_eeprom_i2c_sda_t,



    input              var   logic   amp_fram_wp_en_i,
    output             var   logic   amp_fram_wp_en_t,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PCU Sequencer PMBUS


    input              var   logic   pcu_pmbus_i2c_scl_i,
    output             var   logic   pcu_pmbus_i2c_scl_o,
    output             var   logic   pcu_pmbus_i2c_scl_t,
    input              var   logic   pcu_pmbus_i2c_sda_i,
    output             var   logic   pcu_pmbus_i2c_sda_o,
    output             var   logic   pcu_pmbus_i2c_sda_t,

    input              var   logic   pcu_pmbus_alert_n,
    inout              tri   logic   pcu_pmbus_control,

    output             var   logic   pcu_soc_pmbus_en,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: FE Sequencer PMBUS


    input              var   logic   fe_pmbus_i2c_scl_i,
    output             var   logic   fe_pmbus_i2c_scl_o,
    output             var   logic   fe_pmbus_i2c_scl_t,
    input              var   logic   fe_pmbus_i2c_sda_i,
    output             var   logic   fe_pmbus_i2c_sda_o,
    output             var   logic   fe_pmbus_i2c_sda_t,

    input              var   logic   fe_pmbus_alert_n,
    inout              tri   logic   fe_pmbus_control,
    output             var   logic   fe_pmbus_reset_n,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AMP


    output             var   logic   amp_pa_en,
    output             var   logic   amp_master_en,
    output             var   logic   amp_heater_en,
    output             var   logic   amp_heater_en_t,

    I2CIO_int.Driver                 amp_i2c,
    output             var   logic   amp_i2c_en,

    input              var   logic   amp_pmbus_i2c_scl_i,
    output             var   logic   amp_pmbus_i2c_scl_o,
    output             var   logic   amp_pmbus_i2c_scl_t,
    input              var   logic   amp_pmbus_i2c_sda_i,
    output             var   logic   amp_pmbus_i2c_sda_o,
    output             var   logic   amp_pmbus_i2c_sda_t,

    input              var   logic   amp_pmbus_alert_n,
    input              var   logic   amp_pmbus_control_i,
    output             var   logic   amp_pmbus_control_o,
    output             var   logic   amp_pmbus_control_t,

    input              var   logic   amp_cpm_alert_n,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MPCU Interface


    SPIIO_int.SlaveIO   mpcu_spi,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Blade


    input    var   logic   [12:0]   blade_gpio_i,
    output   var   logic   [12:0]   blade_gpio_t,
    output   var   logic   [12:0]   blade_gpio_o,

    input    var   logic         blade_sync_in,
    output   var   logic         blade_sync_out,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: GPS PPS


    input   var   logic   gps_pps,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Card ID


    input   var   logic   [4:0]   card_id, //(wkingsford): disable PA bias controller except on primary HDR


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transceiver based PPL Aurora pins


    input  var logic ppl_xcvr_rx0_p,
    input  var logic ppl_xcvr_rx0_n,
    output var logic ppl_xcvr_tx0_p,
    output var logic ppl_xcvr_tx0_n
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters


    localparam int MMI_ADDRLEN           = AVMM_ADDRLEN - $clog2(AVMM_DATALEN/8);
    localparam int MMI_DATALEN           = 16;
    localparam int MAX_PKTSIZE           = 5000;
    localparam int MOD_RESAMPLE_NB_FRAC  = 14;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    // Must either be a Tranche 0 or Tranche 1 build
    `ELAB_CHECK(`DEFINED(TRANCHE0) ^ `DEFINED(TRANCHE1));

    // Can't have demod/decoder without RX
    `ELAB_CHECK(`DEFINED(ENABLE_RX) || (~`DEFINED(ENABLE_RX_DEMOD) && ~`DEFINED(ENABLE_RX_DECODER)));

    // Can't have modulator without TX
    `ELAB_CHECK(`DEFINED(ENABLE_TX) || (~`DEFINED(ENABLE_TX_MOD)));

    // Can't have TX EQ without TX
    `ELAB_CHECK(`DEFINED(ENABLE_TX) || (~`DEFINED(ENABLE_TX_EQ)));

    // TX EQ is connected on the mod output
    `ELAB_CHECK(`DEFINED(ENABLE_TX_MOD) || (~`DEFINED(ENABLE_TX_EQ)));


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clock and Reset Elaboration Check


    board_pcuhdr_clock_reset_validate board_pcuhdr_clock_reset_validate_inst (
        .clk_ifc_ps_125                    ( clk_ifc_ps_125                            ),
        .clk_ifc_ps_156_25                 ( clk_ifc_ps_156_25                         ),

        .peripheral_sreset_ifc_ps_125      ( peripheral_sreset_ifc_ps_125.ResetIn      ),
        .peripheral_sreset_ifc_ps_156_25   ( peripheral_sreset_ifc_ps_156_25.ResetIn   ),

        .peripheral_sresetn_ifc_ps_125     ( peripheral_sresetn_ifc_ps_125.ResetIn     ),
        .peripheral_sresetn_ifc_ps_156_25  ( peripheral_sresetn_ifc_ps_156_25.ResetIn  ),

        .interconnect_sreset_ifc_ps_125    ( interconnect_sreset_ifc_ps_125.ResetIn    ),
        .interconnect_sreset_ifc_ps_156_25 ( interconnect_sreset_ifc_ps_156_25.ResetIn ),

        .interconnect_sresetn_ifc_ps_125   ( interconnect_sresetn_ifc_ps_125.ResetIn   ),
        .interconnect_sresetn_ifc_ps_156_25( interconnect_sresetn_ifc_ps_156_25.ResetIn)
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic rx_initdone, tx_initdone;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets


    // External

    Reset_int #(
        .CLOCK_GROUP_ID ( -1 ),
        .NUM            (  1 ),
        .DEN            (  1 ),
        .PHASE_ID       (  0 ),
        .ACTIVE_HIGH    (  0 ),
        .SYNC           (  0 )
    ) aresetn_ifc_external ();

    // Zynq generated output clocks/resets

    // 125 MHz

    Clock_int #(
        .CLOCK_GROUP_ID   ( PL_OSC_GROUP_ID          ),
        .NUM              ( PL_OSC_PLL_125M_NUM      ),
        .DEN              ( PL_OSC_PLL_125M_DEN      ),
        .PHASE_ID         ( PL_OSC_PLL_125M_PHASE_ID ),
        .SOURCE_FREQUENCY ( PL_OSC_FREQUENCY         )
    ) clk_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID          ),
        .NUM            ( PL_OSC_PLL_125M_NUM      ),
        .DEN            ( PL_OSC_PLL_125M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_125M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                        ),
        .SYNC           ( 1                        )
    ) peripheral_sreset_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID          ),
        .NUM            ( PL_OSC_PLL_125M_NUM      ),
        .DEN            ( PL_OSC_PLL_125M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_125M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                        ),
        .SYNC           ( 1                        )
    ) peripheral_sresetn_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID          ),
        .NUM            ( PL_OSC_PLL_125M_NUM      ),
        .DEN            ( PL_OSC_PLL_125M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_125M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                        ),
        .SYNC           ( 1                        )
    ) interconnect_sreset_ifc_ps_125 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID          ),
        .NUM            ( PL_OSC_PLL_125M_NUM      ),
        .DEN            ( PL_OSC_PLL_125M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_125M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                        ),
        .SYNC           ( 1                        )
    ) interconnect_sresetn_ifc_ps_125 ();

    // 156.25 MHz

    Clock_int #(
        .CLOCK_GROUP_ID   ( PL_OSC_GROUP_ID             ),
        .NUM              ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN              ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID         ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .SOURCE_FREQUENCY ( PL_OSC_FREQUENCY            )
    ) clk_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                           ),
        .SYNC           ( 1                           )
    ) peripheral_sreset_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                           ),
        .SYNC           ( 1                           )
    ) peripheral_sresetn_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                           ),
        .SYNC           ( 1                           )
    ) interconnect_sreset_ifc_ps_156_25 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                           ),
        .SYNC           ( 1                           )
    ) interconnect_sresetn_ifc_ps_156_25 ();

    // RX power enable and FE chip reset
    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                           ), // active-low, so it can be interpreted as an active-high power-enable
        .SYNC           ( 1                           )
    ) rx_pwr_en_sresetn_ifc_156_25 ();

    // RX peripheral reset: asserted some delay after RX pwr en
    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                           ),
        .SYNC           ( 1                           )
    ) rx_peripheral_sreset_ifc_156_25 ();

    // TX power enable and FE chip reset
    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 0                           ), // active-low, so it can be interpreted as an active-high power-enable
        .SYNC           ( 1                           )
    ) tx_pwr_en_sresetn_ifc_156_25 ();

    // TX peripheral reset: asserted some delay after TX pwr en
    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC_GROUP_ID             ),
        .NUM            ( PL_OSC_PLL_156_25M_NUM      ),
        .DEN            ( PL_OSC_PLL_156_25M_DEN      ),
        .PHASE_ID       ( PL_OSC_PLL_156_25M_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                           ),
        .SYNC           ( 1                           )
    ) tx_peripheral_sreset_ifc_156_25 ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: TX (DAC38J84) clock/reset interfaces


    // Clock output from the JESD204C core: input to the TX PLL
    Clock_int #(
        .CLOCK_GROUP_ID   ( TX_DAC_GROUP_ID         ),
        .NUM              ( TX_DAC_JESD_150M_NUM    ),
        .DEN              ( TX_DAC_JESD_150M_DEN    ),
        .PHASE_ID         ( TX_DAC_JESD_PHASE_ID    ),
        .SOURCE_FREQUENCY ( FE_LMK_FREQUENCY        )
    ) dac_jesd_clk_ifc();

    // Async reset output from the JESD204C core
    Reset_int #(
        .CLOCK_GROUP_ID ( TX_DAC_GROUP_ID           ),
        .NUM            ( TX_DAC_JESD_150M_NUM      ),
        .DEN            ( TX_DAC_JESD_150M_DEN      ),
        .PHASE_ID       ( TX_DAC_JESD_PHASE_ID      ),
        .ACTIVE_HIGH    ( 0                         ),
        .SYNC           ( 0                         )
    ) dac_jesd_aresetn_ifc();

    // Clock for the TX signal path: output from the TX PLL
    Clock_int #(
        .CLOCK_GROUP_ID   ( TX_DAC_GROUP_ID     ),
        .NUM              ( TX_DAC_PLL_150M_NUM ),
        .DEN              ( TX_DAC_PLL_150M_DEN ),
        .PHASE_ID         ( TX_DAC_PLL_PHASE_ID ),
        .SOURCE_FREQUENCY ( FE_LMK_FREQUENCY    )
    ) txsdr_clk_ifc();

    // Reset for the TX signal path: synchronized from dac_jesd_aresetn_ifc
    Reset_int #(
        .CLOCK_GROUP_ID ( TX_DAC_GROUP_ID       ),
        .NUM            ( TX_DAC_PLL_150M_NUM   ),
        .DEN            ( TX_DAC_PLL_150M_DEN   ),
        .PHASE_ID       ( TX_DAC_PLL_PHASE_ID   ),
        .ACTIVE_HIGH    ( 0                     ),
        .SYNC           ( 1                     )
    ) txsdr_sresetn_ifc();

    // Clock for the DVB-S2X modulator: output from the TX PLL
    localparam int TX_MOD_CLK_NUM = `DEFINED(TX_MOD_ON_DAC_CLK) ? TX_DAC_PLL_150M_NUM : TX_DAC_PLL_200M_NUM;
    localparam int TX_MOD_CLK_DEN = `DEFINED(TX_MOD_ON_DAC_CLK) ? TX_DAC_PLL_150M_DEN : TX_DAC_PLL_200M_DEN;

    Clock_int #(
        .CLOCK_GROUP_ID   ( TX_DAC_GROUP_ID     ),
        .NUM              ( TX_MOD_CLK_NUM      ),
        .DEN              ( TX_MOD_CLK_DEN      ),
        .PHASE_ID         ( TX_DAC_PLL_PHASE_ID ),
        .SOURCE_FREQUENCY ( FE_LMK_FREQUENCY    )
    ) mod_clk_ifc();

    // Reset for the DVB-S2X modulator: synchronized from dac_jesd_aresetn_ifc
    Reset_int #(
        .CLOCK_GROUP_ID ( TX_DAC_GROUP_ID       ),
        .NUM            ( TX_MOD_CLK_NUM        ),
        .DEN            ( TX_MOD_CLK_DEN        ),
        .PHASE_ID       ( TX_DAC_PLL_PHASE_ID   ),
        .ACTIVE_HIGH    ( 0                     ),
        .SYNC           ( 1                     )
    ) mod_sresetn_ifc();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RX (AD9697) clock/reset interfaces


    Clock_int #(
        .CLOCK_GROUP_ID   ( RX_ADC_GROUP_ID         ),
        .NUM              ( RX_ADC_150M_NUM         ),
        .DEN              ( RX_ADC_150M_DEN         ),
        .PHASE_ID         ( RX_ADC_150M_PHASE_ID    ),
        .SOURCE_FREQUENCY ( FE_LMK_FREQUENCY        )
    ) adc_sample_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( RX_ADC_GROUP_ID       ),
        .NUM            ( RX_ADC_150M_NUM       ),
        .DEN            ( RX_ADC_150M_DEN       ),
        .PHASE_ID       ( RX_ADC_150M_PHASE_ID  ),
        .ACTIVE_HIGH    ( 1                     ),
        .SYNC           ( 1                     )
    ) adc_sample_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Free running microsecond counter


    logic [63:0] us_count_on_ps_clk_125, us_count_on_ps_clk_156_25;
    logic        us_pulse_on_ps_clk_125, us_pulse_on_ps_clk_156_25;   // pulses once every microsecond


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SPI to AVMM


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_spi_to_avmm_loopback (
        .clk     ( clk_ifc_ps_156_25.clk                   ),
        .sresetn (interconnect_sresetn_ifc_ps_156_25.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PPL


    SDR_Ctrl_int #( .STATELEN (1) ) ppl_aur_ctrl( .clk ( clk_ifc_ps_156_25.clk ) );

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
    // SUB-SECTION: Ethernet Interfaces


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_eth_src (
        .clk        ( clk_ifc_ps_125.clk                  ),
        .sresetn    ( peripheral_sresetn_ifc_ps_125.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) pspl_eth_sink (
        .clk        ( clk_ifc_ps_125.clk                  ),
        .sresetn    ( peripheral_sresetn_ifc_ps_125.reset )
    );


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
        .DATALEN       ( AVMM_DATALEN       ),
        .ADDRLEN       ( AVMM_ADDRLEN       ),
        .BURSTLEN      ( 11                 ), // Should match the BURSTLEN that is configured in the axi_amm_bridge IP core
        .BURST_CAPABLE ( 1'b1               )
    ) avmm_masters_to_arbiter_ifc [NUM_AVMM_MASTERS-1:0] (); // avmm bridge (zynq)

    // AVMM Arbiter to Unburst Interface
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN       ),
        .ADDRLEN       ( AVMM_ADDRLEN       ),
        .BURSTLEN      ( 11                 ),
        .BURST_CAPABLE ( 1'b1               )
    ) avmm_arbiter_to_unburst_ifc ();

    // AVMM Unburst to Demux Interface
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN       ),
        .ADDRLEN       ( AVMM_ADDRLEN       ),
        .BURSTLEN      ( 1                  ),
        .BURST_CAPABLE ( 1'b0               )
    ) avmm_unburst_to_demux_ifc ();

    // AVMM Demux to Device Interfaces
    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN       ),
        .ADDRLEN       ( AVMM_ADDRLEN       ),
        .BURSTLEN      ( 1                  ),
        .BURST_CAPABLE ( 1'b0               )
    ) avmm_device_ifc [AVMM_NDEVS:0] (); // not AVMM_NDEVS-1, avmm_device_ifc[AVMM_NDEVS] is the necessary bad address responder

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
    // SUB-SECTION: TX/RX Interfaces


    SampleStream_int # (
        .N_CHANNELS ( 2     ),
        .N_PARALLEL ( 8     ),
        .NB         ( 16    ),
        .NB_FRAC    ( 0     ),
        .PAUSABLE   ( 0     )
    ) ssi_dac (
        .clk     ( txsdr_clk_ifc.clk       ),
        .sresetn ( txsdr_sresetn_ifc.reset )
    );

    // dac_jesd_aresetn_ifc.reset, synchronized to txsdr_clk_ifc: this can still be asserted asynchronously, so needs an
    // additional synchronizer stage to make a synchronous reset
    logic txsdr_sresetn_ifc_reset_i;

    xclock_resetn #(
        .INPUT_REG ( 0 )
    ) xclock_txsdr_rst_async (
        .tx_clk     ( 1'b0                                      ),
        .resetn_in  ( dac_jesd_aresetn_ifc.reset                ), // Async reset in (comes from the JESD204C core)
        .rx_clk     ( txsdr_clk_ifc.clk                         ),
        .resetn_out ( txsdr_sresetn_ifc_reset_i                 )  // Async reset out
    );

    xclock_sig #(
        .INPUT_REG ( 0 )
    ) xclock_txsdr_rst_sync (
        .tx_clk     ( txsdr_clk_ifc.clk           ),
        .sig_in     ( txsdr_sresetn_ifc_reset_i   ), // Async reset in
        .rx_clk     ( txsdr_clk_ifc.clk           ),
        .sig_out    ( txsdr_sresetn_ifc.reset     )  // Sync reset out
    );

    AMP_LMH6401_int #( .NAMPS (2)         ) rx_amp ();

    // RX AGC
    logic [47:0] rx_power [0:ADC_AD9697_PCUHDR_PKG::JESD_M-1]; // pwr_detector output bit width is 48
    logic        rx_power_valid_stb;

    // axis_async_fifo status signals for mod clk to dac clk
    logic overflow_mod_clk, bad_frame_mod_clk, good_frame_mod_clk;
    logic overflow_dac_clk, bad_frame_dac_clk, good_frame_dac_clk;

    // Gain used to scale modulator output samples to avoid overflow
    logic [BOARD_PCUHDR_TXSDR_PKG::TX_NB-1:0] mod_gain [BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS-1:0];

    // TODO(wkingsford): PPL DVB-S2X: this should be on the Aurora clock instead
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_in_dvbs2x (
        .clk     ( clk_ifc_ps_156_25.clk                    ),
        .sresetn ( ~tx_peripheral_sreset_ifc_156_25.reset   )
    );

    AXIS_int #(
        .DATA_BYTES         ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALLOW_BACKPRESSURE ( 1'b1                               ),
        .ALIGNED            ( 1'b1                               ),
        .NB                 ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS         ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL         ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x_raw (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES         ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALLOW_BACKPRESSURE ( 1'b1                               ),
        .ALIGNED            ( 1'b1                               ),
        .NB                 ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS         ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL         ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x_scaled (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES         ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALLOW_BACKPRESSURE ( 1'b1                               ),
        .ALIGNED            ( 1'b1                               ),
        .NB                 ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS         ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL         ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x_pre_fir (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES * 3   ),
        .ALIGNED    ( 1'b1                                   ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB          ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS     ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL * 3 )
    ) asdflkj (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES * 3/4   ),
        .ALIGNED    ( 1'b1                                     ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB            ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS       ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL * 3/4 )
    ) axis_out_dvbs2x_filtered (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES * 3   ),
        .ALIGNED    ( 1'b1                                   ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB          ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS     ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL * 3 )
    ) axis_out_dvbs2x_filtered_lcm (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALIGNED    ( 1'b1                               ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x_filtered_full (
        .clk     ( mod_clk_ifc.clk       ),
        .sresetn ( mod_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALIGNED    ( 1'b1                               ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x_pre_fir_txsdr_clk (
        .clk     ( txsdr_clk_ifc.clk       ),
        .sresetn ( txsdr_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES         ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALLOW_BACKPRESSURE ( 0                                  ),
        .ALIGNED            ( 1'b1                               ),
        .NB                 ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS         ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL         ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) axis_out_dvbs2x [0:0] (
        .clk     ( txsdr_clk_ifc.clk       ),
        .sresetn ( txsdr_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES   ),
        .ALIGNED    ( 1'b1                               ),
        .NB         ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
        .N_CHANNELS ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
        .N_PARALLEL ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL )
    ) txsdr_samples_out [0:0] (
        .clk     ( txsdr_clk_ifc.clk       ),
        .sresetn ( txsdr_sresetn_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES ( ADC_AD9697_PCUHDR_PKG::DATABYTES  ),
        .NB         ( ADC_AD9697_PCUHDR_PKG::JESD_N     ),
        .NB_FRAC    ( 0                                 ),
        .N_CHANNELS ( ADC_AD9697_PCUHDR_PKG::JESD_M     ),
        .N_PARALLEL ( ADC_AD9697_PCUHDR_PKG::N_PARALLEL ),
        .ALIGNED    ( 1'b1                              ),
        .ALLOW_BACKPRESSURE ( 0                         )
    ) axis_adc_samples [0:0] (
        .clk    ( adc_sample_clk_ifc.clk       ),
        .sresetn( adc_sample_sreset_ifc.reset != adc_sample_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( ADC_AD9697_PCUHDR_PKG::DATABYTES  ),
        .NB         ( ADC_AD9697_PCUHDR_PKG::JESD_N     ),
        .NB_FRAC    ( 0                                 ),
        .N_CHANNELS ( ADC_AD9697_PCUHDR_PKG::JESD_M     ),
        .N_PARALLEL ( ADC_AD9697_PCUHDR_PKG::N_PARALLEL ),
        .ALIGNED    ( 1'b1                              ),
        .ALLOW_BACKPRESSURE ( 0                         )
    ) axis_demod_samples [0:0] (
        .clk     ( adc_sample_clk_ifc.clk      ),
        .sresetn ( adc_sample_sreset_ifc.reset != adc_sample_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_deframer_result_out (
        .clk    ( adc_sample_clk_ifc.clk       ),
        .sresetn( adc_sample_sreset_ifc.reset != adc_sample_sreset_ifc.ACTIVE_HIGH )
    );

    // Resampling interpolation signals
    logic signed [axis_out_dvbs2x_raw.NB-1:0]       axis_out_dvbs2x_pre_fir_samples           [0:axis_out_dvbs2x_raw.N_CHANNELS-1]       [0:axis_out_dvbs2x_raw.N_PARALLEL-1];
    logic signed [axis_out_dvbs2x_upsampled.NB-1:0] axis_out_dvbs2x_pre_fir_samples_upsampled [0:axis_out_dvbs2x_upsampled.N_CHANNELS-1] [0:axis_out_dvbs2x_upsampled.N_PARALLEL-1];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AMP Control


    // PMBus
    logic [7:0] pmbus_gpio_i;
    logic [7:0] pmbus_gpio_o;
    logic [7:0] pmbus_gpio_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AMP


    // PA Bias Control
    logic pa_bias_initdone;
    logic pa_bias_cal_active;
    // Signal from PA bias controller to synth to power it down
    logic lo_tx_power_down;
    // Signal from synth to PA bias controller, indicating that it is powered on
    logic lo_tx_enabled;

    // Power Monitors
    logic amp_cpm_alert_n_reg;
    logic amp_cpm_initdone;
    logic amp_cpm_active_fault;

    // Heater control
    logic amp_heater_en_hw;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Top-level Reset Controller


    board_pcuhdr_ctrl #(
        .MODULE_ID              ( AVMM_CTRL               ),
        .TRANCHE0               (`DEFINED(TRANCHE0)       ),
        .TRANCHE1               (`DEFINED(TRANCHE1)       ),
        .POWER_TO_RESET_CYCLES  ( 32'd15625000            ), // 100 ms @ 156.25 MHz
        .DEFAULT_ENABLE_LNA     (`DEFINED(LNA_EN_ON_RESET))
    ) board_pcuhdr_ctrl_inst (
        .clk_ifc                            ( clk_ifc_ps_156_25.Input                   ),
        .interconnect_sreset_ifc            ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
        .peripheral_sreset_ifc              ( peripheral_sreset_ifc_ps_156_25.ResetIn   ),

        .avmm                               ( avmm_device_ifc[AVMM_CTRL]                ),

        .card_id                            ( card_id                                   ),
        .amp_heater_en_hw                   ( amp_heater_en_hw                          ),
        .amp_cpm_alert_n                    ( amp_cpm_alert_n                           ),
        .amp_cpm_active_fault               ( amp_cpm_active_fault                      ),

        .amp_cpm_alert_n_reg                ( amp_cpm_alert_n_reg                       ),

        .rx_pwr_en_sresetn_ifc_156_25       ( rx_pwr_en_sresetn_ifc_156_25.ResetOut     ),
        .rx_peripheral_sreset_ifc_156_25    ( rx_peripheral_sreset_ifc_156_25.ResetOut  ),
        .tx_pwr_en_sresetn_ifc_156_25       ( tx_pwr_en_sresetn_ifc_156_25.ResetOut     ),
        .tx_peripheral_sreset_ifc_156_25    ( tx_peripheral_sreset_ifc_156_25.ResetOut  ),

        .if_sel                             ( if_sel                                    ),
        .loopback_sel                       ( mux_sel                                   ),
        .amp_master_en                      ( amp_master_en                             ),
        .amp_pa_en                          ( amp_pa_en                                 ),
        .amp_heater_en                      ( amp_heater_en                             ),
        .amp_i2c_en                         ( amp_i2c_en                                ),
        .uuid_i2c_en                        ( uuid_i2c_en                               ),
        .lna_en                             ( lna_en                                    ),
        .amp_fram_wp_en_t                   ( amp_fram_wp_en_t                          ),

        .lmk_initdone                       ( lmk_ctrl.initdone                         ),
        .ppl_initdone                       ( ppl_aur_ctrl.initdone                     ),
        .rx_initdone                        ( rx_initdone                               ),
        .tx_initdone                        ( tx_initdone                               ),
        .pa_bias_initdone                   ( pa_bias_initdone                          ),
        .cpm_initdone                       ( amp_cpm_initdone                          ),

        .amp_fram_wp_en_i                   ( amp_fram_wp_en_i                          ),
        .amp_heater_en_t                    ( amp_heater_en_t                           )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Free running microsecond counter


    util_stopwatch #(
        .CLOCK_SOURCE ( 125 ),
        .COUNT_WIDTH  ( 64  ),
        .AUTO_START   ( 1   )
    ) free_us_counter_inst (
        .clk              ( clk_ifc_ps_125.clk                 ),
        .rst              ( interconnect_sreset_ifc_ps_125.reset ),
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
        .avmm_out        ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_SPI]    ),
        .clock_ifc_avmm  ( clk_ifc_ps_156_25                               ),
        .sreset_ifc_avmm ( interconnect_sreset_ifc_ps_156_25.ResetIn       ),
        .clock_ifc_axis  ( clk_ifc_ps_156_25                               ),
        .sreset_ifc_axis ( interconnect_sreset_ifc_ps_156_25.ResetIn       ),

        .axis_out ( axis_spi_to_avmm_loopback.Master ), // ENABLE_AXIS=0, so just looped back to avoid undriven pin warnings
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
        .clk_ifc                 ( clk_ifc_ps_156_25                          ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn  ),
        .avmm_in                 ( avmm_masters_to_arbiter_ifc                ),
        .avmm_out                ( avmm_arbiter_to_unburst_ifc.Master         ),
        .read_active_mask        (  ),
        .write_active_mask       (  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Unburst


    avmm_unburst #(
        .ADDRESS_INCREMENT ( 0 ),
        .DEBUG_ILA         ( 0 )
    ) avmm_unburst_arbiter_to_demux (
        .clk_ifc                 ( clk_ifc_ps_156_25                         ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
        .avmm_in                 ( avmm_arbiter_to_unburst_ifc.Slave         ),
        .avmm_out                ( avmm_unburst_to_demux_ifc.Master          )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Demux


    avmm_demux #(
        .NUM_DEVICES        ( AVMM_NDEVS      ),
        .ADDRLEN            ( AVMM_ADDRLEN    ),
        .DEVICE_ADDR_OFFSET ( DEV_OFFSET      ),
        .DEVICE_ADDR_WIDTH  ( DEV_WIDTH       ),
        .DEBUG_ILA          ( 0               ),
        .DEBUG_DEVICE_NUM   ( AVMM_ADDRS_ROM  )
    ) avmm_demux_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                         ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
        .avmm_in                 ( avmm_unburst_to_demux_ifc.Slave           ),
        .avmm_out                ( avmm_device_ifc                           )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Bad Address Responder


    avmm_bad avmm_bad_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                         ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
        .avmm                    ( avmm_device_ifc[AVMM_NDEVS]               )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM ROM


    avmm_rom #(
        .MODULE_VERSION ( 1                                      ),
        .MODULE_ID      ( AVMM_ADDRS_ROM+1                       ),
        .ROM_FILE_NAME  ( "board_pcuhdr_avmm_addrs_rom_init.hex" ),
        .ROM_DEPTH      ( AVMM_ROM_DEPTH                         ),
        .DEBUG_ILA      ( 0                                      )
    ) avmm_rom_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                         ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
        .avmm_in                 ( avmm_device_ifc[AVMM_ADDRS_ROM]           )
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
        .avmm_in            ( avmm_device_ifc[AVMM_SEM]         )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM to AVMM


    avmm_to_avmm #(
        .MODULE_VERSION     ( 1                 ),
        .MODULE_ID          ( AVMM_PS_MASTER+1  ),
        .DEBUG_ILA          ( 0                 )
    ) avmm_to_avmm_ps_master_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                                   ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25                   ),
        .avmm_in                 ( avmm_device_ifc[AVMM_PS_MASTER]                     ),
        .avmm_out                ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Master )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM INIT CTRL


    assign avmm_init_ctrl_ps_master_init_values_ifc.init_regs = '{
        '{49'hFFCA3008, 32'h0000, '1, '0 } // Set pcap_pr field to ICAP/MCAP for SEM
    };

    avmm_init_ctrl #(
        .ILA_DEBUG ( 0 )
    ) avmm_init_ctrl_ps_master_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25                                    ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25                    ),
        .avmm_upstream           ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Slave   ),
        .avmm_downstream         ( avmm_init_ctrl_to_ps_master_ifc.Master               ),
        .avmm_init_ctrl_ifc      ( avmm_init_ctrl_ps_master_init_values_ifc             ),
        .pre_req                 ( 1'b1                                                 ),
        .initdone                (                                                      )
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
        .avmm_in                 ( avmm_device_ifc[AVMM_GIT_INFO]    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: GPIO


    // The HDR currently does not use blade_sync at all
    assign blade_sync_out = 1'b0;

    // blade_gpio carries LVDS SGMII lanes and some misc GPIO: currently unused
    assign blade_gpio_t = '1;
    assign blade_gpio_o = 'X;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: LMK


    SPIDriver_int #(
        .MAXLEN ( 32 ),
        .SSNLEN ( 1  )
    ) lmk_spi_drv_ifc [0:0] (
        .clk     (  clk_ifc_ps_156_25.clk                 ),
        .sresetn ( peripheral_sresetn_ifc_ps_156_25.reset )
    );

    SDR_Ctrl_int #(
        .STATELEN ( 1 )
    ) lmk_ctrl (
        .clk ( clk_ifc_ps_156_25.clk )
    );

    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_lmkclk_ifc, avmm_device_ifc[AVMM_FE_LMKCLK], 1, AVMM_FE_LMKCLK+1, 14, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, lmk_ctrl.initdone);

    // LMK must come up on startup, since it's used to generate the PPL clock
    assign lmk_ctrl.sresetn = peripheral_sresetn_ifc_ps_156_25.reset;

    // TODO(wkingsford): As far as I can tell, this just triggers SYSREF, so should be fine even if TX is disabled. Check PPL with TX disabled, then delete this comment
    assign lmk.syncreq  = (dac.ctrl_sysref_req & dac.start_sysref);

    clk_lmk0482x_ctrl #(
        .MMI_DATALEN           ( MMI_DATALEN ),
        .SPI_SS_BIT            ( 0           ),
        .INIT_HEARTBEAT_TOGGLE ( 1           ),
        .HEARTBEAT_HALF_PERIOD ( 78125000    ), // Half of 156.25 MHz
        .READ_BEFORE_INIT      ( 1           )
    ) clk_lmk0482x_ctrl_inst (
        .sdr ( lmk_ctrl             ),
        .lmk ( lmk                  ),
        .mmi ( mmi_lmkclk_ifc.Slave ),
        .spi ( lmk_spi_drv_ifc[0]   )
    );

    spi_mux #(
        .N      ( 1 ),
        .MAXLEN ( 32 )
    ) lmk_spi_mux (
        .spi_in ( lmk_spi_drv_ifc       ),
        .spi_io ( lmk_spi               )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PLLs


    generate
        if (`DEFINED(TX_MOD_ON_DAC_CLK)) begin : gen_mod_clk
            // Encode symbol rate div based on what clock the modulator is driven by
            localparam int SYMBOL_RATE_DIV = 4;

            enum {
                TX_PLL_IDX_DAC,
                NUM_TX_PLL_CLKS
            } tx_pll_idx_t;

            localparam int TX_PLL_DIVIDE [0:NUM_TX_PLL_CLKS-1] = '{8};

            // Modulator on dac_clk
            assign mod_clk_ifc.clk       = txsdr_clk_ifc.clk;
            assign mod_sresetn_ifc.reset = txsdr_sresetn_ifc.reset;
        end else begin : gen_mod_clk
            localparam int SYMBOL_RATE_DIV = 3;

            enum {
                TX_PLL_IDX_DAC,
                TX_PLL_IDX_MOD,
                NUM_TX_PLL_CLKS
            } tx_pll_idx_t;

            localparam int TX_PLL_DIVIDE [0:NUM_TX_PLL_CLKS-1] = '{8, 6};

            // Modulator on 200 MHz clock
            assign mod_clk_ifc.clk = tx_pll.clk_out[TX_PLL_IDX_MOD];

            // dac_jesd_aresetn_ifc.reset, synchronized to mod_clk_ifc: this can still be asserted asynchronously, so needs an
            // additional synchronizer stage to make a synchronous reset
            logic mod_sresetn_ifc_reset_i;

            xclock_resetn #(
                .INPUT_REG ( 0 )
            ) xclock_mod_rst_async (
                .tx_clk     ( 1'b0                          ),
                .resetn_in  ( dac_jesd_aresetn_ifc.reset    ), // Async reset in (comes from the JESD204C core)
                .rx_clk     ( mod_clk_ifc.clk               ),
                .resetn_out ( mod_sresetn_ifc_reset_i       )  // Async reset out
            );

            xclock_sig #(
                .INPUT_REG ( 0 )
            ) xclock_mod_rst_sync (
                .tx_clk     ( mod_clk_ifc.clk           ),
                .sig_in     ( mod_sresetn_ifc_reset_i   ), // Async reset in
                .rx_clk     ( mod_clk_ifc.clk           ),
                .sig_out    ( mod_sresetn_ifc.reset     )  // Sync reset out
            );
        end
    endgenerate

    // NOTE: dac.clk is an output of the JESD204c core, instantiated in board_pcuhdr_tx
    PhaseLockedLoop_int # (
        .CLKIN_PERIOD ( 6.667                       ),
        .CLKFB_MULT_F ( 8                           ),
        .N_CLKS       ( gen_mod_clk.NUM_TX_PLL_CLKS ),
        .DIVIDE       ( gen_mod_clk.TX_PLL_DIVIDE   ),
        .DEVICE_TYPE  ( 2                           )
    ) tx_pll (
        .clk     ( dac.clk     ),
        .reset_n ( dac.sresetn )
    );

    assign txsdr_clk_ifc.clk       = tx_pll.clk_out[gen_mod_clk.TX_PLL_IDX_DAC];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: TXSDR


    // (wkingsford): PPL DVB-S2X: connect to PPL
    assign axis_in_dvbs2x.tdata  = '0;
    assign axis_in_dvbs2x.tvalid = '1;
    assign axis_in_dvbs2x.tstrb  = '1;
    assign axis_in_dvbs2x.tkeep  = '1;
    assign axis_in_dvbs2x.tid    = '0;
    assign axis_in_dvbs2x.tdest  = '0;
    assign axis_in_dvbs2x.tuser  = '0;

    // Set tlast once every WORDS_PER_FRAME accepted words
    localparam int WORDS_PER_FRAME = 1000;
    logic [$clog2(WORDS_PER_FRAME)-1:0] word_cntr;

    // TODO(wkingsford): PPL DVB-S2X: this should be on the Aurora clock instead
    always_ff @(posedge clk_ifc_ps_156_25.clk) begin
        if (tx_peripheral_sreset_ifc_156_25.reset) begin
            word_cntr <= '0;
        end else begin
            if (axis_in_dvbs2x.tvalid && axis_in_dvbs2x.tready) begin
                if (word_cntr == WORDS_PER_FRAME-1) begin
                    word_cntr <= '0;
                end else begin
                    word_cntr <= word_cntr + 1'b1;
                end
            end
        end
    end

    assign axis_in_dvbs2x.tlast = word_cntr == WORDS_PER_FRAME-1;

    // TX DVB-S2x Modulator
    generate
        if (`DEFINED(ENABLE_TX_MOD)) begin : gen_tx_mod
            logic dvbs2x_data_initdone;
            logic dvbs2x_mod_initdone_mod_clk;
            logic dvbs2x_mod_initdone;

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_dvbs2x_data,
                avmm_device_ifc[AVMM_TX_DVBS2X_DATA_FRAMER],
                1,
                AVMM_TX_DVBS2X_DATA_FRAMER,
                14,
                clk_ifc_ps_156_25,
                interconnect_sreset_ifc_ps_156_25,
                tx_peripheral_sreset_ifc_156_25.reset,
                dvbs2x_data_initdone
            );

            assign dvbs2x_data_initdone = !tx_peripheral_sreset_ifc_156_25.reset; // Ready if not in reset

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_dvbs2x_mod,
                avmm_device_ifc[AVMM_TX_DVBS2X_MOD],
                1,
                AVMM_TX_DVBS2X_MOD,
                7, // Note this is 7 for the mmi_to_mmi_v2 regs
                clk_ifc_ps_156_25,
                interconnect_sreset_ifc_ps_156_25,
                tx_peripheral_sreset_ifc_156_25.reset,
                dvbs2x_mod_initdone
            );

            dvbs2x_tx #(
                .FIFO_DEPTH          ( `TX_DVBS2X_FIFO_DEPTH              ),
                .TXNBITS             ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
                .MMI_DATALEN         ( mmi_dvbs2x_data.DATALEN            ),
                .ENABLE_DUMMY_FRAMES (`DEFINED(ENABLE_TX_MOD_DUMMY_FRAMES))
            ) dvbs2x_tx_inst (
                .clk_sample          (  mod_clk_ifc.clk                       ),
                .sample_resetn       (  mod_sresetn_ifc.reset                 ),
                .clk_sdr             (  clk_ifc_ps_156_25.clk                 ),
                .sdr_resetn          ( ~tx_peripheral_sreset_ifc_156_25.reset ),
                .axis_in             (  axis_in_dvbs2x.Slave                  ),
                .axis_out            (  axis_out_dvbs2x_raw.Master            ),
                .mmi_dvbs2x_data     (  mmi_dvbs2x_data.Slave                 ),
                .mmi_dvbs2x_mod      (  mmi_dvbs2x_mod.Slave                  ),
                .dvbs2x_mod_initdone (  dvbs2x_mod_initdone_mod_clk           )
            );

            always_comb begin
                for (int c = 0; c < BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS; c++) begin
                    mod_gain[c] = 16'd15565; // Gain of 0.95001220703125
                end
            end

            // Scales modulator output samples by ~0.95 to avoid overflow
            axis_sample_gain #(
                .N_CHANNELS     ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS ),
                .GAIN_NB        ( BOARD_PCUHDR_TXSDR_PKG::TX_NB      ),
                .GAIN_NB_FRAC   ( BOARD_PCUHDR_TXSDR_PKG::TX_NB-2    ),
                .INPUT_GAIN_REG ( 1'b1                               )
            ) axis_mod_gain (
                .clk_ifc     ( mod_clk_ifc                   ),
                .sreset_ifc  ( mod_sresetn_ifc               ),
                .axis_in     ( axis_out_dvbs2x_raw.Slave     ),
                .axis_out    ( axis_out_dvbs2x_scaled.Master ),
                .gain        ( mod_gain                      )
            );

            xclock_sig xclock_dvbs2x_mod_initdone (
                .tx_clk  ( mod_clk_ifc.clk             ),
                .sig_in  ( dvbs2x_mod_initdone_mod_clk ),
                .rx_clk  ( clk_ifc_ps_156_25.clk       ),
                .sig_out ( dvbs2x_mod_initdone         )
            );

            if (`DEFINED(TX_MOD_ON_DAC_CLK)) begin : gen_mod_clk_on_dac_clk
                axis_connect axis_connect_mod_to_dac_clk_inst (
                    .axis_in  ( axis_out_dvbs2x_pre_fir.Slave            ),
                    .axis_out ( axis_out_dvbs2x_pre_fir_txsdr_clk.Master )
                );
            end else begin : gen_mod_clk_off_dac_clk
                localparam int N_PARALLEL_RESAMPLE = BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL*3/4;

                // 33 bit fir_compiler output is extended to the nearest byte boundary (40 bits)
                localparam int FILTER_OUT_NB = 40;

                // Maximum fifo depth that uses less than half a BRAM, 18Kb/(32 bits per word * 8 parallel) = 72 rounded down to nearest power of two
                localparam int FIFO_DEPTH = 64;

                logic [BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS*N_PARALLEL_RESAMPLE*FILTER_OUT_NB-1:0] axis_fir_out_4x_downsample_tdata_33b;

                // Upsampling by a factor of 3 by inserting 2 dummy samples for every axis sample per clock cycle
                always_comb begin
                    axis_out_dvbs2x_pre_fir_samples = axis_out_dvbs2x_pre_fir.tdata_to_samples();

                    for (int p = 0; p < BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL; p++) begin
                        for (int c = 0; c < BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS; c++) begin
                            axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p]     = axis_out_dvbs2x_pre_fir_samples[c][p];
                            axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p + 1] = '0;
                            axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p + 2] = '0;
                        end
                    end

                    axis_out_dvbs2x_upsampled.tdata = axis_out_dvbs2x_upsampled.samples_to_tdata(axis_out_dvbs2x_pre_fir_samples_upsampled);
                end

                assign axis_out_dvbs2x_upsampled.tvalid = axis_out_dvbs2x_scaled.tvalid;
                assign axis_out_dvbs2x_upsampled.tstrb  = axis_out_dvbs2x_scaled.tstrb;
                assign axis_out_dvbs2x_upsampled.tkeep  = axis_out_dvbs2x_scaled.tkeep;
                assign axis_out_dvbs2x_upsampled.tlast  = axis_out_dvbs2x_scaled.tlast;
                assign axis_out_dvbs2x_upsampled.tid    = axis_out_dvbs2x_scaled.tid;
                assign axis_out_dvbs2x_upsampled.tdest  = axis_out_dvbs2x_scaled.tdest;
                assign axis_out_dvbs2x_upsampled.tuser  = axis_out_dvbs2x_scaled.tuser;
                assign axis_out_dvbs2x_scaled.tready    = axis_out_dvbs2x_upsampled.tready;

                // Low-pass filter and decimation from 24 parallel samples to 6 parallel samples
                fir_compiler_mod_4x_downsample fir_compiler_mod_4x_downsample_inst (
                    .aclk               ( mod_clk_ifc.clk                      ),
                    .s_axis_data_tvalid ( axis_out_dvbs2x_upsampled.tvalid     ),
                    .s_axis_data_tready ( axis_out_dvbs2x_upsampled.tready     ),
                    .s_axis_data_tdata  ( axis_out_dvbs2x_upsampled.tdata      ),
                    .m_axis_data_tvalid ( axis_out_dvbs2x_filtered.tvalid      ),
                    .m_axis_data_tready ( axis_out_dvbs2x_filtered.tready      ),
                    .m_axis_data_tdata  ( axis_fir_out_4x_downsample_tdata_33b ) // assumes FIR compiler is configured for 33b output sample width
                );

                // Tie off signals that do not go through filter
                assign axis_out_dvbs2x_filtered.tstrb = '1;
                assign axis_out_dvbs2x_filtered.tkeep = '1;
                assign axis_out_dvbs2x_filtered.tlast = '0;
                assign axis_out_dvbs2x_filtered.tid   = '0;
                assign axis_out_dvbs2x_filtered.tdest = '0;
                assign axis_out_dvbs2x_filtered.tuser = '0;

                // TODO: Temporarily truncate FIR output. Replace with general convergent rounding module when complete
                always_comb begin
                    for (int p = 0; p < N_PARALLEL_RESAMPLE; p++) begin
                        for (int c = 0; c < BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS; c++) begin
                            axis_out_dvbs2x_filtered.tdata[BOARD_PCUHDR_TXSDR_PKG::TX_NB*(BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS*p + c) +: BOARD_PCUHDR_TXSDR_PKG::TX_NB]
                                = axis_fir_out_4x_downsample_tdata_33b[FILTER_OUT_NB*(BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS*p + c) + MOD_RESAMPLE_NB_FRAC +: BOARD_PCUHDR_TXSDR_PKG::TX_NB];
                        end
                    end
                end

                // Repackage AXI-Stream samples from 6 parallel samples to 8 parallel samples with the samples
                // being valid three every four clock cycles

                // The adapter must go from 6 -> 24 -> 8 because the conversion must be an integer multiple/factor
                axis_adapter_wrapper axis_adapter_6_to_24_inst (
                    .axis_in  ( axis_out_dvbs2x_filtered     ),
                    .axis_out ( axis_out_dvbs2x_filtered_lcm )
                );

                axis_adapter_wrapper axis_adapter_24_to_8_inst (
                    .axis_in  ( axis_out_dvbs2x_filtered_lcm  ),
                    .axis_out ( axis_out_dvbs2x_filtered_full )
                );

                // CDC for axis samples from mod_clk to txsdr_clk
                axis_async_fifo_wrapper #(
                    .DEPTH          ( FIFO_DEPTH ),
                    .KEEP_ENABLE    ( 1'b0       ),
                    .LAST_ENABLE    ( 1'b0       ),
                    .ID_ENABLE      ( 1'b0       ),
                    .DEST_ENABLE    ( 1'b0       ),
                    .USER_ENABLE    ( 1'b0       ),
                    .FRAME_FIFO     ( 1'b0       ),
                    .DROP_WHEN_FULL ( 1'b0       )
                ) axis_async_fifo_wrapper_mod_to_dac_inst (
                    .axis_in             ( axis_out_dvbs2x_filtered_full.Slave      ),
                    .axis_out            ( axis_out_dvbs2x_pre_fir_txsdr_clk.Master ),
                    .axis_in_overflow    ( overflow_mod_clk                         ),
                    .axis_in_bad_frame   ( bad_frame_mod_clk                        ),
                    .axis_in_good_frame  ( good_frame_mod_clk                       ),
                    .axis_out_overflow   ( overflow_dac_clk                         ),
                    .axis_out_bad_frame  ( bad_frame_dac_clk                        ),
                    .axis_out_good_frame ( good_frame_dac_clk                       )
                );
            end

            // Adjustable TX symbol rate
            dvbs2x_tx_symb_rate_divider #(
                .MODULE_ID         ( AVMM_TX_SYMB_RATE_DIVIDER+1 ),
                .SYMBOL_RATE_DIV   ( gen_mod_clk.SYMBOL_RATE_DIV )
            ) dvbs2x_tx_symb_rate_divider_inst (
                .clk_ifc_sample               ( txsdr_clk_ifc.Input                           ),
                .sreset_ifc_sample_device     ( txsdr_sresetn_ifc.ResetIn                     ),
                .clk_ifc_avmm                 ( clk_ifc_ps_156_25.Input                       ),
                .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25.ResetIn     ),
                .sreset_ifc_avmm_peripheral   ( tx_peripheral_sreset_ifc_156_25.ResetIn       ),
                .axis_in_dvbs2x               ( axis_out_dvbs2x_pre_fir_txsdr_clk.Slave       ),
                .axis_out_dvbs2x              ( axis_out_dvbs2x[0].Master                     ),
                .avmm                         ( avmm_device_ifc[AVMM_TX_SYMB_RATE_DIVIDER]    )
            );

        end else begin : no_tx_mod
            avmm_nul_slave no_avmm_dvbs2x_data  ( .avmm ( avmm_device_ifc[AVMM_TX_DVBS2X_DATA_FRAMER] ) );
            avmm_nul_slave no_avmm_dvbs2x_mod   ( .avmm ( avmm_device_ifc[AVMM_TX_DVBS2X_MOD]         ) );
            avmm_nul_slave no_avmm_tx_symb_rate ( .avmm ( avmm_device_ifc[AVMM_TX_SYMB_RATE_DIVIDER]  ) );
            axis_nul_sink  no_axis_in_dvbs2x    ( .axis ( axis_in_dvbs2x.Slave                        ) );
            axis_nul_src   no_axis_src_dvbs2x   ( .axis ( axis_out_dvbs2x[0].Master                   ) );
        end
    endgenerate


    // TX Equalization FIR
    generate
        if (`DEFINED(ENABLE_TX_EQ)) begin : gen_tx_eq
            axis_sample_complex_filter_avmm #(
                .MODULE_ID_COEFF_REAL ( AVMM_TX_EQ_REAL ),
                .MODULE_ID_COEFF_IMAG ( AVMM_TX_EQ_IMAG ),
                .NUM_COEFFS           ( 41 )
            ) axis_sample_complex_filter_avmm_inst (
                .clk_ifc_avmm ( clk_ifc_ps_156_25.Input ),
                .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
                .sreset_ifc_avmm_peripheral ( tx_peripheral_sreset_ifc_156_25.ResetIn ),

                .clk_ifc_axis    ( mod_clk_ifc.Input ),
                .sreset_ifc_axis ( mod_sresetn_ifc.ResetIn ),

                .axis_in    ( axis_out_dvbs2x_scaled.Slave  ),
                .axis_out   ( axis_out_dvbs2x_pre_fir.Master),

                .avmm_coeff_real    ( avmm_device_ifc[AVMM_TX_EQ_REAL] ),
                .avmm_coeff_imag    ( avmm_device_ifc[AVMM_TX_EQ_IMAG] )
            );
        end else begin : no_tx_eq
            axis_connect axis_connect_inst (
                .axis_in    ( axis_out_dvbs2x_scaled.Slave  ),
                .axis_out   ( axis_out_dvbs2x_pre_fir.Master)
            );

            avmm_nul_slave no_avmm_coeff_real ( .avmm ( avmm_device_ifc[AVMM_TX_EQ_REAL] ) );
            avmm_nul_slave no_avmm_coeff_imag ( .avmm ( avmm_device_ifc[AVMM_TX_EQ_IMAG] ) );
        end
    endgenerate

    // TX Common Stack
    generate
        if (`DEFINED(ENABLE_TX)) begin : gen_axis_tx_common
            // TX power detector and TX capture disabled in axis_tx_common. Tie off
            // unused AVMM interfaces
            AvalonMM_int avmm_nul_tx_capture ();
            AvalonMM_int avmm_nul_tx_pwr_det ();

            avmm_nul_master no_avmm_tx_capture ( .avmm ( avmm_nul_tx_capture.Master ) );
            avmm_nul_master no_avmm_tx_pwr_det ( .avmm ( avmm_nul_tx_pwr_det.Master ) );

            axis_tx_common #(
                .MODULE_ID                   ( AVMM_TX_COMMON+1                             ),
                .SAMPLE_RATE                 ( BOARD_PCUHDR_TXSDR_PKG::TXDAC_SAMPLE_RATE    ),
                .TX_REPLAY_BUFFER_DEPTH      ( `TX_REPLAY_BUFFER_DEPTH                      ),
                .MODULE_ID_TX_REPLAY         ( AVMM_TX_BUFFER+1                             ),
                .MODULE_ID_TX_NCO            ( AVMM_TX_NCO+1                                ),
                .ENABLE_TX_NCO_SIGNAL_SOURCE ( `DEFINED(ENABLE_TX_NCO_SIGNAL_SOURCE)        ),
                .ENABLE_TX_REPLAY            ( `DEFINED(ENABLE_TX_REPLAY_BUFFER)            ),
                .ENABLE_TX_POWER_DETECTOR    ( 1'b0                                         ),
                .ENABLE_TX_CAPTURE           ( 1'b0                                         ),
                .N_PARALLEL                  ( BOARD_PCUHDR_TXSDR_PKG::N_PARALLEL           ),
                .N_CHANNELS                  ( BOARD_PCUHDR_TXSDR_PKG::N_CHANNELS           ),
                .NB                          ( BOARD_PCUHDR_TXSDR_PKG::TX_NB                ),
                .NB_FRAC                     ( '0                                           ),
                .NBYTES                      ( BOARD_PCUHDR_TXSDR_PKG::TX_BYTES             )
            ) axis_tx_common_inst (
                .clk_ifc_avmm                 ( clk_ifc_ps_156_25.Input                    ),
                .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25.ResetIn  ),
                .sreset_ifc_avmm_device       ( tx_peripheral_sreset_ifc_156_25.ResetIn    ),

                .clk_ifc_sample               ( txsdr_clk_ifc.Input             ),
                .sreset_ifc_sample_device     ( txsdr_sresetn_ifc.ResetIn       ),

                .axis_sample_ins              ( axis_out_dvbs2x                 ),
                .axis_sample_outs             ( txsdr_samples_out               ),

                .avmm_tx_common               ( avmm_device_ifc[AVMM_TX_COMMON] ),
                .avmm_tx_replay               ( avmm_device_ifc[AVMM_TX_BUFFER] ),
                .avmm_tx_nco_signal_source    ( avmm_device_ifc[AVMM_TX_NCO]    ),
                .avmm_tx_capture              ( avmm_nul_tx_capture.Slave       ),
                .avmm_tx_power_detector       ( avmm_nul_tx_pwr_det.Slave       )
            );

            // Convert txsdr_samples_out from AXIS to SSI
            axis_to_ssi #(
                .ALIGNED ( 1'b1 )
            ) txsdr_samples_out_axis_to_ssi (
                .axis_in ( txsdr_samples_out[0]     ),
                .ssi_out ( ssi_dac.Source           )
            );
        end else begin : no_axis_tx_common
            axis_nul_sink  no_tx_axis_out_dvbs2x         ( .axis ( axis_out_dvbs2x[0]       ) );
            axis_nul_src   no_txsdr_samples_out          ( .axis ( txsdr_samples_out[0]     ) );
            ssi_nul_source no_ssi_dac                    ( .ssi  ( ssi_dac.Source           ) );

            avmm_nul_slave no_avmm_tx_common             ( .avmm ( avmm_device_ifc[AVMM_TX_COMMON] ) );
            avmm_nul_slave no_avmm_tx_replay             ( .avmm ( avmm_device_ifc[AVMM_TX_BUFFER] ) );
            avmm_nul_slave no_avmm_tx_nco_signal_source  ( .avmm ( avmm_device_ifc[AVMM_TX_NCO]    ) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: HDR FE


    board_pcuhdr_rx #(
        .ENABLE_RX              (`DEFINED(ENABLE_RX) ),
        .RX_ADC_CTRL_MODULE_ID  ( AVMM_RX_ADC_CTRL+1  ),
        .RX_ADC_DATA_MODULE_ID  ( AVMM_RX_ADC_JESD+1  ),
        .RX_AMP_CTRL_MODULE_ID  ( AVMM_RX_AMP+1  ),
        .RX_LO_CTRL_MODULE_ID   ( AVMM_RX_LO+1   )
    ) board_pcuhdr_rx_inst (
        .common_clk_ifc                  ( clk_ifc_ps_156_25.Input                    ),
        .common_peripheral_sreset_ifc    ( rx_peripheral_sreset_ifc_156_25.ResetIn    ),
        .common_interconnect_sreset_ifc  ( interconnect_sreset_ifc_ps_156_25.ResetIn  ),
        .clk_ifc_drp_125                 ( clk_ifc_ps_125.Input                       ),
        .interconnect_sreset_ifc_drp_125 ( interconnect_sreset_ifc_ps_125.ResetIn     ),
        .adc_sample_clk_ifc              ( adc_sample_clk_ifc.Output                  ),
        .adc_sample_sreset_ifc           ( adc_sample_sreset_ifc.ResetOut             ),
        .initdone                        ( rx_initdone                                ),
        .amp                             ( rx_amp.AmpCtrl                             ),
        .adc_ifc                         ( adc_ifc                                    ),
        .axis_adc_samples                ( axis_adc_samples[0].Master                 ),
        .adc_spi                         ( adc_spi                                    ),
        .vga_spi                         ( vga_spi                                    ),
        .lo_rx_spi                       ( lo_rx_spi                                  ),
        .lo_rx_lock_detect               ( lo_rx_lock_detect                          ),
        .avmm_adc_ctrl                   ( avmm_device_ifc[AVMM_RX_ADC_CTRL]          ),
        .avmm_adc_data                   ( avmm_device_ifc[AVMM_RX_ADC_JESD]          ),
        .avmm_amp_ctrl                   ( avmm_device_ifc[AVMM_RX_AMP]               ),
        .avmm_lo_rx                      ( avmm_device_ifc[AVMM_RX_LO]                )
    );

    board_pcuhdr_tx #(
        .ENABLE_TX              (`DEFINED(ENABLE_TX)  ),
        .TRANCHE1               (`DEFINED(TRANCHE1)   ),
        .FE_DIGIPOT_I2C_CLKDIV  ( 400                 ), // ~391 kHz
        .TX_DAC_CTRL_MODULE_ID  ( AVMM_TX_DAC_CTRL+1  ),
        .TX_DAC_DATA_MODULE_ID  ( AVMM_TX_DAC_JESD+1  ),
        .TX_LO_CTRL_MODULE_ID   ( AVMM_TX_LO+1        ),
        .TX_IQ_MOD_MODULE_ID    ( AVMM_TX_IQ_MOD+1    ),
        .TX_CTRL_ADC_MODULE_ID  ( AVMM_TX_CTRL_ADC+1  ),
        .TX_ALC_MODULE_ID       ( AVMM_TX_ALC+1       ),
        .TX_NANO_DAC_MODULE_ID  ( AVMM_TX_NANO_DAC+1  ),
        .TX_FE_DIGIPOT_MODULE_ID( AVMM_FE_TX_DIGIPOT+1)
    ) board_pcuhdr_tx_inst (
        .common_clk_ifc                 ( clk_ifc_ps_156_25.Input                    ),
        .common_peripheral_sreset_ifc   ( peripheral_sreset_ifc_ps_156_25.ResetIn    ),
        .tx_peripheral_sreset_ifc       ( tx_peripheral_sreset_ifc_156_25.ResetIn    ),
        .common_interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn  ),
        .dac_jesd_clk_ifc               ( dac_jesd_clk_ifc.Output                    ),
        .dac_jesd_aresetn_ifc           ( dac_jesd_aresetn_ifc.ResetOut              ),
        .drp_clk_ifc                    ( clk_ifc_ps_125.Input                       ),
        .initdone                       ( tx_initdone                                ),
        // TODO: remove this port, use dac.io_txenable instead
        .tx_enable                      (~pa_bias_cal_active                         ),
        .lo_tx_power_down               ( lo_tx_power_down                           ),
        .lo_tx_enabled                  ( lo_tx_enabled                              ),
        .dac_spi                        ( dac_spi                                    ),
        .tx_spi                         ( tx_spi                                     ),
        .fe_digipot_i2c                 ( digpot_i2c                                 ),
        .lo_tx_spi                      ( lo_tx_spi                                  ),
        .lo_tx_lock_detect              ( lo_tx_lock_detect                          ),
        .ssi_dac                        ( ssi_dac.Sink                               ),
        .dac                            ( dac                                        ),
        .avmm_dac_ctrl                  ( avmm_device_ifc[AVMM_TX_DAC_CTRL]          ),
        .avmm_dac_data                  ( avmm_device_ifc[AVMM_TX_DAC_JESD]          ),
        .avmm_lo_tx                     ( avmm_device_ifc[AVMM_TX_LO]                ),
        .avmm_iq_mod                    ( avmm_device_ifc[AVMM_TX_IQ_MOD]            ),
        .avmm_ctrl_adc                  ( avmm_device_ifc[AVMM_TX_CTRL_ADC]          ),
        .avmm_tx_alc                    ( avmm_device_ifc[AVMM_TX_ALC]               ),
        .avmm_nano_dac                  ( avmm_device_ifc[AVMM_TX_NANO_DAC]          ),
        .avmm_fe_digipot                ( avmm_device_ifc[AVMM_FE_TX_DIGIPOT]        )
    );

    pll_wrapper tx_pll_inst ( .pll ( tx_pll.Provider ) );

    // Active-low reset, so active-high enable. Note that this name is somewhat misleading: it just controls the tristate
    // mode of a couple of pins going to the DAC, as opposed to enabling/disabling the DAC itself.
    assign dac_enable = tx_pwr_en_sresetn_ifc_156_25.reset;

    // TODO(wkingsford): just tied off because of wrong modport for now. Later, need to implement LO leakage suppression
    assign dac.qmc_offset = '{default: '0};

    // This gets driven whenever the amp_lmh6401 module is in reset
    assign vga_pd  = rx_amp.pd;

    // Active-low reset, so invert it for the power-down signal
    assign adc_pdwn_stby = ~rx_pwr_en_sresetn_ifc_156_25.reset;

    // TODO(wkingsford): implement IQ mixer controller: also uses alarm_adrf6780 as input
    assign reset_adrf6780_n = tx_pwr_en_sresetn_ifc_156_25.reset;

    // Active-low resets, so active-high power enables
    assign lo_tx_spi_ce = tx_pwr_en_sresetn_ifc_156_25.reset;
    assign lo_rx_spi_ce = rx_pwr_en_sresetn_ifc_156_25.reset;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RXSDR


    // RX Common Stack
    generate
        if (`DEFINED(ENABLE_RX)) begin : gen_axis_rx_common
            axis_rx_common #(
                .MODULE_ID                         ( AVMM_RX_COMMON+1                           ),
                .SAMPLE_RATE                       ( PCUHDR_RXSDR_PKG::RX_ADC_OUPUT_SAMPLE_RATE ),
                .RX_CAPTURE_BUFFER_DEPTH           ( `RX_CAPTURE_BUFFER_DEPTH                   ),
                .MODULE_ID_RX_CAPTURE              ( AVMM_RX_FIFO+1                             ),
                .MODULE_ID_RX_PWRDET_PRE_GAIN      ( AVMM_RX_PWRDET_PRE_GAIN+1                  ),
                .MODULE_ID_RX_PWRDET_POST_GAIN     ( AVMM_RX_PWRDET_POST_GAIN+1                 ),
                .MODULE_ID_RX_AGC_DIGITAL          ( AVMM_RX_AGC_DIGITAL+1                      ),
                .ENABLE_RX_CAPTURE                 ( `DEFINED(ENABLE_RX_CAPTURE_BUFFER)         ),
                .ENABLE_RX_PWRDET_PRE_GAIN         ( `DEFINED(ENABLE_RX)                        ), // pre-gain pwrdet needed for AGC whenever RX is enabled
                .ENABLE_RX_PWRDET_POST_GAIN        ( `DEFINED(ENABLE_RX_PWRDET_POST_GAIN)       ),
                .ENABLE_RX_AGC_DIGITAL             ( `DEFINED(ENABLE_RX_AGC_DIGITAL)            ),
                .RX_AGC_DIGITAL_POWER_TARGET_LOWER ( 0                                          ), // set properly if/when needed
                .RX_AGC_DIGITAL_POWER_TARGET_UPPER ( '1                                         ), // set properly if/when needed
                .RX_AGC_DIGITAL_UPDATE_PERIOD      ( 1                                          ), // set properly if/when needed
                .NB                                ( ADC_AD9697_PCUHDR_PKG::JESD_N              ),
                .NB_FRAC                           ( '0                                         ),
                .N_CHANNELS                        ( ADC_AD9697_PCUHDR_PKG::JESD_M              ),
                .N_PARALLEL                        ( ADC_AD9697_PCUHDR_PKG::N_PARALLEL          ),
                .NBYTES                            ( ADC_AD9697_PCUHDR_PKG::DATABYTES           )
            ) axis_rx_common_inst (
                .clk_ifc_avmm                 ( clk_ifc_ps_156_25.Input                   ),
                .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
                .sreset_ifc_avmm_device       ( rx_peripheral_sreset_ifc_156_25.ResetIn   ),

                .clk_ifc_sample               ( adc_sample_clk_ifc.Input                  ),
                .sreset_ifc_sample_device     ( adc_sample_sreset_ifc.ResetIn             ),

                .axis_sample_ins              ( axis_adc_samples                          ),
                .axis_sample_outs             ( axis_demod_samples                        ),
                .power_pre_gain               ( rx_power                                  ),
                .power_pre_gain_valid_stb     ( rx_power_valid_stb                        ),
                .avmm_rx_common               ( avmm_device_ifc[AVMM_RX_COMMON]           ),
                .avmm_rx_capture              ( avmm_device_ifc[AVMM_RX_FIFO]             ),
                .avmm_rx_pwrdet_pregain       ( avmm_device_ifc[AVMM_RX_PWRDET_PRE_GAIN]  ),
                .avmm_rx_pwrdet_postgain      ( avmm_device_ifc[AVMM_RX_PWRDET_POST_GAIN] ),
                .avmm_rx_agc_digital          ( avmm_device_ifc[AVMM_RX_AGC_DIGITAL]      )
            );
        end else begin : no_axis_rx_common
            axis_nul_sink no_rx_axis_adc_samples      ( .axis ( axis_adc_samples[0].Slave    ) );
            axis_nul_src  no_rx_axis_demod_samples    ( .axis ( axis_demod_samples[0].Master ) );

            assign rx_power           = '{default: '0};
            assign rx_power_valid_stb = 1'b0;

            avmm_nul_slave no_avmm_rxsdr              ( .avmm ( avmm_device_ifc[AVMM_RX_COMMON]           ) );
            avmm_nul_slave no_avmm_rx_fifo            ( .avmm ( avmm_device_ifc[AVMM_RX_FIFO]             ) );
            avmm_nul_slave no_avmm_rx_pwrdet_pregain  ( .avmm ( avmm_device_ifc[AVMM_RX_PWRDET_PRE_GAIN]  ) );
            avmm_nul_slave no_avmm_rx_pwrdet_postgain ( .avmm ( avmm_device_ifc[AVMM_RX_PWRDET_POST_GAIN] ) );
        end
    endgenerate

    // RX DVB-S2x Demodulator
    dvbs2x_rx #(
        .DVBS2X_ON_ADC_CLK          ( 1'b1                                 ), // 1'b1 disables XCLOCKs, same clocks used below (for adc/dvbs2x_clk_ifc)
        .AVMM_ON_DVBS2X_CLK         ( 1'b0                                 ),

        .ENABLE_DEMOD               ( `DEFINED(ENABLE_RX_DEMOD)            ),
        .ENABLE_DEMOD_CAPTURE       ( `DEFINED(ENABLE_RX_DEMOD_CAPTURE)    ),
        .ENABLE_DECODER             ( `DEFINED(ENABLE_RX_DECODER)          ),
        .ENABLE_BB_FRAME_COUNTER    ( `DEFINED(ENABLE_RX_BB_FRAME_COUNTER) ),
        .ENABLE_BB_ERROR_COUNTER    ( `DEFINED(ENABLE_RX_BB_ERROR_COUNTER) ),

        .SHORT_FRAME_DECODER        ( 1'b1                                 ),

        .NB                         ( ADC_AD9697_PCUHDR_PKG::JESD_N        ),
        .NB_FRAC                    ( '0                                   ),
        .N_CHANNELS                 ( ADC_AD9697_PCUHDR_PKG::JESD_M        ),
        .N_PARALLEL                 ( ADC_AD9697_PCUHDR_PKG::N_PARALLEL    ),
        .NBYTES                     ( ADC_AD9697_PCUHDR_PKG::DATABYTES     ),

        .MODULE_ID_DEMOD            ( AVMM_DVBS2X_DEMOD+1                  ),
        .MODULE_ID_DEMOD_CTRL       ( AVMM_DVBS2X_DEMOD_CTRL+1             ),
        .MODULE_ID_DEMOD_CAPTURE    ( AVMM_DEMOD_CAPTURE+1                 ),
        .MODULE_ID_DECODER          ( AVMM_DVBS2X_DECODER+1                ),
        .MODULE_ID_DECODER_CTRL     ( AVMM_DVBS2X_DECODER_CTRL + 1         ),
        .MODULE_ID_DVBS2X_RX_DATA   ( AVMM_DVBS2X_RX_DATA+1                ),
        .MODULE_ID_DVBS2X_BB_FILT   ( AVMM_RX_DVBS2X_BB_FILT+1             ),
        .MODULE_ID_BB_FRAME_COUNTER ( AVMM_RX_BB_FRAME_COUNTER+1           ),
        .MODULE_ID_BB_ERROR_COUNTER ( AVMM_RX_BB_ERROR_COUNTER+1           )
    ) dvbs2x_rx_inst (
        .adc_clk_ifc                  ( adc_sample_clk_ifc.Input                      ),
        .adc_sreset_ifc               ( adc_sample_sreset_ifc.ResetIn                 ),
        .dvbs2x_clk_ifc               ( adc_sample_clk_ifc.Input                      ),
        .dvbs2x_sreset_ifc            ( adc_sample_sreset_ifc.ResetIn                 ),
        .avmm_clk_ifc                 ( clk_ifc_ps_156_25.Input                       ),
        .avmm_interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25.ResetIn     ),
        .avmm_peripheral_sreset_ifc   ( rx_peripheral_sreset_ifc_156_25.ResetIn       ),
        .axis_samples_in              ( axis_demod_samples[0].Slave                   ),
        .axis_data_out                ( axis_deframer_result_out.Master               ),
        .avmm_demod                   ( avmm_device_ifc[AVMM_DVBS2X_DEMOD]            ),
        .avmm_demod_ctrl              ( avmm_device_ifc[AVMM_DVBS2X_DEMOD_CTRL]       ),
        .avmm_demod_capture           ( avmm_device_ifc[AVMM_DEMOD_CAPTURE]           ),
        .avmm_decoder                 ( avmm_device_ifc[AVMM_DVBS2X_DECODER]          ),
        .avmm_decoder_ctrl            ( avmm_device_ifc[AVMM_DVBS2X_DECODER_CTRL]     ),
        .avmm_dvbs2x_rx_data          ( avmm_device_ifc[AVMM_DVBS2X_RX_DATA]          ),
        .avmm_dvbs2x_bb_filter        ( avmm_device_ifc[AVMM_RX_DVBS2X_BB_FILT]       ),
        .avmm_bb_frame_counter        ( avmm_device_ifc[AVMM_RX_BB_FRAME_COUNTER]     ),
        .avmm_bb_error_counter        ( avmm_device_ifc[AVMM_RX_BB_ERROR_COUNTER]     )
    );

    // TODO: PPL DVB-S2X: connect this to PPL
    axis_nul_sink no_deframer_out ( .axis ( axis_deframer_result_out.Slave ) );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUBSECTION: RX Automatic Gain Control (Analog)


    generate
        if (`DEFINED(ENABLE_RX)) begin : gen_rxagc_analog
            board_pcuhdr_rxagc #(
                .MODULE_ID     ( AVMM_RX_AGC_ANALOG+1        ),
                .N_CHANNELS    ( ADC_AD9697_PCUHDR_PKG::JESD_M )
            ) board_pcuhdr_rxagc_inst (
                .clk_ifc_adc                  ( adc_sample_clk_ifc.Input                  ),
                .sreset_ifc_adc               ( adc_sample_sreset_ifc.ResetIn             ),
                .clk_ifc_avmm                 ( clk_ifc_ps_156_25.Input                   ),
                .sreset_ifc_avmm_interconnect ( interconnect_sreset_ifc_ps_156_25.ResetIn ),
                .sreset_ifc_avmm_peripheral   ( rx_peripheral_sreset_ifc_156_25.ResetIn   ),
                .power                        ( rx_power                                  ),
                .power_valid_stb              ( rx_power_valid_stb                        ),
                .pwr_detector_initdone        (!rx_peripheral_sreset_ifc_156_25.reset     ),
                .amp_initdone                 ( rx_initdone                               ),
                .amp                          ( rx_amp.GainCtrl                           ),
                .avmm                         ( avmm_device_ifc[AVMM_RX_AGC_ANALOG]     )
            );
        end else begin : no_rxagc
            amp_lmh6401_no_gain_ctrl amp_lmh6401_no_gain_ctrl_inst ( .amp  ( rx_amp.GainCtrl                     ) );
            avmm_nul_slave           no_avmm_rx_agc_analog         ( .avmm ( avmm_device_ifc[AVMM_RX_AGC_ANALOG] ) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: HDR-FE EEPROM I2C control
    //
    // TODO(): all disconnected for now


    i2c_nul_io_drv no_uuid_i2c ( .drv ( uuid_i2c ) );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PCU PMBus control


    assign pmbus_gpio_i[0]   = pcu_pmbus_alert_n;
    assign pmbus_gpio_i[1]   = pcu_pmbus_control;
    assign pcu_pmbus_control = pmbus_gpio_t[1] ? 1'bZ : pmbus_gpio_o[1]; // According to schematic, this signal will only be read by the SOC. Therefore the default tristate setting is 1 in the block design.

    assign pcu_soc_pmbus_en = pmbus_gpio_o[7];
    assign pmbus_gpio_i[7]  = pmbus_gpio_o[7]; // output read-back


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: HDR-FE PMBus control


    // All pulled high on the board
    assign pmbus_gpio_i[2]  = fe_pmbus_alert_n;
    assign pmbus_gpio_i[3]  = fe_pmbus_control;
    assign fe_pmbus_control = pmbus_gpio_t[3] ? 1'bZ : pmbus_gpio_o[3];
    assign fe_pmbus_reset_n = pmbus_gpio_o[4];
    assign pmbus_gpio_i[4]  = pmbus_gpio_o[4]; // output read-back


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: HDR-AMP TX control


    board_pcuhdr_amp #(
        .AMP_DIGIPOT_MODULE_ID    ( AVMM_AMP_TX_DIGIPOT + 1                ),
        .AMP_ADC_MODULE_ID        ( AVMM_AMP_TX_ADC + 1                    ),
        .AMP_PA_BIAS_MODULE_ID    ( AVMM_AMP_TX_PA_BIAS + 1                ),
        .AMP_CPM_5V0_MODULE_ID    ( AVMM_AMP_TX_5V0_CPM + 1                ),
        .AMP_CPM_6V0_MODULE_ID    ( AVMM_AMP_TX_6V0_CPM + 1                ),
        .AMP_CPM_20V0_MODULE_ID   ( AVMM_AMP_TX_20V0_CPM + 1               ),
        .RUN_PA_BIAS_CAL_ON_RESET ( `DEFINED(RUN_PA_BIAS_CAL_ON_RESET)     ),
        .TRANCHE0                 ( `DEFINED(TRANCHE0)                     ),
        .TRANCHE1                 ( `DEFINED(TRANCHE1)                     )
    ) board_pcuhdr_amp_inst (
        .clk_ifc                         ( clk_ifc_ps_156_25.Input                   ),
        .peripheral_sreset_ifc           ( peripheral_sreset_ifc_ps_156_25.ResetIn   ),
        .interconnect_sreset_ifc         ( interconnect_sreset_ifc_ps_156_25.ResetIn ),

        .amp_i2c                         ( amp_i2c                               ),

        .avmm_digipot                    ( avmm_device_ifc[AVMM_AMP_TX_DIGIPOT]  ),
        .avmm_adc                        ( avmm_device_ifc[AVMM_AMP_TX_ADC]      ),
        .avmm_pa_bias                    ( avmm_device_ifc[AVMM_AMP_TX_PA_BIAS]  ),
        .avmm_cpm_5v0                    ( avmm_device_ifc[AVMM_AMP_TX_5V0_CPM]  ),
        .avmm_cpm_6v0                    ( avmm_device_ifc[AVMM_AMP_TX_6V0_CPM]  ),
        .avmm_cpm_20v0                   ( avmm_device_ifc[AVMM_AMP_TX_20V0_CPM] ),

        .cpm_alert_n                     ( amp_cpm_alert_n_reg                   ),
        .cpm_initdone                    ( amp_cpm_initdone                      ),
        .cpm_active_fault                ( amp_cpm_active_fault                  ),

        .lo_tx_disabled                  ( ~lo_tx_enabled                        ),
        .pa_bias_cal_active              ( pa_bias_cal_active                    ),
        .pa_bias_initdone                ( pa_bias_initdone                      ),
        .amp_heater_en                   ( amp_heater_en_hw                      )
    );

    assign lo_tx_power_down = pa_bias_cal_active;

    // PMBus GPIOs for HDR-AMP.
    assign pmbus_gpio_i[5]     = amp_pmbus_alert_n;
    assign pmbus_gpio_i[6]     = amp_pmbus_control_i;
    assign amp_pmbus_control_o = pmbus_gpio_o[6];
    assign amp_pmbus_control_t = pmbus_gpio_t[6];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PCU-PCU Link


    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_ctrl_ifc, avmm_device_ifc[AVMM_PPL_CTRL], 1, AVMM_PPL_CTRL+1, 16+20, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_prbs_ifc, avmm_device_ifc[AVMM_PPL_PRBS], 1, AVMM_PPL_PRBS+1, 16+24, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_ctrl_ifc, avmm_device_ifc[AVMM_PPL_AUR_CTRL], 1, AVMM_PPL_AUR_CTRL+1, 16+20, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );
    `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mmi_ppl_aur_drp_ifc, avmm_device_ifc[AVMM_PPL_AUR_DRP], 1, AVMM_PPL_AUR_DRP+1, 16+6, clk_ifc_ps_156_25, interconnect_sreset_ifc_ps_156_25, peripheral_sreset_ifc_ps_156_25.reset, ENABLE_PPL );

    assign ppl_aur_ctrl.sresetn = peripheral_sresetn_ifc_ps_156_25.reset;

    localparam ENABLE_PPL_ETHERNET_TUNNEL = ENABLE_PPL;

    board_pcuhdr_ppl #(
        .ENABLE_MPCU_PPL                ( ENABLE_PPL                    ),
        .ENABLE_PRBS                    ( 1'b1                          ),
        .DEFAULT_ENABLE_ETHERNET_TUNNEL ( ENABLE_PPL_ETHERNET_TUNNEL    ),
        .SYSCLK_FREQ                    ( 156250000                     ),
        .AUR_RX_FRAME_FIFO_DEPTH        ( 128                           ),  // number of 64-bit words
        .DEBUG_AUR_ILA                  ( 1'b0                          )
    ) board_pcuhdr_ppl_inst (
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
            assign ppl_aur_io.RXN_IN   = ppl_xcvr_rx0_n;
            assign ppl_aur_io.RXP_IN   = ppl_xcvr_rx0_p;
            assign ppl_xcvr_tx0_n      = ppl_aur_io.TXN_OUT;
            assign ppl_xcvr_tx0_p      = ppl_aur_io.TXP_OUT;

            // Set up the user clock network.
            IBUFDS_GTE4 #(
                .REFCLK_HROW_CK_SEL ( 2'b10 )   // ODIV2 = 1'b0 (i.e. disable the output ODIV2)
            ) gtrefclk1_buf_inst (
                .I      ( gth_clk0_p          ),
                .IB     ( gth_clk0_n          ),
                .O      ( ppl_aur_io.gtrefclk ),
                .ODIV2  (                     ),
                .CEB    ( 1'b0                )
            );


            if (ENABLE_PPL_ETHERNET_TUNNEL) begin : gen_connect_ppl_eth
                // Create adapters and CDC for Ethernet to/from PPL

                AXIS_int #(
                    .DATA_BYTES(8)
                ) axis_ppl_eth_out_wide (
                    .clk        (  clk_ifc_ps_125.clk                 ),
                    .sresetn    ( peripheral_sresetn_ifc_ps_125.reset )
                );

                AXIS_int #(
                    .DATA_BYTES(8)
                ) axis_ppl_eth_in_wide (
                    .clk        (  clk_ifc_ps_125.clk                 ),
                    .sresetn    ( peripheral_sresetn_ifc_ps_125.reset )
                );

                axis_adapter_wrapper axis_adapter_ppl_eth_in (
                    .axis_in  ( pspl_eth_src.Slave  ),
                    .axis_out ( axis_ppl_eth_in_wide.Master            )
                );

                axis_adapter_wrapper axis_adapter_ppl_eth_out (
                    .axis_in  ( axis_ppl_eth_out_wide.Slave            ),
                    .axis_out ( pspl_eth_sink.Master )
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
                    .axis_out            ( ppl_axis_tx [EXTERNAL_PPL_AXIS_TX_IDX_ETHERNET]          ),
                    .axis_in_overflow    (                                                          ),
                    .axis_in_bad_frame   (                                                          ),
                    .axis_in_good_frame  (                                                          ),
                    .axis_out_overflow   (                                                          ),
                    .axis_out_bad_frame  (                                                          ),
                    .axis_out_good_frame (                                                          )
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
                    .axis_out            ( axis_ppl_eth_out_wide.Master                       ),
                    .axis_in_overflow    (                                                    ),
                    .axis_in_bad_frame   (                                                    ),
                    .axis_in_good_frame  (                                                    ),
                    .axis_out_overflow   (                                                    ),
                    .axis_out_bad_frame  (                                                    ),
                    .axis_out_good_frame (                                                    )
                );
            end else begin : no_ppl_eth
                axis_nul_sink no_axis_ppl_eth_rn   ( .axis (ppl_axis_rx [EXTERNAL_PPL_AXIS_RX_IDX_ETHERNET]) );
                axis_nul_src  no_axis_ppl_axis_tx  ( .axis (ppl_axis_tx [EXTERNAL_PPL_AXIS_TX_IDX_ETHERNET]) );

                axis_connect pspleth_bridge_loopback (
                    .axis_in  ( pspl_eth_src.Slave  ),
                    .axis_out ( pspl_eth_sink.Master )
                );

            end
        end else begin : no_ppl_aur
            assign ppl_aur_io.gtrefclk = 1'b0;
            assign ppl_aur_io.RXN_IN   = 'X;
            assign ppl_aur_io.RXP_IN   = 'X;
            assign ppl_xcvr_tx0_n      = 'X;
            assign ppl_xcvr_tx0_p      = 'X;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq


    // No need to ever assert this reset?
    assign aresetn_ifc_external.reset = 1'b1;

    board_pcuhdr_zynq_wrapper #(
        .AXIS_ETH_FIFO_ADDR_WIDTH        ( $clog2(MAX_PKTSIZE) + 2 ),
        .PSPL_AVMM_LPD_MASTER_ADDR_WIDTH ( 28                      )
    ) zynq_inst (
        // Reset for PL
        .pl_aresetn_ifc_in                     ( aresetn_ifc_external.ResetIn             ),

        // PL Clocks Generated by the Zynq
        .clk_ifc_ps_125_out                    ( clk_ifc_ps_125                           ),
        .clk_ifc_ps_156_25_out                 ( clk_ifc_ps_156_25                        ),

        // PL Interconnect Resets Synchronous to Respective Zynq Generated Clocks
        .interconnect_sreset_ifc_ps_125_out    ( interconnect_sreset_ifc_ps_125.ResetOut     ),
        .interconnect_sresetn_ifc_ps_125_out   ( interconnect_sresetn_ifc_ps_125.ResetOut    ),
        .interconnect_sreset_ifc_ps_156_25_out ( interconnect_sreset_ifc_ps_156_25           ),
        .interconnect_sresetn_ifc_ps_156_25_out( interconnect_sresetn_ifc_ps_156_25.ResetOut),

        // PL Peripheral Resets Synchronous to Respective Zynq Generated Clocks
        .peripheral_sreset_ifc_ps_125_out      ( peripheral_sreset_ifc_ps_125.ResetOut    ),
        .peripheral_sresetn_ifc_ps_125_out     ( peripheral_sresetn_ifc_ps_125.ResetOut   ),
        .peripheral_sreset_ifc_ps_156_25_out   ( peripheral_sreset_ifc_ps_156_25.ResetOut ),
        .peripheral_sresetn_ifc_ps_156_25_out  ( peripheral_sresetn_ifc_ps_156_25.ResetOut),

        // PS to PL LPD AVMM Master - Driven by ARM, on clk_ifc_ps_156_25_out
        .pspl_lpd_avmm_m      ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_ZYNQ] ),

        .savmm_wrapper_in     ( avmm_init_ctrl_to_ps_master_ifc.Slave         ),

        .pspl_eth_tx_in       ( pspl_eth_sink.Slave  ),
        .pspl_eth_rx_out      ( pspl_eth_src.Master  ),

        .pcu_pmbus_i2c_scl_i  ( pcu_pmbus_i2c_scl_i ),
        .pcu_pmbus_i2c_scl_o  ( pcu_pmbus_i2c_scl_o ),
        .pcu_pmbus_i2c_scl_t  ( pcu_pmbus_i2c_scl_t ),
        .pcu_pmbus_i2c_sda_i  ( pcu_pmbus_i2c_sda_i ),
        .pcu_pmbus_i2c_sda_o  ( pcu_pmbus_i2c_sda_o ),
        .pcu_pmbus_i2c_sda_t  ( pcu_pmbus_i2c_sda_t ),

        .fe_pmbus_i2c_scl_i   ( fe_pmbus_i2c_scl_i  ),
        .fe_pmbus_i2c_scl_o   ( fe_pmbus_i2c_scl_o  ),
        .fe_pmbus_i2c_scl_t   ( fe_pmbus_i2c_scl_t  ),
        .fe_pmbus_i2c_sda_i   ( fe_pmbus_i2c_sda_i  ),
        .fe_pmbus_i2c_sda_o   ( fe_pmbus_i2c_sda_o  ),
        .fe_pmbus_i2c_sda_t   ( fe_pmbus_i2c_sda_t  ),

        .amp_pmbus_i2c_scl_i  ( amp_pmbus_i2c_scl_i ),
        .amp_pmbus_i2c_scl_o  ( amp_pmbus_i2c_scl_o ),
        .amp_pmbus_i2c_scl_t  ( amp_pmbus_i2c_scl_t ),
        .amp_pmbus_i2c_sda_i  ( amp_pmbus_i2c_sda_i ),
        .amp_pmbus_i2c_sda_o  ( amp_pmbus_i2c_sda_o ),
        .amp_pmbus_i2c_sda_t  ( amp_pmbus_i2c_sda_t ),

        .pmbus_gpio_i         ( pmbus_gpio_i ),
        .pmbus_gpio_o         ( pmbus_gpio_o ),
        .pmbus_gpio_t         ( pmbus_gpio_t ),

        .cal_eeprom_i2c_scl_i ( cal_eeprom_i2c_scl_i ),
        .cal_eeprom_i2c_scl_o ( cal_eeprom_i2c_scl_o ),
        .cal_eeprom_i2c_scl_t ( cal_eeprom_i2c_scl_t ),
        .cal_eeprom_i2c_sda_i ( cal_eeprom_i2c_sda_i ),
        .cal_eeprom_i2c_sda_o ( cal_eeprom_i2c_sda_o ),
        .cal_eeprom_i2c_sda_t ( cal_eeprom_i2c_sda_t )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Debug


    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA_MOD) begin : dbg_ila_enabled
                ila_debug debug_pcuhdr_sys_mod_clk_inst (
                    .clk    (  mod_clk_ifc.clk                           ),
                    .probe0 (  0                                         ),
                    .probe1 (  axis_out_dvbs2x_raw.tdata[31:0]           ),
                    .probe2 ( {axis_out_dvbs2x_raw.tvalid,
                               axis_out_dvbs2x_raw.tready,
                               axis_out_dvbs2x_raw.tvalid,
                               axis_out_dvbs2x_raw.tready}               ),
                    .probe3 (  axis_out_dvbs2x_raw.tdata[31:0]           ),
                    .probe4 (  axis_out_dvbs2x_filtered_lcm.tdata        ),
                    .probe5 ( {axis_out_dvbs2x_filtered_lcm.tvalid,
                               axis_out_dvbs2x_filtered_lcm.tready}      ),
                    .probe6 (  axis_out_dvbs2x_filtered.tdata[31:0]      ),
                    .probe7 ( {axis_out_dvbs2x_filtered.tvalid,
                               axis_out_dvbs2x_filtered.tready}          ),
                    .probe8 (  axis_out_dvbs2x_upsampled.tdata[31:0]     ),
                    .probe9 ( {axis_out_dvbs2x_upsampled.tvalid,
                               axis_out_dvbs2x_upsampled.tready}         ),
                    .probe10(  axis_out_dvbs2x_filtered_full.tdata[31:0] ),
                    .probe11( {axis_out_dvbs2x_filtered_full.tready,
                               axis_out_dvbs2x_filtered_full.tvalid}     ),
                    .probe12(  axis_out_dvbs2x_filtered_full.tstrb       ),
                    .probe13(  axis_out_dvbs2x_filtered_full.tkeep       ),
                    .probe14( {overflow_mod_clk, bad_frame_mod_clk,
                               good_frame_mod_clk}                       ),
                    .probe15(  0                                         )
                );

                ila_debug debug_pcuhdr_sys_txsdr_clk_inst (
                    .clk    (  txsdr_clk_ifc.clk                ),
                    .probe0 (  axis_out_dvbs2x[0].tdata[31:0] ),
                    .probe1 ( {axis_out_dvbs2x[0].tvalid,
                               axis_out_dvbs2x[0].tready,
                               txsdr_samples_out[0].tvalid,
                               txsdr_samples_out[0].tready}    ),
                    .probe2 (  txsdr_samples_out[0].tdata[31:0]),
                    .probe3 (  axis_out_dvbs2x[0].tstrb       ),
                    .probe4 (  axis_out_dvbs2x[0].tkeep       ),
                    .probe5 ( {overflow_dac_clk,
                               bad_frame_dac_clk,
                               good_frame_dac_clk}            ),
                    .probe6 (  0                              ),
                    .probe7 (  0                              ),
                    .probe8 (  0                              ),
                    .probe9 (  0                              ),
                    .probe10(  0                              ),
                    .probe11(  0                              ),
                    .probe12(  0                              ),
                    .probe13(  0                              ),
                    .probe14(  0                              ),
                    .probe15(  0                              )
                );
            end
        endgenerate
    `endif
endmodule

`default_nettype wire
