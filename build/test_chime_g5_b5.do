onerror {quit -code 1 -force}
vlib work_chime
vmap work work_chime
vlog -sv ../user_source/hdl_source/audio_mix122.v tb_chime_g5_b5.v
vsim -novopt work.tb_chime_g5_b5
onfinish stop
run -all
quit -code 0 -force
