set_property SEVERITY Warning [get_drc_checks LUTLP-1]

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

## DDR3
## ref: https://github.com/CMU-SAFARI/PiDRAM/blob/master/controller-hardware/sources/new_ZC706.xdc

# PadFunction: IO_L7P_T1_AD2P_35
set_property VCCAUX_IO HIGH [get_ports ddr3_reset_n]
set_property SLEW FAST [get_ports ddr3_reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports ddr3_reset_n]
set_property PACKAGE_PIN G17 [get_ports ddr3_reset_n]

# PadFunction: IO_L10N_T1_34
set_property VCCAUX_IO HIGH [get_ports ddr3_cke]
set_property SLEW FAST [get_ports ddr3_cke]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cke]
set_property PACKAGE_PIN D10 [get_ports ddr3_cke]

# PadFunction: IO_L7P_T1_34
set_property VCCAUX_IO HIGH [get_ports ddr3_cs_n]
set_property SLEW FAST [get_ports ddr3_cs_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cs_n]
set_property PACKAGE_PIN J11 [get_ports ddr3_cs_n]

# PadFunction: IO_L7N_T1_34
set_property VCCAUX_IO HIGH [get_ports ddr3_ras_n]
set_property SLEW FAST [get_ports ddr3_ras_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_ras_n]
set_property PACKAGE_PIN H11 [get_ports ddr3_ras_n]

# PadFunction: IO_L17P_T2_34
set_property VCCAUX_IO HIGH [get_ports ddr3_cas_n]
set_property SLEW FAST [get_ports ddr3_cas_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cas_n]
set_property PACKAGE_PIN E7 [get_ports ddr3_cas_n]

# PadFunction: IO_L16N_T2_34
set_property VCCAUX_IO HIGH [get_ports ddr3_we_n]
set_property SLEW FAST [get_ports ddr3_we_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_we_n]
set_property PACKAGE_PIN F7 [get_ports ddr3_we_n]

## DDR3_DM

# PadFunction: IO_L1N_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dm[0]}]
set_property SLEW FAST [get_ports {ddr3_dm[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN J3 [get_ports {ddr3_dm[0]}]

# PadFunction: IO_L7N_T1_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dm[1]}]
set_property SLEW FAST [get_ports {ddr3_dm[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[1]}]
set_property PACKAGE_PIN F2 [get_ports {ddr3_dm[1]}]

##

## DDR3_BA

# PadFunction: IO_L3N_T0_DQS_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_ba[2]}]
set_property SLEW FAST [get_ports {ddr3_ba[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[2]}]
set_property PACKAGE_PIN A7 [get_ports {ddr3_ba[2]}]

# PadFunction: IO_L18P_T2_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_ba[1]}]
set_property SLEW FAST [get_ports {ddr3_ba[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN H7 [get_ports {ddr3_ba[1]}]

# PadFunction: IO_L16P_T2_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_ba[0]}]
set_property SLEW FAST [get_ports {ddr3_ba[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN F8 [get_ports {ddr3_ba[0]}]

##

## DDR3_ADDR

# PadFunction: IO_L1N_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[13]}]
set_property SLEW FAST [get_ports {ddr3_addr[13]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[13]}]
set_property PACKAGE_PIN A10 [get_ports {ddr3_addr[13]}]

##

# PadFunction: IO_L9P_T1_DQS_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[12]}]
set_property SLEW FAST [get_ports {ddr3_addr[12]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN H12 [get_ports {ddr3_addr[12]}]

# PadFunction: IO_L4N_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[11]}]
set_property SLEW FAST [get_ports {ddr3_addr[11]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN B7 [get_ports {ddr3_addr[11]}]

# PadFunction: IO_L17N_T2_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[10]}]
set_property SLEW FAST [get_ports {ddr3_addr[10]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN D6 [get_ports {ddr3_addr[10]}]

# PadFunction: IO_L15P_T2_DQS_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[9]}]
set_property SLEW FAST [get_ports {ddr3_addr[9]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN J8 [get_ports {ddr3_addr[9]}]

# PadFunction: IO_L1P_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[8]}]
set_property SLEW FAST [get_ports {ddr3_addr[8]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN B10 [get_ports {ddr3_addr[8]}]

# PadFunction: IO_L14N_T2_SRCC_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[7]}]
set_property SLEW FAST [get_ports {ddr3_addr[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN E8 [get_ports {ddr3_addr[7]}]

# PadFunction: IO_L14P_T2_SRCC_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[6]}]
set_property SLEW FAST [get_ports {ddr3_addr[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN F9 [get_ports {ddr3_addr[6]}]

# PadFunction: IO_L5N_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[5]}]
set_property SLEW FAST [get_ports {ddr3_addr[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN B6 [get_ports {ddr3_addr[5]}]

# PadFunction: IO_L8N_T1_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[4]}]
set_property SLEW FAST [get_ports {ddr3_addr[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN D11 [get_ports {ddr3_addr[4]}]

# PadFunction: IO_L2N_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[3]}]
set_property SLEW FAST [get_ports {ddr3_addr[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN A9 [get_ports {ddr3_addr[3]}]

# PadFunction: IO_L8P_T1_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[2]}]
set_property SLEW FAST [get_ports {ddr3_addr[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN E11 [get_ports {ddr3_addr[2]}]

# PadFunction: IO_L2P_T0_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[1]}]
set_property SLEW FAST [get_ports {ddr3_addr[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN B9 [get_ports {ddr3_addr[1]}]

# PadFunction: IO_L10P_T1_34
set_property VCCAUX_IO HIGH [get_ports {ddr3_addr[0]}]
set_property SLEW FAST [get_ports {ddr3_addr[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN E10 [get_ports {ddr3_addr[0]}]

##

## DDR3_DQ

# PadFunction: IO_L2P_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[0]}]
set_property SLEW FAST [get_ports {ddr3_dq[0]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN L1 [get_ports {ddr3_dq[0]}]

# PadFunction: IO_L4N_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[1]}]
set_property SLEW FAST [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN L2 [get_ports {ddr3_dq[1]}]

# PadFunction: IO_L5P_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[2]}]
set_property SLEW FAST [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN K5 [get_ports {ddr3_dq[2]}]

# PadFunction: IO_L1P_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[3]}]
set_property SLEW FAST [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN J4 [get_ports {ddr3_dq[3]}]

# PadFunction: IO_L2N_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[4]}]
set_property SLEW FAST [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN K1 [get_ports {ddr3_dq[4]}]

# PadFunction: IO_L4P_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[5]}]
set_property SLEW FAST [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN L3 [get_ports {ddr3_dq[5]}]

# PadFunction: IO_L5N_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[6]}]
set_property SLEW FAST [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN J5 [get_ports {ddr3_dq[6]}]

# PadFunction: IO_L6P_T0_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[7]}]
set_property SLEW FAST [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN K6 [get_ports {ddr3_dq[7]}]

# PadFunction: IO_L8N_T1_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[8]}]
set_property SLEW FAST [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN G6 [get_ports {ddr3_dq[8]}]

# PadFunction: IO_L11P_T1_SRCC_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[9]}]
set_property SLEW FAST [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN H4 [get_ports {ddr3_dq[9]}]

# PadFunction: IO_L8P_T1_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[10]}]
set_property SLEW FAST [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN H6 [get_ports {ddr3_dq[10]}]

# PadFunction: IO_L11N_T1_SRCC_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[11]}]
set_property SLEW FAST [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN H3 [get_ports {ddr3_dq[11]}]

# PadFunction: IO_L10N_T1_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[12]}]
set_property SLEW FAST [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN G1 [get_ports {ddr3_dq[12]}]

# PadFunction: IO_L10P_T1_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[13]}]
set_property SLEW FAST [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN H2 [get_ports {ddr3_dq[13]}]

# PadFunction: IO_L12P_T1_MRCC_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[14]}]
set_property SLEW FAST [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN G5 [get_ports {ddr3_dq[14]}]

# PadFunction: IO_L12N_T1_MRCC_33
set_property VCCAUX_IO HIGH [get_ports {ddr3_dq[15]}]
set_property SLEW FAST [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[15]}]
set_property PACKAGE_PIN G4 [get_ports {ddr3_dq[15]}]

##

## DDR3_DQS_P

# PadFunction: IO_L3P_T0_DQS_33
set_property VCCAUX_IO HIGH [get_ports ddr3_dqs_p[0]]
set_property SLEW FAST [get_ports ddr3_dqs_p[0]]
## bu sekilde diffli olacaksa buf ip felan kullanmak lazim sanirim
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports ddr3_dqs_p[0]]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports ddr3_dqs_p[0]]
set_property PACKAGE_PIN K3 [get_ports ddr3_dqs_p[0]]

# PadFunction: IO_L9P_T1_DQS_33
set_property VCCAUX_IO HIGH [get_ports ddr3_dqs_p[1]]
set_property SLEW FAST [get_ports ddr3_dqs_p[1]]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports ddr3_dqs_p[1]]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports ddr3_dqs_p[1]]
set_property PACKAGE_PIN J1 [get_ports ddr3_dqs_p[1]]

##

## DDR3_DQS_N

# PadFunction: IO_L3N_T0_DQS_33
set_property SLEW FAST [get_ports ddr3_dqs_n[0]]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports ddr3_dqs_n[0]]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports ddr3_dqs_n[0]]
set_property PACKAGE_PIN K2 [get_ports ddr3_dqs_n[0]]

# PadFunction: IO_L9N_T1_DQS_33
set_property SLEW FAST [get_ports ddr3_dqs_n[1]]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports ddr3_dqs_n[1]]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports ddr3_dqs_n[1]]
set_property PACKAGE_PIN H1 [get_ports ddr3_dqs_n[1]]

##

# PadFunction: IO_L18N_T2_34
set_property VCCAUX_IO HIGH [get_ports ddr3_odt]
set_property SLEW FAST [get_ports ddr3_odt]
set_property IOSTANDARD SSTL15 [get_ports ddr3_odt]
set_property PACKAGE_PIN G7 [get_ports ddr3_odt]

##

# PadFunction: IO_L11P_T1_SRCC_34
set_property VCCAUX_IO HIGH [get_ports ddr3_ck_p]
set_property SLEW FAST [get_ports ddr3_ck_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_p]

# PadFunction: IO_L11N_T1_SRCC_34
set_property SLEW FAST [get_ports ddr3_ck_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_n]
set_property PACKAGE_PIN G10 [get_ports ddr3_ck_p]
set_property PACKAGE_PIN F10 [get_ports ddr3_ck_n]
