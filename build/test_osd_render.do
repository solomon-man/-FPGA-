onerror {quit -code 1 -force}
vlib work_osd_render
vmap work work_osd_render
vlog -sv ../user_source/hdl_source/text_layers.v tb_osd_render.v
vsim -novopt work.tb_osd_render
onfinish stop
run -all
quit -code 0 -force
