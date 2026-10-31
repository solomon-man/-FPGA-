set root [file normalize [file join [file dirname [info script]] ..]]
cd [file join $root TD_project]
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run demo.al
elaborate -top top
read_adc ../user_source/constraints_source/pin.adc
set_sippin_assignment {clk} {DRIVESTRENGTH=16;}
set_sippin_assignment {cas_n} {OUTDEL=3; DRIVESTRENGTH=4;}
optimize_rtl
optimize_gate
legalize_phy_inst
write_verilog [file join $root build adc_inspect.v] -implement
exit
