onerror {quit -code 1 -force}
vlib work_progressive
vmap progressive work_progressive
vlog -work progressive -sv ../user_source/hdl_source/pcm_async_fifo.v ../user_source/hdl_source/SD/sd_read_arbiter.v ../user_source/hdl_source/SD/fat32_wav_map.v ../user_source/hdl_source/SD/wav_pcm_reader.v ../user_source/hdl_source/SD/sd_wav_player.v ../user_source/hdl_source/SD/bmp_read.v ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/bmp_fit_read.v ../user_source/hdl_source/SD/fat_bmp_read.v ../user_source/hdl_source/SD/key_press_debounce.v ../user_source/hdl_source/SD/sd_card_bmp.v ../user_source/hdl_source/SD/sd_card_top.v ../user_source/hdl_source/SD/sd_card_cmd.v ../user_source/hdl_source/SD/sd_card_sec_read_write.v ../user_source/hdl_source/SD/spi_master.v tb_progressive.v
vsim -novopt progressive.tb_progressive
run -all
quit -code 0 -force

