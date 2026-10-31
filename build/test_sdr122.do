onerror {quit -code 1 -force}
vlib work_sdr122
vmap work work_sdr122
vlog -sv +incdir+../user_source/hdl_source/include ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/source_scale_address.v ../user_source/hdl_source/scaled_frame_reader.v ../user_source/hdl_source/SD/frame_fifo_read.v tb_sdr_scale122.v
vsim -novopt work.tb_sdr_scale122
onfinish stop
run -all
quit -code 0 -force

