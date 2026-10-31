onerror {quit -code 1 -force}
vlib work_raw_pcm
vlog -sv -work work_raw_pcm ../user_source/hdl_source/SD/wav_pcm_reader.v tb_raw_pcm.v
vsim -novopt work_raw_pcm.tb_raw_pcm
onfinish stop
run -all
quit -sim
vsim -novopt -gCHANNELS=2 work_raw_pcm.tb_raw_pcm
onfinish stop
run -all
quit -code 0 -force
