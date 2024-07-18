// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`default_nettype none


/**
 * This module implements all the peripheral controls for the KaS-FE
 *
 * WIP: copied from board_hsd_ku_hdr for reference
 */
module board_hsd_kas #(
    parameter int     MMI_ADDRLEN           = 0,
    parameter int     MMI_DATALEN           = 0,
    parameter int     SDR_CLK_FREQ          = 0,
    parameter int     I2C_CLK_DIV           = 0,
    parameter int     IOEXP_HALF_CLK_DIV    = 0,
    parameter int     CPM_TRANS_DEPTH       = 0   // If > 0, enable cpm_transients with this buffer depth (number of 48-bit words)
) (
    SDR_Ctrl_int.Slave             sdr,
    output var logic               vstby_initdone,
    KaS_int.Module                 kas,
    SPIIO_int.Driver               spi_3v3_io,
    SPIIO_int.Driver               spi_1v8_io,
    I2CIO_int.Driver               i2c_io,
    IOEXP_SerialOut_int.Driver     ioexp_io,
    CPM_INA23x_int                 cpm, // Used as Ctrl, VBusAlerts, and Monitor modports
    input var logic [15:0]         i2c_clk_divide,
    input var logic                i2c_clk_divide_stb,
    MonitorLimits_int              temp_limits,     // ADC and PA temperature limits: used as Sink and Source modports
                                                    // (Source is implicit, since values and valid are assigned to).

    // Memory interface
    MemoryMap_int.Slave            mmi_synth_rx,
    MemoryMap_int.Slave            mmi_synth_tx,
    MemoryMap_int.Slave            mmi_iqmod,
    MemoryMap_int.Slave            mmi_dac,
    MemoryMap_int.Slave            mmi_adc,
    MemoryMap_int.Slave            mmi_i2c,
    MemoryMap_int.Slave            mmi_cpm,
    MemoryMap_int.Slave            mmi_cpm_alarm,
    MemoryMap_int.Slave            mmi_cpm_maxval,
    MemoryMap_int.Slave            mmi_cpm_trans,
    MemoryMap_int.Slave            mmi_nano_dac,
    MemoryMap_int.Slave            mmi_temp_limits,
    MemoryMap_int.Slave            mmi_tx_alc,

    input var logic     [27:0]     us_count     // used to time cpm_trans events
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations

    import BOARD_HSD_SPI_MUX_PKG::*;


    typedef enum {
        KAS_I2C_CMD_CPM,
        KAS_I2C_CMD_ADC,
        KAS_I2C_CMD_MMI,
        KAS_I2C_NUM_CMDS
    } kas_i2c_cmd_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_vstby  ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_3v8    ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_ioexp  ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_cpm    ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_lmx_rx ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_lmx_tx ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_iqmod  ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_adc    ( .clk (sdr.clk) );
    SDR_Ctrl_int #( .STATELEN ( 1 ) ) sdr_alc    ( .clk (sdr.clk) );


    SPIDriver_int #(
        .MAXLEN ( KAS_SPI_3V3_MAXLEN ),
        .SSNLEN ( KAS_SPI_3V3_NUM_SLAVES )
    ) spi_3v3_mux_in [KAS_SPI_3V3_NUM_DEVICES-1:0] (
        .clk    ( sdr.clk ),
        .sresetn( sdr.sresetn )
    );

    SPIDriver_int #(
        .MAXLEN ( KAS_SPI_1V8_MAXLEN ),
        .SSNLEN ( KAS_SPI_1V8_NUM_DEVICES )
    ) spi_1v8_mux_in [KAS_SPI_1V8_NUM_DEVICES-1:0] (
        .clk    ( sdr.clk ),
        .sresetn( sdr.sresetn )
    );

    // TODO: use the parameters from the input spi io module.
    SPIIO_int # (
        .SSNLEN     ( spi_3v3_io.SSNLEN ),
        .CLK_DIVIDE ( spi_3v3_io.CLK_DIVIDE )
    ) spi_3v3_io_rx_muxed ();

    I2CDriver_int #(
        .I2C_MAXBYTES    ( 8 ),
        .CTRL_CLOCK_FREQ ( SDR_CLK_FREQ )
    ) i2c_cmd [KAS_I2C_NUM_CMDS-1:0] (
        .clk     ( sdr_vstby.clk ),
        .reset_n ( sdr_vstby.sresetn )
    );

    logic signed   [15:0]    pa_temperature;
    logic signed   [15:0]    board_temperature;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign sdr.initdone =  sdr_lmx_tx.initdone
                        && sdr_lmx_rx.initdone
                        && sdr_iqmod.initdone;
    assign sdr.state    = 'X;

    assign sdr_vstby.initdone = sdr_cpm.initdone && sdr_ioexp.initdone;
    assign vstby_initdone = sdr_vstby.initdone; // TODO (cbrown): revisit Ka/S startup sequencing

    // sdr.sresetn is released by hsd_ctrl in state 2.
    // cpm and ioexp should be successfully initialized in state 0, but the state machine will not wait for them if they fail,
    // so we confirm they were initialized before enabling the main FE power rail.
    assign kas.en_3v8     =  sdr.sresetn && sdr_vstby.initdone;
    assign kas.en_6v5     =  kas.en_3v8 && kas.req_6v5;
    assign kas.ioexp_oe_n = ~kas.en_3v8;

    // All CPMs share a common alert signal which any device might assert at startup,
    // so the alert signal is not valid until all CPMs have been configured.
    /*
    assign cpm.alert_valid = {cpm.NUM_MONITORS{sdr_cpm.initdone}};
    */
    assign cpm.alert_valid = {cpm.NUM_MONITORS{sdr_3v8.sresetn}};

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Peripheral bus drivers


    i2c_mux # (
        .DEFAULT_CLK_DIVIDE ( I2C_CLK_DIV ),
        .I2C_MUX_FAN        ( KAS_I2C_NUM_CMDS )
    ) i2c_mux_inst (
        .i2c_mux_cmd    ( i2c_cmd ),
        .i2c_mux_io     ( i2c_io ),
        .clk_divide     ( i2c_clk_divide ),
        .clk_divide_stb ( i2c_clk_divide_stb )
    );

    spi_mux #(
        .N      ( KAS_SPI_3V3_NUM_DEVICES ),
        .MAXLEN ( KAS_SPI_3V3_MAXLEN      )
    ) spi_3v3_mux_inst (
        .spi_in ( spi_3v3_mux_in             ),
        .spi_io ( spi_3v3_io_rx_muxed.Driver )
    );

    spi_mux #(
        .N      ( KAS_SPI_1V8_NUM_DEVICES ),
        .MAXLEN ( KAS_SPI_1V8_MAXLEN      )
    ) spi_1v8_mux_inst (
        .spi_in ( spi_1v8_mux_in ),
        .spi_io ( spi_1v8_io  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Power rail stabilization delays


    // Wait for 3V3_VSTBY rail to stabilize
    util_delay_release #(
        .DELAY          ( 10 * (SDR_CLK_FREQ / 1000) ), // 10 ms @ 125 MHz
        .ASSERTED_VALUE ( 1'b0 ),
        .STARTUP_VALUE  ( 1'b0 )
    ) delay_stby_sresetn_inst  (
        .clk        ( sdr_vstby.clk      ),
        .sig_in     ( kas.en_3v3_vstby   ),
        .sig_out    ( sdr_vstby.sresetn  )
    );

    localparam int I2C_EN_DELAY     = 15 * (SDR_CLK_FREQ / 1000);  // 15 ms @ 125 MHz  ** caution: order of operations matters here. Risk of 32-bit overflow **
    localparam int RESETN_3V8_DELAY = 20 * (SDR_CLK_FREQ / 1000);  // 20 ms @ 125 MHz  ** caution: order of operations matters here. Risk of 32-bit overflow **
    `ELAB_CHECK_LE(I2C_EN_DELAY, RESETN_3V8_DELAY);

    // Assert i2c_en a few milliseconds before exiting 3v8 reset
    util_delay_release #(
        .DELAY          ( I2C_EN_DELAY ),
        .ASSERTED_VALUE ( 1'b0 ),
        .STARTUP_VALUE  ( 1'b0 )
    ) delay_i2c_en_inst  (
        .clk        ( sdr_3v8.clk ),
        .sig_in     ( kas.en_3v8  ),
        .sig_out    ( kas.i2c_en  )
    );

    // Wait for 3V8 and downstream rails to stabilize
    util_delay_release #(
        .DELAY          ( RESETN_3V8_DELAY ),
        .ASSERTED_VALUE ( 1'b0 ),
        .STARTUP_VALUE  ( 1'b0 )
    ) delay_3v8_sresetn_inst  (
        .clk        ( sdr_3v8.clk       ),
        .sig_in     ( kas.en_3v8        ),
        .sig_out    ( sdr_3v8.sresetn   )
    );



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: 595 shift register


    assign sdr_ioexp.sresetn = sdr_vstby.sresetn;


    ioexp_serial_out #(
        .HALF_CLK_DIV ( IOEXP_HALF_CLK_DIV )
    ) kas_ioexp_serial_out (
        .clk                    ( sdr_ioexp.clk),
        .sresetn                ( sdr_ioexp.sresetn),
        .initdone               ( sdr_ioexp.initdone ),
        .ioexp_serial_out       ( ioexp_io ),
        .output_values_current  (),
        .output_values_desired  ({  kas.rx_lo_rst_n,
                                    kas.mod_rst_3v3,
                                    (kas.version == 1) ? kas.filt_sel : kas.drv_off,
                                    kas.sw_ctrl,
                                    kas.tx_lo_rst_n,
                                    kas.adc_sel,
                                    kas.rx_drv_en_sr,
                                    kas.lna_shdn        })
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: CPMs


    assign sdr_cpm.sresetn = sdr_vstby.sresetn;


    // Instantiate the Current monitors
    cpm_ina23x_ctrl #(
        .NUM_MONITORS   ( cpm.NUM_MONITORS )
    ) cpm_ctrl_inst (
        .cpm            ( cpm.Ctrl         ),
        .i2c            ( i2c_cmd[KAS_I2C_CMD_CPM].Master ),
        .mmi            ( mmi_cpm          ),
        .sdr            ( sdr_cpm.Slave    )
    );

    cpm_ina23x_vbus_limits_mmi #(
        .NUM_MONITORS   ( cpm.NUM_MONITORS )
    ) cpm_vbus_limits (
        .sdr            ( sdr_cpm.Monitor  ),
        .cpm            ( cpm.VBusAlerts   ),
        .mmi            ( mmi_cpm_alarm    )
    );

    cpm_ina23x_maxval_mmi #(
        .NUM_MONITORS   ( cpm.NUM_MONITORS )
    ) cpm_maxval_inst (
        .sdr            ( sdr_cpm.Monitor  ),
        .cpm            ( cpm.Monitor      ),
        .mmi            ( mmi_cpm_maxval   )
    );

    if (CPM_TRANS_DEPTH > 0) begin : gen_cpm_trans
        cpm_transients #(
            .BUFFER_SIZE    ( CPM_TRANS_DEPTH )
        ) cpm_itrans_inst (
            .clk                ( sdr_cpm.clk ),
            .reset_n            ( sdr_cpm.sresetn ),
            .mmi                ( mmi_cpm_trans ),
            .vshunt_update_stb  ( cpm.vshunt_update_stb ),
            .vshunt_update_num  ( cpm.vshunt_update_num ),
            .vshunt_update_value( cpm.vshunt_update_value ),
            .us_count           ( us_count )
        );
    end else begin : no_cpm_trans
        mmi_nul_slave no_cpm_trans_mmi( .mmi(mmi_cpm_trans) );
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Synthesizers


    assign sdr_lmx_tx.sresetn = sdr_3v8.sresetn && kas.tx_lo_rst_n;
    assign sdr_lmx_rx.sresetn = sdr_3v8.sresetn && kas.rx_lo_rst_n;


    // The LMX2592 chips don't actually have proper MISO lines. They mux the funcitonality
    // of their MUXout pin. Based on the value of an internal register, it either outptus
    // pll_locked or "register readback", which is like a MISO line, but not open drain.
    // In order to be able to read back register values, we mux the source of miso
    // based on ss_n.
    // Note that in order to use read-back, you must perform a register write to change
    // the functionality of MUXout, then perform the read, then perform another register
    // write to change it back. While MUXout is performing read-back, the value of pll_locked
    // will be nonsensical.
    assign spi_3v3_io.sclk              = spi_3v3_io_rx_muxed.sclk;
    assign spi_3v3_io.hiz               = spi_3v3_io_rx_muxed.hiz;
    assign spi_3v3_io.mosi_out          = spi_3v3_io_rx_muxed.mosi_out;
    assign spi_3v3_io.ss_n              = spi_3v3_io_rx_muxed.ss_n;
    assign spi_3v3_io_rx_muxed.mosi_in  = spi_3v3_io.mosi_in;
    always_comb begin
        // We assume ss_n is one-hot active low.
        spi_3v3_io_rx_muxed.miso = spi_3v3_io.miso;  // DAC miso
        if (~spi_3v3_io_rx_muxed.ss_n == (1<<KAS_SPI_3V3_RXLO)) begin  // synth rx readback
            spi_3v3_io_rx_muxed.miso = kas.rx_lock;
        end
        if (~spi_3v3_io_rx_muxed.ss_n == (1<<KAS_SPI_3V3_TXLO)) begin  // synth tx readback
            spi_3v3_io_rx_muxed.miso = kas.tx_lock;
        end
    end

    // Tx synthesizer
    synth_lmx2592_ctrl #(
        .NUMSPISTEPS        ( KAS_SYNTH_TX_KA_BAND::NUMSPISTEPS             ),
        .SYNTH_ORDER        ( KAS_SYNTH_TX_KA_BAND::SYNTH_ORDER             ),
        .SYNTH_SETTING      ( KAS_SYNTH_TX_KA_BAND::SYNTH_SETTING           ),
        .SYNTH_INITIAL_DELAY( KAS_SYNTH_TX_KA_BAND::SYNTH_INITIAL_DELAY     ),
        .SPI_SS_BIT         ( KAS_SPI_3V3_TXLO                              )
    ) synth_lmx2592_tx_inst (
        .synth_pll_locked   ( kas.tx_lock                       ),
        .synth_error        (                                   ),
        .sdr                ( sdr_lmx_tx.Slave                  ),
        .spi                ( spi_3v3_mux_in[KAS_SPI_3V3_TXLO]  ),
        .mmi                ( mmi_synth_tx                      )
    );

    // Rx synthesizer
    synth_lmx2592_ctrl #(
        .NUMSPISTEPS        ( KAS_SYNTH_RX_S_BAND::NUMSPISTEPS              ),
        .SYNTH_ORDER        ( KAS_SYNTH_RX_S_BAND::SYNTH_ORDER              ),
        .SYNTH_SETTING      ( KAS_SYNTH_RX_S_BAND::SYNTH_SETTING            ),
        .SYNTH_INITIAL_DELAY( KAS_SYNTH_RX_S_BAND::SYNTH_INITIAL_DELAY      ),
        .SPI_SS_BIT         ( KAS_SPI_3V3_RXLO                              )
    ) synth_lmx2592_rx_inst (
        .synth_pll_locked   ( kas.rx_lock                       ),
        .synth_error        (                                   ),
        .sdr                ( sdr_lmx_rx.Slave                  ),
        .spi                ( spi_3v3_mux_in[KAS_SPI_3V3_RXLO]  ),
        .mmi                ( mmi_synth_rx                      )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: IQ modulator


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0           ),
        .NUM              ( 1           ),
        .DEN              ( 1           ),
        .PHASE_ID         ( 0           ),
        .SOURCE_FREQUENCY ( SDR_CLK_FREQ   )
    ) iqmod_clk_ifc ();
    assign iqmod_clk_ifc.clk = sdr_iqmod.clk;

    MemoryMap_int #(
        .DATALEN    ( MMI_DATALEN   ),
        .ADDRLEN    ( MMI_ADDRLEN   )
    ) mmi_init_iqmod ();

    // Wait for ADMV1013 to come out of reset
    // TODO: replace this delay and the mmi_to_spi modules with a proper ADMV1013 controller that includes a startup delay
    util_delay_release #(
        .DELAY          ( 20 * (SDR_CLK_FREQ / 1000) ), // 20 ms @ 125 MHz
        .ASSERTED_VALUE ( 1'b0 ),
        .STARTUP_VALUE  ( 1'b0 )
    ) delay_rxtx_sresetn_inst  (
        .clk        ( sdr_iqmod.clk                         ),
        .sig_in     ( sdr_3v8.sresetn & ~kas.mod_rst_3v3    ),
        .sig_out    ( sdr_iqmod.sresetn                     )
    );

    mmi_to_spi_init_ctrl #(
        .MMI_DATALEN            ( MMI_DATALEN                           ),
        .MMI_ADDRLEN            ( MMI_ADDRLEN                           ),
        .SPI_MAXLEN             ( KAS_SPI_1V8_MAXLEN                    ),
        .INIT_SPI_CLKS          ( IQMOD_ADMV1013_KAS_PKG::INIT_SPI_CLKS ),
        .INIT_HIZ_MASK          ( IQMOD_ADMV1013_KAS_PKG::INIT_HIZ_MASK ),
        .INIT_NUMREGS           ( IQMOD_ADMV1013_KAS_PKG::INIT_NUMREGS  ),
        .INIT_TX_DATA           ( IQMOD_ADMV1013_KAS_PKG::INIT_TX_DATA  ),
        .INIT_SLEEP             ( IQMOD_ADMV1013_KAS_PKG::INIT_SLEEP    )
    ) mmi_to_spi_1v8_iqmod_init_ctrl (
        .clk_ifc                ( iqmod_clk_ifc.Input   ),
        .reset_n                ( sdr_iqmod.sresetn     ),
        .mmi_in                 ( mmi_iqmod             ),
        .mmi_out                ( mmi_init_iqmod.Master ),
        .start                  ( 1'b1                  ), // start as soon as the reset is released
        .initdone               ( sdr_iqmod.initdone    )
    );

    mmi_to_spi #(
        .SPI_SS_BIT ( KAS_SPI_1V8_MOD )
    ) mmi_to_spi_1v8_iqmod_inst (
        .mmi ( mmi_init_iqmod.Slave ),
        .spi ( spi_1v8_mux_in[KAS_SPI_1V8_MOD] )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Vctrl DAC


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0           ),
        .NUM              ( 1           ),
        .DEN              ( 1           ),
        .PHASE_ID         ( 0           ),
        .SOURCE_FREQUENCY ( SDR_CLK_FREQ   )
    ) dac_clk_ifc ();
    assign dac_clk_ifc.clk = sdr_3v8.clk;

    MemoryMap_int #(
        .DATALEN    ( MMI_DATALEN   ),
        .ADDRLEN    ( MMI_ADDRLEN   )
    ) mmi_init_dac ();

    // Write 16'h0 to the DAC immediately out of reset
    mmi_to_spi_init_ctrl #(
        .MMI_DATALEN            ( MMI_DATALEN   ),
        .MMI_ADDRLEN            ( MMI_ADDRLEN   ),
        .SPI_MAXLEN             ( 16            ),
        .INIT_SPI_CLKS          ( 16            ),
        .INIT_HIZ_MASK          ( 16'h0000      ),
        .INIT_NUMREGS           ( 1             ),
        .INIT_TX_DATA           ( {'0}          ),
        .INIT_SLEEP             ( {'0}          )
    ) mmi_to_spi_3v3_dac_init_ctrl (
        .clk_ifc                ( dac_clk_ifc.Input     ),
        .reset_n                ( sdr_3v8.sresetn       ),
        .mmi_in                 ( mmi_dac               ),
        .mmi_out                ( mmi_init_dac.Master   ),
        .start                  ( 1'b1                  ), // start as soon as the reset is released
        .initdone               (                       )
    );

    mmi_to_spi #(
        .SPI_SS_BIT     ( KAS_SPI_3V3_DAC ),
        .SPI_SCLK_INVERT( 1 )
    ) mmi_to_spi_3v3_dac_inst (
        .mmi ( mmi_init_dac.Slave ),
        .spi ( spi_3v3_mux_in[KAS_SPI_3V3_DAC] )
    );



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: ADC


    assign sdr_adc.sresetn = sdr_3v8.sresetn;


    // Actually ADS1115
    adc_ads1015_ctrl #(
        .DEFAULT_POLL_PERIOD(5000000),
        .NUM_ADC            (1),
        .NUM_TEMP_OUTPUTS   (2),
        .TEMP_REG_SOURCES   ('{10, 11}),
        .DISABLE_COMPARATOR (1)
    ) adc_ads1015_ctrl_inst (
        .clk                ( sdr_adc.clk ),
        .sresetn            ( sdr_adc.sresetn ),
        .mmi                ( mmi_adc ),
        .i2c                ( i2c_cmd.Master[KAS_I2C_CMD_ADC] ),
        .pa_temperatures    ( temp_limits.Source ),
        .tx_pwr             ( tx_pwr ),
        .tx_pwr_valid_stb   ( tx_pwr_valid_stb )
    );

    mon_limits_mmi #(.INCLUDE_READBACK(1) ) temp_limits_inst (
        .clk        ( sdr_adc.clk ),
        .sresetn    ( sdr_adc.sresetn ),
        .limit_vals ( temp_limits.Sink ),
        .mmi        ( mmi_temp_limits )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MMI-to-I2C


    mmi_to_i2c #(
        .I2C_MAXBYTES (8),
        .I2C_MUX_FAN  (1)
    ) mmi_to_i2c_inst (
        .mmi (mmi_i2c),
        .i2c (i2c_cmd[KAS_I2C_CMD_MMI:KAS_I2C_CMD_MMI])
    );




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Tx ALC


    assign sdr_alc.sresetn = sdr_3v8.sresetn;


    localparam int AVMM_ADDRLEN = 32;
    localparam int AVMM_DATALEN = 32;

    localparam NANODAC_DATA_WIDTH = 8;
    localparam TX_ALC_PWR_WIDTH = 12;
    localparam TX_ALC_PERIOD_WIDTH = 32;


    localparam bit [NANODAC_DATA_WIDTH-1:0] ALC_MIN_GAIN = 60;
    localparam bit [NANODAC_DATA_WIDTH-1:0] ALC_MAX_GAIN = '1;


    logic gain_initdone;
    logic nanodac_initdone;

    // TX ALC Signals
    logic signed [TX_ALC_PWR_WIDTH-1:0]       tx_pwr;
    logic                            tx_pwr_valid_stb;

    logic                            tx_alc_decrease_gain_stb;
    logic                            tx_alc_increase_gain_stb;
    logic                            tx_alc_gain_valid_stb;
    logic                            tx_alc_gain_updated_stb;

    logic [NANODAC_DATA_WIDTH-1:0]      tx_alc_gain;
    logic [NANODAC_DATA_WIDTH-1:0]      tx_alc_default_gain;
    logic signed [TX_ALC_PWR_WIDTH-1:0] tx_alc_power_target_lower;
    logic signed [TX_ALC_PWR_WIDTH-1:0] tx_alc_power_target_upper;
    logic [TX_ALC_PERIOD_WIDTH-1:0]     tx_alc_update_period;
    logic signed [TX_ALC_PWR_WIDTH-1:0] tx_alc_power_offset;


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

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .NUM              ( 1 ),
        .DEN              ( 1 ),
        .PHASE_ID         ( 0 ),
        .SOURCE_FREQUENCY ( SDR_CLK_FREQ )
    ) common_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .NUM              ( 1 ),
        .DEN              ( 1 ),
        .PHASE_ID         ( 0 ),
        .ACTIVE_HIGH    ( 1                     ),
        .SYNC           ( 1                     )
    ) common_interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .NUM              ( 1 ),
        .DEN              ( 1 ),
        .PHASE_ID         ( 0 ),
        .ACTIVE_HIGH    ( 1                     ),
        .SYNC           ( 1                     )
    ) common_peripheral_sreset_ifc ();

    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) avmm_tx_alc ();

    assign common_clk_ifc.clk = sdr.clk;
    assign common_interconnect_sreset_ifc.reset = ~sdr.sresetn;
    assign common_peripheral_sreset_ifc.reset   = ~sdr.sresetn;


/* TODO (cbrown) revisit this with phantom BP alarm workaround
    mmi_to_avmm #(
        // .AVMM_ADDRLEN ( AVMM_ADDRLEN ),
        // .AVMM_DATALEN ( AVMM_DATALEN )
    ) tx_alc_mmi_to_avmm (
        .clk        ( sdr_alc.clk ),
        .reset_n    ( sdr_alc.sresetn ),
        .mmi        ( mmi_tx_alc ),
        .avmm       ( avmm_tx_alc )
    );

    agc_avmm #(
        .MODULE_VERSION      ( 1                     ),
        .MODULE_ID           ( 1  ),
        .AVMM_ADDRLEN        ( AVMM_ADDRLEN ),
        .AVMM_DATALEN        ( AVMM_DATALEN ),
        .GAIN_WIDTH          ( NANODAC_DATA_WIDTH  ),
        .PWR_WIDTH           ( TX_ALC_PWR_WIDTH      ),
        .PERIOD_WIDTH        ( TX_ALC_PERIOD_WIDTH   ),
        .DEFAULT_GAIN        ( 0),
        .POWER_TARGET_LOWER  ( 0),
        .POWER_TARGET_UPPER  ( 2047),
        .UPDATE_PERIOD       ( SDR_CLK_FREQ* 20 / 1000            ), // an update period of 20 ms
        .ENABLE_BY_DEFAULT   ( 0                     )
    ) tx_alc_avmm_inst (
        .clk_ifc                 ( common_clk_ifc                 ),
        .interconnect_sreset_ifc ( common_interconnect_sreset_ifc ),
        .peripheral_sreset_ifc   ( common_peripheral_sreset_ifc   ),

        .avmm                    ( avmm_tx_alc                    ),
        .agc_reset_ifc           ( tx_alc_loop_reset_ifc.ResetOut ),
        .gain_reset_ifc          ( tx_alc_gain_reset_ifc.ResetOut ),

        .prereq_power            ( sdr_adc.sresetn                ),
        .prereq_gain             ( gain_initdone & nanodac_initdone),

        .gain                    ( tx_alc_gain                    ),

        .default_gain            ( tx_alc_default_gain            ),
        .power_target_lower      ( tx_alc_power_target_lower      ),
        .power_target_upper      ( tx_alc_power_target_upper      ),
        .update_period           ( tx_alc_update_period           )
    );
*/


    agc_mmi #(
        .MMI_DATALEN        ( AVMM_DATALEN ),
        .GAIN_WIDTH          ( NANODAC_DATA_WIDTH  ),
        .PWR_WIDTH           ( TX_ALC_PWR_WIDTH      ),
        .PERIOD_WIDTH        ( TX_ALC_PERIOD_WIDTH   ),
        .DEFAULT_GAIN        ( 0  ),
        .POWER_TARGET_LOWER  ( 0  ),
        .POWER_TARGET_UPPER  ( {1'b0, '1} ),
        .UPDATE_PERIOD       ( SDR_CLK_FREQ* 5 / 1000            ), // an update period of 5 ms
        .ENABLE_BY_DEFAULT   ( 0                     )
    ) tx_agc_mmi_inst (

        .clk        ( sdr_alc.clk ),
        .reset_n    ( sdr_alc.sresetn ),

        .mmi                    ( mmi_tx_alc                    ),

        .agc_reset_ifc           ( tx_alc_loop_reset_ifc.ResetOut ),
        .gain_reset_ifc          ( tx_alc_gain_reset_ifc.ResetOut ),

        .gain                    ( tx_alc_gain                    ),
        .nanodac_initdone        ( nanodac_initdone               ),

        .default_gain            ( tx_alc_default_gain            ),
        .power_target_lower      ( tx_alc_power_target_lower      ),
        .power_target_upper      ( tx_alc_power_target_upper      ),
        .update_period           ( tx_alc_update_period           ),
        .power_offset            ( tx_alc_power_offset            )
    );

    agc_loop #(
        .PWR_WIDTH    ( TX_ALC_PWR_WIDTH    ),
        .PERIOD_WIDTH ( TX_ALC_PERIOD_WIDTH )
    ) tx_alc_loop_inst (
        .clk_ifc            ( common_clk_ifc                ),
        .rst_ifc            ( tx_alc_loop_reset_ifc.ResetIn ),

        .power              ( tx_pwr + tx_alc_power_offset  ),
        .power_target_lower ( tx_alc_power_target_lower     ),
        .power_target_upper ( tx_alc_power_target_upper     ),
        .power_updated_stb  ( tx_pwr_valid_stb              ),
        .power_clear_stb    (                               ), // feeds direct from gain updated

        .update_period      ( tx_alc_update_period          ),

        .gain_updated_stb   ( tx_alc_gain_updated_stb       ),
        .decrease_gain_stb  ( tx_alc_decrease_gain_stb      ),
        .increase_gain_stb  ( tx_alc_increase_gain_stb      )
    );

    // Hold gain adapter in reset while the amps have not initialized
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

    dac_ad5601_ctrl_mmi #(
        .SPI_SS_BIT              ( KAS_SPI_3V3_DAC    ),
        .GAIN_WIDTH              ( NANODAC_DATA_WIDTH ),
    ) nano_dac_inst(
        .clk                     ( sdr.clk                              ),
        .interconnect_sreset     ( ~sdr.sresetn                         ),
        .peripheral_sreset       ( ~sdr.sresetn                         ),
        .en_mmi_ctrl             ( tx_alc_loop_reset_ifc.reset          ),
        .mmi                     ( mmi_nano_dac                         ),
        .spi_cmd                 ( spi_3v3_mux_in[KAS_SPI_3V3_NANODAC]  ),
        .dac_data_in             ( tx_alc_gain                          ),
        .dac_data_in_valid_stb   ( tx_alc_gain_valid_stb                ),
        .dac_data_in_updated_stb ( tx_alc_gain_updated_stb              ),
        .initdone                ( nanodac_initdone                     )
    );


endmodule