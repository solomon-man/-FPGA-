onerror {quit -code 1 -force}
vlib work_fat_cache
vmap work work_fat_cache
vlog -sv ../user_source/hdl_source/SD/fat32_sector_map.v tb_fat_cache.v
vsim -novopt work.tb_fat_cache
onfinish stop
run -all
quit -code 0 -force
