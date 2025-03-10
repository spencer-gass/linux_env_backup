// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * P4 Router AVMM Registers
 * This module implements the AVMM registers for p4_router excluding the VNP4 instance which
 * has it's own table config, and stats registers accessible via an AXI4lite interface.
 * ## Register Map
 * | Offset | Register                 | Type  | Description                                                                                             |
 * |--------|--------------------------|-------|---------------------------------------------------------------------------------------------------------|
 * | 0-15   | AVMM_COMMON_REGS         |       | Ref: avmm_kepler_pkg.sv                                                                                 |
 * | 16     | PARAMS0                  | (r)   | Module parameters needed by software.                                                                   |
 * | 17     | PARAMS1                  | (r)   | Module parameters needed by software.                                                                   |
 * | 18     | ING_PORT_ENABLE_CON      | (r/w) | Enable bit per ingress port.                                                                            |
 * | 19     | EGR_PORT_ENABLE_CON      | (r/w) | Enable bit per egress port.                                                                             |
 * | 20     | ING_PORT_ENABLE_STAT     | (r)   | Changes to ING_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here.     |
 * | 21     | EGR_PORT_ENABLE_STAT     | (r)   | Changes to EGR_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here.     |
 * | 22     | ING_COUNTER_SAMPLE_CON   | (r/w) | Sample and clear ingress counters.                                                                      |
 * | 23     | ING_COUNTER_READ_SEL     | (r/w) | Ingress port and counter type selects.                                                                  |
 * | 24     | ING_COUNTER_READ_DATA0   | (r/w) | Least significant half of selected counter.                                                              |
 * | 25     | ING_COUNTER_READ_DATA1   | (r/w) | Most significant half of selected counter.                                                              |
 * | 26     | EGR_COUNTER_SAMPLE_CON   | (r/w) | Sample and clear egress counters.                                                                       |
 * | 27     | EGR_COUNTER_READ_SEL     | (r/w) | Egress port and coutner type selects.                                                                   |
 * | 28     | EGR_COUNTER_READ_DATA0   | (r/w) | Least significan half of selected counter.                                                              |
 * | 29     | EGR_COUNTER_READ_DATA1   | (r/w) | Most significant half of selected counter.                                                              |
 * | 30     | ING_POLICER_ENABLE       | (r/w) | Enables/disables ingress port shaper. One bit per ingress port.                                         |
 * | 31     | QSYS_TABLE_CONFIG        | (r/w) | Control and status for configuring queue system tables.                                                 |
 * | 32     | QSYS_CONFIG_WRITE_DATA   | (r/w) | Write data for congestion manager configuration table. See table entry formats below.                   |
 * | 33     | QSYS_CONFIG_READ_DATA    | (r)   | Read data from congestion manager configuration table. See table entry formats below.                   |
 * | 34     | QSYS_COUNTER_CON         | (r/w) | Control and status for reading and clearing queue system counters.                                      |
 * | 35     | QSYS_COUNTER_READ_DATA   | (r)   | Read data for queue system counters.                                                                    |
 * | 36     | PKT_CNT_CON              | (r)   | Sample and clear packet counters at different points in the router                                      |
 * | 37     | PKT_CNT_RDATA0           | (r)   | Least significan half of selected counter.                                                              |
 * | 38     | PKT_CNT_RDATA1           | (r)   | Most significant half of selected counter.                                                              |
 * | 39     | VNP4_STATUS              | (r/w) | Vitis Netowrking P4 RAM ECC Event indicator.                                                              |
 * ## Register Definitions
 * ### PARAMS0
 * - [23:16] VNP4_DATA_BYTES: VNP4 AXIS bus width in bytes
 * - [15:8]  NUM_EGR_PORTS: Number of egress interfaces
 * - [7:0]   NUM_ING_PORTS: Number of ingress interfaces
 * ### PARAMS1
 * - [31:16] CORE_CLOCK_PERIOD_PS: Core clock period in picoseconds. Used to calculate shaper decrement.
 * - [15:0]  MTU_BYTES: Supported MTU in bytes
 * ### ING_PORT_ENABLE_CON
 * - [NUM_ING_PORTS-1:0] Enable bit per ingress port. Enabled by default.
 * ### EGR_PORT_ENABLE_CON
 * - [NUM_EGR_PORTS-1:0] Enable bit per egress port. Enabled by default.
 * ### ING_PORT_ENABLE_STAT
 * - [NUM_ING_PORTS-1:0] Changes to ING_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here.
 * ### EGR_PORT_ENABLE_STAT
 * - [NUM_EGR_PORTS-1:0] Changes to EGR_PORT_ENABLE take non-zero time to take effect. Enabled status can be monitored here.
 * ### ING_COUNTER_SAMPLE_CON
 * - [NUM_ING_PORTS-1:0] SAMPLE_ING_COUNTER: Each bit in this register is associated with an ingress port of the same index. 0 to 1 transition of a bit in this register saves samples of all counters from the respective ingress ports then resets the counters. Counter samples can be read by selecting the desired counter via ING_COUNTER_READ_SEL, then reading the data from ING_COUNTER_READ_DATA.
 * ### ING_COUNTER_READ_SEL
 * - [15:8]  ING_PORT_SEL: Select ingress port to populate ING_COUNTER_READ_DATA.
 * - [7:0]   COUNTER_SEL: Select counter to populate ING_COUNTER_READ_DATA.
 *    - 0: Packet count: Number of packets that have ingressed p4_router on the associated port. Includes errored packets.
 *    - 1: Byte count: Sum of the byte lengths of the packets that have ingressed p4_router on the associated port. Includes bytes from errored packets.
 *    - 2: Error count: Number of packets that have ingressed p4_router on the associated port that were marked as errored by the respective MAC
 *    - 3: Ingress buffer overflow count: Number of packets that were dropped at the ingress buffer because the buffer was full. The system is designed in such a way that this shouldn't happen.
 * ### EGR_COUNTER_SAMPLE_CON
 * - [NUM_EGR_PORTS-1:0] Each bit in this register is associated with an egress port of the same index. 0 to 1 transition of a bit in this register saves samples of all counters from the respective egress ports then resets the counters. Counter samples can be read by selecting the desired counter via EGR_COUNTER_READ_SEL, then reading the data from EGR_COUNTER_READ_DATA.
 * ### EGR_COUNTER_READ_SEL
 * - [15:8]  EGR_PORT_SEL: Selects the egress port of the counter to be populated in EGR_COUNTER_READ_DATA.
 * - [7:0]   COUNTER_SEL: Selects the counter to be populated in EGR_COUNTER_READ_DATA.
 *    - 0: Packet count: Number of packets that have ingressed p4_router on the associated port. Includes errored packets.
 *    - 1: Byte count: Sum of the byte lengths of the packets that have ingressed p4_router on the associated port. Includes bytes from errored packets.
 *    - 2: Error count: Number of packets that have ingressed p4_router on the associated port that were marked as errored by the respective MAC
 *    - 3: Egress buffer overflow count: Number of packets that were dropped at the egress buffer because the buffer was full.
 * ### ING_POLICER_ENABLE
 * - [NUM_ING_PORTS-1:0] Enables/disables ingress port shaper. One bit per ingress port.
 * ### QSYS_TABLE_CONFIG
 * - [29]: WRITE_ERR - Write request failed due to invalid table select/address.
 * - [28]: READ_ERR - Read request failed due to invalid table select/address.
 * - [27]: WRITE_BUSY - 0: Write completed; 1: Write in progress.
 * - [26]: READ_BUSY - 0: Read completed; 1: Read in progress.
 * - [25]: WRITE_REQUEST - Triggers write to the selected table entry.
 * - [24]: READ_REQUEST - Triggers read from the selected table entry.
 * - [23:18]: Reserved
 * - [17:16]: TABLE_SELECT - 0: Ingress Policer CIR Table, 1: Ingress Policer CBS Table, 2: Queue Occupancy Threshold Table, 3: Malloc Threshold Table.
 * - [15:0]: TABLE_ADDR - Selects which queue or port index is addressed for read/write.
 * ### QSYS_COUNTER_CON
 * - [26]: ERR - Write request failed due to invalid table select/address.
 * - [25]: BUSY - 0: Read completed; 1: Read in progress.
 * - [24]: OP_REQUEST - Triggers an operation on the selected counter.
 * - [21:20]: OP_CODE - 0: Read, 1: Read and clear, 2: Clear all.
 * - [19:12]: COUNTER_SELECT - Selects counter type for read/clear.
 *    - 0: INGRESS SHAPER DROP - Ingress burst exceeded shaper rate for longer than the ingress queue could absorb.
 *    - 1: QUEUE FULL DROP - Egress queue filled to capacity
 *    - 2: MEMORY ALLOCATION DROP - Egress queue occupied to large a proportion of avaiable queuing memory
 *    - 3: MEMORY FULL DROP - No queuing memory avaiable to be allocated
 *    - 4: BACK TO BACK DROP - Congestion Manager doesn't support start-of-packet in adjacent cycles
 * - [11:7]: Reserved
 * - [6:0]: QUEUE_SELECT - Queue addressed for read/clear.
 * ### PKT_CNT_CON
 * - [11:8] PKT_CNT_READ_SELECT: Selects which sampled count is presented on PKT_CNT_RDATA. Ingress and egress port counts should be read through their respective register (e.g. ING_COUNTER_READ_SEL and ING_COUNTER_READ_DATA0/1).
 *    - 4: Dequeue Packet Counter
 *    - 3: Enqueue Packet Counter
 *    - 2: Queue System Input Packet Counter
 *    - 1: Ingress Bus Packet Counter
 * - [5:0] PKT_CNT_SAMPLE_AND_CLEAR: 0 to 1 transition samples and clears the respective counter. individual ingress and egress port counters can also be sampled with thier respective registers (e.g. ING_COUNTER_READ_SEL and ING_COUNTER_READ_DATA0/1). This register provides a way to sample all packet counters atomically.
 *    - 5: Egress Port Counters: packet, byte, and error counters for all egress ports.
 *    - 4: Dequeue Packet Counter: packets that have exited the queue system toward egress.
 *    - 3: Enqueue Packet Counter: packets that have passed congestion manager and are entering queue memory.
 *    - 2: Queue System Input Packet Counter: packets that have exited VNP4 and are entering the queue system.
 *    - 1: Ingress Bus Packet Counter: packets exiting the ingress buffer toward VNP4.
 *    - 0: Ingress Port Counters: packet, byte and erro counters for all ingress ports.
 * ### VNP4_STATUS
 * - [0] VNP4 RAM ECC event sticky bit. write 0 to clear.
 * ## Table Entry Formats
 * ### Ingress Policer CIR Table
 * One entry per ingress port.
 * Entry format:
 * - [31:16] reserved
 * - [15:13] ING_CIR_WHOLE: Whole part of comitted information rate (i.e. ingress shaper rate)
 * - [12:0]  ING_CIR_FRACTION: fractional part of ingress CIR. CIR is a 3w.13f fixed point number in units of Bytes per clock cycle
 * Notes:
 * - Conveting Mbps to bytes/cycle: Mbits/Sec -> bits/us * 1 bytes / 8 bits * 1 us / 1000ns * CLOCK_PERIOD ns / 1 clock = bytes/clock
 * - where CLOCK_PERIOD in ns comes from CLOCK_PERIOD_PS in PARAMS1 divided by 1000 to convert from ps to ns.
 * ### Ingress Policer CBS Table
 * One entry per ingress port
 * Entry format:
 * - [31:20] reserved
 * - [19:0] ING_CBS: Comitted burst size (i.e. ingress queue depth threshold) in units of bytes.
 * ### Congestion Manager Queue Occupancy Threshold Table
 * One entry per queue
 * Address = {egress_port, prio}; where prio is a 3-bit field.
 * Entry format:
 * - [31:MAX_BYTES_PER_QUEUE_LOG]  reserved
 * - [MAX_BYTES_PER_QUEUE_LOG-1:0] QUEUE_OCCUPANCY_THRESHOLD: Queue occupancy in bytes above which the congestion manager will drop packets to the respective queue.
 * ### Congestion Manager Malloc Threshold table entry format:
 * - Not yet defined or implemented
**/

module p4_router_avmm_regs
    import AVMM_COMMON_REGS_PKG::*;
    import P4_ROUTER_PKG::*;
#(
    parameter bit [15:0]  MODULE_ID = 0,
    parameter int         MTU_BYTES = 2000,
    parameter int         VNP4_DATA_BYTES = 0,
    parameter real        CLOCK_PERIOD_NS = 0,

    parameter int         NUM_ING_PHYS_PORTS = 1,
    parameter int         NUM_EGR_PHYS_PORTS = 1,
    parameter int         ING_COUNTERS_WIDTH = 64,
    parameter int         EGR_COUNTERS_WIDTH = 64
) (
    // Clocks and Resets
    Clock_int.Input     avmm_clk_ifc,
    Reset_int.ResetIn   interconnect_sreset_ifc,
    Reset_int.ResetIn   peripheral_sreset_ifc,

    Clock_int.Input     core_clk_ifc,
    Reset_int.ResetIn   core_sreset_ifc,

    // AVMM Slave
    AvalonMM_int.Slave  avmm,

    output var logic ing_bus_pkt_cnt_clear,
    output var logic qsys_in_pkt_cnt_clear,
    output var logic enqueue_pkt_cnt_clear,
    output var logic dequeue_pkt_cnt_clear,
    input  var logic [63:0] ing_bus_pkt_cnt,
    input  var logic [63:0] qsys_in_pkt_cnt,
    input  var logic [63:0] enqueue_pkt_cnt,
    input  var logic [63:0] dequeue_pkt_cnt,

    // Ingress
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_phys_ports_enable,
    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_cnts_clear,
    input  var logic [ING_COUNTERS_WIDTH-1:0] ing_cnts [NUM_ING_PHYS_PORTS-1:0] [6:0],
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_ports_conneted,
    input  var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow,

    // VNP4
    input  var logic vnp4_ram_ecc_event,

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

    localparam bit [7:0]  NUM_ING_PHYS_PORTS_VEC  = NUM_ING_PHYS_PORTS;
    localparam bit [7:0]  NUM_EGR_PHYS_PORTS_VEC  = NUM_EGR_PHYS_PORTS;
    localparam bit [7:0]  VNP4_DATA_BYTES_VEC = VNP4_DATA_BYTES;
    localparam bit [15:0] MTU_BYTES_VEC = MTU_BYTES;
    localparam bit [15:0] CLOCK_PERIOD_PS_VEC = $rtoi(CLOCK_PERIOD_NS * 1000);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks


    `ELAB_CHECK_GT    ( NUM_ING_PHYS_PORTS, 0                );
    `ELAB_CHECK_GT    ( NUM_EGR_PHYS_PORTS, 0                );
    `ELAB_CHECK_LE    ( NUM_ING_PHYS_PORTS, avmm.DATALEN     ); // Some 32-bit register have a bit per ingress physical port. This register file would need a refactor to support > 32 ingress ports
    `ELAB_CHECK_LE    ( NUM_EGR_PHYS_PORTS, avmm.DATALEN     ); // Same for egress physical ports.
    `ELAB_CHECK_GT    ( VNP4_DATA_BYTES, 0                   );
    `ELAB_CHECK_GT    ( CLOCK_PERIOD_PS_VEC, 0               );
    `ELAB_CHECK_GE    ( avmm.ADDRLEN, $clog2(TOTAL_REGS)     );
    `ELAB_CHECK_EQUAL ( avmm.DATALEN, P4_ROUTER_AVMM_DATALEN ); // Only 32-bit avmm is supported


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Declarations


    logic peripheral_sresetn_core;
    logic interconnect_sresetn_core;
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
                       word_address inside {
                        ADDR_ING_PORT_ENABLE_CON,
                        ADDR_EGR_PORT_ENABLE_CON,
                        ADDR_ING_CNTRS_SAMPLE_CON,
                        ADDR_ING_CNTRS_READ_SEL,
                        ADDR_EGR_CNTRS_SAMPLE_CON,
                        ADDR_EGR_CNTRS_READ_SEL,
                        ADDR_ING_POLICER_ENABLE,
                        ADDR_QSYS_TABLE_CONFIG,
                        ADDR_QSYS_CONFIG_WDATA,
                        ADDR_QSYS_CNTR_CON,
                        ADDR_PKT_CNT_CON,
                        ADDR_VNP4_STATUS
                       };
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
        .resetn_in  ( peripheral_sreset_ifc.reset != peripheral_sreset_ifc.ACTIVE_HIGH  ),
        .rx_clk     ( core_clk_ifc.clk                                                  ),
        .resetn_out ( peripheral_sresetn_core                                            )
    );

    xclock_resetn xclock_interconnect_sreset (
        .tx_clk     ( 1'b0                                                                 ), // Only used if INPUT_REG = 1.
        .resetn_in  ( interconnect_sreset_ifc.reset != interconnect_sreset_ifc.ACTIVE_HIGH ),
        .rx_clk     ( core_clk_ifc.clk                                                     ),
        .resetn_out ( interconnect_sresetn_core                                             )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Transaction


    assign word_address = avmm_core.address >> 2;
    assign peripheral_or_core_sreset = (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) | ~peripheral_sresetn_core;

    assign ing_cntr_port_sel = regs[ADDR_ING_CNTRS_READ_SEL][15:8];
    assign ing_cntr_sel      = regs[ADDR_ING_CNTRS_READ_SEL][7:0];
    assign egr_cntr_port_sel = regs[ADDR_EGR_CNTRS_READ_SEL][15:8];
    assign egr_cntr_sel      = regs[ADDR_EGR_CNTRS_READ_SEL][7:0];

    assign ing_cnts_sample_req = regs[ADDR_ING_CNTRS_SAMPLE_CON];
    assign egr_cnts_sample_req = regs[ADDR_EGR_CNTRS_SAMPLE_CON];

    assign ing_policer_enable = regs[ADDR_ING_POLICER_ENABLE][NUM_ING_PHYS_PORTS-1:0];

    always_ff @(posedge core_clk_ifc.clk) begin
        if (!interconnect_sresetn_core) begin // AVMM bus reset
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

            // Packet Counters
            ing_ports_pkt_cnt_sample_req <= regs[ADDR_PKT_CNT_CON][0];
            ing_bus_pkt_cnt_sample_req   <= regs[ADDR_PKT_CNT_CON][1];
            qsys_in_pkt_cnt_sample_req   <= regs[ADDR_PKT_CNT_CON][2];
            enqueue_pkt_cnt_sample_req   <= regs[ADDR_PKT_CNT_CON][3];
            dequeue_pkt_cnt_sample_req   <= regs[ADDR_PKT_CNT_CON][4];
            egr_ports_pkt_cnt_sample_req <= regs[ADDR_PKT_CNT_CON][5];

            ing_ports_pkt_cnt_sample_req_d <= ing_ports_pkt_cnt_sample_req;
            ing_bus_pkt_cnt_sample_req_d   <= ing_bus_pkt_cnt_sample_req;
            qsys_in_pkt_cnt_sample_req_d   <= qsys_in_pkt_cnt_sample_req;
            enqueue_pkt_cnt_sample_req_d   <= enqueue_pkt_cnt_sample_req;
            dequeue_pkt_cnt_sample_req_d   <= dequeue_pkt_cnt_sample_req;
            egr_ports_pkt_cnt_sample_req_d <= egr_ports_pkt_cnt_sample_req;

            if (ing_bus_pkt_cnt_sample_req && !ing_bus_pkt_cnt_sample_req_d) begin
                ing_bus_pkt_cnt_sampled <= ing_bus_pkt_cnt;
                ing_bus_pkt_cnt_clear   <= 1'b1;
            end else begin
                ing_bus_pkt_cnt_clear   <= 1'b0;
            end

            if (qsys_in_pkt_cnt_sample_req && !qsys_in_pkt_cnt_sample_req_d) begin
                qsys_in_pkt_cnt_sampled <= qsys_in_pkt_cnt;
                qsys_in_pkt_cnt_clear   <= 1'b1;
            end else begin
                qsys_in_pkt_cnt_clear   <= 1'b0;
            end

            if (enqueue_pkt_cnt_sample_req && !enqueue_pkt_cnt_sample_req_d) begin
                enqueue_pkt_cnt_sampled <= enqueue_pkt_cnt;
                enqueue_pkt_cnt_clear   <= 1'b1;
            end else begin
                enqueue_pkt_cnt_clear   <= 1'b0;
            end

            if (dequeue_pkt_cnt_sample_req && !dequeue_pkt_cnt_sample_req_d) begin
                dequeue_pkt_cnt_sampled <= dequeue_pkt_cnt;
                dequeue_pkt_cnt_clear   <= 1'b1;
            end else begin
                dequeue_pkt_cnt_clear   <= 1'b0;
            end

            case (regs[ADDR_PKT_CNT_CON][11:8])
                ING_BUS_PKT_CNTR : begin
                    regs[ADDR_PKT_CNT_RDATA0] <= ing_bus_pkt_cnt_sampled[31:0];
                    regs[ADDR_PKT_CNT_RDATA1] <= ing_bus_pkt_cnt_sampled[63:32];
                end
                QSYS_IN_PKT_CNTR : begin
                    regs[ADDR_PKT_CNT_RDATA0] <= qsys_in_pkt_cnt_sampled[31:0];
                    regs[ADDR_PKT_CNT_RDATA1] <= qsys_in_pkt_cnt_sampled[63:32];
                end
                ENQUEUE_PKT_CNTR : begin
                    regs[ADDR_PKT_CNT_RDATA0] <= enqueue_pkt_cnt_sampled[31:0];
                    regs[ADDR_PKT_CNT_RDATA1] <= enqueue_pkt_cnt_sampled[63:32];
                end
                DEQUEUE_PKT_CNTR : begin
                    regs[ADDR_PKT_CNT_RDATA0] <= dequeue_pkt_cnt_sampled[31:0];
                    regs[ADDR_PKT_CNT_RDATA1] <= dequeue_pkt_cnt_sampled[63:32];
                end
                default: begin
                    regs[ADDR_PKT_CNT_RDATA0] <= '0;
                    regs[ADDR_PKT_CNT_RDATA1] <= '0;
                end
            endcase

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
                if (ing_cnts_sample_req[ing_port] && !ing_cnts_sample_req_d[ing_port] ||
                ing_ports_pkt_cnt_sample_req && !ing_ports_pkt_cnt_sample_req_d) begin
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
                regs[ADDR_ING_CNTRS_READ_DATA0] <= ing_cnts_sampled[ing_cntr_port_sel][ing_cntr_sel][31:0];
                regs[ADDR_ING_CNTRS_READ_DATA1] <= ing_cnts_sampled[ing_cntr_port_sel][ing_cntr_sel][63:32];
            end else begin
                regs[ADDR_ING_CNTRS_READ_DATA0] <= '0;
                regs[ADDR_ING_CNTRS_READ_DATA1] <= '0;
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
                if (egr_cnts_sample_req[egr_port] && !egr_cnts_sample_req_d[egr_port] ||
                egr_ports_pkt_cnt_sample_req && !egr_ports_pkt_cnt_sample_req_d) begin
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
                regs[ADDR_EGR_CNTRS_READ_DATA0] <= egr_cnts_sampled[egr_cntr_port_sel][egr_cntr_sel][31:0];
                regs[ADDR_EGR_CNTRS_READ_DATA1] <= egr_cnts_sampled[egr_cntr_port_sel][egr_cntr_sel][63:32];
            end else begin
                regs[ADDR_EGR_CNTRS_READ_DATA0] <= '0;
                regs[ADDR_EGR_CNTRS_READ_DATA1] <= '0;
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

            // VNP4
            if (vnp4_ram_ecc_event) begin
                regs[ADDR_VNP4_STATUS][0] <= 1'b1;
            end
            regs[ADDR_VNP4_STATUS][31:1] <= '0;

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
                ing_bus_pkt_cnt_sampled                                <= '0;
                ing_bus_pkt_cnt_clear                                  <= 1'b0;
                // VNP4
                regs[ADDR_VNP4_STATUS]                                 <= '0;
                // Queue System
                regs[ADDR_ING_POLICER_ENABLE]                          <= '0;
                regs[ADDR_QSYS_TABLE_CONFIG]                           <= '0;
                regs[ADDR_QSYS_CONFIG_WDATA]                           <= '0;
                regs[ADDR_QSYS_CONFIG_RDATA]                           <= '0;
                regs[ADDR_QSYS_CNTR_CON]                               <= '0;
                regs[ADDR_PKT_CNT_CON]                                 <= '0;
                regs[ADDR_QSYS_CNTR_RDATA]                             <= '0;
                qsys_table_config_wr_err                               <= 1'b0;
                qsys_table_config_rd_err                               <= 1'b0;
                qsys_cntr_op_err                                       <= 1'b0;
                enqueue_pkt_cnt_sampled                                <= '0;
                dequeue_pkt_cnt_sampled                                <= '0;
                qsys_in_pkt_cnt_sampled                                <= '0;
                qsys_in_pkt_cnt_clear                                  <= 1'b0;
                enqueue_pkt_cnt_clear                                  <= 1'b0;
                dequeue_pkt_cnt_clear                                  <= 1'b0;
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
