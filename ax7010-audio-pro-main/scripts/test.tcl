exec xvlog -sv $env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
foreach test {tb_i2s_four tb_doa_square tb_beamformer tb_fx_stereo tb_tmds_encoder tb_doa_full tb_doa_gcc_phat tb_doa_gcc_band tb_audio_control tb_audio_spectrum tb_direction_track tb_audio_conditioner tb_capture_stream} {
 exec xvlog -sv ../../rtl/dc_block.v ../../rtl/speech_band.v ../../rtl/audio_control.v ../../rtl/audio_spectrum.v ../../rtl/direction_track.v ../../rtl/audio_conditioner.v ../../rtl/mic_gain.v ../../rtl/tmds_encoder.v ../../rtl/i2s_duplex.v ../../rtl/doa_square.v ../../rtl/doa_time_domain.v ../../rtl/doa_fft512.v ../../rtl/doa_gcc_phat.v ../../rtl/beamformer.v ../../rtl/voice_eq.v ../../rtl/reverb_lite.v ../../rtl/fx_stereo.v ../../sim/${test}.v
 exec xelab $test -snapshot $test
 set result [exec xsim $test -R]
 puts $result
 set f [open $test.log w];puts $f $result;close $f
 if {[string first "TEST PASSED" $result]<0 || [string first "Fatal:" $result]>=0} {error "Test failed: $test"}
}
puts FOURMIC_TEST_PASS
