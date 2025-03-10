onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TABLE CONFIG}
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/sresetn
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/table_config/awaddr
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/awvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/awready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/table_config/wdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/wvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/wready
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/bresp
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/bvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/bready
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/table_config/araddr
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/arvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/arready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/table_config/rdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/rresp
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/rvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/table_config/rready
add wave -noupdate -divider AVMM
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/avmm/address
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/burstcount
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/byteenable
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/waitrequest
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/response
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/write
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/avmm/writedata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/writeresponsevalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/read
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/avmm/readdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/avmm/readdatavalid
add wave -noupdate -divider {PKT GEN}
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_axis/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/generator_state
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/transmit
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/finite_tx
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/finite_tx_reg
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/finite_tx_num_pkts
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_axis/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_axis/tready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_axis/tdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_checksum_axis/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_checksum_axis/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_checksum_axis/tready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ipv4_header_checksum_axis/tdata
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen/header_comb
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen/header
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/header_bytes
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/header_words
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/packet_bytes_for_header
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/packet_bytes_for_fsm
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/packet_words
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/ip_length
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/tx_word_count
add wave -noupdate -radix unsigned /p4_router_vnp4_tiny_bcam_tb/pkt_gen/flow_def_pkt_gen_radr
add wave -noupdate -divider {PACKET IN}
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tdata
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tkeep
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tlast
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/pkt_gen_out/tuser
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_in_p4_map
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_in_valid
add wave -noupdate -divider {IPV4 CHECKSUM}
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_req/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_req/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_req/tready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_req/tdata
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_resp/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_resp/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_resp/tready
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_verif_resp/tdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_req/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_req/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_req/tready
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_req/tdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_resp/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_resp/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_resp/tready
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/ip_chksum_update_resp/tdata
add wave -noupdate -divider {PACKET OUT}
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/clk
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tvalid
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tready
add wave -noupdate -radix hexadecimal /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tdata
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tkeep
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tlast
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/packet_data_out/tuser
add wave -noupdate -childformat {{/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.ingress_port -radix unsigned} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.egress_port -radix unsigned} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.byte_length -radix unsigned} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.vlan_id -radix hexadecimal} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.vrf_id -radix hexadecimal} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.drop_reason -radix unsigned} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.ether_type -radix hexadecimal} {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.mpls_label -radix hexadecimal}} -expand -subitemconfig {/p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.ingress_port {-height 15 -radix unsigned} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.egress_port {-height 15 -radix unsigned} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.byte_length {-height 15 -radix unsigned} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.vlan_id {-height 15 -radix hexadecimal} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.vrf_id {-height 15 -radix hexadecimal} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.drop_reason {-height 15 -radix unsigned} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.ether_type {-height 15 -radix hexadecimal} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map.mpls_label {-height 15 -radix hexadecimal}} /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_p4_map
add wave -noupdate /p4_router_vnp4_tiny_bcam_tb/dut/genblk5/vnp4_wrapper/user_metadata_out_valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {197101 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 427
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {494999 ps} {6054111 ps}
