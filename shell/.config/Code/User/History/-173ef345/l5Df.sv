// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Queue System
 *
**/

`timescale 1ns/1ps
`include "../../rtl/util/util_make_monitors.svh"
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_queue_system #(
    parameter int NUM_EGR_PORTS = 0,
    parameter int QUEUE_MEM_URAM_DEPTH = 1,
    parameter int MTU_BYTES = 2000
) (

    AXI4Lite_int.Slave  policer_table_config,
    AXI4Lite_int.Slave  cong_man_table_config,

    AXIS_int.Slave  packet_in,
    AXIS_int.Master word_out

);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int NUM_URAM_WORDS = QUEUE_MEM_URAM_DEPTH*4096;
    localparam int NUM_URAM_WORDS_LOG = $clog2(NUM_URAM_WORDS);
    localparam int NUM_URAM_BYTES = NUM_URAM_WORDS*packet_in.DATA_BYTES;
    localparam int MAX_QUEUE_OCCUPANCY = NUM_URAM_BYTES;
    localparam int MAX_QUEUE_OCCUPANCY_LOG = $clog2(MAX_QUEUE_OCCUPANCY);
    localparam int NUM_QUEUES = NUM_EGR_PORTS*NUM_QUEUES_PER_EGR_PORT;
    localparam int NUM_QUEUES_LOG = $clog2(NUM_QUEUES);
    localparam int BYTES_PER_PAGE = 4096;
    localparam int WORDS_PER_PAGE = BYTES_PER_PAGE/packet_in.DATA_BYTES;
    localparam int NUM_PAGES = NUM_URAM_BYTES / BYTES_PER_PAGE;
    localparam int NUM_PAGES_LOG = $clog2(NUM_PAGES);

    localparam int SCHED_DQ_REQ_BYTES = U_INT_CEIL_DIV(NUM_QUEUES_LOG, 8);
    localparam int DQ_NOTE_DATA_BYTES = U_INT_CEIL_DIV($clog2(packet_in.DATA_BYTES)+1, 8);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_EQUAL(packet_in.DATA_BYTES, word_out.DATA_BYTES);
    `ELAB_CHECK_GT(NUM_EGR_PORTS, 0);
    `ELAB_CHECK_GT(QUEUE_MEM_URAM_DEPTH, 0);
    `ELAB_CHECK_GT(BYTES_PER_PAGE, MTU_BYTES) // Some modules assume that a packet can only cross one page boundary so BYTES_PER_PAGE should be GT MTU.


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_PAGES_LOG:0] num_free_pages;
    logic [NUM_QUEUES-1:0]  sched_queue_empty;

    AXIS_int #(
        .DATA_BYTES         ( packet_in.DATA_BYTES     ),
        .USER_WIDTH         ( POLICER_METADATA_WIDTH   ),
        .ALLOW_BACKPRESSURE ( 0                        )
    ) policer_to_cong_man (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES         ( packet_in.DATA_BYTES    ),
        .USER_WIDTH         ( CONG_MAN_METADATA_WIDTH ),
        .ALLOW_BACKPRESSURE ( 0                       )
    ) cong_man_to_enqueue (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES ( NUM_PAGES_LOG  ),
        .ALLOW_BACKPRESSURE ( 0      )
    ) queue_mem_alloc (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES ( NUM_PAGES_LOG  ),
        .ALLOW_BACKPRESSURE ( 0      )
    ) queue_mem_free (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXIS_int #(
        .DATA_BYTES ( DQ_NOTE_DATA_BYTES ),
        .USER_WIDTH ( NUM_QUEUES_LOG ),
        .ALLOW_BACKPRESSURE ( 0      )
    ) dequeue_notification (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    `MAKE_AXIS_MONITOR(dequeue_notification_monitor, dequeue_notification);


    AXIS_int #(
        .DATA_BYTES ( SCHED_DQ_REQ_BYTES  ),
        .ALLOW_BACKPRESSURE ( 0           )
    ) sched_dequeue_req (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXI4Lite_int #(
        .DATALEN    ( MAX_QUEUE_OCCUPANCY_LOG ),
        .ADDRLEN    ( NUM_QUEUES_LOG          )
    ) cong_man_queue_occupancy (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_TAIL_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG             )
    ) queue_tail_pointer (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    AXI4Lite_int #(
        .DATALEN    ( QUEUE_HEAD_POINTER_DATALEN ),
        .ADDRLEN    ( NUM_QUEUES_LOG     )
    ) queue_head_pointer (
        .clk     ( packet_in.clk     ),
        .sresetn ( packet_in.sresetn )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Policer

    p4_router_policer #(
        .MTU_BYTES  ( MTU_BYTES             )
    ) policer (
        .table_config   ( policer_table_config  ),
        .packet_in      ( packet_in             ),
        .packet_out     ( policer_to_cong_man   )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Congestion Manager

    p4_router_congestion_manager #(
        .NUM_PAGES                  ( NUM_PAGES                 ),
        .BYTES_PER_PAGE             ( BYTES_PER_PAGE            ),
        .MAX_BYTES_PER_QUEUE        ( NUM_URAM_BYTES            ),
        .NUM_EGR_PORTS              ( NUM_EGR_PORTS             ),
        .MTU_BYTES                  ( MTU_BYTES                 )
    ) congestion_manager (
        .table_config               ( cong_man_table_config         ),
        .packet_in                  ( policer_to_cong_man           ),
        .packet_out                 ( cong_man_to_enqueue           ),
        .queue_occupancy_a4l        ( cong_man_queue_occupancy      ),
        .queue_tail_pointer_a4l     ( queue_tail_pointer            ),
        .queue_malloc_axis          ( queue_mem_alloc               ),
        .num_free_pages             ( num_free_pages                )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue States

    p4_router_queue_states #(
        .NUM_PAGES               ( NUM_PAGES                 ),
        .WORDS_PER_PAGE          ( WORDS_PER_PAGE            ),
        .BYTES_PER_WORD          ( packet_in.DATA_BYTES      ),
        .NUM_EGR_PORTS           ( NUM_EGR_PORTS             ),
        .MTU_BYTES               ( MTU_BYTES                 )
    ) queue_state (
        .enqueue_queue_occupancy_a4l    ( cong_man_queue_occupancy    ),
        .queue_tail_pointer_a4l         ( queue_tail_pointer          ),
        .queue_head_pointer_a4l         ( queue_head_pointer          ),
        .dequeue_queue_occupancy_axis   ( dequeue_notification        ),
        .queue_empty                    ( sched_queue_empty           )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: URAM Queue Memory Management Unit

    p4_router_uram_queue_mmu #(
        .NUM_PAGES      ( NUM_PAGES         ),
        .MTU_BYTES      ( MTU_BYTES         )
    ) uram_queue_mmu (
        .num_free_pages ( num_free_pages    ),
        .malloc         ( queue_mem_alloc   ),
        .free           ( queue_mem_free    )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Scheduler

    p4_router_scheduler #(
        .NUM_EGR_PORTS           ( NUM_EGR_PORTS            ),
        .MTU_BYTES               ( MTU_BYTES                )
    ) scheduler (
        .queue_empty            ( sched_queue_empty             ),
        .dequeue_notification   ( dequeue_notification_monitor  ),
        .dequeue_req            ( sched_dequeue_req             )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Queue Memory

    p4_router_uram_queue_memory #(
        .QUEUE_MEM_URAM_DEPTH    ( QUEUE_MEM_URAM_DEPTH     ),
        .BYTES_PER_PAGE          ( BYTES_PER_PAGE           ),
        .NUM_PAGES               ( NUM_PAGES                ),
        .NUM_EGR_PORTS           ( NUM_EGR_PORTS            ),
        .MTU_BYTES               ( MTU_BYTES                )
    ) uram_queue_memory (
        .packet_in                 ( cong_man_to_enqueue   ),
        .sched_dequeue_req         ( sched_dequeue_req     ),
        .word_out                  ( word_out              ),
        .queue_head_pointer_a4l    ( queue_head_pointer    ),
        .dequeue_notification      ( dequeue_notification  ),
        .queue_mem_free            ( queue_mem_free        )
    );


endmodule

`default_nettype wire
