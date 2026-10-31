onerror {quit -code 1 -force}
vlib work_serial_reset
vlog -work work_serial_reset E:/TD_Engineer/sim_release/eg4/eg_logic_io.v E:/TD_Engineer/sim_release/eg4/eg_phy_pad.v E:/TD_Engineer/sim_release/eg4/eg_phy_glbl.v
vlog -sv -work work_serial_reset ../user_source/hdl_source/reset_release.v ../user_source/hdl_source/lane_lvds_10_1.v lane_reference.v tb_serial_reset.v
vsim -novopt work_serial_reset.tb_serial_reset work_serial_reset.glbl
onfinish stop
run -all
quit -code 0 -force
