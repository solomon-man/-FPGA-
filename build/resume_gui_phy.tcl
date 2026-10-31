set root [file normalize [file join [file dirname [info script]] ..]]
cd [file join $root gui_flow_verification]
import_device eagle_s20.db -package EG4S20BG256
open_project demo.al
launch_runs phy_1 -jobs 6
wait_run phy_1
save_best_bits
set fh [open [file join $root build gui_flow_status.txt] w]
puts $fh "GUI_FLOW_WAIT_COMPLETE"
close $fh
close_project
exit
