exec xvlog -sv ../../rtl/audio_control.v ../../sim/tb_capture_stream.v ../../sim/tb_capture_full.v
foreach test {tb_capture_stream tb_capture_full} {
 exec xelab $test -snapshot $test
 set result [exec xsim $test -R]
 puts $result
 if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Capture test failed: $test"}
}
