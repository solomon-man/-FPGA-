onerror {quit -code 1 -force}
vlib work_sd_transport
vmap work work_sd_transport
vlog -sv ../user_source/hdl_source/pcm_async_fifo.v ../user_source/hdl_source/SD/sd_read_arbiter.v tb_sd_transport.v
vsim -novopt work.tb_sd_transport
onfinish stop
run -all
quit -code 0 -force
