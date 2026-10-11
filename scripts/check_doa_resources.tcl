# Isolated DOA synthesis/implementation; production project is untouched.
set origin [file normalize [file join [file dirname [info script]] ..]]
cd $origin
file mkdir build/doa_gcc
foreach variant {before after} {
 close_project
 if {$variant eq "before"} {
  if {![file exists build/doa_gcc/doa_square_before.v]} {error "Original snapshot build/doa_gcc/doa_square_before.v is required"}
  read_verilog build/doa_gcc/doa_square_before.v
 } else {
  read_verilog {rtl/doa_square.v rtl/doa_time_domain.v rtl/doa_fft512.v rtl/doa_gcc_phat.v}
  set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
 }
 synth_design -top doa_square -part xc7z010clg400-1 -mode out_of_context
 create_clock -name clk -period 20 [get_ports clk]
 report_utilization -file [format "build/doa_gcc/%s_utilization.rpt" $variant]
 report_timing_summary -file [format "build/doa_gcc/%s_synth_timing.rpt" $variant]
 write_checkpoint -force [format "build/doa_gcc/%s_synth.dcp" $variant]
 opt_design
 place_design
 route_design
 report_utilization -file [format "build/doa_gcc/%s_routed_utilization.rpt" $variant]
 report_timing_summary -file [format "build/doa_gcc/%s_routed_timing.rpt" $variant]
 write_checkpoint -force [format "build/doa_gcc/%s_routed.dcp" $variant]
}
puts DOA_RESOURCE_CHECK_PASS
