onerror {quit -code 1 -force}
vlib work_features
vmap work work_features
vlog -sv ../user_source/hdl_source/display_controls4.v ../user_source/hdl_source/runtime_adjust.v ../user_source/hdl_source/thumbnail_scaler.v ../user_source/hdl_source/frame_commit.v ../user_source/hdl_source/parameter_mailbox.v ../user_source/hdl_source/text_layers.v tb_features.v
vsim -novopt work.tb_features
onfinish stop
run -all
quit -code 0 -force
