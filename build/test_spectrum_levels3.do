onerror {quit -code 1 -force}
vlib work_spectrum_levels3
vmap work work_spectrum_levels3
vlog -sv -work work_spectrum_levels3 ../user_source/hdl_source/audio_spectrum.v reference_v20/audio_spectrum_v20.v tb_spectrum_levels3.v
vsim -novopt work_spectrum_levels3.tb_spectrum_levels3
onfinish stop
run -all
quit -code 0 -force
