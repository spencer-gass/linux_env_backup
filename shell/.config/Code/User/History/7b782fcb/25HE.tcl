# $vunit_tb_path is the path containing the test bench.
# source "${vunit_tb_path}/../util/mmi_waves.tcl"

# Add the signals you want to capture
add wave -noupdate /dac_ad5601_ctrl_mmi_tb/clk_ifc/clk
add wave -noupdate /dac_ad5601_ctrl_mmi_tb/interconnect_sreset_ifc/reset
add wave -noupdate /dac_ad5601_ctrl_mmi_tb/peripheral_sreset_ifc/reset

add wave -noupdate -divider MMI
add wave -noupdate /dac_ad5601_ctrl_mmi_tb/mmi

add wave -noupdate -divider SPI
add wave -noupdate {/dac_ad5601_ctrl_mmi_tb/spi_cmd[0]/start_cmd}
add wave -noupdate {/dac_ad5601_ctrl_mmi_tb/spi_cmd[0]/rdy}
add wave -noupdate -radix hexadecimal {/dac_ad5601_ctrl_mmi_tb/spi_cmd[0]/tx_data}

add wave -noupdate -divider DAC
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/dac_reg
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/dac_reg_valid_stb
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/dac_reg_updated_stb

add wave -noupdate -divider EXPECTED
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/expected_dut_regs
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/expected_start_cmd
add wave -noupdate -radix hexadecimal /dac_ad5601_ctrl_mmi_tb/expected_tx_data