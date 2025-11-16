set_property PACKAGE_PIN U26 [get_ports clk_in1_p]
set_property IOSTANDARD LVDS_25 [get_ports clk_in1_p]

set_property PACKAGE_PIN U27 [get_ports clk_in1_n]
set_property IOSTANDARD LVDS_25 [get_ports clk_in1_n]

set_property PACKAGE_PIN G10 [get_ports rst_pin]
set_property IOSTANDARD LVCMOS15 [get_ports rst_pin]

set_property PACKAGE_PIN AB25 [get_ports rxd_pin]
set_property IOSTANDARD LVCMOS33 [get_ports rxd_pin]

set_property PACKAGE_PIN AA25 [get_ports txd_pin]
set_property IOSTANDARD LVCMOS33 [get_ports txd_pin]

set_property PACKAGE_PIN F5 [get_ports led_run]
set_property IOSTANDARD LVCMOS15 [get_ports led_run]

set_property PACKAGE_PIN G2 [get_ports led]
set_property IOSTANDARD LVCMOS15 [get_ports led]


set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
