// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for dac_ad5601_ctrl.
 */
module dac_ad5601_ctrl_avmm_tb ();
    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;

    parameter  bit        PROTOCOL_CHECK      = 1;
    parameter  int        W_MAX_RESPONSE_TIME = 1000;
    parameter  int        R_MAX_RESPONSE_TIME = 1000;
    parameter  int        MAX_LATENCY         = 5;
    parameter  int        RAND_RUNS           = 500;

    parameter  int        DATALEN             = 32;
    parameter  int        ADDRLEN             = 15;
    parameter  int        BURSTLEN            = 11;
    parameter  int        BURST_CAPABLE       = 1;

    parameter  bit        SET_DEFAULT_ON_RESET = 1'b1; // write the default DAC register value upon reset
    parameter  bit [15:0] DAC_DEFAULT          = 100;    // default DAC register contents. for AD5601,

    parameter  int        SPI_TRANSACTION_LEN  = 20; // used for modeling spi_mux rdy signal

    localparam int TOTAL_REGS        = AVMM_COMMON_NUM_REGS + 2;
    localparam int ADDR_DAC_REG      = TOTAL_REGS - 2;
    localparam int ADDR_EN_AVMM_CTRL = TOTAL_REGS - 1;
    localparam int SPI_TRANSFER_LEN  = 16;
    localparam int SPI_NUM_DEVICES   = 1;

    parameter  bit             [15:0] MODULE_VERSION      = 1;
    parameter  bit             [15:0] MODULE_ID           = 10;

    localparam bit      [DATALEN-1:0] MODULE_VERSION_ID = {MODULE_VERSION, MODULE_ID};

    /* svlint off localparam_type_twostate */
    localparam logic [TOTAL_REGS-1:0] [DATALEN-1:0] COMMON_REGS_INITVALS = '{
        AVMM_COMMON_VERSION_ID:             MODULE_VERSION_ID,
        AVMM_COMMON_STATUS_NUM_DEVICE_REGS: TOTAL_REGS,
        AVMM_COMMON_STATUS_PREREQ_MET:      '1,
        AVMM_COMMON_STATUS_COREQ_MET:       '1,
        default:                            '0
    };
    /* svlint on localparam_type_twostate */


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces
    //


    // AGC module signals
    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) peripheral_sreset_ifc ();


    AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();

    SPIDriver_int #(
        .MAXLEN      ( SPI_TRANSFER_LEN ),      // Max bits in a SPI Transaction
        .SSNLEN      ( SPI_NUM_DEVICES  )       // Number of slave devices
    ) spi_cmd [1] (
        .clk     ( clk_ifc.clk                 ),
        .sresetn ( ~peripheral_sreset_ifc.reset )
    );

    SPIIO_int #(
        .CLK_DIVIDE ( 4 ),
        .SSNLEN     ( SPI_NUM_DEVICES )
    ) spi_io ();

    // AVMM driver class
    avmm_m_test_driver_to_peripheral
    #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE ),
        .TOTAL_REGS    ( TOTAL_REGS    )
    ) avmm_driver;

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


    // Interface to keep track of current state of registers
    local_dut_regs_int #(
        .DATALEN    ( DATALEN    ),
        .TOTAL_REGS ( TOTAL_REGS )
    ) current_dut_regs_ifc();


    `MAKE_AVMM_MONITOR(avmm_monitor, avmm);

    generate
        if (PROTOCOL_CHECK) begin : gen_protocol_check
            avmm_protocol_check #(
                .W_MAX_RESPONSE_TIME   ( W_MAX_RESPONSE_TIME ),
                .R_MAX_RESPONSE_TIME   ( R_MAX_RESPONSE_TIME )
            ) protocol_check_inst (
                .clk_ifc    ( clk_ifc      ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor )
            );
        end
    endgenerate


    // Testbench signals
    logic [ADDRLEN-1:0]   test_address;
    logic [DATALEN/8-1:0] test_byteenable;
    logic [BURSTLEN-1:0]  test_burstcount;
    logic [DATALEN-1:0]   test_writedata;
    logic [DATALEN-1:0]   result_readdata;
    logic [1:0]           result_response;

    logic [ADDRLEN-1:0]   tb_current_word_address;
    logic [ADDRLEN-1:0]   tb_current_burst_address;
    logic [BURSTLEN-1:0]  tb_transfers_remaining;
    logic                 tb_burst_write_in_progress;

    logic invalid_access_returns_error; // indicate whether reads/writes to invalid addresses return avmm.SLAVE_ERROR

    typedef enum {
        IDLE,
        SPI_START,
        SPI_DONE1,
        SPI_DONE2
    } spi_state_t;

    spi_state_t  spi_state_ff;
    int          spi_cntr;
    logic        expected_start_cmd;
    logic [15:0] expected_tx_data;
    logic        rdy_prev;
    logic        rdy_posedge;
    logic        reset_prev;
    logic        reset_deassert;
    logic        dac_write;
    logic        new_dac_write;
    logic        enable_tb_checks;
    logic [7:0]  dac_reg;
    logic        dac_reg_valid_stb;
    logic        dac_reg_updated_stb;
    logic        en_avmm_ctrl;
    logic        randomized;
    logic        initdone;

    // AVMM test signals
    var   logic   [ADDRLEN-1:0]   avmm_address;
    var   logic   [DATALEN/8-1:0] avmm_byteenable;
    var   logic   [DATALEN/8-1:0] avmm_byteenable_queue[$];
    var   logic   [BURSTLEN-1:0]  avmm_burstcount;
    var   logic   [1:0]           avmm_response;
    var   logic   [DATALEN-1:0]   avmm_writedata_queue[$];
    var   logic   [1:0]           avmm_response_queue[$];
    var   logic   [DATALEN-1:0]   avmm_readdata_queue[$];

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers
    //


    always #5  clk_ifc.clk <= ~clk_ifc.clk;


    // function to check if the register at word_address is writable
    function automatic logic writable_reg(input logic [avmm.ADDRLEN-1:0] word_address);
        writable_reg = avmm.is_writable_common_reg(word_address) ||
                       (word_address == ADDR_DAC_REG && current_dut_regs_ifc.regs[ADDR_EN_AVMM_CTRL]);
    endfunction

    // sets a random dac_reg input value and strobes the dac_reg_valid signal
    task automatic strobe_dac_reg;
        input logic [7:0] dac_reg_value;
    begin
        dac_reg = dac_reg_value;
        dac_reg_valid_stb = 1'b1;
        @(posedge clk_ifc.clk);
        #1;
        dac_reg_valid_stb = 1'b0;
    end
    endtask

    // Completes a single random DAC transaction
    task automatic rand_dac_write;
    begin
        strobe_dac_reg($urandom);
        while(~dac_reg_updated_stb) begin
            @(posedge clk_ifc.clk);
        end
    end
    endtask

    // Completes a single random AVMM write for the DAC register
    task automatic rand_avmm_write_dac_reg;
    begin
        avmm_address          = { ADDR_DAC_REG << 2 };
        avmm_writedata_queue  = { $urandom() };
        avmm_byteenable       = '1;
        avmm_byteenable_queue = { avmm_byteenable };
        avmm_burstcount       = 1;

        avmm_driver.write_data(avmm_address, avmm_writedata_queue, avmm_byteenable_queue, avmm_burstcount, avmm_response);
        `CHECK_EQUAL(avmm_response, avmm.RESPONSE_OKAY, "Incorrect write response received.");

        avmm_writedata_queue.delete();
        avmm_byteenable_queue.delete();
    end
    endtask

    task automatic rand_avmm_read;
    begin
        avmm_address    = $urandom_range(0, TOTAL_REGS);
        avmm_byteenable = '1;
        avmm_burstcount = 1;

        avmm_driver.read_data(avmm_address, avmm_readdata_queue, avmm_byteenable, avmm_burstcount, avmm_response_queue);
        `CHECK_EQUAL(avmm_response_queue[0], avmm.RESPONSE_OKAY, "Incorrect read response received.");
        `CHECK_EQUAL(avmm_readdata_queue[0], current_dut_regs_ifc.regs[avmm_address >> 2], "Incorrect read data received");

        avmm_readdata_queue.delete();
        avmm_response_queue.delete();
    end
    endtask

    // keep track of current word address during write bursts
    always_ff @(posedge clk_ifc.clk) begin
        if (interconnect_sreset_ifc.reset) begin
            tb_current_burst_address   <= '0;
            tb_transfers_remaining     <= '0;
            tb_burst_write_in_progress <= 1'b0;
        end else begin
            if (avmm.write) begin
                if (tb_burst_write_in_progress) begin
                    if (tb_transfers_remaining == 1'b1) begin
                        tb_burst_write_in_progress <= 1'b0;
                    end else begin
                        tb_transfers_remaining   <= tb_transfers_remaining - 1'b1;
                        tb_current_burst_address <= tb_current_burst_address + 1'b1;
                    end
                end else begin
                    if (avmm.burstcount > 1) begin
                        tb_burst_write_in_progress <= 1'b1;
                        tb_transfers_remaining     <= avmm.burstcount - 1'b1;
                        tb_current_burst_address   <= (avmm.address >> 2) + 1'b1; // shift right by 2 to obtain word address
                    end
                end
            end
        end
    end

    assign tb_current_word_address = tb_burst_write_in_progress ? tb_current_burst_address : avmm.address >> 2;

    // keep track of expected current state of DUT registers
    always_ff @(posedge clk_ifc.clk) begin
        // reset values
        if (peripheral_sreset_ifc.reset) begin
            current_dut_regs_ifc.regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
            current_dut_regs_ifc.regs[ADDR_DAC_REG]             <= {16'd0, DAC_DEFAULT};
        end else begin
            current_dut_regs_ifc.regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};
            current_dut_regs_ifc.regs[ADDR_EN_AVMM_CTRL] <= {31'd0, en_avmm_ctrl};

            if (en_avmm_ctrl && avmm.write && writable_reg(tb_current_word_address)) begin
                current_dut_regs_ifc.regs[tb_current_word_address] <= avmm.byte_lane_mask(current_dut_regs_ifc.regs[tb_current_word_address]);
            end else if (~en_avmm_ctrl && dac_write) begin
                current_dut_regs_ifc.regs[ADDR_DAC_REG][13:6] <= dac_reg;
            end
        end
    end

    // check for correct assertion/deassertion of spi_cmd.start_cmd and correct spi_cmd.tx_data
    assign dac_write       = (avmm.write & tb_current_word_address == ADDR_DAC_REG) | dac_reg_valid_stb;
    assign rdy_posedge     = spi_cmd[0].rdy & ~rdy_prev;
    assign reset_deassert  = ~peripheral_sreset_ifc.reset & reset_prev;

    always_ff @(posedge clk_ifc.clk) begin
        rdy_prev                <= spi_cmd[0].rdy;
        reset_prev              <= peripheral_sreset_ifc.reset;

        if (peripheral_sreset_ifc.reset) begin
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
                        expected_tx_data[13:6] <= dac_reg;
                    end else begin
                        expected_tx_data       <= dac_write ? avmm.byte_lane_mask(current_dut_regs_ifc.regs[ADDR_DAC_REG])
                                                : current_dut_regs_ifc.regs[ADDR_DAC_REG];
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
                        expected_tx_data[13:6] <= dac_reg;
                    end else begin
                        expected_tx_data       <= avmm.byte_lane_mask(current_dut_regs_ifc.regs[ADDR_DAC_REG]);
                    end

                end
            end
        end

        if (enable_tb_checks) begin
            `CHECK_EQUAL(expected_start_cmd, spi_cmd[0].start_cmd);
            `CHECK_EQUAL(expected_tx_data,  spi_cmd[0].tx_data);
        end
    end

    dac_ad5601_ctrl_avmm #(
        .MODULE_ID            ( MODULE_ID            ),
        .SET_DEFAULT_ON_RESET ( SET_DEFAULT_ON_RESET ),
        .DAC_DEFAULT          ( DAC_DEFAULT          ),
        .SPI_SS_BIT           ( 0 )
    ) DUT (
        .clk_ifc                 ( clk_ifc                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc   ( peripheral_sreset_ifc   ),
        .en_avmm_ctrl            ( en_avmm_ctrl            ),
        .avmm                    ( avmm.Slave              ),
        .spi_cmd                 ( spi_cmd[0].Master       ),
        .dac_reg                 ( dac_reg                 ),
        .dac_reg_valid_stb       ( dac_reg_valid_stb       ),
        .dac_reg_updated_stb     ( dac_reg_updated_stb     ),
        .initdone                ( initdone                )
    );


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk_ifc.clk     <= 1'b0;

            avmm_driver = new (
                .clk_ifc                 ( clk_ifc                 ),
                .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
                .peripheral_sreset_ifc   ( peripheral_sreset_ifc   ),
                .avmm                    ( avmm                    ),
                .current_dut_regs_ifc    ( current_dut_regs_ifc    )
            );

            invalid_access_returns_error = 1'b1;
        end

        `TEST_CASE_SETUP begin
            avmm_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            avmm_driver.set_random_latencies();

            interconnect_sreset_ifc.reset = 1'b1;
            peripheral_sreset_ifc.reset   = 1'b1;
            enable_tb_checks              = 1'b0;

            dac_reg_valid_stb             = 1'b0;
            en_avmm_ctrl                  = 1'b1;

            avmm_driver.init();

            @(posedge clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = 1'b0;

            @(posedge clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = 1'b0;
            enable_tb_checks = 1'b1;

            avmm.byteenable = '1;
            @(posedge clk_ifc.clk);
            if(SET_DEFAULT_ON_RESET) begin
                while(~dac_reg_updated_stb) begin
                    @(posedge clk_ifc.clk);
                end
            end
        end

        `TEST_CASE("avmm_interface") begin
            avmm_driver.check_avmm_transfers(RAND_RUNS, invalid_access_returns_error);
        end

        `TEST_CASE("peripheral_reset") begin
            avmm_driver.check_peripheral_reset(RAND_RUNS, invalid_access_returns_error);
        end

        // a random series of avmm reads
        `TEST_CASE("rand_avmm_read") begin
            repeat(RAND_RUNS) begin
                rand_avmm_read();
            end
        end

        // a random series of avmm writes to the dac reg
        `TEST_CASE("rand_avmm_write") begin
            en_avmm_ctrl = 1'b1;
            repeat(RAND_RUNS) begin
                rand_avmm_write_dac_reg();
            end
        end

        // a random series of direct dac writes
        `TEST_CASE("rand_dac_write") begin
            en_avmm_ctrl = 1'b0;
            repeat(RAND_RUNS) begin
                rand_dac_write();
            end
        end

        // a random series of avmm and direct dac writes
        `TEST_CASE("rand_avmm_dac_write") begin
            repeat(RAND_RUNS) begin
                randomized = $urandom();
                if(randomized) begin
                    en_avmm_ctrl = 1'b0;
                    @(posedge clk_ifc.clk);
                    rand_dac_write();
                end else begin
                    en_avmm_ctrl = 1'b1;
                    @(posedge clk_ifc.clk);
                    rand_avmm_write_dac_reg();
                end

            end
        end
    end

    `WATCHDOG(200ns + (RAND_RUNS * (MAX_LATENCY+1) * (2**(BURSTLEN-1)) * 100ns));
endmodule
