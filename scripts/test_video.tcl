exec xvlog -sv ../../rtl/video_timing_720p.v ../../sim/tb_video_timing.v
exec xelab tb_video_timing -snapshot tb_video_timing
set result [exec xsim tb_video_timing -R]
puts $result
if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Video timing test failed"}
