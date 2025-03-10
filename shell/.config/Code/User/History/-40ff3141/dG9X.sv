// CONFIDENTIAL
// Copyright (c) 2025 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_make_monitors.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for network_packet_generator.
 */
module network_packet_generator_tb ();

    import AVMM_COMMON_REGS_PKG::*;
    import AVMM_TEST_DRIVER_PKG::*;
    import VITIS_NET_P4_NETWORK_PACKET_UTILS_PARSER_PKG::*;
    import IPV4_CHECKSUM_TB_PKG::*;

    parameter  bit        PROTOCOL_CHECK       = 0;

    parameter  int        DATALEN              = 32;
    parameter  int        ADDRLEN              = 15;
    parameter  int        BURSTLEN             = 11;
    parameter  int        BURST_CAPABLE        = 0;
    parameter  int        NUM_FLOWS            = 10;
    parameter  int        CORE_CLOCK_PERIOD_PS = 6400;
    parameter  int        AVMM_CLOCK_PERIOD_PS = 10000;

    import UTIL_INTS::U_INT_CEIL_DIV;
    import AVMM_COMMON_REGS_PKG::*;

    localparam int TOTAL_REGS = AVMM_COMMON_NUM_REGS;

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

    localparam int FLOW_DEF_BITS        = $bits(flow_def_type);
    localparam int FLOW_DEF_32BIT_WORDS = U_INT_CEIL_DIV(FLOW_DEF_BITS, 32);
    localparam int INPUT_REG_OFFSET     = AVMM_COMMON_NUM_REGS;
    localparam int FLOW_DEF_CON_OFFSET  = AVMM_COMMON_NUM_REGS + 1;
    localparam int FLOW_DEF_DAT_OFFSET  = AVMM_COMMON_NUM_REGS + 2;

    enum {
        ADDR_PARAMS = AVMM_COMMON_NUM_REGS,
        ADDR_CNTR_STAT,
        ADDR_GEN_TX_PKT_CNT0,
        ADDR_GEN_TX_PKT_CNT1,
        ADDR_GEN_TX_BYTE_CNT0,
        ADDR_GEN_TX_BYTE_CNT1,
        ADDR_FLOW_TX_PKT_CNT0,
        ADDR_FLOW_TX_PKT_CNT1,
        ADDR_FLOW_TX_BYTE_CNT0,
        ADDR_FLOW_TX_BYTE_CNT1,
        ADDR_TX_CON,
        ADDR_SHAPER_CON,
        ADDR_TX_CNTR_CON,
        ADDR_FLOW_DEF_CON,
        ADDR_FLOW_DEF_DATA,
        NUM_REGS = ADDR_FLOW_DEF_DATA + FLOW_DEF_32BIT_WORDS
     } ADDR_OFFSETS;

    localparam int SAMPLE_GEN_CNTS = 1;
    localparam int SAMPLE_ALL_FLOW_CNTS = 2;
    localparam int SAMPLE_SEL_FLOW_CNT = 4;

    localparam int NUM_FLOWS_LOG = $clog2(NUM_FLOWS);

    localparam logic [15:0] TYPE_DOT1Q = 16'h8100;
    localparam logic [15:0] TYPE_MPLS  = 16'h8847;
    localparam logic [15:0] TYPE_IPV4  = 16'h0800;

    localparam flow_def_type default_flow_def = '{
        mac_da             : 48'hAAAAAAAAAAAA       ,
        mac_sa             : 48'hBBBBBBBBBBBB       ,
        ether_type         : TYPE_MPLS              ,
        vlan_valid         : 1'b1                   ,
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
        pkt_blen_min       : 14'd64                 ,
        pkt_blen_max       : 14'd2000               ,
        payload_mode       : 2'd0                   ,
        payload_value      : 8'h55
    };


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    function automatic int keep_to_bytes(
        input int tkeep
    );
    begin
        automatic int bytes = 0;
        for (int i=0; i<32; i++) begin
            bytes += tkeep[i];
        end
        return bytes;
    end
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals


    longint tb_gen_packet_count;
    longint tb_gen_byte_count;
    longint tb_flow_packet_counts [NUM_FLOWS-1:0];
    longint tb_flow_byte_counts   [NUM_FLOWS-1:0];

    int     clk_cnt;
    int     byte_cnt;
    bit     start_measurement;
    real    measured_rate_bpc;
    real    measured_rate_kbps;

    logic   core_clk;
    logic   core_sresetn;

    logic            metadata_in_valid;
    USER_META_DATA_T metadata_in;
    logic            metadata_out_valid;
    USER_META_DATA_T metadata_out;
    logic            generator_out_sop;

    USER_META_DATA_T rx_hdr_metadata [$];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and Interfaces


    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ),
        .SOURCE_FREQUENCY ( 0 )
    ) avmm_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) interconnect_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )
    ) peripheral_sreset_ifc ();

    AXIS_int #(
        .DATA_BYTES ( 8             ),
        .USER_WIDTH ( NUM_FLOWS_LOG )
    ) generator_out (
        .clk     ( core_clk     ),
        .sresetn ( core_sresetn )
    );

    AXIS_int #(
        .DATA_BYTES ( 8         )
    ) parser_out (
        .clk     ( core_clk     ),
        .sresetn ( core_sresetn )
    );

    AXI4Lite_int #(
        .DATALEN ( VITIS_NET_P4_NETWORK_PACKET_UTILS_PARSER_PKG::S_AXI_DATA_WIDTH ),
        .ADDRLEN ( VITIS_NET_P4_NETWORK_PACKET_UTILS_PARSER_PKG::S_AXI_ADDR_WIDTH )
    ) parser_axi4l (
        .clk        ( avmm_clk_ifc.clk                                                  ),
        .sresetn    ( peripheral_sreset_ifc.reset != peripheral_sreset_ifc.ACTIVE_HIGH  )
    );

    // Interface to keep track of current state of registers
    local_dut_regs_int #(
        .DATALEN    ( DATALEN    ),
        .TOTAL_REGS ( TOTAL_REGS )
    ) current_dut_regs_ifc();

    AvalonMM_int #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE )
    ) avmm ();

    // AVMM driver class
    avmm_m_test_driver_to_peripheral
    #(
        .DATALEN       ( DATALEN       ),
        .ADDRLEN       ( ADDRLEN       ),
        .BURSTLEN      ( BURSTLEN      ),
        .BURST_CAPABLE ( BURST_CAPABLE ),
        .TOTAL_REGS    ( TOTAL_REGS    )
    ) avmm_driver;

    `MAKE_AVMM_MONITOR(avmm_monitor, avmm);

    generate
        if (PROTOCOL_CHECK) begin : gen_protocol_check
            avmm_protocol_check #(
            ) protocol_check_inst (
                .clk_ifc    ( avmm_clk_ifc      ),
                .sreset_ifc ( interconnect_sreset_ifc   ),
                .avmm       ( avmm_monitor.Monitor )
            );
        end
    endgenerate


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Packet and Byte Counters


    always_ff @(posedge generator_out.clk) begin
        if (!generator_out.sresetn) begin
            tb_gen_packet_count    <= 0;
            tb_gen_byte_count      <= 0;
            tb_flow_packet_counts  <= '{default: 0};
            tb_flow_byte_counts    <= '{default: 0};
        end else begin
            if (generator_out.tvalid && generator_out.tready) begin
                if (generator_out.tlast) begin
                    tb_gen_packet_count++;
                    tb_flow_packet_counts[generator_out.tuser]++;
                end
                tb_gen_byte_count                        += keep_to_bytes(generator_out.tkeep);
                tb_flow_byte_counts[generator_out.tuser] += keep_to_bytes(generator_out.tkeep);
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Rate Measurement


    assign measured_rate_bpc  = clk_cnt == 0 ? 0.0 : $itor(byte_cnt) / $itor(clk_cnt);
    assign measured_rate_kbps = measured_rate_bpc * 8.0 / 1000.0 / (CORE_CLOCK_PERIOD_PS / 1e12);

    always_ff @(posedge generator_out.clk) begin
        if (!generator_out.sresetn) begin
            clk_cnt <= 0;
            byte_cnt <= 0;
            start_measurement <= 1'b0;
        end else begin
            start_measurement <= start_measurement | (generator_out.tvalid & generator_out.tready);

            if (start_measurement) begin
                clk_cnt <= clk_cnt + 1;
                if (generator_out.tvalid && generator_out.tready) begin
                    byte_cnt <= byte_cnt + keep_to_bytes(generator_out.tkeep);
                end
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Packet Parser


    axi4lite_nul_master parser_axi4l_null_master(
        .axi( parser_axi4l )
    );

    `MAKE_AXIS_MONITOR(generator_out_monitor, generator_out);

    axis_sop gen_out_sop_inst(
        .axis ( generator_out_monitor ),
        .sop  ( generator_out_sop     )
    );

    assign metadata_in_valid = generator_out_sop;

    vitis_net_p4_network_packet_utils_parser parser (
        .s_axis_aclk             ( core_clk              ),
        .s_axis_aresetn          ( core_sresetn          ),
        .s_axi_aclk              ( core_clk              ),
        .s_axi_aresetn           ( core_sresetn          ),
        .user_metadata_in        ( metadata_in           ),
        .user_metadata_in_valid  ( metadata_in_valid     ),
        .user_metadata_out       ( metadata_out          ),
        .user_metadata_out_valid ( metadata_out_valid    ),
        .s_axi_awaddr            ( parser_axi4l.awaddr   ),
        .s_axi_awvalid           ( parser_axi4l.awvalid  ),
        .s_axi_awready           ( parser_axi4l.awready  ),
        .s_axi_wdata             ( parser_axi4l.wdata    ),
        .s_axi_wstrb             ( parser_axi4l.wstrb    ),
        .s_axi_wvalid            ( parser_axi4l.wvalid   ),
        .s_axi_wready            ( parser_axi4l.wready   ),
        .s_axi_bresp             ( parser_axi4l.bresp    ),
        .s_axi_bvalid            ( parser_axi4l.bvalid   ),
        .s_axi_bready            ( parser_axi4l.bready   ),
        .s_axi_araddr            ( parser_axi4l.araddr   ),
        .s_axi_arvalid           ( parser_axi4l.arvalid  ),
        .s_axi_arready           ( parser_axi4l.arready  ),
        .s_axi_rdata             ( parser_axi4l.rdata    ),
        .s_axi_rvalid            ( parser_axi4l.rvalid   ),
        .s_axi_rready            ( parser_axi4l.rready   ),
        .s_axi_rresp             ( parser_axi4l.rresp    ),
        .m_axis_tdata            ( parser_out.tdata      ),
        .m_axis_tkeep            ( parser_out.tkeep      ),
        .m_axis_tvalid           ( parser_out.tvalid     ),
        .m_axis_tlast            ( parser_out.tlast      ),
        .m_axis_tready           ( parser_out.tready     ),
        .s_axis_tdata            ( generator_out.tdata   ),
        .s_axis_tkeep            ( generator_out.tkeep   ),
        .s_axis_tvalid           ( generator_out.tvalid  ),
        .s_axis_tlast            ( generator_out.tlast   ),
        .s_axis_tready           ( generator_out.tready  )
    );

    axis_nul_sink parser_null_sink (
        .axis ( parser_out )
    );

    always_ff @(posedge core_clk) begin
        if (!core_sresetn) begin
            rx_hdr_metadata.delete();
        end else begin
            if (metadata_out_valid) begin
                rx_hdr_metadata.push_back(metadata_out);
            end
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Device Under Test


    always #(AVMM_CLOCK_PERIOD_PS/20) avmm_clk_ifc.clk  <= ~avmm_clk_ifc.clk;
    always #(CORE_CLOCK_PERIOD_PS/20) core_clk          <= ~core_clk;

    network_packet_generator #(
        .CORE_CLOCK_PERIOD_PS   ( CORE_CLOCK_PERIOD_PS  ),
        .NUM_FLOWS              ( NUM_FLOWS             )
    ) dut (
        .avmm_clk_ifc               ( avmm_clk_ifc            ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc   ),
        .avmm                       ( avmm                    ),
        .packet_out                 ( generator_out           )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tasks


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

        avmm_driver.write_data((avmm_addr << 2), avmm_data_queue, avmm_byteen_queue, avmm_burstcnt, avmm_resp);
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
        avmm_write(ADDR_FLOW_DEF_CON, {flow_id, 4'h0 });
        for (int i=0; i<FLOW_DEF_32BIT_WORDS; i++) begin
            avmm_write(ADDR_FLOW_DEF_DATA+i, flow_def_vec[FLOW_DEF_BITS-1 - 32*i -: 32]);
        end
        avmm_write(ADDR_FLOW_DEF_CON, {flow_id, 4'h1 });
        avmm_write(ADDR_FLOW_DEF_CON, {flow_id, 4'h0 });
    end
    endtask

    task automatic start_generator(
        input logic        finite_tx,
        input logic [27:0] tx_count
    );
        avmm_write(ADDR_TX_CON, {tx_count, 2'b0, finite_tx, 1'b1});
    endtask

    task automatic stop_generator;
        avmm_write(ADDR_TX_CON, 32'h0);
    endtask

    task automatic wait_for_idle_bus;
        automatic bit busy = 1'b1;
        while (busy) begin
            busy = 1'b0;
            repeat (100) begin
                @(posedge generator_out.clk);
                #1;
                busy |= generator_out.tvalid;
            end
        end
    endtask

    task automatic read_gen_counters(
        ref logic [63:0] packet_count,
        ref logic [63:0] byte_count
    );
    begin
        automatic logic [31:0] rdat;

        avmm_write(ADDR_TX_CNTR_CON, SAMPLE_GEN_CNTS);
        avmm_write(ADDR_TX_CNTR_CON, 32'd0);
        do begin
            avmm_read(ADDR_CNTR_STAT, rdat);
            @(posedge core_clk);
            #1;
        end while (rdat);
        avmm_read(ADDR_GEN_TX_PKT_CNT0, rdat);
        packet_count[31:0] = rdat;
        avmm_read(ADDR_GEN_TX_PKT_CNT1, rdat);
        packet_count[63:32] = rdat;

        avmm_read(ADDR_GEN_TX_BYTE_CNT0, rdat);
        byte_count[31:0] = rdat;
        avmm_read(ADDR_GEN_TX_BYTE_CNT1, rdat);
        byte_count[63:32] = rdat;
    end
    endtask

    task automatic read_flow_counters(
        ref logic [63:0] packet_count [NUM_FLOWS-1:0],
        ref logic [63:0] byte_count [NUM_FLOWS-1:0]
    );
    begin
        automatic logic [31:0] rdat;

        avmm_write(ADDR_TX_CNTR_CON, SAMPLE_ALL_FLOW_CNTS);
        avmm_write(ADDR_TX_CNTR_CON, 32'd0);
        do begin
            avmm_read(ADDR_CNTR_STAT, rdat);
            @(posedge avmm_clk_ifc.clk);
            #1;
        end while (rdat);
        for (int flow=0; flow<NUM_FLOWS; flow++) begin
            avmm_write(ADDR_TX_CNTR_CON, {flow[11:0],4'd0});

            repeat (2) @(posedge avmm_clk_ifc.clk);
            #1;

            avmm_read(ADDR_FLOW_TX_PKT_CNT0, rdat);
            packet_count[flow][31:0] = rdat;
            avmm_read(ADDR_FLOW_TX_PKT_CNT1, rdat);
            packet_count[flow][63:32] = rdat;

            avmm_read(ADDR_FLOW_TX_BYTE_CNT0, rdat);
            byte_count[flow][31:0] = rdat;
            avmm_read(ADDR_FLOW_TX_BYTE_CNT1, rdat);
            byte_count[flow][63:32] = rdat;
        end
    end
    endtask

    task automatic verify_packet_and_byte_counts;
    begin
        automatic string err_str;
        automatic logic [63:0] dut_gen_packet_count;
        automatic logic [63:0] dut_gen_byte_count;
        automatic logic [63:0] dut_flow_packet_counts [NUM_FLOWS-1:0];
        automatic logic [63:0] dut_flow_byte_counts   [NUM_FLOWS-1:0];

        read_gen_counters(dut_gen_packet_count, dut_gen_byte_count);
        `CHECK_EQUAL(dut_gen_packet_count, tb_gen_packet_count);
        `CHECK_EQUAL(dut_gen_byte_count, tb_gen_byte_count);
        read_flow_counters(dut_flow_packet_counts, dut_flow_byte_counts);
        for (int flow=0; flow<NUM_FLOWS; flow++) begin
            $sformat(err_str, "flow: %d", flow);
            `CHECK_EQUAL(dut_flow_packet_counts[flow], tb_flow_packet_counts[flow], err_str);
            `CHECK_EQUAL(dut_flow_byte_counts[flow], tb_flow_byte_counts[flow], err_str);
        end
    end
    endtask

    task automatic verify_packet_header(
        input flow_def_type    flow_def,
        input USER_META_DATA_T hdr_metadata
    );
        automatic int expected_ipv4_length = flow_def.pkt_blen_min - 14;
        automatic ipv4_header_t flow_def_ipv4_header;
        `CHECK_EQUAL(hdr_metadata.mac_da            , flow_def.mac_da           );
        `CHECK_EQUAL(hdr_metadata.mac_sa            , flow_def.mac_sa           );
        `CHECK_EQUAL(hdr_metadata.ether_type        , flow_def.ether_type       );
        `CHECK_EQUAL(hdr_metadata.vlan_tag_valid    , flow_def.vlan_valid       );
        if (flow_def.vlan_valid) begin
            `CHECK_EQUAL(hdr_metadata.vlan          , flow_def.vlan_tag         );
            expected_ipv4_length -= 4;
        end
        if (flow_def.num_mpls_labels == 0) begin
            `CHECK_EQUAL(hdr_metadata.mpls_labels_valid     , 2'd0                  );
        end
        if (flow_def.num_mpls_labels >= 1) begin
            `CHECK_EQUAL(hdr_metadata.mpls_labels_valid[0]  , 1'b1                  );
            `CHECK_EQUAL(hdr_metadata.mpls0                 , flow_def.mpls_label0  );
            expected_ipv4_length -= 4;
        end
        if (flow_def.num_mpls_labels >= 2) begin
            `CHECK_EQUAL(hdr_metadata.mpls_labels_valid[1]  , 1'b1                  );
            `CHECK_EQUAL(hdr_metadata.mpls1                 , flow_def.mpls_label1  );
            expected_ipv4_length -= 4;
        end

        flow_def_ipv4_header = '{
            flow_def.ip_version,
            flow_def.ip_ihl,
            {flow_def.ip_dscp, flow_def.ip_ecn},
            expected_ipv4_length,
            flow_def.ip_id,
            flow_def.ip_flags,
            flow_def.ip_frag_ofs,
            flow_def.ip_ttl,
            flow_def.ip_prot,
            16'h0000,
            flow_def.ip_sa,
            flow_def.ip_da
        };

        `CHECK_EQUAL(hdr_metadata.ipv4_valid    , 1'b1                                          );
        `CHECK_EQUAL(hdr_metadata.ipv4_version  , flow_def.ip_version                           );
        `CHECK_EQUAL(hdr_metadata.ipv4_hdr_len  , flow_def.ip_ihl                               );
        `CHECK_EQUAL(hdr_metadata.ipv4_tos      , {flow_def.ip_dscp, flow_def.ip_ecn}           );
        `CHECK_EQUAL(hdr_metadata.ipv4_len      , expected_ipv4_length                          );
        `CHECK_EQUAL(hdr_metadata.ipv4_id       , flow_def.ip_id                                );
        `CHECK_EQUAL(hdr_metadata.ipv4_flags    , flow_def.ip_flags                             );
        `CHECK_EQUAL(hdr_metadata.ipv4_offset   , flow_def.ip_frag_ofs                          );
        `CHECK_EQUAL(hdr_metadata.ipv4_ttl      , flow_def.ip_ttl                               );
        `CHECK_EQUAL(hdr_metadata.ipv4_protocol , flow_def.ip_prot                              );
        `CHECK_EQUAL(hdr_metadata.ipv4_hdr_chk  , ipv4_checksum_gen_func(flow_def_ipv4_header)  );
        `CHECK_EQUAL(hdr_metadata.ipv4_src      , flow_def.ip_sa                                );
        `CHECK_EQUAL(hdr_metadata.ipv4_dst      , flow_def.ip_da                                );
    endtask

    task automatic set_shaper(
        input real rate_kbps
    );
        automatic logic [31:0] clock_period_ps;
        automatic logic [31:0] shaper_credit;

        avmm_read(ADDR_PARAMS, clock_period_ps);
        //                      kb/s      b/s    B/s    B/clk
        shaper_credit = $rtoi(rate_kbps * 1000 / 8.0 * (clock_period_ps / 1e12) * 2**16);
        avmm_write(ADDR_SHAPER_CON, shaper_credit);
    endtask


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk     <= 1'b0;
            core_clk             <= 1'b0;

            avmm_driver = new (
                .clk_ifc                 ( avmm_clk_ifc            ),
                .interconnect_sreset_ifc ( interconnect_sreset_ifc ),
                .peripheral_sreset_ifc   ( peripheral_sreset_ifc   ),
                .avmm                    ( avmm                    ),
                .current_dut_regs_ifc    ( current_dut_regs_ifc    )
            );
        end

        `TEST_CASE_SETUP begin
            interconnect_sreset_ifc.reset = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset   = peripheral_sreset_ifc.ACTIVE_HIGH;
            core_sresetn                  = 1'b0;

            avmm_driver.init();

            @(posedge avmm_clk_ifc.clk);
            #1;
            interconnect_sreset_ifc.reset = ~interconnect_sreset_ifc.ACTIVE_HIGH;

            @(posedge avmm_clk_ifc.clk);
            #1;
            peripheral_sreset_ifc.reset   = ~peripheral_sreset_ifc.ACTIVE_HIGH;

            @(posedge core_clk);
            #1;
            core_sresetn = 1'b1;

            avmm.byteenable = '1;
            @(posedge avmm_clk_ifc.clk);

        end

        `TEST_CASE("smoke") begin
            automatic int           packet_count = 0;
            automatic flow_def_type flow_def = default_flow_def;

            for (int flow=0; flow<NUM_FLOWS; flow++) begin
                flow_def.mac_da = {6{flow[7:0]}};
                write_flow_def(flow, flow_def);
            end
            avmm_write(ADDR_FLOW_DEF_CON, {NUM_FLOWS-1, 16'd0});

            start_generator(0, 0);

            while(packet_count < NUM_FLOWS) begin
                @(posedge core_clk);
                #1;
                if (generator_out.tready && generator_out.tvalid && generator_out.tlast) begin
                    packet_count += 1;
                end
            end
            stop_generator;
            wait_for_idle_bus;
            verify_packet_and_byte_counts;
        end

        `TEST_CASE("finite_packet_tx") begin
            automatic  flow_def_type flow_def = default_flow_def;
            localparam int           PACKETS_PER_FLOW = 10;
            localparam int           NUM_PACKETS = NUM_FLOWS * PACKETS_PER_FLOW;

            for (int flow=0; flow<NUM_FLOWS; flow++) begin
                flow_def.mac_da = {6{flow[7:0]}};
                write_flow_def(flow, flow_def);
            end
            avmm_write(ADDR_FLOW_DEF_CON, {NUM_FLOWS-1, 16'd0});

            start_generator(1'b1, NUM_PACKETS);
            wait_for_idle_bus;
            stop_generator;
            verify_packet_and_byte_counts;

            `CHECK_EQUAL(tb_gen_packet_count, NUM_PACKETS);
            for (int flow=0; flow<NUM_FLOWS; flow++) begin
                `CHECK_EQUAL(tb_flow_packet_counts[flow], NUM_PACKETS/NUM_FLOWS);
            end
        end

        `TEST_CASE("shaper") begin
            automatic int           packet_count = 0;
            automatic flow_def_type flow_def     = default_flow_def;
            automatic real          rate_kbps    = 1.25e6;

            for (int flow=0; flow<NUM_FLOWS; flow++) begin
                flow_def.mac_da = {6{flow[7:0]}};
                write_flow_def(flow, flow_def);
            end
            avmm_write(ADDR_FLOW_DEF_CON, {NUM_FLOWS-1, 16'd0});

            set_shaper(rate_kbps);
            start_generator(0, 0);

            while (packet_count < 100) begin
                if (generator_out.tready && generator_out.tvalid && generator_out.tlast) begin
                    packet_count++;
                end
                @(posedge generator_out.clk);
                #1;
            end
            `CHECK_GREATER(measured_rate_kbps, rate_kbps * 0.99);
            `CHECK_LESS(measured_rate_kbps, rate_kbps * 1.01);

            stop_generator;
        end

        `TEST_CASE("all_packet_types") begin
            localparam int              NUM_PKT_TYPES                       = 6;
            automatic  flow_def_type    flow_defs        [NUM_PKT_TYPES-1:0] = '{default: default_flow_def};
            localparam int              PACKETS_PER_FLOW                    = 10;
            localparam int              NUM_PACKETS                         = NUM_PKT_TYPES * PACKETS_PER_FLOW;
            automatic  int              packet_count = 0;

            for (int flow=0; flow<NUM_PKT_TYPES; flow++) begin
                flow_defs[flow] = default_flow_def;
                flow_defs[flow].vlan_valid = flow % 2;
                flow_defs[flow].num_mpls_labels = (flow/2) % 3;
                flow_defs[flow].ether_type = (flow_defs[flow].num_mpls_labels == 0) ? TYPE_IPV4 : TYPE_MPLS;
                // Only one lable. Use a lable where bottom-of-stack is set.
                if (flow_defs[flow].num_mpls_labels == 1) begin
                    flow_defs[flow].mpls_label0 = default_flow_def.mpls_label1;
                end
                flow_defs[flow].mac_da = {6{flow[7:0]}};
                write_flow_def(flow, flow_defs[flow]);
            end
            avmm_write(ADDR_FLOW_DEF_CON, {NUM_PKT_TYPES-1, 16'd0});

            start_generator(1'b1, NUM_PACKETS);
            wait_for_idle_bus;
            stop_generator;

            for (int pkt=0; pkt<NUM_PACKETS; pkt++) begin
                verify_packet_header(flow_defs[pkt % NUM_PKT_TYPES], rx_hdr_metadata.pop_front());
            end

            verify_packet_and_byte_counts;
            `CHECK_EQUAL(tb_gen_packet_count, NUM_PACKETS);
            for (int flow=0; flow<NUM_PKT_TYPES; flow++) begin
                `CHECK_EQUAL(tb_flow_packet_counts[flow], NUM_PACKETS/NUM_PKT_TYPES);
            end
        end
    end

    `WATCHDOG(5ms);

endmodule
