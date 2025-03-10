// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module is a basic AVMM slave which shall be used whenever basic AVMM
 * registers, with no side effects, are needed to be written to or read from
 * (e.g DRP GPIOs).
 *
 * Note:
 * This module does not support AVMM bursts.
 *
 * AVMM Registers:
 * After the 16 Kepler Common registers follow the input registers (read-only), then the output registers
 * (read/write), each in increasing index order.
 */
module avmm_gpio
    import AVMM_COMMON_REGS_PKG::*;
#(
    parameter bit   [15:0]          MODULE_VERSION  = 0,
    parameter bit   [15:0]          MODULE_ID       = 0,
    parameter int                   DATALEN         = 32,
    parameter int                   NUM_INPUT_REGS  = 1,
    parameter int                   NUM_OUTPUT_REGS = 1,
    parameter bit                   DEBUG_ILA       = 0,

    /* svlint off parameter_type_twostate */
    parameter logic   [DATALEN-1:0] DEFAULT_OUTPUT_VALS [0:NUM_OUTPUT_REGS-1] = '{default: '0}
    /* svlint on parameter_type_twostate */
)   (
    Clock_int.Input                         clk_ifc,
    Reset_int.ResetIn                       peripheral_sreset_ifc,
    Reset_int.ResetIn                       interconnect_sreset_ifc,
    AvalonMM_int.Slave                      avmm,
    input  var logic    [avmm.DATALEN-1:0]  input_vals  [0:NUM_INPUT_REGS-1 ],
    output var logic    [avmm.DATALEN-1:0]  output_vals [0:NUM_OUTPUT_REGS-1],
    output var logic                        gpout_stb
);


    /////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL(DATALEN, avmm.DATALEN);
    `ELAB_CHECK(~avmm.BURST_CAPABLE);
    `ELAB_CHECK_GE(NUM_INPUT_REGS,  1);
    `ELAB_CHECK_GE(NUM_OUTPUT_REGS, 1);


    /////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constants Delcarations


    localparam  int NUM_REGS            = NUM_OUTPUT_REGS + NUM_INPUT_REGS + AVMM_COMMON_NUM_REGS;
    localparam  int COMMON_REGS_START   = 0;
    localparam  int COMMON_REGS_END     = AVMM_COMMON_NUM_REGS - 1;
    localparam  int INPUT_REGS_START    = AVMM_COMMON_NUM_REGS;
    localparam  int INPUT_REGS_END      = INPUT_REGS_START + NUM_INPUT_REGS - 1;
    localparam  int OUTPUT_REGS_START   = INPUT_REGS_END + 1;
    localparam  int OUTPUT_REGS_END     = NUM_REGS-1;


    /////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic   [avmm.DATALEN-1:0]                                      regs [0:NUM_REGS-1];
    logic   [avmm.ADDRLEN-$clog2(avmm.DATALEN/8)-1:0]               address_word_index;
    logic   [$clog2(avmm.DATALEN/8)-1:0]                            address_byte_index;
    logic                                                           writable_addr;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations


    function automatic logic output_reg(input logic [avmm.ADDRLEN-1:0] address);
        output_reg = address inside {[OUTPUT_REGS_START : OUTPUT_REGS_END]};
    endfunction


    /////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign address_word_index   = avmm.address >> $clog2(avmm.DATALEN/8);
    assign address_byte_index   = avmm.address[$clog2(avmm.DATALEN/8)-1:0];
    assign writable_addr        = avmm.is_writable_common_reg(address_word_index) || output_reg(address_word_index);

    assign avmm.waitrequest     = 1'b0;

    generate
        for (genvar i = 0; i < NUM_OUTPUT_REGS; i++) begin
            assign output_vals[i]          = regs[OUTPUT_REGS_START +i];
        end
    endgenerate




    ////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    always_ff @(posedge clk_ifc.clk) begin
        // Interconnect reset to reset the AVMM read/write logic.
        if(interconnect_sreset_ifc.reset == interconnect_sreset_ifc.ACTIVE_HIGH) begin
            avmm.response           <= 'X;
            avmm.readdata           <= 'X;
            avmm.readdatavalid      <= 1'b0;
            avmm.writeresponsevalid <= 1'b0;
            gpout_stb               <= 1'b0;
        end else begin
            // Giving default values to our avmm outputs which may be overwritten below.
            avmm.response           <= 'X;
            avmm.readdata           <= 'X;
            avmm.writeresponsevalid <= 1'b0;
            avmm.readdatavalid      <= 1'b0;
            gpout_stb               <= 1'b0;

            // Address is word aligned, and within the register space
            if ( (address_word_index inside {[0:NUM_REGS-1]}) && (address_byte_index == 0) ) begin
                if(avmm.write) begin
                    avmm.response           <= avmm.RESPONSE_OKAY;
                    avmm.writeresponsevalid <= 1'b1;

                    // Checking if the address is pointing to a writable register, otherwise don't write.
                    if(writable_addr) begin
                        regs[address_word_index]    <= avmm.byte_lane_mask(regs[address_word_index]);

                        if (output_reg(address_word_index)) begin
                            gpout_stb               <= 1'b1;
                        end
                    end
                end

                if(avmm.read) begin
                    // All registers are readable
                    avmm.response       <= avmm.RESPONSE_OKAY;
                    avmm.readdatavalid  <= 1'b1;
                    avmm.readdata       <= regs[address_word_index];
                end

            // When the address is not word aligned or not within the register space, return SLAVE_ERROR.
            end else begin
                if(avmm.write) begin
                    avmm.writeresponsevalid <= 1'b1;
                    avmm.response           <= avmm.RESPONSE_SLAVE_ERROR;
                end

                if(avmm.read) begin
                    avmm.readdatavalid      <= 1'b1;
                    avmm.response           <= avmm.RESPONSE_SLAVE_ERROR;
                end
            end

            // Driving input registers
            for(int i = 0; i < NUM_INPUT_REGS; i++) begin
                regs[INPUT_REGS_START+i]    <= input_vals[i];
            end
        end

        // Peripheral reset to reset the contents of the registers.
        if(peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
            regs                                        <= '{default: '0};
            regs[AVMM_COMMON_VERSION_ID]                <= {MODULE_VERSION, MODULE_ID};
            regs[AVMM_COMMON_STATUS_NUM_DEVICE_REGS]    <= NUM_REGS;
            regs[AVMM_COMMON_STATUS_PREREQ_MET]         <= '1;
            regs[AVMM_COMMON_STATUS_COREQ_MET]          <= '1;
            for (int i = 0; i < NUM_OUTPUT_REGS; i++) begin
                regs[OUTPUT_REGS_START+i]               <= DEFAULT_OUTPUT_VALS[i];
            end
        end else begin
            regs[AVMM_COMMON_STATUS_DEVICE_STATE]   <= {31'd0, 1'b1}; // Device up
        end
    end

`ifndef MODEL_TECH
    generate
        if (DEBUG_ILA) begin : gen_ila
            ila_debug dbg_mmi (
                .clk     ( clk_ifc.clk ),
                .probe0  ( {interconnect_sreset_ifc.reset, peripheral_sreset_ifc.reset} ),
                .probe1  ( avmm.address ),
                .probe2  ( {avmm.burstcount, avmm.byteenable, avmm.waitrequest} ),
                .probe3  ( {avmm.read, avmm.write, avmm.readdatavalid} ),
                .probe4  ( avmm.writedata ),
                .probe5  ( {avmm.response, avmm.writeresponsevalid} ),
                .probe6  ( avmm.readdata ),
                .probe7  ( address_word_index ),
                .probe8  ( address_byte_index ),
                .probe9  ( writable_addr ),
                .probe10 ( output_vals[0] ),
                .probe11 ( input_vals[0] ),
                .probe12 ( 0 ),
                .probe13 ( 0 ),
                .probe14 ( 0 ),
                .probe15 ( 0 )
            );
        end
    endgenerate
`endif
endmodule

`default_nettype wire
