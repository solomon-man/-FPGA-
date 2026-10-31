onerror {quit -code 1 -force}
vlib work_wave_display3
vmap work work_wave_display3
vlog -sv -work work_wave_display3 ../user_source/hdl_source/display_enhance.v ../user_source/hdl_source/thumbnail_scaler.v ../user_source/hdl_source/runtime_adjust.v ../user_source/hdl_source/audio_spectrum.v ../user_source/hdl_source/audio_wave.v ../user_source/hdl_source/text_layers.v tb_wave_display3.v
vsim -novopt work_wave_display3.tb_wave_display3
onfinish stop
run -all
quit -code 0 -force
