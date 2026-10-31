cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run demo.al
elaborate -top top
read_adc ../user_source/constraints_source/pin.adc
optimize_rtl
optimize_gate
legalize_phy_inst
export_db ../build/native_gui_gate.db
write_verilog ../build/native_gui_gate.v -implement
exit
