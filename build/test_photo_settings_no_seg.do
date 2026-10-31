onerror {quit -code 1 -force}
vlib work_no_seg
vmap work work_no_seg
vlog -sv ../user_source/hdl_source/display_controls4.v ../user_source/hdl_source/text_layers.v ../user_source/hdl_source/frame_commit.v tb_six_commit.v
vsim -novopt work.tb_six_commit
onfinish stop
run -all
quit -code 0 -force
