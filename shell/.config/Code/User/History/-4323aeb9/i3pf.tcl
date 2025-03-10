onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TESTBENCH SIGNALS}
add wave -noupdate /p4_router_congestion_manager_tb/send_packet_byte_length
add wave -noupdate /p4_router_congestion_manager_tb/send_packet_data
add wave -noupdate /p4_router_congestion_manager_tb/send_packet_user
add wave -noupdate /p4_router_congestion_manager_tb/send_packet_req
add wave -noupdate /p4_router_congestion_manager_tb/send_packet_busy
add wave -noupdate -radix unsigned /p4_router_congestion_manager_tb/num_free_pages
add wave -noupdate -divider {PACKET IN}
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/clk
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/sresetn
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tvalid
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tready
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tdata
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tstrb
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tkeep
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tlast
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tid
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tdest
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_in/tuser
add wave -noupdate -divider DUT
add wave -noupdate -radix unsigned /p4_router_congestion_manager_tb/dut/num_free_pages
add wave -noupdate /p4_router_congestion_manager_tb/dut/pkt_valid
add wave -noupdate /p4_router_congestion_manager_tb/dut/pkt_sop
add wave -noupdate /p4_router_congestion_manager_tb/dut/pkt_eop
add wave -noupdate -radix unsigned -childformat {{/p4_router_congestion_manager_tb/dut/drop_thresh_read.green_threshold -radix unsigned} {/p4_router_congestion_manager_tb/dut/drop_thresh_read.yellow_threshold -radix unsigned} {/p4_router_congestion_manager_tb/dut/drop_thresh_read.red_threshold -radix unsigned}} -expand -subitemconfig {/p4_router_congestion_manager_tb/dut/drop_thresh_read.green_threshold {-height 17 -radix unsigned} /p4_router_congestion_manager_tb/dut/drop_thresh_read.yellow_threshold {-height 17 -radix unsigned} /p4_router_congestion_manager_tb/dut/drop_thresh_read.red_threshold {-height 17 -radix unsigned}} /p4_router_congestion_manager_tb/dut/drop_thresh_read
add wave -noupdate -radix unsigned -childformat {{{/p4_router_congestion_manager_tb/dut/selected_occupancy_threshold[2]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/selected_occupancy_threshold[3]} -radix unsigned}} -subitemconfig {{/p4_router_congestion_manager_tb/dut/selected_occupancy_threshold[2]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/selected_occupancy_threshold[3]} {-height 17 -radix unsigned}} /p4_router_congestion_manager_tb/dut/selected_occupancy_threshold
add wave -noupdate -expand /p4_router_congestion_manager_tb/dut/packet_in_metadata
add wave -noupdate /p4_router_congestion_manager_tb/dut/packet_in_queue_index
add wave -noupdate /p4_router_congestion_manager_tb/dut/packet_out_metadata
add wave -noupdate /p4_router_congestion_manager_tb/dut/pkt_word_length
add wave -noupdate -radix unsigned /p4_router_congestion_manager_tb/dut/queue_occupancy_plus_blen
add wave -noupdate -radix unsigned -childformat {{{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[8]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[7]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[6]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[5]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[4]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[3]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[2]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[1]} -radix unsigned} {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[0]} -radix unsigned}} -subitemconfig {{/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[8]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[7]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[6]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[5]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[4]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[3]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[2]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[1]} {-height 17 -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_occupancy_pages[0]} {-height 17 -radix unsigned}} /p4_router_congestion_manager_tb/dut/queue_occupancy_pages
add wave -noupdate /p4_router_congestion_manager_tb/dut/malloc_required
add wave -noupdate /p4_router_congestion_manager_tb/dut/malloc_allowed
add wave -noupdate /p4_router_congestion_manager_tb/dut/malloc_approved
add wave -noupdate /p4_router_congestion_manager_tb/dut/current_page_valid
add wave -noupdate -childformat {{/p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.tail_ptr -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.current_page_ptr -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.current_page_valid -radix unsigned}} -expand -subitemconfig {/p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.tail_ptr {-height 17 -radix unsigned} /p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.current_page_ptr {-height 17 -radix unsigned} /p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata.current_page_valid {-height 17 -radix unsigned}} /p4_router_congestion_manager_tb/dut/queue_tail_pointer_rdata
add wave -noupdate -childformat {{/p4_router_congestion_manager_tb/dut/queue_tail_pointer_wdata.new_tail_ptr -radix unsigned} {/p4_router_congestion_manager_tb/dut/queue_tail_pointer_wdata.next_page_ptr -radix unsigned}} -expand -subitemconfig {/p4_router_congestion_manager_tb/dut/queue_tail_pointer_wdata.new_tail_ptr {-height 17 -radix unsigned} /p4_router_congestion_manager_tb/dut/queue_tail_pointer_wdata.next_page_ptr {-height 17 -radix unsigned}} /p4_router_congestion_manager_tb/dut/queue_tail_pointer_wdata
add wave -noupdate /p4_router_congestion_manager_tb/queue_mem_alloc/clk
add wave -noupdate /p4_router_congestion_manager_tb/queue_mem_alloc/tvalid
add wave -noupdate /p4_router_congestion_manager_tb/queue_mem_alloc/tready
add wave -noupdate -radix unsigned /p4_router_congestion_manager_tb/queue_mem_alloc/tdata
add wave -noupdate /p4_router_congestion_manager_tb/dut/pkt_drop
add wave -noupdate /p4_router_congestion_manager_tb/dut/malloc_drop
add wave -noupdate /p4_router_congestion_manager_tb/dut/mem_full_drop
add wave -noupdate /p4_router_congestion_manager_tb/dut/queue_full_drop
add wave -noupdate -divider {PACKET OUT}
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/clk
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/sresetn
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tvalid
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tready
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tdata
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tstrb
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tkeep
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tlast
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tid
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tdest
add wave -noupdate /p4_router_congestion_manager_tb/dut_packet_out/tuser
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4639613 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 334
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
WaveRestoreZoom {0 ps} {6148980 ps}
