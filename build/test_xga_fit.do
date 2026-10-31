onerror {quit -code 1 -force}
vlib work_xga_fit
vmap work work_xga_fit
vlog -sv -work work_xga_fit ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/fat_bmp_read.v tb_xga_fit.v
vsim work_xga_fit.tb_xga_fit
onfinish stop
run -all
quit -code 0 -force
