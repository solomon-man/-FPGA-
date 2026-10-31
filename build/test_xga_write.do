onerror {quit -code 1 -force}
vlib work_xga_write
vlog -work work_xga_write -sv ../user_source/hdl_source/SD/frame_fifo_write.v tb_xga_write.v
vsim -novopt work_xga_write.tb_xga_write
run -all
quit -code 0 -force
