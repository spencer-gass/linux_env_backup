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
    import KAS_DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::*;
#(
    parameter int SYMB_RATE_MSPS [0:NUM_TX_SYMB_RATES-1]       = '{default:'0},
    parameter int                        FIR_COEFF_NB_FRAC     = 15,
    parameter bit [SYMB_RATE_SEL_NB-1:0] DEFAULT_SYMB_RATE_SEL = TX_SYMB_RATE_FULL
) (
    input var logic         clk_sample,
    input var logic         sresetn_sample_device,

    input var logic         clk_mmi,
    input var logic         sresetn_mmi_interconnect,
    input var logic         sresetn_mmi_peripheral,

    AXIS_int.Slave          axis_in_dvbs2x,
    AXIS_int.Master         axis_out_dvbs2x,

    MemoryMap_int.Slave     mmi
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam MODULE_VERSION = 1;

    enum int {
        ADDR_MODULE_VERSION,
        ADDR_SYMB_RATE_SEL,
        ADDR_SYMB_RATE,
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

    function automatic logic writable_reg(input logic [mmi.ADDRLEN-1:0] addr);
        writable_reg = addr == ADDR_SYMB_RATE || addr == ADDR_SYMB_RATE_SEL;
    endfunction

    function automatic logic undefined_addr(input logic [avmm_i.ADDRLEN-1:0] word_address);
        undefined_addr = word_address >= TOTAL_AVMM_REGS;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [SYMB_RATE_SEL_NB-1:0]    symb_rate_sel;
    logic [mmi.DATALEN-1:0]         symbol_rate;

    logic [mmi.DATALEN-1:0]         mmi_regs [0:TOTAL_MMI_REGS-1];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign mmi.wready   = sresetn_mmi_interconnect;
    assign mmi.arready  = sresetn_mmi_interconnect;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    dvbs2x_tx_symb_rate_divider_core #(
        .FIR_COEFF_NB_FRAC      ( FIR_COEFF_NB_FRAC ),
        .DEFAULT_SYMB_RATE_SEL  ( DEFAULT_SYMB_RATE_SEL )
    ) dvbs2x_tx_symb_rate_divider_core_inst (
        .clk_sample             ( clk_sample ),
        .sresetn_sample_device  ( sresetn_sample_device ),
        .axis_in_dvbs2x         ( axis_in_dvbs2x ),
        .axis_out_dvbs2x        ( axis_out_dvbs2x ),
        .symb_rate_sel          ( symb_rate_sel )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUBSECTION: MMI Interface


    xclock_vec_on_change #(
        .WIDTH ( SYMB_RATE_SEL_NB )
    ) xclock_mmi_to_sample (
        .in_clk           ( clk_mmi            ),
        .in_rst           ( ~sreset_mmi_peripheral ),
        .in_vec           ( regs[ADDR_SYMB_RATE_SEL][SYMB_RATE_SEL_NB-1:0] ),
        .out_clk          ( clk_sample         ),
        .out_rst          (                    ),
        .out_vec          ( symb_rate_sel      ),
        .out_changed_stb  (                    )
    );

    assign symb_rate_sel    = symb_rate_to_sel(mmi_regs[ADDR_SYMB_RATE]);

    always_ff @(posedge clk_mmi) begin
        if (~sresetn_mmi_interconnect) begin
            mmi_regs    <= '{   MODULE_VERSION,
                                SYMB_RATE_MSPS[DEFAULT_SYMB_RATE_SEL],
                                DEFAULT_SYMB_RATE_SEL                   };

            mmi.rvalid  <= 1'b0;
            mmi.rdata   <= 'X;

        end else begin
            mmi_regs[ADDR_MODULE_VERSION] <= MODULE_VERSION;

            if (mmi.wvalid && writable_reg(mmi.waddr)) begin
                mmi_regs[mmi.waddr] <= mmi.wdata;
            end

            // If either SYMB_RATE or SYMB_RATE_SEL are written, write the other with the appropriate value.
            // This way software can use either an index or a desired rate. Whichever is more convenient.
            if (mmi.wvalid && mmi.waddr == ADDR_SYMB_RATE_SEL) begin
                mmi_regs[ADDR_SYMB_RATE] <= SYMB_RATE_MSPS[mmi.wdata];
            end

            if (mmi.wvalid && mmi.waddr == ADDR_SYMB_RATE) begin
                mmi_regs[ADDR_SYMB_RATE_SEL] <= symb_rate_to_sel(mmi.wdata);
            end

            if (mmi.arvalid && undefined_addr(mmi.raddr)) begin
                mmi.rdata   <= '0;
                mmi.rvalid  <= 1'b1;
            end else if (mmi.arvalid) begin
                mmi.rdata   <= mmi_regs[mmi.raddr];
                mmi.rvalid  <= 1'b1;
            end

            if (mmi.rvalid & mmi.rready) begin
                mmi.rvalid  <= 1'b0;
            end

            mmi_regs[ADDR_SYMB_RATE_SEL] <= symb_rate_sel;
        end
    end
endmodule

`default_nettype wire
