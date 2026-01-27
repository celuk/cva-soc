open_hw_manager
connect_hw_server
#open_hw_target
open_hw_target {localhost:3121/xilinx_tcf/Digilent/210183741927A}

if { $argc > 0 } {
    set bitstream_file [lindex $argv 0]
} else {
    puts "No bitstream file specified, using default."
    set bitstream_file "/home/shc/projects/cva-soc/vivado/buart/buart.runs/impl_1/prog_uart.bit"
}

current_hw_device [get_hw_devices xc7a35t_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7a35t_0] 0]
set_property PROBES.FILE {} [get_hw_devices xc7a35t_0]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7a35t_0]
set_property PROGRAM.FILE $bitstream_file [get_hw_devices xc7a35t_0]
program_hw_devices [get_hw_devices xc7a35t_0]
refresh_hw_device [lindex [get_hw_devices xc7a35t_0] 0]

close_hw_manager
