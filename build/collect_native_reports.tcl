cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
import_db demo_pr.db
update_timing -mode final
report_timing_summary -file ../build/native_main_timing.rpt
report_timing_status -file ../build/native_main_status.rpt
check_timing -file ../build/native_main_check.rpt
report_timing_exception -file ../build/native_main_exception.rpt
report_timing_ignored -file ../build/native_main_ignored.rpt
write_verilog ../build/native_main_implemented.v -implement
exit
