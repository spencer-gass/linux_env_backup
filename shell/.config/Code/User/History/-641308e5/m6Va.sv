// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Ethernet cross-bar switch N MACs to M PHYs of different kinds. This module handles GMII/XGMII translation to AXI streams both
 * ways.
 *
 * ![](diagrams/ethernet/ethernet_crossbar_muxing.svg)
 */
module ethernet_crossbar
#(
    parameter bit [15:0] MODULE_VERSION           = 0,
    parameter bit [15:0] MODULE_ID                = 0,
    parameter int NUM_PHY_PPLS                    = 1,  // number of 64-bit PPL AXI streams
    parameter int NUM_PHY_XGMIIS                  = 1,  // number of XGMII interfaces towards PHY (PCS/PMA) 10G
    parameter int NUM_PHY_GMIIS                   = 1,  // number of GMII interfaces towards PHY (PCS/PMA) 1G/2.5G
    parameter int NUM_MAC_XGMIIS                  = 1,  // number of XGMII interfaces towards MAC 10G
    parameter int NUM_MAC_GMIIS                   = 1,  // number of XGMII interfaces towards MAC 1G/2.5G
    parameter int NUM_MAC_AXIS                    = 1,  // number of AXIS interfaces towards MAC 1G/2.5G
    parameter int NUM_PHY_LOOPBACKS               = 0,
    parameter int NUM_MAC_LOOPBACKS               = 0,
    parameter int MAX_PKTSIZE                     = 8192,
    parameter bit [NUM_PHY_XGMIIS-1:0] PHY_XGMII_ILA_MASK           = '0,
    parameter bit [NUM_PHY_PPLS-1:0]   PHY_PPL_ILA_MASK             = '0,
    parameter bit [NUM_PHY_GMIIS-1:0]  PHY_GMII_ILA_MASK            = '0,
    parameter bit [NUM_MAC_GMIIS-1:0]  MAC_GMII_ILA_MASK            = '0
) (


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Interfaces


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: clocks and restes


    Clock_int.Input clk_ifc_avmm,
    Reset_int.ResetIn sreset_ifc_avmm_peripheral,
    Reset_int.ResetIn sreset_ifc_avmm_interconnect,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: interfaces towards PHYs


    AXIS_int.Slave  ppl_ins  [0:0][NUM_PHY_PPLS-1:0][0:0],
    AXIS_int.Master ppl_outs [0:0][NUM_PHY_PPLS-1:0][0:0],

    GMII_int.Master   phy_gmiis    [NUM_PHY_GMIIS-1:0],
    Clock_int.Input   clk_ifc_phy_gmiis[NUM_PHY_GMIIS-1:0],
    Reset_int.ResetIn sreset_ifc_phy_gmiis[NUM_PHY_GMIIS-1:0],


    XGMII_int.Master  phy_xgmiis    [NUM_PHY_XGMIIS-1:0],


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: interfaces towards MACs


    GMII_int.Slave mac_gmiis    [NUM_MAC_GMIIS-1:0],
    Clock_int.Input clk_ifc_mac_gmiis[NUM_MAC_GMIIS-1:0],
    Reset_int.ResetIn sreset_ifc_mac_gmiis[NUM_MAC_GMIIS-1:0],


    XGMII_int.Slave  mac_xgmiis    [NUM_MAC_XGMIIS-1:0],
    Clock_int.Input clk_ifc_mac_xgmiis[NUM_MAC_XGMIIS-1:0],
    Reset_int.ResetIn sreset_ifc_mac_xgmiis[NUM_MAC_XGMIIS-1:0],


    AXIS_int.Slave mac_axis_ins  [NUM_MAC_AXIS-1:0],
    AXIS_int.Master mac_axis_outs  [NUM_MAC_AXIS-1:0],


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM on clk_ifc_avmm


    AvalonMM_int.Slave avmm
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int  NUM_PHYS = NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS + NUM_PHY_LOOPBACKS;
    localparam int  NUM_MACS = NUM_MAC_GMIIS + NUM_MAC_XGMIIS + NUM_MAC_AXIS + NUM_MAC_LOOPBACKS;

    localparam int  PHY_GMII_OFFSET = 0;
    localparam int  PHY_XGMII_OFFSET = PHY_GMII_OFFSET + NUM_PHY_GMIIS;
    localparam int  PHY_PPL_OFFSET = PHY_XGMII_OFFSET + NUM_PHY_XGMIIS;
    localparam int  PHY_LOOPBACK_OFFSET = PHY_PPL_OFFSET + NUM_PHY_PPLS;

    localparam int  MAC_GMII_OFFSET = 0;
    localparam int  MAC_XGMII_OFFSET = MAC_GMII_OFFSET + NUM_MAC_GMIIS;
    localparam int  MAC_AXIS_OFFSET = MAC_XGMII_OFFSET + NUM_MAC_XGMIIS;
    localparam int  MAC_LOOPBACK_OFFSET = MAC_AXIS_OFFSET + NUM_MAC_AXIS;

    localparam int  GMII_ETH_FIFO_ADDR_WIDTH        = $clog2(MAX_PKTSIZE) + 2;
    localparam int  XGMII_ETH_FIFO_ADDR_WIDTH       = $clog2(MAX_PKTSIZE) + 2;

    localparam int  PPL_NUM_LANES = ppl_ins[0][0][0].DATA_BYTES / 8;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT(MODULE_VERSION, 0);
    `ELAB_CHECK_GT(MODULE_ID, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic int_axis_clk;
    logic int_axis_sresetn;
    logic int_axis_sreset;

    logic [NUM_MACS-1:0] mac_fifo_tx_error_underflow;
    logic [NUM_MACS-1:0] mac_fifo_tx_fifo_overflow;
    logic [NUM_MACS-1:0] mac_fifo_tx_fifo_bad_frame;
    logic [NUM_MACS-1:0] mac_fifo_tx_fifo_good_frame;
    logic [NUM_MACS-1:0] mac_fifo_rx_error_bad_frame;
    logic [NUM_MACS-1:0] mac_fifo_rx_error_bad_fcs;
    logic [NUM_MACS-1:0] mac_fifo_rx_fifo_overflow;
    logic [NUM_MACS-1:0] mac_fifo_rx_fifo_bad_frame;
    logic [NUM_MACS-1:0] mac_fifo_rx_fifo_good_frame;

    logic [NUM_PHYS-1:0] phy_fifo_tx_error_underflow;
    logic [NUM_PHYS-1:0] phy_fifo_tx_fifo_overflow;
    logic [NUM_PHYS-1:0] phy_fifo_tx_fifo_bad_frame;
    logic [NUM_PHYS-1:0] phy_fifo_tx_fifo_good_frame;
    logic [NUM_PHYS-1:0] phy_fifo_rx_error_bad_frame;
    logic [NUM_PHYS-1:0] phy_fifo_rx_error_bad_fcs;
    logic [NUM_PHYS-1:0] phy_fifo_rx_fifo_overflow;
    logic [NUM_PHYS-1:0] phy_fifo_rx_fifo_bad_frame;
    logic [NUM_PHYS-1:0] phy_fifo_rx_fifo_good_frame;

    logic [NUM_MACS-1:0][$clog2(NUM_PHYS)-1:0] mac_phy_sel;
    logic [NUM_PHYS-1:0][$clog2(NUM_MACS)-1:0] phy_mac_sel;
    logic [NUM_MACS-1:0] mac_phy_sel_invalid;
    logic [NUM_PHYS-1:0] phy_mac_sel_invalid;

    logic [31:0] avmm_gpio_out [0:NUM_MACS-1];
    logic [31:0] avmm_gpio_in  [0:3];


    AXIS_int #(
        .DATA_BYTES(1)
    ) int_mac_axis_in [NUM_MACS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_mac_axis_out [NUM_MACS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phy_axis_in [NUM_PHYS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phy_axis_out [NUM_PHYS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );


    AXIS_int #(
        .DATA_BYTES(1)
    ) int_macphy_axis_in [NUM_MACS-1:0][NUM_PHYS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phymac_axis_in [NUM_PHYS-1:0][NUM_MACS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_macphy_axis_out [NUM_MACS-1:0][NUM_PHYS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phymac_axis_out [NUM_PHYS-1:0][NUM_MACS-1:0] (
        .clk     (  int_axis_clk),
        .sresetn (  int_axis_sresetn)
    );

    GMII_int  unused_mac_gmiis  [-1:0] ();
    GMII_int  unused_phy_gmiis  [-1:0] ();
    XGMII_int unused_mac_xgmiis [-1:0] ();
    XGMII_int unused_phy_xgmiis [-1:0] ();
    Clock_int unused_clk        [-1:0] ();
    Reset_int unused_sreset_ifc [-1:0] ();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    assign int_axis_clk     = clk_ifc_avmm.clk;
    assign int_axis_sresetn = ~(sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH);
    assign int_axis_sreset  = (sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH);


    assign avmm_gpio_in[0] = NUM_MACS;
    assign avmm_gpio_in[1] = NUM_PHYS;
    assign avmm_gpio_in[2] = mac_phy_sel_invalid;
    assign avmm_gpio_in[3] = phy_mac_sel_invalid;

    avmm_gpio #(
        .MODULE_VERSION      ( MODULE_VERSION ),
        .MODULE_ID           ( MODULE_ID      ),
        .DATALEN             ( 32             ),
        .NUM_INPUT_REGS      ( 4              ),
        .NUM_OUTPUT_REGS     ( NUM_MACS       ),
        .DEFAULT_OUTPUT_VALS ( '{default:'1}  )
    ) avmm_gpio_inst (
        .clk_ifc                 ( clk_ifc_avmm                 ),
        .peripheral_sreset_ifc   ( sreset_ifc_avmm_peripheral   ),
        .interconnect_sreset_ifc ( sreset_ifc_avmm_interconnect ),
        .avmm                    ( avmm                         ),
        .input_vals              ( avmm_gpio_in                 ),
        .output_vals             ( avmm_gpio_out                )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: MAC switch


    ethernet_to_axis #(
        .NUM_MAC_GMIIS       ( NUM_MAC_GMIIS        ),
        .NUM_MAC_XGMIIS      ( NUM_MAC_XGMIIS       ),
        .MAX_PKTSIZE         ( MAX_PKTSIZE          ),
        .MAC_GMII_ILA_MASK   ( MAC_GMII_ILA_MASK    )
    ) mac_eth_to_axis (
        .clk_ifc_mac_gmiis       ( clk_ifc_mac_gmiis     ),
        .sreset_ifc_mac_gmiis    ( sreset_ifc_mac_gmiis  ),
        .mac_gmiis               ( mac_gmiis             ),
        .sreset_ifc_mac_xgmiis   ( sreset_ifc_mac_xgmiis ),
        .clk_ifc_mac_xgmiis      ( clk_ifc_mac_xgmiis    ),
        .mac_xgmiis              ( mac_xgmiis            ),
        .clk_ifc_phy_gmiis       ( unused_clk            ),
        .sreset_ifc_phy_gmiis    ( unused_sreset_ifc     ),
        .phy_gmiis               ( unused_phy_gmiis      ),
        .phy_xgmiis              ( unused_phy_xgmiis     ),
        .ppl_outs                (  ),
        .ppl_ins                 (  ),

        .clk_ifc_axis            ( clk_ifc_avmm                 ),
        .sreset_ifc_axis         ( sreset_ifc_avmm_peripheral   ),
        .axis_tx                 ( int_mac_axis_in              ),
        .axis_rx                 ( int_mac_axis_out             ),

        .fifo_tx_error_underflow ( mac_fifo_tx_error_underflow  [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_tx_fifo_overflow   ( mac_fifo_tx_fifo_overflow    [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_tx_fifo_bad_frame  ( mac_fifo_tx_fifo_bad_frame   [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_tx_fifo_good_frame ( mac_fifo_tx_fifo_good_frame  [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_rx_error_bad_frame ( mac_fifo_rx_error_bad_frame  [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_rx_error_bad_fcs   ( mac_fifo_rx_error_bad_fcs    [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_rx_fifo_overflow   ( mac_fifo_rx_fifo_overflow    [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_rx_fifo_bad_frame  ( mac_fifo_rx_fifo_bad_frame   [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] ),
        .fifo_rx_fifo_good_frame ( mac_fifo_rx_fifo_good_frame  [NUM_MAC_GMIIS + NUM_MAC_XGMIIS - 1 : 0] )
    );

    generate

        for (genvar i = MAC_AXIS_OFFSET; i < MAC_AXIS_OFFSET+NUM_MAC_AXIS; i++) begin : gen_mac_axis

                localparam int idx = i - MAC_AXIS_OFFSET;

                axis_pipe_reg axis_connect_mac_axis_in (
                    .axis_in  ( mac_axis_ins[idx]  ),
                    .axis_out ( int_mac_axis_out[i] )
                );

                axis_pipe_reg axis_connect_mac__axis_out (
                    .axis_in  ( int_mac_axis_in[i] ),
                    .axis_out ( mac_axis_outs[idx]  )
                );

                assign mac_fifo_tx_error_underflow[i]= 1'b0;
                assign mac_fifo_tx_fifo_overflow  [i]= 1'b0;
                assign mac_fifo_tx_fifo_bad_frame [i]= 1'b0;
                assign mac_fifo_tx_fifo_good_frame[i]= 1'b0;
                assign mac_fifo_rx_error_bad_frame[i]= 1'b0;
                assign mac_fifo_rx_error_bad_fcs  [i]= 1'b0;
                assign mac_fifo_rx_fifo_overflow  [i]= 1'b0;
                assign mac_fifo_rx_fifo_bad_frame [i]= 1'b0;
                assign mac_fifo_rx_fifo_good_frame[i]= 1'b0;
        end

        for (genvar i = MAC_LOOPBACK_OFFSET; i < MAC_LOOPBACK_OFFSET+NUM_MAC_LOOPBACKS; i++) begin : gen_mac_loopback

            localparam int idx = i - MAC_LOOPBACK_OFFSET;

            axis_pipe_reg axis_connect_mac_loopback (
                .axis_in  ( int_mac_axis_in[i] ),
                .axis_out ( int_mac_axis_out[i] )
            );

            assign mac_fifo_tx_error_underflow[i]= 1'b0;
            assign mac_fifo_tx_fifo_overflow  [i]= 1'b0;
            assign mac_fifo_tx_fifo_bad_frame [i]= 1'b0;
            assign mac_fifo_tx_fifo_good_frame[i]= 1'b0;
            assign mac_fifo_rx_error_bad_frame[i]= 1'b0;
            assign mac_fifo_rx_error_bad_fcs  [i]= 1'b0;
            assign mac_fifo_rx_fifo_overflow  [i]= 1'b0;
            assign mac_fifo_rx_fifo_bad_frame [i]= 1'b0;
            assign mac_fifo_rx_fifo_good_frame[i]= 1'b0;
        end

        for (genvar i = 0; i < NUM_MACS; i++) begin : gen_mac_interface

            assign mac_phy_sel[i] = avmm_gpio_out[i];

            for (genvar k = 0; k < NUM_PHYS; k++) begin

                axis_connect axis_connect_phy_macs_in (
                    .axis_in  ( int_phymac_axis_in[k][i] ),
                    .axis_out ( int_macphy_axis_out[i][k] )
                );
                axis_connect axis_connect_phy_macs_out (
                    .axis_in  ( int_macphy_axis_in[i][k]),
                    .axis_out ( int_phymac_axis_out[k][i]  )
                );
            end

            axis_mux_kep #(.N(NUM_PHYS)
            ) mac_mux (
                .axis_in     (int_macphy_axis_out[i]   ),
                .axis_out    (int_mac_axis_in[i]   ),
                .sel         (mac_phy_sel[i]      ),
                .sel_invalid (mac_phy_sel_invalid[i])
            );

            axis_demux_kep #(.N(NUM_PHYS)
            ) mac_demux (
                .axis_in     (int_mac_axis_out[i]   ),
                .axis_out    (int_macphy_axis_in[i]   ),
                .sel         (mac_phy_sel[i]      ),
                .sel_invalid ()
            );
        end;
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PHY Switch


    ethernet_to_axis #(
        .NUM_PHY_PPLS        ( NUM_PHY_PPLS         ),
        .NUM_PHY_GMIIS       ( NUM_PHY_GMIIS        ),
        .NUM_PHY_XGMIIS      ( NUM_PHY_XGMIIS       ),
        .MAX_PKTSIZE         ( MAX_PKTSIZE          ),
        .PHY_GMII_ILA_MASK   ( PHY_GMII_ILA_MASK    ),
        .PHY_XGMII_ILA_MASK  ( PHY_XGMII_ILA_MASK   ),
        .PHY_PPL_ILA_MASK    ( PHY_PPL_ILA_MASK     )
    ) phy_eth_to_axis (
        .clk_ifc_mac_gmiis       ( unused_clk            ),
        .sreset_ifc_mac_gmiis    ( unused_sreset_ifc     ),
        .mac_gmiis               ( unused_phy_gmiis      ),
        .sreset_ifc_mac_xgmiis   ( unused_clk            ),
        .clk_ifc_mac_xgmiis      ( unused_sreset_ifc     ),
        .mac_xgmiis              ( unused_mac_xgmiis     ),
        .clk_ifc_phy_gmiis       ( clk_ifc_phy_gmiis     ),
        .sreset_ifc_phy_gmiis    ( sreset_ifc_phy_gmiis  ),
        .phy_gmiis               ( phy_gmiis             ),
        .phy_xgmiis              ( phy_xgmiis            ),
        .ppl_outs                ( ppl_outs              ),
        .ppl_ins                 ( ppl_ins               ),

        .clk_ifc_axis            ( clk_ifc_avmm                 ),
        .sreset_ifc_axis         ( sreset_ifc_avmm_peripheral   ),
        .axis_tx                 ( int_mac_axis_in              ),
        .axis_rx                 ( int_mac_axis_out             ),

        .fifo_tx_error_underflow ( phy_fifo_tx_error_underflow [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_tx_fifo_overflow   ( phy_fifo_tx_fifo_overflow   [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_tx_fifo_bad_frame  ( phy_fifo_tx_fifo_bad_frame  [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_tx_fifo_good_frame ( phy_fifo_tx_fifo_good_frame [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_rx_error_bad_frame ( phy_fifo_rx_error_bad_frame [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_rx_error_bad_fcs   ( phy_fifo_rx_error_bad_fcs   [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_rx_fifo_overflow   ( phy_fifo_rx_fifo_overflow   [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_rx_fifo_bad_frame  ( phy_fifo_rx_fifo_bad_frame  [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] ),
        .fifo_rx_fifo_good_frame ( phy_fifo_rx_fifo_good_frame [NUM_PHY_GMIIS + NUM_PHY_XGMIIS + NUM_PHY_PPLS -1 : 0] )
    );

    generate

        for (int k = PHY_LOOPBACK_OFFSET; k < PHY_LOOPBACK_OFFSET + NUM_PHY_LOOPBACKS; k++) begin gen_phy_loopback

            axis_pipe_reg  axis_connect_phy_loopback (
                .axis_in  ( int_phy_axis_in[k] ),
                .axis_out ( int_phy_axis_out[k] )
            );

            assign phy_fifo_tx_error_underflow[k] = 1'b0;
            assign phy_fifo_tx_fifo_overflow  [k] = 1'b0;
            assign phy_fifo_tx_fifo_bad_frame [k] = 1'b0;
            assign phy_fifo_tx_fifo_good_frame[k] = 1'b0;
            assign phy_fifo_rx_error_bad_frame[k] = 1'b0;
            assign phy_fifo_rx_error_bad_fcs  [k] = 1'b0;
            assign phy_fifo_rx_fifo_overflow  [k] = 1'b0;
            assign phy_fifo_rx_fifo_bad_frame [k] = 1'b0;
            assign phy_fifo_rx_fifo_good_frame[k] = 1'b0;

        end

        for (genvar k = 0; k < NUM_PHYS; k++) begin : gen_phy_interface

            axis_mux_kep #(.N(NUM_MACS)
            ) phy_mux (
                .axis_in     (int_phymac_axis_out[k]   ),
                .axis_out    (int_phy_axis_in[k]   ),
                .sel         (phy_mac_sel[k]      ),
                .sel_invalid (phy_mac_sel_invalid[k])
            );

            axis_demux_kep #(.N(NUM_MACS)
            ) phy_demux (
                .axis_in     (int_phy_axis_out[k]   ),
                .axis_out    (int_phymac_axis_in[k]   ),
                .sel         (phy_mac_sel[k]      ),
                .sel_invalid ()
            );
        end

    endgenerate


    always_ff @(posedge clk_ifc_avmm.clk) begin
        if(sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH) begin
            phy_mac_sel <= '0;
        end else begin
            for (int k = 0; k < NUM_PHYS; k++) begin
                for (int i = 0; i < NUM_MACS; i++) begin
                    if (mac_phy_sel[i] == k) begin
                        phy_mac_sel[k] <= i;
                    end else begin
                        phy_mac_sel[k] <= 0;
                    end
                end
            end
        end
    end


endmodule

`default_nettype wire
