// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * P4 Router AVMM Registers
 * This module implements the AVMM registers for p4_router excluding the VNP4 instance which
 * has it's own table config, and stats registers accessible via an AXI4lite interface.
 *
 * Register Map:
 * <table>
 *   <tr><th>Offset     </th><th>Register                   </th><th>Description                                                                                    </th></tr>
 *   <tr><td>0-15       </td><td>AVMM_COMMON_REGS           </td><td>Ref: avmm_kepler_pkg.sv </td></tr>
 *   <tr><td>16         </td><td>PARAMS0                    </td><td>(r)
 *                                                                     - [31:24] reserved
 *                                                                     - [23:16] VNP4_DATA_BYTES: VNP4 AXIS bus width in bytes
 *                                                                     - [15:8]  NUM_EGR_PORTS: Number of egress interfaces
 *                                                                     - [7:0]   NUM_ING_PORTS: Number of ingress interfaces </td></tr>
 *   <tr><td>17         </td><td>PARAMS1                    </td><td>(r)
 *                                                                    - [31:16] CORE_CLOCK_PERIOD_PS: Core clock period in picoseconds. Used to calculate shaper decrement.
 *                                                                    - [15:0]  MTU_BYTES: Supported MTU in bytes </td></tr>
 *   <tr><td>18         </td><td>ING_PORT_ENABLE_CON        </td><td> (r/w)
 *                                                                    - [31:NUM_ING_PORTS] reserved
 *                                                                    - [NUM_ING_PORTS-1:0] ING_PORT_ENABLE_CON: Enable bit per ingress port. default=1s. </td></tr>
 *   <tr><td>19         </td><td>EGR_PORT_ENABLE_CON        </td><td> (r/w)
 *                                                                    - [31:NUM_EGR_PORTS] reserved
 *                                                                    - [NUM_EGR_PORTS-1:0] EGR_PORT_ENABLE_CON: Enable bit per egress port. default=1s.</td></tr>
 *   <tr><td>20         </td><td>ING_PORT_ENABLE_STAT       </td><td>(r)
 *                                                                    - [31:NUM_ING_PORTS] reserved
 *                                                                    - [NUM_ING_PORTS-1:0] ING_PORT_ENABLE_STAT: Changes to ING_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here </td></tr>
 *   <tr><td>21         </td><td>EGR_PORT_ENABLE_STAT       </td><td>(r)
 *                                                                    - [31:NUM_EGR_PORTS] reserved
 *                                                                    - [NUM_EGR_PORTS-1:0] EGR_PORT_ENABLE_STAT: Changes to EGR_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here </td></tr>
 *   <tr><td>22         </td><td>ING_COUNTER_SAMPLE_CON     </td><td>(r/w)
 *                                                                    - [31:NUM_ING_PORTS] reserved
 *                                                                    - [NUM_ING_PORTS-1:0] SAMPLE_ING_COUNTER: Each bit in this register is associated with an ingress port of the same index.
 *                                                                    -     0 to 1 transition of a bit in this register saves samples of all counters from the respective ingress ports then resets the counters.
 *                                                                    -     Counter samples can be read by selecting the desired counter via ING_COUNTER_READ_SEL, then reading the data from ING_COUNTER_READ_DATA. </td></tr>
 *   <tr><td>23         </td><td>ING_COUNTER_READ_SEL       </td><td>(r/w)
 *                                                                    - [31:16] reserved
 *                                                                    - [15:8]  ING_PORT_SEL: Selects the ingress port of the counter to be populated in ING_COUNTER_READ_DATA.
 *                                                                    - [7:0]   COUNTER_SEL: Selects the counter to be populated in ING_COUNTER_READ_DATA.
 *                                                                    -     0: Packet count: Number of packets that have ingressed p4_router on the associated port. Includes errored packets.
 *                                                                    -     1: Byte count: Sum of the byte lengths of the packets that have ingressed p4_router on the associated port. Includes bytes from errored packets.
 *                                                                    -     2: Error count: Number of packets that have ingressed p4_router on the associated port that were marked as errored by the respective MAC
 *                                                                    -     3: Ingress buffer overflow count: Number of packets that were dropped at the ingress buffer because the buffer was full. The system is designed in such a way that this shouldn't happen. </td></tr>
 *   <tr><td>24         </td><td>ING_COUNTER_READ_DATA      </td><td>(r/w)
 *                                                                    - [31:0] ING_COUNTER_READ_DATA: Sampled count of the counter selected by ING_COUNTER_RD_SEL. </td></tr>
 *   <tr><td>25         </td><td>EGR_COUNTER_SAMPLE_CON     </td><td>(r/w)
 *                                                                    - [31:NUM_EGR_PORTS] reserved
 *                                                                    - [NUM_EGR_PORTS-1:0] SAMPLE_EGR_COUNTER: Each bit in this register is associated with an egress port of the same index.
 *                                                                      0 to 1 transition of a bit in this register saves samples of all counters from the respective egress ports then resets the counters.
 *                                                                      Counter samples can be read by selecting the desired counter via EGR_COUNTER_READ_SEL, then reading the data from EGR_COUNTER_READ_DATA. </td></tr>
 *   <tr><td>26         </td><td>EGR_COUNTER_READ_SEL       </td><td>(r/w)
 *                                                                    - [31:16] reserved
 *                                                                    - [15:8]  EGR_PORT_SEL: Selects the egress port of the counter to be populated in EGR_COUNTER_READ_DATA.
 *                                                                    - [7:0]   COUNTER_SEL: Selects the counter to be populated in EGR_COUNTER_READ_DATA.
 *                                                                    -     0: Packet count: Number of packets that have ingressed p4_router on the associated port. Includes errored packets.
 *                                                                    -     1: Byte count: Sum of the byte lengths of the packets that have ingressed p4_router on the associated port. Includes bytes from errored packets.
 *                                                                    -     2: Error count: Number of packets that have ingressed p4_router on the associated port that were marked as errored by the respective MAC
 *                                                                    -     3: Egress buffer overflow count: Number of packets that were dropped at the egress buffer because the buffer was full. </td></tr>
 *   <tr><td>27         </td><td>EGR_COUNTER_READ_DATA      </td><td>(r/w)
 *                                                                    - [31:0] EGR_COUNTER_READ_DATA: Sampled count of the counter selected by EGR_COUNTER_RD_SEL. </td></tr>
 *   <tr><td>28         </td><td>ING_POLICER_ENABLE         </td><td>(r/w)
 *                                                                    - [31:NUM_ING_PORTS]  reserved
 *                                                                    - [NUM_ING_PORTS-1:0] ING_POLICER_ENABLE: Enables/disable ingress port shaper. One bit per ingress port.</td></tr>
 *   <tr><td>29         </td><td>QSYS_TABLE_CONFIG          </td><td>(r/w)
 *                                                                    - [31:30] reserved
 *                                                                    - [29]    WRITE_ERR: Indicates that the most recent write request failed due to invalid table select or address.
 *                                                                    - [28]    READ_ERR:  Indicates that the most recent read request failed due to invalid table select or address.
 *                                                                    - [27]    WRITE_BUSY: 0: The most recently requested write has completed and another write can be issued,
 *                                                                                          1: Write request in progress, new write requests are ignored until busy clears.
 *                                                                    - [26]    READ_BUSY:  0: The most recently requested read has completed and QSYS_CONFIG_READ_DATA has been polulated,
 *                                                                                          1: Read request in progress, new read requests are ignored until busy clears.
 *                                                                    - [25]    WRITE_REQUEST: 0 to 1 transition captures TABLE_SELECT, TABLE_ADDR and QSYS_CONFIG_WRITE_DATA and
 *                                                                                             initates a write to the selected entry of the selected table.
 *                                                                    - [24]    READ_REQUEST: 0 to 1 transition captures TABLE_SELECT, and TABLE_ADDR and initates a read of
 *                                                                                            the selected entry of the selected table and load it in QSYS_CONFIG_READ_DATA
 *                                                                    - [23:18]  reserved
 *                                                                    - [17:16]  TABLE_SELECT: See table descriptions below
 *                                                                                  0: Ingress Policer CIR Table
 *                                                                                  1: Ingress Policer CBS Table
 *                                                                                  2: Queue Occupancy Threshold Table
 *                                                                                  3: Malloc Threshold Table
 *                                                                    - [15:0] TABLE_ADDR: Selects which queue is addressed for read/write. </td></tr>
 *   <tr><td>30         </td><td>QSYS_CONFIG_WRITE_DATA     </td><td>(r/w)
 *                                                                    - [31:0] Write data for congestion manager config table. See table entry formats below. </td></tr>
 *   <tr><td>31         </td><td>QSYS_CONFIG_READ_DATA      </td><td>(r)
 *                                                                    - [31:0] Read data for congestion manager config table. See table entry formats below. </td></tr>
 *   <tr><td>32         </td><td>QSYS_COUNTER_CON           </td><td>(r/w)
 *                                                                    - [31:27] reserved
 *                                                                    - [26]    ERR: Indicates that the most recent write request failed due to invalid table select or address.
 *                                                                    - [25]    BUSY:  0: The most recently requested read has completed and QSYS_CONFIG_READ_DATA has been polulated,
 *                                                                                          1: Read request in progress, new read requests are ignored until busy clears.
 *                                                                    - [24]    OP_REQUEST: 0 to 1 transition captures QUEUE_SELECT, COUNTER_SELECT, and OP_CODE and initates an operation
 *                                                                                            on the selected counter.
 *                                                                    - [23:22] reserved
 *                                                                    - [21:20] OP_CODE: 0=read, 1=read and clear, 2=clear all
 *                                                                    - [23:22] reserved
 *                                                                    - [19:12] COUNTER_SELECT: Selects which counter type is selected for read/clear
 *                                                                                  0: INGRESS SHAPER DROP - Ingress burst exceeded shaper rate for longer than the ingress queue could absorb.
 *                                                                                  1: QUEUE FULL DROP - Egress queue filled to capacity
 *                                                                                  2: MEMORY ALLOCATION DROP - Egress queue occupied to large a proportion of avaiable queuing memory
 *                                                                                  3: MEMORY FULL DROP - No queuing memory avaiable to be allocated
 *                                                                                  4: BACK TO BACK DROP - Congestion Manager doesn't support start-of-packet in adjacent cycles
 *                                                                    - [11:6] reserved
 *                                                                    - [6:0]  QUEUE_SELECT: Selects which queue is addressed for read/clear. </td></tr>
 *   <tr><td>33         </td><td>QSYS_COUNTER_READ_DATA      </td><td>(r)
 *                                                                    - [31:0] Read data for congestion manager drop counters. </td></tr>
 * </table>
 *
 * Ingress Policer CIR Table
 *  One entry per ingress port.
 * Entry format:
 * - [31:16] reserved
 * - [15:13] ING_CIR_WHOLE: Whole part of comitted information rate (i.e. ingress shaper rate)
 * - [12:0]  ING_CIR_FRACTION: fractional part of ingress CIR.
 *   CIR is a 3w.13f fixed point number in units of Bytes per clock cycle
 * Notes:
 *   Conveting Mbps to bytes/cycle:
 *       Mbits/Sec -> bits/us * 1 bytes / 8 bits * 1 us / 1000ns * CLOCK_PERIOD ns / 1 clock = bytes/clock
 *   where CLOCK_PERIOD in ns comes from CLOCK_PERIOD_PS in PARAMS1 divided by 1000 to convert from ps to ns.
 *
 * Ingress Policer CBS Table
 *  One entry per ingress port
 * Entry format:
 * - [31:20] reserved
 * - [19:0] ING_CBS: Comitted burst size (i.e. ingress queue depth threshold) in units of bytes.
 *
 * Congestion Manager Queue Occupancy Threshold Table
 *  One entry per queue
 *  Address = {egress_port, prio}; where prio is a 3-bit field.
 * entry format:
 * - [31:MAX_BYTES_PER_QUEUE_LOG]  reserved
 * - [MAX_BYTES_PER_QUEUE_LOG-1:0] QUEUE_OCCUPANCY_THRESHOLD: Queue occupancy in bytes above which the congestion manager will drop packets to the respective queue.
 *
 * Congestion Manager Malloc Threshold table entry format:
 * - Not yet defined or implemented
 *
**/

module p4_router_avmm_regs
    import AVMM_COMMON_REGS_PKG::*;
    import p4_router_pkg::*;
#(
    parameter bit [15:0]  MODULE_ID = 0,
    parameter int         MTU_BYTES = 2000,
    parameter int         VNP4_DATA_BYTES = 0,
    parameter real        CLOCK_PERIOD_NS = 0,

    parameter int         NUM_ING_PHYS_PORTS = 0,
    parameter int         NUM_EGR_PHYS_PORTS = 0,
    parameter int         ING_COUNTERS_WIDTH = 32,
    parameter int         EGR_COUNTERS_WIDTH = 32
) (
    // Clocks and Resets
    Clock_int.Input     avmm_clk_ifc,
    Reset_int.ResetIn   interconnect_sreset_ifc,
    Reset_int.ResetIn   peripheral_sreset_ifc,

    Clock_int.Input     core_clk_ifc,
    Reset_int.ResetIn   core_sreset_ifc,

    // AVMM Slave
    AvalonMM_int.Slave  avmm,

    // Ingress
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    input  var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow,

    // Queue System

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_policer_enable,
    AXI4Lite_int.Master  ing_policer_table_config,
    AXI4Lite_int.Master  cong_man_table_config,
    AXI4Lite_int.Master  cong_man_counter_access,

    // Egress
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

    localparam int NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);

    localparam int NUM_CNTRS_PER_ING_PHYS_PORT = 5;
    localparam int NUM_CNTRS_PER_EGR_PHYS_PORT = 4;

    localparam int ING_PKT_CNT_INDEX            = 0;
    localparam int ING_BYTE_CNT_INDEX           = 1;
    localparam int ING_ERR_CNT_INDEX            = 2;
    localparam int ING_BUF_OVF_CNT_INDEX        = 3;

    localparam int EGR_PKT_CNT_INDEX            = 0;
    localparam int EGR_BYTE_CNT_INDEX           = 1;
    localparam int EGR_ERR_CNT_INDEX            = 2;
    localparam int EGR_BUF_OVF_CNT_INDEX        = 3;

    enum {
        ADDR_PARAMS0 = AVMM_COMMON_NUM_REGS,
        ADDR_PARAMS1,
        ADDR_ING_PORT_ENABLE_CON,
        ADDR_EGR_PORT_ENABLE_CON,
        ADDR_ING_PORT_ENABLE_STAT,
        ADDR_EGR_PORT_ENABLE_STAT,
        ADDR_ING_CNTRS_SAMPLE_CON,
        ADDR_ING_CNTRS_READ_SEL,
        ADDR_ING_CNTRS_READ_DATA,
        ADDR_EGR_CNTRS_SAMPLE_CON,
        ADDR_EGR_CNTRS_READ_SEL,
        ADDR_EGR_CNTRS_READ_DATA,
        ADDR_ING_POLICER_ENABLE,
        ADDR_QSYS_TABLE_CONFIG,
        ADDR_QSYS_CONFIG_WDATA,
        ADDR_QSYS_CONFIG_RDATA,
        ADDR_QSYS_CNTR_CON,
        ADDR_QSYS_CNTR_RDATA,
        TOTAL_REGS
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

    localparam bit [7:0]  NUM_ING_PHYS_PORTS_VEC  = NUM_ING_PHYS_PORTS;
    localparam bit [7:0]  NUM_EGR_PHYS_PORTS_VEC  = NUM_EGR_PHYS_PORTS;
    localparam bit [7:0]  VNP4_DATA_BYTES_VEC = VNP4_DATA_BYTES;
    localparam bit [15:0] MTU_BYTES_VEC = MTU_BYTES;
    localparam bit [15:0] CLOCK_PERIOD_PS_VEC = $rtoi(CLOCK_PERIOD_NS * 1000);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT    ( NUM_ING_PHYS_PORTS, 0               );
    `ELAB_CHECK_GT    ( NUM_EGR_PHYS_PORTS, 0               );
    `ELAB_CHECK_LE    ( NUM_ING_PHYS_PORTS, 32              ); // Some 32-bit register have a bit per ingress physical port. This register file would need a refactor to support > 32 ingress ports
    `ELAB_CHECK_LE    ( NUM_EGR_PHYS_PORTS, 32              ); // Same for egress physical ports.
    `ELAB_CHECK_GT    ( VNP4_DATA_BYTES, 0                  );
    `ELAB_CHECK_GT    ( CLOCK_PERIOD_PS_VEC, 0              );
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

    // Ingress Counters
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_sample_req_d;
    logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow_d;
    logic [ING_COUNTERS_WIDTH-1:0] ing_buf_overflow_cnts [NUM_ING_PHYS_PORTS-1:0];
    logic [7:0]                    ing_cntr_port_sel;
    logic [7:0]                    ing_cntr_sel;
    logic [ING_COUNTERS_WIDTH-1:0] ing_cnts_sampled [NUM_ING_PHYS_PORTS-1:0] [NUM_CNTRS_PER_ING_PHYS_PORT-1:0];

    // Queue System
    logic qsys_table_wr_req;
    logic qsys_table_wr_req_d;
    logic qsys_table_rd_req;
    logic qsys_table_rd_req_d;
    qsys_table_id_t qsys_table_id;
    logic [CIR_TABLE_WIDTH-1:0] cir_wr_data;
    logic [CBS_TABLE_WIDTH-1:0] cbs_wr_data;
    logic qsys_table_config_wr_busy;
    logic qsys_table_config_rd_busy;
    logic qsys_table_config_wr_err;
    logic qsys_table_config_rd_err;
    qsys_counter_id_t qsys_counter_id;
    logic qsys_cntr_op_req;
    logic qsys_cntr_op_req_d;
    logic qsys_cntr_op_busy;
    logic qsys_cntr_op_err;

    // Egress Counters
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_cnts_sample_req_d;
    logic [NUM_EGR_PHYS_PORTS-1:0] egr_buf_full_drop_d;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_buf_full_drop_cnts [NUM_EGR_PHYS_PORTS-1:0];
    logic [7:0]                    egr_cntr_port_sel;
    logic [7:0]                    egr_cntr_sel;
    logic [EGR_COUNTERS_WIDTH-1:0] egr_cnts_sampled [NUM_EGR_PHYS_PORTS-1:0] [NUM_CNTRS_PER_EGR_PHYS_PORT-1:0];

    // AVMM Interface for CDC
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
                       word_address == ADDR_ING_CNTRS_SAMPLE_CON |
                       word_address == ADDR_ING_CNTRS_READ_SEL |
                       word_address == ADDR_EGR_CNTRS_SAMPLE_CON |
                       word_address == ADDR_EGR_CNTRS_READ_SEL |
                       word_address == ADDR_ING_POLICER_ENABLE |
                       word_address == ADDR_QSYS_TABLE_CONFIG |
                       word_address == ADDR_QSYS_CONFIG_WDATA |
                       word_address == ADDR_QSYS_CNTR_CON;
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

    assign ing_cntr_port_sel = regs[ADDR_ING_CNTRS_READ_SEL][15:8];
    assign ing_cntr_sel      = regs[ADDR_ING_CNTRS_READ_SEL][7:0];
    assign egr_cntr_port_sel = regs[ADDR_EGR_CNTRS_READ_SEL][15:8];
    assign egr_cntr_sel      = regs[ADDR_EGR_CNTRS_READ_SEL][7:0];

    assign ing_cnts_sample_req = regs[ADDR_ING_CNTRS_SAMPLE_CON];
    assign egr_cnts_sample_req = regs[ADDR_EGR_CNTRS_SAMPLE_CON];

    assign ing_policer_enable = regs[ADDR_ING_POLICER_ENABLE][NUM_ING_PHYS_PORTS-1:0];

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

            // AVMM Common Regs
            regs[AVMM_COMMON_STATUS_DEVICE_STATE] <= {31'd0, 1'b1};

            // P4 Router Params
            regs[ADDR_PARAMS0] <= {VNP4_DATA_BYTES_VEC, NUM_EGR_PHYS_PORTS_VEC, NUM_ING_PHYS_PORTS_VEC};
            regs[ADDR_PARAMS1] <= {CLOCK_PERIOD_PS_VEC, MTU_BYTES_VEC};

            // Ingress Registers
            ing_phys_ports_enable           <= regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0];
            egr_phys_ports_enable           <= regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0];
            regs[ADDR_ING_PORT_ENABLE_STAT] <= ing_ports_conneted;
            regs[ADDR_EGR_PORT_ENABLE_STAT] <= egr_ports_conneted;

            ing_cnts_sample_req_d           <= ing_cnts_sample_req;
            ing_buf_overflow_d              <= ing_buf_overflow;

            for (int ing_port=0; ing_port<NUM_ING_PHYS_PORTS; ing_port++) begin
                if (ing_buf_overflow[ing_port] && !ing_buf_overflow_d[ing_port]) begin
                    ing_buf_overflow_cnts[ing_port]++;
                end
                // On rising edge of cnts_sample, read and clear counts
                if (ing_cnts_sample_req[ing_port] & !ing_cnts_sample_req_d[ing_port]) begin
                    ing_cnts_sampled[ing_port][ING_PKT_CNT_INDEX           ] <= ing_cnts[ing_port][AXIS_PROFILE_PKT_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_BYTE_CNT_INDEX          ] <= ing_cnts[ing_port][AXIS_PROFILE_BYTE_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_ERR_CNT_INDEX           ] <= ing_cnts[ing_port][AXIS_PROFILE_ERR_CNT_INDEX];
                    ing_cnts_sampled[ing_port][ING_BUF_OVF_CNT_INDEX       ] <= ing_buf_overflow_cnts[ing_port];
                    ing_buf_overflow_cnts[ing_port] <= '0;
                    ing_cnts_clear[ing_port] <= 1'b1;
                end else begin
                    ing_cnts_clear[ing_port] <= 1'b0;
                end
            end

            if (ing_cntr_port_sel < NUM_ING_PHYS_PORTS && ing_cntr_sel < NUM_CNTRS_PER_ING_PHYS_PORT) begin
                regs[ADDR_ING_CNTRS_READ_DATA] <= ing_cnts_sampled[ing_cntr_port_sel][ing_cntr_sel];
            end else begin
                regs[ADDR_ING_CNTRS_READ_DATA] <= '0;
            end


            // Queue System Registers
            regs[ADDR_QSYS_TABLE_CONFIG][29] <= qsys_table_config_wr_err;
            regs[ADDR_QSYS_TABLE_CONFIG][28] <= qsys_table_config_rd_err;
            regs[ADDR_QSYS_TABLE_CONFIG][27] <= qsys_table_config_wr_busy;
            regs[ADDR_QSYS_TABLE_CONFIG][26] <= qsys_table_config_rd_busy;

            if (ing_policer_table_config.rvalid) begin
                regs[ADDR_QSYS_CONFIG_RDATA] <= ing_policer_table_config.rdata;
                qsys_table_config_rd_err     <= ing_policer_table_config.rresp == ing_policer_table_config.OKAY ? 1'b0 : 1'b1;
            end else if (cong_man_table_config.rvalid) begin
                regs[ADDR_QSYS_CONFIG_RDATA] <= cong_man_table_config.rdata;
                qsys_table_config_rd_err     <= cong_man_table_config.rresp == cong_man_table_config.OKAY ? 1'b0 : 1'b1;
            end

            if (ing_policer_table_config.bvalid) begin
                qsys_table_config_wr_err <= ing_policer_table_config.bresp == ing_policer_table_config.OKAY ? 1'b0 : 1'b1;
            end else if (cong_man_table_config.bvalid) begin
                qsys_table_config_wr_err <= cong_man_table_config.bresp == cong_man_table_config.OKAY ? 1'b0 : 1'b1;
            end

            regs[ADDR_QSYS_CNTR_CON][26] <= qsys_cntr_op_err;
            regs[ADDR_QSYS_CNTR_CON][25] <= qsys_cntr_op_busy;
            if (cong_man_counter_access.rvalid) begin
                regs[ADDR_QSYS_CNTR_RDATA]   <= cong_man_counter_access.rdata;
                qsys_cntr_op_err             <= cong_man_counter_access.rresp == cong_man_counter_access.OKAY ? 1'b0 : 1'b1;
            end

            // Egress Registers
            egr_cnts_sample_req_d <= egr_cnts_sample_req;
            egr_buf_full_drop_d   <= egr_buf_full_drop;

            for (int egr_port=0; egr_port<NUM_EGR_PHYS_PORTS; egr_port++) begin
                if (egr_buf_full_drop[egr_port] && !egr_buf_full_drop_d[egr_port]) begin
                    egr_buf_full_drop_cnts[egr_port]++;
                end
                // On rising edge of cnts_sample, read and clear counts
                if (egr_cnts_sample_req[egr_port] & !egr_cnts_sample_req_d[egr_port]) begin
                    egr_cnts_sampled[egr_port][EGR_PKT_CNT_INDEX    ] <= egr_cnts[egr_port][AXIS_PROFILE_PKT_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_BYTE_CNT_INDEX   ] <= egr_cnts[egr_port][AXIS_PROFILE_BYTE_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_ERR_CNT_INDEX    ] <= egr_cnts[egr_port][AXIS_PROFILE_ERR_CNT_INDEX];
                    egr_cnts_sampled[egr_port][EGR_BUF_OVF_CNT_INDEX] <= egr_buf_full_drop_cnts[egr_port];
                    egr_buf_full_drop_cnts[egr_port] <= '0;
                egr_cnts_clear[egr_port] <= 1'b1;
                end else begin
                    egr_cnts_clear[egr_port] <= 1'b0;
                end
            end

            if (egr_cntr_port_sel < NUM_EGR_PHYS_PORTS && egr_cntr_sel < NUM_CNTRS_PER_EGR_PHYS_PORT) begin
                regs[ADDR_EGR_CNTRS_READ_DATA] <= egr_cnts_sampled[egr_cntr_port_sel][egr_cntr_sel];
            end else begin
                regs[ADDR_EGR_CNTRS_READ_DATA] <= '0;
            end


            // AVMM Write
            avmm_core.writeresponsevalid <= 1'b0;
            avmm_core.waitrequest        <= 1'b0;

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


            // AVMM Read
            avmm_core.readdatavalid      <= 1'b0;

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
                // AVMM Common
                regs[AVMM_COMMON_NUM_REGS-1:0] <= COMMON_REGS_INITVALS;
                // Ingress
                regs[ADDR_ING_PORT_ENABLE_CON]                         <= '0;
                regs[ADDR_ING_PORT_ENABLE_CON][NUM_ING_PHYS_PORTS-1:0] <= '1;
                regs[ADDR_ING_CNTRS_SAMPLE_CON]                        <= '0;
                regs[ADDR_ING_CNTRS_READ_SEL]                          <= '0;
                ing_cnts_sampled                                       <= '{default: '{default: '0}};
                ing_buf_overflow_cnts                                  <= '{default: '0};
                // Queue System
                regs[ADDR_ING_POLICER_ENABLE]                          <= '0;
                regs[ADDR_QSYS_TABLE_CONFIG]                           <= '0;
                regs[ADDR_QSYS_CONFIG_WDATA]                           <= '0;
                regs[ADDR_QSYS_CONFIG_RDATA]                           <= '0;
                regs[ADDR_QSYS_CNTR_CON]                               <= '0;
                regs[ADDR_QSYS_CNTR_RDATA]                             <= '0;
                qsys_table_config_wr_err                               <= 1'b0;
                qsys_table_config_rd_err                               <= 1'b0;
                qsys_cntr_op_err                                       <= 1'b0;
                // Egress
                regs[ADDR_EGR_PORT_ENABLE_CON]                         <= '0;
                regs[ADDR_EGR_PORT_ENABLE_CON][NUM_EGR_PHYS_PORTS-1:0] <= '1;
                regs[ADDR_EGR_CNTRS_SAMPLE_CON]                        <= '0;
                regs[ADDR_EGR_CNTRS_READ_SEL]                          <= '0;
                egr_cnts_sampled                                       <= '{default: '{default: '0}};
                egr_buf_full_drop_cnts                                 <= '{default: '0};
            end

        end
    end // end always block


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ingress Policer and Congestion Manager Config AXI4Lite Masters

    assign ing_policer_table_config.awprot = '0;
    assign ing_policer_table_config.wstrb  = '1;
    assign ing_policer_table_config.bready = 1'b1;
    assign ing_policer_table_config.arprot = '0;
    assign ing_policer_table_config.rready = 1'b1;

    assign cong_man_table_config.awprot = '0;
    assign cong_man_table_config.wstrb  = '1;
    assign cong_man_table_config.bready = 1'b1;
    assign cong_man_table_config.arprot = '0;
    assign cong_man_table_config.rready = 1'b1;

    assign qsys_table_wr_req        = regs[ADDR_QSYS_TABLE_CONFIG][25];
    assign qsys_table_rd_req        = regs[ADDR_QSYS_TABLE_CONFIG][24];
    assign qsys_table_id.select     = regs[ADDR_QSYS_TABLE_CONFIG][17:16];
    assign qsys_table_id.address    = regs[ADDR_QSYS_TABLE_CONFIG][15:0];
    assign cir_wr_data              = regs[ADDR_QSYS_CONFIG_WDATA][CIR_TABLE_WIDTH-1:0];
    assign cbs_wr_data              = regs[ADDR_QSYS_CONFIG_WDATA][CBS_TABLE_WIDTH-1:0];

    assign qsys_table_config_wr_busy = ing_policer_table_config.awvalid | ing_policer_table_config.wvalid |
                                       cong_man_table_config.awvalid | cong_man_table_config.wvalid;

    always_ff @(posedge ing_policer_table_config.clk) begin
        if (!ing_policer_table_config.sresetn) begin
            ing_policer_table_config.awvalid <= 1'b0;
            ing_policer_table_config.wvalid  <= 1'b0;
            ing_policer_table_config.arvalid <= 1'b0;

            cong_man_table_config.awvalid    <= 1'b0;
            cong_man_table_config.wvalid     <= 1'b0;
            cong_man_table_config.arvalid    <= 1'b0;

            qsys_table_wr_req_d              <= 1'b0;
            qsys_table_rd_req_d              <= 1'b0;
            qsys_table_config_rd_busy        <= 1'b0;
        end else begin
            qsys_table_rd_req_d <= qsys_table_rd_req;
            qsys_table_wr_req_d <= qsys_table_wr_req;

            // Write Policer Tables
            if (qsys_table_wr_req && !qsys_table_wr_req_d && !qsys_table_config_wr_busy &&
            (qsys_table_id.select == ING_POLICER_CIR_TABLE || qsys_table_id.select == ING_POLICER_CBS_TABLE)) begin
                ing_policer_table_config.awvalid <= 1'b1;
                ing_policer_table_config.awaddr  <= qsys_table_id;
                ing_policer_table_config.wvalid  <= 1'b1;
                ing_policer_table_config.wdata   <= '0;
                ing_policer_table_config.wdata   <= qsys_table_id.select == ING_POLICER_CIR_TABLE ? cir_wr_data : cbs_wr_data;
            end else begin
                if (ing_policer_table_config.wready) begin
                    ing_policer_table_config.wvalid <= 1'b0;
                end
                if (ing_policer_table_config.awready) begin
                    ing_policer_table_config.awvalid <= 1'b0;
                end
            end

            // Write Congestion Manager Tables
            if (qsys_table_wr_req && !qsys_table_wr_req_d && !qsys_table_config_wr_busy &&
            (qsys_table_id.select == CONG_MAN_DROP_THRESH_TABLE || qsys_table_id.select == CONG_MAN_MALOC_THRESH_TABLE)) begin
                cong_man_table_config.awvalid <= 1'b1;
                cong_man_table_config.awaddr  <= qsys_table_id;
                cong_man_table_config.wvalid  <= 1'b1;
                cong_man_table_config.wdata   <= '0;
                cong_man_table_config.wdata   <= regs[ADDR_QSYS_CONFIG_WDATA];
            end else begin
                if (cong_man_table_config.wready) begin
                    cong_man_table_config.wvalid <= 1'b0;
                end
                if (cong_man_table_config.awready) begin
                    cong_man_table_config.awvalid <= 1'b0;
                end
            end

            // Read Policer Tables
            if (qsys_table_rd_req && !qsys_table_rd_req_d && !ing_policer_table_config.arvalid &&
            (qsys_table_id.select == ING_POLICER_CIR_TABLE || qsys_table_id.select == ING_POLICER_CBS_TABLE)) begin
                ing_policer_table_config.arvalid <= 1'b1;
                ing_policer_table_config.araddr  <= qsys_table_id;
                qsys_table_config_rd_busy        <= 1'b1;
            end else if (ing_policer_table_config.arready) begin
                ing_policer_table_config.arvalid <= 1'b0;
            end

            if (ing_policer_table_config.rvalid) begin
                qsys_table_config_rd_busy <= 1'b0;
            end

            // Read Congestion Manager Tables
            if (qsys_table_rd_req && !qsys_table_rd_req_d && !cong_man_table_config.arvalid &&
            (qsys_table_id.select == CONG_MAN_DROP_THRESH_TABLE || qsys_table_id.select == CONG_MAN_MALOC_THRESH_TABLE)) begin
                cong_man_table_config.arvalid <= 1'b1;
                cong_man_table_config.araddr  <= qsys_table_id;
                qsys_table_config_rd_busy <= 1'b1;
            end else if (cong_man_table_config.arready) begin
                cong_man_table_config.arvalid <= 1'b0;
            end

            if (cong_man_table_config.rvalid) begin
                qsys_table_config_rd_busy <= 1'b0;
            end
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Congestion Manager Counter Access AXI4Lite Master

    assign cong_man_counter_access.arprot = '0;
    assign cong_man_counter_access.rready = 1'b1;

    // write port is unused
    assign cong_man_counter_access.awaddr  = '0;
    assign cong_man_counter_access.awprot  = '0;
    assign cong_man_counter_access.awvalid = 1'b0;
    assign cong_man_counter_access.wdata   = '0;
    assign cong_man_counter_access.wvalid  = 1'b0;
    assign cong_man_counter_access.wstrb   = '1;
    assign cong_man_counter_access.bready  = 1'b1;

    assign qsys_counter_id.op_code      = regs[ADDR_QSYS_CNTR_CON][21:20];
    assign qsys_counter_id.queue        = regs[ADDR_QSYS_CNTR_CON][11:0];
    assign qsys_counter_id.counter_type = regs[ADDR_QSYS_CNTR_CON][19:12];
    assign qsys_cntr_op_req             = regs[ADDR_QSYS_CNTR_CON][24];

    always_ff @(posedge cong_man_counter_access.clk) begin
        if (!cong_man_counter_access.sresetn) begin
            cong_man_counter_access.arvalid <= 1'b0;

            qsys_cntr_op_req_d  <= 1'b0;
            qsys_cntr_op_busy   <= 1'b0;
        end else begin
            qsys_cntr_op_req_d <= qsys_cntr_op_req;

            if (qsys_cntr_op_req && !qsys_cntr_op_req_d && !qsys_cntr_op_busy) begin
                cong_man_counter_access.arvalid <= 1'b1;
                cong_man_counter_access.araddr  <= qsys_counter_id;
                qsys_cntr_op_busy <= 1'b1;
            end else if (cong_man_counter_access.arready) begin
                cong_man_counter_access.arvalid <= 1'b0;
            end

            if (cong_man_counter_access.rvalid) begin
                qsys_cntr_op_busy <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
