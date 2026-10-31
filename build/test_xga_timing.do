onerror {quit -code 1 -force}
vlib work_xga_timing
vlog -work work_xga_timing -sv +incdir+../user_source/hdl_source/SD ../user_source/hdl_source/SD/color_bar.v ../user_source/hdl_source/video_rgb_to_axis_640x480.v tb_xga_timing.v
vsim -novopt work_xga_timing.tb_xga_timing
run -all
quit -code 0 -force
