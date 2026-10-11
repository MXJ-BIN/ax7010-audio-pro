set restore_ready 0
set problem ""
set rc [catch {
 if {$argc != 5} {error "Usage: run_ai_eval.tcl input.bin output.bin result.txt frames input_crc_hex"}
 lassign $argv input output result frames crc_hex
 set input [file normalize $input];set output [file normalize $output];set result [file normalize $result]
 if {$frames < 1 || $frames > 12001 || [file size $input] != $frames*960} {error "Invalid input length"}
 foreach path [list $output $result "$output.part"] {if {[file exists $path]} {error "Output exists: $path"}}
 set origin [file normalize [file join [file dirname [info script]] ..]]
 set f [open D:/ax7010-audio-pro-vitis/last_workspace.txt r];set ws [string trim [read $f]];close $f
 set bit [file join $origin build project ax7010_pro.runs impl_1 audio_ps_wrapper.bit]
 set production_elf [file join $ws doa_uart build doa_uart.elf]
 set init [file join $ws audio_plat export audio_plat hw sdt ps7_init.tcl]
 set ai_elf [file join $origin build ai_eval ai_eval.elf]
 foreach path [list $bit $production_elf $init $ai_elf] {if {![file exists $path]} {error "Missing $path"}}
 set f [open [file join $origin build hardware_ready.txt] r];set stamp [string trim [read $f]];close $f
 if {[file mtime $bit] != $stamp || [file mtime $production_elf] < $stamp} {error "Production firmware release gate mismatch"}
 connect
 targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
 set restore_ready 1
 rst -system
 after 1000
 fpga -file $bit
 source $init
 ps7_init
 ps7_post_config
 loadhw -hw [file join $origin build audio_fourmic.xsa] -mem-ranges [list [list 0x00100000 0x1fffffff] [list 0x41200000 0x4120ffff]]
 mwr 0x41200000 0x1800003f
 targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
 dow $ai_elf
 dow -data $input 0x08000000
 for {set i 0} {$i < 32} {incr i} {mwr [expr {0x07ffe000+4*$i}] 0}
 mwr 0x07ffe000 0x41494556
 mwr 0x07ffe004 1
 mwr 0x07ffe00c $frames
 scan $crc_hex %x crc_value
 mwr 0x07ffe010 $crc_value
 con
 set deadline [expr {[clock seconds]+300}]
 while {1} {
  after 500
  set state [lindex [mrd -value 0x07ffe008 1] 0]
  if {$state == 2 || $state == 3} {break}
  if {[clock seconds] > $deadline} {error "PS inference timeout"}
 }
 set meta [mrd -value 0x07ffe000 32]
 set f [open $result w];foreach v $meta {puts $f [format %u $v]};close $f
 if {$state != 2} {error "AI error code [lindex $meta 5], nonfinite=[lindex $meta 17]"}
 set f [open $output wb];fconfigure $f -translation binary
 set words [expr {$frames*240}]
 for {set offset 0} {$offset < $words} {incr offset $count} {
  set count [expr {min(262144,$words-$offset)}]
  mrd -bin -file "$output.part" [expr {0x10000000+4*$offset}] $count
  set p [open "$output.part" rb];fconfigure $p -translation binary;set block [read $p];close $p
  if {[string length $block] != $count*4} {error "Short output transfer"}
  puts -nonewline $f $block
  file delete "$output.part"
 }
 close $f
 puts "AI_EVAL_INFERENCE_PASS frames=$frames max_us=[lindex $meta 10] late=[lindex $meta 16]"
} problem options]
if {$restore_ready} {
 if {[catch {
  targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
  rst -system
  after 1000
  fpga -file $bit
  source $init
  ps7_init
  ps7_post_config
  targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
  dow $production_elf
  con
  puts AI_EVAL_RESTORE_PASS
 } restore_error]} {puts stderr "RESTORE_FAILED: $restore_error; run scripts/run_doa_uart.bat";exit 2}
}
if {$rc} {puts stderr "AI_EVAL_ERROR: $problem";exit 1}
exit 0
