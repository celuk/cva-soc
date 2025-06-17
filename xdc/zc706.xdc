set_property PACKAGE_PIN H9 [get_ports clk_p]
set_property IOSTANDARD LVDS [get_ports clk_p]
set_property PACKAGE_PIN G9 [get_ports clk_n]
set_property IOSTANDARD LVDS [get_ports clk_n]
create_clock -period 5.000 -name clk_200mhz_p [get_ports clk_p]

# PMOD1_5_LS
#set_property PACKAGE_PIN AA20 [get_ports uart_rx_i]
#set_property IOSTANDARD LVCMOS25 [get_ports uart_rx_i]

set_property PACKAGE_PIN AA20 [get_ports program_rx_i]
set_property IOSTANDARD LVCMOS25 [get_ports program_rx_i]

# PMOD1_4_LS
set_property PACKAGE_PIN Y20 [get_ports uart_tx_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart_tx_o]

# GPIO_LED_0
set_property PACKAGE_PIN A17 [get_ports prog_mode_led_o]
set_property IOSTANDARD LVCMOS15 [get_ports prog_mode_led_o]

# GPIO_DIP_SW3
set_property PACKAGE_PIN AJ13 [get_ports rst_ni]
set_property IOSTANDARD LVCMOS25 [get_ports rst_ni]
