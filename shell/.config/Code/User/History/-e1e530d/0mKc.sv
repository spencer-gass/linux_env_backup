// CONFIDENTIAL
// Copyright (c) 2025 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"

`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for p4_router_avmm_regs
 */
module p4_router_avmm_regs_tb ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import P4_ROUTER_PKG::*;
    import P4_ROUTER_TB_PKG::*;
    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameters


    parameter bit PROTOCOL_CHECK      = 1;
    parameter int W_MAX_RESPONSE_TIME = 1000;
    parameter int R_MAX_RESPONSE_TIME = 1000;
    parameter int MAX_LATENCY         = 5;
    parameter int RAND_RUNS           = 500;

    parameter int DATALEN             = 32;
    parameter int ADDRLEN             = 15;

    parameter int NUM_ING_PHYS_PORTS  = 11;
    parameter int NUM_EGR_PHYS_PORTS  = 11;

    parameter int NUM_QUEUES_PER_EGR_PORT = 8;

    parameter int MTU_BYTES       = 2000;
    parameter int VNP4_DATA_BYTES = 64;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Constants


    localparam int NUM_QUEUES     = NUM_EGR_PHYS_PORTS * NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);

    localparam int NUM_CNTRS_PER_ING_PHYS_PORT  = 5;
    localparam int NUM_CNTRS_PER_EGR_PHYS_PORT  = 4;

    localparam int ING_PKT_CNT_INDEX            = 0;
    localparam int ING_BYTE_CNT_INDEX           = 1;
    localparam int ING_ERR_CNT_INDEX            = 2;
    localparam int ING_BUF_OVF_CNT_INDEX        = 3;

    localparam int EGR_PKT_CNT_INDEX            = 0;
    localparam int EGR_BYTE_CNT_INDEX           = 1;
    localparam int EGR_ERR_CNT_INDEX            = 2;
    localparam int EGR_BUF_OVF_CNT_INDEX        = 3;

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

    localparam bit [7:0]  NUM_ING_PHYS_PORTS_VEC = NUM_ING_PHYS_PORTS;
    localparam bit [7:0]  NUM_EGR_PHYS_PORTS_VEC = NUM_EGR_PHYS_PORTS;
    localparam bit [7:0]  VNP4_DATA_BYTES_VEC    = VNP4_DATA_BYTES;
    localparam bit [15:0] MTU_BYTES_VEC          = MTU_BYTES;
    localparam bit [15:0] CLOCK_PERIOD_PS_VEC    = CORE_CLK_PERIOD * 1000;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clock and Reset Interfaces


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) avmm_clk_ifc ();

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


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interfaces


    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN  ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) cong_man_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_COUNTER_WIDTH    ),
        .ADDRLEN    ( QSYS_COUNTER_ID_WIDTH )
    ) cong_man_counter_access (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QSYS_TABLE_DATALEN  ),
        .ADDRLEN    ( QSYS_TABLE_ID_WIDTH )
    ) ing_policer_table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( 32             ),
        .ADDRLEN    ( NUM_QUEUES_LOG )
    ) cong_man_queue_occupancy (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             )
    ) queue_tail_pointer (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces


    AXIS_int #(
        .DATA_BYTES         ( VNP4_DATA_BYTES          ),
        .USER_WIDTH         ( POLICER_METADATA_WIDTH   ),
        .ALLOW_BACKPRESSURE ( 0                        )
    ) vnp4_to_policer (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES         ( VNP4_DATA_BYTES          ),
        .USER_WIDTH         ( POLICER_METADATA_WIDTH   ),
        .ALLOW_BACKPRESSURE ( 0                        )
    ) policer_to_cong_man (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES         ( VNP4_DATA_BYTES         ),
        .USER_WIDTH         ( CONG_MAN_METADATA_WIDTH ),
        .ALLOW_BACKPRESSURE ( 0                       )
    ) cong_man_to_enqueue (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES         ( 2 ),
        .ALLOW_BACKPRESSURE ( 0 )
    ) queue_mem_alloc (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Interfaces


    AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Signals


    // Testbench signals
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
    logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req_d;
    logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0];
    logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow_d;
    logic [ING_COUNTERS_WIDTH-1:0] ing_buf_overflow_cnts [NUM_ING_PHYS_PORTS-1:0];
    logic [ING_COUNTERS_WIDTH-1:0] ing_cnts_sampled [NUM_ING_PHYS_PORTS-1:0] [NUM_CNTRS_PER_ING_PHYS_PORT-1:0];

    logic [NUM_EGR_PHYS_PORTS-1:0] egr_phys_ports_enable;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_clear;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req_d;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0];
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_ports_conneted;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop_d;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_buf_full_drop_cnts [NUM_EGR_PHYS_PORTS-1:0];
    logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts_sampled [NUM_EGR_PHYS_PORTS-1:0] [NUM_CNTRS_PER_EGR_PHYS_PORT-1:0];

    logic [NUM_ING_PHYS_PORTS-1:0] ing_policer_enable;
    logic qsys_table_config_rd_busy;
    logic qsys_cntr_op_busy;
    logic qsys_cntr_op_err;
    logic [QSYS_COUNTER_WIDTH-1:0] qsys_cntr_rdata;
    logic qsys_config_rd_err;
    logic qsys_config_wr_err;
    logic [QSYS_TABLE_DATALEN-1:0] qsys_config_rdata;

    logic [63:0] ing_bus_pkt_cnt = '0;
    logic [63:0] qsys_in_pkt_cnt = '0;
    logic [63:0] enqueue_pkt_cnt = '0;
    logic [63:0] dequeue_pkt_cnt = '0;

    logic [63:0] ing_bus_pkt_cnt_sampled;
    logic [63:0] qsys_in_pkt_cnt_sampled;
    logic [63:0] enqueue_pkt_cnt_sampled;
    logic [63:0] dequeue_pkt_cnt_sampled;

    logic ing_ports_pkt_cnt_sample_req;
    logic ing_bus_pkt_cnt_sample_req;
    logic qsys_in_pkt_cnt_sample_req;
    logic enqueue_pkt_cnt_sample_req;
    logic dequeue_pkt_cnt_sample_req;
    logic egr_ports_pkt_cnt_sample_req;

    logic ing_ports_pkt_cnt_sample_req_d = 1'b0;
    logic ing_bus_pkt_cnt_sample_req_d   = 1'b0;
    logic qsys_in_pkt_cnt_sample_req_d   = 1'b0;
    logic enqueue_pkt_cnt_sample_req_d   = 1'b0;
    logic dequeue_pkt_cnt_sample_req_d   = 1'b0;
    logic egr_ports_pkt_cnt_sample_req_d = 1'b0;

    logic peripheral_sresetn_core;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test and Test Drivers


    always #AVMM_CLK_PERIOD  avmm_clk_ifc.clk <= ~avmm_clk_ifc.clk;
    always #CORE_CLK_PERIOD  core_clk_ifc.clk <= ~core_clk_ifc.clk;

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
                .clk_ifc    ( avmm_clk_ifc              ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor      )
            );
        end
    endgenerate

    // function to check if the register at word_address is writable
    function automatic logic writable_reg(input logic [avmm.ADDRLEN-1:0] word_address);
        writable_reg = avmm.is_writable_common_reg(word_address)
                     | word_address == ADDR_ING_PORT_ENABLE_CON
                     | word_address == ADDR_EGR_PORT_ENABLE_CON
                     | word_address == ADDR_ING_CNTRS_SAMPLE_CON
                     | word_address == ADDR_ING_CNTRS_READ_SEL
                     | word_address == ADDR_EGR_CNTRS_SAMPLE_CON
                     | word_address == ADDR_EGR_CNTRS_READ_SEL
                     | word_address == ADDR_ING_POLICER_ENABLE
                     | word_address == ADDR_QSYS_TABLE_CONFIG
                     | word_address == ADDR_QSYS_CONFIG_WDATA
                     | word_address == ADDR_QSYS_CNTR_CON
                     | word_address == ADDR_PKT_CNT_CON;
    endfunction

    // keep track of current word address during write bursts
    always_ff @(posedge avmm_clk_ifc.clk) begin
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

    xclock_resetn xclock_peripheral_sreset (
        .tx_clk     ( 1'b0                                                              ), // Only used if INPUT_REG = 1.
        .resetn_in  ( peripheral_sreset_ifc.reset != peripheral_sreset_ifc.ACTIVE_HIGH  ),
        .rx_clk     ( core_clk_ifc.clk                                                  ),
        .resetn_out ( peripheral_sresetn_core                                           )
    );

    // keep track of expected current state of DUT registers

    assign ing_cnts_sample_req = dut_regs_ifc.regs[ADDR_ING_CNTRS_SAMPLE_CON][NUM_ING_PHYS_PORTS-1:0];
    assign egr_cnts_sample_req = dut_regs_ifc.regs[ADDR_EGR_CNTRS_SAMPLE_CON][NUM_EGR_PHYS_PORTS-1:0];

    always_ff @(posedge avmm_clk_ifc.clk) begin
        if (!peripheral_sresetn_core) begin
            // Common
            dut_regs_ifc.regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
            dut_regs_ifc.regs[ADDR_PKT_CNT_CON]                                 <= '0;
            // Ingress
            dut_regs_ifc.regs[ADDR_ING_CNTRS_SAMPLE_CON]                        <= '0;
            dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL]                          <= '0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON]                         <= '0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0] <= '1;
            ing_buf_overflow_cnts                                               <= '{default: '0};
            ing_cnts_sampled                                                    <= '{default: '{default: '0}};
            // Queue System
            dut_regs_ifc.regs[ADDR_ING_POLICER_ENABLE]                          <= '0;
            dut_regs_ifc.regs[ADDR_QSYS_TABLE_CONFIG]                           <= '0;
            dut_regs_ifc.regs[ADDR_QSYS_CONFIG_WDATA]                           <= '0;
            dut_regs_ifc.regs[ADDR_QSYS_CONFIG_RDATA]                           <= '0;
            dut_regs_ifc.regs[ADDR_QSYS_CNTR_CON]                               <= '0;
            dut_regs_ifc.regs[ADDR_QSYS_CNTR_RDATA]                             <= '0;
            // Egress
            dut_regs_ifc.regs[ADDR_EGR_CNTRS_SAMPLE_CON]                        <= '0;
            dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL]                          <= '0;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON]                         <= '0;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0] <= '1;
            egr_buf_full_drop_cnts                                              <= '{default: '0};
            egr_cnts_sampled                                                    <= '{default: '{default: '0}};
        end else begin
            // Common
            dut_regs_ifc.regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};

            // Parameters
            dut_regs_ifc.regs[ADDR_PARAMS0] <= {VNP4_DATA_BYTES_VEC, NUM_EGR_PHYS_PORTS_VEC, NUM_ING_PHYS_PORTS_VEC};
            dut_regs_ifc.regs[ADDR_PARAMS1] <= {CLOCK_PERIOD_PS_VEC, MTU_BYTES_VEC};

           // Packet Counters
            ing_ports_pkt_cnt_sample_req <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][0];
            ing_bus_pkt_cnt_sample_req   <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][1];
            qsys_in_pkt_cnt_sample_req   <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][2];
            enqueue_pkt_cnt_sample_req   <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][3];
            dequeue_pkt_cnt_sample_req   <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][4];
            egr_ports_pkt_cnt_sample_req <= dut_regs_ifc.regs[ADDR_PKT_CNT_CON][5];

            ing_ports_pkt_cnt_sample_req_d <= ing_ports_pkt_cnt_sample_req;
            ing_bus_pkt_cnt_sample_req_d   <= ing_bus_pkt_cnt_sample_req;
            qsys_in_pkt_cnt_sample_req_d   <= qsys_in_pkt_cnt_sample_req;
            enqueue_pkt_cnt_sample_req_d   <= enqueue_pkt_cnt_sample_req;
            dequeue_pkt_cnt_sample_req_d   <= dequeue_pkt_cnt_sample_req;
            egr_ports_pkt_cnt_sample_req_d <= egr_ports_pkt_cnt_sample_req;

            if (ing_bus_pkt_cnt_sample_req && !ing_bus_pkt_cnt_sample_req_d) begin
                ing_bus_pkt_cnt_sampled <= ing_bus_pkt_cnt;
            end

            if (qsys_in_pkt_cnt_sample_req && !qsys_in_pkt_cnt_sample_req_d) begin
                qsys_in_pkt_cnt_sampled <= qsys_in_pkt_cnt;
            end

            if (enqueue_pkt_cnt_sample_req && !enqueue_pkt_cnt_sample_req_d) begin
                enqueue_pkt_cnt_sampled <= enqueue_pkt_cnt;
            end

            if (dequeue_pkt_cnt_sample_req && !dequeue_pkt_cnt_sample_req_d) begin
                dequeue_pkt_cnt_sampled <= dequeue_pkt_cnt;
            end

            case (dut_regs_ifc.regs[ADDR_PKT_CNT_CON][11:8])
                ING_BUS_PKT_CNTR : begin
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA0] <= ing_bus_pkt_cnt_sampled[31:0];
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA1] <= ing_bus_pkt_cnt_sampled[63:32];
                end
                QSYS_IN_PKT_CNTR : begin
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA0] <= qsys_in_pkt_cnt_sampled[31:0];
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA1] <= qsys_in_pkt_cnt_sampled[63:32];
                end
                ENQUEUE_PKT_CNTR : begin
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA0] <= enqueue_pkt_cnt_sampled[31:0];
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA1] <= enqueue_pkt_cnt_sampled[63:32];
                end
                DEQUEUE_PKT_CNTR : begin
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA0] <= dequeue_pkt_cnt_sampled[31:0];
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA1] <= dequeue_pkt_cnt_sampled[63:32];
                end
                default: begin
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA0] <= '0;
                    dut_regs_ifc.regs[ADDR_PKT_CNT_RDATA1] <= '0;
                end
            endcase

            // Ingress
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_STAT]                         <= '0;
            dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_STAT][NUM_ING_PHYS_PORTS-1:0] <= dut_regs_ifc.regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0];

            ing_cnts_sample_req_d       <= ing_cnts_sample_req;
            ing_buf_overflow_d          <= ing_buf_overflow;
            for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
                if (ing_buf_overflow[ing_port] && !ing_buf_overflow_d[ing_port]) begin
                    ing_buf_overflow_cnts[ing_port]++;
                end
                if (ing_cnts_sample_req[ing_port] && !ing_cnts_sample_req_d[ing_port] ||
                ing_ports_pkt_cnt_sample_req && !ing_ports_pkt_cnt_sample_req_d) begin
                    ing_cnts_sampled[ing_port][ING_PKT_CNT_INDEX           ] <= ing_cnts[ing_port][AXIS_PROFILE_PKT_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_BYTE_CNT_INDEX          ] <= ing_cnts[ing_port][AXIS_PROFILE_BYTE_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_ERR_CNT_INDEX           ] <= ing_cnts[ing_port][AXIS_PROFILE_ERR_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_BUF_OVF_CNT_INDEX       ] <= ing_buf_overflow_cnts[ing_port];
                    ing_buf_overflow_cnts[ing_port] <= '0;
                end
            end

            if (dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][15:8] < NUM_ING_PHYS_PORTS &&
                dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][7:0]  < NUM_CNTRS_PER_ING_PHYS_PORT) begin
                dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_DATA0] <= ing_cnts_sampled[dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][15:8]][dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][7:0]][31:0];
                dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_DATA1] <= ing_cnts_sampled[dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][15:8]][dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_SEL][7:0]][63:32];
            end else begin
                dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_DATA0] <= '0;
                dut_regs_ifc.regs[ADDR_ING_CNTRS_READ_DATA1] <= '0;
            end

            // Queue System

            dut_regs_ifc.regs[ADDR_QSYS_TABLE_CONFIG][27] <= ing_policer_table_config.wvalid | cong_man_table_config.wvalid;
            dut_regs_ifc.regs[ADDR_QSYS_TABLE_CONFIG][26] <= qsys_table_config_rd_busy;
            dut_regs_ifc.regs[ADDR_QSYS_TABLE_CONFIG][28] <= qsys_config_rd_err;
            dut_regs_ifc.regs[ADDR_QSYS_TABLE_CONFIG][29] <= qsys_config_wr_err;
            dut_regs_ifc.regs[ADDR_QSYS_CONFIG_RDATA]     <= qsys_config_rdata;
            dut_regs_ifc.regs[ADDR_QSYS_CNTR_CON][25]     <= qsys_cntr_op_busy;
            dut_regs_ifc.regs[ADDR_QSYS_CNTR_CON][26]     <= qsys_cntr_op_err;
            dut_regs_ifc.regs[ADDR_QSYS_CNTR_RDATA]       <= qsys_cntr_rdata;

            // Egress
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_STAT]                         <= '0;
            dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_STAT][NUM_EGR_PHYS_PORTS-1:0] <= dut_regs_ifc.regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0];

            egr_cnts_sample_req_d   <= egr_cnts_sample_req;
            egr_buf_full_drop_d     <= egr_buf_full_drop;
            for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
                if (egr_buf_full_drop[egr_port] && !egr_buf_full_drop_d[egr_port]) begin
                    egr_buf_full_drop_cnts[egr_port]++;
                end
                if (egr_cnts_sample_req[egr_port] && !egr_cnts_sample_req_d[egr_port] ||
                egr_ports_pkt_cnt_sample_req && !egr_ports_pkt_cnt_sample_req_d) begin
                    egr_cnts_sampled[egr_port][EGR_PKT_CNT_INDEX    ] <= egr_cnts[egr_port][AXIS_PROFILE_PKT_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_BYTE_CNT_INDEX   ] <= egr_cnts[egr_port][AXIS_PROFILE_BYTE_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_ERR_CNT_INDEX    ] <= egr_cnts[egr_port][AXIS_PROFILE_ERR_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_BUF_OVF_CNT_INDEX] <= egr_buf_full_drop_cnts[egr_port];
                    egr_buf_full_drop_cnts[egr_port] <= '0;
                end
            end

            if (dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][15:8] < NUM_EGR_PHYS_PORTS &&
                dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][7:0] < NUM_CNTRS_PER_EGR_PHYS_PORT) begin
                dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_DATA0] <= egr_cnts_sampled[dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][15:8]][dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][7:0]][31:0];
                dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_DATA1] <= egr_cnts_sampled[dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][15:8]][dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_SEL][7:0]][63:32];
            end else begin
                dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_DATA0] <= '0;
                dut_regs_ifc.regs[ADDR_EGR_CNTRS_READ_DATA1] <= '0;
            end

            if (avmm.write && writable_reg(tb_current_word_address)) begin
                dut_regs_ifc.regs[tb_current_word_address] <= avmm.byte_lane_mask(dut_regs_ifc.regs[tb_current_word_address]);
            end
        end
    end

    always_ff @(posedge core_clk_ifc.clk) begin
        if (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) begin
            qsys_table_config_rd_busy <= 1'b0;
            qsys_config_rdata         <= '0;
            qsys_config_rd_err        <= 1'b0;
            qsys_config_wr_err        <= 1'b0;
            qsys_cntr_op_busy         <= 1'b0;
            qsys_cntr_op_err          <= 1'b0;
            qsys_cntr_rdata           <= '0;
        end else begin
            if (ing_policer_table_config.arvalid || cong_man_table_config.arvalid) begin
                qsys_table_config_rd_busy <= 1'b1;
            end
            if (ing_policer_table_config.bvalid) begin
                qsys_config_wr_err <= ing_policer_table_config.bresp == ing_policer_table_config.OKAY ? 1'b0 : 1'b1;
            end else if (cong_man_table_config.bvalid) begin
                qsys_config_wr_err <= cong_man_table_config.bresp == cong_man_table_config.OKAY ? 1'b0 : 1'b1;
            end
            if (ing_policer_table_config.rvalid) begin
                qsys_config_rdata           <= ing_policer_table_config.rdata;
                qsys_config_rd_err          <= ing_policer_table_config.rresp == ing_policer_table_config.OKAY ? 1'b0 : 1'b1;
                qsys_table_config_rd_busy   <= 1'b0;
            end else if (cong_man_table_config.rvalid) begin
                qsys_config_rdata           <= cong_man_table_config.rdata;
                qsys_config_rd_err          <= cong_man_table_config.rresp == cong_man_table_config.OKAY ? 1'b0 : 1'b1;
                qsys_table_config_rd_busy   <= 1'b0;
            end
            if (cong_man_counter_access.arvalid && cong_man_counter_access.arready) begin
                qsys_cntr_op_busy <= 1'b1;
            end
            if (cong_man_counter_access.rvalid) begin
                qsys_cntr_op_busy <= 1'b0;
                qsys_cntr_op_err  <= cong_man_counter_access.rresp == cong_man_counter_access.OKAY ? 1'b0 : 1'b1;
                qsys_cntr_rdata   <= cong_man_counter_access.rdata;
            end
        end
    end

    p4_router_avmm_regs #(
        .MODULE_ID          ( MODULE_ID             ),
        .MTU_BYTES          ( MTU_BYTES             ),
        .VNP4_DATA_BYTES    ( VNP4_DATA_BYTES       ),
        .CLOCK_PERIOD_NS    ( CORE_CLK_PERIOD       ),
        .ING_COUNTERS_WIDTH ( ING_COUNTERS_WIDTH    ),
        .EGR_COUNTERS_WIDTH ( EGR_COUNTERS_WIDTH    ),
        .NUM_ING_PHYS_PORTS ( NUM_ING_PHYS_PORTS    ),
        .NUM_EGR_PHYS_PORTS ( NUM_EGR_PHYS_PORTS    )
    ) dut (
        .avmm_clk_ifc               ( avmm_clk_ifc              ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc   ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc     ),
        .core_clk_ifc               ( core_clk_ifc              ),
        .core_sreset_ifc            ( core_sreset_ifc           ),
        .avmm                       ( avmm                      ),
        .ing_phys_ports_enable      ( ing_phys_ports_enable     ),
        .ing_cnts_clear             ( ing_cnts_clear            ),
        .ing_cnts                   ( ing_cnts                  ),
        .ing_ports_conneted         ( ing_ports_conneted        ),
        .ing_buf_overflow           ( ing_buf_overflow          ),
        .ing_policer_enable         ( ing_policer_enable        ),
        .ing_policer_table_config   ( ing_policer_table_config  ),
        .cong_man_table_config      ( cong_man_table_config     ),
        .cong_man_counter_access    ( cong_man_counter_access   ),
        .egr_phys_ports_enable      ( egr_phys_ports_enable     ),
        .egr_cnts_clear             ( egr_cnts_clear            ),
        .egr_cnts                   ( egr_cnts                  ),
        .egr_ports_conneted         ( egr_ports_conneted        ),
        .egr_buf_full_drop          ( egr_buf_full_drop         )
    );

    assign ing_ports_conneted = ing_phys_ports_enable;
    assign egr_ports_conneted = egr_phys_ports_enable;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Policer and Congestion Manager to supply AXI4Lite end points


    assign vnp4_to_policer.tvalid = 1'b0;
    assign vnp4_to_policer.tdata  = '0;
    assign vnp4_to_policer.tuser  = '0;

    p4_router_policer #(
        .NUM_ING_PORTS  ( NUM_ING_PHYS_PORTS ),
        .MTU_BYTES      ( MTU_BYTES          )
    ) ingress_policer (
        .enable       ( ing_policer_enable          ),
        .table_config ( ing_policer_table_config    ),
        .packet_in    ( vnp4_to_policer             ),
        .packet_out   ( policer_to_cong_man         )
    );

    p4_router_congestion_manager #(
        .NUM_PAGES                  ( 512                ),
        .BYTES_PER_PAGE             ( 4096               ),
        .MAX_BYTES_PER_QUEUE        ( 512*4096           ),
        .NUM_EGR_PORTS              ( NUM_EGR_PHYS_PORTS ),
        .MTU_BYTES                  ( MTU_BYTES          )
    ) congestion_manager (
        .packet_in                  ( policer_to_cong_man      ),
        .table_config               ( cong_man_table_config    ),
        .counter_access             ( cong_man_counter_access  ),
        .packet_out                 ( cong_man_to_enqueue      ),
        .queue_occupancy_a4l        ( cong_man_queue_occupancy ),
        .queue_tail_pointer_a4l     ( queue_tail_pointer       ),
        .queue_malloc_axis          ( queue_mem_alloc          ),
        .num_free_pages             ( '1                       )
    );

    assign cong_man_to_enqueue.tready = 1'b1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Tasks


    task automatic avmm_read_and_check;
        input int word_address;
    begin
        avmm_address    = word_address << 2;
        avmm_byteenable = '1;
        avmm_burstcount = 1;
        avmm_driver.read_data(avmm_address, avmm_readdata_queue, avmm_byteenable, avmm_burstcount, avmm_response_queue);
        if (word_address < TOTAL_REGS) begin
            `CHECK_EQUAL(avmm_response_queue[0], avmm.RESPONSE_OKAY, "Incorrect read response received.");
        end else begin
            `CHECK_EQUAL(avmm_response_queue[0], avmm.RESPONSE_SLAVE_ERROR, "Incorrect read response received.");
        end
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

    task automatic rand_avmm_read;
    begin
        avmm_read_and_check($urandom_range(0, TOTAL_REGS));
    end
    endtask

    task automatic read_and_check_ing_counters;
    begin
        automatic logic [7:0]  ing_port_vec;
        automatic logic [7:0]  ing_cntr_vec;

        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            for(int cntr=0; cntr<NUM_CNTRS_PER_ING_PHYS_PORT; cntr++) begin
                ing_port_vec = ing_port;
                ing_cntr_vec= cntr;
                avmm_write(ADDR_ING_CNTRS_READ_SEL, {16'b0, ing_port_vec, ing_cntr_vec});
                avmm_read_and_check(ADDR_ING_CNTRS_READ_DATA0);
                avmm_read_and_check(ADDR_ING_CNTRS_READ_DATA1);
            end
        end
    end
    endtask

    task automatic test_ingress_axis_profile_counters;
    begin
        automatic logic [31:0] cnts_to_sample = $urandom();

        // Latch all zeros for all counters
        ing_cnts = '{default: '{default: '0}};

        avmm_write(ADDR_ING_CNTRS_SAMPLE_CON, '1);

        // verify that we read all zeros
        read_and_check_ing_counters;

        // Set counter value
        ing_cnts = '{default: '{default: 32'hAAAAAAAA}};

        // only sample some counters
        avmm_write(ADDR_ING_CNTRS_SAMPLE_CON, cnts_to_sample);

        // verify that only the sampled counters changed
        read_and_check_ing_counters;
    end
    endtask

    task automatic read_and_check_egr_counters;
    begin
        automatic logic [7:0]  egr_port_vec;
        automatic logic [7:0]  egr_cntr_vec;

        for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
            for(int cntr=0; cntr<NUM_CNTRS_PER_EGR_PHYS_PORT; cntr++) begin
                egr_port_vec = egr_port;
                egr_cntr_vec= cntr;
                avmm_write(ADDR_EGR_CNTRS_READ_SEL, {16'b0, egr_port_vec, egr_cntr_vec});
                avmm_read_and_check(ADDR_EGR_CNTRS_READ_DATA0);
                avmm_read_and_check(ADDR_EGR_CNTRS_READ_DATA1);
            end
        end
    end
    endtask

    task automatic test_egress_axis_profile_counters;
    begin
        automatic logic [31:0] cnts_to_sample = $urandom();

        // Latch all zeros for all counters
        egr_cnts = '{default: '{default: '0}};

        avmm_write(ADDR_EGR_CNTRS_SAMPLE_CON, '1);

        // verify that we read all zeros
        read_and_check_egr_counters;

        // Set counter value
        egr_cnts = '{default: '{default: 32'hAAAAAAAA}};

        // only sample some counters
        avmm_write(ADDR_EGR_CNTRS_SAMPLE_CON, cnts_to_sample);

        // verify that only the sampled counters changed
        read_and_check_egr_counters;
    end
    endtask

    task automatic test_ingress_buf_drop_counters;
    begin
        // verify that we read all zeros
        read_and_check_ing_counters;

        // Increment each counter by a different number
        for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
            repeat (3) @(posedge core_clk_ifc.clk);
            #0;
            for (int b=0; b<NUM_ING_PHYS_PORTS; b++)begin
                if (b > ing_port) begin
                    ing_buf_overflow[b] <= 1'b1;
                end
            end
            repeat (3) @(posedge core_clk_ifc.clk);
            #0;
            ing_buf_overflow <= '0;
        end

        // sample counters
        avmm_write(ADDR_ING_CNTRS_SAMPLE_CON, '1);

        // verify that counters match expectation
        read_and_check_ing_counters;
    end
    endtask

    task automatic test_egress_buf_drop_counters;
    begin
        // verify that we read all zeros
        read_and_check_egr_counters;

        // Increment each counter by a different number
        for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
            repeat (3) @(posedge core_clk_ifc.clk);
            #0;
            for (int b=0; b<NUM_EGR_PHYS_PORTS; b++)begin
                if (b > egr_port) begin
                    egr_buf_full_drop[b] <= 1'b1;
                end
            end
            repeat (3) @(posedge core_clk_ifc.clk);
            #0;
            egr_buf_full_drop <= '0;
        end

        // sample counters
        avmm_write(ADDR_EGR_CNTRS_SAMPLE_CON, '1);

        // verify that the sampled counters match expectation
        read_and_check_egr_counters;
    end
    endtask

    task automatic test_table_config;
    begin
        automatic qsys_table_id_t table_id;
        table_id.select = $urandom();
        if ($urandom() % 2) begin // Half of the time pick a random address in a valid range
            case(table_id.select)
                ING_POLICER_CIR_TABLE       : table_id.address = $urandom() % NUM_ING_PHYS_PORTS;
                ING_POLICER_CBS_TABLE       : table_id.address = $urandom() % NUM_ING_PHYS_PORTS;
                CONG_MAN_DROP_THRESH_TABLE  : table_id.address = $urandom() % NUM_QUEUES;
                default                     : table_id.address = $urandom();
            endcase
        end else begin // The other half of the time pick a random address for the full range
            table_id.address = $urandom();
        end
        avmm_write(ADDR_QSYS_TABLE_CONFIG, {8'b0, 1'b0, 1'b0, 6'b0, table_id});
        avmm_write(ADDR_QSYS_TABLE_CONFIG, {8'b0, 1'b1, 1'b0, 6'b0, table_id});
        repeat (4) @(posedge core_clk_ifc.clk);
        avmm_write(ADDR_QSYS_TABLE_CONFIG, {8'b0, 1'b0, 1'b1, 6'b0, table_id});
        avmm_write(ADDR_QSYS_TABLE_CONFIG, {8'b0, 1'b0, 1'b0, 6'b0, table_id});
        avmm_read_and_check(ADDR_QSYS_TABLE_CONFIG);
        avmm_read_and_check(ADDR_QSYS_CONFIG_WDATA);
        avmm_read_and_check(ADDR_QSYS_CONFIG_RDATA);
    end
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Tests


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk = 1'b0;
            core_clk_ifc.clk = 1'b0;

            avmm_driver = new (
                .clk_ifc                 ( avmm_clk_ifc             ),
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

            ing_buf_overflow  = 0;
            egr_buf_full_drop = 0;
            ing_cnts          = '{default: '{default: '0}};
            egr_cnts          = '{default: '{default: '0}};

            avmm_driver.init();

            @(posedge avmm_clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = 1'b0;
            core_sreset_ifc.reset         = 1'b0;

            @(posedge avmm_clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = 1'b0;

            avmm.byteenable = '1;
            @(posedge avmm_clk_ifc.clk);

        end

        `TEST_CASE("avmm_interface") begin
            avmm_driver.check_avmm_transfers(RAND_RUNS, invalid_access_returns_error);
        end

        // Had issues with this failing because dut regs are on the other side of an xclock avmm but
        // test bench expected regs are instant access
        //
        // `TEST_CASE("peripheral_reset") begin
        //     avmm_driver.check_peripheral_reset(RAND_RUNS, invalid_access_returns_error);
        // end

        // a random series of avmm reads
        `TEST_CASE("rand_avmm_read") begin
            repeat(RAND_RUNS) begin
                rand_avmm_read();
            end
        end

        // Set, and sample ingress counters that are managed by axis profile
        `TEST_CASE("ingress_axis_profile_counters") begin
            repeat(RAND_RUNS/50) begin
                test_ingress_axis_profile_counters();
            end
        end

        // Set, and sample egresscounters that are managed by axis profile
        `TEST_CASE("egress_axis_profile_counters") begin
            repeat(RAND_RUNS/50) begin
                test_egress_axis_profile_counters();
            end
        end

        // Set and sample ingress buffer full drop counters
        `TEST_CASE("ingress_buf_drop_counters") begin
            repeat(RAND_RUNS/50) begin
                $display("Run: %d", 1);
                test_ingress_buf_drop_counters();
            end
        end

        // Set and sample egress buffer full drop counters
        `TEST_CASE("egress_buf_drop_counters") begin
            repeat(RAND_RUNS/50) begin
                test_egress_buf_drop_counters();
            end
        end

        `TEST_CASE("table_config") begin
            repeat(RAND_RUNS) begin
                test_table_config();
            end
        end

        `TEST_CASE("cong_man_counter_access") begin
            automatic logic [31:0] wdata = '0;
            wdata[21:20] = READ;            // op_code
            wdata[11:0]  = 1;               // queue
            wdata[19:12] = QUEUE_FULL_DROP; // counter_type
            wdata[24]    = 0;               // qsys_cntr_op_req
            avmm_write(ADDR_QSYS_CNTR_CON, wdata);
            wdata[24]    = 1;               // qsys_cntr_op_req
            avmm_write(ADDR_QSYS_CNTR_CON, wdata);
            avmm_read_and_check(ADDR_QSYS_CNTR_RDATA);
        end
    end

    `WATCHDOG(200ns + (RAND_RUNS * 2us));

endmodule
