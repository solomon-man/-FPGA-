onerror {quit -code 1 -force}
vlib work_sdram_link
vlog -sv -work work_sdram_link +incdir+../user_source/hdl_source/include ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/SD/sdram.v tb_sdram_link.v
vsim -novopt work_sdram_link.tb_sdram_link
onfinish stop
run -all
quit -code 0 -force
