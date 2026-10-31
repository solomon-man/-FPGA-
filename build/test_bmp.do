onerror {quit -code 1 -force}
vlib work_timing_test
vmap work work_timing_test
vlog ../user_source/hdl_source/SD/bmp_read_legacy.v tb_bmp_timing.v
vsim -novopt work.tb_bmp_timing
run -all
quit -code 0 -force

