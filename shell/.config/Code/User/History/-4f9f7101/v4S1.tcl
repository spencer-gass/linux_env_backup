onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TESTBENCH SIGNALS}
add wave -noupdate /p4_router_ingress_tb/core_clk_ifc/clk
add wave -noupdate /p4_router_ingress_tb/send_packet_data
add wave -noupdate /p4_router_ingress_tb/send_packet_byte_length
add wave -noupdate /p4_router_ingress_tb/send_packet_req
add wave -noupdate /p4_router_ingress_tb/send_packet_req_d
add wave -noupdate /p4_router_ingress_tb/send_packet_busy
add wave -noupdate /p4_router_ingress_tb/flush_ing_buffer
add wave -noupdate /p4_router_ingress_tb/packet_sink_reset
add wave -noupdate -divider {PHYSICAL PORTS}
add wave -noupdate -divider {INGRESS BUFFER}
add wave -noupdate -expand /p4_router_ingress_tb/DUT/ing_buf/ing_buf_overflow
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_buf
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_buf
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_buf_wren
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_buf_wren
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_buf_wdata
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_buf_wdata
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_buf_waddr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_buf_waddr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_phys_ports_adapted_tvalid
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_phys_ports_adapted_tdata
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_phys_ports_adapted_tlast
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_valid
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_last
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/partition_full
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/wr_if_sel
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_wr_ptr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_wr_ptr_committed
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_wr_ptr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/last_word_ptr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_encoded
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/wcnt
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/wcnt_sel
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/keep_bytes_comb
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/keep_bytes
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/read_state
add wave -noupdate -radix unsigned /p4_router_ingress_tb/DUT/ing_buf/rd_if_sel
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_rd_ptr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_rd_ptr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/atr_buf_rd
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/keep_comb
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/drop
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_valid
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_last
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_atr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_buf_raddr
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_data
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_port_id
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ing_bus_keep
add wave -noupdate /p4_router_ingress_tb/DUT/ing_buf/ingress_metadata
add wave -noupdate -divider {INGRESS BUS}
add wave -noupdate /p4_router_ingress_tb/ing_bus/clk
add wave -noupdate /p4_router_ingress_tb/ing_bus/sresetn
add wave -noupdate /p4_router_ingress_tb/ing_bus/tvalid
add wave -noupdate /p4_router_ingress_tb/ing_bus/tready
add wave -noupdate /p4_router_ingress_tb/ing_bus/tdata
add wave -noupdate /p4_router_ingress_tb/ing_bus/tstrb
add wave -noupdate /p4_router_ingress_tb/ing_bus/tkeep
add wave -noupdate /p4_router_ingress_tb/ing_bus/tlast
add wave -noupdate /p4_router_ingress_tb/ing_bus/tid
add wave -noupdate /p4_router_ingress_tb/ing_bus/tdest
add wave -noupdate /p4_router_ingress_tb/ing_bus/tuser
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {25910181 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 285
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {46193487 ps}
