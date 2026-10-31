onerror {quit -code 1 -force}
vlib work_wave_levels3
vmap work work_wave_levels3
vlog -sv -work work_wave_levels3 ../user_source/hdl_source/audio_wave.v reference_v027/audio_ring_levels.v reference_v027/AL_MAP_LUT1.v tb_wave_levels3.v
vsim -novopt work_wave_levels3.tb_wave_levels3
onfinish stop
run -all
quit -code 0 -force
