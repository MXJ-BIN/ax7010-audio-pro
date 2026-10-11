# Run in Vivado TCL; all output is isolated from existing release builds.
set origin [file normalize [file join [file dirname [info script]] ..]]
file mkdir $origin/build/doa_gcc
cd $origin/build/doa_gcc
exec xvlog -sv $env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv {*}[glob $origin/rtl/*.v]
foreach test {tb_doa_gcc_phat tb_doa_gcc_band tb_doa_full tb_doa_square tb_audio_spectrum tb_direction_track} {
 exec xvlog -sv $origin/sim/$test.v
 exec xelab $test -snapshot $test
 set result [exec xsim $test -R]
 puts $result
 set f [open $test.log w];puts $f $result;close $f
 if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Test failed: $test"}
}
puts DOA_GCC_TEST_PASS
