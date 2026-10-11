# AX7010 PL 50 MHz oscillator
set_property PACKAGE_PIN U18 [get_ports pl_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports pl_clk_50m]
create_clock -name pl_clk_50m -period 20.000 [get_ports pl_clk_50m]

# PL keys, active low.
# Key1: mic monitor. Key2: quieter. Key3: dry bypass.
set_property PACKAGE_PIN N15 [get_ports key1_n]
set_property PACKAGE_PIN N16 [get_ports key2_n]
set_property PACKAGE_PIN T17 [get_ports key3_n]
set_property IOSTANDARD LVCMOS33 [get_ports key1_n]
set_property IOSTANDARD LVCMOS33 [get_ports key2_n]
set_property IOSTANDARD LVCMOS33 [get_ports key3_n]

# PL LEDs, active low. LED1 is the mic0 / left side.
set_property PACKAGE_PIN M14 [get_ports {led_n[0]}]
set_property PACKAGE_PIN M15 [get_ports {led_n[1]}]
set_property PACKAGE_PIN K16 [get_ports {led_n[2]}]
set_property PACKAGE_PIN J16 [get_ports {led_n[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_n[*]}]

# J11 expansion header, Bank35, 3.3 V.
# Pin1 GND, pin39/40 3.3 V. Do not tie the PCM5102A VDD33 pin back to the FPGA.
set_property PACKAGE_PIN F17 [get_ports mic0_sd]
set_property PACKAGE_PIN F16 [get_ports mic1_sd]
set_property PACKAGE_PIN F20 [get_ports i2s_bclk]
set_property PACKAGE_PIN F19 [get_ports i2s_lrck]
set_property PACKAGE_PIN G20 [get_ports i2s_dac_sd]
set_property IOSTANDARD LVCMOS33 [get_ports mic0_sd]
set_property IOSTANDARD LVCMOS33 [get_ports mic1_sd]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrck]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_dac_sd]

set_property PACKAGE_PIN G19 [get_ports mic2_sd]
set_property PACKAGE_PIN H18 [get_ports mic3_sd]
set_property IOSTANDARD LVCMOS33 [get_ports {mic2_sd mic3_sd}]

# External audio pins are synchronous to the PL clock at the board boundary.
# Use explicit board-level budgets so check_timing does not leave these paths
# unconstrained. Tighten these values when measured pin-to-pin timing is known.
set_input_delay  -clock pl_clk_50m -max 0.000 [get_ports {mic0_sd mic1_sd mic2_sd mic3_sd}]
set_input_delay  -clock pl_clk_50m -min 0.000 [get_ports {mic0_sd mic1_sd mic2_sd mic3_sd}]
set_output_delay -clock pl_clk_50m -max 0.000 [get_ports {i2s_bclk i2s_lrck i2s_dac_sd}]
set_output_delay -clock pl_clk_50m -min 0.000 [get_ports {i2s_bclk i2s_lrck i2s_dac_sd}]
set_output_delay -clock pl_clk_50m -max 0.000 [get_ports {led_n[*]}]
set_output_delay -clock pl_clk_50m -min 0.000 [get_ports {led_n[*]}]

set_property PACKAGE_PIN N18 [get_ports hdmi_clk_p]
set_property PACKAGE_PIN V20 [get_ports {hdmi_d_p[0]}]
set_property PACKAGE_PIN T20 [get_ports {hdmi_d_p[1]}]
set_property PACKAGE_PIN N20 [get_ports {hdmi_d_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {
    hdmi_clk_p hdmi_clk_n hdmi_d_p[*] hdmi_d_n[*]
}]

set_property PACKAGE_PIN V16 [get_ports hdmi_out_en]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_out_en]

set_false_path -from [get_ports {key1_n key2_n key3_n}] -to [get_cells -hier -filter {NAME =~ *key_meta_reg*}]
