onerror {quit -code 1 -force}
vlib work_fit122
vmap work work_fit122
vlog -sv ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/fat_bmp_read.v tb_fit122.v
vsim work.tb_fit122
onfinish stop
run -all
quit -code 0 -force
