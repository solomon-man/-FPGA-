onerror {quit -code 1 -force}
vlib work_xga
vlog -work work_xga -sv ../user_source/hdl_source/xga_scale_config.v ../user_source/hdl_source/scaled_frame_reader.v ../user_source/hdl_source/SD/frame_fifo_read.v tb_xga_reader.v
vsim -novopt work_xga.tb_xga_reader
run -all
quit -code 0 -force
