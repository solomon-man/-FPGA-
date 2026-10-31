onerror {quit -code 1 -force}
vlib work_pll_clocks
vlog -work work_pll_clocks E:/TD_Engineer/sim_release/eg4/eg_phy_pll.v sim_bufg.v ../user_source/hdl_source/IP/sys_pll.v ../user_source/hdl_source/IP/video_pll.v ../user_source/hdl_source/IP/PLL_HDMI_AUDIO.v
vlog -sv -work work_pll_clocks tb_pll_clocks.v
vsim -novopt work_pll_clocks.tb_pll_clocks
onfinish stop
run -all
quit -code 0 -force
