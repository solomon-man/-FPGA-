# Board oscillator: 50 MHz. PLL clocks are derived from the actual RTL settings.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
rename_clock -name sd_card_clk -source [get_ports {clk}] -master_clock clk [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name ext_mem_clk -source [get_ports {clk}] -master_clock clk [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name video_clk -source [get_ports {clk}] -master_clock clk [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name hdmi_5x_clk -source [get_ports {clk}] -master_clock clk [get_pins {video_pll_m0/pll_inst.clkc[1]}]
rename_clock -name audio_mclk -source [get_ports {clk}] -master_clock clk [get_pins {u_audio_pll/pll_inst.clkc[2]}]

# Pixel and serializer clocks run together: keep their synchronous relationship.
# The SDRAM and controller share ext_mem_clk; all read/write paths are timed.
# Audio I2S inputs and reset release are synchronized in their receiving domains.
# Include the 50 MHz power-on reset source in the non-audio clock group.
set_clock_groups -asynchronous -group [get_clocks {audio_mclk}] -group [get_clocks {clk video_clk hdmi_5x_clk sd_card_clk ext_mem_clk}]
# System PLL and video PLL have separate lock/reset acquisition. Crossings use
# asynchronous FIFOs, synchronizer chains, or acknowledged stable mailboxes.
# Do not assume a fixed edge phase between those two PLLs after configuration.
# Keep SDRAM and pixel/TMDS clock relationships fully timed.
set_clock_groups -asynchronous -group [get_clocks {sd_card_clk ext_mem_clk}] -group [get_clocks {video_clk hdmi_5x_clk}]

# SD and SDRAM user clocks communicate through the dual-clock frame FIFOs.
# Their Gray-pointer synchronizers are intentionally asynchronous; do not
# force a phase relationship between the 100 MHz SD clock and the 83.333 MHz
# SDRAM clock. All SDRAM interface paths remain timed on ext_mem_clk.
set_clock_groups -asynchronous -group [get_clocks {sd_card_clk}] -group [get_clocks {ext_mem_clk}]

# Raw asynchronous reset into reset_release chains only.
# Synchronized release stages and downstream consumers remain timed.
set_false_path -through [get_nets {rst_all}]
