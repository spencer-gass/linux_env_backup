// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Ingress buffering for P4 router
 *  input arrays of adapted AXIS interfaces
 *  schedule words from interfaces into partitions of a wide memory
 *  schdule packets from the wide memory toward VNP4
 *
 * Notes:
 *  Using RR to schedule words from interfaces into the buffer and RR
 *  to schedule packets out of the buffer towards VNP4. This is simple
 *  and might be good engough but with larger numbers of low rate
 *  interfaces, it could make sense to use a scheduling algorithm that
 *  gives proportionally more time slots to the higher rate interfaces.
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

module p4_router_ingress_buffer #(
    parameter int NUM_ING_PHYS_PORTS  = 0,
    parameter int ING_BUF_DEPTH_PER_IFC = 4096,
    parameter int MIN_PKT_BYTES = 64,
    parameter int MTU_BYTES = 1500
)(
    AXIS_int.Slave      ing_phys_ports_adapted  [NUM_ING_PHYS_PORTS-1:0],
    AXIS_int.Master     ing_bus,

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import p4_router_pkg::*;
    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int ING_BUF_DEPTH_PER_IFC_LOG = $clog2(ING_BUF_DEPTH_PER_IFC);
    localparam int ING_BUF_DEPTH = ING_BUF_DEPTH_PER_IFC * NUM_ING_PHYS_PORTS;
    localparam int ING_BUF_DEPTH_LOG = $clog2(ING_BUF_DEPTH);
    localparam int MIN_PKT_WORDS = U_INT_CEIL_DIV(MIN_PKT_BYTES, ing_bus.DATA_BYTES);

    localparam int NUM_PKTS_PER_IFC = U_INT_CEIL_DIV(ING_BUF_DEPTH_PER_IFC, MIN_PKT_WORDS);
    localparam int NUM_PKTS_PER_IFC_LOG = $clog2(NUM_PKTS_PER_IFC);
    localparam int MTU_BYTES_LOG = $clog2(MTU_BYTES);
    localparam int ING_BUS_DATA_BYTES_LOG = $clog2(ing_bus.DATA_BYTES);
    localparam int ATR_BUF_WIDTH = ING_BUF_DEPTH_PER_IFC_LOG+ing_bus.DATA_BYTES;
    localparam int ATR_BUF_DEPTH = NUM_PKTS_PER_IFC * NUM_ING_PHYS_PORTS;
    localparam int ATR_BUF_DEPTH_LOG = $clog2(ATR_BUF_DEPTH);

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types

    typedef struct packed {
        logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] last_word_ptr;
        logic [MTU_BYTES_LOG-1:0] byte_length;
    } atr_t;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_GE(ING_BUF_DEPTH_PER_IFC*ing_bus.DATA_BYTES, 2*MIN_PKT_BYTES);
    `ELAB_CHECK_EQUAL(ing_phys_ports_adapted[0].DATA_BYTES, ing_bus.DATA_BYTES);
    `ELAB_CHECK_GE(ing_bus.USER_WIDTH, INGRESS_METADATA_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions

    function logic [ING_BUS_DATA_BYTES_LOG:0] keep_to_bytes(
        input [ing_bus.DATA_BYTES-1:0] keep
    );
        for (int i=1; i<ing_bus.DATA_BYTES; i++) begin
            if (!keep[i]) begin
                return i;
            end
        end
        return ing_bus.DATA_BYTES;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    (* ram_style = "block" *)       logic [ing_bus.DATA_BYTES*8-1:0] ing_buf [ING_BUF_DEPTH-1:0];
    (* ram_style = "distributed" *) logic [ATR_BUF_WIDTH-1:0]        atr_buf [ATR_BUF_DEPTH-1:0];

    logic                            ing_buf_wren;
    logic                            atr_buf_wren;
    logic [ing_bus.DATA_BYTES*8-1:0] ing_buf_wdata [2:1] = '{default: '0};
    logic [ATR_BUF_WIDTH-1:0]        atr_buf_wdata = '0;
    logic [ING_BUF_DEPTH_LOG-1:0]    ing_buf_waddr = '0;
    logic [ATR_BUF_DEPTH_LOG-1:0]    atr_buf_waddr = '0;

    logic [NUM_ING_PHYS_PORTS-1:0]   ing_phys_ports_adapted_tvalid;
    logic [ing_bus.DATA_BYTES*8-1:0] ing_phys_ports_adapted_tdata [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_ING_PHYS_PORTS-1:0]   ing_phys_ports_adapted_tlast;

    logic ing_valid;
    logic ing_last;
    logic partition_full;

    logic [NUM_ING_PHYS_PORTS_LOG-1:0]    wr_if_sel[2:0];
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_wr_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_wr_ptr_committed [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_wr_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] last_word_ptr;
    atr_t                                 atr_encoded;

    logic [MTU_BYTES_LOG-ING_BUS_DATA_BYTES_LOG-1:0] wcnt [NUM_ING_PHYS_PORTS-1:0];
    logic [MTU_BYTES_LOG-ING_BUS_DATA_BYTES_LOG-1:0] wcnt_sel;
    logic [ING_BUS_DATA_BYTES_LOG:0]                 keep_bytes_comb [NUM_ING_PHYS_PORTS-1:0];
    logic [ING_BUS_DATA_BYTES_LOG:0]                 keep_bytes [NUM_ING_PHYS_PORTS-1:0];

    logic [NUM_ING_PHYS_PORTS_LOG-1:0]    rd_if_sel;
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_rd_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_rd_ptr [NUM_ING_PHYS_PORTS-1:0];

    atr_t                                 atr_buf_rd;
    logic [ing_bus.DATA_BYTES-1:0]        keep_comb;
    logic [NUM_ING_PHYS_PORTS-1:0]        drop;

    logic [1:0] ing_bus_valid;
    logic [1:0] ing_bus_last;
    atr_t                               ing_bus_atr [1:0]     = '{default: '0};
    logic [ING_BUF_DEPTH_LOG-1:0]       ing_buf_raddr         = '0;
    logic [ing_bus.DATA_BYTES*8-1:0]    ing_bus_data          = '0;
    logic [NUM_ING_PHYS_PORTS_LOG-1:0]  ing_bus_port_id [1:0] = '{default: '0};
    logic [ing_bus.DATA_BYTES-1:0]      ing_bus_keep          = '0;

    ingress_metadata_t ingress_metadata;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB- SECTION: Buffre Write Controller

    for (genvar ifc=0; ifc<NUM_ING_PHYS_PORTS; ifc++) begin
        assign ing_phys_ports_adapted[ifc].tready = wr_if_sel[0] == ifc ? 1'b1 : 1'b0;
        assign ing_phys_ports_adapted_tvalid[ifc] = ing_phys_ports_adapted[ifc].tvalid;
        assign ing_phys_ports_adapted_tdata[ifc]  = ing_phys_ports_adapted[ifc].tdata;
        assign ing_phys_ports_adapted_tlast[ifc]  = ing_phys_ports_adapted[ifc].tlast;
        assign keep_bytes_comb[ifc]               = keep_to_bytes(ing_phys_ports_adapted[ifc].tkeep);
    end

    assign atr_encoded.last_word_ptr = last_word_ptr;
    assign atr_encoded.byte_length   = (wcnt_sel << ING_BUS_DATA_BYTES_LOG) + keep_bytes[wr_if_sel[1]];

    // Transfer one word per RR cycle to that interface's partition in the ingress buffer.
    // ingress interface throughput = ing_bus throughput / num_interface.
    // throughput into the buffer must be GTE L2 throughput on the interface to avoid async_fifo overflow.
    always_ff @(posedge ing_bus.clk ) begin : ing_buf_wr
        if (~ing_bus.sresetn) begin
            wr_if_sel            <= '{default: '0};
            ing_wr_ptr           <= '{default: '0};
            ing_wr_ptr_committed <= '{default: '0};
            atr_wr_ptr           <= '{default: '0};
            ing_buf_overflow     <= '0;
            drop                 <= '0;
            wcnt                 <= '{default: '0};
            ing_valid            <= 1'b0;
        end else begin
            /// Round-Robbin for now. could create an access pattern that hits wider interfaces more often to use the bus more efficiently
            /// The buffer write pipeline assumes that the same ports won't be visited in back-to-back cycles
            wr_if_sel <= {wr_if_sel[1:0], '0};
            if (wr_if_sel[0] == NUM_ING_PHYS_PORTS-1) begin
                wr_if_sel[0] <= '0;
            end else begin
                wr_if_sel[0] <= wr_if_sel[0] + 1;
            end

            // Stage 0
            ing_valid           <= ing_phys_ports_adapted_tvalid[wr_if_sel[0]];
            ing_last            <= ing_phys_ports_adapted_tlast[wr_if_sel[0]];
            partition_full      <= ing_wr_ptr[wr_if_sel[0]]+1 == ing_rd_ptr[wr_if_sel[0]] ? 1'b1 : 1'b0;
            ing_buf_wdata[1]    <= ing_phys_ports_adapted_tdata[wr_if_sel[0]];

            if (ing_phys_ports_adapted_tvalid[wr_if_sel[0]]) begin
                if (ing_phys_ports_adapted_tlast[wr_if_sel[0]]) begin
                    wcnt[wr_if_sel[0]] <= '0;
                end else begin
                    wcnt[wr_if_sel[0]] <= wcnt[wr_if_sel[0]] + 1;
                end
            end

            keep_bytes       <= keep_bytes_comb;
            wcnt_sel         <= wcnt[wr_if_sel[0]];
            last_word_ptr    <= ing_wr_ptr[wr_if_sel[0]];

            // Stage 1
            ing_buf_wren     <= 1'b0;
            atr_buf_wren     <= 1'b0;
            ing_buf_overflow <= '0;
            if (ing_valid) begin
                if (partition_full || drop[wr_if_sel[1]]) begin
                    drop[wr_if_sel[1]] <= 1'b1;
                    ing_wr_ptr[wr_if_sel[1]] <= ing_wr_ptr_committed[wr_if_sel[1]];
                    if (ing_last) begin
                        drop[wr_if_sel[1]] <= 1'b0;
                        ing_buf_overflow[wr_if_sel[1]] <= 1'b1;
                    end
                end else begin
                    ing_buf_wren  <= 1'b1;
                    ing_wr_ptr[wr_if_sel[1]] <= ing_wr_ptr[wr_if_sel[1]] + 1;
                    if (ing_last) begin
                        atr_buf_wren <= 1'b1;
                        ing_wr_ptr_committed[wr_if_sel[1]] <= ing_wr_ptr[wr_if_sel[1]];
                    end
                end
            end

            ing_buf_waddr    <= {wr_if_sel[1], ing_wr_ptr[wr_if_sel[1]]};
            ing_buf_wdata[2] <= ing_buf_wdata[1];
            atr_buf_waddr    <= {wr_if_sel[1], atr_wr_ptr[wr_if_sel[1]]};
            atr_buf_wdata    <= atr_encoded;

            // Stage 2
            if (ing_buf_wren) begin
                ing_buf[ing_buf_waddr] <= ing_buf_wdata[2];
            end
            if (atr_buf_wren) begin
                atr_wr_ptr[wr_if_sel[2]] <= atr_wr_ptr[wr_if_sel[2]] + 1;
                atr_buf[atr_buf_waddr] <= atr_buf_wdata;
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB- SECTION: Buffre Read Controller

    assign atr_buf_rd = atr_buf[{rd_if_sel, atr_rd_ptr[rd_if_sel]}];

    always_comb begin
        keep_comb = '0;
        for (int i=0; i<ing_bus.DATA_BYTES; i++) begin
            if (i < ing_bus_atr[0].byte_length[ING_BUS_DATA_BYTES_LOG-1:0]) keep_comb[i] = 1'b1;
        end
        if (ing_bus_atr[0].byte_length[ING_BUS_DATA_BYTES_LOG-1:0] === 0) keep_comb = '1;
    end

    // Round robbin through the partitions to check if a full packet is ready.
    // If so, dispatch toward VNP4. There should be more thoughput on this bus
    // than the individual interfaces combined so order shouldn't impact throughput
    // as long as the bus is utilized.
    // could make selection combinationally to avoid idle cycles while polling.
    // could use some kind of DWRR to balance latency for different packet sizes.
    always_ff @(posedge ing_bus.clk) begin : ing_buf_rd
        if (~ing_bus.sresetn) begin
            rd_if_sel  <= '0;
            ing_rd_ptr <= '{default: '0};
            atr_rd_ptr <= '{default: '0};
            ing_bus_valid <= '0;
            ing_bus_last  <= '0;
        end else begin

            // Stage 0
            if (ing_bus.tready || !ing_bus_valid[0] || !ing_bus_valid[1]) begin
                ing_bus_valid[0]   <= 1'b0;
                ing_bus_last[0]    <= 1'b0;
                ing_bus_atr[0]     <= atr_buf_rd;
                ing_bus_port_id[0] <= rd_if_sel;
                if (atr_rd_ptr[rd_if_sel] == atr_wr_ptr[rd_if_sel] || ing_bus_last[0]) begin
                    if (rd_if_sel == NUM_ING_PHYS_PORTS-1) begin
                        rd_if_sel <= '0;
                    end else begin
                        rd_if_sel <= rd_if_sel + 1;
                    end
                end else begin
                    ing_bus_valid[0] <= 1'b1;
                    ing_buf_raddr <= {rd_if_sel, ing_rd_ptr[rd_if_sel]};
                    ing_rd_ptr[rd_if_sel] <= ing_rd_ptr[rd_if_sel] + 1;
                    if (ing_rd_ptr[rd_if_sel] == atr_buf_rd.last_word_ptr) begin
                        ing_bus_last[0] <= 1'b1;
                        atr_rd_ptr[rd_if_sel] <= atr_rd_ptr[rd_if_sel] + 1;
                    end
                end
            end

            // Stage 1
            if (ing_bus.tready || !ing_bus_valid[1]) begin
                ing_bus_valid[1]   <= ing_bus_valid[0];
                ing_bus_last[1]    <= ing_bus_last[0];
                ing_bus_atr[1]     <= ing_bus_atr[0];
                ing_bus_port_id[1] <= ing_bus_port_id[0];
                if (ing_bus_valid[0]) begin
                    ing_bus_data  <= ing_buf[ing_buf_raddr];
                    ing_bus_keep  <= ing_bus_last[0] ? keep_comb : '1;
                end
            end
        end
    end

    assign ing_bus.tvalid = ing_bus_valid[1];
    assign ing_bus.tlast  = ing_bus_last[1];
    assign ing_bus.tkeep  = ing_bus_keep;
    assign ing_bus.tdata  = ing_bus_data;

    // insert ingress port number into tuser
    assign ingress_metadata.ingress_port = ing_bus_port_id[1];
    assign ingress_metadata.byte_length = ing_bus_atr[1].byte_length;
    assign ing_bus.tuser = ingress_metadata;

    // tie off unused AXIS signals
    assign ing_bus.tstrb = '1;
    assign ing_bus.tid   = '0;
    assign ing_bus.tdest = '0;

endmodule

`default_nettype wire
