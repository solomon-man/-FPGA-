onerror {quit -code 1 -force}
vlib work_wave_overlay3
vmap work work_wave_overlay3
vlog -sv -work work_wave_overlay3 ../user_source/hdl_source/audio_wave.v reference_v027/audio_ring_overlay.v tb_wave_overlay3.v
vsim -novopt work_wave_overlay3.tb_wave_overlay3
onfinish stop
run -all
quit -code 0 -force
