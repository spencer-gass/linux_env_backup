// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * P4 Router Queue Memory Management Unit
 *  Not yet implemented. Passthrough for now.
 *
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_uram_queue_mmu #(
    parameter int NUM_PAGES = 0,
    parameter int NUM_PAGES_LOG = $clog2(NUM_PAGES),
    parameter int MTU_BYTES = 2000
) (
    output var logic [NUM_PAGES_LOG:0]   num_free_pages,
    AXIS_int.Master                      malloc,
    AXIS_int.Slave                       free
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_PAGES_LOG, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types

    typedef enum { INIT, ACTIVE } mmu_state_t;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_PAGES_LOG-1:0] free_pages_fifo [NUM_PAGES-1:0];
    logic [NUM_PAGES_LOG:0]   free_pages_wr_ptr;
    logic [NUM_PAGES_LOG:0]   free_pages_rd_ptr;

    mmu_state_t mmu_state;
    logic [NUM_PAGES_LOG-1:0] init_cnt;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    // This results in the correct number of free pages except when free pages equals zero.
    // But in that case malloc.valid would deassert to inidcate that there are no more free words
    // and num_free_words would be ignored.
    assign num_free_pages = NUM_PAGES - free_pages_rd_ptr[NUM_PAGES_LOG-1:0] + free_pages_wr_ptr[NUM_PAGES_LOG-1:0];
    assign malloc.tvalid = free_pages_rd_ptr[NUM_PAGES_LOG-1:0] == free_pages_wr_ptr[NUM_PAGES_LOG-1:0] &&
                           free_pages_rd_ptr[NUM_PAGES_LOG] != free_pages_wr_ptr[NUM_PAGES_LOG] ?
                           1'b0 : 1'b1;
    assign free.tready = 1'b1;

    always_ff @(posedge malloc.clk ) begin
        if (!malloc.sresetn) begin
            mmu_state <= INIT;
            init_cnt <= '0;
            free_pages_wr_ptr <= '0;
            free_pages_rd_ptr <= '0;
        end else begin
            case (mmu_state)
                INIT: begin
                    `ifdef MODEL_TECH
                        // bypass looping through the counters in sim to save time.
                        mmu_state <= ACTIVE;
                        for (int i=0; i<NUM_PAGES; i++) begin
                            free_pages_fifo[i] <= i;
                        end
                    `endif
                    `ifndef MODEL_TECH
                        if (init_cnt == NUM_PAGES-1) begin
                            init_cnt <= '0;
                            mmu_state <= ACTIVE;
                        end else begin
                            init_cnt <= init_cnt + 1;
                        end
                        free_pages_fifo[init_cnt] <= init_cnt;
                    `endif
                end
                ACTIVE: begin
                    if (malloc.tvalid && malloc.tready) begin
                        free_pages_rd_ptr <= free_pages_rd_ptr + 1;
                    end
                    if (free.tvalid) begin
                        free_pages_wr_ptr <= free_pages_wr_ptr + 1;
                        free_pages_fifo[free_pages_wr_ptr] <= free.tdata;
                    end
                end
                default: begin
                    mmu_state <= INIT;
                end
            endcase
        end
    end

    assign malloc.tdata = free_pages_fifo[free_pages_rd_ptr];
    assign malloc.tkeep = '1;
    assign malloc.tuser = '0;
    assign malloc.tstrb = '1;
    assign malloc.tid   = '0;
    assign malloc.tdest = '0;


endmodule

`default_nettype wire
