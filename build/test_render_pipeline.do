onerror {quit -code 1 -force}
vlib work_render_pipeline
vmap work work_render_pipeline
vlog -sv -work work_render_pipeline ../user_source/hdl_source/audio_spectrum.v reference_v30/audio_spectrum_v30.v tb_render_pipeline.v
vsim -novopt work_render_pipeline.tb_render_pipeline
onfinish stop
run -all
quit -code 0 -force
