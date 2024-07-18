// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for dac_ad5601_ctrl_mmi.
 */
module dac_ad5601_ctrl_mmi_tb ();
    parameter  bit        PROTOCOL_CHECK      = 1;
    parameter  int        W_MAX_RESPONSE_TIME = 1000;
    parameter  int        R_MAX_RESPONSE_TIME = 1000;
    parameter  int        MAX_LATENCY         = 5;
    parameter  int        RAND_RUNS           = 500;

    parameter  int        DATALEN             = 16;
    parameter  int        ADDRLEN             = 15;
    parameter real        SIM_ASSIGN_DELAY    = 0.0;
    parameter  int        MMI_INIT_ON_RESET   = 1;


    parameter  bit        SET_DEFAULT_ON_RESET = 1'b1; // write the default DAC register value upon reset
    parameter  bit [15:0] DAC_DEFAULT          = 100;    // default DAC register contents. for AD5601,

    parameter  int        SPI_TRANSACTION_LEN  = 20; // used for modeling spi_mux rdy signal

    parameter  bit [15:0] MODULE_VERSION      = 1;

    enum {
        ADDR_MODULE_VERSION,
        ADDR_DAC_REG,
        ADDR_EN_MMI_CTRL,
        TOTAL_REGS
    } reg_addrs;

        typedef enum {
        IDLE,
        SPI_START,
        SPI_DONE1,
        SPI_DONE2
    } spi_state_t;

    localparam int SPI_TRANSFER_LEN  = 16;
    localparam int DAC_REG_RSVD_WIDTH = 6;
    localparam int DAC_GAIN_WIDTH = 8;
    localparam int SPI_NUM_DEVICES   = 1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces
    //


    // AGC module signals
    logic                 clk;
    logic                 interconnect_sreset;
    logic                 peripheral_sreset;

    MemoryMap_int #(
        .DATALEN          ( DATALEN         ),
        .ADDRLEN          ( ADDRLEN         ),
        .SIM_ASSIGN_DELAY ( SIM_ASSIGN_DELAY)
    ) mmi ();

    MMI_master #(
        .DATALEN(DATALEN),
        .ADDRLEN(ADDRLEN)
    ) mmi_driver (
        .clk        ( clk                 ),
        .sresetn    ( interconnect_sreset )
    );

    SPIDriver_int #(
        .MAXLEN      ( SPI_TRANSFER_LEN ),      // Max bits in a SPI Transaction
        .SSNLEN      ( SPI_NUM_DEVICES  )       // Number of slave devices
    ) spi_cmd [1] (
        .clk     ( clk                ),
        .sresetn ( ~peripheral_sreset )
    );

    SPIIO_int #(
        .CLK_DIVIDE ( 4 ),
        .SSNLEN     ( SPI_NUM_DEVICES )
    ) spi_io ();


    MMI_master_module #(
        .PROTOCOL_CHECK     ( PROTOCOL_CHECK     ),
        .RUN_INIT           ( MMI_INIT_ON_RESET  ),
        .W_MAX_RESPONSE_TIME( W_MAX_RESPONSE_TIME),
        .R_MAX_RESPONSE_TIME( R_MAX_RESPONSE_TIME)
    ) u_MMI_master_module(
        .control (mmi_driver ),
        .o       (mmi        )
    );

    // instantiate spi_mux to drive spi_cmd.rdy
    spi_mux #(
        .N ( 1 ),
        .MAXLEN ( SPI_TRANSFER_LEN )
    ) spi_mux_inst (
        .spi_in ( spi_cmd.Driver ),
        .spi_io ( spi_io.Driver )
    );

    // tie off spi_io.IO
    spi_nul_io_io spi_nul_io_io_inst ( .io ( spi_io.IO ) );


    `MAKE_MMI_MONITOR(mmi_monitor, mmi);


    // Testbench signals


    logic [TOTAL_REGS-1:0] [DATALEN-1:0] expected_dut_regs;

    logic                 expected_start_cmd;
    logic [15:0]          expected_tx_data;
    logic                 rdy_prev;
    logic                 rdy_posedge;
    logic                 reset_prev;
    logic                 reset_deassert;
    logic                 dac_write;
    logic                 new_dac_write;
    logic                 enable_tb_checks;
    logic [7:0]           dac_reg;
    logic                 dac_reg_valid_stb;
    logic                 dac_reg_updated_stb;
    logic                 en_mmi_ctrl;
    logic                 randomized;
    logic                 initdone;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers
    //

    always #5 clk <= ~clk;


    // function to check if the register at word_address is writable
    function automatic logic writable_reg(input logic [mmi.ADDRLEN-1:0] address);
        writable_reg = address == ADDR_DAC_REG && expected_dut_regs[ADDR_EN_MMI_CTRL];
    endfunction

    // sets a random dac_reg input value and strobes the dac_reg_valid signal
    task automatic strobe_dac_reg;
        input logic [7:0] dac_reg_value;
    begin
        dac_reg = dac_reg_value;
        dac_reg_valid_stb = 1'b1;
        @(posedge clk);
        #1;
        dac_reg_valid_stb = 1'b0;
    end
    endtask

    // Completes a single random DAC transaction
    task automatic rand_dac_write;
    begin
        strobe_dac_reg($urandom);
        while(~dac_reg_updated_stb) begin
            @(posedge clk);
        end
    end
    endtask

    // Completes a single random MMI write for the DAC register
    task automatic rand_mmi_write_dac_reg;
        automatic logic [ADDRLEN-1:0] waddr;
        automatic logic [DATALEN-1:0] wdata;
    begin
        waddr = { ADDR_DAC_REG };
        wdata = { $urandom() };
        mmi_driver.write_data(waddr, wdata);
    end
    endtask

    // Performs an checks a single MMI write to a random address
    task automatic rand_mmi_write;
        automatic  logic [ADDRLEN-1 : 0] waddr;
        automatic  logic [DATALEN-1 : 0] wdata;
        automatic  logic [DATALEN-1 : 0] rdata_pre;
        automatic  logic [DATALEN-1 : 0] rdata_post;
    begin
        wdata = $urandom();
        waddr = $urandom_range(0, TOTAL_REGS*2);
        mmi_driver.read_data(waddr, rdata_pre);
        mmi_driver.write_data(waddr, wdata);
        mmi_driver.read_data(waddr, rdata_post);

        if (waddr >= TOTAL_REGS) begin
            `CHECK_EQUAL(rdata_pre, 0);
            `CHECK_EQUAL(rdata_post, 0);
        end else if (~writable_reg(waddr)) begin
            `CHECK_EQUAL(rdata_pre, rdata_post);
        end else begin
            `CHECK_EQUAL(rdata_post, wdata);
            `CHECK_EQUAL(wdata, expected_dut_regs[waddr]);
        end
    end
    endtask

    // Performs and checks a single MMI read from a random address
    task automatic rand_mmi_read;
        automatic  logic [DATALEN-1 : 0] rdata;
        automatic  logic [ADDRLEN-1 : 0] raddr;
    begin
        raddr = $urandom_range(0, TOTAL_REGS*2);

        mmi_driver.read_data(raddr, rdata);

        if (raddr >= TOTAL_REGS) begin
            `CHECK_EQUAL(rdata, 0, "Invalid register reads non-zero value");
        end else begin
            `CHECK_EQUAL(rdata, expected_dut_regs[raddr], "Incorrect read data received");
        end
    end
    endtask

    // Performs num_runs randoms read and writes
    task automatic check_mmi_transfers;
        input      int                   num_runs;

        localparam bit                   READ  = 0;
        localparam bit                   WRITE = 1;

        automatic  bit                   transfer_type;
    begin
        repeat(num_runs) begin
            case (transfer_type)
                READ: begin
                    rand_mmi_read;
                end

                WRITE: begin
                    rand_mmi_write;
                end
            endcase
        end
    end
    endtask

    // Check that peripheral resets only reset the registers and do not
    // stop transactions in progress
    task automatic check_peripheral_reset;
        input int num_runs;

        localparam int MAX_RESET_WIDTH       = 20;
        localparam int NUM_TRANSFERS_PER_RUN = 5;
        localparam int INCLUDE_DELAY = 1;
    begin
        repeat(num_runs) begin
            @(posedge clk);
            #INCLUDE_DELAY;
            peripheral_sreset = 1'b1;
            @(posedge clk);
            fork
                begin
                    repeat($urandom_range(MAX_RESET_WIDTH)) @(posedge clk);
                    #INCLUDE_DELAY;
                    peripheral_sreset = 1'b0;
                end
                begin
                    check_mmi_transfers(NUM_TRANSFERS_PER_RUN);
                end
            join
        end
    end
    endtask

    // keep track of expected current state of DUT registers
    always_ff @(posedge clk) begin
        // reset values
        if (interconnect_sreset) begin
            expected_dut_regs[ADDR_MODULE_VERSION]  <= MODULE_VERSION;
            expected_dut_regs[ADDR_DAC_REG]         <= DAC_DEFAULT;
        end else begin

            expected_dut_regs[ADDR_EN_MMI_CTRL] <= {15'd0, en_mmi_ctrl};

            if (mmi.wvalid && mmi.wready && writable_reg(mmi.waddr)) begin
                expected_dut_regs[mmi.waddr] <= mmi.wdata;
            end else if (!expected_dut_regs[ADDR_EN_MMI_CTRL] && dac_write) begin
                expected_dut_regs[ADDR_DAC_REG][13:6] <= dac_reg;
            end
        end
    end

    // check for correct assertion/deassertion of spi_cmd.start_cmd and correct spi_cmd.tx_data
    assign dac_write       = (mmi.wvalid && mmi.wready && mmi.waddr == ADDR_DAC_REG) | dac_reg_valid_stb;
    assign rdy_posedge     = spi_cmd[0].rdy & ~rdy_prev;
    assign reset_deassert  = ~peripheral_sreset & reset_prev;

    always_ff @(posedge clk) begin
        rdy_prev                <= spi_cmd[0].rdy;
        reset_prev              <= peripheral_sreset;

        if (peripheral_sreset) begin
            expected_start_cmd   <= 1'b0;
            expected_tx_data     <= 'X;
            new_dac_write        <= 1'b0;

        end else begin
            if (reset_deassert & SET_DEFAULT_ON_RESET) begin // reset deasserted
                expected_start_cmd <= 1'b1;
                expected_tx_data   <= DAC_DEFAULT;
                new_dac_write      <= dac_write;

            end else if (rdy_posedge) begin // spi transfer completed
                new_dac_write <= 1'b0;
                if (dac_write | new_dac_write) begin // new dac write happening now or during spi transfer
                    expected_start_cmd <= 1'b1;
                    if (dac_reg_valid_stb) begin
                        expected_tx_data <= {expected_dut_regs[ADDR_DAC_REG][SPI_TRANSFER_LEN-1 : DAC_GAIN_WIDTH+DAC_REG_RSVD_WIDTH],
                                             dac_reg,
                                             expected_dut_regs[ADDR_DAC_REG][DAC_REG_RSVD_WIDTH-1:0]};
                    end else begin
                        expected_tx_data       <= dac_write ? mmi.wdata : expected_dut_regs[ADDR_DAC_REG];
                    end
                end else begin
                    expected_start_cmd <= 1'b0;
                end

            end else if (dac_write) begin // write to dac reg occurring at any time besides reset deassert and rdy assert
                expected_start_cmd <= 1'b1;
                if (expected_start_cmd) begin // write occurring while spi transfer in progress
                    new_dac_write <= 1'b1;
                end else begin
                    if (dac_reg_valid_stb) begin
                        expected_tx_data <= {expected_dut_regs[ADDR_DAC_REG][SPI_TRANSFER_LEN-1 : DAC_GAIN_WIDTH+DAC_REG_RSVD_WIDTH],
                                             dac_reg,
                                             expected_dut_regs[ADDR_DAC_REG][DAC_REG_RSVD_WIDTH-1:0]};
                    end else begin
                        expected_tx_data       <= mmi.wdata;
                    end

                end
            end
        end

        if (enable_tb_checks) begin
            `CHECK_EQUAL(expected_start_cmd, spi_cmd[0].start_cmd);
            `CHECK_EQUAL(expected_tx_data,  spi_cmd[0].tx_data);
        end
    end

    dac_ad5601_ctrl_mmi #(
        .SET_DEFAULT_ON_RESET ( SET_DEFAULT_ON_RESET ),
        .DAC_DEFAULT          ( DAC_DEFAULT          ),
        .SPI_SS_BIT           ( 0 )
    ) DUT (
        .clk                     ( clk                     ),
        .interconnect_sreset     ( interconnect_sreset     ),
        .peripheral_sreset       ( peripheral_sreset       ),
        .en_mmi_ctrl             ( en_mmi_ctrl             ),
        .mmi                     ( mmi.Slave               ),
        .spi_cmd                 ( spi_cmd[0].Master       ),
        .dac_reg                 ( dac_reg                 ),
        .dac_reg_valid_stb       ( dac_reg_valid_stb       ),
        .dac_reg_updated_stb     ( dac_reg_updated_stb     ),
        .initdone                ( initdone                )
    );


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk     <= 1'b0;

        end

        `TEST_CASE_SETUP begin
            @(posedge clk);
            interconnect_sreset     = 1'b1;
            peripheral_sreset       = 1'b1;
            enable_tb_checks        = 1'b0;
            dac_reg_valid_stb       = 1'b0;
            en_mmi_ctrl             = 1'b1;

            mmi_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            mmi_driver.randomize_r_latencies;
            mmi_driver.randomize_w_latency;


            @(posedge clk);
            #1;
            interconnect_sreset = 1'b0;

            @(posedge clk);
            #1;
            peripheral_sreset = 1'b0;
            enable_tb_checks = 1'b1;

            @(posedge clk);
            if(SET_DEFAULT_ON_RESET) begin
                while(~dac_reg_updated_stb) begin
                    @(posedge clk);
                end
            end
        end

        // a random series of mmi reads and writes
        `TEST_CASE("mmi_transfers") begin
            check_mmi_transfers(RAND_RUNS);
        end

        // a random series of mmi reads and writes while peripheral reset is asserted
        `TEST_CASE("peripheral_reset") begin
            check_peripheral_reset(RAND_RUNS);
        end

        // a random series of mmi reads
        `TEST_CASE("rand_mmi_read") begin
            repeat(RAND_RUNS) begin
                rand_mmi_read();
            end
        end

        // a random series of mmi writes to the dac reg
        `TEST_CASE("rand_mmi_dac_write") begin
            en_mmi_ctrl = 1'b1;
            repeat(RAND_RUNS) begin
                rand_mmi_write_dac_reg();
            end
        end

        // a random series of direct dac writes
        `TEST_CASE("rand_direct_dac_write") begin
            en_mmi_ctrl      = 1'b0;
            repeat(RAND_RUNS) begin
                rand_dac_write();
            end
        end

        // a random series of mmi and direct dac writes
        `TEST_CASE("rand_mmi_and_direct_dac_write") begin
            repeat(RAND_RUNS) begin
                randomized = $urandom();
                if(randomized) begin
                    en_mmi_ctrl = 1'b0;
                    @(posedge clk);
                    rand_dac_write();
                end else begin
                    en_mmi_ctrl = 1'b1;
                    @(posedge clk);
                    rand_mmi_write_dac_reg();
                end
            end
        end

        // write to dac_reg via MMI when en_mmi_ctrl=0
        `TEST_CASE("rand_mmi)dac_write_mmi_disabled") begin
            en_mmi_ctrl = 1'b0;
            repeat(RAND_RUNS) begin
                rand_mmi_write_dac_reg();
            end
        end

        // direct writes to dac_reg when en_mmi_ctrl=1
        `TEST_CASE("rand_dac_write_mmi_enabled") begin
            en_mmi_ctrl      = 1'b1;
            repeat(RAND_RUNS) begin
                rand_dac_write();
            end
        end
    end

    `WATCHDOG(1us + (RAND_RUNS * 1us));
endmodule
