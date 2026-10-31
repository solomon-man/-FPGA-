onerror {quit -code 1 -force}
vlib work_refresh_test
vmap work work_refresh_test
vlog +incdir+../user_source/hdl_source/include ../user_source/hdl_source/include/sdr_init_ref.enc.v tb_sdram_refresh.v
vsim -novopt work.tb_sdram_refresh
run -all
quit -code 0 -force
