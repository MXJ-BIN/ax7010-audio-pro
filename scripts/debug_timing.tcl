set origin [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $origin build project ax7010_pro.runs impl_1 audio_ps_wrapper_placed.dcp]
report_timing -delay_type max -max_paths 10 -file [file join $origin build timing_debug.rpt]
exit
