onerror {quit -code 1 -force}
vlib work_reader_owner
vlog -work work_reader_owner -sv ../user_source/hdl_source/xga_scale_config.v ../user_source/hdl_source/scaled_frame_reader.v ../user_source/hdl_source/SD/frame_fifo_read.v tb_reader_owner.v
vsim -novopt work_reader_owner.tb_reader_owner
run -all
quit -code 0 -force
