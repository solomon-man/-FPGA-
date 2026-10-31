cd {G:/ANLU_Project/digital photo frame3.0/TD_project/timing_verified_Runs/phy_1}
import_device eagle_s20.db -package EG4S20BG256
import_db timing_verified_pr.db
update_timing -mode final
report_timing_summary -file ../../../build/project_manager_timing.rpt
report_timing_status -file ../../../build/project_manager_status.rpt
check_timing -file ../../../build/project_manager_check.rpt
write_verilog ../../../build/project_manager_implemented.v -implement
exit
