onerror {quit -code 1 -force}
vlib work_122
vmap work work_122
vlog -sv ../user_source/hdl_source/source_scale_address.v ../user_source/hdl_source/SD/frame_fifo_read.v ../user_source/hdl_source/audio_mix122.v tb_audio122.v
vsim -novopt work.tb_audio122
onfinish stop
run -all
quit -code 0 -force
