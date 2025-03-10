// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Testbench for VNP4 with TinyBCAM
 */
module p4_router_vnp4_tiny_bcam_tb();

    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;

    parameter bit PROTOCOL_CHECK    = 0;

    parameter int MTU_BYTES         = 1500;
    parameter int PACKET_MAX_BLEN   = MTU_BYTES;
    parameter int PACKET_MIN_BLEN   = 64;

    parameter int DATALEN           = 32;
    parameter int ADDRLEN           = 15;
    parameter int BURSTLEN          = 11;
    parameter int BURST_CAPABLE     = 0;

    /////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import P4_ROUTER_PKG::*;
    import P4_ROUTER_TB_PKG::*;
    import UTIL_INTS::*;


    /////////////////////////////////////////////////////////////////////////
    // SECTION: Constants


    localparam int VNP4_DATA_BYTES        = P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::TDATA_NUM_BYTES;
    localparam int MTU_BYTES_LOG          = $clog2(MTU_BYTES);
    localparam int MAX_PKT_WLEN           = U_INT_CEIL_DIV(PACKET_MAX_BLEN, VNP4_DATA_BYTES);
    localparam int VNP4_DATA_BYTES_LOG    = $clog2(VNP4_DATA_BYTES);

    // from vitis_net_p4_frr_tq_ecp_tiny_bcam_defs.h
    // specific to this configuration of VNP4
    localparam int ADDR_BUILDINFO        = 32'h00000000;
    localparam int ADDR_INTERRUPT        = 32'h00000008;
    localparam int ADDR_CONTROL          = 32'h000000E8;
    localparam int ADDR_INTF_MAP         = 32'h00002000;
    localparam int ADDR_LFIB             = 32'h00004000;
    localparam int ADDR_IPV4_FIB_INGRESS = 32'h00006000;
    localparam int ADDR_CMP_IPV4_FIB     = 32'h00008000;
    localparam int ADDR_CMP_MAC_FIB      = 32'h0000A000;
    localparam int ADDR_VLAN_MAP         = 32'h0000C000;

    localparam int NUM_CAMS              = 5;

    localparam int CAM_OFFSETS [NUM_CAMS-1:0] = '{
        ADDR_LFIB,
        ADDR_IPV4_FIB_INGRESS,
        ADDR_CMP_IPV4_FIB,
        ADDR_CMP_MAC_FIB,
        ADDR_VLAN_MAP
    };

    // Common to all TinyBCAMs

    localparam int REG_WIDTH_BYTES = 4;

    localparam int ADDR_CAM_CTRL           = REG_WIDTH_BYTES * 8'h00;
    localparam int ADDR_CAM_ENTRY_ID       = REG_WIDTH_BYTES * 8'h01;
    localparam int ADDR_CAM_EMULATION_MODE = REG_WIDTH_BYTES * 8'h02;
    localparam int ADDR_CAM_LOOKUP_COUNT   = REG_WIDTH_BYTES * 8'h03;
    localparam int ADDR_CAM_HIT_COUNT      = REG_WIDTH_BYTES * 8'h04;
    localparam int ADDR_CAM_MISS_COUNT     = REG_WIDTH_BYTES * 8'h05;
    localparam int ADDR_CAM_DATA0          = REG_WIDTH_BYTES * 8'h10;

    localparam int MASK_CTRL_RD_BIT           = 32'd1 << 0;
    localparam int MASK_CTRL_WR_BIT           = 32'd1 << 1;
    localparam int MASK_CTRL_RST_BIT          = 32'd1 << 2;
    localparam int MASK_CTRL_DEBUG_MODE       = 32'd1 << 29;
    localparam int MASK_CTRL_DEBUG_CAPTURE    = 32'd1 << 30;
    localparam int MASK_CTRL_ENTRY_IN_USE_BIT = 32'd1 << 31;

    // Network Packet Generator Constants

    typedef struct packed {
        logic [47:0] mac_da;
        logic [47:0] mac_sa;
        logic [15:0] ether_type;
        logic        vlan_valid;
        logic [31:0] vlan_tag;
        logic [1:0]  num_mpls_labels;
        logic [31:0] mpls_label0;
        logic [31:0] mpls_label1;
        logic [3:0]  ip_version;
        logic [3:0]  ip_ihl;
        logic [5:0]  ip_dscp;
        logic [1:0]  ip_ecn;
        logic [15:0] ip_length;
        logic [15:0] ip_id;
        logic [2:0]  ip_flags;
        logic [12:0] ip_frag_ofs;
        logic [7:0]  ip_ttl;
        logic [7:0]  ip_prot;
        logic [15:0] ip_hdr_chk;
        logic [31:0] ip_sa;
        logic [31:0] ip_da;
        logic [1:0]  pkt_blen_mode;
        logic [13:0] pkt_blen_min;
        logic [13:0] pkt_blen_max;
        logic [1:0]  payload_mode;
        logic [7:0]  payload_value;
    } flow_def_type;

    localparam logic [15:0] TYPE_DOT1Q = 16'h8100;
    localparam logic [15:0] TYPE_MPLS  = 16'h8847;
    localparam logic [15:0] TYPE_IPV4  = 16'h0800;

    localparam flow_def_type default_flow_def = '{
        mac_da             : 48'h101010101010       ,
        mac_sa             : 48'h202020202020       ,
        ether_type         : TYPE_MPLS              ,
        vlan_valid         : 1'b0                   ,
        vlan_tag           : {TYPE_DOT1Q, 16'd100}  ,
        num_mpls_labels    : 2'd2                   ,
        mpls_label0        : 32'hAAAAA001           ,
        mpls_label1        : 32'h55555101           ,
        ip_version         : 4'h4                   ,
        ip_ihl             : 4'h5                   ,
        ip_dscp            : 6'd0                   ,
        ip_ecn             : 2'd0                   ,
        ip_length          : 16'd100                ,
        ip_id              : 16'd100                ,
        ip_flags           : 16'd0                  ,
        ip_frag_ofs        : 3'd0                   ,
        ip_ttl             : 13'd0                  ,
        ip_prot            : 8'd1                   ,
        ip_hdr_chk         : 8'd6                   ,
        ip_sa              : 32'hAAAAAAAA           ,
        ip_da              : 32'hBBBBBBBB           ,
        pkt_blen_mode      : 2'b0                   ,
        pkt_blen_min       : 14'd100                ,
        pkt_blen_max       : 14'd2000               ,
        payload_mode       : 2'd0                   ,
        payload_value      : 8'h55
    };

    localparam int NUM_FLOWS            = 32;
    localparam int NUM_FLOWS_LOG        = $clog2(NUM_FLOWS);
    localparam int CORE_CLOCK_PERIOD_PS = CORE_CLK_PERIOD * 1000;

    localparam int FLOW_DEF_BITS        = $bits(flow_def_type);
    localparam int FLOW_DEF_32BIT_WORDS = U_INT_CEIL_DIV(FLOW_DEF_BITS, 32);

    enum {
        ADDR_PKT_GEN_PARAMS = AVMM_COMMON_NUM_REGS,
        ADDR_PKT_GEN_CNTR_STAT,
        ADDR_PKT_GEN_GEN_TX_PKT_CNT0,
        ADDR_PKT_GEN_GEN_TX_PKT_CNT1,
        ADDR_PKT_GEN_GEN_TX_BYTE_CNT0,
        ADDR_PKT_GEN_GEN_TX_BYTE_CNT1,
        ADDR_PKT_GEN_FLOW_TX_PKT_CNT0,
        ADDR_PKT_GEN_FLOW_TX_PKT_CNT1,
        ADDR_PKT_GEN_FLOW_TX_BYTE_CNT0,
        ADDR_PKT_GEN_FLOW_TX_BYTE_CNT1,
        ADDR_PKT_GEN_TX_CON,
        ADDR_PKT_GEN_SHAPER_CON,
        ADDR_PKT_GEN_TX_CNTR_CON,
        ADDR_PKT_GEN_FLOW_DEF_CON,
        ADDR_PKT_GEN_FLOW_DEF_DATA,
        NUM_REGS = ADDR_PKT_GEN_FLOW_DEF_DATA + FLOW_DEF_32BIT_WORDS
     } ADDR_OFFSETS;

    localparam int SAMPLE_GEN_CNTS      = 1;
    localparam int SAMPLE_ALL_FLOW_CNTS = 2;
    localparam int SAMPLE_SEL_FLOW_CNT  = 4;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    int                             send_packet_byte_length;
    logic [0:MTU_BYTES*8-1]         send_packet_data;
    ingress_metadata_t              send_packet_user;
    bit                             send_packet_req;
    bit                             send_packet_busy;
    int                             send_packet_count;

    ingress_metadata_t              packet_in_metadata;
    vnp4_wrapper_metadata_t         packet_out_metadata;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Clocks and Resets


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) core_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) peripheral_sreset_ifc ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS Interfaces


    AXIS_int #(
        .USER_WIDTH ( INGRESS_METADATA_WIDTH    ),
        .DATA_BYTES ( 8                         )
    ) pkt_gen_out (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( INGRESS_METADATA_WIDTH    ),
        .DATA_BYTES ( 8                         )
    ) pkt_gen_out_byte_swapped (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( INGRESS_METADATA_WIDTH    ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_packet_in_byte_swapped (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( INGRESS_METADATA_WIDTH    ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_packet_in_no_metadata (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( INGRESS_METADATA_WIDTH    ),
        .DATA_BYTES ( VNP4_DATA_BYTES           )
    ) dut_packet_in (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .USER_WIDTH ( VNP4_WRAPPER_METADATA_WIDTH   ),
        .DATA_BYTES ( VNP4_DATA_BYTES               )
    ) dut_packet_out (
        .clk     (core_clk_ifc.clk                                     ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXI4Lite Interfaces


    AXI4Lite_int #(
        .DATALEN    ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_DATA_WIDTH ),
        .ADDRLEN    ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_ADDR_WIDTH )
    ) table_config (
        .clk     ( core_clk_ifc.clk                                     ),
        .sresetn ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


   AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();


    //////////////////////////////////////////////////////////////////////////
    // Logic Implemenatation


    // simulation clock
    always #(CORE_CLK_PERIOD/2) core_clk_ifc.clk <= ~core_clk_ifc.clk;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION:  AVMM driver class

    avmm_m_test_driver #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm_driver;

    `MAKE_AVMM_MONITOR(avmm_monitor, avmm);

    generate
        if (PROTOCOL_CHECK) begin : gen_protocol_check
            avmm_protocol_check #(
            ) protocol_check_inst (
                .clk_ifc    ( core_clk_ifc              ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor      )
            );
        end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: A4L Config Driver


    AXI4Lite_master #(
        .DATALEN ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_DATA_WIDTH ),
        .ADDRLEN ( P4_ROUTER_VNP4_FRR_T1_ECP_TINY_BCAM_PKG::S_AXI_ADDR_WIDTH )
    ) config_master (
        .clk     (core_clk_ifc.clk                                      ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH  )
    );

    AXI4Lite_master_module config_master_inst (
        .control  ( config_master ),
        .o        ( table_config  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Generator


    network_packet_generator #(
        .CORE_CLOCK_PERIOD_PS   ( CORE_CLOCK_PERIOD_PS  ),
        .NUM_FLOWS              ( NUM_FLOWS             )
    ) pkt_gen (
        .avmm_clk_ifc               ( core_clk_ifc            ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc   ),
        .avmm                       ( avmm                    ),
        .packet_out                 ( pkt_gen_out             )
    );

    axis_endian_swap byte_swap_pkt_gen_out (
        .axis_in    ( pkt_gen_out               ),
        .axis_out   ( pkt_gen_out_byte_swapped  )
    );

    axis_adapter_wrapper width_conv(
        .axis_in    ( pkt_gen_out_byte_swapped      ),
        .axis_out   ( dut_packet_in_no_metadata     )
    );

    // axis_endian_swap byte_swap_dut_packet_in (
    //     .axis_in    ( dut_packet_in_byte_swapped    ),
    //     .axis_out   ( dut_packet_in_no_metadata     )
    // );

    always_comb begin
        packet_in_metadata.ingress_port = 10'd1;
        packet_in_metadata.byte_length  = 14'd100;

        dut_packet_in_no_metadata.tready    = dut_packet_in.tready;
        dut_packet_in.tvalid                = dut_packet_in_no_metadata.tvalid;
        dut_packet_in.tdata                 = dut_packet_in_no_metadata.tdata;
        dut_packet_in.tstrb                 = dut_packet_in_no_metadata.tstrb;
        dut_packet_in.tkeep                 = dut_packet_in_no_metadata.tkeep;
        dut_packet_in.tlast                 = dut_packet_in_no_metadata.tlast;
        dut_packet_in.tid                   = dut_packet_in_no_metadata.tid;
        dut_packet_in.tdest                 = dut_packet_in_no_metadata.tdest;
        dut_packet_in.tuser                 = packet_in_metadata;
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: DUT


    p4_router_vnp4_wrapper_select #(
        .VNP4_DATA_BYTES    ( VNP4_DATA_BYTES           ),
        .VNP4_IP_SEL        ( FRR_T1_ECP_TINY_BCAM      )
    ) dut (
        .cam_clk            ( dut_packet_out.clk        ),
        .cam_sresetn        ( dut_packet_out.sresetn    ),
        .control            ( table_config              ),
        .packet_data_in     ( dut_packet_in             ),
        .packet_data_out    ( dut_packet_out            ),
        .ram_ecc_event      (                           )
    );

    assign packet_out_metadata = dut_packet_out.tuser;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Sink


    assign dut_packet_out.tready = (core_sreset_ifc.reset == core_sreset_ifc.ACTIVE_HIGH) ? 1'b0 : 1'b1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks


    task automatic write_table(
        input int           table_offset,
        input logic [4:0]   entry_id,
        input logic [127:0] key,
        input int           key_bits,
        input logic [255:0] value,
        input int           value_bits
    );
    begin
        const int BYTES_PER_KEY        = (key_bits + 7) / 8;
        const int WORDS_PER_KEY        = (key_bits + 31) / 32;
        // The action ID and params must be written to the registers starting from
        // TinyBcamAvmmAddrs.CAM_DATA0 + 2*words_per_key, where the factor of 2 comes from
        // leaving room for both the key and the mask (which is unused in the BCAM,
        // as opposed to TCAM)
        const int VALUE_BYTE_OFFSET    = 2 * BYTES_PER_KEY;
        const int VALUE_WORD_OFFSET    = VALUE_BYTE_OFFSET / REG_WIDTH_BYTES;
        const int WORDS_PER_VALUE      = (value_bits + (VALUE_BYTE_OFFSET % REG_WIDTH_BYTES) + 31) / 32;
        const int NUM_ROWS             = 32;

        automatic logic [1:0]   resp;
        automatic int           rdata;
        automatic logic [255:0] value_adj = value << (VALUE_BYTE_OFFSET % 4 * 8);

        // Validate entry_id
        if (entry_id < 0 || entry_id >= NUM_ROWS) begin
            $fatal("Entry ID %d is out of range. must be between 0 and %d", entry_id, NUM_ROWS-1);
        end

        // Check if this entry is already occupied
        // config_master.write_data(
        //     .addr ( table_offset + ADDR_CAM_ENTRY_ID ),
        //     .data ( entry_id ),
        //     .resp ( resp )
        // );

        // config_master.read_data(
        //     .addr ( table_offset + ADDR_CAM_CTRL ),
        //     .data ( rdata ),
        //     .resp ( resp )
        // );
        // config_master.write_data(
        //     .addr ( table_offset + ADDR_CAM_CTRL ),
        //     .data ( rdata | MASK_CTRL_RD_BIT ),
        //     .resp ( resp )
        // );
        // config_master.read_data(
        //     .addr ( table_offset + ADDR_CAM_CTRL ),
        //     .data ( rdata ),
        //     .resp ( resp )
        // );

        // if (rdata & MASK_CTRL_ENTRY_IN_USE_BIT) begin
        //     $fatal("entry id %d is already in use.", entry_id);
        // end

        for (int i=0; i<WORDS_PER_KEY; i++) begin
            config_master.write_data(
                .addr ( table_offset + ADDR_CAM_DATA0 + REG_WIDTH_BYTES * i ),
                .data ( key[32*i +: 32] ),
                .resp ( resp )
            );
        end

        for (int i=0; i<WORDS_PER_VALUE; i++) begin
            config_master.write_data(
                .addr ( table_offset + ADDR_CAM_DATA0 + (VALUE_WORD_OFFSET * REG_WIDTH_BYTES) + REG_WIDTH_BYTES * i ),
                .data ( value_adj[32*i +: 32] ),
                .resp ( resp )
            );
        end

        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_ENTRY_ID ),
            .data ( entry_id ),
            .resp ( resp )
        );

        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_CTRL ),
            .data ( MASK_CTRL_WR_BIT & MASK_CTRL_ENTRY_IN_USE_BIT ),
            .resp ( resp )
        );

        rdata = MASK_CTRL_WR_BIT;
        while (rdata & MASK_CTRL_WR_BIT) begin
            config_master.read_data(
                .addr ( table_offset + ADDR_CAM_CTRL ),
                .data ( rdata ),
                .resp ( resp )
            );
        end

        ///
        $display("read back regs");
        for (int i=0; i<24; i++) begin
            config_master.read_data(
                .addr ( table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES ),
                .data ( rdata ),
                .resp ( resp )
            );
            $display("%h : %h", table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES, rdata);
        end

        $display("read a different entry");
        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_ENTRY_ID ),
            .data ( entry_id + 1 ),
            .resp ( resp )
        );
        config_master.read_data(
            .addr ( table_offset + ADDR_CAM_CTRL ),
            .data ( rdata ),
            .resp ( resp )
        );
        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_CTRL ),
            .data ( rdata | MASK_CTRL_RD_BIT ),
            .resp ( resp )
        );
        for (int i=0; i<24; i++) begin
            config_master.read_data(
                .addr ( table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES ),
                .data ( rdata ),
                .resp ( resp )
            );
            $display("%h : %h", table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES, rdata);
        end

        $display("read the entry you just wrote");
        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_ENTRY_ID ),
            .data ( entry_id ),
            .resp ( resp )
        );
        config_master.read_data(
            .addr ( table_offset + ADDR_CAM_CTRL ),
            .data ( rdata ),
            .resp ( resp )
        );
        config_master.write_data(
            .addr ( table_offset + ADDR_CAM_CTRL ),
            .data ( rdata | MASK_CTRL_RD_BIT ),
            .resp ( resp )
        );
        for (int i=0; i<24; i++) begin
            config_master.read_data(
                .addr ( table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES ),
                .data ( rdata ),
                .resp ( resp )
            );
            $display("%h : %h", table_offset + ADDR_CAM_CTRL + i * REG_WIDTH_BYTES, rdata);
        end
    end
    endtask

    task automatic write_intf_map_table(
        input logic [4:0]  entry_id,
        input logic [9:0]  key_ingress_port,
        input logic [1:0]  action_id,
        input logic [31:0] param_vrf_id,
        input logic [11:0] param_vlan_id
    );
    begin
        //TODO(sgass) find a way to import this from IP output products
        const int TABLE_OFFSET         = ADDR_INTF_MAP;
        const int KEY_BITS             = 10;
        const int ACTION_ID_BITS       = 2;
        const int ACTION_PARAM_BITS    = 46;
        const int NUM_ROWS             = 32;

        const int ACTION_ID_MD_SET     = 0;
        const int ACTION_ID_DROP       = 1;
        const int ACTION_ID_NO_ACTION  = 2;

        write_table(
            .table_offset   ( ADDR_INTF_MAP         ),
            .entry_id       ( entry_id              ),
            .key            ( key_ingress_port      ),
            .key_bits       ( KEY_BITS              ),
            .value          ( {param_vlan_id,
                              param_vrf_id,
                              action_id}
                            ),
            .value_bits     ( ACTION_PARAM_BITS     )
        );
    end
    endtask

    task automatic write_lfib_table(
        input logic [4:0]  entry_id,
        input logic [19:0] key_mpls_label,
        input logic [2:0]  action_id,
        input logic [19:0] param_mpls_label_out,
        input logic [47:0] param_mac_sa,
        input logic [47:0] param_mac_da,
        input logic [31:0] param_vrf_id,
        input logic [9:0]  param_ingress_port
    );
    begin
        const int TABLE_OFFSET          = ADDR_LFIB;
        const int KEY_BITS              = 20;
        const int ACTION_ID_BITS        = 3;
        const int ACTION_PARAM_BITS     = 161;
        const int NUM_ROWS              = 32;

        const int ACTION_ID_MPLS_POP    = 0;
        const int ACTION_ID_LSR_SWAP    = 1;
        const int ACTION_ID_LSR_NOOP    = 2;
        const int ACTION_ID_DROP        = 3;
        const int ACTION_ID_NO_ACTION   = 4;

        write_table(
            .table_offset   ( ADDR_LFIB                 ),
            .entry_id       ( entry_id                  ),
            .key            ( key_mpls_label            ),
            .key_bits       ( KEY_BITS                  ),
            .value          ( {param_mpls_label_out,
                               param_mac_sa,
                               param_mac_da,
                               param_vrf_id,
                               param_ingress_port,
                               action_id}
                            ),
            .value_bits     ( ACTION_PARAM_BITS         )
        );
    end
    endtask

    task automatic write_ipv4_fib_ingress_table(
        input logic [4:0]  entry_id,
        input logic [31:0] key_ip_da,
        input logic [31:0] key_vrf_id,
        input logic [2:0]  action_id,
        input logic [19:0] param_mpls_vpn_label,
        input logic [19:0] param_mpls_transport_label,
        input logic [47:0] param_mac_sa,
        input logic [47:0] param_mac_da,
        input logic [9:0]  param_ingress_port
    );
    begin
        const int TABLE_OFFSET          = ADDR_IPV4_FIB_INGRESS;
        const int KEY_BITS              = 64;
        const int ACTION_ID_BITS        = 3;
        const int ACTION_PARAM_BITS     = 149;
        const int NUM_ROWS              = 32;

        const int ACTION_ID_LOCAL_TX        = 0;
        const int ACTION_ID_LER_SINGLE_PUSH = 1;
        const int ACTION_ID_LER_PUSH        = 2;
        const int ACTION_ID_DROP            = 3;
        const int ACTION_ID_NO_ACTION       = 4;

        automatic logic [148:0] value = '0;

        case (action_id)
            ACTION_ID_LOCAL_TX : begin
                value = {param_mac_sa,
                         param_mac_da,
                         param_ingress_port,
                         action_id};
            end

            ACTION_ID_LER_PUSH | ACTION_ID_LER_SINGLE_PUSH : begin
                value = {param_mpls_vpn_label,
                         param_mpls_transport_label,
                         param_mac_sa,
                         param_mac_da,
                         param_ingress_port,
                         action_id};
            end
            default: value = '0;
        endcase

        write_table(
            .table_offset   ( ADDR_IPV4_FIB_INGRESS     ),
            .entry_id       ( entry_id                  ),
            .key            ( {key_ip_da, key_vrf_id}   ),
            .key_bits       ( KEY_BITS                  ),
            .value          ( value                     ),
            .value_bits     ( ACTION_PARAM_BITS         )
        );

    end
    endtask

    task automatic write_cmp_ipv4_fib_table(
        input logic [4:0]  entry_id,
        input logic [9:0]  key_ingress_port,
        input logic [31:0] key_ip_da,
        input logic [31:0] key_vrf_id,
        input logic [2:0]  action_id,
        input logic [11:0] param_vlan_id
    );
    begin
        const int TABLE_OFFSET          = ADDR_CMP_IPV4_FIB;
        const int KEY_BITS              = 74;
        const int ACTION_ID_BITS        = 2;
        const int ACTION_PARAM_BITS     = 14;
        const int NUM_ROWS              = 32;

        const int ACTION_ID_TAG_DOT1Q   = 0;
        const int ACTION_ID_DROP        = 1;
        const int ACTION_ID_NO_ACTION   = 2;

        write_table(
            .table_offset   ( ADDR_CMP_IPV4_FIB             ),
            .entry_id       ( entry_id                      ),
            .key            ( {key_ingress_port, key_ip_da} ),
            .key_bits       ( KEY_BITS                      ),
            .value          ( {param_vlan_id,
                               action_id}
                            ),
            .value_bits     ( ACTION_PARAM_BITS             )
        );
    end
    endtask

    task automatic write_cmp_mac_fib_table(
        input logic [4:0]  entry_id,
        input logic [47:0] key_mac_da,
        input logic [9:0]  key_ingress_port,
        input logic [2:0]  action_id,
        input logic [11:0] param_vlan_id
    );
    begin
        const int TABLE_OFFSET          = ADDR_CMP_MAC_FIB;
        const int KEY_BITS              = 58;
        const int ACTION_ID_BITS        = 2;
        const int ACTION_PARAM_BITS     = 14;
        const int NUM_ROWS              = 32;

        const int ACTION_ID_TAG_DOT1Q   = 0;
        const int ACTION_ID_DROP        = 1;
        const int ACTION_ID_NO_ACTION   = 2;

        write_table(
            .table_offset   ( ADDR_CMP_MAC_FIB                  ),
            .entry_id       ( entry_id                          ),
            .key            ( {key_mac_da, key_ingress_port}    ),
            .key_bits       ( KEY_BITS                          ),
            .value          ( {param_vlan_id,
                               action_id}
                            ),
            .value_bits     ( ACTION_PARAM_BITS                 )
        );
    end
    endtask

    task automatic write_vlan_map_table(
        input logic [4:0]  entry_id,
        input logic [11:0] key_vlan_id,
        input logic [2:0]  action_id,
        input logic [9:0]  param_ingress_port
    );
    begin
        const int TABLE_OFFSET          = ADDR_VLAN_MAP;
        const int KEY_BITS              = 12;
        const int ACTION_ID_BITS        = 2;
        const int ACTION_PARAM_BITS     = 12;
        const int NUM_ROWS              = 32;

        const int ACTION_ID_STRIP_DOT1Q = 0;
        const int ACTION_ID_DROP        = 1;
        const int ACTION_ID_NO_ACTION   = 2;

        write_table(
            .table_offset   ( ADDR_VLAN_MAP         ),
            .entry_id       ( entry_id              ),
            .key            ( key_vlan_id           ),
            .key_bits       ( KEY_BITS              ),
            .value          ( {param_ingress_port,
                               action_id}
                            ),
            .value_bits     ( ACTION_PARAM_BITS     )
        );
    end
    endtask

    task automatic avmm_write(
        input logic [avmm.ADDRLEN-1:0] avmm_addr,
        input logic [avmm.DATALEN-1:0] avmm_data
    );
    begin
        automatic logic   [avmm.DATALEN-1:0]    avmm_data_queue[$];
        automatic logic   [avmm.BURSTLEN-1:0]   avmm_burstcnt;
        automatic logic   [avmm.DATALEN/8-1:0]  avmm_byteen_queue[$];
        automatic logic   [1:0]                 avmm_resp;

        avmm_burstcnt = 1;
        avmm_data_queue.push_back(avmm_data);
        avmm_byteen_queue.push_back('1);

        avmm_driver.write_data(
            .address          ( avmm_addr << 2 ),
            .writedata_queue  ( avmm_data_queue ),
            .byteenable_queue ( avmm_byteen_queue ),
            .burstcount       ( avmm_burstcnt ),
            .response         ( avmm_resp )
        );
    end
    endtask

    task automatic avmm_read(
        input logic [avmm.ADDRLEN-1:0] avmm_addr,
        ref   logic [avmm.DATALEN-1:0] avmm_data
    );
    begin
        automatic logic   [avmm.DATALEN-1:0]    avmm_data_queue[$];
        automatic logic   [avmm.BURSTLEN-1:0]   avmm_burstcnt;
        automatic logic   [avmm.DATALEN/8-1:0]  avmm_byteen_queue;
        automatic logic   [1:0]                 avmm_resp[$];

        avmm_burstcnt = 1;
        avmm_byteen_queue = '1;

        avmm_driver.read_data((avmm_addr << 2), avmm_data_queue, avmm_byteen_queue, avmm_burstcnt, avmm_resp);
        avmm_data = avmm_data_queue.pop_front();
        `CHECK_EQUAL(avmm_resp.pop_front(), avmm.RESPONSE_OKAY);
    end
    endtask

    task automatic write_flow_def(
        input logic [15:0]  flow_id,
        input flow_def_type flow_def
    );
    begin
        automatic logic [FLOW_DEF_BITS-1:0] flow_def_vec = flow_def;
        avmm_write(ADDR_PKT_GEN_FLOW_DEF_CON, {flow_id, 4'h0 });
        for (int i=0; i<FLOW_DEF_32BIT_WORDS; i++) begin
            avmm_write(ADDR_PKT_GEN_FLOW_DEF_DATA+i, flow_def_vec[FLOW_DEF_BITS-1 - 32*i -: 32]);
        end
        avmm_write(ADDR_PKT_GEN_FLOW_DEF_CON, {flow_id, 4'h1 });
        avmm_write(ADDR_PKT_GEN_FLOW_DEF_CON, {flow_id, 4'h0 });
    end
    endtask

    task automatic start_generator(
        input logic        finite_tx,
        input logic [27:0] tx_count
    );
        avmm_write(ADDR_PKT_GEN_TX_CON, {tx_count, 2'b0, finite_tx, 1'b1});
    endtask

    task automatic stop_generator;
        avmm_write(ADDR_PKT_GEN_TX_CON, 32'h0);
    endtask

    task automatic set_shaper(
        input real rate_kbps
    );
        automatic logic [31:0] clock_period_ps;
        automatic logic [31:0] shaper_credit;

        avmm_read(ADDR_PKT_GEN_PARAMS, clock_period_ps);
        //                      kb/s      b/s    B/s    B/clk
        shaper_credit = $rtoi(rate_kbps * 1000 / 8.0 * (clock_period_ps / 1e12) * 2**16);
        avmm_write(ADDR_PKT_GEN_SHAPER_CON, shaper_credit);
    endtask

    task automatic get_vnp4_build_info;
    begin

        automatic logic [1:0]   resp;
        automatic int           rdata;

        config_master.read_data(
            .addr ( ADDR_BUILDINFO ),
            .data ( rdata ),
            .resp ( resp )
        );
        $display("Revision Register: %h", rdata);

        config_master.read_data(
            .addr ( ADDR_BUILDINFO + REG_WIDTH_BYTES ),
            .data ( rdata ),
            .resp ( resp )
        );
        $display("Params Register: %h", rdata);
        $display("packet_rate:     %d", rdata[9:0]);
        $display("core_clock_mhz:  %d", rdata[19:10]);
        $display("axi_clock_mhz:   %d", rdata[29:20]);
    end
    endtask

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            core_clk_ifc.clk  = 1'b0;
            send_packet_req   = 1'b0;
            send_packet_count = 0;

            avmm_driver = new (
                .clk_ifc                 ( core_clk_ifc            ),
                .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
                .avmm                    ( avmm                    )
            );
        end

        `TEST_CASE_SETUP begin

            core_sreset_ifc.reset         = core_sreset_ifc.ACTIVE_HIGH;
            interconnect_sreset_ifc.reset = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset   = peripheral_sreset_ifc.ACTIVE_HIGH;
            repeat (2) @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset         = ~core_sreset_ifc.ACTIVE_HIGH;
            interconnect_sreset_ifc.reset = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset   = ~peripheral_sreset_ifc.ACTIVE_HIGH;

        end

        // Set CIR and CBS to min so that all packets are drop marked
        `TEST_CASE("smoke") begin

            automatic ingress_metadata_t      metadata_in;
            automatic vnp4_wrapper_metadata_t expected_metadata_out;
            automatic flow_def_type           flow_def = default_flow_def;
            automatic int                     packet_count = 0;
            automatic logic [avmm.DATALEN-1:0] rdata;

            localparam int NUM_PACKETS_TO_SEND = 1;
            localparam int NUM_FLOWS           = 1;

            repeat (10) @(posedge core_clk_ifc.clk);

            get_vnp4_build_info;

            // write_intf_map_table(
            //         .entry_id           ( 0 ),
            //         .key_ingress_port   ( 10'd1 ),
            //         .action_id          ( 0 ),
            //         .param_vrf_id       ( 32'h12345678 ),
            //         .param_vlan_id      ( 12'd100 )
            //     );


            write_lfib_table(
                .entry_id               ( 1 ),
                .key_mpls_label         ( default_flow_def.mpls_label0[31 -: 20] ),
                .action_id              ( 4 ),
                .param_mpls_label_out   ( 20'h12345 ),
                .param_mac_sa           ( default_flow_def.mac_sa ),
                .param_mac_da           ( default_flow_def.mac_da ),
                .param_vrf_id           ( 32'h12345678 ),
                .param_ingress_port     ( 10'h0 )
            );

            // write_ipv4_fib_ingress_table(
            //     .entry_id                       ( 0 ),
            //     .key_ip_da                      ( default_flow_def.ip_da ),
            //     .key_vrf_id                     ( 32'h12345678 ),
            //     .action_id                      ( 0 ),
            //     .param_mpls_vpn_label           ( 20'h12345 ),
            //     .param_mpls_transport_label     ( 20'h55555 ),
            //     .param_mac_sa                   ( default_flow_def.mac_sa ),
            //     .param_mac_da                   ( default_flow_def.mac_da ),
            //     .param_ingress_port             ( 0 )
            // );

            // write_cmp_ipv4_fib_table(
            //     .entry_id           ( 0 ),
            //     .key_ingress_port   ( 0 ),
            //     .key_ip_da          ( default_flow_def.ip_da ),
            //     .key_vrf_id         ( 32'h12345678),
            //     .action_id          ( 0 ),
            //     .param_vlan_id      ( 12'd100 )
            // );

            // write_cmp_mac_fib_table(
            //     .entry_id           ( 0 ),
            //     .key_mac_da         ( default_flow_def.mac_da ),
            //     .key_ingress_port   ( 0 ),
            //     .action_id          ( 0 ),
            //     .param_vlan_id      ( 12'd100 )
            // );

            // write_vlan_map_table(
            //     .entry_id           ( 0 ),
            //     .key_vlan_id        ( 12'd100 ),
            //     .action_id          ( 0 ),
            //     .param_ingress_port ( 0 )
            // );

            for (int flow=0; flow<NUM_FLOWS; flow++) begin
                // flow_def.mac_da = {6{flow[7:0]}};
                write_flow_def(flow, flow_def);
            end
            avmm_write(ADDR_PKT_GEN_FLOW_DEF_CON, {NUM_FLOWS-1, 16'd0});

            start_generator(1'b1, NUM_PACKETS_TO_SEND);

            // while(packet_count < NUM_PACKETS_TO_SEND) begin
            //     @(posedge core_clk_ifc.clk);
            //     #1;
            //     if (dut_packet_out.tready && dut_packet_out.tvalid && dut_packet_out.tlast) begin
            //         packet_count += 1;
            //     end
            // end

            repeat (200) @(posedge core_clk_ifc.clk);

            stop_generator;
        end
    end

    `WATCHDOG(500us);

endmodule
