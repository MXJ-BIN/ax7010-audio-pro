exec xvlog -sv -i . ../../rtl/speech_band.v ../../sim/tb_speech_band.v
exec xelab tb_speech_band -snapshot tb_speech_band
set result [exec xsim tb_speech_band -R]
puts $result
if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Speech filter test failed"}
