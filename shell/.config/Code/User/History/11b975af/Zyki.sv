// CONFIDENTIAL
// Copyright (c) 2025 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module converts a configurable number of GMII/XGMII interfaces to AXI streams for both tx and rx directions.
 */
module ethernet_to_axis
#(
    parameter  bit [15:0]               MODULE_VERSION      = 0,
    parameter  bit [15:0]               MODULE_ID           = 0,
    parameter  int                      NUM_MAC_GMIIS       = 0,  // number of XGMII interfaces towards MAC 1G/2.5G
    parameter  int                      NUM_MAC_XGMIIS      = 0,  // number of XGMII interfaces towards MAC 10G
    parameter  int                      NUM_PHY_PPLS        = 0,  // number of 64-bit PPL AXI streams
    parameter  int                      NUM_PHY_GMIIS       = 0,  // number of GMII interfaces towards PHY (PCS/PMA) 1G/2.5G
    parameter  int                      NUM_PHY_XGMIIS      = 0,  // number of XGMII interfaces towards PHY (PCS/PMA) 10G
    localparam int                      NUM_AXIS            = NUM_MAC_GMIIS
                                                            + NUM_MAC_XGMIIS
                                                            + NUM_PHY_GMIIS
                                                            + NUM_PHY_XGMIIS
                                                            + NUM_PHY_PPLS,
    parameter  int                      MAX_PKTSIZE         = 8192,
    parameter  bit [NUM_MAC_GMIIS-1:0]  MAC_GMII_ILA_MASK   = '0,
    parameter  bit [NUM_PHY_GMIIS-1:0]  PHY_GMII_ILA_MASK   = '0,
    parameter  bit [NUM_PHY_XGMIIS-1:0] PHY_XGMII_ILA_MASK  = '0,
    parameter  bit [NUM_PHY_PPLS-1:0]   PHY_PPL_ILA_MASK    = '0
) (


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Interfaces


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ethernet Interfaces Towards PHYs


    AXIS_int.Slave      ppl_ins                 [0:0][NUM_PHY_PPLS-1:0][0:0],
    AXIS_int.Master     ppl_outs                [0:0][NUM_PHY_PPLS-1:0][0:0],

    Clock_int.Input     clk_ifc_phy_gmiis       [NUM_PHY_GMIIS-1:0],
    Reset_int.ResetIn   sreset_ifc_phy_gmiis    [NUM_PHY_GMIIS-1:0],
    GMII_int.Master     phy_gmiis               [NUM_PHY_GMIIS-1:0],

    XGMII_int.Master    phy_xgmiis              [NUM_PHY_XGMIIS-1:0],


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ethernet Interfaces Towards MACs


    Clock_int.Input     clk_ifc_mac_gmiis       [NUM_MAC_GMIIS-1:0],
    Reset_int.ResetIn   sreset_ifc_mac_gmiis    [NUM_MAC_GMIIS-1:0],
    GMII_int.Slave      mac_gmiis               [NUM_MAC_GMIIS-1:0],

    Reset_int.ResetIn   sreset_ifc_mac_xgmiis   [NUM_MAC_XGMIIS-1:0],
    Clock_int.Input     clk_ifc_mac_xgmiis      [NUM_MAC_XGMIIS-1:0],
    XGMII_int.Slave     mac_xgmiis              [NUM_MAC_XGMIIS-1:0],


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces Towards System


    Clock_int.Input     clk_ifc_axis            [NUM_MAC_GMIIS-1:0],
    Reset_int.ResetIn   sreset_ifc_axis         [NUM_MAC_GMIIS-1:0],
    AXIS_int.Slave      axis_tx                 [NUM_AXIS-1:0],
    AXIS_int.Master     axis_rx                 [NUM_AXIS-1:0]


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Fifo Status


    output var logic [NUM_AXIS-1:0] fifo_tx_error_underflow,
    output var logic [NUM_AXIS-1:0] fifo_tx_fifo_overflow,
    output var logic [NUM_AXIS-1:0] fifo_tx_fifo_bad_frame,
    output var logic [NUM_AXIS-1:0] fifo_tx_fifo_good_frame,
    output var logic [NUM_AXIS-1:0] fifo_rx_error_bad_frame,
    output var logic [NUM_AXIS-1:0] fifo_rx_error_bad_fcs,
    output var logic [NUM_AXIS-1:0] fifo_rx_fifo_overflow,
    output var logic [NUM_AXIS-1:0] fifo_rx_fifo_bad_frame,
    output var logic [NUM_AXIS-1:0] fifo_rx_fifo_good_frame
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int  MAC_GMII_OFFSET  = 0;
    localparam int  MAC_XGMII_OFFSET = MAC_GMII_OFFSET + NUM_MAC_GMIIS;

    localparam int  PHY_GMII_OFFSET  = MAC_XGMII_OFFSET + NUM_MAC_XGMIIS;
    localparam int  PHY_XGMII_OFFSET = PHY_GMII_OFFSET  + NUM_PHY_GMIIS;
    localparam int  PHY_PPL_OFFSET   = PHY_XGMII_OFFSET + NUM_PHY_XGMIIS;

    localparam int  GMII_ETH_FIFO_ADDR_WIDTH  = $clog2(MAX_PKTSIZE) + 2;
    localparam int  XGMII_ETH_FIFO_ADDR_WIDTH = $clog2(MAX_PKTSIZE) + 2;

    localparam int  PPL_NUM_LANES = ppl_ins[0][0][0].DATA_BYTES / 8;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT(MODULE_VERSION, 0);
    `ELAB_CHECK_GT(MODULE_ID, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic int_axis_sresetn;
    logic int_axis_sreset;

    logic [31:0] avmm_gpio_out [0:NUM_MACS-1];
    logic [31:0] avmm_gpio_in  [0:3];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    //TODO(sgass) add either counters or sticky bits for fifo status

    assign int_axis_sresetn = ~(sreset_ifc_axis.reset == sreset_ifc_axis.ACTIVE_HIGH);
    assign int_axis_sreset  =  (sreset_ifc_axis.reset == sreset_ifc_axis.ACTIVE_HIGH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Ethernet to Axis Conversion


    generate
        for (genvar axis_idx = 0; axis_idx < NUM_AXIS; axis_idx++) begin : gen_interfaces

            if ( axis_idx >=  MAC_GMII_OFFSET && axis_idx < MAC_GMII_OFFSET + NUM_MAC_GMIIS ) begin : gen_mac_gmii

                localparam int mac_gmii_idx = axis_idx - MAC_GMII_OFFSET;

                eth_mac_1g_fifo #(
                    .AXIS_DATA_WIDTH    ( 8 * axis_tx[0].DATA_BYTES   ),
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
                    .rx_clk             ( clk_ifc_mac_gmiis[mac_gmii_idx].clk       ),
                    .rx_rst             ( sreset_ifc_mac_gmiis[mac_gmii_idx].reset  ),
                    .tx_clk             ( clk_ifc_mac_gmiis[mac_gmii_idx].clk       ),
                    .tx_rst             ( sreset_ifc_mac_gmiis[mac_gmii_idx].reset  ),
                    .logic_clk          ( clk_ifc_axis.clk                          ),
                    .logic_rst          ( int_axis_sreset                           ),

                    .tx_axis_tdata      ( axis_tx[axis_idx].tdata   ),
                    .tx_axis_tkeep      ( '1                        ),
                    .tx_axis_tvalid     ( axis_tx[axis_idx].tvalid  ),
                    .tx_axis_tready     ( axis_tx[axis_idx].tready  ),
                    .tx_axis_tlast      ( axis_tx[axis_idx].tlast   ),
                    .tx_axis_tuser      ( axis_tx[axis_idx].tuser   ),

                    .rx_axis_tdata      ( axis_rx[axis_idx].tdata   ),
                    .rx_axis_tkeep      ( axis_rx[axis_idx].tkeep   ),
                    .rx_axis_tvalid     ( axis_rx[axis_idx].tvalid  ),
                    .rx_axis_tready     ( axis_rx[axis_idx].tready  ),
                    .rx_axis_tlast      ( axis_rx[axis_idx].tlast   ),
                    .rx_axis_tuser      ( axis_rx[axis_idx].tuser   ),

                    .gmii_rxd           ( mac_gmiis[mac_gmii_idx].tx_d  ),
                    .gmii_rx_dv         ( mac_gmiis[mac_gmii_idx].tx_en ),
                    .gmii_rx_er         ( mac_gmiis[mac_gmii_idx].tx_er ),

                    .gmii_txd           ( mac_gmiis[mac_gmii_idx].rx_d  ),
                    .gmii_tx_en         ( mac_gmiis[mac_gmii_idx].rx_dv ),
                    .gmii_tx_er         ( mac_gmiis[mac_gmii_idx].rx_er ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow ( fifo_tx_error_underflow[axis_idx] ),
                    .tx_fifo_overflow   ( fifo_tx_fifo_overflow  [axis_idx] ),
                    .tx_fifo_bad_frame  ( fifo_tx_fifo_bad_frame [axis_idx] ),
                    .tx_fifo_good_frame ( fifo_tx_fifo_good_frame[axis_idx] ),
                    .rx_error_bad_frame ( fifo_rx_error_bad_frame[axis_idx] ),
                    .rx_error_bad_fcs   ( fifo_rx_error_bad_fcs  [axis_idx] ),
                    .rx_fifo_overflow   ( fifo_rx_fifo_overflow  [axis_idx] ),
                    .rx_fifo_bad_frame  ( fifo_rx_fifo_bad_frame [axis_idx] ),
                    .rx_fifo_good_frame ( fifo_rx_fifo_good_frame[axis_idx] )
                );

                // Unused
                assign axis_rx[axis_idx].tstrb = '1;
                assign axis_rx[axis_idx].tid   = '0;
                assign axis_rx[axis_idx].tdest = '0;

                if (MAC_GMII_ILA_MASK[mac_gmii_idx]) begin : gen_gmii_mac_ila
                    ila_debug gmii_ila (
                        .clk    ( clk_ifc_axis.clk  ),
                        .probe0 ( {axis_tx[axis_idx].tdata,  axis_tx[axis_idx].tkeep}   ),
                        .probe1 ( {axis_tx[axis_idx].tvalid, axis_tx[axis_idx].tready}  ),
                        .probe2 ( {axis_tx[axis_idx].tuser,  axis_tx[axis_idx].tlast}   ),
                        .probe3 ( {axis_rx[axis_idx].tdata,  axis_rx[axis_idx].tkeep}   ),
                        .probe4 ( {axis_rx[axis_idx].tvalid, axis_rx[axis_idx].tready}  ),
                        .probe5 ( {axis_rx[axis_idx].tlast,  axis_rx[axis_idx].tuser}   ),
                        .probe6 ( {int_axis_sreset } ),
                        .probe7 ( {mac_gmiis[mac_gmii_idx].tx_d, mac_gmiis[mac_gmii_idx].tx_en, mac_gmiis[mac_gmii_idx].tx_er} ),
                        .probe8 ( {mac_gmiis[mac_gmii_idx].rx_d, mac_gmiis[mac_gmii_idx].rx_dv, mac_gmiis[mac_gmii_idx].rx_er} ),
                        .probe9 ( {  fifo_tx_error_underflow[axis_idx],
                                     fifo_tx_fifo_overflow[axis_idx],
                                     fifo_tx_fifo_bad_frame[axis_idx],
                                     fifo_tx_fifo_good_frame[axis_idx],
                                     fifo_rx_error_bad_frame[axis_idx],
                                     fifo_rx_error_bad_fcs[axis_idx],
                                     fifo_rx_fifo_overflow[axis_idx],
                                     fifo_rx_fifo_bad_frame[axis_idx],
                                     fifo_rx_fifo_good_frame[axis_idx]
                                  }  ),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end

            end else if ( axis_idx >=  MAC_XGMII_OFFSET && axis_idx < MAC_XGMII_OFFSET + NUM_MAC_XGMIIS ) begin : gen_mac_xgmii

                localparam int mac_xgmii_idx = axis_idx - MAC_XGMII_OFFSET;

                eth_mac_10g_fifo #(
                    .DATA_WIDTH         ( 64                            ),
                    .CTRL_WIDTH         ( 64/8                          ),
                    .AXIS_DATA_WIDTH    ( 8 * axis_tx[0].DATA_BYTES     ),
                    .AXIS_KEEP_ENABLE   ( 0                             ),
                    .ENABLE_PADDING     ( 1                             ),
                    .MIN_FRAME_LENGTH   ( 64                            ),
                    .TX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH  ),
                    .TX_FRAME_FIFO      ( 1                             ),
                    .TX_DROP_BAD_FRAME  ( 1                             ),
                    .TX_DROP_WHEN_FULL  ( 1                             ),
                    .RX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH  ),
                    .RX_FRAME_FIFO      ( 1                             ),
                    .RX_DROP_BAD_FRAME  ( 1                             ),
                    .RX_DROP_WHEN_FULL  ( 1                             )
                ) xgmii_mac_fifo (
                    .rx_clk                 ( clk_ifc_mac_xgmiis[mac_xgmii_idx].clk      ),
                    .rx_rst                 ( sreset_ifc_mac_xgmiis[mac_xgmii_idx].reset ),
                    .tx_clk                 ( clk_ifc_mac_xgmiis[mac_xgmii_idx].clk      ),
                    .tx_rst                 ( sreset_ifc_mac_xgmiis[mac_xgmii_idx].reset ),
                    .logic_clk              ( clk_ifc_axis.clk                           ),
                    .logic_rst              ( int_axis_sreset                            ),

                    .ptp_sample_clk         ( 1'b0),

                    .tx_axis_tdata          ( axis_tx[axis_idx].tdata  ),
                    .tx_axis_tkeep          ( '1                       ),
                    .tx_axis_tvalid         ( axis_tx[axis_idx].tvalid ),
                    .tx_axis_tready         ( axis_tx[axis_idx].tready ),
                    .tx_axis_tlast          ( axis_tx[axis_idx].tlast  ),
                    .tx_axis_tuser          ( axis_tx[axis_idx].tuser  ),

                    .s_axis_tx_ptp_ts_tag   ( '0    ),
                    .s_axis_tx_ptp_ts_valid ( 1'b0  ),
                    .s_axis_tx_ptp_ts_ready (       ),

                    .m_axis_tx_ptp_ts_96    (       ),
                    .m_axis_tx_ptp_ts_tag   (       ),
                    .m_axis_tx_ptp_ts_valid (       ),
                    .m_axis_tx_ptp_ts_ready ( 1'b0  ),
                    .m_axis_rx_ptp_ts_96    (       ),
                    .m_axis_rx_ptp_ts_valid (       ),
                    .m_axis_rx_ptp_ts_ready ( 1'b0  ),

                    .ptp_ts_96              ( '0    ),

                    .rx_axis_tdata      ( axis_rx[axis_idx].tdata  ),
                    .rx_axis_tkeep      ( axis_rx[axis_idx].tkeep  ),
                    .rx_axis_tvalid     ( axis_rx[axis_idx].tvalid ),
                    .rx_axis_tready     ( axis_rx[axis_idx].tready ),
                    .rx_axis_tlast      ( axis_rx[axis_idx].tlast  ),
                    .rx_axis_tuser      ( axis_rx[axis_idx].tuser  ),

                    .xgmii_rxd          ( mac_xgmiis[mac_xgmii_idx].txd ),
                    .xgmii_rxc          ( mac_xgmiis[mac_xgmii_idx].txc ),

                    .xgmii_txd          ( mac_xgmiis[mac_xgmii_idx].rxd ),
                    .xgmii_txc          ( mac_xgmiis[mac_xgmii_idx].rxc ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow ( fifo_tx_error_underflow[axis_idx] ),
                    .tx_fifo_overflow   ( fifo_tx_fifo_overflow  [axis_idx] ),
                    .tx_fifo_bad_frame  ( fifo_tx_fifo_bad_frame [axis_idx] ),
                    .tx_fifo_good_frame ( fifo_tx_fifo_good_frame[axis_idx] ),
                    .rx_error_bad_frame ( fifo_rx_error_bad_frame[axis_idx] ),
                    .rx_error_bad_fcs   ( fifo_rx_error_bad_fcs  [axis_idx] ),
                    .rx_fifo_overflow   ( fifo_rx_fifo_overflow  [axis_idx] ),
                    .rx_fifo_bad_frame  ( fifo_rx_fifo_bad_frame [axis_idx] ),
                    .rx_fifo_good_frame ( fifo_rx_fifo_good_frame[axis_idx] )
                );

                assign axis_rx[axis_idx].tstrb = '1;
                assign axis_rx[axis_idx].tid   = '0;
                assign axis_rx[axis_idx].tdest = '0;

            end else if ( axis_idx >= PHY_GMII_OFFSET && axis_idx < PHY_GMII_OFFSET + NUM_PHY_GMIIS ) begin : gen_phy_gmii

                localparam int phy_gmiii_idx = axis_idx - PHY_GMII_OFFSET;

                eth_mac_1g_fifo #(
                    .AXIS_DATA_WIDTH    ( 8 * axis_tx[0].DATA_BYTES   ),
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
                    .rx_clk             ( clk_ifc_phy_gmiis[phy_gmiii_idx].clk      ),
                    .rx_rst             ( sreset_ifc_phy_gmiis[phy_gmiii_idx].reset ),
                    .tx_clk             ( clk_ifc_phy_gmiis[phy_gmiii_idx].clk      ),
                    .tx_rst             ( sreset_ifc_phy_gmiis[phy_gmiii_idx].reset ),
                    .logic_clk          ( clk_ifc_axis.clk                          ),
                    .logic_rst          ( int_axis_sreset                           ),

                    .tx_axis_tdata      ( axis_tx[axis_idx].tdata   ),
                    .tx_axis_tkeep      ( '1                        ),
                    .tx_axis_tvalid     ( axis_tx[axis_idx].tvalid  ),
                    .tx_axis_tready     ( axis_tx[axis_idx].tready  ),
                    .tx_axis_tlast      ( axis_tx[axis_idx].tlast   ),
                    .tx_axis_tuser      ( axis_tx[axis_idx].tuser   ),

                    .rx_axis_tdata      ( axis_rx[axis_idx].tdata   ),
                    .rx_axis_tkeep      ( axis_rx[axis_idx].tkeep   ),
                    .rx_axis_tvalid     ( axis_rx[axis_idx].tvalid  ),
                    .rx_axis_tready     ( axis_rx[axis_idx].tready  ),
                    .rx_axis_tlast      ( axis_rx[axis_idx].tlast   ),
                    .rx_axis_tuser      ( axis_rx[axis_idx].tuser   ),

                    .gmii_rxd           ( phy_gmiis[phy_gmiii_idx].rx_d  ),
                    .gmii_rx_dv         ( phy_gmiis[phy_gmiii_idx].rx_dv ),
                    .gmii_rx_er         ( phy_gmiis[phy_gmiii_idx].rx_er ),

                    .gmii_txd           ( phy_gmiis[phy_gmiii_idx].tx_d  ),
                    .gmii_tx_en         ( phy_gmiis[phy_gmiii_idx].tx_en ),
                    .gmii_tx_er         ( phy_gmiis[phy_gmiii_idx].tx_er ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow ( fifo_tx_error_underflow[axis_idx] ),
                    .tx_fifo_overflow   ( fifo_tx_fifo_overflow  [axis_idx] ),
                    .tx_fifo_bad_frame  ( fifo_tx_fifo_bad_frame [axis_idx] ),
                    .tx_fifo_good_frame ( fifo_tx_fifo_good_frame[axis_idx] ),
                    .rx_error_bad_frame ( fifo_rx_error_bad_frame[axis_idx] ),
                    .rx_error_bad_fcs   ( fifo_rx_error_bad_fcs  [axis_idx] ),
                    .rx_fifo_overflow   ( fifo_rx_fifo_overflow  [axis_idx] ),
                    .rx_fifo_bad_frame  ( fifo_rx_fifo_bad_frame [axis_idx] ),
                    .rx_fifo_good_frame ( fifo_rx_fifo_good_frame[axis_idx] )
                );

                // Unused
                assign axis_rx[axis_idx].tstrb = '1;
                assign axis_rx[axis_idx].tid   = '0;
                assign axis_rx[axis_idx].tdest = '0;

                if (PHY_GMII_ILA_MASK[phy_gmiii_idx]) begin : gen_phy_ila
                    ila_debug gmii_ila (
                        .clk    (  clk_ifc_axis.clk                                      ),
                        .probe0 ({ axis_tx[axis_idx].tdata,  axis_tx[axis_idx].tkeep}    ),
                        .probe1 ({ axis_tx[axis_idx].tvalid, axis_tx[axis_idx].tready}   ),
                        .probe2 ({ axis_tx[axis_idx].tuser,  axis_tx[axis_idx].tlast}    ),
                        .probe3 ({ axis_rx[axis_idx].tdata,  axis_rx[axis_idx].tkeep}    ),
                        .probe4 ({ axis_rx[axis_idx].tvalid, axis_rx[axis_idx].tready}   ),
                        .probe5 ({ axis_rx[axis_idx].tlast,  axis_rx[axis_idx].tuser}    ),
                        .probe6 ({ int_axis_sreset }                                     ),
                        .probe7 ({ phy_gmiis[phy_gmiii_idx].tx_d,
                                   phy_gmiis[phy_gmiii_idx].tx_en,
                                   phy_gmiis[phy_gmiii_idx].tx_er
                                }),
                        .probe8 ({ phy_gmiis[phy_gmiii_idx].rx_d,
                                   phy_gmiis[phy_gmiii_idx].rx_dv,
                                   phy_gmiis[phy_gmiii_idx].rx_er
                                }),
                        .probe9 ({   fifo_tx_error_underflow[axis_idx],
                                    fifo_tx_fifo_overflow[axis_idx],
                                    fifo_tx_fifo_bad_frame[axis_idx],
                                    fifo_tx_fifo_good_frame[axis_idx],
                                    fifo_rx_error_bad_frame[axis_idx],
                                    fifo_rx_error_bad_fcs[axis_idx],
                                    fifo_rx_fifo_overflow[axis_idx],
                                    fifo_rx_fifo_bad_frame[axis_idx],
                                    fifo_rx_fifo_good_frame[axis_idx]
                                }),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end


            end else if ( axis_idx >=  PHY_XGMII_OFFSET && axis_idx < PHY_XGMII_OFFSET + NUM_PHY_XGMIIS ) begin : gen_phy_xgmii

                localparam int phy_xgmiii_idx = axis_idx - PHY_XGMII_OFFSET;

                eth_mac_10g_fifo #(
                    .DATA_WIDTH         ( 64                            ),
                    .CTRL_WIDTH         ( 64/8                          ),
                    .AXIS_DATA_WIDTH    ( 8 * axis_tx[0].DATA_BYTES     ),
                    .AXIS_KEEP_ENABLE   ( 0                             ),
                    .ENABLE_PADDING     ( 1                             ),
                    .MIN_FRAME_LENGTH   ( 64                            ),
                    .TX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH  ),
                    .TX_FRAME_FIFO      ( 1                             ),
                    .TX_DROP_BAD_FRAME  ( 1                             ),
                    .TX_DROP_WHEN_FULL  ( 1                             ),
                    .RX_FIFO_DEPTH      ( 2**XGMII_ETH_FIFO_ADDR_WIDTH  ),
                    .RX_FRAME_FIFO      ( 1                             ),
                    .RX_DROP_BAD_FRAME  ( 1                             ),
                    .RX_DROP_WHEN_FULL  ( 1                             )
                ) xgmii_phy_fifo (
                    .rx_clk                 ( phy_xgmiis[phy_xgmiii_idx].rx_clk     ),
                    .rx_rst                 ( phy_xgmiis[phy_xgmiii_idx].rx_sreset  ),
                    .tx_clk                 ( phy_xgmiis[phy_xgmiii_idx].tx_clk     ),
                    .tx_rst                 ( phy_xgmiis[phy_xgmiii_idx].tx_sreset  ),
                    .logic_clk              ( clk_ifc_axis.clk                      ),
                    .logic_rst              ( int_axis_sreset                       ),

                    .ptp_sample_clk         ( 1'b0 ),

                    .tx_axis_tdata          ( axis_tx[axis_idx].tdata  ),
                    .tx_axis_tkeep          ( '1       ),
                    .tx_axis_tvalid         ( axis_tx[axis_idx].tvalid ),
                    .tx_axis_tready         ( axis_tx[axis_idx].tready ),
                    .tx_axis_tlast          ( axis_tx[axis_idx].tlast  ),
                    .tx_axis_tuser          ( axis_tx[axis_idx].tuser  ),

                    .s_axis_tx_ptp_ts_tag   ( '0    ),
                    .s_axis_tx_ptp_ts_valid ( 1'b0  ),
                    .s_axis_tx_ptp_ts_ready (       ),

                    .m_axis_tx_ptp_ts_96    (       ),
                    .m_axis_tx_ptp_ts_tag   (       ),
                    .m_axis_tx_ptp_ts_valid (       ),
                    .m_axis_tx_ptp_ts_ready ( 1'b0  ),
                    .m_axis_rx_ptp_ts_96    (       ),
                    .m_axis_rx_ptp_ts_valid (       ),
                    .m_axis_rx_ptp_ts_ready ( 1'b0  ),

                    .ptp_ts_96              ( '0    ),

                    .rx_axis_tdata          ( axis_rx[axis_idx].tdata        ),
                    .rx_axis_tkeep          ( axis_rx[axis_idx].tkeep        ),
                    .rx_axis_tvalid         ( axis_rx[axis_idx].tvalid       ),
                    .rx_axis_tready         ( axis_rx[axis_idx].tready       ),
                    .rx_axis_tlast          ( axis_rx[axis_idx].tlast        ),
                    .rx_axis_tuser          ( axis_rx[axis_idx].tuser        ),

                    .xgmii_rxd              ( phy_xgmiis[phy_xgmiii_idx].rxd ),
                    .xgmii_rxc              ( phy_xgmiis[phy_xgmiii_idx].rxc ),

                    .xgmii_txd              ( phy_xgmiis[phy_xgmiii_idx].txd ),
                    .xgmii_txc              ( phy_xgmiis[phy_xgmiii_idx].txc ),

                    .ifg_delay              ( 8'd12 ),

                    .tx_error_underflow ( fifo_tx_error_underflow[axis_idx] ),
                    .tx_fifo_overflow   ( fifo_tx_fifo_overflow  [axis_idx] ),
                    .tx_fifo_bad_frame  ( fifo_tx_fifo_bad_frame [axis_idx] ),
                    .tx_fifo_good_frame ( fifo_tx_fifo_good_frame[axis_idx] ),
                    .rx_error_bad_frame ( fifo_rx_error_bad_frame[axis_idx] ),
                    .rx_error_bad_fcs   ( fifo_rx_error_bad_fcs  [axis_idx] ),
                    .rx_fifo_overflow   ( fifo_rx_fifo_overflow  [axis_idx] ),
                    .rx_fifo_bad_frame  ( fifo_rx_fifo_bad_frame [axis_idx] ),
                    .rx_fifo_good_frame ( fifo_rx_fifo_good_frame[axis_idx] )
                );

                assign axis_rx[axis_idx].tstrb = '1;
                assign axis_rx[axis_idx].tid   = '0;
                assign axis_rx[axis_idx].tdest = '0;

                if (PHY_XGMII_ILA_MASK[phy_xgmiii_idx]) begin : gen_phy_ila
                    ila_debug xgmii_ila (
                        .clk    ( clk_ifc_axis.clk  ),
                        .probe0 ({ axis_tx[axis_idx].tdata} ),
                        .probe1 ({ axis_tx[axis_idx].tvalid,
                                   axis_tx[axis_idx].tready,
                                   axis_tx[axis_idx].tkeep
                                }),
                        .probe2 ({ axis_tx[axis_idx].tuser,    axis_tx[axis_idx].tlast}  ),
                        .probe3 ({ axis_rx[axis_idx].tdata } ),
                        .probe4 ({ axis_rx[axis_idx].tvalid,
                                   axis_rx[axis_idx].tready,
                                   axis_rx[axis_idx].tkeep
                                }),
                        .probe5 ({ axis_rx[axis_idx].tlast,  axis_rx[axis_idx].tuser} ),
                        .probe6 ({ int_axis_sreset }                        ),
                        .probe7 ({ phy_xgmiis[phy_xgmiii_idx].txd[31:0]}    ),
                        .probe8 ({ phy_xgmiis[phy_xgmiii_idx].txd[63:32]}   ),
                        .probe9 ({ phy_xgmiis[phy_xgmiii_idx].rxd[31:0]}    ),
                        .probe10({ phy_xgmiis[phy_xgmiii_idx].rxd[63:32]}   ),
                        .probe11({ phy_xgmiis[phy_xgmiii_idx].txc}          ),
                        .probe12({ phy_xgmiis[phy_xgmiii_idx].rxc}          ),
                        .probe13({ fifo_tx_error_underflow[axis_idx],
                                   fifo_tx_fifo_overflow[axis_idx],
                                   fifo_tx_fifo_bad_frame[axis_idx],
                                   fifo_tx_fifo_good_frame[axis_idx],
                                   fifo_rx_error_bad_frame[axis_idx],
                                   fifo_rx_error_bad_fcs[axis_idx],
                                   fifo_rx_fifo_overflow[axis_idx],
                                   fifo_rx_fifo_bad_frame[axis_idx],
                                   fifo_rx_fifo_good_frame[axis_idx]
                                }),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end

            end else if ( axis_idx >= PHY_PPL_OFFSET && axis_idx < PHY_PPL_OFFSET + NUM_PHY_PPLS ) begin : gen_ppl

                localparam int phy_ppl_idx = axis_idx - PHY_PPL_OFFSET;

                AXIS_int #(
                    .DATA_BYTES(8 * PPL_NUM_LANES)
                ) ppl_ins_i [0:0][0:0][0:0] (
                    .clk     (  ppl_ins[0][phy_ppl_idx][0].clk),
                    .sresetn (  ppl_ins[0][phy_ppl_idx][0].sresetn)
                );

                AXIS_int #(
                    .DATA_BYTES(8 * PPL_NUM_LANES)
                ) ppl_outs_i [0:0][0:0][0:0] (
                    .clk     (  ppl_outs[0][phy_ppl_idx][0].clk),
                    .sresetn (  ppl_outs[0][phy_ppl_idx][0].sresetn)
                );


                axis_connect ppl_ins_i_con (
                    .axis_in  ( ppl_ins[0][phy_ppl_idx][0] ),
                    .axis_out ( ppl_ins_i[0][0][0] )
                );

                axis_connect ppl_outs_i_con (
                    .axis_in  ( ppl_outs_i[0][0][0] ),
                    .axis_out ( ppl_outs[0][phy_ppl_idx][0] )
                );

                ethernet_ppl_fifo #(
                    .ENABLE_PPL   (1'b1       ),
                    .MAX_PKTSIZE  (MAX_PKTSIZE),
                    .DEBUG_ILA    (PHY_PPL_ILA_MASK[phy_ppl_idx]  ),
                    .NUM_LANES    (PPL_NUM_LANES),
                    .NUM_CHANNELS (1          ),
                    .NUM_QUADS    (1          ),
                    .NUM_STREAMS  (1          )
                ) ethernet_ppl_fifo_phy (
                    .clk_eth_ifc    ( clk_ifc_axis.clk  ),
                    .sreset_eth_ifc ( sreset_ifc_axis   ),
                    .eth_sink       ( axis_tx[axis_idx] ),
                    .eth_src        ( axis_rx[axis_idx] ),
                    .ppl_axis_tx    ( ppl_outs_i        ),
                    .ppl_axis_rx    ( ppl_ins_i         )
                );

                assign fifo_tx_error_underflow[axis_idx] = 1'b0;
                assign fifo_tx_fifo_overflow  [axis_idx] = 1'b0;
                assign fifo_tx_fifo_bad_frame [axis_idx] = 1'b0;
                assign fifo_tx_fifo_good_frame[axis_idx] = 1'b0;
                assign fifo_rx_error_bad_frame[axis_idx] = 1'b0;
                assign fifo_rx_error_bad_fcs  [axis_idx] = 1'b0;
                assign fifo_rx_fifo_overflow  [axis_idx] = 1'b0;
                assign fifo_rx_fifo_bad_frame [axis_idx] = 1'b0;
                assign fifo_rx_fifo_good_frame[axis_idx] = 1'b0;

            end
        end
    endgenerate

endmodule

`default_nettype wire
