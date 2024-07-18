// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`default_nettype none

/**
 * Parameters for dvbs2x_tx_symb_rate_divider.
 *
 */
package DVBS2X_TX_SYMB_RATE_DIVIDER_PKG;

    // AXIS mux source select info
    localparam int SYMB_RATE_SEL_NB = 2;

    enum bit [SYMB_RATE_SEL_NB-1:0] {
        TX_SYMB_RATE_QUARTER,
        TX_SYMB_RATE_HALF,
        TX_SYMB_RATE_FULL, // default
        NUM_TX_SYMB_RATES
    } tx_symb_rate_idx_t;

endpackage


package KAS_DVBS2X_TX_SYMB_RATE_DIVIDER_PKG;

    localparam int SYMB_RATE_MSPS [0:DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::NUM_TX_SYMB_RATES-1]  = {
        100, // TX_SYMB_RATE_QUARTER
        200, // TX_SYMB_RATE_HALF
        400  // TX_SYMB_RATE_FULL
    };

endpackage

`default_nettype wire
