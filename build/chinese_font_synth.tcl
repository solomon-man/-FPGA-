cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run timing_verified.al
elaborate -top top
optimize_rtl
report_area -file ../build/chinese_font_rtl.area
optimize_gate -packarea ../build/chinese_font_gate.area
export_db ../build/chinese_font_gate.db
exit
