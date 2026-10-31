onerror {quit -code 1 -force}
vlib work_adjust_pipeline
vmap work work_adjust_pipeline
vlog -sv -work work_adjust_pipeline ../user_source/hdl_source/runtime_adjust.v tb_adjust_pipeline.v
vsim -novopt work_adjust_pipeline.tb_adjust_pipeline
onfinish stop
run -all
quit -code 0 -force
