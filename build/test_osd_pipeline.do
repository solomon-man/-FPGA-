onerror {quit -code 1 -force}
vlib work_osd_pipeline
vlog -sv -work work_osd_pipeline ../user_source/hdl_source/text_layers.v tb_osd_pipeline.v
vsim -novopt work_osd_pipeline.tb_osd_pipeline
onfinish stop
run -all
quit -code 0 -force
