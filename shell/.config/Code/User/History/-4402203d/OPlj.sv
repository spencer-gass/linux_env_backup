// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`include "../avmm/avmm_util.svh"
`default_nettype none

/**
 * TX symbol rate selection module. Takes in axis samples output from modulator (via dvbs2x_tx) and
 * allows user to select between 3 predefined symbol rates: Quarter, Half, and Full symbol rates
 * defined by (TXDAC_SAMPLE_RATE / SYMBOL_RATE_DIV) via an AVMM interface.
 *
 */
module dvbs2x_tx_symb_rate_divider_avmm
    import AVMM_COMMON_REGS_PKG::*;
    import DVBS2X_TX_SYMB_RATE_DIVIDER_PKG::*;
#(
    parameter bit [15:0]                 MODULE_ID             = 0,
    parameter int                        FIR_COEFF_NB_FRAC     = 15,
    parameter bit [SYMB_RATE_SEL_NB-1:0] DEFAULT_SYMB_RATE_SEL = TX_SYMB_RATE_FULL
) (
    Clock_int.Input         clk_ifc_sample,
    Reset_int.ResetIn       sreset_ifc_sample_device,

    Clock_int.Input         clk_ifc_avmm,
    Reset_int.ResetIn       sreset_ifc_avmm_interconnect,
    Reset_int.ResetIn       sreset_ifc_avmm_peripheral,

    AXIS_int.Slave          axis_in_dvbs2x,
    AXIS_int.Master         axis_out_dvbs2x,

    AvalonMM_int.Slave      avmm
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT    ( avmm.ADDRLEN,        0  );
    `ELAB_CHECK_EQUAL ( avmm.DATALEN,        32 );
    `ELAB_CHECK_EQUAL ( avmm.BURSTLEN,       1  );
    `ELAB_CHECK_EQUAL ( avmm.BURST_CAPABLE,  0  );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam bit [15:0] MODULE_VERSION = 1;

    // AVMM register map
    enum int {
        ADDR_SYMB_RATE_SEL,
        ADDR_SYMB_RATE,
        TOTAL_AVMM_REGS
    } avmm_addrs;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    // AVMM
    logic [SYMB_RATE_SEL_NB-1:0] symb_rate_sel;

    AvalonMM_int #(
        .DATALEN         ( avmm.DATALEN       ),
        .ADDRLEN         ( avmm.ADDRLEN       ),
        .BURSTLEN        ( avmm.BURSTLEN      ),
        .BURST_CAPABLE   ( avmm.BURST_CAPABLE )
    ) avmm_i();

    logic [TOTAL_AVMM_REGS-1:0] [avmm_i.DATALEN-1:0] regs;
    logic [avmm_i.ADDRLEN-1:0]                       word_address;


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

    function automatic logic writable_reg(input logic [avmm_i.ADDRLEN-1:0] word_address);
        writable_reg = word_address == ADDR_SYMB_RATE_SEL;
    endfunction

    function automatic logic undefined_addr(input logic [avmm_i.ADDRLEN-1:0] word_address);
        undefined_addr = word_address >= TOTAL_AVMM_REGS;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    dvbs2x_tx_symb_rate_divider_core #(
        .FIR_COEFF_NB_FRAC      ( FIR_COEFF_NB_FRAC ),
        .DEFAULT_SYMB_RATE_SEL  ( DEFAULT_SYMB_RATE_SEL )
    ) dvbs2x_tx_symb_rate_divider_core_inst (
        .clk_sample             ( clk_ifc_sample.clk        ),
        .sresetn_sample_device  ( sreset_ifc_sample_device.reset != sreset_ifc_sample_device.ACTIVE_HIGH ),
        .axis_in_dvbs2x         ( axis_in_dvbs2x            ),
        .axis_out_dvbs2x        ( axis_out_dvbs2x           ),
        .symb_rate_sel          ( symb_rate_sel             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUBSECTION: AVMM Interface


    avmm_common_regs #(
        .MODULE_ID                ( MODULE_ID       ),
        .MODULE_VERSION           ( MODULE_VERSION  ),
        .NUM_DEVICE_SPECIFIC_REGS ( TOTAL_AVMM_REGS )
    ) avmm_common_regs_inst (
        .clk_ifc                      ( clk_ifc_avmm                 ),
        .sreset_ifc_avmm_interconnect ( sreset_ifc_avmm_interconnect ),
        .sreset_ifc_avmm_device       ( sreset_ifc_avmm_peripheral   ),
        .avmm_in                      ( avmm                         ),
        .avmm_out                     ( avmm_i.Master                ),
        .slave_up                     ( sreset_ifc_avmm_peripheral.reset != sreset_ifc_avmm_peripheral.ACTIVE_HIGH ),
        .slave_prereq_met             ( '1                           ),
        .slave_coreq_met              ( '1                           )
    );

    xclock_vec_on_change #(
        .WIDTH ( SYMB_RATE_SEL_NB )
    ) xclock_avmm_to_sample (
        .in_clk           ( clk_ifc_avmm.clk   ),
        .in_rst           ( sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH ),
        .in_vec           ( regs[ADDR_SYMB_RATE_SEL][SYMB_RATE_SEL_NB-1:0] ),
        .out_clk          ( clk_ifc_sample.clk ),
        .out_rst          (                    ),
        .out_vec          ( symb_rate_sel      ),
        .out_changed_stb  (                    )
    );

    assign word_address = avmm_i.address >> $clog2(avmm_i.DATALEN/8);

    always_ff @(posedge clk_ifc_avmm.clk) begin

        if (sreset_ifc_avmm_interconnect.reset == sreset_ifc_avmm_interconnect.ACTIVE_HIGH ) begin
            avmm_i.waitrequest        <= 1'b1;
            avmm_i.response           <= 'X;
            avmm_i.writeresponsevalid <= 1'b0;
            avmm_i.readdata           <= 'X;
            avmm_i.readdatavalid      <= 1'b0;
        end else begin
            avmm_i.waitrequest        <= 1'b0;
            avmm_i.writeresponsevalid <= 1'b0;
            avmm_i.readdatavalid      <= 1'b0;

            if (avmm_i.write) begin
                avmm_i.response           <= avmm_i.RESPONSE_OKAY;
                avmm_i.writeresponsevalid <= 1'b1;

                if (writable_reg(word_address)) begin
                    regs[word_address] <= avmm_i.byte_lane_mask(regs[word_address]);
                end else if (undefined_addr(word_address)) begin
                    avmm_i.response    <= avmm_i.RESPONSE_SLAVE_ERROR;
                end

                // If either SYMB_RATE or SYMB_RATE_SEL are written, write the other with the appropriate value.
                // This way software can use either an index or a desired rate. Whichever is more convenient.
                if (word_address == ADDR_SYMB_RATE_SEL) begin
                    regs[ADDR_SYMB_RATE] <= SYMB_RATE_MSPS[avmm_i.byte_lane_mask(regs[word_address])];
                end

                if (word_address == ADDR_SYMB_RATE) begin
                    regs[ADDR_SYMB_RATE_SEL] <= symb_rate_to_sel(avmm_i.byte_lane_mask(regs[word_address]));
                end
            end

            if (avmm_i.read) begin
                avmm_i.readdatavalid <= 1'b1;

                if (undefined_addr(word_address)) begin
                    avmm_i.response <= avmm_i.RESPONSE_SLAVE_ERROR;
                end else begin
                    avmm_i.readdata <= regs[word_address];
                    avmm_i.response <= avmm_i.RESPONSE_OKAY;
                end
            end
        end

        if (sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH) begin
            regs[ADDR_SYMB_RATE_SEL] <= DEFAULT_SYMB_RATE_SEL;
        end
    end

endmodule

`default_nettype wire
