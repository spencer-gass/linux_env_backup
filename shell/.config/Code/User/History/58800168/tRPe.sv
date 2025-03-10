// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../util/util_check_elab.svh"
`default_nettype none

// TODO: Move this to config file
// TODO: Temporarily use BRAM to maintain compatibility with S-UE for now, should use PS DDR
`define R2D2_BRAM_0KB

/**
 * This is a wrapper for the zynq_pcuecp IP core. It gathers I/Os into more convenient interfaces.
 *
 * AXI Addressing: (NOTE: REMOVED FOR NOW)
 * Where the PL is an AXI master (e.g. axi_lpd_s), it can issue either 40 or 49 bit addresses.
 * 49-bit addressing is used when going through the virtual memory mapping unit. In that case, you must set AxUSER[0] = 1'b1.
 * Since we don't want to do that, we leave AxUSER = '0, which tells the fabric we are using 40-bit physical addresses.
 */
module board_pcuecp_zynq_wrapper #(
    parameter int AXIS_ETH_FIFO_ADDR_WIDTH = 12,
    parameter int AVMM_LPD_M_ADDR_WIDTH = 28, // Needs to match Zynq block design memory map window size
    parameter bit DEBUG_ILA = 0 // Set to 1 to instantiate ILA for hardware debug
) (
    Reset_int.ResetIn   rtl_aresetn_in,         // Reset for block diagram peripherals and interconnect. Must be asserted for duration of slowest clock on this module.

    Clock_int.Output    clk_ifc_ps_156_25_out,                 // Zynq generated clock for use by PS-PL interconnect. 156.25 MHz.
    Clock_int.Input     clk_ifc_ps_156_25_in,                 // Zynq generated clock for use by PS-PL interconnect. 156.25 MHz.
    Reset_int.ResetOut  peripheral_sreset_ifc_ps_156_25_out,   // Peripheral reset synchronous to Zynq generated 156.25 MHz clock.
    Reset_int.ResetOut  peripheral_sresetn_ifc_ps_156_25_out,
    Reset_int.ResetOut  interconnect_sreset_ifc_ps_156_25_out, // Interconnect reset synchronous to Zyqn generated 156.25 MHz clock.
    Reset_int.ResetIn   interconnect_sreset_ifc_ps_156_25_in, // Interconnect reset synchronous to Zyqn generated 156.25 MHz clock.

    Reset_int.ResetOut  interconnect_sresetn_ifc_ps_156_25_out,

    Clock_int.Output    clk_ifc_ps_125_out,                 // Zynq generated clock for use by PS-PL etherent. 125 MHz.
    Reset_int.ResetOut  peripheral_sreset_ifc_ps_125_out,   // Peripheral reset synchronous to Zynq generated 125 MHz clock.
    Reset_int.ResetOut  peripheral_sresetn_ifc_ps_125_out,
    Reset_int.ResetOut  interconnect_sreset_ifc_ps_125_out, // Interconnect reset synchronous to Zyqn generated 125 MHz clock.
    Reset_int.ResetOut  interconnect_sresetn_ifc_ps_125_out,

    Clock_int.Output    clk_ifc_ps_200_out,                 // Zynq generated clock for use by PS-PL etherent. 200 MHz.
    Reset_int.ResetOut  peripheral_sreset_ifc_ps_200_out,   // Peripheral reset synchronous to Zynq generated 200 MHz clock.
    Reset_int.ResetOut  peripheral_sresetn_ifc_ps_200_out,
    Reset_int.ResetOut  interconnect_sreset_ifc_ps_200_out, // Interconnect reset synchronous to Zyqn generated 200 MHz clock.
    Reset_int.ResetOut  interconnect_sresetn_ifc_ps_200_out,

    Clock_int.Output    clk_ifc_ps_50_out,

    AXIS_int.Slave      pspl_eth_tx_in [5:0],       // Ethernet packets to send to the PS via pl_eth_0
    AXIS_int.Master     pspl_eth_rx_out [5:0],      // Ethernet packets received from the PS on pl_eth_0

    AvalonMM_int.Master avmm_lpd_m,             // AVMM LPD bus master (driver by ARM, on clk_ifc_ps_156_25_out)

    AvalonMM_int.Slave  savmm_wrapper_in,

    input  var logic [2:0]      pl_i2c_scl_i,   // {0=blade_pmbus, 1=cal_eeprom, 2=id_eeprom}
    output var logic [2:0]      pl_i2c_scl_o,
    output var logic [2:0]      pl_i2c_scl_t,
    input  var logic [2:0]      pl_i2c_sda_i,
    output var logic [2:0]      pl_i2c_sda_o,
    output var logic [2:0]      pl_i2c_sda_t,
    input  var logic [31:0]     linux_gpio_i,
    output var logic [31:0]     linux_gpio_o,
    output var logic [31:0]     linux_gpio_t,
    AXIS_int.Slave vnp4_s_axis,
    AXIS_int.Master vnp4_m_axis
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_LE(AVMM_LPD_M_ADDR_WIDTH, avmm_lpd_m.ADDRLEN);

    `ELAB_CHECK_EQUAL(peripheral_sreset_ifc_ps_156_25_out.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(interconnect_sreset_ifc_ps_156_25_out.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(peripheral_sreset_ifc_ps_125_out.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(interconnect_sreset_ifc_ps_125_out.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(peripheral_sreset_ifc_ps_200_out.ACTIVE_HIGH, 1);
    `ELAB_CHECK_EQUAL(interconnect_sreset_ifc_ps_200_out.ACTIVE_HIGH, 1);

    `ELAB_CHECK_EQUAL(peripheral_sresetn_ifc_ps_156_25_out.ACTIVE_HIGH, 0);
    `ELAB_CHECK_EQUAL(interconnect_sresetn_ifc_ps_156_25_out.ACTIVE_HIGH, 0);
    `ELAB_CHECK_EQUAL(peripheral_sresetn_ifc_ps_125_out.ACTIVE_HIGH, 0);
    `ELAB_CHECK_EQUAL(interconnect_sresetn_ifc_ps_125_out.ACTIVE_HIGH, 0);
    `ELAB_CHECK_EQUAL(peripheral_sresetn_ifc_ps_200_out.ACTIVE_HIGH, 0);
    `ELAB_CHECK_EQUAL(interconnect_sresetn_ifc_ps_200_out.ACTIVE_HIGH, 0);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    AXI4_int #(
        .DATALEN ( 32                       ),
        .ADDRLEN ( savmm_wrapper_in.ADDRLEN ),
        .WIDLEN  ( 16                       ),
        .RIDLEN  ( 16                       )
    ) pl_s_axi ();

    AXI4_int #(
        .DATALEN ( 32                    ),
        .ADDRLEN ( AVMM_LPD_M_ADDR_WIDTH ),
        .WIDLEN  ( 16                    ),
        .RIDLEN  ( 16                    )
    ) pl_m_axi ();

    logic [39:0]    pl_m_axi_araddr, pl_m_axi_awaddr;


    GMII_int pspl_gmii [5 : 0] ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation

    zynq_pcuecp zynq_inst (
        .rtl_aresetn                        ( rtl_aresetn_in.reset                ),

        .pl_clk0_156_25                     ( clk_ifc_ps_156_25_out.clk           ),
        .pl_clk0_125                        ( clk_ifc_ps_125_out.clk              ),
        .pl_clk1_50                         ( clk_ifc_ps_50_out.clk               ),
        .pl_clk2_200                        ( clk_ifc_ps_200_out.clk              ),

        .pl_peripheral_sreset0_156_25       ( peripheral_sreset_ifc_ps_156_25_out.reset   ),
        .pl_peripheral_sreset1_125          ( peripheral_sreset_ifc_ps_125_out.reset      ),
        .pl_peripheral_sreset2_200          ( peripheral_sreset_ifc_ps_200_out.reset      ),
        .pl_interconnect_sreset0_156_25     ( interconnect_sreset_ifc_ps_156_25_out.reset ),
        .pl_interconnect_sreset1_125        ( interconnect_sreset_ifc_ps_125_out.reset    ),
        .pl_interconnect_sreset2_200        ( interconnect_sreset_ifc_ps_200_out.reset    ),

        .pl_peripheral_sresetn0_156_25      ( peripheral_sresetn_ifc_ps_156_25_out.reset   ),
        .pl_peripheral_sresetn1_125         ( peripheral_sresetn_ifc_ps_125_out.reset      ),
        .pl_peripheral_sresetn2_200         ( peripheral_sresetn_ifc_ps_200_out.reset      ),
        .pl_interconnect_sresetn0_156_25    ( interconnect_sresetn_ifc_ps_156_25_out.reset ),
        .pl_interconnect_sresetn1_125       ( interconnect_sresetn_ifc_ps_125_out.reset    ),
        .pl_interconnect_sresetn2_200       ( interconnect_sresetn_ifc_ps_200_out.reset    ),

        .pspl_eth_bridge_gmii_0_rx_dv       ( pspl_gmii[0].rx_dv      ),
        .pspl_eth_bridge_gmii_0_rx_er       ( pspl_gmii[0].rx_er      ),
        .pspl_eth_bridge_gmii_0_rxd         ( pspl_gmii[0].rx_d       ),
        .pspl_eth_bridge_gmii_0_tx_en       ( pspl_gmii[0].tx_en      ),
        .pspl_eth_bridge_gmii_0_tx_er       ( pspl_gmii[0].tx_er      ),
        .pspl_eth_bridge_gmii_0_txd         ( pspl_gmii[0].tx_d       ),

        /* Tie off MDIO - we have no PHY for internal GMII connections. */
        .pspl_eth_bridge_mdio_0_mdc         (                                   ),
        .pspl_eth_bridge_mdio_0_mdio_i      ( 1'b1                              ),
        .pspl_eth_bridge_mdio_0_mdio_o      (                                   ),
        .pspl_eth_bridge_mdio_0_mdio_t      (                                   ),

        .pspl_eth_bridge_gmii_1_rx_dv       ( pspl_gmii[1].rx_dv     ),
        .pspl_eth_bridge_gmii_1_rx_er       ( pspl_gmii[1].rx_er     ),
        .pspl_eth_bridge_gmii_1_rxd         ( pspl_gmii[1].rx_d      ),
        .pspl_eth_bridge_gmii_1_tx_en       ( pspl_gmii[1].tx_en     ),
        .pspl_eth_bridge_gmii_1_tx_er       ( pspl_gmii[1].tx_er     ),
        .pspl_eth_bridge_gmii_1_txd         ( pspl_gmii[1].tx_d      ),

        /* Tie off MDIO - we have no PHY for internal GMII connections. */
        .pspl_eth_bridge_mdio_1_mdc         (                                   ),
        .pspl_eth_bridge_mdio_1_mdio_i      ( 1'b1                              ),
        .pspl_eth_bridge_mdio_1_mdio_o      (                                   ),
        .pspl_eth_bridge_mdio_1_mdio_t      (                                   ),

        .gmii_gem0_col                     (1'b0                                        ), // no collision
        .gmii_gem0_crs                     (1'b1                                        ), // carrier is aways sensed
        .gmii_gem0_rx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem0_rx_dv                   (pspl_gmii[2].rx_dv                          ),
        .gmii_gem0_rx_er                   (pspl_gmii[2].rx_er                          ),
        .gmii_gem0_rxd                     (pspl_gmii[2].rx_d                           ),
        .gmii_gem0_speed_mode              (                                            ), //  1000 Mb/s using GMII Interface
        .gmii_gem0_tx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem0_tx_en                   (pspl_gmii[2].tx_en                          ),
        .gmii_gem0_tx_er                   (pspl_gmii[2].tx_er                          ),
        .gmii_gem0_txd                     (pspl_gmii[2].tx_d                           ),

        .gmii_gem1_col                     (1'b0                                        ), // no collision
        .gmii_gem1_crs                     (1'b1                                        ), // carrier is aways sensed
        .gmii_gem1_rx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem1_rx_dv                   (pspl_gmii[3].rx_dv                          ),
        .gmii_gem1_rx_er                   (pspl_gmii[3].rx_er                          ),
        .gmii_gem1_rxd                     (pspl_gmii[3].rx_d                           ),
        .gmii_gem1_speed_mode              (                                            ), //  1000 Mb/s using GMII Interface
        .gmii_gem1_tx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem1_tx_en                   (pspl_gmii[3].tx_en                          ),
        .gmii_gem1_tx_er                   (pspl_gmii[3].tx_er                          ),
        .gmii_gem1_txd                     (pspl_gmii[3].tx_d                           ),

        .gmii_gem2_col                     (1'b0                                        ), // no collision
        .gmii_gem2_crs                     (1'b1                                        ), // carrier is aways sensed
        .gmii_gem2_rx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem2_rx_dv                   (pspl_gmii[4].rx_dv                          ),
        .gmii_gem2_rx_er                   (pspl_gmii[4].rx_er                          ),
        .gmii_gem2_rxd                     (pspl_gmii[4].rx_d                           ),
        .gmii_gem2_speed_mode              (                                            ), //  1000 Mb/s using GMII Interface
        .gmii_gem2_tx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem2_tx_en                   (pspl_gmii[4].tx_en                          ),
        .gmii_gem2_tx_er                   (pspl_gmii[4].tx_er                          ),
        .gmii_gem2_txd                     (pspl_gmii[4].tx_d                           ),

        .gmii_gem3_col                     (1'b0                                        ), // no collision
        .gmii_gem3_crs                     (1'b1                                        ), // carrier is aways sensed
        .gmii_gem3_rx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem3_rx_dv                   (pspl_gmii[5].rx_dv                          ),
        .gmii_gem3_rx_er                   (pspl_gmii[5].rx_er                          ),
        .gmii_gem3_rxd                     (pspl_gmii[5].rx_d                           ),
        .gmii_gem3_speed_mode              (                                            ), //  1000 Mb/s using GMII Interface
        .gmii_gem3_tx_clk                  (clk_ifc_ps_125_out.clk                      ),
        .gmii_gem3_tx_en                   (pspl_gmii[5].tx_en                          ),
        .gmii_gem3_tx_er                   (pspl_gmii[5].tx_er                          ),
        .gmii_gem3_txd                     (pspl_gmii[5].tx_d                           ),

        .pl_m_axi_awid                      ( pl_m_axi.awid                      ),
        .pl_m_axi_awaddr                    ( pl_m_axi_awaddr                    ),
        .pl_m_axi_awlen                     ( pl_m_axi.awlen                     ),
        .pl_m_axi_awsize                    ( pl_m_axi.awsize                    ),
        .pl_m_axi_awburst                   ( pl_m_axi.awburst                   ),
        .pl_m_axi_awlock                    ( pl_m_axi.awlock                    ),
        .pl_m_axi_awcache                   ( pl_m_axi.awcache                   ),
        .pl_m_axi_awprot                    ( pl_m_axi.awprot                    ),
        .pl_m_axi_awregion                  (                                    ),
        .pl_m_axi_awqos                     ( pl_m_axi.awqos                     ),
        .pl_m_axi_awuser                    (                                    ),
        .pl_m_axi_awvalid                   ( pl_m_axi.awvalid                   ),
        .pl_m_axi_awready                   ( pl_m_axi.awready                   ),

        .pl_m_axi_wdata                     ( pl_m_axi.wdata                     ),
        .pl_m_axi_wstrb                     ( pl_m_axi.wstrb                     ),
        .pl_m_axi_wlast                     ( pl_m_axi.wlast                     ),
        .pl_m_axi_wvalid                    ( pl_m_axi.wvalid                    ),
        .pl_m_axi_wready                    ( pl_m_axi.wready                    ),

        .pl_m_axi_bid                       ( pl_m_axi.bid                       ),
        .pl_m_axi_bresp                     ( pl_m_axi.bresp                     ),
        .pl_m_axi_bvalid                    ( pl_m_axi.bvalid                    ),
        .pl_m_axi_bready                    ( pl_m_axi.bready                    ),

        .pl_m_axi_arid                      ( pl_m_axi.arid                      ),
        .pl_m_axi_araddr                    ( pl_m_axi_araddr                    ),
        .pl_m_axi_arlen                     ( pl_m_axi.arlen                     ),
        .pl_m_axi_arsize                    ( pl_m_axi.arsize                    ),
        .pl_m_axi_arburst                   ( pl_m_axi.arburst                   ),
        .pl_m_axi_arlock                    ( pl_m_axi.arlock                    ),
        .pl_m_axi_arcache                   ( pl_m_axi.arcache                   ),
        .pl_m_axi_arprot                    ( pl_m_axi.arprot                    ),
        .pl_m_axi_arregion                  (                                    ),
        .pl_m_axi_arqos                     ( pl_m_axi.arqos                     ),
        .pl_m_axi_aruser                    (                                    ),
        .pl_m_axi_arvalid                   ( pl_m_axi.arvalid                   ),
        .pl_m_axi_arready                   ( pl_m_axi.arready                   ),

        .pl_m_axi_rid                       ( pl_m_axi.rid                       ),
        .pl_m_axi_rdata                     ( pl_m_axi.rdata                     ),
        .pl_m_axi_rresp                     ( pl_m_axi.rresp                     ),
        .pl_m_axi_rlast                     ( pl_m_axi.rlast                     ),
        .pl_m_axi_rvalid                    ( pl_m_axi.rvalid                    ),
        .pl_m_axi_rready                    ( pl_m_axi.rready                    ),

        .pl_s_axi_awaddr                    ( pl_s_axi.awaddr   ),
        .pl_s_axi_awlen                     ( pl_s_axi.awlen    ),
        .pl_s_axi_awsize                    ( pl_s_axi.awsize   ),
        .pl_s_axi_awburst                   ( pl_s_axi.awburst  ),
        .pl_s_axi_awlock                    ( pl_s_axi.awlock   ),
        .pl_s_axi_awcache                   ( pl_s_axi.awcache  ),
        .pl_s_axi_awprot                    ( pl_s_axi.awprot   ),
        .pl_s_axi_awregion                  (                   ),
        .pl_s_axi_awqos                     ( pl_s_axi.awqos    ),
        .pl_s_axi_awuser                    (                   ),
        .pl_s_axi_awvalid                   ( pl_s_axi.awvalid  ),
        .pl_s_axi_awready                   ( pl_s_axi.awready  ),

        .pl_s_axi_wdata                     ( pl_s_axi.wdata    ),
        .pl_s_axi_wstrb                     ( pl_s_axi.wstrb    ),
        .pl_s_axi_wlast                     ( pl_s_axi.wlast    ),
        .pl_s_axi_wvalid                    ( pl_s_axi.wvalid   ),
        .pl_s_axi_wready                    ( pl_s_axi.wready   ),

        .pl_s_axi_bresp                     ( pl_s_axi.bresp    ),
        .pl_s_axi_bvalid                    ( pl_s_axi.bvalid   ),
        .pl_s_axi_bready                    ( pl_s_axi.bready   ),

        .pl_s_axi_araddr                    ( pl_s_axi.araddr   ),
        .pl_s_axi_arlen                     ( pl_s_axi.arlen    ),
        .pl_s_axi_arsize                    ( pl_s_axi.arsize   ),
        .pl_s_axi_arburst                   ( pl_s_axi.arburst  ),
        .pl_s_axi_arlock                    ( pl_s_axi.arlock   ),
        .pl_s_axi_arcache                   ( pl_s_axi.arcache  ),
        .pl_s_axi_arprot                    ( pl_s_axi.arprot   ),
        .pl_s_axi_arregion                  (                   ),
        .pl_s_axi_arqos                     ( pl_s_axi.arqos    ),
        .pl_s_axi_aruser                    (                   ),
        .pl_s_axi_arvalid                   ( pl_s_axi.arvalid  ),
        .pl_s_axi_arready                   ( pl_s_axi.arready  ),

        .pl_s_axi_rdata                     ( pl_s_axi.rdata    ),
        .pl_s_axi_rresp                     ( pl_s_axi.rresp    ),
        .pl_s_axi_rlast                     ( pl_s_axi.rlast    ),
        .pl_s_axi_rvalid                    ( pl_s_axi.rvalid   ),
        .pl_s_axi_rready                    ( pl_s_axi.rready   ),

        .blade_pmbus_i2c_scl_i              ( pl_i2c_scl_i[0]                   ),
        .blade_pmbus_i2c_scl_o              ( pl_i2c_scl_o[0]                   ),
        .blade_pmbus_i2c_scl_t              ( pl_i2c_scl_t[0]                   ),
        .blade_pmbus_i2c_sda_i              ( pl_i2c_sda_i[0]                   ),
        .blade_pmbus_i2c_sda_o              ( pl_i2c_sda_o[0]                   ),
        .blade_pmbus_i2c_sda_t              ( pl_i2c_sda_t[0]                   ),

        .cal_eeprom_i2c_scl_i               ( pl_i2c_scl_i[1]                   ),
        .cal_eeprom_i2c_scl_o               ( pl_i2c_scl_o[1]                   ),
        .cal_eeprom_i2c_scl_t               ( pl_i2c_scl_t[1]                   ),
        .cal_eeprom_i2c_sda_i               ( pl_i2c_sda_i[1]                   ),
        .cal_eeprom_i2c_sda_o               ( pl_i2c_sda_o[1]                   ),
        .cal_eeprom_i2c_sda_t               ( pl_i2c_sda_t[1]                   ),

        .id_eeprom_i2c_scl_i                ( pl_i2c_scl_i[2]                   ),
        .id_eeprom_i2c_scl_o                ( pl_i2c_scl_o[2]                   ),
        .id_eeprom_i2c_scl_t                ( pl_i2c_scl_t[2]                   ),
        .id_eeprom_i2c_sda_i                ( pl_i2c_sda_i[2]                   ),
        .id_eeprom_i2c_sda_o                ( pl_i2c_sda_o[2]                   ),
        .id_eeprom_i2c_sda_t                ( pl_i2c_sda_t[2]                   ),

        .linux_gpio_0_tri_i                 ( linux_gpio_i                      ),
        .linux_gpio_0_tri_o                 ( linux_gpio_o                      ),
        .linux_gpio_0_tri_t                 ( linux_gpio_t                      ),

        .vnp4_m_axis_tdata                  ( vnp4_m_axis.tdata ),
        .vnp4_m_axis_tkeep                  ( vnp4_m_axis.tkeep ),
        .vnp4_m_axis_tlast                  ( vnp4_m_axis.tlast ),
        .vnp4_m_axis_tready                 ( vnp4_m_axis.tready ),
        .vnp4_m_axis_tvalid                 ( vnp4_m_axis.tvalid ),
        .vnp4_metadata_in                   ( '0 ),
        .vnp4_s_axis_tdata                  ( vnp4_m_axis.tdata ),
        .vnp4_s_axis_tkeep                  ( vnp4_m_axis.tkeep ),
        .vnp4_s_axis_tlast                  ( vnp4_m_axis.tlast ),
        .vnp4_s_axis_tready                 ( vnp4_m_axis.tready ),
        .vnp4_s_axis_tvalid                 ( vnp4_m_axis.tvalid ),
        .vnp4_user_extern_in                ( '0 ),
        .vnp4_user_extern_in_valid          ( 1'b0 ),
        .vnp4_user_metadata_in_valid        ( 1'b0 )

    );

    always_comb begin
        pl_m_axi.araddr = '0;
        pl_m_axi.araddr[AVMM_LPD_M_ADDR_WIDTH-1:0] = pl_m_axi_araddr[AVMM_LPD_M_ADDR_WIDTH-1:0];

        pl_m_axi.awaddr = '0;
        pl_m_axi.awaddr[AVMM_LPD_M_ADDR_WIDTH-1:0] = pl_m_axi_awaddr[AVMM_LPD_M_ADDR_WIDTH-1:0];
    end

    axi4_to_avmm #(
        .AVMM_BURST_INCR ( 0 )
    ) axi4_to_avmm_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25_in                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25_in ),
        .axi_in                  ( pl_m_axi.Slave                       ),
        .avmm_out                ( avmm_lpd_m                           )
    );

    avmm_to_axi4 avmm_to_axi4_inst (
        .clk_ifc                 ( clk_ifc_ps_156_25_in                 ),
        .interconnect_sreset_ifc ( interconnect_sreset_ifc_ps_156_25_in ),
        .avmm_in                 ( savmm_wrapper_in                     ),
        .axi_out                 ( pl_s_axi.Master                      )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI Ethernet
    //

    generate
        for (genvar i = 0; i < 6; i++) begin: gen_pspl_gmii_axis_fifo
            eth_mac_1g_fifo #(
                .AXIS_DATA_WIDTH   (8                          ),
                .AXIS_KEEP_ENABLE  (0                          ),
                .MIN_FRAME_LENGTH  (64                         ),
                .ENABLE_PADDING    (1                          ),
                .TX_FIFO_DEPTH     (2**AXIS_ETH_FIFO_ADDR_WIDTH),
                .TX_FRAME_FIFO     (1                          ),
                .TX_DROP_BAD_FRAME (1                          ),
                .TX_DROP_WHEN_FULL (1                          ),
                .RX_FIFO_DEPTH     (2**AXIS_ETH_FIFO_ADDR_WIDTH),
                .RX_FRAME_FIFO     (1                          ),
                .RX_DROP_BAD_FRAME (1                          ),
                .RX_DROP_WHEN_FULL (1                          )
            ) pl_eth_mac_inst (
                .rx_clk             (clk_ifc_ps_125_out.clk                ),
                .rx_rst             (peripheral_sreset_ifc_ps_125_out.reset),

                .tx_clk             (clk_ifc_ps_125_out.clk                ),
                .tx_rst             (peripheral_sreset_ifc_ps_125_out.reset),

                .logic_clk          (clk_ifc_ps_125_out.clk                ),
                .logic_rst          (peripheral_sreset_ifc_ps_125_out.reset),

                .tx_axis_tdata      (pspl_eth_tx_in[i].tdata               ),
                .tx_axis_tkeep      ('1                                    ),
                .tx_axis_tvalid     (pspl_eth_tx_in[i].tvalid              ),
                .tx_axis_tready     (pspl_eth_tx_in[i].tready              ),
                .tx_axis_tlast      (pspl_eth_tx_in[i].tlast               ),
                .tx_axis_tuser      (pspl_eth_tx_in[i].tuser               ),

                .rx_axis_tdata      (pspl_eth_rx_out[i].tdata              ),
                .rx_axis_tkeep      (pspl_eth_rx_out[i].tkeep              ),
                .rx_axis_tvalid     (pspl_eth_rx_out[i].tvalid             ),
                .rx_axis_tready     (pspl_eth_rx_out[i].tready             ),
                .rx_axis_tlast      (pspl_eth_rx_out[i].tlast              ),
                .rx_axis_tuser      (pspl_eth_rx_out[i].tuser              ),

                .gmii_rxd           (pspl_gmii[i].tx_d                     ),
                .gmii_rx_dv         (pspl_gmii[i].tx_en                    ),
                .gmii_rx_er         (pspl_gmii[i].tx_er                    ),

                .gmii_txd           (pspl_gmii[i].rx_d                     ),
                .gmii_tx_en         (pspl_gmii[i].rx_dv                    ),
                .gmii_tx_er         (pspl_gmii[i].rx_er                    ),

                // No speed negotiation; always assume 1G.
                .rx_clk_enable      (1'b1                                  ),
                .tx_clk_enable      (1'b1                                  ),
                .rx_mii_select      (1'b0                                  ),
                .tx_mii_select      (1'b0                                  ),

                .ifg_delay          (8'd12                                 ),

                .tx_error_underflow (                                      ),
                .tx_fifo_overflow   (                                      ),
                .tx_fifo_bad_frame  (                                      ),
                .tx_fifo_good_frame (                                      ),
                .rx_error_bad_frame (                                      ),
                .rx_error_bad_fcs   (                                      ),
                .rx_fifo_overflow   (                                      ),
                .rx_fifo_bad_frame  (                                      ),
                .rx_fifo_good_frame (                                      )
            );

            // Unused
            assign pspl_eth_rx_out[i].tstrb = '1;
            assign pspl_eth_rx_out[i].tid   = '0;
            assign pspl_eth_rx_out[i].tdest = '0;

        end
    endgenerate


    generate
        if (DEBUG_ILA) begin
            ila_debug ila_debug_zynq_ethernet_axis (
                .clk     (clk_ifc_ps_125_out.clk                              ),
                .probe0  (pspl_eth_tx_in_0.tdata                              ),
                .probe1  ({pspl_eth_tx_in_0.tvalid, pspl_eth_tx_in_0.tready}  ),
                .probe2  ({pspl_eth_tx_in_0.tuser, pspl_eth_tx_in_0.tlast}    ),
                .probe3  ({pspl_eth_rx_out_0.tdata, pspl_eth_rx_out_0.tkeep}  ),
                .probe4  ({pspl_eth_rx_out_0.tvalid, pspl_eth_rx_out_0.tready}),
                .probe5  ({pspl_eth_rx_out_0.tlast,  pspl_eth_rx_out_0.tuser} ),
                .probe6  (pspl_eth_tx_in_1.tdata                              ),
                .probe7  ({pspl_eth_tx_in_1.tvalid, pspl_eth_tx_in_1.tready}  ),
                .probe8  ({pspl_eth_tx_in_1.tuser, pspl_eth_tx_in_1.tlast}    ),
                .probe9  ({pspl_eth_rx_out_1.tdata, pspl_eth_rx_out_1.tkeep}  ),
                .probe10 ({pspl_eth_rx_out_1.tvalid, pspl_eth_rx_out_1.tready}),
                .probe11 ({pspl_eth_rx_out_1.tlast,  pspl_eth_rx_out_1.tuser} ),
                .probe12 (peripheral_sreset_ifc_ps_125_out.reset              ),
                .probe13 (0                                                   ),
                .probe14 (0                                                   ),
                .probe15 (0                                                   )
            );
        end
    endgenerate

endmodule

`default_nettype wire
