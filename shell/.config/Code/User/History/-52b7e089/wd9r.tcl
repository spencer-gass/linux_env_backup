# $vunit_tb_path is the path containing the test bench.
source "${vunit_tb_path}/../util/avmm_waves.tcl"
source "${vunit_tb_path}/../util/axi4_waves.tcl"

# Add the signals you want to capture
add wave -noupdate avmm_clk_ifc.clk
add wave -noupdate interconnect_sreset_ifc.reset
add wave -noupdate peripheral_sreset_ifc.reset

add wave -noupdate -divider {PACKET}
add_axi4stream_waves DUT/payload_id
add_axi4stream_waves DUT/payload_32
add_axi4stream_waves DUT/payload_adapt
add wave -noupdate -divider {DEBUG_ALL}
add wave -noupdate  DUT/*

add wave -noupdate -divider {TX}
add_axi4stream_waves axis_tx
add wave -noupdate gmii_tx_*
add wave -noupdate tx_error_underflow
add wave -noupdate tx_fifo_overflow
add wave -noupdate tx_fifo_bad_frame
add wave -noupdate tx_fifo_good_frame
add wave -noupdate -divider {RX}
add_axi4stream_waves axis_rx
add wave -noupdate gmii_rx_*
add wave -noupdate rx_error_bad_frame
add wave -noupdate rx_error_bad_fcs
add wave -noupdate rx_fifo_overflow
add wave -noupdate rx_fifo_bad_frame
add wave -noupdate rx_fifo_good_frame

add wave -noupdate -divider {AVMM_IN}
add_avmm_waves avmm
