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
module ethernet_point_to_multipoint_hub
#(
    parameter bit [15:0]                MODULE_VERSION      = 0,
    parameter bit [15:0]                MODULE_ID           = 0,
    parameter string                    POINT_INTF_TYPE     = "GMII_MASTER",  // Valid options are GMII_MASTER, GMII_SLAVE, XGMII_MASTER, XGMII_SLAVE, PPL, and AXIS
    parameter int                       NUM_PHY_PPLS        = 1,              // number of 64-bit PPL AXI streams
    parameter int                       NUM_PHY_XGMIIS      = 1,              // number of XGMII interfaces towards PHY (PCS/PMA) 10G
    parameter int                       NUM_PHY_GMIIS       = 1,              // number of GMII interfaces towards PHY (PCS/PMA) 1G/2.5G
    parameter int                       NUM_MAC_XGMIIS      = 1,              // number of XGMII interfaces towards MAC 10G
    parameter int                       NUM_MAC_GMIIS       = 1,              // number of XGMII interfaces towards MAC 1G/2.5G
    parameter int                       NUM_MAC_AXIS        = 1,              // number of AXIS interfaces towards MAC 1G/2.5G
    parameter int                       NUM_PHY_LOOPBACKS   = 0,
    parameter int                       NUM_MAC_LOOPBACKS   = 0,
    parameter int                       MAX_PKTSIZE         = 8192,
    parameter bit                       POINT_INTF_ILA      = 1'b0,
    parameter bit [NUM_PHY_XGMIIS-1:0]  PHY_XGMII_ILA_MASK  = '0,
    parameter bit [NUM_PHY_PPLS-1:0]    PHY_PPL_ILA_MASK    = '0,
    parameter bit [NUM_PHY_GMIIS-1:0]   PHY_GMII_ILA_MASK   = '0,
    parameter bit [NUM_MAC_GMIIS-1:0]   MAC_GMII_ILA_MASK   = '0
) (


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Interfaces


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: clocks and resets


    Clock_int.Input   clk_ifc_avmm,
    Reset_int.ResetIn sreset_ifc_avmm_peripheral,
    Reset_int.ResetIn sreset_ifc_avmm_interconnect,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM on clk_ifc_avmm


    AvalonMM_int.Slave avmm,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Point Interfaces
    // Only one of these interfaces is active and is selected at build-time by
    // the POINT_INTF_TYPE parameter


    GMII_int.Slave      point_mac_gmii,
    Clock_int.Input     point_clk_ifc_mac_gmii,
    Reset_int.ResetIn   point_sreset_ifc_mac_gmii,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Multi-point Interfaces


    AXIS_int.Slave      multipoint_ppl_ins                 [0:0][NUM_PHY_PPLS-1:0][0:0],
    AXIS_int.Master     multipoint_ppl_outs                [0:0][NUM_PHY_PPLS-1:0][0:0],

    GMII_int.Master     multipoint_phy_gmiis               [NUM_PHY_GMIIS-1:0],
    Clock_int.Input     multipoint_clk_ifc_phy_gmiis       [NUM_PHY_GMIIS-1:0],
    Reset_int.ResetIn   multipoint_sreset_ifc_phy_gmiis    [NUM_PHY_GMIIS-1:0],

    XGMII_int.Master    multipoint_phy_xgmiis              [NUM_PHY_XGMIIS-1:0],

    GMII_int.Slave      multipoint_mac_gmiis               [NUM_MAC_GMIIS-1:0],
    Clock_int.Input     multipoint_clk_ifc_mac_gmiis       [NUM_MAC_GMIIS-1:0],
    Reset_int.ResetIn   multipoint_sreset_ifc_mac_gmiis    [NUM_MAC_GMIIS-1:0],

    XGMII_int.Slave     multipoint_mac_xgmiis              [NUM_MAC_XGMIIS-1:0],
    Clock_int.Input     multipoint_clk_ifc_mac_xgmiis      [NUM_MAC_XGMIIS-1:0],
    Reset_int.ResetIn   multipoint_sreset_ifc_mac_xgmiis   [NUM_MAC_XGMIIS-1:0],

    AXIS_int.Slave      multipoint_mac_axis_ins            [NUM_MAC_AXIS-1:0],
    AXIS_int.Master     multipoint_mac_axis_outs           [NUM_MAC_AXIS-1:0],

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

    logic point_mac_fifo_tx_error_underflow;
    logic point_mac_fifo_tx_fifo_overflow;
    logic point_mac_fifo_tx_fifo_bad_frame;
    logic point_mac_fifo_tx_fifo_good_frame;
    logic point_mac_fifo_rx_error_bad_frame;
    logic point_mac_fifo_rx_error_bad_fcs;
    logic point_mac_fifo_rx_fifo_overflow;
    logic point_mac_fifo_rx_fifo_bad_frame;
    logic point_mac_fifo_rx_fifo_good_frame;

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
    ) point_axis_ingress (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) point_axis_egress (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );



    AXIS_int #(
        .DATA_BYTES(1)
    ) int_mac_axis_in [NUM_MACS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_mac_axis_out [NUM_MACS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phy_axis_in [NUM_PHYS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phy_axis_out [NUM_PHYS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );


    AXIS_int #(
        .DATA_BYTES(1)
    ) int_macphy_axis_in [NUM_MACS-1:0][NUM_PHYS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phymac_axis_in [NUM_PHYS-1:0][NUM_MACS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_macphy_axis_out [NUM_MACS-1:0][NUM_PHYS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES(1)
    ) int_phymac_axis_out [NUM_PHYS-1:0][NUM_MACS-1:0] (
        .clk     ( int_axis_clk     ),
        .sresetn ( int_axis_sresetn )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    assign int_axis_clk     = clk_ifc_avmm.clk;
    assign int_axis_sresetn = ~(sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH);
    assign int_axis_sreset  = (sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Registers


    assign avmm_gpio_in[0] = NUM_MACS;
    assign avmm_gpio_in[1] = NUM_PHYS;
    assign avmm_gpio_in[2] = mac_phy_sel_invalid;
    assign avmm_gpio_in[3] = phy_mac_sel_invalid;

    avmm_gpio #(
        .MODULE_VERSION          ( MODULE_VERSION ),
        .MODULE_ID               ( MODULE_ID      ),
        .DATALEN                 ( 32             ),
        .NUM_INPUT_REGS          ( 4              ),
        .NUM_OUTPUT_REGS         ( NUM_MACS       ),
        .DEFAULT_OUTPUT_VALS     ( '{default:'1}  )
    ) avmm_gpio_inst (
        .clk_ifc                 ( clk_ifc_avmm                 ),
        .peripheral_sreset_ifc   ( sreset_ifc_avmm_peripheral   ),
        .interconnect_sreset_ifc ( sreset_ifc_avmm_interconnect ),
        .avmm                    ( avmm                         ),
        .input_vals              ( avmm_gpio_in                 ),
        .output_vals             ( avmm_gpio_out                )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Point Interface


    generate
        case (POINT_INTF_TYPE)

            //TODO(sgass): Support other interface types as they are needed by
            // adding them to this generate statement.

            "GMII_SLAVE": begin

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
                    .rx_clk             ( clk_ifc_mac_gmii.clk        ),
                    .rx_rst             ( sreset_ifc_mac_gmii.reset   ),

                    .tx_clk             ( clk_ifc_mac_gmii.clk        ),
                    .tx_rst             ( sreset_ifc_mac_gmii.reset   ),

                    .logic_clk          ( int_axis_clk                ),
                    .logic_rst          ( int_axis_sreset             ),

                    .tx_axis_tdata      ( point_axis_egress.tdata     ),
                    .tx_axis_tkeep      ( '1                          ),
                    .tx_axis_tvalid     ( point_axis_egress.tvalid    ),
                    .tx_axis_tready     ( point_axis_egress.tready    ),
                    .tx_axis_tlast      ( point_axis_egress.tlast     ),
                    .tx_axis_tuser      ( point_axis_egress.tuser     ),

                    .rx_axis_tdata      ( point_axis_ingress.tdata    ),
                    .rx_axis_tkeep      ( point_axis_ingress.tkeep    ),
                    .rx_axis_tvalid     ( point_axis_ingress.tvalid   ),
                    .rx_axis_tready     ( point_axis_ingress.tready   ),
                    .rx_axis_tlast      ( point_axis_ingress.tlast    ),
                    .rx_axis_tuser      ( point_axis_ingress.tuser    ),

                    .gmii_rxd           ( point_mac_gmii.tx_d         ),
                    .gmii_rx_dv         ( point_mac_gmii.tx_en        ),
                    .gmii_rx_er         ( point_mac_gmii.tx_er        ),

                    .gmii_txd           ( point_mac_gmii.rx_d         ),
                    .gmii_tx_en         ( point_mac_gmii.rx_dv        ),
                    .gmii_tx_er         ( point_mac_gmii.rx_er        ),

                    // No speed negotiation; always assume full speed incoming clock.
                    .rx_clk_enable      ( 1'b1 ),
                    .tx_clk_enable      ( 1'b1 ),
                    .rx_mii_select      ( 1'b0 ),
                    .tx_mii_select      ( 1'b0 ),

                    .ifg_delay          ( 8'd12 ),

                    .tx_error_underflow ( point_mac_fifo_tx_error_underflow ),
                    .tx_fifo_overflow   ( point_mac_fifo_tx_fifo_overflow   ),
                    .tx_fifo_bad_frame  ( point_mac_fifo_tx_fifo_bad_frame  ),
                    .tx_fifo_good_frame ( point_mac_fifo_tx_fifo_good_frame ),
                    .rx_error_bad_frame ( point_mac_fifo_rx_error_bad_frame ),
                    .rx_error_bad_fcs   ( point_mac_fifo_rx_error_bad_fcs   ),
                    .rx_fifo_overflow   ( point_mac_fifo_rx_fifo_overflow   ),
                    .rx_fifo_bad_frame  ( point_mac_fifo_rx_fifo_bad_frame  ),
                    .rx_fifo_good_frame ( point_mac_fifo_rx_fifo_good_frame )
                );

                // Unused
                assign point_axis_egress.tstrb  = '1;
                assign point_axis_egress.tid    = '0;
                assign point_axis_egress.tdest  = '0;
                assign point_axis_ingress.tstrb = '1;
                assign point_axis_ingress.tid   = '0;
                assign point_axis_ingress.tdest = '0;

                if (POINT_INTF_ILA) begin : gen_point_intf_ila
                    ila_debug gmii_ila (
                        .clk   (  int_axis_clk                                          ),
                        .probe0({ point_axis_ingress.tdata,  point_axis_ingress.tkeep  }),
                        .probe1({ point_axis_ingress.tvalid, point_axis_ingress.tready }),
                        .probe2({ point_axis_ingress.tuser,  point_axis_ingress.tlast  }),
                        .probe3({ point_axis_egress.tdata,   point_axis_egress.tkeep   }),
                        .probe4({ point_axis_egress.tvalid,  point_axis_egress.tready  }),
                        .probe5({ point_axis_egress.tlast,   point_axis_egress.tuser   }),
                        .probe6({ int_axis_sreset }                                                 ),
                        .probe7({ point_mac_gmii.tx_d,
                                   point_mac_gmii.tx_en,
                                   point_mac_gmii.tx_er
                                }),
                        .probe8({ point_mac_gmii.rx_d,
                                  point_mac_gmii.rx_dv,
                                  point_mac_gmii.rx_er
                                }),
                        .probe9({  point_mac_fifo_tx_error_underflow,
                                   point_mac_fifo_tx_fifo_overflow,
                                   point_mac_fifo_tx_fifo_bad_frame,
                                   point_mac_fifo_tx_fifo_good_frame,
                                   point_mac_fifo_rx_error_bad_frame,
                                   point_mac_fifo_rx_error_bad_fcs,
                                   point_mac_fifo_rx_fifo_overflow,
                                   point_mac_fifo_rx_fifo_bad_frame,
                                   point_mac_fifo_rx_fifo_good_frame
                                }),
                        .probe10( '0 ),
                        .probe11( '0 ),
                        .probe12( '0 ),
                        .probe13( '0 ),
                        .probe14( '0 ),
                        .probe15( '0 )
                    );
                end
            end

            default: begin
                $fatal("Invalid point interface type: %s. Only GMII_SLAVE is supported.", POINT_INTF_TYPE);
            end

        endcase
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Multi-Point Interfaces


    ethernet_to_axis #(
        .NUM_MAC_GMIIS       ( NUM_MAC_GMIIS        ),
        .NUM_MAC_XGMIIS      ( NUM_MAC_XGMIIS       ),
        .NUM_PHY_GMIIS       ( NUM_PHY_GMIIS        ),
        .NUM_PHY_XGMIIS      ( NUM_PHY_XGMIIS       ),
        .NUM_PHY_PPLS        ( NUM_PHY_PPLS         ),
        .MAX_PKTSIZE         ( MAX_PKTSIZE          ),
        .MAC_GMII_ILA_MASK   ( MAC_GMII_ILA_MASK    ),
        .PHY_GMII_ILA_MASK   ( PHY_GMII_ILA_MASK    ),
        .PHY_XGMII_ILA_MASK  ( PHY_XGMII_ILA_MASK   ),
        .PHY_PPL_ILA_MASK    ( PHY_PPL_ILA_MASK     )
    ) mac_eth_to_axis (
        .clk_ifc_mac_gmiis       ( clk_ifc_mac_gmiis     ),
        .sreset_ifc_mac_gmiis    ( sreset_ifc_mac_gmiis  ),
        .mac_gmiis               ( mac_gmiis             ),
        .sreset_ifc_mac_xgmiis   ( sreset_ifc_mac_xgmiis ),
        .clk_ifc_mac_xgmiis      ( clk_ifc_mac_xgmiis    ),
        .mac_xgmiis              ( mac_xgmiis            ),
        .clk_ifc_phy_gmiis       ( unused_clk_ifc        ),
        .sreset_ifc_phy_gmiis    ( unused_sreset_ifc     ),
        .phy_gmiis               ( unused_phy_gmiis      ),
        .phy_xgmiis              ( unused_phy_xgmiis     ),
        .ppl_outs                ( unused_ppl_outs       ),
        .ppl_ins                 ( unused_ppl_ins        ),

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

endmodule

`default_nettype wire
