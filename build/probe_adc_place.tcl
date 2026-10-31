set root [file normalize [file join [file dirname [info script]] ..]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root build demo_gate.db]
set_sippin_assignment {S73} {DRIVESTRENGTH=16;}
set_sippin_assignment {S20} {OUTDEL=3; DRIVESTRENGTH=4;}
place
report_cells [get_cells {U3/sdram_syn_8}] -attributes
report_cells [get_cells {U3/sdram_syn_45}] -attributes
exit
