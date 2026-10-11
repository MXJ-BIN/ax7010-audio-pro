if {[catch {
set origin [file normalize [file join [file dirname [info script]] ..]]
set handle [open D:/ax7010-audio-pro-vitis/last_workspace.txt r]
set ws [string trim [read $handle]]
close $handle
set bit [file join $origin build project ax7010_pro.runs impl_1 audio_ps_wrapper.bit]
if {$argc > 0} {set bit [file normalize [lindex $argv 0]]}
set elf [file join $ws doa_uart build doa_uart.elf]
set init [file join $ws audio_plat export audio_plat hw sdt ps7_init.tcl]
foreach required [list $bit $elf $init] {
    if {![file exists $required]} {error "Missing file: $required; finish hardware/software build first"}
}
set ready_path [file join $origin build hardware_ready.txt]
if {![file exists $ready_path]} {error "Hardware release gate missing; complete timing-checked hardware build first"}
set ready_handle [open $ready_path r]
set ready_mtime [string trim [read $ready_handle]]
close $ready_handle
if {[file mtime $bit] != $ready_mtime || [file mtime $elf] < $ready_mtime} {error "Bitstream/ELF release dates mismatch; rebuild hardware then Vitis"}
puts "DOWNLOAD: bit=$bit"
puts "DOWNLOAD: elf=$elf"
connect
puts "JTAG targets:"
puts [targets]
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
rst -system
after 1000
puts "STEP: program FPGA"
fpga -file $bit
puts "STEP: initialize PS"
source $init
ps7_init
ps7_post_config
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
puts "STEP: download ELF"
dow $elf
con
puts "DOWNLOAD_PASS: ARM started; watch UART 115200 8N1, no flow control"
} problem options]} {
    puts stderr "DOWNLOAD_ERROR: $problem"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
