onerror {quit -code 1 -force}
vlib work_six_photos
vmap work work_six_photos
vlog -sv ../user_source/hdl_source/pcm_async_fifo.v ../user_source/hdl_source/SD/sd_read_arbiter.v ../user_source/hdl_source/SD/fat32_wav_map.v ../user_source/hdl_source/SD/wav_pcm_reader.v ../user_source/hdl_source/SD/sd_wav_player.v ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/fat_bmp_read.v ../user_source/hdl_source/SD/key_press_debounce.v ../user_source/hdl_source/SD/sd_card_bmp.v ../user_source/hdl_source/SD/sd_card_top.v ../user_source/hdl_source/SD/sd_card_cmd.v ../user_source/hdl_source/SD/sd_card_sec_read_write.v ../user_source/hdl_source/SD/spi_master.v ../user_source/hdl_source/display_controls4.v ../user_source/hdl_source/frame_commit.v tb_six_cache.v tb_photo_settings.v tb_six_fat.v tb_six_addresses.v ../user_source/hdl_source/SD/frame_fifo_write.v
vlog -sv ../user_source/hdl_source/text_layers.v
vsim -novopt work.tb_six_cache
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_six_fat
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_six_addresses
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_photo_settings
onfinish stop
run -all
quit -sim
vlog -sv +incdir+../user_source/hdl_source/include ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/source_scale_address.v ../user_source/hdl_source/scaled_frame_reader.v ../user_source/hdl_source/SD/frame_fifo_read.v ../user_source/hdl_source/IP/afifo_32_16_256.v ../user_source/hdl_source/audio_mix122.v tb_six_reader.v tb_six_commit.v tb_six_audio.v
vsim -novopt work.tb_six_commit
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_six_audio
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_six_reader
onfinish stop
run -all
quit -code 0 -force
