// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../../rtl/util/util_make_monitors.svh"
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * This module implements an Ethernet MPLS IPv4 packet generator with a 64-bit data path
 * ## Register Map:
 * | Offset | Register                      | Type  | Description                                             |
 * |--------|-------------------------------|-------|---------------------------------------------------------|
 * | 16     | Parameters                    | (r)   | Module parameters needed by software                    |
 * | 17     | TX Counter Status             | (r)   | Status of counter sample requests                       |
 * | 18     | Gerator TX Packet Count 0     | (r)   | [31:0]  of aggregate packet count                       |
 * | 19     | Gerator TX Packet Count 1     | (r)   | [63:32] of aggregate packet count                       |
 * | 20     | Gerator TX Byte Count 0       | (r)   | [31:0]  of aggregate byte count                         |
 * | 21     | Gerator TX Byte Count 1       | (r)   | [63:32] of aggregate byte count                         |
 * | 22     | Flow TX Packet Count 0        | (r)   | [31:0]  of per flow packet count                        |
 * | 23     | Flow TX Packet Count 1        | (r)   | [63:32] of per flow packet count                        |
 * | 24     | Flow TX Byte Count 0          | (r)   | [31:0]  of per flow byte count                          |
 * | 25     | Flow TX Byte Count 1          | (r)   | [63:32] of per flow byte count                          |
 * | 26     | TX Control                    | (r/w) | Controls when and how the generator transmits.          |
 * | 27     | Shaper Control                | (r/w) | Controls the rate of packet transmision.                |
 * | 28     | TX Counter Control            | (r/w) | Samples and selects transmit counters.                  |
 * | 29     | Flow Definition Control       | (r/w) | Index and write strobe for flow definition RAM.         |
 * | 30     | Flow Definition Write Data 0  | (r/w) | Least significant word of flow definition write data.   |
 * | 42     | Flow Definition Write Data 12 | (r/w) | Least significant word of flow definition write data.   |
 * ## Register Definitions
 * ### Parameters
 * - [31:0] Clock period in picoseconds. Used to set shaper rate.
 * ### Counter Status
 * - [0] Busy - Indicates that a counter sample request is being processed.
 * ### TX Control
 * - [31:4] Finit Packet Count - Number of packets to send if Finite Transmit is set.
 * - [1]    Finite Transmit - 0: Send packets until Transmit is deasserted 1: Send a finite number of packets.
 * - [0]    Transmit - 1: Initiates packet transmission, 0: stops packet transmission.
 * ### Shaper Control
 * - [19:16] whole part of shaper rate in bytes per clock
 * - [15:0]  fractional part of shaper rate in bytes per clock
 * ### TX Counter Control
 * - [15:4] Counter Select - determines which counter sample populates flow TX counter registers, and which counter is sampled when Sample Selected Flow Counter is asserted.
 * - [2]    Sample Selected Flow Counter - Samples the flow packet and byte counters of the flow selected by Counter Select bits.
 * - [1]    Sample All Flow Counters - Samples and clears all per flow packet and byte counters.
 * - [0]    Sample Generator Counters - Samples and clears aggregate packet and byte counters and loads the sampled counts in Generator TX Packet and Byte Count registers.
 * ### Flow Definition Control
 * - [27:16] Largest valid flow definition index.
 * - [15:4]  Flow Index - Selects the flow entry to write.
 * - [0]     Write Enable - 0 to 1 transition writes the contents of Flow Definition Write Data registers into the flow definition RAM at the address indicated by Flow Index bits in this register.
 * ### Flow Definition Write Data
 * - Flow Definition Write Data registers 0 to 11 represent the data to be written to the flow definition RAM. The fields are listed below where register 0 holds MAC DA 47:16 and so on.
 * ## Flow Definition Fields
 * | Range  | Name                      |
 * |--------|---------------------------|
 * | 47:0   | MAC DA                    |
 * | 47:0   | MAC SA                    |
 * | 15:0   | Ether type                |
 * | 0:0    | VLAN valid                |
 * | 31:0   | VLAN tag                  |
 * | 1:0    | Number of MPLS labels     |
 * | 31:0   | MPLS label0               |
 * | 31:0   | MPLS label1               |
 * | 3:0    | IPv4 version              |
 * | 3:0    | IPv4 ihl                  |
 * | 5:0    | IPv4 dscp                 |
 * | 1:0    | IPv4 ecn                  |
 * | 15:0   | IPv4 length               |
 * | 15:0   | IPv4 id                   |
 * | 2:0    | IPv4 flags                |
 * | 12:0   | IPv4 frag_ofs             |
 * | 7:0    | IPv4 ttl                  |
 * | 7:0    | IPv4 prot                 |
 * | 15:0   | IPv4 hdr_chk              |
 * | 31:0   | IPv4 sa                   |
 * | 31:0   | IPv4 da                   |
 * | 1:0    | packet byte length mode   |
 * | 13:0   | packet byte length min    |
 * | 13:0   | packet byte length max    |
 * | 1:0    | payload mode              |
 * | 7:0    | payload value             |
 */
module network_packet_generator
#(
    parameter int CORE_CLOCK_PERIOD_PS = 0,
    parameter int MODULE_ID            = 0,
    parameter int NUM_FLOWS            = 512,
    parameter bit DEBUG_ILA            = 0
) (
    Clock_int           avmm_clk_ifc,
    Reset_int           interconnect_sreset_ifc,
    Reset_int           peripheral_sreset_ifc,

    AvalonMM_int.Slave  avmm,
    AXIS_int.Master     packet_out
);


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Imports


    import UTIL_INTS::U_INT_CEIL_DIV;
    import AVMM_COMMON_REGS_PKG::*;


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_GT    ( CORE_CLOCK_PERIOD_PS,   0             );
    `ELAB_CHECK_EQUAL ( packet_out.DATA_BYTES,  8             );
    `ELAB_CHECK_EQUAL ( packet_out.USER_WIDTH,  NUM_FLOWS_LOG );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int MODULE_VERSION = 0;

    localparam int ETH_ADDR_BYTES   = 12;
    localparam int ETH_TYPE_BYTES   = 2;
    localparam int ETH_BYTES        = ETH_ADDR_BYTES + ETH_TYPE_BYTES;
    localparam int VLAN_BYTES       = 4;
    localparam int MPLS_BYTES       = 4;
    localparam int IPV4_BYTES       = 20;
    localparam int MAX_HEADER_BYTES =   ETH_BYTES    // 14 +
                                      + VLAN_BYTES   // 4  +
                                      + 2*MPLS_BYTES // 8  +
                                      + IPV4_BYTES;  // 20 = 46

    localparam int MAX_HEADER_BYTES_LOG = $clog2(MAX_HEADER_BYTES);
    localparam int MAX_HEADER_WORDS     = MAX_HEADER_BYTES / 8;
    localparam int MAX_HEADER_WORDS_LOG = $clog2(MAX_HEADER_WORDS);
    localparam int MAX_PACKET_BYTES_LOG = 14;
    localparam int MAX_PACKET_WORDS_LOG = MAX_PACKET_BYTES_LOG - 3;

    typedef enum {
        IDLE,
        HEADER,
        HEADER_AND_PAYLOAD,
        PAYLOAD,
        TX_COMPLETE,
        WAIT_FOR_SHAPER_READY
    } generator_state_t;

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
    localparam int NUM_FLOWS_LOG        = $clog2(NUM_FLOWS);

    enum {
        ADDR_PARAMS,
        ADDR_CNTR_STAT,
        ADDR_GEN_TX_PKT_CNT0,
        ADDR_GEN_TX_PKT_CNT1,
        ADDR_GEN_TX_BYTE_CNT0,
        ADDR_GEN_TX_BYTE_CNT1,
        ADDR_FLOW_TX_PKT_CNT0,
        ADDR_FLOW_TX_PKT_CNT1,
        ADDR_FLOW_TX_BYTE_CNT0,
        ADDR_FLOW_TX_BYTE_CNT1,
        NUM_INPUT_REGS
     } INPUT_ADDR_OFFSETS;

    enum {
        ADDR_TX_CON,
        ADDR_SHAPER_CON,
        ADDR_TX_CNTR_CON,
        ADDR_FLOW_DEF_CON,
        ADDR_FLOW_DEF_DATA,
        NUM_OUTPUT_REGS = ADDR_FLOW_DEF_DATA + FLOW_DEF_32BIT_WORDS
     } OUTPUT_ADDR_OFFSETS;

    // A precision between 1kbps and 1Mbps should cover most use cases
    // 1 Mbps = 125 kBps = 8e-4 bytes per clock @156.25M
    // 16 fractional bits -> 1.5e-5 Bytes/clk
    // 4w.16f should be a good staring point

    typedef struct packed {
        logic [15:0] whole;
        logic [15:0] frac;
    } shaper_acum_type;

    localparam int NUM_ACUM_BITS = $bits(shaper_acum_type);

    typedef struct packed {
        logic [3:0]  whole;
        logic [15:0] frac;
    } shaper_credit_type;

    localparam int NUM_CREDIT_BITS = $bits(shaper_credit_type);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    logic [31:0]                regs_in  [0:NUM_INPUT_REGS-1];
    logic [31:0]                regs_out [0:NUM_OUTPUT_REGS-1];
    logic                       regs_strb;

    logic [FLOW_DEF_BITS-1:0]   flow_def_ram [NUM_FLOWS-1:0];
    logic [FLOW_DEF_BITS-1:0]   flow_def_wdat;
    logic [NUM_FLOWS_LOG-1:0]   flow_def_wadr;
    logic [NUM_FLOWS_LOG-1:0]   flow_def_avmm_radr;
    logic                       flow_def_we;
    flow_def_type               flow_def_pkt_gen_rdat;
    logic [NUM_FLOWS_LOG-1:0]   flow_def_pkt_gen_radr;
    logic [NUM_FLOWS_LOG-1:0]   flow_def_pkt_gen_radr_sop;
    logic [NUM_FLOWS_LOG-1:0]   last_valid_flow_def_index;

    logic                       transmit;
    logic                       transmit_packet_out_clk;
    logic                       finite_tx;
    logic                       finite_tx_reg;
    logic [27:0]                finite_tx_num_pkts;

    logic [54:0]                gen_tx_byte_cnt;
    logic [54:0]                gen_tx_byte_cnt_sample;
    logic [47:0]                gen_tx_pkt_cnt;
    logic [47:0]                gen_tx_pkt_cnt_sample;
    logic [54:0]                flow_tx_byte_cnts [NUM_FLOWS-1:0];
    logic [54:0]                flow_tx_byte_cnt_samples [NUM_FLOWS-1:0];
    logic [47:0]                flow_tx_pkt_cnts [NUM_FLOWS-1:0];
    logic [47:0]                flow_tx_pkt_cnt_samples [NUM_FLOWS-1:0];
    logic                       gen_tx_cntr_sample_req;
    logic                       gen_tx_cntr_sample_req_packet_out_clk;
    logic                       gen_tx_cntr_sample_req_packet_out_clk_d;
    logic                       flow_tx_cntr_sample_all;
    logic                       flow_tx_cntr_sample_all_packet_out_clk;
    logic                       flow_tx_cntr_sample_all_packet_out_clk_d;
    logic                       flow_tx_cntr_sample_selected;
    logic                       flow_tx_cntr_sample_selected_packet_out_clk;
    logic                       flow_tx_cntr_sample_selected_packet_out_clk_d;
    logic [11:0]                flow_tx_cntr_sel;
    logic                       cntr_sample_rdy_tog;
    logic                       cntr_sample_rdy_tog_avmm_clk;
    logic                       cntr_sample_rdy_tog_avmm_clk_d;
    logic                       assembled_packet_sop;

    generator_state_t           generator_state;

    logic [8*MAX_HEADER_BYTES-1:0]      header;
    logic [8*MAX_HEADER_BYTES-1:0]      header_comb;
    logic [MAX_HEADER_BYTES_LOG-1:0]    header_bytes;
    logic [MAX_HEADER_BYTES_LOG-1:0]    header_bytes_comb;
    logic [MAX_HEADER_WORDS_LOG-1:0]    header_words;
    logic [MAX_PACKET_WORDS_LOG-1:0]    packet_words;
    logic [MAX_PACKET_BYTES_LOG-1:0]    packet_bytes;

    logic [MAX_PACKET_WORDS_LOG-1:0]    tx_word_count;
    logic [MAX_PACKET_WORDS_LOG-1:0]    remaining_tx_packets;

    shaper_credit_type                  shaper_credit;
    shaper_credit_type                  shaper_debit;
    shaper_acum_type                    shaper_acum;
    logic                               shaper_rdy;
    logic                               shaper_saturated;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Interfaces


    AXIS_int #(
        .DATA_BYTES ( packet_out.DATA_BYTES ),
        .USER_WIDTH ( packet_out.USER_WIDTH )
    ) assembled_packet (
        .clk     ( packet_out.clk     ),
        .sresetn ( packet_out.sresetn )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM Registers


    avmm_gpio #(
        .MODULE_VERSION         ( MODULE_VERSION                        ),
        .MODULE_ID              ( MODULE_ID                             ),
        .NUM_INPUT_REGS         ( NUM_INPUT_REGS                        ),
        .NUM_OUTPUT_REGS        ( NUM_OUTPUT_REGS                       ),
        .DEFAULT_OUTPUT_VALS    ('{ADDR_SHAPER_CON: '1, default: '0}    )
    ) regs (
        .clk_ifc                  ( avmm_clk_ifc            ),
        .peripheral_sreset_ifc    ( peripheral_sreset_ifc   ),
        .interconnect_sreset_ifc  ( interconnect_sreset_ifc ),
        .avmm                     ( avmm                    ),
        .input_vals               ( regs_in                 ),
        .output_vals              ( regs_out                ),
        .gpout_stb                ( regs_strb               )
    );

    always_comb begin
        for (int i=0; i<FLOW_DEF_32BIT_WORDS; i++) begin
            flow_def_wdat[FLOW_DEF_BITS-1-32*i -: 32] = regs_out[ADDR_FLOW_DEF_DATA+i];
        end
    end

    always_ff @(posedge avmm_clk_ifc.clk) begin
        flow_def_we   <= regs_out[ADDR_FLOW_DEF_CON][0] & regs_strb;
        flow_def_wadr <= regs_out[ADDR_FLOW_DEF_CON][15:4];
        if (flow_def_we) begin
            flow_def_ram[flow_def_wadr] <= flow_def_wdat;
        end
    end

    assign last_valid_flow_def_index    = regs_out[ADDR_FLOW_DEF_CON][27:16];
    assign transmit                     = regs_out[ADDR_TX_CON][0];
    assign finite_tx                    = regs_out[ADDR_TX_CON][1];
    assign finite_tx_num_pkts           = regs_out[ADDR_TX_CON][31:4];

    xclock_sig transmit_xclock (
        .tx_clk  ( avmm_clk_ifc.clk         ),
        .sig_in  ( transmit                 ),
        .rx_clk  ( packet_out.clk           ),
        .sig_out ( transmit_packet_out_clk  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Packet Assembler


    assign assembled_packet.tdest = '0;
    assign assembled_packet.tid   = '0;
    assign assembled_packet.tstrb = '1;

    always_ff @(posedge packet_out.clk) begin
        if (!packet_out.sresetn) begin
            generator_state         <= IDLE;
            flow_def_pkt_gen_radr   <= '0;
            flow_def_pkt_gen_rdat   <= '{default: '0};
        end else begin
            header       <= header_comb;
            header_bytes <= header_bytes_comb;
            header_words <= header_bytes_comb[2:0] == 0 ? header_bytes_comb[MAX_HEADER_BYTES_LOG-1:3] : header_bytes_comb[MAX_HEADER_BYTES_LOG-1:3] + 1;
            packet_words <= flow_def_pkt_gen_rdat.pkt_blen_min[2:0] == 0 ? flow_def_pkt_gen_rdat.pkt_blen_min[MAX_PACKET_BYTES_LOG-1:3] : flow_def_pkt_gen_rdat.pkt_blen_min[MAX_PACKET_BYTES_LOG-1:3] + 1;
            packet_bytes <= flow_def_pkt_gen_rdat.pkt_blen_min;

            flow_def_pkt_gen_rdat <= flow_def_ram[flow_def_pkt_gen_radr];

            assembled_packet.tvalid <= 1'b0;
            assembled_packet.tlast  <= 1'b0;
            assembled_packet.tkeep  <= '1;

            gen_tx_cntr_sample_req_packet_out_clk_d         <= gen_tx_cntr_sample_req_packet_out_clk;
            flow_tx_cntr_sample_all_packet_out_clk_d        <= flow_tx_cntr_sample_all_packet_out_clk;
            flow_tx_cntr_sample_selected_packet_out_clk_d   <= flow_tx_cntr_sample_selected_packet_out_clk;

/*
            ETH = 14
            VLAN = N * 4
            MPLS = M * 4
            IPv4 = 20

            Header with no tags  = 34 bytes
            Header with max tags = 50 bytes
            Min packet size      = 64 bytes
            axis.DATA_BYTES      = 8  bytes

            No case where packet is all header and no payload.
            No case where a packet ends in the header+payload state.
            All packets go through payload state.
            If more packet types are added (e.g. IPv6) this may no longer be the case
            and the header and header+payload states will need to account for the
            possibility of the packet ending in those states.
*/

            case (generator_state)
                IDLE : begin
                    tx_word_count         <= '0;
                    flow_def_pkt_gen_radr <= '0;
                    finite_tx_reg         <= finite_tx;
                    remaining_tx_packets  <= finite_tx_num_pkts-1;
                    if (transmit_packet_out_clk) begin
                        generator_state <= HEADER;
                    end
                end
                HEADER : begin
                    assembled_packet.tvalid <= 1'b1;
                    assembled_packet.tdata <= header[$left(header) - 64*tx_word_count -: 64];
                    assembled_packet.tuser <= flow_def_pkt_gen_radr;
                    if (assembled_packet.tready) begin
                        tx_word_count <= tx_word_count + 1;
                        if (header_bytes[2:0] != 3'b0 && tx_word_count+2 == header_words) begin
                            generator_state <= HEADER_AND_PAYLOAD;
                        end else if (tx_word_count+1 == header_words) begin
                            generator_state <= PAYLOAD;
                            if (flow_def_pkt_gen_radr == last_valid_flow_def_index) begin
                                flow_def_pkt_gen_radr <= '0;
                            end else begin
                                flow_def_pkt_gen_radr <= flow_def_pkt_gen_radr + 1;
                            end
                        end
                    end
                end
                HEADER_AND_PAYLOAD : begin
                    assembled_packet.tvalid <= 1'b1;
                    for (int b=0; b<8; b++) begin
                        if (b < header_bytes[2:0]) begin
                            assembled_packet.tdata[63-8*b -: 8] <= header[$left(header) - 64*tx_word_count - 8*b -: 8];
                        end else begin
                            assembled_packet.tdata[63-8*b -: 8] <= flow_def_pkt_gen_rdat.payload_value;
                        end
                    end
                    if (assembled_packet.tready) begin
                        tx_word_count <= tx_word_count + 1;
                        generator_state <= PAYLOAD;
                        if (flow_def_pkt_gen_radr == last_valid_flow_def_index) begin
                            flow_def_pkt_gen_radr <= '0;
                        end else begin
                            flow_def_pkt_gen_radr <= flow_def_pkt_gen_radr + 1;
                        end
                    end
                end
                PAYLOAD : begin
                    assembled_packet.tvalid <= 1'b1;
                    assembled_packet.tdata  <= {8{flow_def_pkt_gen_rdat.payload_value}};
                    if (assembled_packet.tready) begin
                        tx_word_count <= tx_word_count + 1;
                        if(tx_word_count+1 == packet_words) begin
                            assembled_packet.tlast <= 1'b1;
                            tx_word_count <= '0;
                            if (!transmit_packet_out_clk) begin
                                generator_state <= IDLE;
                            end else if (finite_tx_reg && remaining_tx_packets == 0) begin
                                generator_state <= TX_COMPLETE;
                            end else begin
                                remaining_tx_packets <= remaining_tx_packets - 1;
                                if (shaper_rdy) begin
                                    generator_state <= HEADER;
                                end else begin
                                    generator_state <= WAIT_FOR_SHAPER_READY;
                                end
                            end
                        end
                    end
                end
                TX_COMPLETE : begin
                    if (!transmit_packet_out_clk) begin
                        generator_state <= IDLE;
                    end
                end
                WAIT_FOR_SHAPER_READY : begin
                    if (!transmit_packet_out_clk) begin
                        generator_state <= IDLE;
                    end else if (shaper_rdy) begin
                        generator_state <= HEADER;
                    end
                end
                default: generator_state <= IDLE;
            endcase
        end
    end

    always_comb begin
        header_comb = '0;
        header_comb[$left(header_comb) -: 8*ETH_ADDR_BYTES] = {flow_def_pkt_gen_rdat.mac_da, flow_def_pkt_gen_rdat.mac_sa};
        header_bytes_comb = ETH_ADDR_BYTES;
        if (flow_def_pkt_gen_rdat.vlan_valid) begin
            header_comb[$left(header_comb) - 8*header_bytes_comb -: 8*VLAN_BYTES] = flow_def_pkt_gen_rdat.vlan_tag;
            header_bytes_comb += VLAN_BYTES;
        end
        header_comb[$left(header_comb) - 8*header_bytes_comb -: 8*ETH_TYPE_BYTES] = flow_def_pkt_gen_rdat.ether_type;
        header_bytes_comb += ETH_TYPE_BYTES;
        if (flow_def_pkt_gen_rdat.num_mpls_labels > 0) begin
            header_comb[$left(header_comb) - 8*header_bytes_comb -: 8*MPLS_BYTES] = flow_def_pkt_gen_rdat.mpls_label0;
            header_bytes_comb += MPLS_BYTES;
        end
        if (flow_def_pkt_gen_rdat.num_mpls_labels > 1) begin
            header_comb[$left(header_comb) - 8*header_bytes_comb -: 8*MPLS_BYTES] = flow_def_pkt_gen_rdat.mpls_label1;
            header_bytes_comb += MPLS_BYTES;
        end
        header_comb[$left(header_comb) - 8*header_bytes_comb -: 8*IPV4_BYTES] = {
            flow_def_pkt_gen_rdat.ip_version,
            flow_def_pkt_gen_rdat.ip_ihl,
            flow_def_pkt_gen_rdat.ip_dscp,
            flow_def_pkt_gen_rdat.ip_ecn,
            flow_def_pkt_gen_rdat.ip_length, /// Need to update
            flow_def_pkt_gen_rdat.ip_id,
            flow_def_pkt_gen_rdat.ip_flags,
            flow_def_pkt_gen_rdat.ip_frag_ofs,
            flow_def_pkt_gen_rdat.ip_ttl,
            flow_def_pkt_gen_rdat.ip_prot,
            flow_def_pkt_gen_rdat.ip_hdr_chk, /// Need to update
            flow_def_pkt_gen_rdat.ip_sa,
            flow_def_pkt_gen_rdat.ip_da
        };
        header_bytes_comb += IPV4_BYTES;
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Shaper


    assign shaper_rdy       = ~shaper_acum[$left(shaper_acum)];
    // Stop adding credit if the accumulator gets too positive.
    assign shaper_saturated = shaper_acum[$left(shaper_acum) -: 2] == 2'b01 ? 1'b1 : 1'b0;
    assign shaper_debit     = '{whole: keep_to_bytes(assembled_packet.tkeep), frac: 16'd0};

    always_ff @(posedge packet_out.clk) begin
        if (generator_state == IDLE) begin
            shaper_credit <= regs_out[ADDR_SHAPER_CON][19:0];
            shaper_acum   <= '0;
        end else begin
            if (assembled_packet.tvalid && assembled_packet.tready) begin
                if (shaper_saturated) begin
                    shaper_acum <= shaper_acum - shaper_debit;
                end else begin
                    shaper_acum <= shaper_acum - shaper_debit + shaper_credit;
                end
            end else if (!shaper_saturated) begin
                shaper_acum <= shaper_acum + shaper_credit;
            end
        end
    end

    axis_rate_limit_wrapper #(
        .RATE_CONFIG_WIDTH  ( NUM_CREDIT_BITS ),
        .RATE_ACC_WIDTH     ( NUM_ACUM_BITS   )
    ) transmit_shaper (
        .axis_in            ( assembled_packet ),
        .axis_out           ( packet_out ),

        .rate_num           (  ),
        .rate_denom         (  ),
        .rate_by_frame      (  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: Transmit Counters


    `MAKE_AXIS_MONITOR(assembled_packet_monitor, assembled_packet);

    axis_sop gen_out_sop_inst(
        .axis ( assembled_packet_monitor ),
        .sop  ( assembled_packet_sop     )
    );

    assign gen_tx_cntr_sample_req          = regs_out[ADDR_TX_CNTR_CON][0];
    assign flow_tx_cntr_sample_all         = regs_out[ADDR_TX_CNTR_CON][1];
    assign flow_tx_cntr_sample_selected    = regs_out[ADDR_TX_CNTR_CON][2];
    assign flow_tx_cntr_sel                = regs_out[ADDR_TX_CNTR_CON][15:4];

    xclock_sig gen_cnt_sample_req_xclock (
        .tx_clk  ( avmm_clk_ifc.clk                      ),
        .sig_in  ( gen_tx_cntr_sample_req                ),
        .rx_clk  ( packet_out.clk                        ),
        .sig_out ( gen_tx_cntr_sample_req_packet_out_clk )
    );

    xclock_sig flow_cnt_sample_selected_xclock (
        .tx_clk  ( avmm_clk_ifc.clk                             ),
        .sig_in  ( flow_tx_cntr_sample_selected                 ),
        .rx_clk  ( packet_out.clk                               ),
        .sig_out ( flow_tx_cntr_sample_selected_packet_out_clk  )
    );

    xclock_sig flow_cnt_sample_all_xclock (
        .tx_clk  ( avmm_clk_ifc.clk                         ),
        .sig_in  ( flow_tx_cntr_sample_all                  ),
        .rx_clk  ( packet_out.clk                           ),
        .sig_out ( flow_tx_cntr_sample_all_packet_out_clk   )
    );

    xclock_sig cntr_sample_rdy_tog_xclock (
        .tx_clk  ( packet_out.clk               ),
        .sig_in  ( cntr_sample_rdy_tog          ),
        .rx_clk  ( avmm_clk_ifc.clk             ),
        .sig_out ( cntr_sample_rdy_tog_avmm_clk )
    );

    always_ff @(posedge packet_out.clk) begin
        if (!packet_out.sresetn) begin
            flow_def_pkt_gen_radr_sop   <= '0;
            gen_tx_pkt_cnt              <= '0;
            gen_tx_byte_cnt             <= '0;
            gen_tx_pkt_cnt_sample       <= '0;
            gen_tx_byte_cnt_sample      <= '0;
            flow_tx_pkt_cnts            <= '{default: '0};
            flow_tx_pkt_cnt_samples     <= '{default: '0};
            flow_tx_byte_cnts           <= '{default: '0};
            flow_tx_byte_cnt_samples    <= '{default: '0};
            cntr_sample_rdy_tog         <= 1'b0;
        end else begin

            if (assembled_packet.tvalid && assembled_packet.tready && assembled_packet_sop) begin
                flow_def_pkt_gen_radr_sop <= flow_def_pkt_gen_radr;
            end

            if ((flow_tx_cntr_sample_all_packet_out_clk && !flow_tx_cntr_sample_all_packet_out_clk_d)
                || (flow_tx_cntr_sample_selected_packet_out_clk && !flow_tx_cntr_sample_selected_packet_out_clk_d)
                || (gen_tx_cntr_sample_req_packet_out_clk && !gen_tx_cntr_sample_req_packet_out_clk_d)) begin
                cntr_sample_rdy_tog <= ~cntr_sample_rdy_tog;
            end

            if (flow_tx_cntr_sample_all_packet_out_clk && !flow_tx_cntr_sample_all_packet_out_clk_d) begin
                flow_tx_pkt_cnt_samples     <= flow_tx_pkt_cnts;
                flow_tx_pkt_cnts            <= '{default: '0};
                flow_tx_byte_cnt_samples    <= flow_tx_byte_cnts;
                flow_tx_byte_cnts           <= '{default: '0};
            end else if (flow_tx_cntr_sample_selected_packet_out_clk && !flow_tx_cntr_sample_selected_packet_out_clk_d) begin
                flow_tx_pkt_cnt_samples[flow_tx_cntr_sel]   <= flow_tx_pkt_cnts[flow_tx_cntr_sel];
                flow_tx_pkt_cnts[flow_tx_cntr_sel]          <= '0;
                flow_tx_byte_cnt_samples[flow_tx_cntr_sel]  <= flow_tx_byte_cnts[flow_tx_cntr_sel];
                flow_tx_byte_cnts[flow_tx_cntr_sel]         <= '0;
            end

            if (assembled_packet.tvalid && assembled_packet.tready && assembled_packet.tlast && !(&flow_tx_pkt_cnts[flow_def_pkt_gen_radr_sop])) begin
                if ((flow_tx_cntr_sample_all_packet_out_clk && !flow_tx_cntr_sample_all_packet_out_clk_d)
                    || (flow_tx_cntr_sample_selected_packet_out_clk && !flow_tx_cntr_sample_selected_packet_out_clk_d && flow_tx_cntr_sel == flow_def_pkt_gen_radr_sop)) begin
                    flow_tx_pkt_cnts[flow_def_pkt_gen_radr_sop]   <= 48'd1;
                    flow_tx_byte_cnts[flow_def_pkt_gen_radr_sop]  <= packet_bytes;
                end else begin
                    flow_tx_pkt_cnts[flow_def_pkt_gen_radr_sop]   <= flow_tx_pkt_cnts[flow_def_pkt_gen_radr_sop] + 1;
                    flow_tx_byte_cnts[flow_def_pkt_gen_radr_sop]  <= flow_tx_byte_cnts[flow_def_pkt_gen_radr_sop] + packet_bytes;
                end
            end

            if (assembled_packet.tvalid && assembled_packet.tready && assembled_packet.tlast && !(&gen_tx_pkt_cnt)) begin
                if (gen_tx_cntr_sample_req_packet_out_clk && !gen_tx_cntr_sample_req_packet_out_clk_d) begin
                    gen_tx_pkt_cnt_sample   <= gen_tx_pkt_cnt;
                    gen_tx_pkt_cnt          <= 1;
                    gen_tx_byte_cnt_sample  <= gen_tx_byte_cnt;
                    gen_tx_byte_cnt         <= packet_bytes;
                end else begin
                    gen_tx_pkt_cnt  <= gen_tx_pkt_cnt + 1;
                    gen_tx_byte_cnt <= gen_tx_byte_cnt + packet_bytes;
                end
            end else if (gen_tx_cntr_sample_req_packet_out_clk && !gen_tx_cntr_sample_req_packet_out_clk_d) begin
                gen_tx_pkt_cnt_sample <= gen_tx_pkt_cnt;
                gen_tx_pkt_cnt <= '0;
                gen_tx_byte_cnt_sample <= gen_tx_byte_cnt;
                gen_tx_byte_cnt <= '0;
            end
        end
    end

    always_ff @(posedge avmm_clk_ifc.clk) begin
        if (peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH) begin
            regs_in <= '{default: '0};
            cntr_sample_rdy_tog_avmm_clk_d <= 1'b0;
        end else begin

            cntr_sample_rdy_tog_avmm_clk_d <= cntr_sample_rdy_tog_avmm_clk;

            if ((gen_tx_cntr_sample_req || flow_tx_cntr_sample_selected || flow_tx_cntr_sample_all) && regs_strb) begin
                regs_in[ADDR_CNTR_STAT][0] <= 1'b1;
            end else if (cntr_sample_rdy_tog_avmm_clk_d != cntr_sample_rdy_tog_avmm_clk) begin
                regs_in[ADDR_CNTR_STAT][0] <= 1'b0;
            end

            regs_in[ADDR_GEN_TX_PKT_CNT0]   <= gen_tx_pkt_cnt_sample[31:0];
            regs_in[ADDR_GEN_TX_PKT_CNT1]   <= {16'd0, gen_tx_pkt_cnt_sample[47:32]};
            regs_in[ADDR_GEN_TX_BYTE_CNT0]  <= gen_tx_byte_cnt_sample[31:0];
            regs_in[ADDR_GEN_TX_BYTE_CNT1]  <= {9'd0, gen_tx_byte_cnt_sample[54:32]};
            regs_in[ADDR_FLOW_TX_PKT_CNT0]  <= flow_tx_pkt_cnt_samples[flow_tx_cntr_sel][31:0];
            regs_in[ADDR_FLOW_TX_PKT_CNT1]  <= {16'd0, flow_tx_pkt_cnt_samples[flow_tx_cntr_sel][47:32]};
            regs_in[ADDR_FLOW_TX_BYTE_CNT0] <= flow_tx_byte_cnt_samples[flow_tx_cntr_sel][31:0];
            regs_in[ADDR_FLOW_TX_BYTE_CNT1] <= {9'd0, flow_tx_byte_cnt_samples[flow_tx_cntr_sel][54:32]};
            regs_in[ADDR_PARAMS]            <= CORE_CLOCK_PERIOD_PS;
        end
    end


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: ILAs


    `ifndef MODEL_TECH
        generate
            if (DEBUG_ILA) begin : gen_ila

                ila_debug avmm_ila (
                    .clk    ( avmm_clk_ifc.clk                  ),
                    .probe0 ({interconnect_sreset_ifc.sreset,
                              peripheral_sreset_ifc.sreset     }),
                    .probe1 ( avmm.address                      ),
                    .probe2 ( avmm.byteenable                   ),
                    .probe3 ( {avmm.write,
                               avmm.read,
                               avmm.waitrequest,
                               avmm.writeresponsevalid,
                               avmm.readresponsevalid}          ),
                    .probe4 ( avmm.response                     ),
                    .probe5 ( avmm.writedata                    ),
                    .probe6 ( avmm.readdata                     ),
                    .probe7 ( '0                                ),
                    .probe8 ( '0                                ),
                    .probe9 ( '0                                ),
                    .probe10( '0                                ),
                    .probe11( '0                                ),
                    .probe12( '0                                ),
                    .probe13( '0                                ),
                    .probe14( '0                                ),
                    .probe15( '0                                )
                );

                ila_debug packet_gen_ila (
                    .clk    ( packet_out.clk            ),
                    .probe0 ( packet_out.sresetn        ),
                    .probe1 ( generator_state           ),
                    .probe2 ( tx_word_count             ),
                    .probe3 ( flow_def_pkt_gen_radr     ),
                    .probe4 ( {finite_tx_reg,
                               finite_tx,
                               shaper_rdy}              ),
                    .probe5 ( remaining_tx_packets      ),
                    .probe6 ( transmit_packet_out_clk   ),
                    .probe7 ( {assembled_packet.tvalid,
                               assembled_packet.tready}       ),
                    .probe8 ( assembled_packet.tdata[63:32]   ),
                    .probe9 ( assembled_packet.tdata[31:0]    ),
                    .probe10( header_bytes              ),
                    .probe11( header_words              ),
                    .probe12( '0                        ),
                    .probe13( '0                        ),
                    .probe14( '0                        ),
                    .probe15( '0                        )
                );
            end
        endgenerate
    `endif
endmodule

`default_nettype wire
