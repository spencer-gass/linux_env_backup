// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * TX symbol rate selection module. Takes in axis samples output from modulator (via dvbs2x_tx) and
 * allows user to select between 3 predefined symbol rates: Quarter, Half, and Full symbol rates
 * defined by (TXDAC_SAMPLE_RATE / SYMBOL_RATE_DIV) via an AVMM interface.
 *
 */
module dvbs2x_tx_symb_rate_divider_mmi
    import DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::*;
#(
    parameter int SYMB_RATE_MSPS [0:NUM_TX_SYMB_RATES-1]       = '{default:'0},
    parameter int                        FIR_COEFF_NB_FRAC     = 15,
    parameter bit [SYMB_RATE_SEL_NB-1:0] DEFAULT_SYMB_RATE_SEL = TX_SYMB_RATE_FULL
) (
    input var logic         clk_sample,
    input var logic         sresetn_sample,

    input var logic         clk_mmi,
    input var logic         sresetn_mmi_interconnect,
    input var logic         sresetn_mmi_peripheral,

    AXIS_int.Slave          axis_in_dvbs2x,
    AXIS_int.Master         axis_out_dvbs2x,

    MemoryMap_int.Slave     mmi
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    enum int {
        ADDR_SYMB_RATE,
        ADDR_SYMB_RATE_SEL,
        TOTAL_MMI_REGS
    } mmi_addrs;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations


    function logic [SYMB_RATE_SEL_NB-1:0] symb_rate_to_sel;
        input  logic [mmi.DATALEN-1:0] symbol_rate_msps;
    begin
        symb_rate_to_sel = DEFAULT_SYMB_RATE_SEL;
        for (int i = 0; i < NUM_TX_SYMB_RATES; i++) begin
            if (symbol_rate_msps == SYMB_RATE_MSPS[i]) begin
                symb_rate_to_sel = i;
            end
        end
    end
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [SYMB_RATE_SEL_NB-1:0]    symb_rate_sel
    logic [mmi.DATALEN-1:0]         symbol_rate;

    logic [mmi.DATALEN-1:0]         mmi_regs [0:TOTAL_MMI_REGS-1];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign mmi.wready   = sresetn_mmi_interconnect;
    assign mmi.arready  = sresetn_mmi_interconnect;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    assign symb_rate_sel    = symb_rate_to_sel(mmi_regs[ADDR_SYMB_RATE]);

    always_ff @(posedge clk_mmi) begin
        if (~sresetn_mmi_interconnect) begin
            mmi_regs    <= '{   SYMB_RATE_MSPS[DEFAULT_SYMB_RATE_SEL],
                                DEFAULT_SYMB_RATE_SEL                   };

            mmi.rvalid  <= 1'b0;
            mmi.rdata   <= 'X;

        end else begin
            if (mmi.wvalid && mmi.waddr < TOTAL_MMI_REGS) begin
                mmi_regs[mmi.waddr] <= mmi.wdata;
            end

            if (mmi.arvalid && mmi.raddr < TOTAL_MMI_REGS) begin
                mmi.rdata   <= mmi_regs[mmi.raddr];
                mmi.rvalid  <= 1'b1;
            else
                mmi.rdata   <= '0;
                mmi.rvalid  <= 1'b0;
            end

            if (mmi.rvalid & mmi.rready) begin
                mmi.rvalid  <= 1'b0;
            end

            mmi_regs[ADDR_SYMB_RATE_SEL] <= symb_rate_sel;
        end
    end
endmodule

`default_nettype wire
