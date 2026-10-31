onerror {quit -code 1 -force}
vlib work_video_alignment
vmap work work_video_alignment
vlog -sv -work work_video_alignment ../user_source/hdl_source/display_enhance.v ../user_source/hdl_source/thumbnail_scaler.v ../user_source/hdl_source/runtime_adjust.v ../user_source/hdl_source/audio_spectrum.v ../user_source/hdl_source/audio_wave.v ../user_source/hdl_source/text_layers.v tb_video_alignment.v
vsim -novopt work_video_alignment.tb_video_alignment
onfinish stop
run -all
quit -code 0 -force
