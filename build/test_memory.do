onerror {quit -code 1 -force}
vlib work_memory
vlog -work work_memory -sv ../user_source/hdl_source/SD/frame_fifo_write.v tb_memory_addresses.v
vsim -novopt work_memory.tb_memory_addresses
run -all
quit -code 0 -force
