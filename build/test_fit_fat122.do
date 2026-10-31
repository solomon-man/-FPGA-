onerror {quit -code 1 -force}
vlib work_fit_fat122
vmap work work_fit_fat122
vlog -sv ../user_source/hdl_source/SD/bmp_read.v ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/bmp_fit_read.v ../user_source/hdl_source/SD/fat_bmp_read.v tb_fit_fat122.v
vsim -novopt work.tb_fit_fat122
onfinish stop
run -all
quit -code 0 -force
