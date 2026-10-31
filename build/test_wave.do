onerror {quit -code 1 -force}
vlib work_wave
vlog -work work_wave -sv ../user_source/hdl_source/promax_audio_waveform.v tb_wave.v
vsim -novopt work_wave.tb_wave
run -all
quit -code 0 -force
