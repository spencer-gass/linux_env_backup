// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

/**
 * Ingress buffering for P4 router
 *  input arrays of adapted AXIS interfaces
 *  schedule words from interfaces into partitions of a wide memory
 *  schdule packets from the wide memory toward VNP4
**/

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none


module p4_router_ing_buf #(
    parameter int NUM_ING_PHYS_PORTS  = 0,
    parameter int ING_BUF_DEPTH_PER_IFC = 4096,
    parameter int MIN_PKT_BYTES = 64
)
(
    AXIS_int.Slave      ing_phys_ports_adapted  [NUM_ING_PHYS_PORTS-1:0],
    AXIS_int.Master     ing_bus,

    output var logic [NUM_ING_PHYS_PORTS-1:0] ing_buf_overflow
);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports

    import UTIL_INTS::*;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Localparams

    localparam int ING_BUF_DEPTH_PER_IFC_LOG = $clog2(ING_BUF_DEPTH_PER_IFC);
    localparam int ING_BUF_DEPTH = ING_BUF_DEPTH_PER_IFC * NUM_ING_PHYS_PORTS;
    localparam int MIN_PKT_WORDS = U_INT_CEIL_DIV(MIN_PKT_BYTES, ing_bus.DATA_BYTES);

    localparam int NUM_PKTS_PER_IFC = U_INT_CEIL_DIV(ING_BUF_DEPTH_PER_IFC, MIN_PKT_WORDS);
    localparam int NUM_PKTS_PER_IFC_LOG = $clog2(NUM_PKTS_PER_IFC);
    localparam int ATR_BUF_WIDTH = ING_BUF_DEPTH_PER_IFC_LOG+ing_bus.DATA_BYTES;
    localparam int ATR_BUF_DEPTH = NUM_PKTS_PER_IFC * NUM_ING_PHYS_PORTS;
    localparam int ATR_BUF_DEPTH_LOG = $clog2(ATR_BUF_DEPTH);

    localparam NUM_ING_PHYS_PORTS_LOG = $clog2(NUM_ING_PHYS_PORTS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Elaboration Checks

    `ELAB_CHECK_GT(NUM_ING_PHYS_PORTS, 0);
    `ELAB_CHECK_EQUAL(ing_phys_ports_adapted[0].DATA_BYTES, ing_bus.DATA_BYTES);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    logic [NUM_ING_PHYS_PORTS_LOG-1:0] wr_if_sel;
    (* ram_style = "mixed" *)       logic [ing_bus.DATA_BYTES*8-1:0] ing_buf [ING_BUF_DEPTH-1:0];
    (* ram_style = "distributed" *) logic [ATR_BUF_WIDTH-1:0] atr_buf [ATR_BUF_DEPTH-1:0];
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_wr_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_wr_ptr [NUM_ING_PHYS_PORTS-1:0];

    logic [NUM_ING_PHYS_PORTS-1:0]   tvalid;
    logic [ing_bus.DATA_BYTES*8-1:0] tdata [NUM_ING_PHYS_PORTS-1:0];
    logic [ing_bus.DATA_BYTES-1:0]   tkeep [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_ING_PHYS_PORTS-1:0]   tlast;

    logic [NUM_ING_PHYS_PORTS_LOG-1:0] rd_if_sel;

    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] last_word;
    logic [ATR_BUF_WIDTH-1:0]        atr_rd;
    logic [ING_BUF_DEPTH_PER_IFC_LOG-1:0] ing_rd_ptr [NUM_ING_PHYS_PORTS-1:0];
    logic [NUM_PKTS_PER_IFC_LOG-1:0]      atr_rd_ptr [NUM_ING_PHYS_PORTS-1:0];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    for (genvar ifc=0; ifc<NUM_ING_PHYS_PORTS; ifc++) begin
        assign ing_phys_ports_adapted[ifc].tready = wr_if_sel == ifc ? 1'b1 : 1'b0;
        assign tvalid[ifc] = ing_phys_ports_adapted[ifc].tvalid;
        assign tdata[ifc]  = ing_phys_ports_adapted[ifc].tdata;
        assign tkeep[ifc]  = ing_phys_ports_adapted[ifc].tkeep;
        assign tlast[ifc]  = ing_phys_ports_adapted[ifc].tlast;
    end

    always_ff @(posedge ing_bus.clk ) begin : ing_buf_wr
        if (~ing_bus.sresetn) begin
            wr_if_sel <= '0;
            ing_wr_ptr <= '{default: '0};
            atr_wr_ptr <= '{default: '0};
            ing_buf_overflow <= '0;
        end else begin
            // Round-Robbin for now. could create an access pattern that hits wider interfaces more often to use the bus more efficiently
            if (wr_if_sel == NUM_ING_PHYS_PORTS-1) begin
                wr_if_sel <= '0;
            end else begin
                wr_if_sel <= wr_if_sel + 1;
            end
            ing_buf_overflow <= '0;
            if (tvalid[wr_if_sel]) begin
                if (ing_wr_ptr[wr_if_sel]+1 == ing_rd_ptr[wr_if_sel]) ing_buf_overflow[wr_if_sel] <= 1'b1;
                ing_buf[{wr_if_sel, ing_wr_ptr[wr_if_sel]}] <= tdata[wr_if_sel];
                ing_wr_ptr[wr_if_sel] <= ing_wr_ptr[wr_if_sel] + 1;
                if (tlast[wr_if_sel]) begin
                    atr_buf[{wr_if_sel, atr_wr_ptr[wr_if_sel]}] <= {ing_wr_ptr[wr_if_sel], tkeep[wr_if_sel]};
                    atr_wr_ptr[wr_if_sel] <= atr_wr_ptr[wr_if_sel] + 1;
                end
            end
        end
    end

    assign atr_rd       = atr_buf[{rd_if_sel, atr_rd_ptr[rd_if_sel]}];
    assign last_word    = atr_rd[ing_bus.DATA_BYTES +: ING_BUF_DEPTH_PER_IFC_LOG];

    always_ff @(posedge ing_bus.clk) begin : ing_buf_rd
        if (~ing_bus.sresetn) begin
            rd_if_sel  <= '0;
            ing_rd_ptr <= '{default: '0};
            atr_rd_ptr <= '{default: '0};
            ing_bus.tvalid <= 1'b0;
            ing_bus.tlast  <= 1'b0;
        end else begin
            // Round-Robbin for now. could create an access pattern that hits wider interfaces more often to use the bus more efficiently
            ing_bus.tvalid <= 1'b0;
            ing_bus.tlast <= 1'b0;
            ing_bus.tkeep <= '1;
            if (atr_rd_ptr[rd_if_sel] == atr_wr_ptr[rd_if_sel] || ing_bus.tlast) begin
                if (rd_if_sel == NUM_ING_PHYS_PORTS-1) begin
                    rd_if_sel <= '0;
                end else begin
                    rd_if_sel <= rd_if_sel + 1;
                end
            end else begin
                ing_bus.tvalid <= 1'b1;
                ing_bus.tdata  <= ing_buf[{rd_if_sel, ing_rd_ptr[rd_if_sel]}];
                ing_rd_ptr[rd_if_sel] <= ing_rd_ptr[rd_if_sel] + 1;
                if (ing_rd_ptr[rd_if_sel] == last_word) begin
                    ing_bus.tlast <= 1'b1;
                    ing_bus.tkeep <= atr_rd[ing_bus.DATA_BYTES-1:0];
                    atr_rd_ptr[rd_if_sel] <= atr_rd_ptr[rd_if_sel] + 1;
                end else begin

                end
            end
        end
    end

    assign ing_bus.tstrb = '1;
    assign ing_bus.tid   = '0;
    assign ing_bus.tdest = '0;
    assign ing_bus.tuser = rd_if_sel;

endmodule

`default_nettype wire
