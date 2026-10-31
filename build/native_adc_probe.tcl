cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
import_db demo_Runs/syn_1/demo_gate.db
set_sippin_assignment {S20} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {cas_n/S20} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {U3/sdram/cas_n} {OUTDEL=3;DRIVESTRENGTH=4;}
set_sippin_assignment {S73} {DRIVESTRENGTH=16;}
place
write_verilog ../build/native_adc_probe.v -implement
exit
