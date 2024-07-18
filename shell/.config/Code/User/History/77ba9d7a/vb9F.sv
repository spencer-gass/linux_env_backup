// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

/**
 * This module implements all the peripheral controls for the TX side of the HDR-FE
 */
module board_pcuhdr_tx
#(
    parameter bit           ENABLE_TX               = 1,
    parameter bit           TRANCHE1                = 0,

    parameter int           FE_DIGIPOT_I2C_CLKDIV   = 0,

    parameter bit [31:0]    TX_DAC_CTRL_MODULE_ID   = 0,
    parameter bit [31:0]    TX_DAC_DATA_MODULE_ID   = 0,
    parameter bit [31:0]    TX_LO_CTRL_MODULE_ID    = 0,
    parameter bit [31:0]    TX_IQ_MOD_MODULE_ID     = 0,
    parameter bit [31:0]    TX_CTRL_ADC_MODULE_ID   = 0,
    parameter bit [31:0]    TX_ALC_MODULE_ID        = 0,
    parameter bit [31:0]    TX_NANO_DAC_MODULE_ID   = 0,
    parameter bit [31:0]    TX_FE_DIGIPOT_MODULE_ID = 0,
    parameter bit           DEBUG_ILA               = 0
) (
    // Main system clock: everything is on this clock unless otherwise specified
    Clock_int.Input         common_clk_ifc,
    // Peripheral reset for all TX devices, on common_clk_ifc
    Reset_int.ResetIn       common_peripheral_sreset_ifc,
    // Interconnect reset for entire common_clk_ifc clock domain
    Reset_int.ResetIn       common_interconnect_sreset_ifc,

    // DAC sample clock interface
    Clock_int.Output        dac_jesd_clk_ifc,
    // DAC async reset output: must be synchronized before use
    Reset_int.ResetOut      dac_jesd_aresetn_ifc,

    // Clock used solely for DRP
    Clock_int.Input         drp_clk_ifc,

    output var logic        initdone,

    // Set to 0 to set all ssi_dac samples to zero
    input var logic         tx_enable,

    // Power off TX LO for PA bias closed-loop cal and power on when complete
    input  var logic        lo_tx_power_down,
    output var logic        lo_tx_enabled,

    // Sample stream input interface: must be either on dac_jesd_clk_ifc, or a clock with equal frequency and a known phase
    // relationship (e.g. an equal-frequency PLL output)
    SampleStream_int.Sink   ssi_dac,

    DAC_DAC3xj8x_int        dac, // Presents as TxSDR modport (used as Control and Data internally)

    // SPI bus for DAC38J84 (main TX DAC)
    SPIIO_int.Driver        dac_spi,

    // SPI bus for ADRF6780 IQ modulator, AD5601 nanoDAC, and MCP3464 ctrl ADC
    SPIIO_int.Driver        tx_spi,

    // I2C bus for MAX5477 digipot on HDR-FE
    I2CIO_int.Driver        fe_digipot_i2c,

    // SPI bus for ADF5356 PLLVCO
    SPIIO_int.Driver        lo_tx_spi,
    input var logic         lo_tx_lock_detect,

    // AVMM slaves
    AvalonMM_int.Slave      avmm_dac_ctrl,  // DAC38J84 SPI registers
    AvalonMM_int.Slave      avmm_dac_data,  // DAC38J84 JESD204C core (via mmi_to_mmi_v2 and mmi_to_axi4lite)
    AvalonMM_int.Slave      avmm_lo_tx,     // ADF5356 PLLVCO (synth_adf5356_ctrl)
    AvalonMM_int.Slave      avmm_iq_mod,    // ADRF6780 IQ modulator (raw access over avmm_to_spi)
    AvalonMM_int.Slave      avmm_ctrl_adc,  // MCP3464 ctrl ADC
    AvalonMM_int.Slave      avmm_tx_alc,    // TX ALC registers
    AvalonMM_int.Slave      avmm_nano_dac,  // AD5601 nanoDAC
    AvalonMM_int.Slave      avmm_fe_digipot // MAX5477 digipot (via dpm_max547x_ctrl_avmm)
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(common_peripheral_sreset_ifc.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(common_interconnect_sreset_ifc.ACTIVE_HIGH, 1);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int NANODAC_DATA_WIDTH  = 8;
    localparam int TX_ALC_PWR_WIDTH    = ADC_MCP3464::ADC_RES;
    localparam int TX_ALC_PERIOD_WIDTH = 32;
    localparam int SPI_MAXLEN   = 48; // TODO(wkingsford): set this smaller, on a per-bus basis
                                      // Note (kreider) I set this to 48 for now  because the
                                      // ctrl ADC needs MAXLEN of 40, and avmm_to_spi requires
                                      // MAXLEN to be a multiple of MMI_DATALEN

    // Default ALC target of 0 dBm.
    // These values have to be doubled for TRANCHE1, because the HDR-FEv4 has a 2x gain on the power detector circuit.
    // TODO(wkingsford): These are the values set using sdr.tx_alc_power_target_dbm = 0, which uses
    // a CSV of measured power detector voltage vs. output power for 32 APSK. These should eventually
    // be replaced by board-by-board calibration, using a KEEP record.
    localparam bit signed [TX_ALC_PWR_WIDTH-1:0] ALC_POWER_TARGET_LOWER = (TRANCHE1 ? 2 : 1) * 170;
    localparam bit signed [TX_ALC_PWR_WIDTH-1:0] ALC_POWER_TARGET_UPPER = (TRANCHE1 ? 2 : 1) * 187;

    // Changing the nanoDAC output below this threshold has no appreciable effect on the detected power:
    // see figure 6, page 9 of the ADF6780 datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/ADRF6780.pdf
    // This was also verified empirically.
    localparam bit [NANODAC_DATA_WIDTH-1:0] ALC_MIN_GAIN = 60;
    localparam bit [NANODAC_DATA_WIDTH-1:0] ALC_MAX_GAIN = '1;

    // Start with the minimum gain: ALC can increase it from there.
    localparam bit [NANODAC_DATA_WIDTH-1:0] DEFAULT_NANO_DAC_GAIN = ALC_MIN_GAIN;

    typedef enum {
        TX_SPI_IDX_IQ_MOD,
        TX_SPI_IDX_CTRL_ADC,
        TX_SPI_IDX_NANO_DAC,
        TX_SPI_NUM_IDX
    } tx_spi_idx_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    SPIDriver_int #( .MAXLEN( SPI_MAXLEN ), .SSNLEN( TX_SPI_NUM_IDX ) ) tx_spi_mux_in [TX_SPI_NUM_IDX-1:0] (
        .clk     ( common_clk_ifc.clk                      ),
        .sresetn (~common_peripheral_sreset_ifc.reset      )
    );

    SPIDriver_int #( .MAXLEN( SYNTH_ADF5356_HDR_TX_PKG::SPI_MAXLEN ), .SSNLEN( 1 ) ) lo_tx_spi_mux_in [0:0] (
        .clk     ( common_clk_ifc.clk                      ),
        .sresetn (~common_peripheral_sreset_ifc.reset      )
    );

    SPIDriver_int #( .MAXLEN( SPI_MAXLEN ), .SSNLEN( 1 ) ) dac_spi_mux_in [0:0] (
        .clk     ( common_clk_ifc.clk                      ),
        .sresetn (~common_peripheral_sreset_ifc.reset      )
    );

    I2CDriver_int #(
        .I2C_MAXBYTES    ( 2 ),
        .CTRL_CLOCK_FREQ ( 156250000 )
    ) fe_digipot_i2c_cmd [0:0] (
        .clk ( common_clk_ifc.clk                      ),
        .reset_n ( ~common_peripheral_sreset_ifc.reset )
    );

    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_dac_ctrl ( .clk ( common_clk_ifc.clk ) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_dac_data ( .clk ( common_clk_ifc.clk ) );

    logic tx_enable_ssidac_clk;

    SampleStream_int # (
        .N_CHANNELS (ssi_dac.N_CHANNELS),
        .N_PARALLEL (ssi_dac.N_PARALLEL),
        .NB         (ssi_dac.NB        ),
        .NB_FRAC    (ssi_dac.NB_FRAC   ),
        .PAUSABLE   (ssi_dac.PAUSABLE  )
    ) ssi_dac_controlled (
        .clk     ( ssi_dac.clk     ),
        .sresetn ( ssi_dac.sresetn )
    );

    logic iq_mod_spi_initdone;
    logic lo_tx_spi_initdone;

    logic ctrl_adc_initdone;
    logic gain_initdone;
    logic nanodac_initdone;

    logic lo_tx_lock_detect_sync;

    // TX ALC Signals
    logic signed [ADC_MCP3464::ADC_RES-1:0] ctrl_adc_sample           [ADC_MCP3464_HDR_FE::N_ADC_CHANNELS-1:0];
    logic                                   ctrl_adc_sample_valid_stb [ADC_MCP3464_HDR_FE::N_ADC_CHANNELS-1:0];

    logic                            tx_alc_decrease_gain_stb;
    logic                            tx_alc_increase_gain_stb;
    logic                            tx_alc_gain_valid_stb;
    logic                            tx_alc_gain_updated_stb;

    logic [NANODAC_DATA_WIDTH-1:0]      tx_alc_gain;
    logic [NANODAC_DATA_WIDTH-1:0]      tx_alc_default_gain;
    logic signed [TX_ALC_PWR_WIDTH-1:0] tx_alc_power_target_lower;
    logic signed [TX_ALC_PWR_WIDTH-1:0] tx_alc_power_target_upper;
    logic [TX_ALC_PERIOD_WIDTH-1:0]     tx_alc_update_period;

    Reset_int #(
        .CLOCK_GROUP_ID ( common_clk_ifc.CLOCK_GROUP_ID ),
        .NUM            ( common_clk_ifc.NUM            ),
        .DEN            ( common_clk_ifc.DEN            )
    ) tx_alc_loop_reset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( common_clk_ifc.CLOCK_GROUP_ID ),
        .NUM            ( common_clk_ifc.NUM            ),
        .DEN            ( common_clk_ifc.DEN            )
    ) tx_alc_gain_reset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( common_clk_ifc.CLOCK_GROUP_ID ),
        .NUM            ( common_clk_ifc.NUM            ),
        .DEN            ( common_clk_ifc.DEN            )
    ) tx_alc_gain_reset_dac_init_ifc ();



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign initdone = sdr_dac_ctrl.initdone && sdr_dac_data.initdone && iq_mod_spi_initdone && lo_tx_spi_initdone &&
        ctrl_adc_initdone && gain_initdone && nanodac_initdone;

    // Note that these only exist in the dac interface as well for backwards compatibility with PCH
    assign dac_jesd_clk_ifc.clk         = dac.clk;
    assign dac_jesd_aresetn_ifc.reset   = dac.sresetn;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    // The resets for the sdr interfaces
    assign sdr_dac_ctrl.sresetn = ~common_peripheral_sreset_ifc.reset;
    assign sdr_dac_data.sresetn = ~common_peripheral_sreset_ifc.reset;

    // Generate for the transmit
    generate
        if (ENABLE_TX) begin : gen_enable_tx
            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_dac_ctrl,
                avmm_dac_ctrl,
                1,
                TX_DAC_CTRL_MODULE_ID,
                148,
                common_clk_ifc,
                common_interconnect_sreset_ifc,
                common_peripheral_sreset_ifc.reset,
                sdr_dac_ctrl.initdone
            );

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_dac_data,
                avmm_dac_data,
                1,
                TX_DAC_DATA_MODULE_ID,
                7,
                common_clk_ifc,
                common_interconnect_sreset_ifc,
                common_peripheral_sreset_ifc.reset,
                sdr_dac_data.initdone
            );

            spi_mux #(
                .N             ( TX_SPI_NUM_IDX ),
                .MAXLEN        ( SPI_MAXLEN     ),
                .MISO_HIZ_MASK ( 1'b0           )
            ) tx_spi_mux_inst (
                .spi_in(tx_spi_mux_in),
                .spi_io(tx_spi)
            );

            avmm_to_spi #(
                .MODULE_ID      ( TX_IQ_MOD_MODULE_ID                   ),
                .SPI_SS_BIT     ( TX_SPI_IDX_IQ_MOD                     ),
                .SPI_MAXLEN     ( IQMOD_ADRF6780_HDR_PKG::SPI_MAXLEN    ),
                .INIT_SPI_CLKS  ( IQMOD_ADRF6780_HDR_PKG::INIT_SPI_CLKS ),
                .INIT_HIZ_MASK  ( IQMOD_ADRF6780_HDR_PKG::INIT_HIZ_MASK ),
                .INIT_NUMREGS   ( IQMOD_ADRF6780_HDR_PKG::INIT_NUMREGS  ),
                .INIT_TX_DATA   ( IQMOD_ADRF6780_HDR_PKG::INIT_TX_DATA  ),
                .INIT_SLEEP     ( IQMOD_ADRF6780_HDR_PKG::INIT_SLEEP    )
            ) iq_mod_avmm_to_spi (
                .clk_ifc                    ( common_clk_ifc            ),
                .interconnect_sreset_ifc    ( common_interconnect_sreset_ifc   ),
                .peripheral_sreset_ifc      ( common_peripheral_sreset_ifc     ),
                .avmm                       ( avmm_iq_mod                      ),
                .spi                        ( tx_spi_mux_in[TX_SPI_IDX_IQ_MOD] ),
                .initdone                   ( iq_mod_spi_initdone              )
            );

            adc_mcp3464_ctrl #(
                .MODULE_ID           ( TX_CTRL_ADC_MODULE_ID                  ),
                .DEVICE_ADDR         ( ADC_MCP3464_HDR_FE::DEVICE_ADDR        ),
                .SPI_SS_BIT          ( TX_SPI_IDX_CTRL_ADC                    ),
                .WAIT_PERIOD         ( UTIL_INTS::U_INT_MAX(ADC_MCP3464_HDR_FE::SAMPLE_PERIOD, // TODO Wait period must be >= tx_spi.CLK_DIVIDE as workaround for spi_mux bug
                                                           tx_spi.CLK_DIVIDE) ),               //(after fixing bug, change this to simply ADC_MCP3464_HDR_FE::SAMPLE_PERIOD)
                .ADC_CHANNEL_SELECT  ( ADC_MCP3464_HDR_FE::ADC_CHANNEL_SELECT ),
                .N_ADC_CHANNELS      ( ADC_MCP3464_HDR_FE::N_ADC_CHANNELS     ),
                .CFG_VAL             ( ADC_MCP3464_HDR_FE::CFG_VAL            )
            ) ctrl_adc_inst (
                .clk_ifc                 ( common_clk_ifc                     ),
                .interconnect_sreset_ifc ( common_interconnect_sreset_ifc     ),
                .peripheral_sreset_ifc   ( common_peripheral_sreset_ifc       ),
                .avmm                    ( avmm_ctrl_adc                      ),
                .spi_cmd                 ( tx_spi_mux_in[TX_SPI_IDX_CTRL_ADC] ),
                .adc_sample              ( ctrl_adc_sample                    ),
                .adc_sample_valid_stb    ( ctrl_adc_sample_valid_stb          ),
                .initdone                ( ctrl_adc_initdone                  )
            );

            agc_avmm #(
                .MODULE_VERSION      ( 1                     ),
                .MODULE_ID           ( TX_ALC_MODULE_ID      ),
                .GAIN_WIDTH          ( NANODAC_DATA_WIDTH    ),
                .PWR_WIDTH           ( TX_ALC_PWR_WIDTH      ),
                .PERIOD_WIDTH        ( TX_ALC_PERIOD_WIDTH   ),
                .DEFAULT_GAIN        ( DEFAULT_NANO_DAC_GAIN ),
                .POWER_TARGET_LOWER  ( ALC_POWER_TARGET_LOWER),
                .POWER_TARGET_UPPER  ( ALC_POWER_TARGET_UPPER),
                .UPDATE_PERIOD       ( 3125000               ), // an update period of 20 ms
                .ENABLE_BY_DEFAULT   ( 1                     )
            ) tx_alc_avmm_inst (
                .clk_ifc                 ( common_clk_ifc                 ),
                .interconnect_sreset_ifc ( common_interconnect_sreset_ifc ),
                .peripheral_sreset_ifc   ( common_peripheral_sreset_ifc   ),

                .avmm                    ( avmm_tx_alc                    ),
                .agc_reset_ifc           ( tx_alc_loop_reset_ifc.ResetOut ),
                .gain_reset_ifc          ( tx_alc_gain_reset_ifc.ResetOut ),

                .prereq_power            ( ctrl_adc_initdone               ),
                .prereq_gain             ( gain_initdone & nanodac_initdone),

                .gain                    ( tx_alc_gain                    ),

                .default_gain            ( tx_alc_default_gain            ),
                .power_target_lower      ( tx_alc_power_target_lower      ),
                .power_target_upper      ( tx_alc_power_target_upper      ),
                .update_period           ( tx_alc_update_period           )
            );

            agc_loop #(
                .PWR_WIDTH    ( TX_ALC_PWR_WIDTH    ),
                .PERIOD_WIDTH ( TX_ALC_PERIOD_WIDTH )
            ) tx_alc_loop_inst (
                .clk_ifc            ( common_clk_ifc                ),
                .rst_ifc            ( tx_alc_loop_reset_ifc.ResetIn ),

                .power              ( ctrl_adc_sample[1]            ), // Proportional to VREF - VDET of the HMC1082 on the HDR-FE
                .power_target_lower ( tx_alc_power_target_lower     ),
                .power_target_upper ( tx_alc_power_target_upper     ),
                .power_updated_stb  ( ctrl_adc_sample_valid_stb[1]  ),
                .power_clear_stb    (                               ), // feeds direct from gain updated

                .update_period      ( tx_alc_update_period          ),

                .gain_updated_stb   ( tx_alc_gain_updated_stb       ),
                .decrease_gain_stb  ( tx_alc_decrease_gain_stb      ),
                .increase_gain_stb  ( tx_alc_increase_gain_stb      )
            );

            // Hold gain adapter in reset while the nanoDAC has not initialized
            assign tx_alc_gain_reset_dac_init_ifc.reset = tx_alc_gain_reset_ifc.reset | ~nanodac_initdone;

            agc_adapter_ad5601 #(
                .GAIN_WIDTH   ( NANODAC_DATA_WIDTH ),
                .MAX_AMP_GAIN ( ALC_MAX_GAIN       ),
                .MIN_AMP_GAIN ( ALC_MIN_GAIN       )
            ) agc_adapter_ad5601_inst (
                .clk_ifc ( common_clk_ifc                         ),
                .rst_ifc ( tx_alc_gain_reset_dac_init_ifc.ResetIn ),

                .gain_updated_stb  ( tx_alc_gain_updated_stb   ),

                .decrease_gain_stb ( tx_alc_decrease_gain_stb  ),
                .increase_gain_stb ( tx_alc_increase_gain_stb  ),
                .default_gain      ( tx_alc_default_gain       ),

                .gain              ( tx_alc_gain               ),
                .gain_valid_stb    ( tx_alc_gain_valid_stb     ),
                .initdone          ( gain_initdone             )
            );

            dac_ad5601_ctrl_avmm #(
                .MODULE_ID  ( TX_NANO_DAC_MODULE_ID ),
                .SPI_SS_BIT ( TX_SPI_IDX_NANO_DAC   ),
                .GAIN_WIDTH ( NANODAC_DATA_WIDTH    )
            ) nano_dac_inst (
                .clk_ifc                 ( common_clk_ifc                     ),
                .interconnect_sreset_ifc ( common_interconnect_sreset_ifc     ),
                .peripheral_sreset_ifc   ( common_peripheral_sreset_ifc       ),
                .en_avmm_ctrl            ( tx_alc_loop_reset_ifc.reset        ),
                .avmm                    ( avmm_nano_dac                      ),
                .spi_cmd                 ( tx_spi_mux_in[TX_SPI_IDX_NANO_DAC] ),
                .dac_data_in             ( tx_alc_gain                        ),
                .dac_data_in_valid_stb   ( tx_alc_gain_valid_stb              ),
                .dac_data_in_updated_stb ( tx_alc_gain_updated_stb            ),
                .initdone                ( nanodac_initdone                   )
            );

            // Using spi_mux instead of spi_drv, even though N=1, because of differences in the interface
            spi_mux #(
                .N      (1),
                .MAXLEN (SYNTH_ADF5356_HDR_TX_PKG::SPI_MAXLEN)
            ) lo_tx_spi_mux_inst (
                .spi_in(lo_tx_spi_mux_in),
                .spi_io(lo_tx_spi)
            );

            xclock_sig tx_lo_lock_detect_synchronizer (
                .tx_clk  ( 0                      ), // Unused
                .sig_in  ( lo_tx_lock_detect      ),
                .rx_clk  ( common_clk_ifc.clk     ),
                .sig_out ( lo_tx_lock_detect_sync )
            );

            // Instantiate the synthesizer controller
            synth_adf5356_ctrl #(
                .MODULE_ID            ( TX_LO_CTRL_MODULE_ID                         ),
                .SPI_SS_BIT           ( 0                                            ),
                .SPI_MAXLEN           ( SYNTH_ADF5356_HDR_TX_PKG::SPI_MAXLEN         ),
                .NUM_DEVICE_REGS      ( SYNTH_ADF5356_HDR_TX_PKG::NUM_DEVICE_REGS    ),
                .INIT_TX_DATA         ( SYNTH_ADF5356_HDR_TX_PKG::INIT_TX_DATA       ),
                .SLEEP_BEFORE_REG_0   ( SYNTH_ADF5356_HDR_TX_PKG::SLEEP_BEFORE_REG_0 ),
                .INIT_POWER_DOWN_CTRL ( 1'b1 )  // PA bias control requires direct control of power down bit
            ) lo_tx_synth_adf5356_ctrl_inst (
                .clk_ifc                    ( common_clk_ifc                    ),
                .interconnect_sreset_ifc    ( common_interconnect_sreset_ifc    ),
                .peripheral_sreset_ifc      ( common_peripheral_sreset_ifc      ),
                .avmm_in                    ( avmm_lo_tx                        ),
                .spi                        ( lo_tx_spi_mux_in[0]               ),
                .power_down                 ( lo_tx_power_down                  ),
                .lock_detect                ( lo_tx_lock_detect_sync            ),
                .initdone                   ( lo_tx_spi_initdone                ),
                .enabled                    ( lo_tx_enabled                     )
            );

            dpm_max547x_ctrl_avmm #(
                .MODULE_ID  ( TX_FE_DIGIPOT_MODULE_ID    ),
                .AVMM_CONTROL_DEFAULT ( 1 ), // the vreg_{a,b} ports are disconnected, so only use AVMM control
                .I2C_ADDRESS( 7'b0101000 )
            ) dpm_max547x_ctrl_avmm_inst (
                .clk_ifc                    ( common_clk_ifc                    ),
                .interconnect_sreset_ifc    ( common_interconnect_sreset_ifc    ),
                .avmm                       ( avmm_fe_digipot                   ),
                .vreg_a                     ( 'X                                ),
                .vreg_a_valid_stb           ( 1'b0                              ),
                .vreg_b                     ( 'X                                ),
                .vreg_b_valid_stb           ( 1'b0                              ),
                .i2c                        ( fe_digipot_i2c_cmd[0]             ),
                .wp                         (  ) // WP is tied low on the HDR-AMP, so this output is unused
            );

            i2c_drv #(
                .DEFAULT_CLK_DIVIDE ( FE_DIGIPOT_I2C_CLKDIV )
            ) fe_digipot_i2c_drv (
                .i2c_cmd    ( fe_digipot_i2c_cmd[0]     ),
                .i2c_io     ( fe_digipot_i2c            )
            );

            // Using spi_mux instead of spi_drv, even though N=1, because of differences in the interface
            spi_mux #(
                .N      (1),
                .MAXLEN (SPI_MAXLEN)
            ) dac_spi_mux_inst (
                .spi_in(dac_spi_mux_in),
                .spi_io(dac_spi)
            );

            // Instantiate the DAC Controller module.
            dac_dac3xj8x_ctrl # (
                .SPI_SS_BIT(0)
            ) dac_3xj8x_ctrl_inst (
                .sdr (sdr_dac_ctrl ),
                .dac (dac.Control  ),
                .spi (dac_spi_mux_in[0]),
                .mmi (mmi_dac_ctrl )
            );

            // Assign JESD lane i to GTH lane LANE_ASSIGNMENT[i]
            localparam int LANE_ASSIGNMENT [0:dac.JESD_L-1] = '{5, 3, 2, 4, 1, 0, 7, 6};

            // Instantiate the JESD204C module: always 1200 MSPS mode
            dac_dac3xj8x_jesd204c #(
                .TXDAC_1200MSPS ( 1'b1            ),
                .LANE_ASSIGNMENT( LANE_ASSIGNMENT )
            ) dac_3xj8x_jesd204c_inst (
                .sdr (sdr_dac_data              ),
                .dac (dac.Data                  ),
                .mmi (mmi_dac_data              ),
                .ssi (ssi_dac_controlled.Sink   ),
                .drpclk ( drp_clk_ifc.clk       )
            );

            xclock_sig xclock_tx_enable (
                .tx_clk (common_clk_ifc.clk     ),
                .sig_in (tx_enable              ),
                .rx_clk (dac_jesd_clk_ifc.clk   ),
                .sig_out(tx_enable_ssidac_clk   )
            );
            ssi_disable ssi_dac_zero_source_inst (
                .enable (tx_enable_ssidac_clk     ),
                .in     (ssi_dac                  ),
                .out    (ssi_dac_controlled.Source)
            );
        end else begin : gen_no_tx
            sdr_ctrl_nul_slave    no_tx_dac_ctrl ( .ctrl ( sdr_dac_ctrl ) );
            sdr_ctrl_nul_slave    no_tx_dac_data ( .ctrl ( sdr_dac_data ) );
            dac_dac3xj8x_nul_ctrl   no_dac_ctrl ( .dac( dac ) );
            dac_dac3xj8x_nul_data   no_dac_data ( .dac( dac ) );

            spi_nul_io_driver no_dac_spi   ( .drv( dac_spi    ) );
            spi_nul_io_driver no_tx_spi    ( .drv( tx_spi     ) );
            i2c_nul_io_drv    no_digpot_i2c( .drv( fe_digipot_i2c ) );
            spi_nul_io_driver no_lo_tx_spi ( .drv( lo_tx_spi ) );

            avmm_nul_slave no_avmm_dac_ctrl ( .avmm ( avmm_dac_ctrl ) );
            avmm_nul_slave no_avmm_dac_data ( .avmm ( avmm_dac_data ) );
            avmm_nul_slave no_avmm_lo_tx ( .avmm ( avmm_lo_tx ) );
            avmm_nul_slave no_avmm_iq_mod ( .avmm ( avmm_iq_mod ) );
            avmm_nul_slave no_avmm_ctrl_adc ( .avmm ( avmm_ctrl_adc ) );
            avmm_nul_slave no_avmm_tx_alc ( .avmm ( avmm_tx_alc ) );
            avmm_nul_slave no_avmm_nano_dac ( .avmm ( avmm_nano_dac ) );
            avmm_nul_slave no_avmm_fe_digipot ( .avmm ( avmm_fe_digipot ) );
        end
    endgenerate
    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : dbg_ila_enabled
                ila_debug debug_tx_inst (
                    .clk    (  common_clk_ifc.clk               ),
                    .probe0 (  {ctrl_adc_sample[1]    ,
                               ctrl_adc_sample_valid_stb[1]}  ),
                    .probe1 (  {ctrl_adc_sample[2]    ,
                               ctrl_adc_sample_valid_stb[2]}  ),
                    .probe2 ( {ctrl_adc_sample[0]    ,
                               ctrl_adc_sample_valid_stb[0]}  ),
                    .probe3 (  tx_alc_gain                      ),
                    .probe4 ( {tx_alc_increase_gain_stb,
                               tx_alc_decrease_gain_stb,
                               tx_alc_gain_updated_stb,
                               tx_alc_gain_valid_stb}           ),
                    .probe5 (  tx_alc_update_period             ),
                    .probe6 (  tx_alc_default_gain              ),
                    .probe7 (  0                         ),
                    .probe8 (  tx_alc_power_target_lower        ),
                    .probe9 (  0                         ),
                    .probe10(  tx_alc_power_target_upper        ),
                    .probe11(  0                         ),
                    .probe12(  0                         ),
                    .probe13(  0                         ),
                    .probe14(  0                         ),
                    .probe15(  0                         )
                );
            end
        endgenerate
    `endif

endmodule

`default_nettype wire
