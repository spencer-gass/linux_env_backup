// CONFIDENTIAL
// Copyright (c) 2025 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Ethernet point to multi-point broadcast interconnect.
 * Connects one Ethernet link to N other links.
 * Broadcast in the point to multi-point direction.
 * Round-robin in the multi-point to point direction.
 * This module handles GMII/XGMII translation to AXI streams
 * in both directions.
 **/
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
    // SUB-SECTION: clocks and resets


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


    GMII_int.Slave      mac_gmiis               [NUM_MAC_GMIIS-1:0],
    Clock_int.Input     clk_ifc_mac_gmiis       [NUM_MAC_GMIIS-1:0],
    Reset_int.ResetIn   sreset_ifc_mac_gmiis    [NUM_MAC_GMIIS-1:0],


    XGMII_int.Slave     mac_xgmiis              [NUM_MAC_XGMIIS-1:0],
    Clock_int.Input     clk_ifc_mac_xgmiis      [NUM_MAC_XGMIIS-1:0],
    Reset_int.ResetIn   sreset_ifc_mac_xgmiis   [NUM_MAC_XGMIIS-1:0],


    AXIS_int.Slave      mac_axis_ins            [NUM_MAC_AXIS-1:0],
    AXIS_int.Master     mac_axis_outs           [NUM_MAC_AXIS-1:0],


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


    generate
        for (genvar i = 0; i < NUM_MACS; i++) begin : gen_mac_interface


            assign mac_phy_sel[i] = avmm_gpio_out[i];


            if ( i >=  MAC_GMII_OFFSET && i < MAC_GMII_OFFSET + NUM_MAC_GMIIS ) begin : gen_gmii

                localparam int idx = i - MAC_GMII_OFFSET;

                //convert each GMII to AXIS

                eth_mac_1g_fifo #(
                    .AXIS_DATA_WIDTH    ( 8                           ),
                    .AXIS_KEEP_ENABLE   ( 0                           ),
                    .MIN_FRAME_LENGTH   ( 64                          ),
                    .ENABLE_PADDING     ( 1                           ),
                    .TX_FIFO_DEPTH      ( 2**GMII_ETH_FIFO_ADDR_WIDTH ),
                    .TX_FRAME_FIFO      ( 1                           ),
                    .TX_DROP_BAD_FRAME  ( 1                           ),
                    .TX_DROP_WHEN_FULL  ( 1                           ),
                    .RX_FIFO_DEPTH      ( 2**GMII_ETH_FIFO_ADDR_WIDTH ),
                    .RX_FRAME_FIFO      ( 1                           ),
                    .RX_DROP_BAD_FRAME  ( 1                           ),
                    .RX_DROP_WHEN_FULL  ( 1                           )
                ) gmii_mac_fifo (
                    .rx_clk             ( clk_ifc_mac_gmiis[idx].clk),
                    .rx_rst             ( sreset_ifc_mac_gmiis[idx].reset ),

                    .tx_clk             ( clk_ifc_mac_gmiis[idx].clk),
                    .tx_rst             ( sreset_ifc_mac_gmiis[idx].reset ),

                    .logic_clk          ( int_axis_clk),
                    .logic_rst          ( int_axis_sreset ),

                    .tx_axis_tdata      ( int_mac_axis_in[i].tdata  ),
                    .tx_axis_tkeep      ( '1                      ),
                    .tx_axis_tvalid     ( int_mac_axis_in[i].tvalid ),
                    .tx_axis_tready     ( int_mac_axis_in[i].tready ),
                    .tx_axis_tlast      ( int_mac_axis_in[i].tlast  ),
                    .tx_axis_tuser      ( int_mac_axis_in[i].tuser  ),

                    .rx_axis_tdata      ( int_mac_axis_out[i].tdata  ),
                    .rx_axis_tkeep      ( int_mac_axis_out[i].tkeep  ),
                    .rx_axis_tvalid     ( int_mac_axis_out[i].tvalid ),
                    .rx_axis_tready     ( int_mac_axis_out[i].tready ),
                    .rx_axis_tlast      ( int_mac_axis_out[i].tlast  ),
                    .rx_axis_tuser      ( int_mac_axis_out[i].tuser  ),

                    .gmii_rxd           ( mac_gmiis[idx].tx_d   ),
                    .gmii_rx_dv         ( mac_gmiis[idx].tx_en  ),
                    .gmii_rx_er         ( mac_gmiis[idx].tx_er  ),

                    .gmii_txd           ( mac_gmiis[idx].rx_d  ),
                    .gmii_tx_en         ( mac_gmiis[idx].rx_dv ),
                    .gmii_tx_er         ( mac_gmiis[idx].rx_er ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow (mac_fifo_tx_error_underflow[i]),
                    .tx_fifo_overflow   (mac_fifo_tx_fifo_overflow  [i]),
                    .tx_fifo_bad_frame  (mac_fifo_tx_fifo_bad_frame [i]),
                    .tx_fifo_good_frame (mac_fifo_tx_fifo_good_frame[i]),
                    .rx_error_bad_frame (mac_fifo_rx_error_bad_frame[i]),
                    .rx_error_bad_fcs   (mac_fifo_rx_error_bad_fcs  [i]),
                    .rx_fifo_overflow   (mac_fifo_rx_fifo_overflow  [i]),
                    .rx_fifo_bad_frame  (mac_fifo_rx_fifo_bad_frame [i]),
                    .rx_fifo_good_frame (mac_fifo_rx_fifo_good_frame[i])
                );

                // Unused
                assign int_mac_axis_out[i].tstrb = '1;
                assign int_mac_axis_out[i].tid   = '0;
                assign int_mac_axis_out[i].tdest = '0;

                if (MAC_GMII_ILA_MASK[idx]) begin : gen_mac_ila
                    ila_debug gmii_ila (
                        .clk    ( int_axis_clk  ),
                        .probe0 ( {int_mac_axis_in[i].tdata,   int_mac_axis_in[i].tkeep} ),
                        .probe1 ( {int_mac_axis_in[i].tvalid,   int_mac_axis_in[i].tready} ),
                        .probe2 ( {int_mac_axis_in[i].tuser,    int_mac_axis_in[i].tlast}  ),
                        .probe3 ( {int_mac_axis_out[i].tdata,  int_mac_axis_out[i].tkeep} ),
                        .probe4 ( {int_mac_axis_out[i].tvalid, int_mac_axis_out[i].tready} ),
                        .probe5 ( {int_mac_axis_out[i].tlast,  int_mac_axis_out[i].tuser} ),
                        .probe6( {int_axis_sreset } ),
                        .probe7( {mac_gmiis[idx].tx_d, mac_gmiis[idx].tx_en, mac_gmiis[idx].tx_er} ),
                        .probe8( {mac_gmiis[idx].rx_d, mac_gmiis[idx].rx_dv, mac_gmiis[idx].rx_er} ),
                        .probe9( {  mac_fifo_tx_error_underflow[i], mac_fifo_tx_fifo_overflow[i], mac_fifo_tx_fifo_bad_frame[i],
                                    mac_fifo_tx_fifo_good_frame[i], mac_fifo_rx_error_bad_frame[i], mac_fifo_rx_error_bad_fcs[i],
                                    mac_fifo_rx_fifo_overflow[i], mac_fifo_rx_fifo_bad_frame[i], mac_fifo_rx_fifo_good_frame[i]
                                  }  ),
                        .probe10( {mac_phy_sel[i]} ),
                        .probe11( {mac_phy_sel_invalid[i]} ),
                        .probe12( {phy_mac_sel} ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end

            end else if ( i >=  MAC_XGMII_OFFSET && i < MAC_XGMII_OFFSET + NUM_MAC_XGMIIS ) begin : gen_xgmii

                localparam int idx = i - MAC_XGMII_OFFSET;

                eth_mac_10g_fifo #(
                    .DATA_WIDTH         (64),
                    .CTRL_WIDTH         (64/8),
                    .AXIS_DATA_WIDTH    ( 8                           ),
                    .AXIS_KEEP_ENABLE   ( 0                           ),
                    .ENABLE_PADDING     ( 1                           ),
                    .MIN_FRAME_LENGTH   ( 64                          ),
                    .TX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH ),
                    .TX_FRAME_FIFO      ( 1                           ),
                    .TX_DROP_BAD_FRAME  ( 1                           ),
                    .TX_DROP_WHEN_FULL  ( 1                           ),
                    .RX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH ),
                    .RX_FRAME_FIFO      ( 1                           ),
                    .RX_DROP_BAD_FRAME  ( 1                           ),
                    .RX_DROP_WHEN_FULL  ( 1                           )
                ) xgmii_mac_fifo (
                    .rx_clk             ( clk_ifc_mac_xgmiis[idx].clk),
                    .rx_rst             ( sreset_ifc_mac_xgmiis[idx].reset ),

                    .tx_clk             ( clk_ifc_mac_xgmiis[idx].clk),
                    .tx_rst             ( sreset_ifc_mac_xgmiis[idx].reset ),

                    .logic_clk          ( int_axis_clk),
                    .logic_rst          ( int_axis_sreset ),


                    .ptp_sample_clk     ( 1'b0),

                    .tx_axis_tdata      ( int_mac_axis_in[i].tdata  ),
                    .tx_axis_tkeep      ( '1                      ),
                    .tx_axis_tvalid     ( int_mac_axis_in[i].tvalid ),
                    .tx_axis_tready     ( int_mac_axis_in[i].tready ),
                    .tx_axis_tlast      ( int_mac_axis_in[i].tlast  ),
                    .tx_axis_tuser      ( int_mac_axis_in[i].tuser  ),

                    .s_axis_tx_ptp_ts_tag  ('0),
                    .s_axis_tx_ptp_ts_valid(1'b0),
                    .s_axis_tx_ptp_ts_ready(),

                    .m_axis_tx_ptp_ts_96   (),
                    .m_axis_tx_ptp_ts_tag  (),
                    .m_axis_tx_ptp_ts_valid(),
                    .m_axis_tx_ptp_ts_ready(1'b0),
                    .m_axis_rx_ptp_ts_96   (),
                    .m_axis_rx_ptp_ts_valid(),
                    .m_axis_rx_ptp_ts_ready(1'b0),

                    .ptp_ts_96          ('0),

                    .rx_axis_tdata      ( int_mac_axis_out[i].tdata  ),
                    .rx_axis_tkeep      ( int_mac_axis_out[i].tkeep  ),
                    .rx_axis_tvalid     ( int_mac_axis_out[i].tvalid ),
                    .rx_axis_tready     ( int_mac_axis_out[i].tready ),
                    .rx_axis_tlast      ( int_mac_axis_out[i].tlast  ),
                    .rx_axis_tuser      ( int_mac_axis_out[i].tuser  ),

                    .xgmii_rxd           ( mac_xgmiis[idx].txd   ),
                    .xgmii_rxc         ( mac_xgmiis[idx].txc  ),

                    .xgmii_txd           ( mac_xgmiis[idx].rxd  ),
                    .xgmii_txc         ( mac_xgmiis[idx].rxc ),


                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow (mac_fifo_tx_error_underflow[i]),
                    .tx_fifo_overflow   (mac_fifo_tx_fifo_overflow  [i]),
                    .tx_fifo_bad_frame  (mac_fifo_tx_fifo_bad_frame [i]),
                    .tx_fifo_good_frame (mac_fifo_tx_fifo_good_frame[i]),
                    .rx_error_bad_frame (mac_fifo_rx_error_bad_frame[i]),
                    .rx_error_bad_fcs   (mac_fifo_rx_error_bad_fcs  [i]),
                    .rx_fifo_overflow   (mac_fifo_rx_fifo_overflow  [i]),
                    .rx_fifo_bad_frame  (mac_fifo_rx_fifo_bad_frame [i]),
                    .rx_fifo_good_frame (mac_fifo_rx_fifo_good_frame[i])
                );

                assign int_mac_axis_out[i].tstrb = '1;
                assign int_mac_axis_out[i].tid   = '0;
                assign int_mac_axis_out[i].tdest = '0;


            end else if ( i >=  MAC_AXIS_OFFSET && i < MAC_AXIS_OFFSET + NUM_MAC_AXIS ) begin : gen_axis

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

            end else if ( i >=  MAC_LOOPBACK_OFFSET && i < MAC_LOOPBACK_OFFSET + NUM_MAC_LOOPBACKS ) begin : gen_loopback

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

        end



    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: PHY Switch


        for (genvar k = 0; k < NUM_PHYS; k++) begin : gen_phy_interface

            if ( k >=  PHY_GMII_OFFSET && k < PHY_GMII_OFFSET + NUM_PHY_GMIIS ) begin : gen_gmii

                localparam int idx = k - PHY_GMII_OFFSET;


                eth_mac_1g_fifo #(
                    .AXIS_DATA_WIDTH    ( 8                           ),
                    .AXIS_KEEP_ENABLE   ( 0                           ),
                    .MIN_FRAME_LENGTH   ( 64                          ),
                    .ENABLE_PADDING     ( 1                           ),
                    .TX_FIFO_DEPTH      ( 2**GMII_ETH_FIFO_ADDR_WIDTH ),
                    .TX_FRAME_FIFO      ( 1                           ),
                    .TX_DROP_BAD_FRAME  ( 1                           ),
                    .TX_DROP_WHEN_FULL  ( 1                           ),
                    .RX_FIFO_DEPTH      ( 2**GMII_ETH_FIFO_ADDR_WIDTH ),
                    .RX_FRAME_FIFO      ( 1                           ),
                    .RX_DROP_BAD_FRAME  ( 1                           ),
                    .RX_DROP_WHEN_FULL  ( 1                           )
                ) gmii_phy_fifo (
                    .rx_clk             ( clk_ifc_phy_gmiis[idx].clk),
                    .rx_rst             ( sreset_ifc_phy_gmiis[idx].reset ),

                    .tx_clk             ( clk_ifc_phy_gmiis[idx].clk),
                    .tx_rst             ( sreset_ifc_phy_gmiis[idx].reset ),

                    .logic_clk          ( int_axis_clk),
                    .logic_rst          ( int_axis_sreset ),

                    .tx_axis_tdata      ( int_phy_axis_in[k].tdata  ),
                    .tx_axis_tkeep      ( '1                ),
                    .tx_axis_tvalid     ( int_phy_axis_in[k].tvalid ),
                    .tx_axis_tready     ( int_phy_axis_in[k].tready ),
                    .tx_axis_tlast      ( int_phy_axis_in[k].tlast  ),
                    .tx_axis_tuser      ( int_phy_axis_in[k].tuser  ),

                    .rx_axis_tdata      ( int_phy_axis_out[k].tdata  ),
                    .rx_axis_tkeep      ( int_phy_axis_out[k].tkeep  ),
                    .rx_axis_tvalid     ( int_phy_axis_out[k].tvalid ),
                    .rx_axis_tready     ( int_phy_axis_out[k].tready ),
                    .rx_axis_tlast      ( int_phy_axis_out[k].tlast  ),
                    .rx_axis_tuser      ( int_phy_axis_out[k].tuser  ),

                    .gmii_rxd           ( phy_gmiis[idx].rx_d   ),
                    .gmii_rx_dv         ( phy_gmiis[idx].rx_dv  ),
                    .gmii_rx_er         ( phy_gmiis[idx].rx_er  ),

                    .gmii_txd           ( phy_gmiis[idx].tx_d  ),
                    .gmii_tx_en         ( phy_gmiis[idx].tx_en ),
                    .gmii_tx_er         ( phy_gmiis[idx].tx_er ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow (phy_fifo_tx_error_underflow[k]),
                    .tx_fifo_overflow   (phy_fifo_tx_fifo_overflow  [k]),
                    .tx_fifo_bad_frame  (phy_fifo_tx_fifo_bad_frame [k]),
                    .tx_fifo_good_frame (phy_fifo_tx_fifo_good_frame[k]),
                    .rx_error_bad_frame (phy_fifo_rx_error_bad_frame[k]),
                    .rx_error_bad_fcs   (phy_fifo_rx_error_bad_fcs  [k]),
                    .rx_fifo_overflow   (phy_fifo_rx_fifo_overflow  [k]),
                    .rx_fifo_bad_frame  (phy_fifo_rx_fifo_bad_frame [k]),
                    .rx_fifo_good_frame (phy_fifo_rx_fifo_good_frame[k])
                );

                // Unused
                assign int_phy_axis_out[k].tstrb = '1;
                assign int_phy_axis_out[k].tid   = '0;
                assign int_phy_axis_out[k].tdest = '0;

                if (PHY_GMII_ILA_MASK[idx]) begin : gen_phy_ila
                    ila_debug gmii_ila (
                        .clk    ( int_axis_clk  ),
                        .probe0 ( {int_phy_axis_in[k].tdata,   int_phy_axis_in[k].tkeep} ),
                        .probe1 ( {int_phy_axis_in[k].tvalid,   int_phy_axis_in[k].tready} ),
                        .probe2 ( {int_phy_axis_in[k].tuser,    int_phy_axis_in[k].tlast}  ),
                        .probe3 ( {int_phy_axis_out[k].tdata,  int_phy_axis_out[k].tkeep} ),
                        .probe4 ( {int_phy_axis_out[k].tvalid, int_phy_axis_out[k].tready} ),
                        .probe5 ( {int_phy_axis_out[k].tlast,  int_phy_axis_out[k].tuser} ),
                        .probe6( {int_axis_sreset } ),
                        .probe7( {phy_gmiis[idx].tx_d, phy_gmiis[idx].tx_en, phy_gmiis[idx].tx_er} ),
                        .probe8( {phy_gmiis[idx].rx_d, phy_gmiis[idx].rx_dv, phy_gmiis[idx].rx_er} ),
                        .probe9( {  phy_fifo_tx_error_underflow[k], phy_fifo_tx_fifo_overflow[k], phy_fifo_tx_fifo_bad_frame[k],
                                    phy_fifo_tx_fifo_good_frame[k], phy_fifo_rx_error_bad_frame[k], phy_fifo_rx_error_bad_fcs[k],
                                    phy_fifo_rx_fifo_overflow[k], phy_fifo_rx_fifo_bad_frame[k], phy_fifo_rx_fifo_good_frame[k]
                                  }  ),
                        .probe10( {phy_mac_sel[k]} ),
                        .probe11( {phy_mac_sel_invalid[k]} ),
                        .probe12( {mac_phy_sel} ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end


            end else if ( k >=  PHY_XGMII_OFFSET && k < PHY_XGMII_OFFSET + NUM_PHY_XGMIIS ) begin : gen_xgmii

                localparam int idx = k - PHY_XGMII_OFFSET;


                eth_mac_10g_fifo #(
                    .DATA_WIDTH         (64),
                    .CTRL_WIDTH         (64/8),
                    .AXIS_DATA_WIDTH    ( 8                           ),
                    .AXIS_KEEP_ENABLE   ( 0                           ),
                    .ENABLE_PADDING     ( 1                           ),
                    .MIN_FRAME_LENGTH   ( 64                          ),
                    .TX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH ),
                    .TX_FRAME_FIFO      ( 1                           ),
                    .TX_DROP_BAD_FRAME  ( 1                           ),
                    .TX_DROP_WHEN_FULL  ( 1                           ),
                    .RX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH ),
                    .RX_FRAME_FIFO      ( 1                           ),
                    .RX_DROP_BAD_FRAME  ( 1                           ),
                    .RX_DROP_WHEN_FULL  ( 1                           )
                ) xgmii_phy_fifo (
                    .rx_clk             ( phy_xgmiis[idx].rx_clk),
                    .rx_rst             ( phy_xgmiis[idx].rx_sreset ),

                    .tx_clk             ( phy_xgmiis[idx].tx_clk),
                    .tx_rst             ( phy_xgmiis[idx].tx_sreset ),

                    .logic_clk          ( int_axis_clk),
                    .logic_rst          ( int_axis_sreset ),


                    .ptp_sample_clk     ( 1'b0),

                    .tx_axis_tdata      ( int_phy_axis_in[k].tdata  ),
                    .tx_axis_tkeep      ( '1       ),
                    .tx_axis_tvalid     ( int_phy_axis_in[k].tvalid ),
                    .tx_axis_tready     ( int_phy_axis_in[k].tready ),
                    .tx_axis_tlast      ( int_phy_axis_in[k].tlast  ),
                    .tx_axis_tuser      ( int_phy_axis_in[k].tuser  ),

                    .s_axis_tx_ptp_ts_tag  ('0),
                    .s_axis_tx_ptp_ts_valid(1'b0),
                    .s_axis_tx_ptp_ts_ready(),

                    .m_axis_tx_ptp_ts_96   (),
                    .m_axis_tx_ptp_ts_tag  (),
                    .m_axis_tx_ptp_ts_valid(),
                    .m_axis_tx_ptp_ts_ready(1'b0),
                    .m_axis_rx_ptp_ts_96   (),
                    .m_axis_rx_ptp_ts_valid(),
                    .m_axis_rx_ptp_ts_ready(1'b0),

                    .ptp_ts_96          ('0),

                    .rx_axis_tdata      ( int_phy_axis_out[k].tdata  ),
                    .rx_axis_tkeep      ( int_phy_axis_out[k].tkeep  ),
                    .rx_axis_tvalid     ( int_phy_axis_out[k].tvalid ),
                    .rx_axis_tready     ( int_phy_axis_out[k].tready ),
                    .rx_axis_tlast      ( int_phy_axis_out[k].tlast  ),
                    .rx_axis_tuser      ( int_phy_axis_out[k].tuser  ),

                    .xgmii_rxd           ( phy_xgmiis[idx].rxd   ),
                    .xgmii_rxc           ( phy_xgmiis[idx].rxc  ),

                    .xgmii_txd           ( phy_xgmiis[idx].txd  ),
                    .xgmii_txc           ( phy_xgmiis[idx].txc ),


                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow (phy_fifo_tx_error_underflow[k]),
                    .tx_fifo_overflow   (phy_fifo_tx_fifo_overflow  [k]),
                    .tx_fifo_bad_frame  (phy_fifo_tx_fifo_bad_frame [k]),
                    .tx_fifo_good_frame (phy_fifo_tx_fifo_good_frame[k]),
                    .rx_error_bad_frame (phy_fifo_rx_error_bad_frame[k]),
                    .rx_error_bad_fcs   (phy_fifo_rx_error_bad_fcs  [k]),
                    .rx_fifo_overflow   (phy_fifo_rx_fifo_overflow  [k]),
                    .rx_fifo_bad_frame  (phy_fifo_rx_fifo_bad_frame [k]),
                    .rx_fifo_good_frame (phy_fifo_rx_fifo_good_frame[k])
                );


                assign int_phy_axis_out[k].tstrb = '1;
                assign int_phy_axis_out[k].tid   = '0;
                assign int_phy_axis_out[k].tdest = '0;


                if (PHY_XGMII_ILA_MASK[idx]) begin : gen_phy_ila
                    ila_debug xgmii_ila (
                        .clk    ( int_axis_clk  ),
                        .probe0 ( {int_phy_axis_in[k].tdata} ),
                        .probe1 ( {int_phy_axis_in[k].tvalid,   int_phy_axis_in[k].tready, int_phy_axis_in[k].tkeep} ),
                        .probe2 ( {int_phy_axis_in[k].tuser,    int_phy_axis_in[k].tlast}  ),
                        .probe3 ( {int_phy_axis_out[k].tdata } ),
                        .probe4 ( {int_phy_axis_out[k].tvalid, int_phy_axis_out[k].tready, int_phy_axis_out[k].tkeep} ),
                        .probe5 ( {int_phy_axis_out[k].tlast,  int_phy_axis_out[k].tuser} ),
                        .probe6( {int_axis_sreset } ),
                        .probe7( {phy_xgmiis[idx].txd[31:0]}),
                        .probe8( {phy_xgmiis[idx].txd[63:32]}),
                        .probe9( {phy_xgmiis[idx].rxd[31:0]}),
                        .probe10( {phy_xgmiis[idx].rxd[63:32]}),
                        .probe11( {phy_xgmiis[idx].txc}),
                        .probe12( {phy_xgmiis[idx].rxc}),
                        .probe13( {  phy_fifo_tx_error_underflow[k], phy_fifo_tx_fifo_overflow[k], phy_fifo_tx_fifo_bad_frame[k],
                                    phy_fifo_tx_fifo_good_frame[k], phy_fifo_rx_error_bad_frame[k], phy_fifo_rx_error_bad_fcs[k],
                                    phy_fifo_rx_fifo_overflow[k], phy_fifo_rx_fifo_bad_frame[k], phy_fifo_rx_fifo_good_frame[k]
                                  }  ),
                        .probe14( {phy_mac_sel[k]} ),
                        .probe15( {phy_mac_sel_invalid[k]} )
                    );
                end

            end else if ( k >=  PHY_PPL_OFFSET && k < PHY_PPL_OFFSET + NUM_PHY_PPLS ) begin : gen_ppl

                localparam int idx = k - PHY_PPL_OFFSET;

                AXIS_int #(
                    .DATA_BYTES(8 * PPL_NUM_LANES)
                ) ppl_ins_i [0:0][0:0][0:0] (
                    .clk     (  ppl_ins[0][idx][0].clk),
                    .sresetn (  ppl_ins[0][idx][0].sresetn)
                );

                AXIS_int #(
                    .DATA_BYTES(8 * PPL_NUM_LANES)
                ) ppl_outs_i [0:0][0:0][0:0] (
                    .clk     (  ppl_outs[0][idx][0].clk),
                    .sresetn (  ppl_outs[0][idx][0].sresetn)
                );


                axis_connect ppl_ins_i_con (
                    .axis_in  ( ppl_ins[0][idx][0] ),
                    .axis_out ( ppl_ins_i[0][0][0] )
                );

                axis_connect ppl_outs_i_con (
                    .axis_in  ( ppl_outs_i[0][0][0] ),
                    .axis_out ( ppl_outs[0][idx][0] )
                );


                ethernet_ppl_fifo #(
                    .ENABLE_PPL   (1'b1       ),
                    .MAX_PKTSIZE  (MAX_PKTSIZE),
                    .DEBUG_ILA    (PHY_PPL_ILA_MASK[idx]  ),
                    .NUM_LANES    (PPL_NUM_LANES),
                    .NUM_CHANNELS (1          ),
                    .NUM_QUADS    (1          ),
                    .NUM_STREAMS  (1          )
                ) ethernet_ppl_fifo_phy (
                    .clk_eth_ifc    (clk_ifc_avmm             ),
                    .sreset_eth_ifc (sreset_ifc_avmm_peripheral          ),
                    .eth_sink       (int_phy_axis_in[k:k]     ),
                    .eth_src        (int_phy_axis_out[k:k]    ),
                    .ppl_axis_tx    (ppl_outs_i),
                    .ppl_axis_rx    (ppl_ins_i )
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


            end else if ( k >=  PHY_LOOPBACK_OFFSET && k < PHY_LOOPBACK_OFFSET + NUM_PHY_LOOPBACKS ) begin : gen_loopback

                localparam int idx = k - PHY_XGMII_OFFSET;


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

/*
    axis_broadcast_wrapper #(
        .N ( N )
    ) point_to_multipoint_broadcast (
        axis_in  ( axis_point_in        ),
        axis_out ( axis_multipoint_out  )
    );

    axis_arb_mux_wrapper #(
        .N          ( N             ),
        .ARB_TYPE   ( "ROUND_ROBIN" ),
    ) multipoint_to_point_arb_mux (
        .axis_in        ( axis_multipoint_in ),
        .axis_out       ( axis_point_out     ),
        .grant          (  ),
        .grant_valid    (  ),
        .grant_encoded  (  )
    );
*/
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
