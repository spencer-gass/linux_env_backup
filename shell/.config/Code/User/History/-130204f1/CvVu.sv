// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`include "../../avmm/avmm_util.svh"
`default_nettype none

`include "board_zcu111_config.svh"

`define DEFINED(A) `ifdef A 1 `else 0 `endif

/**
 * Instantiation and connection of high-level blocks for the ZCU111 Development Kit
 */
module board_zcu111_system
    import AVMM_ADDRS_ZCU111::*;
    import BOARD_ZCU111_CLOCK_RESET_PKG::*;
    import BOARD_ZCU111_TX_PKG::*;
    import BOARD_ZCU111_RX_PKG::*;
(


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets


    Clock_int.Input clk_ifc_board_100,

    Reset_int aresetn_ifc_external,

    Clock_int clk_ifc_125,
    Reset_int sreset_ifc_125_interconnect,
    Reset_int sreset_ifc_125_peripheral,
    Reset_int sresetn_ifc_125_interconnect,
    Reset_int sresetn_ifc_125_peripheral,

    Clock_int clk_ifc_156_25,
    Reset_int sreset_ifc_156_25_interconnect,
    Reset_int sreset_ifc_156_25_peripheral,
    Reset_int sresetn_ifc_156_25_interconnect,
    Reset_int sresetn_ifc_156_25_peripheral,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: User Interface


    SPIIO_int user_spi,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SFP28 GTY


    // SFP0
    `ifdef ENABLE_SFP0
        `define REQUIRE_USER_MGT_SI570_CLOCK_C 1
        input  var logic sfp0_rx_p,
        input  var logic sfp0_rx_n,
        output var logic sfp0_tx_p,
        output var logic sfp0_tx_n,
    `endif

    // SFP1
    `ifdef ENABLE_SFP1
        `define REQUIRE_USER_MGT_SI570_CLOCK_C 1
        input  var logic sfp1_rx_p,
        input  var logic sfp1_rx_n,
        output var logic sfp1_tx_p,
        output var logic sfp1_tx_n,
    `endif

    // SFP2
    `ifdef ENABLE_SFP2
        `define REQUIRE_USER_MGT_SI570_CLOCK_C 1
        input  var logic sfp2_rx_p,
        input  var logic sfp2_rx_n,
        output var logic sfp2_tx_p,
        output var logic sfp2_tx_n,
    `endif

    // SFP3
    `ifdef ENABLE_SFP3
        `define REQUIRE_USER_MGT_SI570_CLOCK_C 1
        input  var logic sfp3_rx_p,
        input  var logic sfp3_rx_n,
        output var logic sfp3_tx_p,
        output var logic sfp3_tx_n,
    `endif

    // SFP 156.25 MHz clock
    `ifdef REQUIRE_USER_MGT_SI570_CLOCK_C
        input var logic clk_sfp_p,
        input var logic clk_sfp_n,
    `endif


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RFSoC


    input  var logic sysref_rfsoc_n,
    input  var logic sysref_rfsoc_p,

    input  var logic adc0_clk_n,
    input  var logic adc0_clk_p,

    input  var logic adc0_01_rx_n,
    input  var logic adc0_01_rx_p,
    input  var logic adc0_23_rx_n,
    input  var logic adc0_23_rx_p,

    input  var logic dac1_clk_n,
    input  var logic dac1_clk_p,

    output var logic dac12_tx_n,
    output var logic dac12_tx_p
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants and Parameters


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets


    // TODO: Parameters and validation
    Clock_int adc_clk_ifc ();
    Reset_int adc_sreset_ifc ();

    Clock_int dac_clk_ifc ();
    Reset_int dac_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( PL_OSC0_GROUP_ID  ), // Matches XDC
        .NUM              ( 1                 ),
        .DEN              ( 2                 ),
        .PHASE_ID         ( PL_OSC0_PHASE_ID  ),
        .SOURCE_FREQUENCY ( PL_OSC0_FREQUENCY )
    ) clk_ifc_50 ();

    Reset_int #(
        .CLOCK_GROUP_ID ( PL_OSC0_GROUP_ID ),
        .NUM            ( PL_OSC0_NUM      ),
        .DEN            ( PL_OSC0_DEN      ),
        .PHASE_ID       ( PL_OSC0_PHASE_ID ),
        .ACTIVE_HIGH    ( 1                ),
        .SYNC           ( 1                )
    ) sreset_global_ifcs[GLOBAL_SRESETS_NUM_RESETS-1:0] ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SPI to AVMM


    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_spi_to_avmm_loopback (
        .clk     ( clk_ifc_156_25.clk                    ),
        .sresetn ( sresetn_ifc_156_25_interconnect.reset )
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
    // SUB-SECTION: TX Signal Sources


    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES      ),
        .ALLOW_BACKPRESSURE ( 0             ),
        .ALIGNED            ( 1'b1          ),
        .NB                 ( TX_NB         ),
        .N_CHANNELS         ( TX_N_CHANNELS ),
        .N_PARALLEL         ( TX_N_PARALLEL )
    ) axis_mod_pre_symb_rate (
        .clk     (  dac_clk_ifc.clk      ),
        .sresetn ( !dac_sreset_ifc.reset )
    );

    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES      ),
        .ALLOW_BACKPRESSURE ( 0             ),
        .ALIGNED            ( 1'b1          ),
        .NB                 ( TX_NB         ),
        .N_CHANNELS         ( TX_N_CHANNELS ),
        .N_PARALLEL         ( TX_N_PARALLEL )
    ) axis_mod_samples [0:0] (
        .clk     (  dac_clk_ifc.clk      ),
        .sresetn ( !dac_sreset_ifc.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ethernet


    // Shared logic signals
    logic gtrefclk;
    logic pma_reset;
    logic mmcm_locked;

    // Ethernet frames from SFP0 to PL (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_sfp0_to_pl (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from PL to SFP0 (Originating from PL)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_pl_to_sfp0 (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from SFP1 to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_sfp1_to_ps (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from PS to SFP1 (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_ps_to_sfp1 (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from SFP2 to PL (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_sfp2_to_pl (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from PL to SFP2 (Originating from PL)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_pl_to_sfp2 (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from SFP3 to PS (Originating from outside)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_sfp3_to_ps (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );

    // Ethernet frames from PS to SFP3 (Originating from PS)
    AXIS_int #(
        .DATA_BYTES ( 1 )
    ) axis_ps_to_sfp3 (
        .clk     ( clk_ifc_125.clk                    ),
        .sresetn ( sresetn_ifc_125_interconnect.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RF Data Converter Interfaces


    // AXIS ADC Interfaces
    AXIS_int #(
        .DATA_BYTES         ( RX_BYTES      ),
        .ALLOW_BACKPRESSURE ( 0             ),
        .ALIGNED            ( 1'b1          ),
        .NB                 ( RX_NB         ),
        .N_CHANNELS         ( RX_N_CHANNELS ),
        .N_PARALLEL         ( RX_N_PARALLEL )
    ) axis_adc_samples [0:0] (
        .clk     (  adc_clk_ifc.clk      ),
        .sresetn ( !adc_sreset_ifc.reset )
    );

    // AXIS DAC Interfaces
    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES      ),
        .ALLOW_BACKPRESSURE ( 0             ),
        .ALIGNED            ( 1'b1          ),
        .NB                 ( TX_NB         ),
        .N_CHANNELS         ( TX_N_CHANNELS ),
        .N_PARALLEL         ( TX_N_PARALLEL )
    ) axis_dac_samples [0:0] (
        .clk     (  dac_clk_ifc.clk      ),
        .sresetn ( !dac_sreset_ifc.reset )
    );

    logic rf_data_converter_irq;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RX Signal Sinks


    AXIS_int #(
        .DATA_BYTES         ( RX_BYTES      ),
        .ALLOW_BACKPRESSURE ( 0             ),
        .ALIGNED            ( 1'b1          ),
        .NB                 ( RX_NB         ),
        .N_CHANNELS         ( RX_N_CHANNELS ),
        .N_PARALLEL         ( RX_N_PARALLEL )
    ) axis_demod_samples [0:0] (
        .clk     (  adc_clk_ifc.clk      ),
        .sresetn ( !adc_sreset_ifc.reset )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Module Declarations and Connections


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PLL for 50 MHz DRP clock


    PhaseLockedLoop_int # (.CLKIN_PERIOD(10), .CLKFB_MULT_F(10), .N_CLKS(1), .DIVIDE ('{20}), .DEVICE_TYPE (2) )
        pll_50_ifc ( .clk(clk_ifc_board_100.clk), .reset_n (1'b1));

    pll_wrapper pll_wrapper_ethernet ( .pll (pll_50_ifc) );

    assign clk_ifc_50.clk = pll_50_ifc.clk_out[0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: System Controller


    avmm_global_reset_controller #(
        .MODULE_VERSION ( 1                              ),
        .MODULE_ID      ( AVMM_GLOBAL_RESET_CONTROLLER+1 ),
        .NUM_RESETS     ( GLOBAL_SRESETS_NUM_RESETS      )
    ) avmm_global_reset_controller_inst  (
        .clk_ifc                 ( clk_ifc_156_25 ),

        .peripheral_sreset_ifc   ( sreset_ifc_156_25_peripheral   ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect ),

        .sreset_out_ifcs ( sreset_global_ifcs ),

        .avmm ( avmm_dev_ifc[AVMM_GLOBAL_RESET_CONTROLLER] )
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
        .clock_ifc_avmm  ( clk_ifc_156_25                                  ),
        .sreset_ifc_avmm ( sreset_ifc_156_25_interconnect                  ),

        .clock_ifc_axis  ( clk_ifc_156_25                                  ),
        .sreset_ifc_axis ( sreset_ifc_156_25_interconnect                  ),
        .axis_out        ( axis_spi_to_avmm_loopback.Master                ), // TODO: Loopback for now
        .axis_in         ( axis_spi_to_avmm_loopback.Slave                 ),

        .spi_slave_io ( user_spi )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Arbiter


    avmm_arbiter #(
        .N             ( NUM_AVMM_MASTERS ),
        .ARB_TYPE      ( "round-robin"    ),
        .HIGHEST       (  0               ),
        .ILA_DEBUG_IDX ( -1               )
    ) avmm_arbiter_inst (
        .clk_ifc                 ( clk_ifc_156_25                     ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect     ),
        .avmm_in                 ( avmm_masters_to_arbiter_ifc        ),
        .avmm_out                ( avmm_arbiter_to_unburst_ifc.Master ),
        .read_active_mask        (                                    ),
        .write_active_mask       (                                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Arbiter


    avmm_unburst #(
        .ADDRESS_INCREMENT ( 0 ),
        .DEBUG_ILA         ( 0 )
    ) avmm_unburst_spi_to_demux (
        .clk_ifc                 ( clk_ifc_156_25                    ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect    ),
        .avmm_in                 ( avmm_arbiter_to_unburst_ifc.Slave ),
        .avmm_out                ( avmm_unburst_to_demux_ifc.Master  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Demux


    avmm_demux #(
        .NUM_DEVICES        ( AVMM_NDEVS     ),
        .ADDRLEN            ( AVMM_ADDRLEN   ),
        .DEVICE_ADDR_OFFSET ( DEV_OFFSET     ),
        .DEVICE_ADDR_WIDTH  ( DEV_WIDTH      ),
        .DEBUG_ILA          ( 0              ),
        .DEBUG_DEVICE_NUM   ( AVMM_ADDRS_ROM )
    ) avmm_demux_inst (
        .clk_ifc                 ( clk_ifc_156_25                  ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect  ),
        .avmm_in                 ( avmm_unburst_to_demux_ifc.Slave ),
        .avmm_out                ( avmm_dev_ifc                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Bad Address Responder


    avmm_bad avmm_bad_inst (
        .clk_ifc                 ( clk_ifc_156_25                 ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect ),
        .avmm                    ( avmm_dev_ifc[AVMM_NDEVS]       )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM ROM


    avmm_rom #(
        .MODULE_VERSION ( 1                                      ),
        .MODULE_ID      ( AVMM_ADDRS_ROM+1                       ),
        .ROM_FILE_NAME  ( "board_zcu111_avmm_addrs_rom_init.hex" ),
        .ROM_DEPTH      ( AVMM_ROM_DEPTH                         ),
        .DEBUG_ILA      ( 0                                      )
    ) avmm_rom_inst (
        .clk_ifc                 ( clk_ifc_156_25                 ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_ADDRS_ROM]   )
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
        .clk_ifc                 ( clk_ifc_156_25                 ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_GIT_INFO]    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM PS Master


    avmm_to_avmm #(
        .MODULE_VERSION ( 1                ),
        .MODULE_ID      ( AVMM_PS_MASTER+1 ),
        .DEBUG_ILA      ( 0                )
    ) avmm_to_avmm_ps_master_inst (
        .clk_ifc                 ( clk_ifc_156_25                                      ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect                      ),
        .avmm_in                 ( avmm_dev_ifc[AVMM_PS_MASTER]                        ),
        .avmm_out                ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Master )
    );

    assign avmm_init_ctrl_ps_master_init_values_ifc.init_regs = '{
        '{49'hFFCA3008, 32'h0000, '1, '0 } // Set pcap_pr field to ICAP/MCAP for SEM
    };

    avmm_init_ctrl #(
        .ILA_DEBUG ( 0 )
    ) avmm_init_ctrl_ps_master_inst (
        .clk_ifc                 ( clk_ifc_156_25                                     ),
        .interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect                     ),
        .avmm_upstream           ( avmm_to_avmm_to_avmm_init_ctrl_ps_master_ifc.Slave ),
        .avmm_downstream         ( avmm_init_ctrl_to_ps_master_ifc.Master             ),
        .avmm_init_ctrl_ifc      ( avmm_init_ctrl_ps_master_init_values_ifc           ),
        .pre_req                 ( 1'b1                                               ),
        .initdone                (                                                    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: TX Common Stack


    axis_tx_common #(
        .MODULE_ID      ( AVMM_TX_COMMON+1 ), // TODO

        .SAMPLE_RATE    ( TX_DAC_INPUT_SAMPLE_RATE ),

        .N_INPUTS       ( 1 ),
        .N_OUTPUTS      ( 1 ),

        .MODULE_ID_TX_REPLAY         ( AVMM_TX_REPLAY+1   ),
        .MODULE_ID_TX_NCO            ( AVMM_TX_NCO_CTRL+1 ),
        .MODULE_ID_TX_POWER_DETECTOR ( AVMM_TX_PWRDET+1   ),
        .MODULE_ID_TX_CAPTURE        ( AVMM_TX_CAPTURE+1  ),

        .ENABLE_TX_NCO_SIGNAL_SOURCE ( `DEFINED(ENABLE_TX_NCO_SIGNAL_SOURCE) ),
        .ENABLE_TX_REPLAY            ( `DEFINED(ENABLE_TX_REPLAY)            ),
        .ENABLE_TX_POWER_DETECTOR    ( `DEFINED(ENABLE_TX_POWER_DETECTOR)    ),
        .ENABLE_TX_CAPTURE           ( `DEFINED(ENABLE_TX_CAPTURE)           ),

        .TX_REPLAY_BUFFER_DEPTH  ( `TX_REPLAY_BUFFER_DEPTH  ),
        .TX_CAPTURE_BUFFER_DEPTH ( `TX_CAPTURE_BUFFER_DEPTH ),

        .GAIN_NB      ( TX_GAIN_NB      ),
        .GAIN_NB_FRAC ( TX_GAIN_NB - 17 ), // 1 sign, 16 integer, 10 fractional

        .NB                 ( TX_NB         ),
        .NB_FRAC            ( 0             ),
        .N_CHANNELS         ( TX_N_CHANNELS ),
        .N_PARALLEL         ( TX_N_PARALLEL ),
        .NBYTES             ( TX_BYTES      )
    ) axis_tx_common_inst (
        .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
        .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
        .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

        .clk_ifc_sample           ( dac_clk_ifc.Input      ),
        .sreset_ifc_sample_device ( dac_sreset_ifc.ResetIn ),

        .axis_sample_ins  ( axis_mod_samples ),
        .axis_sample_outs ( axis_dac_samples ),

        .avmm_tx_common            ( avmm_dev_ifc[AVMM_TX_COMMON]   ),
        .avmm_tx_replay            ( avmm_dev_ifc[AVMM_TX_REPLAY]   ),
        .avmm_tx_nco_signal_source ( avmm_dev_ifc[AVMM_TX_NCO_CTRL] ),
        .avmm_tx_capture           ( avmm_dev_ifc[AVMM_TX_CAPTURE]  ),
        .avmm_tx_power_detector    ( avmm_dev_ifc[AVMM_TX_PWRDET]   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: TX DVB-S2x Modulator


    generate
        if (`DEFINED(ENABLE_TX_DVBS2X)) begin : gen_enable_tx_dvbs2x
            var logic tx_dvbs2x_data_initdone;

            assign tx_dvbs2x_data_initdone = !sreset_ifc_156_25_peripheral.reset; // Ready if not in reset

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_tx_dvbs2x_data,
                avmm_dev_ifc[AVMM_TX_DVBS2X_DATA_FRAMER],
                1,
                AVMM_TX_DVBS2X_DATA_FRAMER+1,
                14,
                clk_ifc_156_25,
                sreset_ifc_156_25_interconnect,
                sreset_ifc_156_25_peripheral.reset,
                tx_dvbs2x_data_initdone
            );


            var logic tx_dvbs2x_mod_initdone;

            assign tx_dvbs2x_mod_initdone = !sreset_ifc_156_25_peripheral.reset; // Ready if not in reset

            `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(
                mmi_tx_dvbs2x_mod,
                avmm_dev_ifc[AVMM_TX_DVBS2X_MOD],
                1,
                AVMM_TX_DVBS2X_MOD+1,
                18,
                clk_ifc_156_25,
                sreset_ifc_156_25_interconnect,
                sreset_ifc_156_25_peripheral.reset,
                tx_dvbs2x_mod_initdone
            );


            dvbs2x_tx #(
                .FIFO_DEPTH  ( `TX_DVBS2X_FIFO_DEPTH      ),
                .TXNBITS     ( TX_NB                      ),
                .MMI_DATALEN ( mmi_tx_dvbs2x_data.DATALEN )
            ) dvbs2x_tx_inst (
                .clk_sample      ( dac_clk_ifc.clk                       ),
                .sample_resetn   (!dac_sreset_ifc.reset                  ),
                .clk_sdr         ( clk_ifc_156_25.clk                    ),
                .sdr_resetn      ( sresetn_ifc_156_25_interconnect.reset ),
                .axis_in         ( axis_sfp0_to_pl.Slave                 ),
                .axis_out        ( axis_mod_pre_symb_rate.Master         ),
                .mmi_dvbs2x_data ( mmi_tx_dvbs2x_data.Slave              ),
                .mmi_dvbs2x_mod  ( mmi_tx_dvbs2x_mod.Slave               )
            );

            // Adjustable TX symbol rate
            dvbs2x_tx_symb_rate_divider_avmm #(
                .MODULE_ID         ( AVMM_TX_SYMB_RATE_DIVIDER+1 ),
                .SYMB_RATE_MSPS    ( HDR_DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::SYMB_RATE_MSPS )
            ) dvbs2x_tx_symb_rate_divider_avmm_inst (
                .clk_ifc_sample               ( dac_clk_ifc.Input                       ),
                .sreset_ifc_sample_device     ( dac_sreset_ifc.ResetIn                  ),
                .clk_ifc_avmm                 ( clk_ifc_156_25.Input                    ),
                .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect.ResetIn  ),
                .sreset_ifc_avmm_peripheral   ( sreset_ifc_156_25_peripheral.ResetIn    ),
                .axis_in_dvbs2x               ( axis_mod_pre_symb_rate.Slave            ),
                .axis_out_dvbs2x              ( axis_mod_samples[0].Master              ),
                .avmm                         ( avmm_dev_ifc[AVMM_TX_SYMB_RATE_DIVIDER] )
            );
        end else begin : no_tx_dvbs2x
            avmm_nul_slave no_avmm_tx_dvbs2x_data ( .avmm ( avmm_dev_ifc[AVMM_TX_DVBS2X_DATA_FRAMER] ) );
            avmm_nul_slave no_avmm_tx_dvbs2x_mod  ( .avmm ( avmm_dev_ifc[AVMM_TX_DVBS2X_MOD]         ) );
            avmm_nul_slave no_avmm_tx_symb_rate   ( .avmm ( avmm_dev_ifc[AVMM_TX_SYMB_RATE_DIVIDER]  ) );
            axis_nul_sink  no_axis_in_dvbs2x      ( .axis ( axis_sfp0_to_pl.Slave                    ) );
            axis_nul_src   no_axis_src_dvbs2x     ( .axis ( axis_mod_samples[0].Master               ) );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RX Common Stack


    axis_rx_common #(
        .MODULE_ID      ( AVMM_RX_COMMON+1 ), // TODO

        .SAMPLE_RATE    ( RX_ADC_OUPUT_SAMPLE_RATE ),

        .N_INPUTS       ( 1 ),
        .N_OUTPUTS      ( 1 ),

        .MODULE_ID_RX_CAPTURE          ( AVMM_RX_CAPTURE+1          ),
        .MODULE_ID_RX_PWRDET_PRE_GAIN  ( AVMM_RX_PWRDET_PRE_GAIN+1  ),
        .MODULE_ID_RX_PWRDET_POST_GAIN ( AVMM_RX_PWRDET_POST_GAIN+1 ),
        .MODULE_ID_RX_AGC_DIGITAL      ( AVMM_RX_AGC_DIGITAL+1      ),

        .ENABLE_RX_CAPTURE             ( `DEFINED(ENABLE_RX_CAPTURE)        ),
        .ENABLE_RX_PWRDET_PRE_GAIN     ( `DEFINED(ENABLE_RX_POWER_DETECTOR) ),
        .ENABLE_RX_PWRDET_POST_GAIN    ( `DEFINED(ENABLE_RX_POWER_DETECTOR) ),
        .ENABLE_RX_AGC_DIGITAL         ( `DEFINED(ENABLE_RX_AGC_DIGITAL)    ),

        .RX_CAPTURE_BUFFER_DEPTH ( `RX_CAPTURE_BUFFER_DEPTH ),

        .RX_AGC_DIGITAL_POWER_TARGET_LOWER ( 17017661 ), // Default lower power target of -18 dBFS
        .RX_AGC_DIGITAL_POWER_TARGET_UPPER ( 26971175 ), // Default upper power target of -16 dBFS
        .RX_AGC_DIGITAL_UPDATE_PERIOD      ( 3125000  ), // default update period of 0.02 seconds (3,125,000/156,250,000)
        .RX_AGC_DIGITAL_STEP_SIZE_DB       ( 0.05     ),

        .GAIN_NB      ( RX_GAIN_NB      ),
        .GAIN_NB_FRAC ( RX_GAIN_NB - 17 ), // 1 sign, 16 integer, 10 fractional

        .NB                 ( RX_NB         ),
        .NB_FRAC            ( 0             ),
        .N_CHANNELS         ( RX_N_CHANNELS ),
        .N_PARALLEL         ( RX_N_PARALLEL ),
        .NBYTES             ( RX_BYTES      )
    ) axis_rx_common_inst (
        .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
        .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
        .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

        .clk_ifc_sample           ( adc_clk_ifc.Input      ),
        .sreset_ifc_sample_device ( adc_sreset_ifc.ResetIn ),

        .axis_sample_ins  ( axis_adc_samples   ),
        .axis_sample_outs ( axis_demod_samples ),

        // unused ports as we don't have an external device
        .power_pre_gain            (  ),
        .power_pre_gain_valid_stb  (  ),

        .avmm_rx_common            ( avmm_dev_ifc[AVMM_RX_COMMON]  ),
        .avmm_rx_capture           ( avmm_dev_ifc[AVMM_RX_CAPTURE] ),
        .avmm_rx_pwrdet_pregain    ( avmm_dev_ifc[AVMM_RX_PWRDET_PRE_GAIN] ),
        .avmm_rx_pwrdet_postgain   ( avmm_dev_ifc[AVMM_RX_PWRDET_POST_GAIN]),
        .avmm_rx_agc_digital       ( avmm_dev_ifc[AVMM_RX_AGC_DIGITAL])
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: RX DVB-S2x Demodulator


    dvbs2x_rx #(
        .DVBS2X_ON_ADC_CLK  ( 1'b1 ), // 1'b1 disables XCLOCKs, same clocks used below
        .AVMM_ON_DVBS2X_CLK ( 1'b0 ),

        .ENABLE_DEMOD               ( `DEFINED(ENABLE_RX_DVBS2X)           ),
        .ENABLE_DEMOD_CAPTURE       ( `DEFINED(ENABLE_DEMOD_CAPTURE)       ),
        .ENABLE_DECODER             ( `DEFINED(ENABLE_RX_DVBS2X)           ),
        .ENABLE_BB_FRAME_COUNTER    ( `DEFINED(ENABLE_RX_BB_FRAME_COUNTER) ),
        .ENABLE_BB_ERROR_COUNTER    ( `DEFINED(ENABLE_RX_BB_ERROR_COUNTER) ),

        .DEMOD_CAPTURE_BUFFER_DEPTH ( `DEMOD_CAPTURE_BUFFER_DEPTH          ),

        .NB                 ( RX_NB         ),
        .NB_FRAC            ( 0             ),
        .N_CHANNELS         ( RX_N_CHANNELS ),
        .N_PARALLEL         ( RX_N_PARALLEL ),
        .NBYTES             ( RX_BYTES      ),

        .MODULE_ID_DEMOD            ( AVMM_DVBS2X_DEMOD        + 1 ),
        .MODULE_ID_DEMOD_CTRL       ( AVMM_DVBS2X_DEMOD_CTRL   + 1 ),
        .MODULE_ID_DEMOD_CAPTURE    ( AVMM_DEMOD_CAPTURE       + 1 ),
        .MODULE_ID_DECODER          ( AVMM_DVBS2X_DECODER      + 1 ),
        .MODULE_ID_DECODER_CTRL     ( AVMM_DVBS2X_DECODER_CTRL + 1 ),
        .MODULE_ID_DVBS2X_RX_DATA   ( AVMM_DVBS2X_RX_DATA      + 1 ),
        .MODULE_ID_DVBS2X_BB_FILT   ( AVMM_DVBS2X_BB_FILTER    + 1 ),
        .MODULE_ID_BB_FRAME_COUNTER ( AVMM_RX_BB_FRAME_COUNTER + 1 ),
        .MODULE_ID_BB_ERROR_COUNTER ( AVMM_RX_BB_ERROR_COUNTER + 1 )
    ) dvbs2x_rx_inst (
        .adc_clk_ifc    ( adc_clk_ifc.Input      ),
        .adc_sreset_ifc ( adc_sreset_ifc.ResetIn ),

        .dvbs2x_clk_ifc    ( adc_clk_ifc.Input      ),
        .dvbs2x_sreset_ifc ( adc_sreset_ifc.ResetIn ),

        .avmm_clk_ifc                 ( clk_ifc_156_25                 ),
        .avmm_interconnect_sreset_ifc ( sreset_ifc_156_25_interconnect ),
        .avmm_peripheral_sreset_ifc   ( sreset_ifc_156_25_peripheral   ),

        .axis_samples_in ( axis_demod_samples[0] ),

        .axis_data_out ( axis_pl_to_sfp0.Master ),

        .avmm_demod            ( avmm_dev_ifc[AVMM_DVBS2X_DEMOD]           ),
        .avmm_demod_ctrl       ( avmm_dev_ifc[AVMM_DVBS2X_DEMOD_CTRL]      ),
        .avmm_demod_capture    ( avmm_dev_ifc[AVMM_DEMOD_CAPTURE]          ),
        .avmm_decoder          ( avmm_dev_ifc[AVMM_DVBS2X_DECODER]         ),
        .avmm_decoder_ctrl     ( avmm_dev_ifc[AVMM_DVBS2X_DECODER_CTRL]    ),
        .avmm_dvbs2x_rx_data   ( avmm_dev_ifc[AVMM_DVBS2X_RX_DATA]         ),
        .avmm_dvbs2x_bb_filter ( avmm_dev_ifc[AVMM_DVBS2X_BB_FILTER]       ),
        .avmm_bb_frame_counter ( avmm_dev_ifc[AVMM_RX_BB_FRAME_COUNTER]    ),
        .avmm_bb_error_counter ( avmm_dev_ifc[AVMM_RX_BB_ERROR_COUNTER]    )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Zynq Wrapper


    board_zcu111_zynq_wrapper #(
        .ADC_DEBUG_ILA  ( 0 ),
        .DAC_DEBUG_ILA  ( 0 ),
        .SFP1_DEBUG_ILA ( 0 )
    ) board_zcu111_zynq_wrapper_inst (
        .aresetn_ifc_external ( aresetn_ifc_external ),

        .clk_ifc_125                  ( clk_ifc_125                  ),
        .sreset_ifc_125_interconnect  ( sreset_ifc_125_interconnect  ),
        .sreset_ifc_125_peripheral    ( sreset_ifc_125_peripheral    ),
        .sresetn_ifc_125_interconnect ( sresetn_ifc_125_interconnect ),
        .sresetn_ifc_125_peripheral   ( sresetn_ifc_125_peripheral   ),

        .clk_ifc_156_25                  ( clk_ifc_156_25                  ),
        .sreset_ifc_156_25_interconnect  ( sreset_ifc_156_25_interconnect  ),
        .sreset_ifc_156_25_peripheral    ( sreset_ifc_156_25_peripheral    ),
        .sresetn_ifc_156_25_interconnect ( sresetn_ifc_156_25_interconnect ),
        .sresetn_ifc_156_25_peripheral   ( sresetn_ifc_156_25_peripheral   ),

        `ifdef ENABLE_SFP1
            .axis_sfp1_to_ps ( axis_sfp1_to_ps.Slave  ), // Outside -> PS
            .axis_ps_to_sfp1 ( axis_ps_to_sfp1.Master ), // PS -> Outside
        `endif

        `ifdef ENABLE_SFP3
            .axis_sfp3_to_ps ( axis_sfp3_to_ps.Slave  ), // Outside -> PS
            .axis_ps_to_sfp3 ( axis_ps_to_sfp3.Master ), // PS -> Outside
        `endif

        .avmm_lpd_m ( avmm_masters_to_arbiter_ifc[AVMM_MASTER_ZYNQ] ),
        .avmm_lpd_s ( avmm_init_ctrl_to_ps_master_ifc.Slave         ),

        .sysref_rfsoc_n ( sysref_rfsoc_n ),
        .sysref_rfsoc_p ( sysref_rfsoc_p ),

        .adc0_clk_n ( adc0_clk_n ),
        .adc0_clk_p ( adc0_clk_p ),

        .adc_clk_ifc    ( adc_clk_ifc.Output      ),
        .adc_sreset_ifc ( adc_sreset_ifc.ResetOut ),

        .adc0_01_rx_n ( adc0_01_rx_n ),
        .adc0_01_rx_p ( adc0_01_rx_p ),
        .adc0_23_rx_n ( adc0_23_rx_n ),
        .adc0_23_rx_p ( adc0_23_rx_p ),

        .axis_adc_m ( axis_adc_samples[0].Master ),

        .dac1_clk_n ( dac1_clk_n ),
        .dac1_clk_p ( dac1_clk_p ),

        .dac_clk_ifc    ( dac_clk_ifc.Output      ),
        .dac_sreset_ifc ( dac_sreset_ifc.ResetOut ),

        .dac12_tx_n ( dac12_tx_n ),
        .dac12_tx_p ( dac12_tx_p ),

        .axis_dac_s ( axis_dac_samples[0].Slave )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: SFP28 GTY Ethernet


    // Determine which transceiver will hold the shared logic
    `ifdef ENABLE_SFP0
        `define ENABLE_SHARE_LOGIC_SFP0
    `elsif ENABLE_SFP1
        `define ENABLE_SHARE_LOGIC_SFP1
    `elsif ENABLE_SFP2
        `define ENABLE_SHARE_LOGIC_SFP2
    `elsif ENABLE_SFP3
        `define ENABLE_SHARE_LOGIC_SFP3
    `endif

    `ifdef ENABLE_SFP0 // Must be an ifdef to remove the pin references when not used
        generate
            // SFP0 - 1G SGMII - PL
            if (1) begin : gen_enable_sfp0
                var logic mdio_mmi_sfp0_sgmii_mac_initdone;

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sfp0_sgmii_mac_ifc, avmm_dev_ifc[AVMM_SFP0_SGMII_MAC_MDIO], 1, AVMM_SFP0_SGMII_MAC_MDIO+1, 4, clk_ifc_156_25, sreset_ifc_156_25_interconnect, sreset_ifc_156_25_peripheral.reset, mdio_mmi_sfp0_sgmii_mac_initdone);

                MDIO_IO_int #(
                    .CLK_DIVIDE ( 80 ) // Chosen to be <= 2.5 MHz for clock freqs <= 200 MHz
                ) sfp0_sgmii_mac_mdio ();

                mdio_mmi mdio_mmi_sfp0_sgmii_mac_inst (
                    .clk    ( clk_ifc_156_25.clk                   ),
                    .rst    ( sreset_ifc_156_25_interconnect.reset ),
                    .mdio_io( sfp0_sgmii_mac_mdio                  ),
                    .mmi    ( mdio_mmi_sfp0_sgmii_mac_ifc          )
                );

                ethernet_xcvr_sgmii_or_basex_to_axis #(
                    .ENABLE                   ( `DEFINED(ENABLE_SFP0)             ),
                    .AXIS_ETH_FIFO_ADDR_WIDTH ( 12                                ), // TODO (alao): Can maybe reduce later
                    .DEFAULT_SGMII_OR_BASEX_N ( 1'b1                              ),
                    .DEFAULT_AUTONEG_ON       ( 1'b0                              ),
                    .SHARED_LOGIC             ( `DEFINED(ENABLE_SHARE_LOGIC_SFP0) ),
                    .PHYADDR                  ( 0                                 ),
                    .DEBUG_ILA                ( 1'b0                              )
                ) ethernet_xcvr_sgmii_to_axis_sfp0_inst (
                    // Use register reset because PCS/PMA core needs to be reset after linux boot up.
                    // https://support.xilinx.com/s/article/72806?language=en_US
                    .rtl_areset_in ( sreset_global_ifcs[GLOBAL_SRESETS_PCS_PMA] ),

                    .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
                    .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
                    .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

                    .initdone_avmm_clk ( mdio_mmi_sfp0_sgmii_mac_initdone ),

                    .clk_ifc_free_running ( clk_ifc_50.Input ),

                    .axis_in  ( axis_pl_to_sfp0.Slave  ), // FPGA TX
                    .axis_out ( axis_sfp0_to_pl.Master ), // FPGA RX

                    .avmm_drp ( avmm_dev_ifc[AVMM_SFP0_SGMII_MAC_DRP] ),

                    .mdio     ( sfp0_sgmii_mac_mdio ),

                    .xcvr_refclk_p ( clk_sfp_p ),
                    .xcvr_refclk_n ( clk_sfp_n ),
                    .xcvr_rx_p     ( sfp0_rx_p ),
                    .xcvr_rx_n     ( sfp0_rx_n ),
                    .xcvr_tx_p     ( sfp0_tx_p ),
                    .xcvr_tx_n     ( sfp0_tx_n ),

                    .gtrefclk    ( gtrefclk    ),
                    .pma_reset   ( pma_reset   ),
                    .mmcm_locked ( mmcm_locked )
                );
            end
        endgenerate
    `else
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp0_mdio ( .avmm ( avmm_dev_ifc[AVMM_SFP0_SGMII_MAC_MDIO] ) );
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp0_drp ( .avmm ( avmm_dev_ifc[AVMM_SFP0_SGMII_MAC_DRP] ) );

        axis_nul_sink no_axis_sink_ethernet_xcvr_sgmii_to_axis_sfp0 ( .axis ( axis_pl_to_sfp0.Slave ) );
        axis_nul_src no_axis_src_ethernet_xcvr_sgmii_to_axis_sfp0 ( .axis ( axis_sfp0_to_pl.Master ) );
    `endif

    `ifdef ENABLE_SFP1 // Must be an ifdef to remove the pin references when not used
        generate
            // SFP1 - 1G SGMII - PS
            if (1) begin : gen_enable_sfp1
                var logic mdio_mmi_sfp1_sgmii_mac_initdone;

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sfp1_sgmii_mac_ifc, avmm_dev_ifc[AVMM_SFP1_SGMII_MAC_MDIO], 1, AVMM_SFP1_SGMII_MAC_MDIO+1, 4, clk_ifc_156_25, sreset_ifc_156_25_interconnect, sreset_ifc_156_25_peripheral.reset, mdio_mmi_sfp1_sgmii_mac_initdone);

                MDIO_IO_int #(
                    .CLK_DIVIDE ( 80 ) // Chosen to be <= 2.5 MHz for clock freqs <= 200 MHz
                ) sfp1_sgmii_mac_mdio ();

                mdio_mmi mdio_mmi_sfp1_sgmii_mac_inst (
                    .clk    ( clk_ifc_156_25.clk                   ),
                    .rst    ( sreset_ifc_156_25_interconnect.reset ),
                    .mdio_io( sfp1_sgmii_mac_mdio                  ),
                    .mmi    ( mdio_mmi_sfp1_sgmii_mac_ifc          )
                );

                ethernet_xcvr_sgmii_or_basex_to_axis #(
                    .ENABLE                   ( `DEFINED(ENABLE_SFP1)             ), // Handled by the generate if
                    .AXIS_ETH_FIFO_ADDR_WIDTH ( 12                                ), // TODO (alao): Can maybe reduce later
                    .DEFAULT_SGMII_OR_BASEX_N ( 1'b1                              ),
                    .DEFAULT_AUTONEG_ON       ( 1'b0                              ),
                    .SHARED_LOGIC             ( `DEFINED(ENABLE_SHARE_LOGIC_SFP1) ),
                    .PHYADDR                  ( 1                                 ),
                    .DEBUG_ILA                ( 1'b0                              )
                ) ethernet_xcvr_sgmii_to_axis_sfp1_inst (
                    // Use register reset because PCS/PMA core needs to be reset after linux boot up.
                    // https://support.xilinx.com/s/article/72806?language=en_US
                    .rtl_areset_in ( sreset_global_ifcs[GLOBAL_SRESETS_PCS_PMA] ),

                    .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
                    .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
                    .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

                    .initdone_avmm_clk ( mdio_mmi_sfp1_sgmii_mac_initdone ),

                    .clk_ifc_free_running ( clk_ifc_50.Input ),

                    .axis_in  ( axis_ps_to_sfp1.Slave  ), // PS TX
                    .axis_out ( axis_sfp1_to_ps.Master ), // PS RX

                    .avmm_drp ( avmm_dev_ifc[AVMM_SFP1_SGMII_MAC_DRP] ),

                    .mdio ( sfp1_sgmii_mac_mdio ),

                    .xcvr_refclk_p ( clk_sfp_p ),
                    .xcvr_refclk_n ( clk_sfp_n ),
                    .xcvr_rx_p     ( sfp1_rx_p ),
                    .xcvr_rx_n     ( sfp1_rx_n ),
                    .xcvr_tx_p     ( sfp1_tx_p ),
                    .xcvr_tx_n     ( sfp1_tx_n ),

                    .gtrefclk    ( gtrefclk    ),
                    .pma_reset   ( pma_reset   ),
                    .mmcm_locked ( mmcm_locked )
                );
            end
        endgenerate
    `else
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp1_mdio ( .avmm ( avmm_dev_ifc[AVMM_SFP1_SGMII_MAC_MDIO] ) );
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp1_drp ( .avmm ( avmm_dev_ifc[AVMM_SFP1_SGMII_MAC_DRP] ) );
    `endif

    `ifdef ENABLE_SFP2 // Must be an ifdef to remove the pin references when not used
        generate
            // SFP2 - 1G 1000BASE-X
            if (1) begin : gen_enable_sfp2
                var logic mdio_mmi_sfp2_sgmii_mac_initdone;

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sfp2_sgmii_mac_ifc, avmm_dev_ifc[AVMM_SFP2_SGMII_MAC_MDIO], 1, AVMM_SFP2_SGMII_MAC_MDIO+1, 4, clk_ifc_156_25, sreset_ifc_156_25_interconnect, sreset_ifc_156_25_peripheral.reset, mdio_mmi_sfp2_sgmii_mac_initdone);

                MDIO_IO_int #(
                    .CLK_DIVIDE ( 80 ) // Chosen to be <= 2.5 MHz for clock freqs <= 200 MHz
                ) sfp2_sgmii_mac_mdio ();

                mdio_mmi mdio_mmi_sfp2_sgmii_mac_inst (
                    .clk    ( clk_ifc_156_25.clk                   ),
                    .rst    ( sreset_ifc_156_25_interconnect.reset ),
                    .mdio_io( sfp2_sgmii_mac_mdio                  ),
                    .mmi    ( mdio_mmi_sfp2_sgmii_mac_ifc          )
                );

                ethernet_xcvr_sgmii_or_basex_to_axis #(
                    .ENABLE                   ( `DEFINED(ENABLE_SFP2)             ), // Handled by the generate if
                    .AXIS_ETH_FIFO_ADDR_WIDTH ( 12                                ), // TODO (alao): Can maybe reduce later
                    .DEFAULT_SGMII_OR_BASEX_N ( 1'b1                              ),
                    .DEFAULT_AUTONEG_ON       ( 1'b0                              ),
                    .SHARED_LOGIC             ( `DEFINED(ENABLE_SHARE_LOGIC_SFP2) ),
                    .PHYADDR                  ( 2                                 ),
                    .DEBUG_ILA                ( 1'b0                              )
                ) ethernet_xcvr_sgmii_to_axis_sfp2_inst (
                    // Use register reset because PCS/PMA core needs to be reset after linux boot up.
                    // https://support.xilinx.com/s/article/72806?language=en_US
                    .rtl_areset_in ( sreset_global_ifcs[GLOBAL_SRESETS_PCS_PMA] ),

                    .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
                    .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
                    .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

                    .initdone_avmm_clk ( mdio_mmi_sfp2_sgmii_mac_initdone ),

                    .clk_ifc_free_running ( clk_ifc_50.Input ),

                    .axis_in  ( axis_pl_to_sfp2.Slave  ), // PL TX
                    .axis_out ( axis_sfp2_to_pl.Master ), // PL RX

                    .avmm_drp ( avmm_dev_ifc[AVMM_SFP2_SGMII_MAC_DRP] ),

                    .mdio ( sfp2_sgmii_mac_mdio ),

                    .xcvr_refclk_p ( clk_sfp_p ),
                    .xcvr_refclk_n ( clk_sfp_n ),
                    .xcvr_rx_p     ( sfp2_rx_p ),
                    .xcvr_rx_n     ( sfp2_rx_n ),
                    .xcvr_tx_p     ( sfp2_tx_p ),
                    .xcvr_tx_n     ( sfp2_tx_n ),

                    .gtrefclk    ( gtrefclk    ),
                    .pma_reset   ( pma_reset   ),
                    .mmcm_locked ( mmcm_locked )
                );
            end
        endgenerate
    `else
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp2_mdio ( .avmm ( avmm_dev_ifc[AVMM_SFP2_SGMII_MAC_MDIO] ) );
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp2_drp ( .avmm ( avmm_dev_ifc[AVMM_SFP2_SGMII_MAC_DRP] ) );
    `endif

    `ifdef ENABLE_SFP3 // Must be an ifdef to remove the pin references when not used
        generate
            // SFP3 - 1G 1000BASE-X
            if (1) begin : gen_enable_sfp3
                var logic mdio_mmi_sfp3_sgmii_mac_initdone;

                `AVMM_UTIL_AVMM_TO_MMI_LEGACY_SLAVE_INST(mdio_mmi_sfp3_sgmii_mac_ifc, avmm_dev_ifc[AVMM_SFP3_SGMII_MAC_MDIO], 1, AVMM_SFP3_SGMII_MAC_MDIO+1, 4, clk_ifc_156_25, sreset_ifc_156_25_interconnect, sreset_ifc_156_25_peripheral.reset, mdio_mmi_sfp3_sgmii_mac_initdone);

                MDIO_IO_int #(
                    .CLK_DIVIDE ( 80 ) // Chosen to be <= 2.5 MHz for clock freqs <= 200 MHz
                ) sfp3_sgmii_mac_mdio ();

                mdio_mmi mdio_mmi_sfp3_sgmii_mac_inst (
                    .clk    ( clk_ifc_156_25.clk                   ),
                    .rst    ( sreset_ifc_156_25_interconnect.reset ),
                    .mdio_io( sfp3_sgmii_mac_mdio                  ),
                    .mmi    ( mdio_mmi_sfp3_sgmii_mac_ifc          )
                );

                ethernet_xcvr_sgmii_or_basex_to_axis #(
                    .ENABLE                   ( `DEFINED(ENABLE_SFP3)             ), // Handled by the generate if
                    .AXIS_ETH_FIFO_ADDR_WIDTH ( 12                                ), // TODO (alao): Can maybe reduce later
                    .DEFAULT_SGMII_OR_BASEX_N ( 1'b1                              ),
                    .DEFAULT_AUTONEG_ON       ( 1'b0                              ),
                    .SHARED_LOGIC             ( `DEFINED(ENABLE_SHARE_LOGIC_SFP3) ),
                    .PHYADDR                  ( 3                                 ),
                    .DEBUG_ILA                ( 1'b0                              )
                ) ethernet_xcvr_sgmii_to_axis_sfp3_inst (
                    // Use register reset because PCS/PMA core needs to be reset after linux boot up.
                    // https://support.xilinx.com/s/article/72806?language=en_US
                    .rtl_areset_in ( sreset_global_ifcs[GLOBAL_SRESETS_PCS_PMA] ),

                    .clk_ifc_avmm                 ( clk_ifc_156_25                 ),
                    .sreset_ifc_avmm_interconnect ( sreset_ifc_156_25_interconnect ),
                    .sreset_ifc_avmm_device       ( sreset_ifc_156_25_peripheral   ),

                    .initdone_avmm_clk ( mdio_mmi_sfp3_sgmii_mac_initdone ),

                    .clk_ifc_free_running ( clk_ifc_50.Input ),

                    .axis_in  ( axis_ps_to_sfp3.Slave  ), // PS TX
                    .axis_out ( axis_sfp3_to_ps.Master ), // PS RX

                    .avmm_drp ( avmm_dev_ifc[AVMM_SFP3_SGMII_MAC_DRP] ),

                    .mdio ( sfp3_sgmii_mac_mdio ),

                    .xcvr_refclk_p ( clk_sfp_p ),
                    .xcvr_refclk_n ( clk_sfp_n ),
                    .xcvr_rx_p     ( sfp3_rx_p ),
                    .xcvr_rx_n     ( sfp3_rx_n ),
                    .xcvr_tx_p     ( sfp3_tx_p ),
                    .xcvr_tx_n     ( sfp3_tx_n ),

                    .gtrefclk    ( gtrefclk    ),
                    .pma_reset   ( pma_reset   ),
                    .mmcm_locked ( mmcm_locked )
                );
            end
        endgenerate
    `else
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp3_mdio ( .avmm ( avmm_dev_ifc[AVMM_SFP3_SGMII_MAC_MDIO] ) );
        avmm_nul_slave no_avmm_ethernet_xcvr_sgmii_to_axis_sfp3_drp ( .avmm ( avmm_dev_ifc[AVMM_SFP3_SGMII_MAC_DRP] ) );
    `endif
endmodule

`default_nettype wire
