set origin [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw -hw [file join $origin build audio_fourmic.xsa] -mem-ranges [list [list 0x43c00000 0x43c3ffff] [list 0x41200000 0x4120ffff]]
puts "HARDWARE_GAINS_OPTIONS_UI:"
puts [mrd 0x43c00000 3]
puts "HARDWARE_CAPTURE_LEVELS_DIAG_STATUS_ID_TARGET:"
puts [mrd 0x43c00010 6]
puts "HARDWARE_GPIO_CTRL:"
puts [mrd 0x41200000]
puts DIAGNOSTIC_READ_PASS
exit
