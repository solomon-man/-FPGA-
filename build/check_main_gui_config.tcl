cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run demo.al
load_run_param -run phy_1
export_flow_script -run phy_1 -file ../build/gui_phy_export.tcl
report_param
close_project
import_db demo_Runs/native_gui_syn/demo_gate.db
write_verilog ../build/native_gui_sdram_verified.v -implement
exit
