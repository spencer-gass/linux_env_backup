// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 *
 * P4 Router AVMM Registers
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_avmm_regs
    import AVMM_COMMON_REGS_PKG::*;
#(
    parameter bit [15:0]  MODULE_ID = 0,
    parameter int         MTU_BYTES = 1500,

    parameter int         NUM_8B_ING_PHYS_PORTS  = 0,
    parameter int         NUM_16B_ING_PHYS_PORTS = 0,
    parameter int         NUM_32B_ING_PHYS_PORTS = 0,
    parameter int         NUM_64B_ING_PHYS_PORTS = 0,
    parameter int         NUM_ING_PHYS_PORTS = NUM_8B_ING_PHYS_PORTS + NUM_16B_ING_PHYS_PORTS + NUM_32B_ING_PHYS_PORTS + NUM_64B_ING_PHYS_PORTS,

    parameter int         NUM_8B_EGR_PHYS_PORTS  = 0,
    parameter int         NUM_16B_EGR_PHYS_PORTS = 0,
    parameter int         NUM_32B_EGR_PHYS_PORTS = 0,
    parameter int         NUM_64B_EGR_PHYS_PORTS = 0,
    parameter int         NUM_EGR_PHYS_PORTS = NUM_8B_EGR_PHYS_PORTS + NUM_16B_EGR_PHYS_PORTS + NUM_32B_EGR_PHYS_PORTS + NUM_64B_EGR_PHYS_PORTS,

    parameter int         ING_COUNTERS_WIDTH = 32,
    parameter int         EGR_COUNTERS_WIDTH = 32
) (
    Clock_int           avmm_clk_ifc,
    Reset_int           interconnect_sreset_ifc,
    Reset_int           peripheral_sreset_ifc,

    Clock_int           core_clk_ifc,
    Reset_int           core_sreset_ifc,

    AvalonMM_int.Slave  avmm,

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    input  var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_full_drop,

    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_phys_ports_enable,
    output var logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_clear,
    input  var logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts [NUM_EGR_PHYS_PORTS-1:0] [6:0],
    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_ports_conneted,
    input  var logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations

    localparam bit [7:0] MODULE_MAJOR_VERSION = 1;
    localparam bit [7:0] MODULE_MINOR_VERSION = 0;
    localparam bit [avmm.DATALEN-1:0] MODULE_VERSION_ID = {MODULE_MAJOR_VERSION,
                                                           MODULE_MINOR_VERSION,
                                                           MODULE_ID};

    localparam int NUM_CNTRS_PER_PHYS_PORT = 4;
    localparam int BYTE_CNT_INDEX = 0;
    localparam int PKT_CNT_INDEX = 5;
    localparam int ERR_CNT_INDEX = 6;

    enum {
        ADDR_ING_PORT_ENABLE_CON = AVMM_COMMON_NUM_REGS,
        ADDR_ING_PHYS_PORTS_PARAM,
        ADDR_EGR_PHYS_PORTS_PARAM,
        ADDR_MTU_PARAM,
        ADDR_EGR_PORT_ENABLE_CON,
        ADDR_ING_PORT_ENABLE_STAT,
        ADDR_EGR_PORT_ENABLE_STAT,
        ADDR_ING_COUNTER_CON,
        ADDR_EGR_COUNTER_CON,
        ADDR_ING_COUNTERS_START,
        ADDR_EGR_COUNTERS_START = ADDR_ING_COUNTERS_START + NUM_ING_PHYS_PORTS*NUM_CNTRS_PER_PHYS_PORT,
        TOTAL_REGS = ADDR_EGR_COUNTERS_START + NUM_EGR_PHYS_PORTS*NUM_CNTRS_PER_PHYS_PORT
    } reg_addrs;

    /* svlint off localparam_type_twostate */
    localparam logic [TOTAL_REGS-1:0] [avmm.DATALEN-1:0] COMMON_REGS_INITVALS = '{
        AVMM_COMMON_VERSION_ID:             MODULE_VERSION_ID,
        AVMM_COMMON_STATUS_NUM_DEVICE_REGS: TOTAL_REGS,
        AVMM_COMMON_STATUS_PREREQ_MET:      '1,
        AVMM_COMMON_STATUS_COREQ_MET:       '1,
        default:                            '0
    };
    /* svlint on localparam_type_twostate */

    localparam bit [7:0] NUM_8B_ING_PHYS_PORTS_VEC  = NUM_8B_ING_PHYS_PORTS;
    localparam bit [7:0] NUM_16B_ING_PHYS_PORTS_VEC = NUM_16B_ING_PHYS_PORTS;
    localparam bit [7:0] NUM_32B_ING_PHYS_PORTS_VEC = NUM_32B_ING_PHYS_PORTS;
    localparam bit [7:0] NUM_64B_ING_PHYS_PORTS_VEC = NUM_64B_ING_PHYS_PORTS;
    localparam bit [7:0] NUM_8B_EGR_PHYS_PORTS_VEC  = NUM_8B_EGR_PHYS_PORTS;
    localparam bit [7:0] NUM_16B_EGR_PHYS_PORTS_VEC = NUM_16B_EGR_PHYS_PORTS;
    localparam bit [7:0] NUM_32B_EGR_PHYS_PORTS_VEC = NUM_32B_EGR_PHYS_PORTS;
    localparam bit [7:0] NUM_64B_EGR_PHYS_PORTS_VEC = NUM_64B_EGR_PHYS_PORTS;
    localparam bit [15:0] MTU_BYTES_VEC = MTU_BYTES;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT    ( NUM_ING_PHYS_PORTS, 0               );
    `ELAB_CHECK_GT    ( NUM_EGR_PHYS_PORTS, 0               );
    `ELAB_CHECK_LE    ( NUM_ING_PHYS_PORTS, 32              ); // Some 32-bit register have a bit per ingress physical port. This register file would need a refactor to support > 32 ingress ports
    `ELAB_CHECK_LE    ( NUM_EGR_PHYS_PORTS, 32              ); // Same for egress physical ports.
    `ELAB_CHECK_GE    ( avmm.ADDRLEN, $clog2(TOTAL_REGS)    );
    `ELAB_CHECK_EQUAL ( avmm.DATALEN, 32                    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations

    logic peripheral_sreset_core;
    logic interconnect_sreset_core;
    logic peripheral_or_core_sreset;

    logic [TOTAL_REGS-1:0] [avmm.DATALEN-1:0] regs;

    logic [avmm.ADDRLEN-1:0]   word_address;
    logic [avmm.ADDRLEN-1:0]   current_word_address;    // incrementing address for burst transfers
    logic [avmm.BURSTLEN-1:0]  transfers_remaining;     // transfers remaining in a burst
    logic                      burst_write_in_progress;
    logic                      burst_read_in_progress;

    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req_d;
    logic [ING_COUNTERS_WIDTH-1:0] ing_buf_full_drop_cnts [NUM_ING_PHYS_PORTS-1:0];

    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req_d;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_buf_full_drop_cnts [NUM_EGR_PHYS_PORTS-1:0];


    AvalonMM_int #(
        .DATALEN       ( avmm.DATALEN ),
        .ADDRLEN       ( avmm.ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) avmm_core();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations

    function automatic logic writable_reg(input logic [avmm.ADDRLEN-1:0] word_address);
        writable_reg = avmm_core.is_writable_common_reg(word_address) |
                       word_address == ADDR_ING_PORT_ENABLE_CON |
                       word_address == ADDR_EGR_PORT_ENABLE_CON |
                       word_address == ADDR_ING_COUNTER_CON |
                       word_address == ADDR_EGR_COUNTER_CON;
    endfunction

    function automatic logic undefined_addr(input logic [avmm.ADDRLEN-1:0] word_address);
        undefined_addr = word_address >= TOTAL_REGS;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clock Domain Crossing


    xclock_avmm avmm_to_core_clk(
        .clk_in_ifc                  ( avmm_clk_ifc             ),
        .interconnect_sreset_in_ifc  ( interconnect_sreset_ifc  ),
        .avmm_in                     ( avmm                     ),

        .clk_out_ifc                 ( core_clk_ifc             ),
        .interconnect_sreset_out_ifc ( core_sreset_ifc          ),
        .avmm_out                    ( avmm_core                )
    );

    xclock_resetn xclock_peripheral_sreset (
        .tx_clk     ( 1'b0                                                              ), // Only used if INPUT_REG = 1.
        .resetn_in  ( peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH  ),
        .rx_clk     ( core_clk_ifc.clk                                                  ),
        .resetn_out ( peripheral_sreset_core                                            )
    );

        xclock_resetn xclock_interconnect_sreset (
        .tx_clk     ( 1'b0                                                                 ), // Only used if INPUT_REG = 1.
        .resetn_in  ( interconnect_sreset_ifc.reset == interconnect_sreset_ifc.ACTIVE_HIGH ),
        .rx_clk     ( core_clk_ifc.clk                                                     ),
        .resetn_out ( interconnect_sreset_core                                             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Transaction

    assign word_address = avmm_core.address >> 2;
    assign peripheral_or_core_sreset = (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) | peripheral_sreset_core;

    always_ff @(posedge core_clk_ifc.clk) begin
        if (interconnect_sreset_core) begin // AVMM bus reset
            avmm_core.waitrequest        <= 1'b1;
            avmm_core.response           <= 'X;
            avmm_core.writeresponsevalid <= 1'b0;
            avmm_core.readdata           <= 'X;
            avmm_core.readdatavalid      <= 1'b0;

            burst_write_in_progress <= 2'b0;
            burst_read_in_progress  <= 1'b0;
            current_word_address    <= 'X;
            transfers_remaining     <= 'X;

        end else begin

            avmm_core.writeresponsevalid <= 1'b0;
            avmm_core.readdatavalid      <= 1'b0;
            avmm_core.waitrequest        <= 1'b0;

            regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};
            regs[ADDR_ING_PHYS_PORTS_PARAM] <= {NUM_64B_ING_PHYS_PORTS_VEC, NUM_32B_ING_PHYS_PORTS_VEC, NUM_16B_ING_PHYS_PORTS_VEC, NUM_8B_ING_PHYS_PORTS_VEC};
            regs[ADDR_EGR_PHYS_PORTS_PARAM] <= {NUM_64B_EGR_PHYS_PORTS_VEC, NUM_32B_EGR_PHYS_PORTS_VEC, NUM_16B_EGR_PHYS_PORTS_VEC, NUM_8B_EGR_PHYS_PORTS_VEC};
            regs[ADDR_MTU_PARAM] <= MTU_BYTES_VEC;

            ing_phys_ports_enable           <= regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0];
            egr_phys_ports_enable           <= regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0];
            regs[ADDR_ING_PORT_ENABLE_STAT] <= ing_ports_conneted;
            regs[ADDR_EGR_PORT_ENABLE_STAT] <= egr_ports_conneted;

            ing_cnts_sample_req     <= regs[ADDR_ING_COUNTER_CON];
            ing_cnts_sample_req_d   <= ing_cnts_sample_req;
            egr_cnts_sample_req     <= regs[ADDR_EGR_COUNTER_CON];
            egr_cnts_sample_req_d   <= egr_cnts_sample_req;

            // On rising edge of cnts_sample, read and clear counts
            for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
                if (ing_buf_full_drop[ing_port]) begin
                    ing_buf_full_drop_cnts[ing_port]++;
                end
                if (ing_cnts_sample_req[ing_port] & !ing_cnts_sample_req_d[ing_port]) begin
                    regs[ADDR_ING_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*ing_port+0] <= ing_cnts[ing_port][PKT_CNT_INDEX];
                    regs[ADDR_ING_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*ing_port+1] <= ing_cnts[ing_port][BYTE_CNT_INDEX];
                    regs[ADDR_ING_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*ing_port+2] <= ing_cnts[ing_port][ERR_CNT_INDEX];
                    regs[ADDR_ING_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*ing_port+3] <= ing_buf_full_drop_cnts[ing_port];
                    ing_buf_full_drop_cnts[ing_port] <= '0;
                    ing_cnts_clear[ing_port] <= 1'b1;
                end else begin
                    ing_cnts_clear[ing_port] <= 1'b0;
                end
            end

            for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
                if (egr_buf_full_drop[egr_port]) begin
                    egr_buf_full_drop_cnts[egr_port]++;
                end
                if (egr_cnts_sample_req[egr_port] & !egr_cnts_sample_req_d[egr_port]) begin
                    regs[ADDR_EGR_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*egr_port+0] <= egr_cnts[egr_port][PKT_CNT_INDEX];
                    regs[ADDR_EGR_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*egr_port+1] <= egr_cnts[egr_port][BYTE_CNT_INDEX];
                    regs[ADDR_EGR_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*egr_port+2] <= egr_cnts[egr_port][ERR_CNT_INDEX];
                    regs[ADDR_EGR_COUNTERS_START+NUM_CNTRS_PER_PHYS_PORT*egr_port+3] <= egr_buf_full_drop_cnts[egr_port];
                    egr_buf_full_drop_cnts[egr_port] <= '0;
                egr_cnts_clear[egr_port] <= 1'b1;
                end else begin
                    egr_cnts_clear[egr_port] <= 1'b0;
                end
            end

            if (avmm_core.write) begin
                if (burst_write_in_progress) begin
                    current_word_address <= current_word_address+1;
                    if (writable_reg(current_word_address)) begin
                        regs[current_word_address] <= avmm_core.byte_lane_mask(regs[current_word_address]);
                    end else if (undefined_addr(current_word_address)) begin
                        avmm_core.response              <= avmm_core.RESPONSE_SLAVE_ERROR;
                    end

                    // final transfer of burst
                    if (transfers_remaining == 1) begin
                        avmm_core.writeresponsevalid <= 1'b1;
                        burst_write_in_progress <= 1'b0;
                    end else begin
                        transfers_remaining     <= transfers_remaining - 1'b1;
                    end
                end else begin
                    avmm_core.response <= avmm_core.RESPONSE_OKAY;

                    // write first word for burst or single transfer
                    if (writable_reg(word_address)) begin
                        regs[word_address] <= avmm_core.byte_lane_mask(regs[word_address]);
                    end else if (undefined_addr(word_address)) begin
                        avmm_core.response           <= avmm_core.RESPONSE_SLAVE_ERROR;
                    end

                    // begin burst transfer
                    if (avmm_core.burstcount > 1) begin
                        burst_write_in_progress <= 1'b1;
                        transfers_remaining     <= avmm_core.burstcount - 1'b1;
                        current_word_address    <= word_address + 1'b1;

                    // single transfer
                    end else begin
                        avmm_core.writeresponsevalid <= 1'b1;
                    end
                end
            end // end avmm_core write

            if (avmm_core.read | burst_read_in_progress) begin
                avmm_core.readdatavalid <= 1'b1;

                if (burst_read_in_progress) begin
                    current_word_address <= current_word_address+1;
                    if (undefined_addr(current_word_address)) begin
                        avmm_core.readdata <= 'X;
                        avmm_core.response <= avmm_core.RESPONSE_SLAVE_ERROR;
                    end else begin
                        avmm_core.readdata <= regs[current_word_address];
                        avmm_core.response <= avmm_core.RESPONSE_OKAY;
                    end

                    // final transfer of burst
                    if (transfers_remaining == 1) begin
                        burst_read_in_progress <= 1'b0;
                    end else begin
                        transfers_remaining    <= transfers_remaining - 1'b1;
                    end
                end else begin
                    // read first word for burst or single transfer
                    if (undefined_addr(word_address)) begin
                        avmm_core.readdata <= 'X;
                        avmm_core.response <= avmm_core.RESPONSE_SLAVE_ERROR;
                    end else begin
                        avmm_core.readdata <= regs[word_address];
                        avmm_core.response <= avmm_core.RESPONSE_OKAY;
                    end

                    // begin burst transfer
                    if (avmm_core.burstcount > 1) begin
                        burst_read_in_progress <= 1'b1;
                        transfers_remaining    <= avmm_core.burstcount - 1'b1;
                        current_word_address   <= word_address + 1'b1;
                    end
                end
            end // end avmm_core read

            if (peripheral_or_core_sreset) begin
                regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
                regs[ADDR_ING_PORT_ENABLE_CON]                         <= '0;
                regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0] <= '1;
                regs[ADDR_EGR_PORT_ENABLE_CON]                         <= '0;
                regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0] <= '1;
                regs[ADDR_ING_COUNTER_CON] <= '0;
                regs[ADDR_EGR_COUNTER_CON] <= '0;
                for (int i=ADDR_ING_COUNTERS_START; i<TOTAL_REGS; i++) begin
                    regs[i] <= '0;
                end
                for (int i=0; i<NUM_ING_PHYS_PORTS; i++) begin
                    ing_buf_full_drop_cnts[i] <= '0;
                end
                for (int i=0; i<NUM_EGR_PHYS_PORTS; i++) begin
                    egr_buf_full_drop_cnts[i] <= '0;
                end
            end

        end
    end // end always block

endmodule

`default_nettype wire
