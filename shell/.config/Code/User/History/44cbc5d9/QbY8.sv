// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module implements the MMI register map and SPI control (via spi_mux)
 * for the AD5601 nanoDAC peripheral. It drives spi_mux using a SPIDriver_int.
 * Writing to the DAC register initiates 16-bit SPI transfers to the AD5601.
 *
 * Register Map:
 * <table>
 *   <tr><th>Offset</th><th>Register           </th><th>Description                                                    </th></tr>
 *   <tr><td>0     </td><td>MODULE_VERSION     </td><td>(r) </td></tr>
 *   <tr><td>1     </td><td>DAC_REG            </td><td>(r/w)
 *                                                            - [15:14] operating mode
 *                                                            - [13:6] data
 *                                                            - [5:0] reserved </td></tr>
 *   <tr><td>2     </td><td>EN_MMI_CTRL        </td><td>(r/w)
 *                                                            - [0] enables mmi writes to DAC_REG </td></tr>
 * </table>
 *
 */
module dac_ad5601_ctrl_mmi
#(
    parameter   bit         SET_DEFAULT_ON_RESET = 1'b0, // write the default DAC register value upon reset
    parameter   bit [15:0]  DAC_DEFAULT          = 0,    // default DAC register contents. for AD5601,
                                                         // bits [15:14] control the operating mode
                                                         // bits [13:6] are the data bits
                                                         // bits [5:0] are ignored
    parameter int           SPI_SS_BIT           = -1,
    parameter int           GAIN_WIDTH           = 8,
    parameter bit           DEBUG_ILA            = 0
) (

    input  var logic                  clk,
    input  var logic                  interconnect_sreset,
    input  var logic                  peripheral_sreset,

    input  var logic                  en_mmi_ctrl,

    MemoryMap_int.Slave               mmi,
    SPIDriver_int.Master              spi_cmd,

    input  var logic [GAIN_WIDTH-1:0] dac_data_in,
    input  var logic                  dac_data_in_valid_stb,
    output var logic                  dac_data_in_updated_stb,

    output var logic                  initdone
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT    ( mmi.ADDRLEN,    0                       );
    `ELAB_CHECK_GE    ( mmi.DATALEN,    16                      );
    `ELAB_CHECK_EQUAL ( mmi.DATALEN,    2**$clog2(mmi.DATALEN)  );
    `ELAB_CHECK_GE    ( spi_cmd.MAXLEN, 16                      );
    `ELAB_CHECK_GE    ( SPI_SS_BIT,     0                       );
    `ELAB_CHECK_EQUAL ( GAIN_WIDTH,     8                       );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam bit SPI_SCLK_INVERT = 1'b1; // AD5601 clocks data on falling edge of SCLK
    localparam int DAC_SPI_MAXLEN = 16;
    localparam int DAC_REG_RSVD_WIDTH = 6;

    localparam bit [15:0] MODULE_VERSION = 1;

    enum {
        ADDR_MODULE_VERSION,
        ADDR_DAC_REG,
        ADDR_EN_MMI_CTRL,
        TOTAL_REGS
    } reg_addrs;


    typedef enum {
        IDLE,
        SPI_START_AFTER_RESET,
        SPI_START
    } state_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [TOTAL_REGS-1:0] [mmi.DATALEN-1:0] regs;

    logic                      write_to_dac_reg;
    logic                      new_dac_wr_request;
    logic                      spi_rdy_posedge;
    logic                      rdy_prev;
    logic [DAC_SPI_MAXLEN-1:0] dac_reg_spi_tx;
    logic [DAC_SPI_MAXLEN-1:0] dac_reg_in;

    state_t state_ff;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations


    function automatic logic writable_reg(input logic [mmi.ADDRLEN-1:0] address);
        writable_reg = (address == ADDR_DAC_REG && regs[ADDR_EN_MMI_CTRL]);
    endfunction

    function automatic logic undefined_addr(input logic [mmi.ADDRLEN-1:0] address);
        undefined_addr = address >= TOTAL_REGS;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments

    assign mmi.arready = ~mmi.rvalid & ~interconnect_sreset;

    assign dac_reg_spi_tx = regs[ADDR_DAC_REG][DAC_SPI_MAXLEN-1:0];

    always_comb begin
        dac_reg_in = dac_reg_spi_tx;
        dac_reg_in[DAC_REG_RSVD_WIDTH +: GAIN_WIDTH] = dac_data_in;
    end

    assign spi_rdy_posedge     = (spi_cmd.rdy & ~rdy_prev);
    assign spi_cmd.n_clks      = DAC_SPI_MAXLEN;
    assign spi_cmd.stall_sclk  = '0;
    assign spi_cmd.hiz_mask    = '0;
    assign spi_cmd.ssn_mask    = ~(1 << SPI_SS_BIT);
    assign spi_cmd.sclk_invert = SPI_SCLK_INVERT;
    assign spi_cmd.start_delay = '0;

    assign write_to_dac_reg = regs[ADDR_EN_MMI_CTRL] ? (mmi.wvalid && mmi.wready && mmi.waddr == ADDR_DAC_REG) :
                                                         dac_data_in_valid_stb;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    // Initdone control
    generate
        // if set default on reset, initialization completes when default gain spi transaction is complete
        if (SET_DEFAULT_ON_RESET) begin : gen_set_default_on_reset
            always_ff @(posedge clk) begin
                if (peripheral_sreset) begin
                    initdone <= 1'b0;
                end else if (spi_rdy_posedge) begin
                    initdone <= 1'b1;
                end
            end
        // if not set default on reset, initialization completes when reset is deasserted
        end else begin : no_set_default_on_reset
            assign initdone = ~peripheral_sreset;
        end
    endgenerate

    always_ff @(posedge clk) begin
        rdy_prev <= spi_cmd.rdy;
    end

    // SPI transfer control
    always_ff @(posedge clk) begin
        if (peripheral_sreset) begin
            // in-progress SPI transactions are interrupted upon peripheral reset
            state_ff                <= SET_DEFAULT_ON_RESET ? SPI_START_AFTER_RESET : IDLE;
            spi_cmd.tx_data         <= 'X;
            new_dac_wr_request      <= 1'b0;
            spi_cmd.start_cmd       <= 1'b0;
            dac_data_in_updated_stb <= 1'b0;
        end else begin
            dac_data_in_updated_stb <= 1'b0;
            case (state_ff)
                IDLE : begin
                    if (write_to_dac_reg) begin
                        state_ff          <= SPI_START;
                        spi_cmd.start_cmd <= 1'b1;
                        if (dac_data_in_valid_stb && !regs[ADDR_EN_MMI_CTRL]) begin
                            spi_cmd.tx_data <= dac_reg_in;
                        end else begin
                            spi_cmd.tx_data <= mmi.wdata;
                        end
                    end
                end

                SPI_START_AFTER_RESET : begin
                    state_ff          <= SPI_START;
                    spi_cmd.start_cmd <= 1'b1;
                    spi_cmd.tx_data   <= dac_reg_spi_tx;

                    if (write_to_dac_reg) begin
                        new_dac_wr_request <= 1'b1; // new MMI write to DAC reg during cycle between reset deassertion and start of SPI command
                    end
                end

                SPI_START : begin
                    if (write_to_dac_reg) begin
                        new_dac_wr_request <= 1'b1; // new MMI write to DAC reg during SPI transfer
                    end

                    if (spi_rdy_posedge) begin
                        dac_data_in_updated_stb <= 1'b1;
                        if (new_dac_wr_request | write_to_dac_reg) begin
                            state_ff           <= SPI_START;
                            if (dac_data_in_valid_stb && !regs[ADDR_EN_MMI_CTRL]) begin
                                spi_cmd.tx_data <= dac_reg_in;
                            end else if (write_to_dac_reg) begin
                                spi_cmd.tx_data <= mmi.wdata;
                            end else begin
                                spi_cmd.tx_data <= dac_reg_spi_tx;
                            end
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


    // MMI transactions
    always_ff @(posedge clk) begin
        if (interconnect_sreset) begin
            mmi.wready  <= 1'b0;
            mmi.rvalid  <= 1'b0;
            mmi.rdata   <= 'X;
        end else begin

            regs[ADDR_MODULE_VERSION] <= MODULE_VERSION;
            regs[ADDR_EN_MMI_CTRL] <= {{(mmi.DATALEN-1){1'b0}}, en_mmi_ctrl};

            mmi.wready  <= 1'b1;
            if (dac_data_in_valid_stb && !regs[ADDR_EN_MMI_CTRL]) begin
                regs[ADDR_DAC_REG][13:6] <= dac_data_in;
            end

            if (mmi.wvalid && mmi.wready && writable_reg(mmi.waddr)) begin
                regs[mmi.waddr] <= mmi.wdata;
            end

            if (~mmi.rvalid) begin
                if (mmi.arready & mmi.arvalid) begin
                    mmi.rvalid <= 1'b1;

                    // Output the read value.
                    if (undefined_addr(mmi.raddr)) begin
                        mmi.rdata <= '0;
                    end else begin
                        mmi.rdata <= regs[mmi.raddr];
                    end
                end
            end else begin  // mmi.rvalid
                if (mmi.rready) begin
                    mmi.rvalid  <= 1'b0;
                end
            end

        end
        // peripheral_sreset resets the contents of the registers, even if a transaction is in progress
        if (peripheral_sreset) begin
            regs[ADDR_DAC_REG] <= DAC_DEFAULT;
        end
    end // end always block


    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                logic [31:0] dbg_cntr;
                always_ff @(posedge clk) begin
                    if (peripheral_sreset) begin
                        dbg_cntr <= '0;
                    end else begin
                        dbg_cntr <= dbg_cntr + 1'b1;
                    end
                end

                ila_debug dbg_pcuhdr_txsdr_mmi (
                    .clk    ( clk                                              ),
                    .probe0 ({interconnect_sreset,
                              peripheral_sreset                               }),
                    .probe1 ({mmi.arvalid , mmi.arready,
                              mmi.rvalid, mmi.rready, mmi.raddr               }),
                    .probe2 ({mmi.wvalid, mmi.wready, mmi.waddr}),
                    .probe3 ( mmi.wdata                                        ),
                    .probe4 ( mmi.rdata                                        ),
                    .probe5 ({spi_cmd.start_cmd,  spi_cmd.n_clks,
                              spi_cmd.stall_sclk, spi_cmd.ssn_mask,
                              spi_cmd.sclk_invert                             }),
                    .probe6 ( spi_cmd.tx_data[15:0]                            ),
                    .probe7 ({spi_cmd.rdy, spi_cmd.hiz_mask[15:0]             }),
                    .probe8 ( regs[ADDR_DAC_REG]                               ),
                    .probe9 ( spi_cmd.rx_miso[15:0]                            ),
                    .probe10( state_ff                                         ),
                    .probe11({write_to_dac_reg, new_dac_wr_request            }),
                    .probe12( dac_data_in ),
                    .probe13( dac_data_in_valid_stb ),
                    .probe14( dac_data_in_updated_stb ),
                    .probe15( dbg_cntr )
                );
            end
        endgenerate
    `endif
endmodule

`default_nettype wire