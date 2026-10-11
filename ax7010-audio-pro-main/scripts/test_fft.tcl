exec xvlog -sv D:/AMDDesignTools/2026.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
exec xvlog -sv ../../rtl/audio_spectrum.v ../../sim/tb_audio_spectrum.v
exec xelab tb_audio_spectrum -snapshot tb_audio_spectrum
set result [exec xsim tb_audio_spectrum -R]
puts $result
if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "FFT test failed"}
