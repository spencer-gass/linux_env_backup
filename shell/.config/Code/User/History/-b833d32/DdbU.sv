// CONFIDENTIAL
// Copyright (c) 2017 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

//`define I2C_MUX_DEBUG 1

/**
 * Allows multiple I2C drivers to control different devices on the same I2C bus
 *
 * If client i asserts i2c_mux_cmd[i].lock_req, then, once it is selected as
 * the active client, it will remain the active client until it deasserts its
 * lock request and any active transactions are completed.
 */
module i2c_mux #(
    parameter int MAX_CLK_DIVIDE     = 2**15,
    parameter int DEFAULT_CLK_DIVIDE = 100,  // Must be Multiple of 4
    parameter int I2C_MUX_FAN        = 3,    // Number of controllers
    parameter bit ENABLE_DRV_ILA     = 1'b0
)(
    I2CDriver_int.Driver i2c_mux_cmd [I2C_MUX_FAN-1:0],  // Command interface
    I2CIO_int.Driver i2c_mux_io,                         // Device interface


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Dynamic Clock Divider Control
    //
    // For setting the clock division at runtime: will take the value from
    // clk_divide when clk_divide_stb is strobed, but won't come into effect
    // during a command


    input var logic [$clog2(MAX_CLK_DIVIDE):0]  clk_divide,
    input var logic                             clk_divide_stb
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    // FSM States
    typedef enum {
        IDLE,   // Cycle through controllers till one makes a request
        CHECK,
        START   // Wait for I2C bus to finish
    }state_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic   clk, reset_n;
    state_t state_ff;
    logic   posedge_div_clk;
    logic   i2c_start_ff;

    logic [8*i2c_mux_cmd[0].I2C_MAXBYTES-1:0] rx_data_ff [I2C_MUX_FAN-1:0];
    logic [i2c_mux_cmd[0].I2C_MAXBYTES:0]     rx_ack_ff  [I2C_MUX_FAN-1:0];
    logic [I2C_MUX_FAN-1:0]                   rdy_ff;
    logic [$clog2(I2C_MUX_FAN):0]             ctrl_index;

    logic                                         in_start_cmd [I2C_MUX_FAN-1:0];
    logic [$clog2(i2c_mux_cmd[0].I2C_MAXBYTES):0] in_n_bytes   [I2C_MUX_FAN-1:0];
    logic                                         in_use_stop  [I2C_MUX_FAN-1:0];
    logic [6:0]                                   in_addr      [I2C_MUX_FAN-1:0];
    logic                                         in_rnotw     [I2C_MUX_FAN-1:0];
    logic [8*i2c_mux_cmd[0].I2C_MAXBYTES-1:0]     in_tx_data   [I2C_MUX_FAN-1:0];
    logic                                         in_lock_req  [I2C_MUX_FAN-1:0];

    // Instantiate the I2C Driver module
    I2CDriver_int #(
        .I2C_MAXBYTES    ( i2c_mux_cmd[0].I2C_MAXBYTES ),
        .CTRL_CLOCK_FREQ ( i2c_mux_cmd[0].CTRL_CLOCK_FREQ )
    ) i2c_cmd (
        .clk     ( clk     ),
        .reset_n ( reset_n )
    );

    I2CIO_int #() i2c_io ();

    i2c_drv # (
        .DEFAULT_CLK_DIVIDE ( DEFAULT_CLK_DIVIDE ),
        .ENABLE_DEBUG_ILA   ( ENABLE_DRV_ILA     )
    ) i2c_drv_inst (
        .i2c_cmd        ( i2c_cmd        ),
        .i2c_io         ( i2c_io         ),
        .clk_divide     ( clk_divide     ),
        .clk_divide_stb ( clk_divide_stb )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    assign clk = i2c_mux_cmd[0].clk;
    assign reset_n = i2c_mux_cmd[0].reset_n;

    generate
        for (genvar idx = 0; idx < I2C_MUX_FAN; idx++) begin: gen_block_mux_copy_signals
            // Inputs
            assign in_start_cmd [idx] = i2c_mux_cmd[idx].start_cmd;
            assign in_n_bytes   [idx] = i2c_mux_cmd[idx].n_bytes;
            assign in_use_stop  [idx] = i2c_mux_cmd[idx].use_stop;
            assign in_addr      [idx] = i2c_mux_cmd[idx].addr;
            assign in_rnotw     [idx] = i2c_mux_cmd[idx].rnotw;
            assign in_tx_data   [idx] = i2c_mux_cmd[idx].tx_data;
            assign in_lock_req  [idx] = i2c_mux_cmd[idx].lock_req;

            // Outputs
            assign i2c_mux_cmd[idx].rx_data = rx_data_ff[idx];
            assign i2c_mux_cmd[idx].rx_ack  = rx_ack_ff [idx];

            // Keep rdy signal high for all clients except the active one
            assign i2c_mux_cmd[idx].rdy = (idx == ctrl_index)? rdy_ff[idx] : 1;
        end
    endgenerate

    // Assigning the outputs of the i2c_driver to all the controllers
    always_comb begin
        if (~reset_n) begin
            for (int i = 0; i < I2C_MUX_FAN; i++) begin
                rx_ack_ff [i] = 0;
                rx_data_ff[i] = 0;
            end
        end else begin
            for (int i = 0; i < I2C_MUX_FAN; i++) begin
                rx_ack_ff [i] = i2c_cmd.rx_ack;
                rx_data_ff[i] = i2c_cmd.rx_data;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(~reset_n) begin
            state_ff     <= IDLE;
            i2c_start_ff <= 0;
            ctrl_index   <= 0;
            rdy_ff       <= '1;
        end else begin
            case(state_ff)
                IDLE: begin
                    rdy_ff[ctrl_index] <= i2c_cmd.rdy;
                    if (in_start_cmd[ctrl_index] && i2c_cmd.rdy) begin
                        i2c_start_ff <= 1'b1;
                        state_ff <= CHECK;
                    end else begin
                        // Increment control index ONLY if there is no active lock request from the
                        // current client.
                        if (!in_lock_req[ctrl_index]) begin
                            if(ctrl_index < I2C_MUX_FAN-1) begin
                                ctrl_index <= ctrl_index + 1;
                            end else begin
                                ctrl_index <= 0;
                            end
                        end
                    end
                end

                // Wait for command to be accepted
                CHECK: begin
                    if(~i2c_cmd.rdy) begin
                        state_ff <= START;
                        i2c_start_ff <= 1'b0;
                    end
                end

                START: begin
                    rdy_ff[ctrl_index] <= i2c_cmd.rdy;
                    if(i2c_cmd.rdy) begin
                        state_ff <= IDLE;
                        // Increment control index ONLY if there is no active lock request from the
                        // current client.
                        if (!in_lock_req[ctrl_index]) begin
                            if(ctrl_index < I2C_MUX_FAN-1) begin
                                ctrl_index <= ctrl_index + 1;
                            end else begin
                                ctrl_index <= 0;
                            end
                        end
                    end
                end
            endcase
        end
    end

    assign i2c_cmd.start_cmd = i2c_start_ff;
    assign i2c_cmd.n_bytes   = in_n_bytes [ctrl_index];
    assign i2c_cmd.use_stop  = in_use_stop[ctrl_index];
    assign i2c_cmd.addr      = in_addr    [ctrl_index];
    assign i2c_cmd.rnotw     = in_rnotw   [ctrl_index];
    assign i2c_cmd.tx_data   = in_tx_data [ctrl_index];
    assign i2c_cmd.lock_req  = in_lock_req[ctrl_index]; // Note this is unused in i2c_drv except in ILA

    assign i2c_mux_io.scl     = i2c_io.scl;
    assign i2c_mux_io.sda_out = i2c_io.sda_out;
    assign i2c_io.sda_in      = i2c_mux_io.sda_in;

    `ifndef MODEL_TECH
        `ifdef I2C_MUX_DEBUG

            logic i2c_state_change, i2c_clk_edge, i2c_scl_prev;
            state_t i2c_prev_state;

            always_ff @(posedge clk) begin
                if (~reset_n) begin
                    i2c_prev_state      <= IDLE;
                    i2c_scl_prev        <= 1'b0;
                end else begin
                    i2c_prev_state      <= state_ff;
                    i2c_scl_prev        <= i2c_io.scl;
                end
            end

            assign i2c_state_change = (state_ff != i2c_prev_state) ? 1'b1 : 1'b0;
            assign i2c_clk_edge     = (i2c_io.scl != i2c_scl_prev) ? 1'b1 : 1'b0;

            ila_debug i2c_mux_debug (
            .clk    ( clk                                                     ),
            .probe0 ( {i2c_mux_io.sda_in, i2c_mux_io.sda_out, i2c_mux_io.scl} ),
            .probe1 ( {i2c_cmd.start_cmd, i2c_cmd.rnotw, i2c_cmd.rdy}         ),
            .probe2 ( {i2c_io.scl, i2c_io.sda_in, i2c_io.sda_out}             ),
            .probe3 ( {in_start_cmd[0], in_start_cmd[1],
                       in_rnotw[0], in_rnotw[1],
                       rdy_ff[0], rdy_ff[1]}),
            .probe4 ( state_ff                                                ),
            .probe5 ( {i2c_mux_cmd[0].start_cmd,i2c_mux_cmd[1].start_cmd}     ),
            .probe6 (  i2c_mux_cmd[0].tx_data                                 ),
            .probe7 (  i2c_mux_cmd[1].tx_data                                 ),
            .probe8 (  i2c_mux_cmd[0].rdy                                     ),
            .probe9 (  i2c_mux_cmd[1].rdy                                     ),
            .probe10(  i2c_mux_cmd[0].addr                                    ),
            .probe11(  i2c_mux_cmd[1].addr                                    ),
            .probe12(  ctrl_index                                             ),
            .probe13(  i2c_clk_edge                                           ),
            .probe14(  i2c_state_change                                       ),
            .probe15( {i2c_mux_cmd[0].lock_req, i2c_mux_cmd[1].lock_req}      )
            );
        `endif
    `endif
endmodule

`default_nettype wire
