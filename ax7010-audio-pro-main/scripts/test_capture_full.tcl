exec xvlog -sv ../../rtl/audio_control.v ../../sim/tb_capture_full.v
exec xelab tb_capture_full -snapshot tb_capture_full
set result [exec xsim tb_capture_full -R]
puts $result
if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Capture test failed"}
