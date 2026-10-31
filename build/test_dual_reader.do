onerror {quit -code 1 -force}
vlib work_dual_reader
vlog -work work_dual_reader -sv ../user_source/hdl_source/xga_scale_config.v ../user_source/hdl_source/scaled_frame_reader.v ../user_source/hdl_source/SD/frame_fifo_read.v tb_dual_reader.v
vsim -novopt work_dual_reader.tb_dual_reader
run -all
quit -code 0 -force
