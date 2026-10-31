onerror {quit -code 1 -force}
vlib work_fat121
vmap work work_fat121
vlog -sv ../user_source/hdl_source/SD/bmp_read.v ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/bmp_fit_read.v ../user_source/hdl_source/SD/fat_bmp_read.v tb_fat121.v
vsim -novopt work.tb_fat121
onfinish stop
run -all
quit -code 0 -force
