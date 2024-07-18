// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * TX symbol rate selection module. Takes in axis samples output from modulator (via dvbs2x_tx) and
 * allows user to select between 3 predefined symbol rates: Quarter, Half, and Full symbol rates
 * defined by (TXDAC_SAMPLE_RATE / 2^(2-symb_rate_sel))
 *
 * TODO: testbench
 */
module dvbs2x_tx_symb_rate_divider_core
    import DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::*;
#(
    parameter bit [SYMB_RATE_SEL_NB-1:0] DEFAULT_SYMB_RATE_SEL = TX_SYMB_RATE_FULL
) (
    input var logic                        clk_sample,
    input var logic                        sresetn_sample_device,

    AXIS_int.Slave                         axis_in_dvbs2x,
    AXIS_int.Master                        axis_out_dvbs2x,

    input var logic [SYMB_RATE_SEL_NB-1:0] symb_rate_sel
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int N_CHANNELS        = 2;
    localparam int N_PARALLEL        = 8;
    localparam int TX_NB             = 16; // bits per sample
    localparam int FIR_COEFF_NB_FRAC = 15,


    localparam int TX_BYTES   = (TX_NB * N_CHANNELS * N_PARALLEL - 1)/8 + 1; // unaligned samples


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES         ),
        .ALLOW_BACKPRESSURE ( 0                ),
        .ALIGNED            ( 1'b1             ),
        .NB                 ( TX_NB            ),
        .N_CHANNELS         ( N_CHANNELS       ),
        .N_PARALLEL         ( N_PARALLEL       )
    ) axis_pre_fir [NUM_TX_SYMB_RATES-1:0] (
        .clk     ( clk_sample ),
        .sresetn ( sresetn_sample_device )
    );

    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES / 4     ),
        .ALLOW_BACKPRESSURE ( 0                ),
        .ALIGNED            ( 1'b1             ),
        .NB                 ( TX_NB            ),
        .N_CHANNELS         ( N_CHANNELS       ),
        .N_PARALLEL         ( N_PARALLEL / 4   )
    ) axis_fir_in_2_parallel (
        .clk     ( clk_sample ),
        .sresetn ( sresetn_sample_device )
    );

    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES / 2     ),
        .ALLOW_BACKPRESSURE ( 0                ),
        .ALIGNED            ( 1'b1             ),
        .NB                 ( TX_NB            ),
        .N_CHANNELS         ( N_CHANNELS       ),
        .N_PARALLEL         ( N_PARALLEL / 2   )
    ) axis_fir_in_4_parallel (
        .clk     ( clk_sample ),
        .sresetn ( sresetn_sample_device )
    );

    logic [2*8*TX_BYTES-1:0] axis_fir_out_quarter_tdata_32b;
    logic [2*8*TX_BYTES-1:0] axis_fir_out_half_tdata_32b;

    AXIS_int #(
        .DATA_BYTES         ( TX_BYTES         ),
        .ALLOW_BACKPRESSURE ( 0                ),
        .ALIGNED            ( 1'b1             ),
        .NB                 ( TX_NB            ),
        .N_CHANNELS         ( N_CHANNELS       ),
        .N_PARALLEL         ( N_PARALLEL       )
    ) axis_post_fir [NUM_TX_SYMB_RATES-1:0] (
        .clk     ( clk_sample ),
        .sresetn ( sresetn_sample_device )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUBSECTION: Interpolation and output selection


    // Demux to streams for each symbol rate
    axis_demux_kep #(
        .N ( NUM_TX_SYMB_RATES )
    ) axis_demux_kep_inst (
        .axis_in     ( axis_in_dvbs2x  ),
        .axis_out    ( axis_pre_fir    ),
        .sel         ( symb_rate_sel   ),
        .sel_invalid (                 )
    );


    // Quarter Symbol Rate

    // De-parallelize from 8-parallel to 2-parallel for filter input
    axis_adapter_wrapper axis_adapter_2_parallel (
        .axis_in    ( axis_pre_fir[TX_SYMB_RATE_QUARTER] ),
        .axis_out   ( axis_fir_in_2_parallel.Master     )
    );

    fir_compiler_dvbs2x_tx_quarter fir_compiler_dvbs2x_tx_quarter_inst (
        .aclk               ( clk_sample                                ),
        .s_axis_data_tvalid ( axis_fir_in_2_parallel.tvalid             ),
        .s_axis_data_tready ( axis_fir_in_2_parallel.tready             ),
        .s_axis_data_tdata  ( axis_fir_in_2_parallel.tdata              ),
        .m_axis_data_tvalid ( axis_post_fir[TX_SYMB_RATE_QUARTER].tvalid ),
        .m_axis_data_tdata  ( axis_fir_out_quarter_tdata_32b             ) // assumes FIR compiler is configured for 32b output sample width
    );

    // Tie off unused ports
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tstrb = '1;
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tkeep = '1;
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tlast = '1;
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tid   = '0;
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tdest = '0;
    assign axis_post_fir[TX_SYMB_RATE_QUARTER].tuser = '0;

    // TODO: Temporarily truncate FIR output. Replace with general convergent rounding module when complete
    always_comb begin
        for (int p = 0; p < N_PARALLEL; p++) begin
            for (int c = 0; c < N_CHANNELS; c++) begin
                axis_post_fir[TX_SYMB_RATE_QUARTER].tdata[TX_NB*(N_CHANNELS*p + c) +: TX_NB]
                    = axis_fir_out_quarter_tdata_32b[32*(N_CHANNELS*p + c) + FIR_COEFF_NB_FRAC +: TX_NB];
            end
        end
    end


    // Half Symbol Rate

    // De-parallelize from 8-parallel to 4-parallel for filter input
    axis_adapter_wrapper axis_adapter_4_parallel (
        .axis_in    ( axis_pre_fir[TX_SYMB_RATE_HALF] ),
        .axis_out   ( axis_fir_in_4_parallel.Master      )
    );

    fir_compiler_dvbs2x_tx_half fir_compiler_dvbs2x_tx_half_inst (
        .aclk               ( clk_sample                                 ),
        .s_axis_data_tvalid ( axis_fir_in_4_parallel.tvalid              ),
        .s_axis_data_tready ( axis_fir_in_4_parallel.tready              ),
        .s_axis_data_tdata  ( axis_fir_in_4_parallel.tdata               ),
        .m_axis_data_tvalid ( axis_post_fir[TX_SYMB_RATE_HALF].tvalid ),
        .m_axis_data_tdata  ( axis_fir_out_half_tdata_32b             ) // assumes FIR compiler is configured for 32b output sample width
    );

    // Tie off unused ports
    assign axis_post_fir[TX_SYMB_RATE_HALF].tstrb = '1;
    assign axis_post_fir[TX_SYMB_RATE_HALF].tkeep = '1;
    assign axis_post_fir[TX_SYMB_RATE_HALF].tlast = '1;
    assign axis_post_fir[TX_SYMB_RATE_HALF].tid   = '0;
    assign axis_post_fir[TX_SYMB_RATE_HALF].tdest = '0;
    assign axis_post_fir[TX_SYMB_RATE_HALF].tuser = '0;

    // TODO: Temporarily truncate FIR output. Replace with general convergent rounding module when complete
    always_comb begin
        for (int p = 0; p < N_PARALLEL; p++) begin
            for (int c = 0; c < N_CHANNELS; c++) begin
                axis_post_fir[TX_SYMB_RATE_HALF].tdata[TX_NB*(N_CHANNELS*p + c) +: TX_NB]
                    = axis_fir_out_half_tdata_32b[32*(N_CHANNELS*p + c) + FIR_COEFF_NB_FRAC +: TX_NB];
            end
        end
    end


    // Full Symbol Rate

    // This is the default symbol rate. No interpolation filter needed.
    axis_connect axis_connect_full (
        .axis_in  ( axis_pre_fir[TX_SYMB_RATE_FULL]  ),
        .axis_out ( axis_post_fir[TX_SYMB_RATE_FULL] )
    );


    // Select symbol rate
    axis_mux_kep #(
        .N ( NUM_TX_SYMB_RATES )
    ) axis_mux_symb_rate (
        .axis_in     ( axis_post_fir   ),
        .axis_out    ( axis_out_dvbs2x ),
        .sel         ( symb_rate_sel   ),
        .sel_invalid ( )
    );

endmodule
