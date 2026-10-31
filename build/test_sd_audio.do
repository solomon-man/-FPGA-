onerror {quit -code 1 -force}
vlib work_sd_audio
vmap work work_sd_audio
vlog -sv ../user_source/hdl_source/SD/sd_read_arbiter.v ../user_source/hdl_source/pcm_async_fifo.v ../user_source/hdl_source/SD/fat32_wav_map.v ../user_source/hdl_source/SD/wav_pcm_reader.v ../user_source/hdl_source/SD/sd_wav_player.v tb_sd_audio.v
vsim -novopt work.tb_sd_audio
onfinish stop
run -all
quit -sim
vsim -novopt -gPARTITION=2048 work.tb_sd_audio
onfinish stop
run -all
quit -sim
vsim -novopt -gPCM_ONLY=1 -gPARTITION=2048 work.tb_sd_audio
onfinish stop
run -all
quit -sim
vsim -novopt -gPCM_ONLY=1 -gLOOP_TEST=1 -gPARTITION=2048 work.tb_sd_audio
onfinish stop
run -all
quit -code 0 -force
