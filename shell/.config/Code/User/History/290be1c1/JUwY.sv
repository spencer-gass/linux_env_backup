// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for p4_router_avmm_regs
 */
module p4_router_avmm_regs_tb ();
    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;

    parameter bit   PROTOCOL_CHECK      = 1;
    parameter int   W_MAX_RESPONSE_TIME = 1000;
    parameter int   R_MAX_RESPONSE_TIME = 1000;
    parameter int   MAX_LATENCY         = 5;
    parameter int   RAND_RUNS           = 500;

    parameter int   DATALEN             = 32;
    parameter int   ADDRLEN             = 15;

    parameter int   NUM_ING_PHYS_PORTS  = 8;
    parameter int   NUM_EGR_PHYS_PORTS  = 8;
    parameter int   ING_COUNTERS_WIDTH  = 32;
    parameter int   EGR_COUNTERS_WIDTH  = 32;

    enum {
        ADDR_ING_PORT_ENABLE_CON = AVMM_COMMON_NUM_REGS,
        ADDR_EGR_PORT_ENABLE_CON,
        ADDR_ING_PORT_ENABLE_STAT,
        ADDR_EGR_PORT_ENABLE_STAT,
        ADDR_ING_COUNTER_CON,
        ADDR_EGR_COUNTER_CON,
        ADDR_ING_COUNTERS_START,
        ADDR_EGR_COUNTERS_START = ADDR_ING_COUNTERS_START + NUM_ING_PHYS_PORTS,
        TOTAL_REGS = ADDR_EGR_COUNTERS_START + NUM_EGR_PHYS_PORTS
    } reg_addrs;

    parameter  bit [15:0] MODULE_VERSION      = {8'b1, 8'b0};
    parameter  bit [15:0] MODULE_ID           = 10;

    localparam bit [DATALEN-1:0] MODULE_VERSION_ID = {MODULE_VERSION, MODULE_ID};

    /* svlint off localparam_type_twostate */
    localparam logic [TOTAL_REGS-1:0] [DATALEN-1:0] COMMON_REGS_INITVALS = '{
        AVMM_COMMON_VERSION_ID:             MODULE_VERSION_ID,
        AVMM_COMMON_STATUS_NUM_DEVICE_REGS: TOTAL_REGS,
        AVMM_COMMON_STATUS_PREREQ_MET:      '1,
        AVMM_COMMON_STATUS_COREQ_MET:       '1,
        default:                            '0
    };
    /* svlint on localparam_type_twostate */

    localparam  int BURSTLEN            = 1;
    localparam  int BURST_CAPABLE       = 0;

    localparam int NUM_CNTRS_PER_PHYS_PORT = 4;
    localparam int BYTE_CNT_INDEX = 0;
    localparam int PKT_CNT_INDEX = 5;
    localparam int ERR_CNT_INDEX = 6;

    localparam int ING_BUF_FULL_DROP_INDEX = 3;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces
    //

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) peripheral_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) interconnect_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 ) // Doesn't matter for TB
    ) core_sreset_ifc ();

    AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();

    // AVMM driver class
    avmm_m_test_driver_to_peripheral
    #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE ),
        .TOTAL_REGS    ( TOTAL_REGS    )
    ) avmm_driver;

    // Interface to keep track of current state of registers
    local_dut_regs_int #(
        .DATALEN    ( DATALEN    ),
        .TOTAL_REGS ( TOTAL_REGS )
    ) dut_regs_ifc();


    `MAKE_AVMM_MONITOR(avmm_monitor, avmm);

    generate
        if (PROTOCOL_CHECK) begin : gen_protocol_check
            avmm_protocol_check #(
                .W_MAX_RESPONSE_TIME   ( W_MAX_RESPONSE_TIME ),
                .R_MAX_RESPONSE_TIME   ( R_MAX_RESPONSE_TIME )
            ) protocol_check_inst (
                .clk_ifc    ( clk_ifc                   ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor      )
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

    // AVMM test signals
    logic   [ADDRLEN-1:0]   avmm_address;
    logic   [DATALEN/8-1:0] avmm_byteenable;
    logic   [DATALEN/8-1:0] avmm_byteenable_queue[$];
    logic   [BURSTLEN-1:0]  avmm_burstcount;
    logic   [1:0]           avmm_response;
    logic   [DATALEN-1:0]   avmm_writedata_queue[$];
    logic   [1:0]           avmm_response_queue[$];
    logic   [DATALEN-1:0]   avmm_readdata_queue[$];

    // DUT signals
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_phys_ports_enable;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_cnts_clear;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_cnts_sample_req;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_cnts_sample_req_d;
    logic [ING_COUNTERS_WIDTH-1:0]  ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0];
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_ports_conneted;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_buf_full_drop;
    logic [NUM_ING_PHYS_PORTS-1:0]  ing_buf_full_drop_d;
    logic [ING_COUNTERS_WIDTH-1:0]  ing_buf_full_drop_cnts [NUM_ING_PHYS_PORTS-1:0];


    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_phys_ports_enable;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_cnts_clear;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_cnts_sample_req;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_cnts_sample_req_d;
    logic [EGR_COUNTERS_WIDTH-1:0]  egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0];
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_ports_conneted;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_full_drop;
    logic [NUM_EGR_PHYS_PORTS-1:0]  egr_buf_full_drop_d;
    logic [EGR_COUNTERS_WIDTH-1:0]  egr_buf_full_drop_cnts [NUM_EGR_PHYS_PORTS-1:0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and test drivers
    //

    always #5  clk_ifc.clk <= ~clk_ifc.clk;
    always #2  core_clk_ifc.clk <= ~core_clk_ifc.clk;


    // function to check if the register at word_address is writable
    function automatic logic writable_reg(input logic [avmm.ADDRLEN-1:0] word_address);
        writable_reg = avmm.is_writable_common_reg(word_address) |
                        word_address == ADDR_ING_PORT_ENABLE_CON |
                        word_address == ADDR_ING_COUNTER_CON     |
                        word_address == ADDR_EGR_PORT_ENABLE_CON |
                        word_address == ADDR_EGR_COUNTER_CON;
    endfunction

    task automatic avmm_read_and_check;
        input int word_address;
    begin
        avmm_address    = word_address << 2;
        avmm_byteenable = '1;
        avmm_burstcount = 1;
        avmm_driver.read_data(avmm_address, avmm_readdata_queue, avmm_byteenable, avmm_burstcount, avmm_response_queue);
        `CHECK_EQUAL(avmm_response_queue[0], avmm.RESPONSE_OKAY, "Incorrect read response received.");
        `CHECK_EQUAL(avmm_readdata_queue[0], dut_regs_ifc.regs[word_address], "Incorrect read data received");
        avmm_readdata_queue.delete();
        avmm_response_queue.delete();
    end
    endtask

    task automatic avmm_write;
        input int word_address;
        input int data;
    begin
        avmm_address = word_address << 2;
        avmm_byteenable = '1;
        avmm_burstcount = 1;

        avmm_writedata_queue  = { data };
        avmm_byteenable_queue = { avmm_byteenable };

        avmm_driver.write_data(avmm_address, avmm_writedata_queue, avmm_byteenable_queue, avmm_burstcount, avmm_response);
        `CHECK_EQUAL(avmm_response, avmm.RESPONSE_OKAY, "Incorrect write response received.");
    end
    endtask

    task automatic avmm_write_zero;
        input int word_address;
    begin
        avmm_address          = word_address << 2;
        avmm_writedata_queue  = { '0 };
        avmm_byteenable       = '1;
        avmm_byteenable_queue = { avmm_byteenable };
        avmm_burstcount       = 1;

        avmm_driver.write_data(avmm_address, avmm_writedata_queue, avmm_byteenable_queue, avmm_burstcount, avmm_response);
        `CHECK_EQUAL(avmm_response, avmm.RESPONSE_OKAY, "Incorrect write response received.");
    end
    endtask

    task automatic rand_avmm_read;
    begin
        avmm_read_and_check($urandom_range(0, TOTAL_REGS));
    end
    endtask

    task automatic test_axis_profile_counters;

        automatic logic [31:0] cnts_to_sample = $urandom();

        // Latch all zeros for all counters
        ing_cnts = '{default: '{default: '0}};

        avmm_write(ADDR_ING_COUNTER_CON, '1);

        // verify that we read all zeros
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            for(int cntr=0; cntr<NUM_CNTRS_PER_PHYS_PORT; cntr++) begin
                avmm_read_and_check(ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+cntr);
            end
        end

        // Set counter value
        ing_cnts = '{default: '{default: 32'hAAAAAAAA}};

        // only sample some counters
        avmm_write(ADDR_ING_COUNTER_CON, cnts_to_sample);

        // verify that only the sampled counters changed
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            for(int cntr=0; cntr<NUM_CNTRS_PER_PHYS_PORT; cntr++) begin
                avmm_read_and_check(ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+cntr);
            end
        end

    endtask

    task automatic test_buf_drop_counters;

        // verify that we read all zeros
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            avmm_read_and_check(ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+ING_BUF_FULL_DROP_INDEX);
        end

        // Increment each counter by a different number
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            @(posedge core_clk_ifc.clk);
            #0;
            for (int b=0; b<NUM_ING_PHYS_PORTS; b++)begin
                if (b > ing_port) begin
                    ing_buf_full_drop[b] <= 1'b1;
                end
            end
            @(posedge core_clk_ifc.clk);
            #0;
            ing_buf_full_drop <= '0;
        end

        // only sample some counters
        avmm_write(ADDR_ING_COUNTER_CON, '1);

        // verify that only the sampled counters changed
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            for(int cntr=0; cntr<NUM_CNTRS_PER_PHYS_PORT; cntr++) begin
                avmm_read_and_check(ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+cntr);
            end
        end

    endtask

    // keep track of current word address during write bursts
    always_ff @(posedge clk_ifc.clk) begin
        if (interconnect_sreset_ifc.reset == interconnect_sreset_ifc.ACTIVE_HIGH) begin
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
        if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
            dut_regs_ifc.regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
            dut_regs_ifc.regs[ADDR_ING_COUNTER_CON]                             <= 32'b0;
            dut_regs_ifc.regs[ADDR_EGR_COUNTER_CON]                             <= 32'b0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON]                         <= '0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0] <= '1;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON]                         <= '0;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0] <= '1;
            for (int i=ADDR_ING_COUNTERS_START; i<TOTAL_REGS; i++) begin
                dut_regs_ifc.regs[i] <= '0;
            end
            ing_buf_full_drop_cnts <= '{default: '0};
            egr_buf_full_drop_cnts <= '{default: '0};
        end else begin
            dut_regs_ifc.regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_STAT]                         <= '0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_STAT][NUM_ING_PHYS_PORTS-1:0] <= dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0];
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_STAT]                         <= '0;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_STAT][NUM_EGR_PHYS_PORTS-1:0] <= dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0];

            ing_cnts_sample_req     <= dut_regs_ifc.regs[ADDR_ING_COUNTER_CON];
            ing_cnts_sample_req_d   <= ing_cnts_sample_req;
            ing_buf_full_drop_d     <= ing_buf_full_drop;
            for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
                if (ing_buf_full_drop[ing_port] && !ing_buf_full_drop_d[ing_port]) begin
                    ing_buf_full_drop_cnts[ing_port]++;
                end
                if (ing_cnts_sample_req[ing_port] && !ing_cnts_sample_req_d[ing_port]) begin
                    dut_regs_ifc.regs[ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+0] <= ing_cnts[ing_port][PKT_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+1] <= ing_cnts[ing_port][BYTE_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+2] <= ing_cnts[ing_port][ERR_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_ING_COUNTERS_START+ing_port*NUM_CNTRS_PER_PHYS_PORT+3] <= ing_buf_full_drop_cnts[ing_port];
                    ing_buf_full_drop_cnts[ing_port] <= '0;
                end
            end

            egr_cnts_sample_req     <= dut_regs_ifc.regs[ADDR_EGR_COUNTER_CON];
            egr_cnts_sample_req_d   <= egr_cnts_sample_req;
            egr_buf_full_drop_d     <= egr_buf_full_drop;
            for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
                if (egr_buf_full_drop && !egr_buf_full_drop_d) begin
                    egr_buf_full_drop_cnts[egr_port]++;
                end
                if (egr_cnts_sample_req[egr_port] && !egr_cnts_sample_req_d[egr_port]) begin
                    dut_regs_ifc.regs[ADDR_EGR_COUNTERS_START+egr_port*NUM_CNTRS_PER_PHYS_PORT+0] <= egr_cnts[egr_port][PKT_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_EGR_COUNTERS_START+egr_port*NUM_CNTRS_PER_PHYS_PORT+1] <= egr_cnts[egr_port][BYTE_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_EGR_COUNTERS_START+egr_port*NUM_CNTRS_PER_PHYS_PORT+2] <= egr_cnts[egr_port][ERR_CNT_INDEX];
                    dut_regs_ifc.regs[ADDR_EGR_COUNTERS_START+egr_port*NUM_CNTRS_PER_PHYS_PORT+3] <= egr_buf_full_drop_cnts[egr_port];
                    egr_buf_full_drop_cnts[egr_port] <= '0;
                end
            end

            if (avmm.write && writable_reg(tb_current_word_address)) begin
                dut_regs_ifc.regs[tb_current_word_address] <= avmm.byte_lane_mask(dut_regs_ifc.regs[tb_current_word_address]);
            end
        end
    end

    p4_router_avmm_regs #(
        .MODULE_ID              ( MODULE_ID          ),
        .ING_COUNTERS_WIDTH     ( ING_COUNTERS_WIDTH ),
        .EGR_COUNTERS_WIDTH     ( EGR_COUNTERS_WIDTH ),
        .NUM_ING_PHYS_PORTS     ( NUM_ING_PHYS_PORTS ),
        .NUM_EGR_PHYS_PORTS     ( NUM_EGR_PHYS_PORTS )
    ) dut (
        .avmm_clk_ifc               ( clk_ifc                   ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .core_clk_ifc               ( core_clk_ifc              ),
        .core_sreset_ifc            ( core_sreset_ifc           ),
        .avmm                       ( avmm                      ),
        .ing_phys_ports_enable      ( ing_phys_ports_enable     ),
        .ing_cnts_clear             ( ing_cnts_clear            ),
        .ing_cnts                   ( ing_cnts                  ),
        .ing_ports_conneted         ( ing_ports_conneted        ),
        .ing_buf_full_drop          ( ing_buf_full_drop         ),
        .egr_phys_ports_enable      ( egr_phys_ports_enable     ),
        .egr_cnts_clear             ( egr_cnts_clear            ),
        .egr_cnts                   ( egr_cnts                  ),
        .egr_ports_conneted         ( egr_ports_conneted        ),
        .egr_buf_full_drop          ( egr_buf_full_drop         )
    );

    assign ing_ports_conneted = ing_phys_ports_enable;
    assign egr_ports_conneted = egr_phys_ports_enable;

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            clk_ifc.clk      <= 1'b0;
            core_clk_ifc.clk <= 1'b0;

            avmm_driver = new (
                .clk_ifc                 ( clk_ifc                  ),
                .interconnect_sreset_ifc ( interconnect_sreset_ifc  ),
                .peripheral_sreset_ifc   ( peripheral_sreset_ifc    ),
                .avmm                    ( avmm                     ),
                .current_dut_regs_ifc    ( dut_regs_ifc             )
            );

            invalid_access_returns_error = 1'b1;
        end

        `TEST_CASE_SETUP begin
            avmm_driver.MAX_RAND_LATENCY = MAX_LATENCY;
            avmm_driver.set_random_latencies();

            interconnect_sreset_ifc.reset = 1'b1;
            peripheral_sreset_ifc.reset   = 1'b1;
            core_sreset_ifc.reset         = 1'b1;

            ing_buf_full_drop = 0;
            egr_buf_full_drop = 0;
            ing_cnts = '{default: '{default: '0}};
            egr_cnts = '{default: '{default: '0}};

            avmm_driver.init();

            @(posedge clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = 1'b0;
            core_sreset_ifc.reset         = 1'b0;

            @(posedge clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = 1'b0;

            avmm.byteenable = '1;
            @(posedge clk_ifc.clk);

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

        // Set, and sample counters that are managed by axis profile
        `TEST_CASE("test_axis_profile_counters") begin
            repeat(RAND_RUNS) begin
                test_axis_profile_counters();
            end
        end

        // Set and sample ingress/egress buffer full drop counters
        `TEST_CASE("test_buf_drop_counters") begin
            repeat(RAND_RUNS) begin
                test_buf_drop_counters();
            end
        end

    end

    `WATCHDOG(200ns + (RAND_RUNS * (MAX_LATENCY+1) * (2**(BURSTLEN-1)) * 100ns));
endmodule
