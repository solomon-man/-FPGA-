onerror {quit -code 1 -force}
vlib work_temperature
vmap work work_temperature
vlog -sv ../user_source/hdl_source/runtime_adjust.v ../user_source/hdl_source/parameter_mailbox.v tb_temperature.v
vsim -novopt work.tb_temperature
onfinish stop
run -all
quit -code 0 -force
