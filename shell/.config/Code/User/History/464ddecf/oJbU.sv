// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for dac_ad5601_ctrl.
 */
module dac_ad5601_ctrl_mmi_tb ();
    parameter  bit        PROTOCOL_CHECK      = 1;
    parameter  int        W_MAX_RESPONSE_TIME = 1000;
    parameter  int        R_MAX_RESPONSE_TIME = 1000;
    parameter  int        MAX_LATENCY         = 5;
    parameter  int        RAND_RUNS           = 5;

    parameter  int        DATALEN             = 16;
    parameter  int        ADDRLEN             = 15;
    parameter real        SIM_ASSIGN_DELAY    = 0.0;
    parameter  int        MMI_INIT_ON_RESET   = 1;


    parameter  bit        SET_DEFAULT_ON_RESET = 1'b1; // write the default DAC register value upon reset
    parameter  bit [15:0] DAC_DEFAULT          = 100;    // default DAC register contents. for AD5601,

    parameter  int        SPI_TRANSACTION_LEN  = 20; // used for modeling spi_mux rdy signal

    parameter  bit [15:0] MODULE_VERSION      = 1;
    parameter  bit [15:0] MODULE_ID           = 10;

    enum {
        ADDR_MODULE_ID,
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
    localparam int SPI_NUM_DEVICES   = 1;
    

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

    MemoryMap_int #(
        .DATALEN          ( DATALEN         ),
        .ADDRLEN          ( ADDRLEN         ),
        .SIM_ASSIGN_DELAY ( SIM_ASSIGN_DELAY)
    ) mmi ();

    MMI_master #(
        .DATALEN(DATALEN),
        .ADDRLEN(ADDRLEN)
    ) mmi_driver (
        .clk        ( clk_ifc.clk                   ),
        .sresetn    ( interconnect_sreset_ifc.reset )
    );

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
    logic        en_mmi_ctrl;
    logic        randomized;
    logic        initdone;

    // test signals
    var   logic   [ADDRLEN-1:0]   mmi_waddr;
    var   logic   [ADDRLEN-1:0]   mmi_wword;
    var   logic   [ADDRLEN-1:0]   mmi_raddr;
    var   logic   [ADDRLEN-1:0]   mmi_rword;
    var   logic   [DATALEN-1:0]   mmi_wdata;
    var   logic   [DATALEN-1:0]   mmi_rdata;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers
    //


    always #5  clk_ifc.clk <= ~clk_ifc.clk;


    // function to check if the register at word_address is writable
    function automatic logic writable_reg(input logic [mmi.ADDRLEN-1:0] word_address);
        writable_reg = word_address == ADDR_DAC_REG;
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

    // Completes a single random MMI write for the DAC register
    task automatic rand_mmi_write_dac_reg;
    begin
        mmi_waddr = { ADDR_DAC_REG << 2 };
        mmi_wdata = { $urandom() };

        mmi_driver.write_data(mmi_waddr, mmi_wdata);

    end
    endtask

    task automatic rand_mmi_write;
        automatic  logic [ADDRLEN-1 : 0] waddr;
        automatic  logic [ADDRLEN-1 : 0] wword;
        automatic  logic [DATALEN-1 : 0] wdata;
        automatic  logic [DATALEN-1 : 0] rdata_pre;
        automatic  logic [DATALEN-1 : 0] rdata_post;
    begin
        wdata = $urandom();
        mmi_driver.read_data(waddr, rdata_pre);
        mmi_driver.write_data(waddr, wdata);
        //@(posedge clk_ifc.clk);
        mmi_driver.read_data(waddr, rdata_post);

        wword = waddr >> 2;
        if (wword >= TOTAL_REGS) begin
            `CHECK_EQUAL(rdata_pre, 0);
            `CHECK_EQUAL(rdata_post, 0);
        end else if (~writable_reg(wword)) begin
            `CHECK_EQUAL(rdata_pre, rdata_post);
        end else begin
            `CHECK_EQUAL(rdata_post, wdata);
            `CHECK_EQUAL(wdata, expected_dut_regs[wword]);
        end
    end
    endtask

    task automatic rand_mmi_read;
        automatic  logic [DATALEN-1 : 0] rdata;
        automatic  logic [ADDRLEN-1 : 0] raddr;
        automatic  logic [ADDRLEN-1 : 0] rword;
    begin
        raddr = $urandom_range(0, TOTAL_REGS*2);
        rword = raddr >> 2;

        mmi_driver.read_data(raddr, rdata);

        if (rword >= TOTAL_REGS) begin
            `CHECK_EQUAL(rdata, 0, "Invalid register reads non-zero value");
        end else begin
            `CHECK_EQUAL(rdata, expected_dut_regs[rword], "Incorrect read data received");
        end
    end
    endtask

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
            peripheral_sreset_ifc.reset = 1'b1;
            @(posedge clk_ifc.clk);
            fork
                begin
                    repeat($urandom_range(MAX_RESET_WIDTH)) @(posedge clk_ifc.clk);
                    #INCLUDE_DELAY;
                    peripheral_sreset_ifc.reset = 1'b0;
                end
                begin
                    check_mmi_transfers(NUM_TRANSFERS_PER_RUN);
                end
            join
        end
    end
    endtask

    assign mmi_wword = mmi.waddr >> 2;
    assign mmi_rword = mmi.raddr >> 2;

    // keep track of expected current state of DUT registers
    always_ff @(posedge clk_ifc.clk) begin
        // reset values
        if (peripheral_sreset_ifc.reset) begin
            expected_dut_regs[ADDR_MODULE_ID]       <= MODULE_ID;
            expected_dut_regs[ADDR_MODULE_VERSION]  <= MODULE_VERSION;
            expected_dut_regs[ADDR_DAC_REG]         <= DAC_DEFAULT;
        end else begin

            expected_dut_regs[ADDR_EN_MMI_CTRL] <= {31'd0, en_mmi_ctrl};

            if (en_mmi_ctrl && mmi.wvalid && mmi.wready && writable_reg(mmi_wword)) begin
                expected_dut_regs[mmi_wword] <= mmi.wdata;
            end else if (~en_mmi_ctrl && dac_write) begin
                expected_dut_regs[ADDR_DAC_REG][13:6] <= dac_reg;
            end
        end
    end

    // check for correct assertion/deassertion of spi_cmd.start_cmd and correct spi_cmd.tx_data
    assign dac_write       = (mmi.wvalid && mmi.wready && mmi_wword == ADDR_DAC_REG) | dac_reg_valid_stb;
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
                        expected_tx_data[13:6] <= dac_reg;
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
        .MODULE_ID            ( MODULE_ID            ),
        .SET_DEFAULT_ON_RESET ( SET_DEFAULT_ON_RESET ),
        .DAC_DEFAULT          ( DAC_DEFAULT          ),
        .SPI_SS_BIT           ( 0 )
    ) DUT (
        .clk_ifc                 ( clk_ifc                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc   ( peripheral_sreset_ifc   ),
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
            clk_ifc.clk     <= 1'b0;

        end

        `TEST_CASE_SETUP begin
            @(posedge clk_ifc.clk);
            interconnect_sreset_ifc.reset = 1'b1;
            peripheral_sreset_ifc.reset   = 1'b1;
            enable_tb_checks              = 1'b0;
            dac_reg_valid_stb             = 1'b0;
            en_mmi_ctrl                   = 1'b1;

            mmi_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            mmi_driver.randomize_r_latencies;
            mmi_driver.randomize_w_latency;
                       

            @(posedge clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = 1'b0;

            @(posedge clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = 1'b0;
            // enable_tb_checks = 1'b1;

            @(posedge clk_ifc.clk);
            if(SET_DEFAULT_ON_RESET) begin
                while(~dac_reg_updated_stb) begin
                    @(posedge clk_ifc.clk);
                end
            end
        end

        `TEST_CASE("mmi_transfers") begin
            check_mmi_transfers(RAND_RUNS);
        end

        `TEST_CASE("peripheral_reset") begin
            check_peripheral_reset(RAND_RUNS);
        end
    // <--- SRG ---> //

        // a random series of avmm reads
        `TEST_CASE("rand_mmi_read") begin
            repeat(RAND_RUNS) begin
                rand_mmi_read();
            end
        end

        // a random series of avmm writes to the dac reg
        `TEST_CASE("rand_mmi_write") begin
            en_mmi_ctrl = 1'b1;
            repeat(RAND_RUNS) begin
                rand_mmi_write_dac_reg();
            end
        end

        // a random series of direct dac writes
        `TEST_CASE("rand_dac_write") begin
            en_mmi_ctrl = 1'b0;
            repeat(RAND_RUNS) begin
                rand_dac_write();
            end
        end

        // // a random series of avmm and direct dac writes
        // `TEST_CASE("rand_avmm_dac_write") begin
        //     repeat(RAND_RUNS) begin
        //         randomized = $urandom();
        //         if(randomized) begin
        //             en_mmi_ctrl = 1'b0;
        //             @(posedge clk_ifc.clk);
        //             rand_dac_write();
        //         end else begin
        //             en_mmi_ctrl = 1'b1;
        //             @(posedge clk_ifc.clk);
        //             rand_avmm_write_dac_reg();
        //         end
                
        //     end
        // end
    end

    `WATCHDOG(200ns + (RAND_RUNS * (MAX_LATENCY+1) * 100ns));
endmodule
