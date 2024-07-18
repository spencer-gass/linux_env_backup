// CONFIDENTIAL
// Copyright (c) 2019 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This implements the transmit signal path for DVB-S2, Tx FIFO Buffer, TXReplay, NCO Signal Source, DUC for RFoE
 *
 * Tx FIFO Buffer:
 *     mmi_buf is an axis_mmibuffer that can be used to provide a waveform for playback.
 *     The axis stream it drives is 8 bytes wide, containing four 16-bit samples encoding
 *     2-parallel IQ data. When writing data words to mmi_buf, write samples in the
 *     order Q[1], I[1], Q[0], I[0].
 */
module txsdr
    import DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::*;
#(
    parameter bit [15:0] DEFAULT_TX_MUX_SEL = 0,
    parameter bit [15:0] DEFAULT_TX_GAIN0 = 16'h3A00,
    parameter bit [15:0] DEFAULT_TX_GAIN1 = 16'h0000,
    parameter bit ENABLE_TXDVBS2      = 1,
    parameter bit ENABLE_TXDVBS2X     = 0,
    parameter int TXFIFO_DEPTH_MMI_WORDS = 0,  // mmi buffer depth in words; 0 to disable buffers
    parameter int TXDVBS2_FIFO_DEPTH  = 8192,  // One jumbo frame, rounded up to a power of 2
    parameter int MMI_DATALEN         = 16,
    parameter int MMI_ADDRLEN         = 15,
    parameter bit ENABLE_TXREPLAY     = 1,
    parameter bit ENABLE_TXREPLAY_BUF = 1,
    parameter bit ENABLE_RFOE         = 1,
    parameter bit ENABLE_IQ_TUNNEL    = 0,
    parameter int BLOCK_SIZE_EXPONENT = 9,
    parameter bit MOD_ON_SSI_CLK      = 0,       // 0: clk_mod is assumed to be 240 MHz, 1: clk_mod is assumed to be equal to ssi_out.clk
    parameter bit MOD_400MSYM         = 0
) (
    input var logic          clk_300,
    input var logic          clk_mod,

    SDR_Ctrl_int.Slave       sdr,
    SampleStream_int.Sink    ssi_ins [TXSDR_PKG::EXTERNAL_SSI_SRC_NUM_INDICES-1:0],
    AXIS_int.Slave           axis_iq_tunnel_in,
    SampleStream_int.Source  ssi_out,
    SampleStream_int.Source  ssi_out_dvbs2x,

    AXIS_int.Slave           axis,
    input var logic          ms_pulse,                          // Pulse once each ms, on axis.clk.
    WatchdogAction_int.Watchdog     acm_modcod_watchdog_action, // Responds to alarms by resetting the modcod.

    // Source of input samples for TXREPLAY or TXREPLAY_BUF to transmit
    BlockByteCtrl_int.Client bb_ctrl_replay,
    AXIS_int.Slave           bb_read_replay,

    // High speed buffer for TXREPLAY_BUF to copy samples from disk to
    BlockByteCtrl_int.Client bb_ctrl_replay_buf,
    AXIS_int.Slave           bb_read_replay_buf,
    AXIS_int.Master          bb_write_replay_buf,

    // Memory interfaces (on sdr.clk)
    MemoryMap_int.Slave      mmi_dvbs2_data,  // Control for DVB-S2 framer
    MemoryMap_int.Slave      mmi_dvbs2x_data, // Control for DVB-S2X framer
    MemoryMap_int.Slave      mmi_dsp,         // Control for general resets, output mux, gains, offsets
    MemoryMap_int.Slave      mmi_dvbs2_mod,   // Control for DVB-S2 modulator
    MemoryMap_int.Slave      mmi_dvbs2x_mod,  // Control for DVB-S2X modulator
    MemoryMap_int.Slave      mmi_buf,         // Control for mmi TX FIFO buffer
    MemoryMap_int.Slave      mmi_replay,      // Control for ssd_tx_replay
    MemoryMap_int.Slave      mmi_nco,         // Control for NCO signal source
    MemoryMap_int.Slave      mmi_symb_rate_div,
    MemoryMap_int.Slave      mmi_coeff_real,
    MemoryMap_int.Slave      mmi_coeff_imag

    //input var logic [SYMB_RATE_SEL_NB-1:0] symb_rate_sel

);

    import TXSDR_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(MMI_DATALEN, 16);
    `ELAB_CHECK_GE   (MMI_ADDRLEN, 6);
    `ELAB_CHECK_EQUAL(ENABLE_TXDVBS2 && ENABLE_TXDVBS2X, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int TXDAC_SAMPLE_RATE = 300000000;

    localparam N_CHANNELS = ENABLE_TXDVBS2X ? N_CHANNELS_1200MSPS : N_CHANNELS_300MSPS;
    localparam N_PARALLEL = ENABLE_TXDVBS2X ? N_PARALLEL_1200MSPS : N_PARALLEL_300MSPS;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic mod_resetn_on_clk_mod, mod_resetn_on_clk_300, mod_resetn;

    logic               axisbuf_resetn;
    logic signed [15:0] tx_gain   [1:0];
    logic signed [15:0] tx_offset [3:0];
    logic        [15:0] tx_mux_sel;

    logic  [$clog2(TXSDR_DUC_PKG::NUM_AXIS_IN_INDICES)-1:0] duc_source_select;

    // Main axis input, after axis_mute which drops frames in reset
    AXIS_int #(
        .DATA_BYTES ( axis.DATA_BYTES )
    ) axis_gated (
        .clk     ( axis.clk     ),
        .sresetn ( axis.sresetn )
    );

    SampleStream_int #(
        .N_CHANNELS ( N_CHANNELS    ),
        .N_PARALLEL ( N_PARALLEL    ),
        .NB         ( TX_N_BITS_INT ),
        .NB_FRAC    ( 0             )
    ) ssi_internal_txsdr_ssi_src [INTERNAL_SSI_SRC_NUM_INDICES-1:0] (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES ((N_CHANNELS*TX_N_BITS_INT-1)/8+1   ),
        .ID_WIDTH   ( 1                                 ),
        .DEST_WIDTH ( 1                                 ),
        .USER_WIDTH ( 1                                 )
    ) duc_axis_in [TXSDR_DUC_PKG::NUM_AXIS_IN_INDICES-1:0] (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    /**
     * ssi_rfoe is obtained by taking only the first parallel element of ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE] (this is the only
     * element that has actual RFoE data; the other element was zero-padded to match the form of ssi_ins)
     */
    SampleStream_int #(
        .N_CHANNELS ( N_CHANNELS    ),
        .N_PARALLEL ( 1             ),
        .NB         ( TX_N_BITS_INT ),
        .NB_FRAC    ( 0             )
    ) ssi_rfoe (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    // ssi_rfoe after passing through ssi_to_axis
    AXIS_int #(
        .DATA_BYTES ((N_CHANNELS*TX_N_BITS_INT-1)/8+1   ),
        .ID_WIDTH   ( 1                                 ),
        .DEST_WIDTH ( 1                                 ),
        .USER_WIDTH ( 1                                 )
    ) axis_rfoe (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    // tx_samples, before adding offsets (splitting it this way allows synthesis into DSP blocks)
    SampleStream_int #(
        .N_CHANNELS ( N_CHANNELS                     ),
        .N_PARALLEL ( N_PARALLEL                     ),
        .NB         ( TX_N_BITS_INT + TX_N_BITS_FRAC ),
        .NB_FRAC    ( TX_N_BITS_FRAC                 )
    ) ssi_tx_gain_mult_out (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    // 2-parallel, 150 MHz samples from DVB-S2 modulator
    SampleStream_int #(
        .N_CHANNELS ( 2             ), // I and Q
        .N_PARALLEL ( 2             ),
        .NB         ( TX_N_BITS_INT ),
        .NB_FRAC    ( 0             )
    ) dvbs2_samples (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    // Raw iq samples from an nco
    SampleStream_int #(
        .N_CHANNELS ( 2             ),
        .N_PARALLEL ( 2             ),
        .NB         ( TX_N_BITS_INT ),
        .NB_FRAC    ( 0             ),
        .IS_IQ      ( 1'b1          )
    ) nco_samples (
        .clk     ( ssi_out.clk     ),
        .sresetn ( ssi_out.sresetn )
    );

    // Instantiate the AXIS interfaces
    AXIS_int #(
        .DATA_BYTES ( 8 )
    ) mmi_buf_samples (
        .clk     ( ssi_out.clk    ),
        .sresetn ( axisbuf_resetn )
    );

    MemoryMap_int #(
        .DATALEN ( mmi_dsp.DATALEN ),
        .ADDRLEN ( mmi_dsp.ADDRLEN )
    ) mmi_dsp_on_clk_ssi ();

    // AXIS interface from DVB-S2X modulator
    AXIS_int #(
        .DATA_BYTES ( (TX_N_BITS_INT*8*2-1)/8+1 ),
        .NB         ( TX_N_BITS_INT ),
        .NB_FRAC    ( 0             ),
        .N_CHANNELS ( N_CHANNELS    ), // I and Q
        .N_PARALLEL ( N_PARALLEL    ),
        .ALIGNED    ( 1             )
    ) axis_out_dvbs2x (
        .clk     ( ssi_out.clk      ),
        .sresetn ( ssi_out.sresetn  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign sdr.initdone = sdr.sresetn;
    assign sdr.state    = 'X;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Signal sources


    // Null source, outputs 0
    always_comb begin
        ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NULL].data       = '{N_CHANNELS{'{N_PARALLEL{'0}}}};
        ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NULL].valid      = 1'b0;
        ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NULL].center_ref = 1'b0;
    end

    generate
        if (ENABLE_TXDVBS2 || ENABLE_TXDVBS2X) begin : gen_txdvb
            // Synchronize mod_resetn_ssiclk to clk_300
            xclock_sig xclock_300_resetn (
                .tx_clk  ( ssi_out.clk           ),
                .sig_in  ( mod_resetn            ),
                .rx_clk  ( clk_300               ),
                .sig_out ( mod_resetn_on_clk_300 )
            );
            // Synchronize mod_resetn_ssiclk to clk_mod
            xclock_sig xclock_mod_resetn (
                .tx_clk  ( ssi_out.clk           ),
                .sig_in  ( mod_resetn            ),
                .rx_clk  ( clk_mod               ),
                .sig_out ( mod_resetn_on_clk_mod )
            );

            // Drop frames from axis when in reset
            axis_mute #(
                .ALLOW_LAST_WORD    ( 0 ),
                .DROP_WHEN_MUTED    ( 1 ),
                .FRAMED             ( 1 )
            ) mute_while_reset (
                .axis_in        ( axis              ),
                .axis_out       ( axis_gated.Master ),
                .enable         ( sdr.sresetn       ),
                .connected      (                   )
            );
            if (ENABLE_TXDVBS2X == 0) begin : gen_txdvbs2
                dvbs2_tx #(
                    .TXNBITS        ( TX_N_BITS_INT      ),
                    .FIFO_DEPTH     ( TXDVBS2_FIFO_DEPTH ),
                    .MOD_ON_SSI_CLK ( MOD_ON_SSI_CLK     )
                ) txsdr_dvbs2_inst (
                    .clk_sample       ( clk_300                    ),
                    .sample_resetn    ( ssi_out.sresetn            ), // clk_300 is synchronous to ssi_out.clk, so this is safe
                    .clk_mod          ( clk_mod                    ),
                    .mod_resetn       ( mod_resetn_on_clk_mod      ),
                    .clk_sdr          ( sdr.clk                    ),
                    .sdr_resetn       ( sdr.sresetn                ),
                    .axis_in          ( axis_gated.Slave           ), // 100 MHz
                    .ssi_out          ( dvbs2_samples.Source       ), // 150 MHz 2 parallel sample output (300 MSPS IQ)
                    .ms_pulse         ( ms_pulse                   ),
                    .watchdog_action  ( acm_modcod_watchdog_action ),
                    .mmi_dvbs2_data   ( mmi_dvbs2_data             ), // on axis.clk
                    .mmi_dvbs2_mod    ( mmi_dvbs2_mod              )
                );

                // Duplicate DVB-S2 samples to both channels
                always_ff @(posedge ssi_out.clk) begin
                    if (~ssi_out.sresetn) begin
                        ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2].data <= '{N_CHANNELS{'{N_PARALLEL{'X}}}};
                    end else begin
                        for (int ch_idx = 0; ch_idx < 2; ch_idx++) begin
                            for (int parallel_idx = 0; parallel_idx < N_PARALLEL; parallel_idx++) begin
                                for (int iq = 0; iq < 2; iq++) begin
                                    ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2].data[2*ch_idx + iq][parallel_idx] <=
                                        dvbs2_samples.data[iq][parallel_idx];
                                end
                            end
                        end
                    end
                end

                assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2].valid      = dvbs2_samples.valid;
                assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2].center_ref = dvbs2_samples.center_ref;
                ssi_nul_source no_dvbs2x_samples ( .ssi (ssi_out_dvbs2x) );
            end
            else begin : gen_txdvbs2x

                localparam int TX_NB   = 16;
                localparam int TX_BYTES   = (TX_NB * N_CHANNELS * N_PARALLEL - 1)/8 + 1; // unaligned samples


                AXIS_int #(
                    .DATA_BYTES         ( TX_BYTES   ),
                    .ALLOW_BACKPRESSURE ( 1'b1                               ),
                    .ALIGNED            ( 1'b1                               ),
                    .NB                 ( TX_NB      ),
                    .N_CHANNELS         ( N_CHANNELS ),
                    .N_PARALLEL         ( N_PARALLEL )
                ) axis_out_dvbs2x_raw (
                    .clk     ( clk_mod      ),
                    .sresetn ( mod_resetn_on_clk_mod )
                );


                dvbs2x_tx #(
                    .TXNBITS                ( TX_N_BITS_INT          ),
                    .FIFO_DEPTH             ( TXDVBS2_FIFO_DEPTH     ),
                    .MMI_DATALEN            ( mmi_dvbs2_data.DATALEN ),
                    .DEFAULT_ROLLOFF_IDX    ( MOD_400MSYM ? 1 : 0    )  // 0.25 rolloff for 400Msym/s, otherwise 0.35
                ) txsdr_dvbs2x_inst (
                    .clk_sample       ( clk_mod             ),
                    .sample_resetn    ( mod_resetn_on_clk_mod ),
                    .clk_sdr          ( sdr.clk             ),
                    .sdr_resetn       ( sdr.sresetn         ),
                    .axis_in          ( axis_gated.Slave    ), // 100 MHz
                    .axis_out         ( axis_out_dvbs2x_raw.Master ), // 150 MHz 8 parallel sample output (1200 MSPS IQ)
                    .mmi_dvbs2x_data  ( mmi_dvbs2_data      ), // on axis.clk, TODO: this will probably be a different slave with the new framer
                    .mmi_dvbs2x_mod   ( mmi_dvbs2x_mod      )
                );


                if (!MOD_400MSYM) begin: gen_300msym
                    // TODO: not valid. Needs CDC
                    axis_connect name (
                        .in(axis_out_dvbs2x_raw),
                        .out(axis_out_dvbs2x)
                    );
                end
                else begin: gen_400msym

                    //
                    // <From board_pcuhdr_system>
                    //

                    AXIS_int #(
                        .DATA_BYTES         ( TX_BYTES   ),
                        .ALLOW_BACKPRESSURE ( 1'b1                               ),
                        .ALIGNED            ( 1'b1                               ),
                        .NB                 ( TX_NB      ),
                        .N_CHANNELS         ( N_CHANNELS ),
                        .N_PARALLEL         ( N_PARALLEL )
                    ) axis_out_dvbs2x_scaled (
                        .clk     ( clk_mod      ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES * 3   ),
                        .ALIGNED    ( 1'b1                                   ),
                        .NB         ( TX_NB          ),
                        .N_CHANNELS ( N_CHANNELS     ),
                        .N_PARALLEL ( N_PARALLEL * 3 )
                    ) axis_out_dvbs2x_upsampled (
                        .clk     ( clk_mod      ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES * 3/4   ),
                        .ALIGNED    ( 1'b1                                     ),
                        .NB         ( TX_NB            ),
                        .N_CHANNELS ( N_CHANNELS       ),
                        .N_PARALLEL ( N_PARALLEL * 3/4 )
                    ) axis_out_dvbs2x_filtered (
                        .clk     ( clk_mod      ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES * 3   ),
                        .ALIGNED    ( 1'b1                                   ),
                        .NB         ( TX_NB          ),
                        .N_CHANNELS ( N_CHANNELS     ),
                        .N_PARALLEL ( N_PARALLEL * 3 )
                    ) axis_out_dvbs2x_filtered_lcm (
                        .clk     ( clk_mod      ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES   ),
                        .ALIGNED    ( 1'b1                               ),
                        .NB         ( TX_NB      ),
                        .N_CHANNELS ( N_CHANNELS ),
                        .N_PARALLEL ( N_PARALLEL )
                    ) axis_out_dvbs2x_filtered_full (
                        .clk     ( clk_mod      ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES   ),
                        .ALIGNED    ( 1'b1                               ),
                        .NB         ( TX_NB      ),
                        .N_CHANNELS ( N_CHANNELS ),
                        .N_PARALLEL ( N_PARALLEL )
                    ) axis_out_dvbs2x_pre_fir (
                        .clk     ( clk_mod       ),
                        .sresetn ( mod_resetn_on_clk_mod )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES   ),
                        .ALIGNED    ( 1'b1                               ),
                        .NB         ( TX_NB      ),
                        .N_CHANNELS ( N_CHANNELS ),
                        .N_PARALLEL ( N_PARALLEL )
                    ) axis_out_dvbs2x_pre_fir_txsdr_clk (
                        .clk     ( axis_out_dvbs2x.clk       ),
                        .sresetn ( axis_out_dvbs2x.sresetn )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES   ),
                        .ALIGNED    ( 1'b1                               ),
                        .NB         ( TX_NB      ),
                        .N_CHANNELS ( N_CHANNELS ),
                        .N_PARALLEL ( N_PARALLEL )
                    ) axis_out_dvbs2x_pre_gain_txsdr_clk (
                        .clk     ( axis_out_dvbs2x.clk       ),
                        .sresetn ( axis_out_dvbs2x.sresetn )
                    );

                    AXIS_int #(
                        .DATA_BYTES ( TX_BYTES   ),
                        .ALIGNED    ( 1'b1                               ),
                        .NB         ( TX_NB      ),
                        .N_CHANNELS ( N_CHANNELS ),
                        .N_PARALLEL ( N_PARALLEL )
                    ) axis_out_dvbs2x_pre_offset_txsdr_clk (
                        .clk     ( axis_out_dvbs2x.clk       ),
                        .sresetn ( axis_out_dvbs2x.sresetn )
                    );


                    // Reset_int #(
                    //     .CLOCK_GROUP_ID ( 1 ),
                    //     .NUM            ( 1 ),
                    //     .DEN            ( 1 ),
                    //     .PHASE_ID       ( 1 ),
                    //     .ACTIVE_HIGH    ( 0 ),
                    //     .SYNC           ( 1 )
                    // ) clk300_sresetn_ifc();

                    // Clock_int #(
                    //     .CLOCK_GROUP_ID   ( 1 ),
                    //     .NUM              ( 1 ),
                    //     .DEN              ( 1 ),
                    //     .PHASE_ID         ( 1 ),
                    //     .SOURCE_FREQUENCY ( 1 )
                    // ) clk300_clk_ifc();


                    Reset_int #(
                        .CLOCK_GROUP_ID ( 1 ),
                        .NUM            ( 1 ),
                        .DEN            ( 1 ),
                        .PHASE_ID       ( 1 ),
                        .ACTIVE_HIGH    ( 0 ),
                        .SYNC           ( 1 )
                    ) mod_sreset_ifc();

                    Clock_int #(
                        .CLOCK_GROUP_ID   ( 1 ),
                        .NUM              ( 1 ),
                        .DEN              ( 1 ),
                        .PHASE_ID         ( 1 ),
                        .SOURCE_FREQUENCY ( 1 )
                    ) mod_clk_ifc();


                    // assign clk300_clk_ifc.clk = clk_300;
                    // assign clk300_sresetn_ifc.reset = mod_resetn_on_clk_300;

                    // Modulator on 200 MHz clock
                    assign mod_clk_ifc.clk = clk_mod;
                    assign mod_sreset_ifc.reset = mod_resetn_on_clk_mod;



                    localparam int N_PARALLEL_RESAMPLE = N_PARALLEL*3/4;

                    // 33 bit fir_compiler output is extended to the nearest byte boundary (40 bits)
                    localparam int FILTER_OUT_NB = 40;

                    // Maximum fifo depth that uses less than half a BRAM, 18Kb/(32 bits per word * 8 parallel) = 72 rounded down to nearest power of two
                    localparam int FIFO_DEPTH = 64;

                    localparam int MOD_RESAMPLE_NB_FRAC  = 14;

                    logic [N_CHANNELS*N_PARALLEL_RESAMPLE*FILTER_OUT_NB-1:0] axis_fir_out_4x_downsample_tdata_33b;


                    // Resampling interpolation signals
                    logic signed [axis_out_dvbs2x_raw.NB-1:0]       axis_out_dvbs2x_pre_fir_samples           [0:axis_out_dvbs2x_raw.N_CHANNELS-1]       [0:axis_out_dvbs2x_raw.N_PARALLEL-1];
                    logic signed [axis_out_dvbs2x_upsampled.NB-1:0] axis_out_dvbs2x_pre_fir_samples_upsampled [0:axis_out_dvbs2x_upsampled.N_CHANNELS-1] [0:axis_out_dvbs2x_upsampled.N_PARALLEL-1];


                    // Gain used to scale modulator output samples to avoid overflow
                    logic [TX_NB-1:0] mod_gain [N_CHANNELS-1:0];

                    always_comb begin
                        for (int c = 0; c < N_CHANNELS; c++) begin
                            mod_gain[c] = 16'd15565; // Gain of 0.95001220703125
                        end
                    end


                    // Scales modulator output samples by ~0.95 to avoid overflow
                    axis_sample_gain #(
                        .N_CHANNELS     ( N_CHANNELS ),
                        .GAIN_NB        ( TX_NB      ),
                        .GAIN_NB_FRAC   ( TX_NB-2    ),
                        .INPUT_GAIN_REG ( 1'b1                               )
                    ) axis_mod_gain (
                        .clk_ifc     ( mod_clk_ifc                   ),
                        .sreset_ifc  ( mod_sreset_ifc               ),
                        .axis_in     ( axis_out_dvbs2x_raw.Slave     ),
                        .axis_out    ( axis_out_dvbs2x_scaled.Master ),
                        .gain        ( mod_gain                      )
                    );


                    // TX Equalization FIR
                    /*
                    generate
                        if (`DEFINED(ENABLE_TX_EQ)) begin : gen_tx_eq
                    */
                            axis_sample_complex_filter_mmi #(
                                // .MODULE_ID_COEFF_REAL ( AVMM_TX_EQ_REAL ),
                                // .MODULE_ID_COEFF_IMAG ( AVMM_TX_EQ_IMAG ),
                                .NUM_COEFFS(17)
                            ) axis_sample_complex_filter_mmi_inst (

                                .clk_mmi           ( sdr.clk             ),
                                .sresetn_mmi       ( sdr.sresetn         ),

                                .clk_ifc_axis    ( mod_clk_ifc.Input ),
                                .sreset_ifc_axis ( mod_sreset_ifc.ResetIn ),

                                .axis_in    ( axis_out_dvbs2x_scaled.Slave  ),
                                .axis_out   ( axis_out_dvbs2x_pre_fir.Master),

                                .mmi_coeff_real    ( mmi_coeff_real ),
                                .mmi_coeff_imag    ( mmi_coeff_imag )
                            );
                    /*
                        end else begin : no_tx_eq
                            axis_connect axis_connect_inst (
                                .axis_in    ( axis_out_dvbs2x_scaled.Slave  ),
                                .axis_out   ( axis_out_dvbs2x_pre_fir.Master)
                            );

                            avmm_nul_slave no_avmm_coeff_real ( .avmm ( avmm_device_ifc[AVMM_TX_EQ_REAL] ) );
                            avmm_nul_slave no_avmm_coeff_imag ( .avmm ( avmm_device_ifc[AVMM_TX_EQ_IMAG] ) );
                        end
                    endgenerate
                    */


                    // Upsampling by a factor of 3 by inserting 2 dummy samples for every axis sample per clock cycle
                    always_comb begin
                        axis_out_dvbs2x_pre_fir_samples = axis_out_dvbs2x_pre_fir.tdata_to_samples();

                        for (int p = 0; p < N_PARALLEL; p++) begin
                            for (int c = 0; c < N_CHANNELS; c++) begin
                                axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p]     = axis_out_dvbs2x_pre_fir_samples[c][p];
                                axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p + 1] = '0;
                                axis_out_dvbs2x_pre_fir_samples_upsampled[c][3*p + 2] = '0;
                            end
                        end

                        axis_out_dvbs2x_upsampled.tdata = axis_out_dvbs2x_upsampled.samples_to_tdata(axis_out_dvbs2x_pre_fir_samples_upsampled);
                    end

                    assign axis_out_dvbs2x_upsampled.tvalid = axis_out_dvbs2x_pre_fir.tvalid;
                    assign axis_out_dvbs2x_upsampled.tstrb  = axis_out_dvbs2x_pre_fir.tstrb;
                    assign axis_out_dvbs2x_upsampled.tkeep  = axis_out_dvbs2x_pre_fir.tkeep;
                    assign axis_out_dvbs2x_upsampled.tlast  = axis_out_dvbs2x_pre_fir.tlast;
                    assign axis_out_dvbs2x_upsampled.tid    = axis_out_dvbs2x_pre_fir.tid;
                    assign axis_out_dvbs2x_upsampled.tdest  = axis_out_dvbs2x_pre_fir.tdest;
                    assign axis_out_dvbs2x_upsampled.tuser  = axis_out_dvbs2x_pre_fir.tuser;
                    assign axis_out_dvbs2x_pre_fir.tready   = axis_out_dvbs2x_upsampled.tready;

                    // Low-pass filter and decimation from 24 parallel samples to 6 parallel samples
                    fir_compiler_mod_4x_downsample fir_compiler_mod_4x_downsample_inst (
                        .aclk               ( clk_mod                              ),
                        .s_axis_data_tvalid ( axis_out_dvbs2x_upsampled.tvalid     ),
                        .s_axis_data_tready ( axis_out_dvbs2x_upsampled.tready     ),
                        .s_axis_data_tdata  ( axis_out_dvbs2x_upsampled.tdata      ),
                        .m_axis_data_tvalid ( axis_out_dvbs2x_filtered.tvalid      ),
                        .m_axis_data_tready ( axis_out_dvbs2x_filtered.tready      ),
                        .m_axis_data_tdata  ( axis_fir_out_4x_downsample_tdata_33b ) // assumes FIR compiler is configured for 33b output sample width
                    );



                    // Tie off signals that do not go through filter
                    assign axis_out_dvbs2x_filtered.tstrb  = '1;
                    assign axis_out_dvbs2x_filtered.tkeep  = '1;
                    assign axis_out_dvbs2x_filtered.tlast  = '0;
                    assign axis_out_dvbs2x_filtered.tid    = '0;
                    assign axis_out_dvbs2x_filtered.tdest  = '0;
                    assign axis_out_dvbs2x_filtered.tuser  = '0;

                    // TODO: Temporarily truncate FIR output. Replace with general convergent rounding module when complete
                    always_comb begin
                        for (int p = 0; p < N_PARALLEL_RESAMPLE; p++) begin
                            for (int c = 0; c < N_CHANNELS; c++) begin
                                axis_out_dvbs2x_filtered.tdata[TX_NB*(N_CHANNELS*p + c) +: TX_NB]
                                    = axis_fir_out_4x_downsample_tdata_33b[FILTER_OUT_NB*(N_CHANNELS*p + c) + MOD_RESAMPLE_NB_FRAC +: TX_NB];
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
                        .axis_in_overflow    (                        ),
                        .axis_in_bad_frame   (                        ),
                        .axis_in_good_frame  (                        ),
                        .axis_out_overflow   (                        ),
                        .axis_out_bad_frame  (                        ),
                        .axis_out_good_frame (                        )
                    );

                    //
                    // </from board_pcuhdr_system>
                    //



                    ////////////////////////////////////////////////////////////////////////////////////////////////
                    // SUB-SECTION: Symbol rate divider



                    Reset_int #(
                        .CLOCK_GROUP_ID ( 1 ),
                        .NUM            ( 1 ),
                        .DEN            ( 1 ),
                        .PHASE_ID       ( 1 ),
                        .ACTIVE_HIGH    ( 0 ),
                        .SYNC           ( 1 )
                    ) axis_out_sreset_ifc();

                    Clock_int #(
                        .CLOCK_GROUP_ID   ( 1 ),
                        .NUM              ( 1 ),
                        .DEN              ( 1 ),
                        .PHASE_ID         ( 1 ),
                        .SOURCE_FREQUENCY ( 1 )
                    ) axis_out_clk_ifc();

                    // Samples on 150 MHz clock
                    assign axis_out_clk_ifc.clk      = axis_out_dvbs2x.clk;
                    assign axis_out_sreset_ifc.reset = axis_out_dvbs2x.sresetn;


                    /*
                    MemoryMap_int #(
                        .DATALEN ( mmi_symb_rate_div.DATALEN ),
                        .ADDRLEN ( mmi_symb_rate_div.ADDRLEN )
                    ) mmi_symb_rate_div_on_clk_ssi ();


                    xclock_mmi #(
                        .FF_CASCADE ( 2 ) // This must be at least 2
                    ) xclock_mmi_txdsp (
                        .m_clk    ( sdr.clk                   ),
                        .m_resetn ( sdr.sresetn               ),
                        .m_mmi    ( mmi_symb_rate_div         ),

                        .s_clk    ( ssi_out.clk               ),
                        .s_resetn ( ssi_out.sresetn           ),
                        .s_mmi    ( mmi_symb_rate_div_on_clk_ssi.Master )
                    );


                    mmi_woregfile #(
                        .NREGS(1),
                        .DWIDTH(2)
                    ) mmi_woregfile_inst (
                        .clk(ssi_out.clk),
                        .rst(~ssi_out.sresetn),
                        .mmi(mmi_symb_rate_div_on_clk_ssi),
                        .output_val({symb_rate_sel}),
                        .gpout(),
                        .gpout_stb()
                    );


                    dvbs2x_tx_symb_rate_divider_mmi #()
                    dvbs2x_tx_symb_rate_divider_mmi_inst (
                        .clk_ifc_sample             ( axis_out_clk_ifc ),
                        .sreset_ifc_sample_device   ( axis_out_sreset_ifc ),
                        .axis_in_dvbs2x             ( axis_out_dvbs2x_pre_fir_txsdr_clk.Slave ),
                        .axis_out_dvbs2x            ( axis_out_dvbs2x_pre_gain_txsdr_clk.Master ),
                        .symb_rate_sel              ( symb_rate_sel )
                    );
                    */

                    logic [SYMB_RATE_SEL_NB-1:0] symb_rate_sel_on_ssi_clk;

                    xclock_vec_on_change #(
                        .WIDTH      ( DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::SYMB_RATE_SEL_NB ),
                        .INPUT_REG  ( 1'b1 )
                    ) (
                        .in_clk             ( sdr.clk                   ),
                        .in_rst             (~sdr.sresetn               ),
                        .in_vec             ( symb_rate_sel             ),
                        .out_clk            ( ssi_out.clk               ),
                        .out_rst            (                           ),
                        .out_vec            ( symb_rate_sel_on_ssi_clk  ),
                        .out_changed_stb    (                           )
                    );

                    dvbs2x_tx_symb_rate_divider_core #()
                    dvbs2x_tx_symb_rate_divider_core_inst (
                        .clk_ifc_sample             ( axis_out_clk_ifc ),
                        .sreset_ifc_sample_device   ( axis_out_sreset_ifc ),
                        .axis_in_dvbs2x             ( axis_out_dvbs2x_pre_fir_txsdr_clk.Slave   ),
                        .axis_out_dvbs2x            ( axis_out_dvbs2x_pre_gain_txsdr_clk.Master ),
                        .symb_rate_sel              ( symb_rate_sel )
                    );

                    dvbs2x_tx_symb_rate_divider_mmi #(
                        .SYMB_RATE_MSPS         ( KAS_DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::SYMB_RATE_MSPS ),
                        .DEFAULT_SYMB_RATE_SEL  ( DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::TX_SYMB_RATE_FULL )
                    ) dvbs2x_tx_symb_rate_divider_mmi_inst(
                        .clk_sample               (axis_out_clk_ifc.clk                                         ),
                        .sresetn_sample_device    (axis_out_sreset_ifc.reset != axis_out_sreset_ifc.ACTIVE_HIGH ),
                        .clk_mmi                  (sdr.clk                                                      ),
                        .sresetn_mmi_interconnect (sdr.sresetn                                                  ),
                        .sresetn_mmi_peripheral   (sdr.sresetn                                                  ),
                        .axis_in_dvbs2x           (axis_out_dvbs2x_pre_fir_txsdr_clk.Slave                      ),
                        .axis_out_dvbs2x          (axis_out_dvbs2x_pre_gain_txsdr_clk.Master                    ),
                        .mmi                      (mmi_symb_rate_div                                            )
                    );



                    ////////////////////////////////////////////////////////////////////////////////////////////////
                    // SUB-SECTION: Digital gain and offset


                    axis_sample_gain #(
                        .N_CHANNELS     ( N_CHANNELS ),
                        .GAIN_NB        ( TX_NB      ),
                        .GAIN_NB_FRAC   ( TX_NB-2    ), // sdr.txdsp_gain = 16384 == unity gain
                        .INPUT_GAIN_REG ( 1'b1       )
                    ) txdsp_gain (
                        .clk_ifc     ( axis_out_clk_ifc                         ),
                        .sreset_ifc  ( axis_out_sreset_ifc                      ),
                        .axis_in     ( axis_out_dvbs2x_pre_gain_txsdr_clk.Slave ),
                        .axis_out    ( axis_out_dvbs2x_pre_offset_txsdr_clk.Master  ),
                        .gain        ( '{unsigned'(tx_gain[0]), unsigned'(tx_gain[0]) } )
                    );

                    axis_sample_offset #(
                        .N_CHANNELS       ( N_CHANNELS ),
                        .OFFSET_NB        ( TX_NB      ),
                        .INPUT_OFFSET_REG ( 1'b0       )
                    ) txdsp_offset (
                        .clk_ifc     ( axis_out_clk_ifc                         ),
                        .sreset_ifc  ( axis_out_sreset_ifc                      ),
                        .axis_in     ( axis_out_dvbs2x_pre_offset_txsdr_clk.Slave ),
                        .axis_out    ( axis_out_dvbs2x.Master                   ),
                        .offset      ( '{tx_offset[0], tx_offset[1] } )
                    );

                end


                axis_to_ssi #(
                   .ALIGNED ( 1'b0 )
                ) dvbs2x_axis_to_ssi (
                    .axis_in   ( axis_out_dvbs2x.Slave ),
                    .ssi_out   ( ssi_out_dvbs2x        )
                );

                ssi_nul_source no_dvbs2_samples ( .ssi (dvbs2_samples.Source) );
                ssi_nul_source no_dvbs2_samples_internal_mux_input ( .ssi (ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2]) );
            end
        end else begin
            ssi_nul_source no_dvbs2x_samples( .ssi (ssi_out_dvbs2x) );
            ssi_nul_source no_dvbs2_samples ( .ssi (dvbs2_samples.Source) );
            ssi_nul_source no_dvbs2_samples_internal_mux_input ( .ssi (ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2]) );

            axis_nul_sink no_axis      ( .axis( axis           ) );
            mmi_nul_slave no_mmi_data  ( .mmi ( mmi_dvbs2_data ) );
            mmi_nul_slave no_mmi_dvbs2 ( .mmi ( mmi_dvbs2_mod  ) );
            mon_watchdog_action_nul     no_watchdog_alarm   ( .watchdog(acm_modcod_watchdog_action) );
        end

        if (!ENABLE_TXDVBS2X) begin
            mmi_nul_slave no_mmi_dvbs2x_data ( .mmi ( mmi_dvbs2x_data ) );
            mmi_nul_slave no_mmi_dvbs2x_mod  ( .mmi ( mmi_dvbs2x_mod  ) );
        end

        if (TXFIFO_DEPTH_MMI_WORDS > 0) begin : gen_mmibuf
            axis_mmibuffer #(
                .BUFFER_DEPTH ( 2*TXFIFO_DEPTH_MMI_WORDS ),
                .BIG_ENDIAN   ( 1'b1                     )
            ) inst_axis_mmibuffer (
                .clk_mmi     ( sdr.clk         ),
                .sresetn_mmi ( sdr.sresetn     ),
                .mmi         ( mmi_buf         ),
                .axis_out    ( mmi_buf_samples )
            );

            // Adapt AXIS MMIBUFFER output to SSI
            always_ff @(posedge ssi_out.clk) begin
                if (~ssi_out.sresetn) begin
                    ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER].data <= '{N_CHANNELS{'{N_PARALLEL{'X}}}};
                end else begin
                    for (int ch_idx = 0; ch_idx < 2; ch_idx++) begin
                        for (int parallel_idx = 0; parallel_idx < N_PARALLEL; parallel_idx++) begin
                            for (int iq = 0; iq < 2; iq++) begin
                                ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER].data[2*ch_idx + iq][parallel_idx] <=
                                    signed'(mmi_buf_samples.tdata[32*parallel_idx + 16*iq +: 16]);
                            end
                        end
                    end
                end
            end

            assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER].valid      = 1'b1;
            assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER].center_ref = 1'b1;


        end else begin : gen_no_mmi_buf
            ssi_nul_source no_axis_mmibuffer_samples ( .ssi (ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER]) );
            mmi_nul_slave no_mmi_buf_mmi_buf_inst ( .mmi  ( mmi_buf  ) );
            axis_nul_src no_mmi_buf_samples_inst ( .axis ( mmi_buf_samples ) );
        end

        if ( ENABLE_TXREPLAY ) begin : gen_txreplay
            if ( ENABLE_TXREPLAY_BUF ) begin : gen_txreplay_buf
                txreplay_buf_mmi # (
                    .BLOCK_SIZE_EXPONENT  ( BLOCK_SIZE_EXPONENT ), // block-byte layer block size
                    .USE_XILINX_DSP48E1   ( 1                   )
                ) txreplay_buf_inst (
                    .clk_100      ( bb_read_replay.clk                               ),
                    .sresetn_100  ( bb_read_replay.sresetn                           ),
                    .clk_150      ( ssi_out.clk                                      ),
                    .sresetn_150  ( ssi_out.sresetn                                  ),
                    .clk_300      ( clk_300                                          ), // must be rising-edge aligned with clk_150
                    .bb_src_ctrl  ( bb_ctrl_replay                                   ),
                    .bb_src_read  ( bb_read_replay                                   ),
                    .bb_buf_ctrl  ( bb_ctrl_replay_buf                               ),
                    .bb_buf_read  ( bb_read_replay_buf                               ),
                    .bb_buf_write ( bb_write_replay_buf                              ),
                    .samples_out  ( duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_TXREPLAY] ),
                    .mmi          ( mmi_replay                                       )
                );
            end else begin: no_txreplay_buf
                txreplay_mmi # (
                    .BLOCK_SIZE_EXPONENT  ( BLOCK_SIZE_EXPONENT ), // block-byte layer block size
                    .USE_XILINX_DSP48E1   ( 1                   )
                ) txreplay_inst (
                    .clk_100     ( bb_read_replay.clk                               ),
                    .sresetn_100 ( bb_read_replay.sresetn                           ),
                    .clk_150     ( ssi_out.clk                                      ),
                    .sresetn_150 ( ssi_out.sresetn                                  ),
                    .clk_300     ( clk_300                                          ), // must be rising-edge aligned with clk_150
                    .bb_ctrl     ( bb_ctrl_replay                                   ),
                    .bb_read     ( bb_read_replay                                   ),
                    .samples_out ( duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_TXREPLAY] ),
                    .mmi         ( mmi_replay                                       )
                );

                bb_nul_client no_txreplay_buf_bb_ctrl  ( .bbctrl ( bb_ctrl_replay_buf  ) );
                axis_nul_sink no_txreplay_buf_bb_read  ( .axis   ( bb_read_replay_buf  ) );
                axis_nul_src  no_txreplay_buf_bb_write ( .axis   ( bb_write_replay_buf ) );
            end
        end else begin : no_txreplay
            // tie off unused interfaces
            axis_nul_sink  no_tx_replay_bb_read     ( .axis   (bb_read_replay      ) );
            mmi_nul_slave  no_tx_replay_mmi         ( .mmi    (mmi_replay          ) );
            bb_nul_client  no_tx_replay_bb_ctrl     ( .bbctrl (bb_ctrl_replay      ) );
            axis_nul_src   no_tx_replay_samples     ( .axis   (duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_TXREPLAY] ) );
            bb_nul_client  no_txreplay_buf_bb_ctrl  ( .bbctrl (bb_ctrl_replay_buf  ) );
            axis_nul_sink  no_txreplay_buf_bb_read  ( .axis   (bb_read_replay_buf  ) );
            axis_nul_src   no_txreplay_buf_bb_write ( .axis   (bb_write_replay_buf ) );
        end

        // TX DUC shared by TX replay, RFoE, and IQ Tunnel
        if ( ENABLE_TXREPLAY || ENABLE_RFOE || ENABLE_IQ_TUNNEL) begin : gen_duc
            /**
             * Taking only the first parallel element of ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE] (this is the only element that
             * has actual RFoE data; the other element was zero-padded to match the form of ssi_ins)
             */
            always_comb begin
                for (int i=0; i<N_CHANNELS; i++) begin
                    ssi_rfoe.data[i][0] = ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE].data[i][0];
                end
                ssi_rfoe.valid      = ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE].valid;
                ssi_rfoe.center_ref = ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE].center_ref;
            end
            /**
             * txsdr_duc requires an AXIS input, not SSI, since it backpressures while zero-padding.
             * The RFoE source only asserts valid once every N cycles, where N is the upsampling factor, so a single
             * pipeline register is enough to ensure that ssi_ins[EXTERNAL_SSI_SRC_IDX_RFOE] is never backpressured.
             */
            ssi_to_axis #(
                .ALIGNED    ( 0 ) // txsdr_duc assumes that samples are efficiently packed
            ) ssi_to_axis_rfoe_inst (
                .ssi_in     ( ssi_rfoe.Sink     ),
                .axis_out   ( axis_rfoe.Master  )
            );

            axis_pipe_reg axis_rfoe_pipe_reg (
                .axis_in    ( axis_rfoe.Slave                              ),
                .axis_out   ( duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_RFOE] )
            );

            // Zero-pad 2-channel 1-parallel axis_iq_tunnel_in to match duc_axis_in (these extra channels are dropped inside
            // txsdr_duc)
            axis_connect axis_connect_iq_tunnel_in (
                .axis_in    ( axis_iq_tunnel_in                                 ),
                .axis_out   ( duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_IQ_TUNNEL] )
            );

            always_comb begin
                if (tx_mux_sel == INTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_SSI_SRC_IDX_RFOE) begin
                    // Select RFoE as the source
                    duc_source_select = TXSDR_DUC_PKG::AXIS_IN_IDX_RFOE;
                end else if (tx_mux_sel == INTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_AXIS_SRC_IDX_IQ_TUNNEL) begin
                    // Select IQ Tunnel as the source
                    duc_source_select = TXSDR_DUC_PKG::AXIS_IN_IDX_IQ_TUNNEL;
                end else begin
                    // Select TX replay as the source
                    duc_source_select = TXSDR_DUC_PKG::AXIS_IN_IDX_TXREPLAY;
                end
            end

            // Upsampling and interpolation
            txsdr_duc #(
                .ENABLE_RFOE        ( ENABLE_RFOE           ),
                .ENABLE_IQ_TUNNEL   ( ENABLE_IQ_TUNNEL      ),
                .USE_XILINX_DSP48E1 ( 1                     )
            ) txsdr_duc_inst (
                .clk_300            ( clk_300                                               ),
                .source_select      ( duc_source_select                                     ),
                .axis_in            ( duc_axis_in                                           ),
                .ssi_out            ( ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DUC]  )
            );
        end else begin : no_duc
            axis_nul_sink  no_tx_replay_sink    ( .axis   (duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_TXREPLAY]) );
            axis_nul_src   no_rfoe_src          ( .axis   (duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_RFOE]) );
            axis_nul_sink  no_rfoe_sink         ( .axis   (duc_axis_in[TXSDR_DUC_PKG::AXIS_IN_IDX_RFOE]) );
        end

    endgenerate


    nco_signal_source #(
        .USE_DITHER  ( 1'b1              ),
        .SAMPLE_RATE ( TXDAC_SAMPLE_RATE )
    ) nco_signal_source_inst (
        .clk_sdr     ( sdr.clk     ),
        .sresetn_sdr ( sdr.sresetn ),
        .mmi_in      ( mmi_nco     ),
        .ssi_out     ( nco_samples )
    );

    // Duplicate NCO Signal Source samples to both channels
    always_ff @(posedge ssi_out.clk) begin
        if (~ssi_out.sresetn) begin
            ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NCO].data <= '{N_CHANNELS{'{N_PARALLEL{'X}}}};
        end else begin
            for (int ch_idx = 0; ch_idx < 2; ch_idx++) begin
                for (int parallel_idx = 0; parallel_idx < N_PARALLEL; parallel_idx++) begin
                    for (int iq = 0; iq < 2; iq++) begin
                        ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NCO].data[2*ch_idx + iq][parallel_idx] <=
                            nco_samples.data[iq][parallel_idx];
                    end
                end
            end
        end
    end

    assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NCO].valid      = nco_samples.valid;
    assign ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NCO].center_ref = nco_samples.center_ref;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Switch between signal sources, apply digital gain, add DC offset


    assign mmi_buf_samples.tready = 1'b1; // always able to accept data

    // Mux and apply gain
    always_ff @(posedge ssi_out.clk) begin
        if (~ssi_out.sresetn) begin
            ssi_tx_gain_mult_out.data <= '{N_CHANNELS{'{N_PARALLEL{'X}}}};
        end else begin
            for (int ch_idx = 0; ch_idx < 2; ch_idx++) begin
                for (int parallel_idx = 0; parallel_idx < N_PARALLEL; parallel_idx++) begin
                    for (int iq = 0; iq < 2; iq++) begin
                        case (tx_mux_sel)
                            INTERNAL_SSI_SRC_IDX_DVB_S2         : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DVB_S2].data[2*ch_idx + iq][parallel_idx];
                            INTERNAL_SSI_SRC_IDX_DUC            : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DUC].data[2*ch_idx + iq][parallel_idx];
                            INTERNAL_SSI_SRC_IDX_NCO            : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NCO].data[2*ch_idx + iq][parallel_idx];
                            INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_AXIS_MMIBUFFER].data[2*ch_idx + iq][parallel_idx];
                            (INTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_SSI_SRC_IDX_DSSS) : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_ins[EXTERNAL_SSI_SRC_IDX_DSSS].data[2*ch_idx + iq][parallel_idx];
                            // If RFoE is selected, the output signal comes from the DUC module, not directly from the RFoE SSI input
                            (INTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_SSI_SRC_IDX_RFOE) : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DUC].data[2*ch_idx + iq][parallel_idx];
                            // If the IQ tunnel is selected, the output signal comes from the DUC module, not directly from the IQ tunnel SSI input
                            (INTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_SSI_SRC_NUM_INDICES+EXTERNAL_AXIS_SRC_IDX_IQ_TUNNEL) :
                                ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_DUC].data[2*ch_idx + iq][parallel_idx];
                            default                             : ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx] <=
                                tx_gain[ch_idx]*ssi_internal_txsdr_ssi_src[INTERNAL_SSI_SRC_IDX_NULL].data[2*ch_idx + iq][parallel_idx];
                        endcase
                    end
                end
            end
        end
    end

    // TODO: (cbrown) Eliminate this generate. Need different N_CHANNELS and N_PARALLEL for 300 Msps and 1200 Msps
    generate
    if (!ENABLE_TXDVBS2X) begin: gen_ssi_out_gain_offset
        // Bitshift multiplier output and add DC offset
        always_ff @(posedge ssi_out.clk) begin
            if (~ssi_out.sresetn) begin
                ssi_out.data <= '{N_CHANNELS{'{N_PARALLEL{'0}}}};
            end else begin
                for (int ch_idx = 0; ch_idx < 2; ch_idx++) begin
                    for (int parallel_idx = 0; parallel_idx < N_PARALLEL; parallel_idx++) begin
                        for (int iq = 0; iq < 2; iq++) begin
                            ssi_out.data[2*ch_idx + iq][parallel_idx] <=
                                ssi_tx_gain_mult_out.data[2*ch_idx + iq][parallel_idx][ssi_tx_gain_mult_out.NB-1:ssi_tx_gain_mult_out.NB_FRAC] +
                                tx_offset[2*ch_idx + iq];
                        end
                    end
                end
            end
        end
    end
    endgenerate

    assign ssi_tx_gain_mult_out.valid      = 1'b1;
    assign ssi_tx_gain_mult_out.center_ref = 1'b1;
    assign ssi_out.valid                   = 1'b1;
    assign ssi_out.center_ref              = 1'b1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MMI registers for controlling TX sources


    xclock_mmi #(
        .FF_CASCADE ( 2 ) // This must be at least 2
    ) xclock_mmi_txdsp (
        .m_clk    ( sdr.clk                   ),
        .m_resetn ( sdr.sresetn               ),
        .m_mmi    ( mmi_dsp                   ),

        .s_clk    ( ssi_out.clk               ),
        .s_resetn ( ssi_out.sresetn           ),
        .s_mmi    ( mmi_dsp_on_clk_ssi.Master )
    );

    txsdr_dsp_mmi #(
        .DEFAULT_TX_MUX_SEL ( DEFAULT_TX_MUX_SEL ),
        .DEFAULT_TX_GAIN0   ( DEFAULT_TX_GAIN0   ),
        .DEFAULT_TX_GAIN1   ( DEFAULT_TX_GAIN1   )
    ) txsdr_dsp_mmi_inst (
        .clk            ( ssi_out.clk              ),
        .reset_n        ( ssi_out.sresetn          ),
        .axisbuf_resetn ( axisbuf_resetn           ),
        .mod_resetn     ( mod_resetn               ),
        .tx_gain        ( tx_gain                  ),
        .tx_offset      ( tx_offset                ),
        .tx_mux_sel     ( tx_mux_sel               ),
        .mmi            ( mmi_dsp_on_clk_ssi.Slave )
    );
endmodule

`default_nettype wire
