onerror {quit -code 1 -force}
vlib work_blackbox
vmap work work_blackbox
vlog -sv ../user_source/hdl_source/SD/fat32_sector_map.v ../user_source/hdl_source/SD/fat_bmp_read.v tb_fit122.v
vsim work.tb_fit122
onfinish stop
run 100 us
echo "EXISTING_PROJECT_SOURCE_ASPECT_FIT_ELABORATION_PASS"
quit -code 0 -force

