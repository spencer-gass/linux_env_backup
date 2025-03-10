// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * IPv4 packet generator.
 * WARNING: there is no CDC (except control and status signals) between registers on AVMM bus and main logic. Please make sure that
 * there is no change on registers above offset 0x12 (CTRL_REGISTER) after packet sending was started
 */
module ethernet_ip_packet_src #(
    parameter bit [47:0] MAC_ADDR_SRC   = 48'haa_aa_aa_aa_bb_aa,
    parameter int        PACKET_LENGTH  = 10,
    parameter bit [15:0] MODULE_VERSION = 0,
    parameter bit [15:0] MODULE_ID      = 0,
    parameter bit        DEBUG_ILA      = 0
) (
    AXIS_int.Master    axis_out,
    Clock_int.Input    clk_ifc_avmm,
    Reset_int.ResetIn  sreset_ifc_avmm_peripheral,
    Reset_int.ResetIn  sreset_ifc_avmm_interconnect,
    AvalonMM_int.Slave avmm
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations

    typedef enum {
        IDLE,
        NEXT_PACKET,
        WAIT_HEADER,
        WAIT_SENDING,
        WAIT_INTERVAL
    } state_t;

    typedef struct packed {
        logic        sign;
        logic [6:0]  whole;
        logic [23:0] fraction;
    } shaper_accum_fixed_point_type;

    typedef struct packed {
        logic        sign;
        logic [6:0]  whole;
        logic [23:0] fraction;
    } shaper_dec_fixed_point_type;

    localparam int GPIO_OUT_REG_NUM = 16;
    localparam int GPIO_IN_REG_NUM  = 5;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation




    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations

    // Tx ethernet signals
    logic            eth_tx_hdr_valid, eth_tx_hdr_ready, eth_tx_payload_tuser;
    logic            eth_tx_busy, eth_tx_payload_tvalid;
    logic            eth_tx_payload_tready, eth_tx_payload_tlast;
    logic      [7:0] eth_tx_payload_tdata;
    logic     [47:0] eth_tx_dest_mac, eth_tx_src_mac;
    logic     [15:0] eth_tx_type;


    logic [7:0]  eth_tx_payload_axis_tdata;
    logic        eth_tx_payload_axis_tvalid;
    logic        eth_tx_payload_axis_tready;
    logic        eth_tx_payload_axis_tlast;
    logic        eth_tx_payload_axis_tuser;

    logic eth_tx_payload_axis_tkeep;

    logic busy;
    logic tx_error_payload_early_termination;


    logic [31:0] avmm_gpio_out [0:GPIO_OUT_REG_NUM-1];
    logic [31:0] avmm_gpio_in  [0:GPIO_IN_REG_NUM-1];
    logic avmm_gpio_out_stb;


    AXIS_int #(.DATA_BYTES(4)) ip_payload_32 (
        .clk     (axis_out.clk    ),
        .sresetn (axis_out.sresetn)
    );

    AXIS_int #(.DATA_BYTES(1)) ip_payload_8 (
        .clk     (axis_out.clk    ),
        .sresetn (axis_out.sresetn)
    );

    AXIS_int #(.DATA_BYTES(4)) ip_payload_id (
        .clk     (axis_out.clk    ),
        .sresetn (axis_out.sresetn)
    );

    state_t fsm_state;


    logic [31:0] fsm_num_packets;

    logic fsm_start;
    logic fsm_continuous_send;

    logic [31:0] fsm_remaining_packets;
    logic [31:0] fsm_packet_id;
    logic fsm_packet_sent;

    logic fsm_next_packet_stb;
    logic fsm_ip_hdr_ready;

    logic ip_hdr_valid;
    logic tx_busy;
    logic ip_hdr_ready;


    logic [15:0] ip_eth_type; // 16'h0800
    logic [5:0]  ip_dscp;
    logic [1:0]  ip_ecn;
    logic [15:0] ip_length;
    logic [15:0] ip_identification;
    logic [2:0]  ip_flags; //3'b010
    logic [12:0] ip_fragment_offset; //'0
    logic [7:0]  ip_ttl; // '0
    logic [7:0]  ip_protocol; // 8'd17 UDP
    logic [31:0] ip_source_ip;
    logic [31:0] ip_dest_ip;
    logic [47:0] ip_mac_dest;

    logic        continuous_send_flag;
    logic [63:0] tx_cnt;

    logic [31:0] frame_footer                [PACKET_LENGTH-1:0];

    shaper_dec_fixed_point_type shaper_dec;
    shaper_accum_fixed_point_type shaper_accum;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    avmm_gpio #(
        .MODULE_VERSION      (MODULE_VERSION   ),
        .MODULE_ID           (MODULE_ID        ),
        .DATALEN             (32               ),
        .NUM_INPUT_REGS      (GPIO_IN_REG_NUM                ),
        .NUM_OUTPUT_REGS     (GPIO_OUT_REG_NUM)
    ) avmm_gpio_inst (
        .clk_ifc                 (clk_ifc_avmm                ),
        .peripheral_sreset_ifc   (sreset_ifc_avmm_peripheral  ),
        .interconnect_sreset_ifc (sreset_ifc_avmm_interconnect),
        .avmm                    (avmm                        ),
        .input_vals              (avmm_gpio_in                ),
        .output_vals             (avmm_gpio_out               ),
        .gpout_stb               (avmm_gpio_out_stb)
    );


    assign avmm_gpio_in[0][31] = fsm_state != IDLE; //STATUS_REG
    assign avmm_gpio_in[0][30] = tx_busy; //STATUS_REG
    assign avmm_gpio_in[0][29:8] = '0;
    assign avmm_gpio_in[0][7:0] = fsm_state;
    assign avmm_gpio_in[1] = fsm_remaining_packets;
    assign avmm_gpio_in[2] = shaper_accum;
    assign avmm_gpio_in[3] = tx_cnt[31:0];
    assign avmm_gpio_in[4] = tx_cnt[63:32];

    assign fsm_start = avmm_gpio_out[0][0] & avmm_gpio_out_stb;  //CTRL_REG
    assign fsm_continuous_send = avmm_gpio_out[0][1];

    assign fsm_num_packets   = avmm_gpio_out[1];
    assign shaper_dec        = avmm_gpio_out[2][30:0];
    assign ip_eth_type       = avmm_gpio_out[3];
    assign ip_dscp           = avmm_gpio_out[4];
    assign ip_ecn            = avmm_gpio_out[5];
    assign ip_length         = avmm_gpio_out[6][31] ? avmm_gpio_out[6][15:0] :  {PACKET_LENGTH * 4}+ 5*4;
    assign ip_identification = avmm_gpio_out[7];
    assign ip_flags          = avmm_gpio_out[8];
    assign ip_fragment_offset= avmm_gpio_out[9];
    assign ip_ttl            = avmm_gpio_out[10];
    assign ip_protocol       = avmm_gpio_out[11];
    assign ip_source_ip      = avmm_gpio_out[12];
    assign ip_dest_ip        = avmm_gpio_out[13];
    assign ip_mac_dest[47:32]= avmm_gpio_out[14][15:0];
    assign ip_mac_dest[31:0] = avmm_gpio_out[15];

    always_ff @(posedge clk_ifc_avmm.clk ) begin
        if (sreset_ifc_avmm_peripheral.reset == sreset_ifc_avmm_peripheral.ACTIVE_HIGH) begin
            fsm_packet_id        <= 0;
            fsm_state            <= IDLE;
        end else begin
            fsm_next_packet_stb   <= 1'b0;
            unique case (fsm_state)
                IDLE : begin
                    fsm_remaining_packets <= fsm_num_packets;
                    fsm_packet_id         <= '0;
                    ip_hdr_valid          <= 1'b0;
                    continuous_send_flag  <= fsm_continuous_send;
                    if (fsm_start) begin
                        fsm_state <= WAIT_HEADER;
                        ip_hdr_valid <= 1'b1;
                    end
                end

                WAIT_HEADER : begin
                    tx_cnt <= '0;
                    if (fsm_ip_hdr_ready && shaper_accum.sign) begin
                        fsm_state <= NEXT_PACKET;
                    end
                end

                NEXT_PACKET : begin
                    fsm_remaining_packets <= continuous_send_flag ? '0 : fsm_remaining_packets - 1;
                    fsm_packet_id         <= fsm_packet_id + 1;
                    fsm_state             <= WAIT_SENDING;
                end

                WAIT_SENDING : begin
                    fsm_next_packet_stb   <= 1'b1;
                    if (fsm_packet_sent) begin
                        fsm_state             <= WAIT_INTERVAL;
                        if (!tx_cnt[63]) begin
                            tx_cnt <= tx_cnt + 1;
                        end
                    end
                end

                WAIT_INTERVAL : begin
                    if (fsm_interval_remainig == 0) begin
                        fsm_state <= NEXT_PACKET;
                        if (fsm_remaining_packets == 0 && !fsm_continuous_send) begin
                            fsm_state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk_ifc_avmm.clk) begin
        if (fsm_state == IDLE) begin // reset in idle
            shaper_accum <= '0;
        end else if (fsm_state == NEXT_PACKET) begin // a packet was sent
            shaper_accum <= shaper_accum + {74, 24b0} - shaper_dec;
        end else if (shaper_accum.sign == shaper_accume.whole[$left(shaper_accume.whole)]) begin // decrement or saturate
            shaper_accum <= shaper_accum - shaper_dec;
        end
    end


    xclock_pulse xclock_send_packet_stb (
        .sresetn_in  (~sreset_ifc_avmm_peripheral.reset ),
        .clk_in      (clk_ifc_avmm.clk                  ),
        .pulse_in    (fsm_next_packet_stb               ),
        .sresetn_out (axis_out.sresetn                  ),
        .clk_out     (axis_out.clk                      ),
        .pulse_out   (ip_payload_id.tvalid              )
    );

    xclock_sig xclock_ip_hdr_ready (
        .tx_clk ( axis_out.clk       ),
        .sig_in ( ip_hdr_ready),

        .rx_clk ( clk_ifc_avmm.clk    ),
        .sig_out( fsm_ip_hdr_ready  )
    );



    xclock_sig xclock_fsm_packet_sent (
        .tx_clk ( axis_out.clk       ),
        .sig_in ( ip_payload_id.tready & ip_payload_id.tvalid),

        .rx_clk ( clk_ifc_avmm.clk ),
        .sig_out( fsm_packet_sent  )
    );


    // generation of IP payload (repeated packet_number)

    axis_footer_add #(
        .FOOTER_WORDS(PACKET_LENGTH)
    ) eop_footer_add (
        .axis_in           (ip_payload_id ),
        .axis_out          (ip_payload_32   ),
        .frame_in_progress (              ),
        .end_frame_stb     (1'b0          ),
        .end_of_frame      (              ),
        .footer_in         ('{default:fsm_packet_id})
    );


    assign ip_payload_id.tstrb = '1;
    assign ip_payload_id.tid   = '0;
    assign ip_payload_id.tdest = '0;
    assign ip_payload_id.tuser = '0;
    assign ip_payload_id.tkeep = '1;
    assign ip_payload_id.tlast  = 1'b1;
    assign ip_payload_id.tdata = fsm_packet_id;


    // assign ip_payload_32.tid   = '0;
    // assign ip_payload_32.tdest = '0;


    axis_adapter_wrapper ip_payload_adapter (
        .axis_in  ( ip_payload_32.Slave   ),
        .axis_out ( ip_payload_8.Master )
    );



    ip_eth_tx ip_eth_tx_inst (
        .clk                       (axis_out.clk              ),
        .rst                       (~axis_out.sresetn          ),
        // IP frame input
        .s_ip_hdr_valid                  (ip_hdr_valid                      ),
        .s_ip_hdr_ready                  (ip_hdr_ready                      ),
        .s_eth_dest_mac                  (ip_mac_dest                       ),
        .s_eth_src_mac                   (MAC_ADDR_SRC                      ),
        .s_eth_type                      (ip_eth_type                       ),
        .s_ip_dscp                       (ip_dscp                           ),
        .s_ip_ecn                        (ip_ecn                            ),
        .s_ip_length                     (ip_length                         ),
        .s_ip_identification             (ip_identification                 ),
        .s_ip_flags                      (ip_flags                          ),
        .s_ip_fragment_offset            (ip_fragment_offset                ),
        .s_ip_ttl                        (ip_ttl                            ),
        .s_ip_protocol                   (ip_protocol                       ),
        .s_ip_source_ip                  (ip_source_ip                      ),
        .s_ip_dest_ip                    (ip_dest_ip                        ),


        .s_ip_payload_axis_tdata         (ip_payload_8.tdata           ),
        .s_ip_payload_axis_tvalid        (ip_payload_8.tvalid          ),
        .s_ip_payload_axis_tready        (ip_payload_8.tready   ),
        .s_ip_payload_axis_tlast         (ip_payload_8.tlast           ),
        .s_ip_payload_axis_tuser         (ip_payload_8.tuser           ),
        // Ethernet frame output
        .m_eth_hdr_valid                 (eth_tx_hdr_valid                  ),
        .m_eth_hdr_ready                 (eth_tx_hdr_ready                  ),
        .m_eth_dest_mac                  (eth_tx_dest_mac                   ),
        .m_eth_src_mac                   (eth_tx_src_mac                    ),
        .m_eth_type                      (eth_tx_type                       ),
        .m_eth_payload_axis_tdata        (eth_tx_payload_axis_tdata         ),
        .m_eth_payload_axis_tvalid       (eth_tx_payload_axis_tvalid        ),
        .m_eth_payload_axis_tready       (eth_tx_payload_axis_tready        ),
        .m_eth_payload_axis_tlast        (eth_tx_payload_axis_tlast         ),
        .m_eth_payload_axis_tuser        (eth_tx_payload_axis_tuser         ),
        // Status signals
        .busy                            (tx_busy                           ),
        .error_payload_early_termination (tx_error_payload_early_termination)
    );


    eth_axis_tx #(
        .DATA_WIDTH  (8 )
    ) eth_to_axis (
        .clk                       (axis_out.clk              ),
        .rst                       (~axis_out.sresetn          ),
        // Ethernet frame input
        .s_eth_hdr_valid           (eth_tx_hdr_valid          ),
        .s_eth_hdr_ready           (eth_tx_hdr_ready          ),
        .s_eth_dest_mac            (eth_tx_dest_mac           ),
        .s_eth_src_mac             (eth_tx_src_mac            ),
        .s_eth_type                (eth_tx_type               ),
        .s_eth_payload_axis_tdata  (eth_tx_payload_axis_tdata ),
        .s_eth_payload_axis_tkeep  (eth_tx_payload_axis_tkeep ),
        .s_eth_payload_axis_tvalid (eth_tx_payload_axis_tvalid),
        .s_eth_payload_axis_tready (eth_tx_payload_axis_tready),
        .s_eth_payload_axis_tlast  (eth_tx_payload_axis_tlast ),
        .s_eth_payload_axis_tuser  (eth_tx_payload_axis_tuser ),
        // AXI output
        .m_axis_tdata              (axis_out.tdata           ),
        .m_axis_tkeep              (axis_out.tkeep           ),
        .m_axis_tvalid             (axis_out.tvalid          ),
        .m_axis_tready             (axis_out.tready          ),
        .m_axis_tlast              (axis_out.tlast           ),
        .m_axis_tuser              (axis_out.tuser           ),
        // Status signals
        .busy                      (                         )
    );

    assign axis_out.tstrb = '1;
    assign axis_out.tid   = '0;
    assign axis_out.tdest = '0;



    /////////////////////////////////////////////////////////////////////
    // SECTION: ILA Probes


    `ifndef MODEL_TECH


        generate
            if (DEBUG_ILA) begin: gen_ila
                ila_debug dbg_ila_avmm (
                    .clk     (clk_ifc_avmm.clk    ),
                    .probe0  ({fsm_num_packets   }),
                    .probe1  ({shaper_accum      }),
                    .probe2  ({ip_eth_type       }),
                    .probe3  ({ip_dscp           }),
                    .probe4  ({ip_ecn            }),
                    .probe5  ({ip_length         }),
                    .probe6  ({ip_identification }),
                    .probe7  ({ip_flags          }),
                    .probe8  ({ip_fragment_offset}),
                    .probe9  ({ip_ttl            }),
                    .probe10 ({ip_protocol       }),
                    .probe11 ({ip_source_ip      }),
                    .probe12 ({ip_dest_ip        }),
                    .probe13 ({ip_mac_dest[47:32]}),
                    .probe14 ({ip_mac_dest[31:0] }),
                    .probe15 ({fsm_state,fsm_start,fsm_ip_hdr_ready} )
                );
            end
        endgenerate
    `endif


endmodule

`default_nettype wire
