onerror {quit -code 1 -force}
vlib work_spectrum
vmap work work_spectrum
vlog -sv ../user_source/hdl_source/audio_spectrum.v ../user_source/hdl_source/text_layers.v tb_spectrum.v
vsim -novopt work.tb_spectrum
onfinish stop
run -all
quit -sim
vlib spectrum_previous
vlog -sv -work spectrum_previous ../docs/before_radial48_fatcache/audio_spectrum.v
vlog -sv tb_spectrum_compare.v
vsim -novopt work.spectrum_compare_cfg
onfinish stop
run -all
quit -code 0 -force
