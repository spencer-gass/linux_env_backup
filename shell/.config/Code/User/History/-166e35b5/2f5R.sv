// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module implements the AVMM register map and SPI control (via spi_mux)
 * for the AD5601 nanoDAC peripheral. It drives spi_mux using a SPIDriver_int.
 * Writing to the lower 16 bits of the DAC register initiates 16-bit SPI
 * transfers to the AD5601.
 *
 */
module dac_ad5601_ctrl_avmm
    import AVMM_COMMON_REGS_PKG::*;
#(
    parameter   bit [15:0]  MODULE_ID            = 0,
    parameter   bit         SET_DEFAULT_ON_RESET = 1'b0, // write the default DAC register value upon reset
    parameter   bit [15:0]  DAC_DEFAULT          = 0,    // default DAC register contents. for AD5601,
                                                         // bits [15:14] control the operating mode
                                                         // bits [13:6] are the data bits
                                                         // bits [5:0] are ignored
    parameter int           SPI_SS_BIT           = -1,
    parameter int           GAIN_WIDTH           = 8,
    parameter bit           DEBUG_ILA            = 0
) (
    Clock_int                         clk_ifc,
    Reset_int                         interconnect_sreset_ifc,
    Reset_int                         peripheral_sreset_ifc,

    input  var logic                  en_avmm_ctrl,

    AvalonMM_int.Slave                avmm,
    SPIDriver_int.Master              spi_cmd,

    input  var logic [GAIN_WIDTH-1:0] dac_reg,
    input  var logic                  dac_reg_valid_stb,
    output var logic                  dac_reg_updated_stb,

    output var logic                  initdone
);


    ////////////////////j///////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT    ( avmm.ADDRLEN,   0                       );
    `ELAB_CHECK_EQUAL ( avmm.DATALEN,   32                      );
    `ELAB_CHECK_EQUAL ( avmm.DATALEN,   2**$clog2(avmm.DATALEN) );
    `ELAB_CHECK_GE    ( spi_cmd.MAXLEN, 16                      );
    `ELAB_CHECK_GE    ( SPI_SS_BIT,     0                       );
    `ELAB_CHECK_EQUAL ( GAIN_WIDTH,     8                       );



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam bit SPI_SCLK_INVERT = 1'b1; // AD5601 clocks data on falling edge of SCLK

    localparam bit [15:0] MODULE_VERSION = 1;

    enum {
        ADDR_DAC_REG = AVMM_COMMON_NUM_REGS,
        ADDR_EN_AVMM_CTRL,
        TOTAL_REGS
    } reg_addrs;

    localparam bit [avmm.DATALEN-1:0] MODULE_VERSION_ID = {MODULE_VERSION, MODULE_ID};

    /* svlint off localparam_type_twostate */
    localparam logic [TOTAL_REGS-1:0] [avmm.DATALEN-1:0] COMMON_REGS_INITVALS = '{
        AVMM_COMMON_VERSION_ID:             MODULE_VERSION_ID,
        AVMM_COMMON_STATUS_NUM_DEVICE_REGS: TOTAL_REGS,
        AVMM_COMMON_STATUS_PREREQ_MET:      '1,
        AVMM_COMMON_STATUS_COREQ_MET:       '1,
        default:                            '0
    };
    /* svlint on localparam_type_twostate */

    localparam int DAC_SPI_MAXLEN = 16;

    typedef enum {
        IDLE,
        SPI_START_AFTER_RESET,
        SPI_START
    } state_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [TOTAL_REGS-1:0] [avmm.DATALEN-1:0] regs;

    logic [avmm.ADDRLEN-1:0]   word_address;
    logic [avmm.ADDRLEN-1:0]   current_word_address;    // incrementing address for burst transfers
    logic [avmm.BURSTLEN-1:0]  transfers_remaining;     // transfers remaining in a burst
    logic                      burst_write_in_progress;
    logic                      burst_read_in_progress;

    logic                      write_to_dac_reg;
    logic                      new_dac_wr_request;
    logic                      spi_rdy_posedge;
    logic                      rdy_prev;
    logic [DAC_SPI_MAXLEN-1:0] dac_reg_bits;

    state_t state_ff;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations


    function automatic logic writable_reg(input logic [avmm.ADDRLEN-1:0] word_address);
        writable_reg = (avmm.is_writable_common_reg(word_address)
                        || (word_address == ADDR_DAC_REG && regs[ADDR_EN_AVMM_CTRL]));
    endfunction

    function automatic logic undefined_addr(input logic [avmm.ADDRLEN-1:0] word_address);
        undefined_addr = word_address >= TOTAL_REGS;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    assign word_address = avmm.address >> 2;

    assign dac_reg_bits        = regs[ADDR_DAC_REG][DAC_SPI_MAXLEN-1:0]; // upper 16 bits are don't care
    assign spi_rdy_posedge     = (spi_cmd.rdy & ~rdy_prev);

    assign spi_cmd.n_clks      = DAC_SPI_MAXLEN;
    assign spi_cmd.stall_sclk  = '0;
    assign spi_cmd.hiz_mask    = '0;
    assign spi_cmd.ssn_mask    = ~(1 << SPI_SS_BIT);
    assign spi_cmd.sclk_invert = SPI_SCLK_INVERT;
    assign spi_cmd.start_delay = '0;

    assign write_to_dac_reg = regs[ADDR_EN_AVMM_CTRL] ?  (avmm.write & ((burst_write_in_progress & current_word_address == ADDR_DAC_REG) |
                                                         (~burst_write_in_progress & word_address == ADDR_DAC_REG))) :
                                                          dac_reg_valid_stb;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    // Initdone control
    generate
        // if set default on reset, initialization completes when default gain spi transaction is complete
        if (SET_DEFAULT_ON_RESET) begin : gen_set_default_on_reset
            always_ff @(posedge clk_ifc.clk) begin
                if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
                    initdone <= 1'b0;
                end else if (spi_rdy_posedge) begin
                    initdone <= 1'b1;
                end
            end
        // if not set default on reset, initialization completes when reset is deasserted
        end else begin : no_set_default_on_reset
            assign initdone = peripheral_sreset_ifc.reset != peripheral_sreset_ifc.ACTIVE_HIGH;
        end
    endgenerate

    always_ff @(posedge clk_ifc.clk) begin
        rdy_prev <= spi_cmd.rdy;
    end

    // SPI transfer control
    always_ff @(posedge clk_ifc.clk) begin
        if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
            state_ff            <= SET_DEFAULT_ON_RESET ? SPI_START_AFTER_RESET : IDLE; // in-progress SPI transactions are interrupted upon peripheral reset
            spi_cmd.tx_data     <= 'X;
            new_dac_wr_request  <= 1'b0;
            spi_cmd.start_cmd   <= 1'b0;
            dac_reg_updated_stb <= 1'b0;
        end else begin
            dac_reg_updated_stb <= 1'b0;
            case (state_ff)
                IDLE : begin
                    if (write_to_dac_reg) begin
                        state_ff          <= SPI_START;
                        spi_cmd.start_cmd <= 1'b1;
                        if (dac_reg_valid_stb && !regs[ADDR_EN_AVMM_CTRL]) begin
                            spi_cmd.tx_data       <= '0;
                            spi_cmd.tx_data[13:6] <= dac_reg;
                        end else begin
                            spi_cmd.tx_data       <= avmm.byte_lane_mask(regs[ADDR_DAC_REG]);
                        end
                    end
                end

                SPI_START_AFTER_RESET : begin
                    state_ff          <= SPI_START;
                    spi_cmd.start_cmd <= 1'b1;
                    spi_cmd.tx_data   <= dac_reg_bits;

                    if (write_to_dac_reg) begin
                        new_dac_wr_request <= 1'b1; // new AVMM write to DAC reg during cycle between reset deassertion and start of SPI command
                    end
                end

                SPI_START : begin
                    if (write_to_dac_reg) begin
                        new_dac_wr_request <= 1'b1; // new AVMM write to DAC reg during SPI transfer
                    end

                    if (spi_rdy_posedge) begin
                        dac_reg_updated_stb <= 1'b1;
                        if (new_dac_wr_request | write_to_dac_reg) begin
                            state_ff           <= SPI_START;
                            spi_cmd.tx_data    <= write_to_dac_reg ? avmm.byte_lane_mask(regs[ADDR_DAC_REG]) : dac_reg_bits;
                            new_dac_wr_request <= 1'b0;
                        end else begin
                            state_ff           <= IDLE;
                            spi_cmd.start_cmd  <= 1'b0;
                        end
                    end
                end

            endcase
        end
    end

    // AVMM transactions
    always_ff @(posedge clk_ifc.clk) begin
        if (interconnect_sreset_ifc.reset == interconnect_sreset_ifc.ACTIVE_HIGH) begin // AVMM bus reset
            avmm.waitrequest        <= 1'b1;
            avmm.response           <= 'X;
            avmm.writeresponsevalid <= 1'b0;
            avmm.readdata           <= 'X;
            avmm.readdatavalid      <= 1'b0;

            burst_write_in_progress <= 2'b0;
            burst_read_in_progress  <= 1'b0;
            current_word_address    <= 'X;
            transfers_remaining     <= 'X;

        end else begin
            avmm.writeresponsevalid <= 1'b0;
            avmm.readdatavalid      <= 1'b0;
            avmm.waitrequest        <= 1'b0;

            regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};
            regs[ADDR_EN_AVMM_CTRL]               <= {31'd0, en_avmm_ctrl};

            if (dac_reg_valid_stb && !regs[ADDR_EN_AVMM_CTRL]) begin
                regs[ADDR_DAC_REG][13:6] <= dac_reg;
            end

            if (avmm.write) begin
                if (burst_write_in_progress) begin
                    if (writable_reg(current_word_address)) begin
                        regs[current_word_address] <= avmm.byte_lane_mask(regs[current_word_address]);
                    end else if (undefined_addr(current_word_address)) begin
                        avmm.response              <= avmm.RESPONSE_SLAVE_ERROR;
                    end

                    // final transfer of burst
                    if (transfers_remaining == 1) begin
                        avmm.writeresponsevalid <= 1'b1;
                        burst_write_in_progress <= 1'b0;
                    end else begin
                        current_word_address    <= current_word_address + 1'b1;
                        transfers_remaining     <= transfers_remaining - 1'b1;
                    end
                end else begin
                    avmm.response <= avmm.RESPONSE_OKAY;

                    // write first word for burst or single transfer
                    if (writable_reg(word_address)) begin
                        regs[word_address]      <= avmm.byte_lane_mask(regs[word_address]);
                    end else if (undefined_addr(word_address)) begin
                        avmm.response           <= avmm.RESPONSE_SLAVE_ERROR;
                    end

                    // begin burst transfer
                    if (avmm.burstcount > 1) begin
                        burst_write_in_progress <= 1'b1;
                        transfers_remaining     <= avmm.burstcount - 1'b1;
                        current_word_address    <= word_address + 1'b1;

                    // single transfer
                    end else begin
                        avmm.writeresponsevalid <= 1'b1;
                    end
                end
            end // end avmm write

            if (avmm.read | burst_read_in_progress) begin
                avmm.readdatavalid <= 1'b1;

                if (burst_read_in_progress) begin
                    if (undefined_addr(current_word_address)) begin
                        avmm.response <= avmm.RESPONSE_SLAVE_ERROR;
                    end else begin
                        avmm.readdata <= regs[current_word_address];
                        avmm.response <= avmm.RESPONSE_OKAY;
                    end

                    // final transfer of burst
                    if (transfers_remaining == 1) begin
                        burst_read_in_progress <= 1'b0;
                    end else begin
                        current_word_address   <= current_word_address + 1'b1;
                        transfers_remaining    <= transfers_remaining - 1'b1;
                    end
                end else begin
                    // read first word for burst or single transfer
                    if (undefined_addr(word_address)) begin
                        avmm.response <= avmm.RESPONSE_SLAVE_ERROR;
                    end else begin
                        avmm.readdata <= regs[word_address];
                        avmm.response <= avmm.RESPONSE_OKAY;
                    end

                    // begin burst transfer
                    if (avmm.burstcount > 1) begin
                        burst_read_in_progress <= 1'b1;
                        transfers_remaining    <= avmm.burstcount - 1'b1;
                        current_word_address   <= word_address + 1'b1;
                    end
                end
            end // end avmm read
        end
        // peripheral_sreset resets the contents of the registers, even if a transaction is in progress
        if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
            regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
            regs[ADDR_DAC_REG]             <= {16'd0, DAC_DEFAULT};
        end
    end // end always block

    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                logic [31:0] dbg_cntr;
                always_ff @(posedge clk_ifc.clk) begin
                    if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
                        dbg_cntr <= '0;
                    end else begin
                        dbg_cntr <= dbg_cntr + 1'b1;
                    end
                end

                ila_debug dbg_pcuhdr_txsdr_avmm (
                    .clk    ( clk_ifc.clk                                      ),
                    .probe0 ({interconnect_sreset_ifc.reset,
                              peripheral_sreset_ifc.reset                     }),
                    .probe1 ({word_address[7:0], avmm.read                    }),
                    .probe2 ({avmm.byteenable,   avmm.response,
                              avmm.write,        avmm.writeresponsevalid,
                              avmm.readdatavalid                              }),
                    .probe3 ( avmm.writedata                                   ),
                    .probe4 ( avmm.readdata                                    ),
                    .probe5 ({spi_cmd.start_cmd,  spi_cmd.n_clks,
                              spi_cmd.stall_sclk, spi_cmd.ssn_mask,
                              spi_cmd.sclk_invert                             }),
                    .probe6 ( spi_cmd.tx_data[15:0]                            ),
                    .probe7 ({spi_cmd.rdy, spi_cmd.hiz_mask[15:0]             }),
                    .probe8 ( regs[ADDR_DAC_REG]                               ),
                    .probe9 ( spi_cmd.rx_miso[15:0]                            ),
                    .probe10( state_ff                                         ),
                    .probe11({write_to_dac_reg, new_dac_wr_request            }),
                    .probe12( dac_reg ),
                    .probe13( dac_reg_valid_stb ),
                    .probe14( dac_reg_updated_stb ),
                    .probe15( dbg_cntr )
                );
            end
        endgenerate
    `endif
endmodule

`default_nettype wire
