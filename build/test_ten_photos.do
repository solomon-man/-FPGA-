onerror {quit -code 1 -force}
vlib work_ten_photos
vmap work work_ten_photos
vlog -sv ../user_source/hdl_source/pcm_async_fifo.v ../user_source/hdl_source/SD/sd_read_arbiter.v ../user_source/hdl_source/SD/fat32_wav_map.v ../user_source/hdl_source/SD/wav_pcm_reader.v ../user_source/hdl_source/SD/sd_wav_player.v ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/fat_bmp_read.v ../user_source/hdl_source/SD/key_press_debounce.v ../user_source/hdl_source/SD/sd_card_bmp.v ../user_source/hdl_source/SD/sd_card_top.v ../user_source/hdl_source/SD/sd_card_cmd.v ../user_source/hdl_source/SD/sd_card_sec_read_write.v ../user_source/hdl_source/SD/spi_master.v ../user_source/hdl_source/display_controls4.v ../user_source/hdl_source/frame_commit.v tb_ten_cache.v tb_photo_settings.v tb_ten_fat.v
vlog -sv ../user_source/hdl_source/text_layers.v
vsim -novopt work.tb_ten_cache
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_photo_settings
onfinish stop
run -all
quit -sim
vsim -novopt work.tb_ten_fat
onfinish stop
run -all
quit -code 0 -force
