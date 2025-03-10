// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Package
**/

`default_nettype none

package p4_router_pkg;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: ENUMs

    enum {
        RESERVED,
        ECHO_PHYS_PORT,
        FRR_T1_ECP,
        FRR_T1_MPCU,
        NUM_VNP4_IP_OPTIONS
    } vnp4_ip_options;

    enum {
        INDEX_8B,
        INDEX_16B,
        INDEX_32B,
        INDEX_64B,
        NUM_AXIS_ARRAYS
    } port_width_indecies;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Physical Port Array Related Constants and Functions

    localparam int NUM_ING_AXIS_ARRAYS = NUM_AXIS_ARRAYS;
    localparam int NUM_EGR_AXIS_ARRAYS = NUM_AXIS_ARRAYS;

    function int get_max_num_ports_per_array(
        input int array [NUM_AXIS_ARRAYS-1:0]
    );
        automatic int max = 0;
        for (int i=0; i<NUM_AXIS_ARRAYS; i++) begin
            if (array[i] > max) begin
                max = array[i];
            end
        end
        return max;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Stats Counters

    localparam int AXIS_PROFILE_BYTE_CNT_INDEX  = 0;
    localparam int AXIS_PROFILE_PKT_CNT_INDEX   = 5;
    localparam int AXIS_PROFILE_ERR_CNT_INDEX   = 6;

    localparam int ING_COUNTERS_WIDTH = 32;
    localparam int EGR_COUNTERS_WIDTH = 32;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Metadata structs Conveyed By AXIS.tuser

    localparam INGRESS_METADATA_INGRESS_PORT_WIDTH = 5;
    localparam VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH = 5;

    typedef struct packed {
        logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0]  ingress_port;
        logic [13:0] byte_length;
    } ingress_metadata_t;

    typedef struct packed {
        logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0]  ingress_port;
        logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0]  egress_port;
        logic [2:0]  prio;
        logic [13:0] byte_length;
    } vnp4_wrapper_metadata_t;

    typedef struct packed {
        logic [INGRESS_METADATA_INGRESS_PORT_WIDTH-1:0]  ingress_port;
        logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0]  egress_port;
        logic [2:0]  prio;
        logic [13:0] byte_length;
        logic        policer_drop_mark;
    } policer_metadata_t;

    typedef struct packed {
        logic [15:0]  tail_ptr;
        logic [15:0]  current_page_ptr;
        logic [15:0]  next_page_ptr;
    } cong_man_metadata_t;

    typedef struct packed {
        logic [VNP4_WRAPPER_METADATA_EGRESS_PORT_WIDTH-1:0]  egress_port;
    } queue_system_metadata_t;

    localparam int INGRESS_METADATA_WIDTH = $bits(ingress_metadata_t);
    localparam int VNP4_WRAPPER_METADATA_WIDTH = $bits(vnp4_wrapper_metadata_t);
    localparam int POLICER_METADATA_WIDTH = $bits(policer_metadata_t);
    localparam int CONG_MAN_METADATA_WIDTH = $bits(cong_man_metadata_t);
    localparam int QUEUE_SYS_METADATA_WIDTH = $bits(queue_system_metadata_t);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Queue System

    localparam int POLICER_COLOR_BITS = 2;
    localparam int PRIO_BITS = 3;

    enum {
        ING_POLICER_CIR_TABLE,
        ING_POLICER_CBS_TABLE,
        CONG_MAN_DROP_THRESH_TABLE,
        CONG_MAN_MALOC_THRESH_TABLE,
        NUM_QSYS_TABLES
    } queue_system_table_indecies;

    localparam int NUM_QSYS_TABLES_LOG = $clog2(NUM_QSYS_TABLES);

    enum {
        ING_POLICER_DROP,
        QUEUE_FULL_DROP,
        MALLOC_DROP,
        MEM_FULL_DROP,
        B2B_DROP,
        NUM_COUNTERS_PER_QUEUE
    } counter_names;

    enum {
        READ,
        READ_AND_CLEAR,
        CLEAR_ALL,
        NUM_QSYS_COUNTER_OP_CODES
    } qsys_counter_op_codes;

    localparam int NUM_QSYS_COUNTER_OP_CODES_LOG = $clog2(NUM_QSYS_COUNTER_OP_CODES);
    localparam int NUM_COUNTERS_PER_QUEUE_LOG = $clog2(NUM_COUNTERS_PER_QUEUE);

    function policer_metadata_t add_policer_drop_mark_to_metadata(
        input logic policer_drop_mark,
        input vnp4_wrapper_metadata_t vnp4_wrapper_metadata
    );
        automatic policer_metadata_t policer_metadata;

        policer_metadata.ingress_port      = vnp4_wrapper_metadata.ingress_port;
        policer_metadata.egress_port       = vnp4_wrapper_metadata.egress_port;
        policer_metadata.prio              = vnp4_wrapper_metadata.prio;
        policer_metadata.byte_length       = vnp4_wrapper_metadata.byte_length;
        policer_metadata.policer_drop_mark = policer_drop_mark;

        return policer_metadata;
    endfunction

    localparam int NUM_QUEUES_PER_EGR_PORT = 4;
    localparam int NUM_QUEUES_PER_EGR_PORT_LOG = $clog2(NUM_QUEUES_PER_EGR_PORT);

    localparam int DQ_LATENCY = 8; // Number of cycles after the scheduler requests a dequeue before it can dequeue to the same egress port
                                   // 0: scheduler dequeue request
                                   // 1: head pointer read req
                                   // 2: head pointer memory output register valid
                                   // 3: head pointer read resp
                                   // 4: queue mem DO1 valid
                                   // 5: queue mem DO2 valid + dequeue notification valid
                                   // 6: word_out valid + queue empty updates after queue states get dequeue notification
                                   // 7: egress demux valid
                                   // 8: egress buffer read updates
                                   /// could make egress demux combinational to save a cycle of latency

    typedef struct packed {
        logic [2:0]  whole;     // 10G ethernet is our highest rate interface so no more than 8 bytes per cycle should be needed.
        logic [12:0] fraction;  // CIR is in units of Mbits/sec or 8000ths-of-a-byte/clk -> clog2(8000) = 13.
    } bucket_decrement_t;

    localparam int CIR_TABLE_WIDTH = $bits(bucket_decrement_t);

    typedef struct packed {
        logic [19:0] whole;     // CBS is limited to 1024kbytes -> 2**20 bytes
        logic [12:0] fraction;  // As many fractional bits as the decrement.
    } bucket_t;

    typedef logic [19:0] bucket_depth_threshold_t; // CBS in bytes

    localparam int CBS_TABLE_WIDTH = $bits(bucket_depth_threshold_t);

    typedef struct packed {
        logic [1:0]  select;
        logic [15:0] address;
    } qsys_table_id_t;

    localparam int QSYS_TABLE_ID_WIDTH = $size(qsys_table_id_t);
    localparam int QSYS_TABLE_DATALEN = 32;

    typedef struct packed {
        logic [1:0]  op_code;
        logic [11:0] queue;
        logic [7:0]  counter_type;
    } qsys_counter_id_t;

    localparam int QSYS_COUNTER_WIDTH = 32;
    localparam int QSYS_COUNTER_ID_WIDTH = $bits(qsys_counter_id_t);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Metadata Structs Conveyed Over AXI4Lite.rdata and AXI4Lite.wdata

    // Used for AXI4Lite rdata and wdata, so keep total bit-width byte-alligned.
    typedef struct packed {
        logic [15:0] tail_ptr;
        logic [14:0] current_page_ptr;
        logic        current_page_valid;
    } queue_tail_pointer_read_t;

    typedef struct packed {
        logic [15:0] new_tail_ptr;
        logic [14:0] next_page_ptr;
        logic        malloc_approved;
    } queue_tail_pointer_write_t;

    localparam QUEUE_TAIL_POINTER_DATALEN = 32;

    typedef struct packed {
        logic [15:0] head_ptr;
        logic [15:0] page_ptr;
    } queue_head_pointer_read_t;

    localparam QUEUE_HEAD_POINTER_DATALEN = 32;


endpackage

`default_nettype wire