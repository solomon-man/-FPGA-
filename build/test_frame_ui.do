onerror {quit -code 1 -force}
vlib work_frame_ui
vmap work work_frame_ui
vlog -sv ../user_source/hdl_source/display_controls4.v ../user_source/hdl_source/text_layers.v tb_frame_ui.v
vsim -novopt work.tb_frame_ui
onfinish stop
run -all
quit -code 0 -force
