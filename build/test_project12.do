onerror {quit -code 1 -force}
vlib work_project12
vmap work work_project12
vlog -sv ../user_source/hdl_source/picture_adjust.v ../user_source/hdl_source/runtime_adjust.v ../user_source/hdl_source/thumbnail_scaler.v ../user_source/hdl_source/text_layers.v ../user_source/hdl_source/audio_wave.v ../user_source/hdl_source/status_osd_overlay.v ../user_source/hdl_source/promax_audio_waveform.v ../user_source/hdl_source/audio_spectrum.v ../user_source/hdl_source/display_enhance.v ../user_source/hdl_source/frame_commit.v ../user_source/hdl_source/reset_release.v ../user_source/hdl_source/feature_keys.v ../user_source/hdl_source/SD/bmp_read.v tb_display.v tb_commit.v tb_bmp_full.v
vsim -novopt work.tb_commit
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_display
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_bmp_full
onfinish stop
run -all
quit -code 0 -force

