cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run demo.al
elaborate -top top
read_adc ../user_source/constraints_source/pin.adc
set_sippin_assignment {S20} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {S73} {DRIVESTRENGTH=16;}
set_sippin_assignment {U3/sdram/ras_n} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {U3/sdram.we_n} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {dm0/S75} {OUTDEL=3;DRIVESTRENGTH=4;}
optimize_rtl
optimize_gate
legalize_phy_inst
write_verilog ../build/native_adc_synth.v -implement
exit
