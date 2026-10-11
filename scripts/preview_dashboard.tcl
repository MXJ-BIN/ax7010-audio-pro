exec xvlog -sv ../../rtl/dashboard_text.v ../../rtl/audio_dashboard.v ../../sim/tb_dashboard.v
exec xelab tb_dashboard -snapshot tb_dashboard
set result [exec xsim tb_dashboard -R]
puts $result
if {[string first "TEST PASSED" $result]<0} {error "Dashboard simulation failed"}
