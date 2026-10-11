set origin [file normalize [file join [file dirname [info script]] ..]]
cd $origin
if {[file exists ./build/hardware_ready.txt]} {file delete ./build/hardware_ready.txt}
open_project ./build/project/ax7010_pro.xpr
foreach rtl_file [glob ./rtl/*.v] {
    set present 0
    foreach known_file [get_files -quiet] {
        if {[file normalize $known_file] eq [file normalize $rtl_file]} {set present 1; break}
    }
    if {!$present} {add_files -norecurse $rtl_file}
}
update_compile_order -fileset sources_1
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY} [current_project]
if {[get_property CONFIG.PRIM_SOURCE [get_ips video_clock]] ne "No_buffer"} {
    set_property CONFIG.PRIM_SOURCE No_buffer [get_ips video_clock]
    generate_target all [get_ips video_clock]
}
# Module-reference OOC checkpoints must be rebuilt after nested RTL changes.
set audio_runs [get_runs -quiet -filter {NAME =~ *audio_top*synth_1 || NAME =~ *audio_control*synth_1}]
if {[llength $audio_runs] > 0} {reset_run $audio_runs}
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_utilization -file ./build/utilization.rpt
report_timing_summary -report_unconstrained -file ./build/timing.rpt
report_cdc -details -file ./build/cdc.rpt
report_methodology -file ./build/methodology.rpt
report_bus_skew -file ./build/bus_skew.rpt
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0} {error "Setup timing failed; do not release this bitstream"}
if {[get_property SLACK [get_timing_paths -delay_type min -max_paths 1]] < 0} {error "Hold timing failed; do not release this bitstream"}
write_hw_platform -fixed -include_bit -force ./build/audio_fourmic.xsa
set ready [open ./build/hardware_ready.txt w]
puts $ready [file mtime ./build/project/ax7010_pro.runs/impl_1/audio_ps_wrapper.bit]
close $ready
puts FOURMIC_BUILD_PASS
