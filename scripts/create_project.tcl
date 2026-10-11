set origin [file normalize [file join [file dirname [info script]] ..]]
cd $origin
create_project ax7010_pro ./build/project -part xc7z010clg400-1 -force
set_property target_language Verilog [current_project]
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY} [current_project]
add_files [glob ./rtl/*.v]
add_files -fileset constrs_1 ./constr/ax7010_audio.xdc
add_files -fileset sim_1 [glob ./sim/*.v]
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name video_clock
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {371.250} CONFIG.NUM_OUT_CLKS {2} CONFIG.USE_LOCKED {true} CONFIG.USE_RESET {true} CONFIG.RESET_TYPE {ACTIVE_HIGH}] [get_ips video_clock]
generate_target all [get_ips video_clock]
source ./scripts/create_bd.tcl
set_property top audio_ps_wrapper [current_fileset]
update_compile_order -fileset sources_1


close_project
