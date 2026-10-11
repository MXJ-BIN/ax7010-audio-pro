if {[catch {
 if {$argc != 2} {error "Usage: export_ddr.tcl raw.bin metadata.txt"}
 set output [file normalize [lindex $argv 0]]
 set metadata [file normalize [lindex $argv 1]]
 foreach name [list $output $metadata "$output.part"] {
  if {[file exists $name]} {error "Output exists: $name"}
 }
 set origin [file normalize [file join [file dirname [info script]] ..]]
 connect
 targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
 loadhw -hw [file join $origin build audio_fourmic.xsa] -mem-ranges [list [list 0x00100000 0x1fffffff]]
 set meta [mrd -value 0x07fff000 16]
 if {[lindex $meta 0] != 0x41554452 || [lindex $meta 1] != 1 || [lindex $meta 2] != 2} {
  error "No complete valid DDR recording; use rec SECONDS and wait for REC_READY"
 }
 set base [lindex $meta 3];set frames [lindex $meta 4]
 if {$base != 0x08000000 || $frames <= 0 || $frames > 100663296} {error "Invalid recording address or length"}
 set binary [open $output wb]
 fconfigure $binary -translation binary
 set start [clock milliseconds]
 for {set offset 0} {$offset < $frames} {incr offset $count} {
  set count [expr {min(262144,$frames-$offset)}]
  mrd -bin -file "$output.part" [expr {$base+4*$offset}] $count
  set part [open "$output.part" rb];fconfigure $part -translation binary
  set bytes [read $part];close $part
  if {[string length $bytes] != 4*$count} {error "Short JTAG transfer at frame $offset"}
  puts -nonewline $binary $bytes
  file delete "$output.part"
  puts "DDR_EXPORT frames=[expr {$offset+$count}]/$frames"
 }
 close $binary
 set after [mrd -value 0x07fff000 16]
 if {$after ne $meta} {error "Recording changed during export; discard this export"}
 set handle [open $metadata w]
 foreach value $meta {puts $handle [format %u $value]}
 close $handle
 puts "DDR_EXPORT_PASS frames=$frames elapsed_ms=[expr {[clock milliseconds]-$start}]"
} problem options]} {
 puts stderr "DDR_EXPORT_ERROR: $problem"
 puts stderr [dict get $options -errorinfo]
 exit 1
}
exit 0
