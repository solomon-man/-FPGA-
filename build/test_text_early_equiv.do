onerror {quit -code 1 -force}
vlib work_text_early
vmap text_early work_text_early
vlog -work text_early -sv +define+MODEL_TECH ../user_source/hdl_source/text_layers.v tb_text_early_equiv.v
vsim -novopt text_early.tb_text_early_equiv
run -all
quit -code 0 -force
