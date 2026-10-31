# Use a disposable project snapshot so an older open GUI cannot overwrite it.
set root [file normalize [file join [file dirname [info script]] ..]]
set probe [file join $root gui_flow_verification]
file mkdir $probe
set fh [open [file join $root TD_project demo.al] r]
set project_text [read $fh]
close $fh
set project_text [string map [list "Path=\"$root/TD_project\"" "Path=\"$probe\""] $project_text]
set fh [open [file join $probe demo.al] w]
puts -nonewline $fh $project_text
close $fh
cd $probe
import_device eagle_s20.db -package EG4S20BG256
open_project demo.al
set_param route hold_fix_iteration 20 -run phy_1
set_param place fix_hold off -run phy_1
set_param place seed 4 -run phy_1
set_param place effort high -run phy_1
set_param place post_clock_route_opt on -run phy_1
set_param route effort high -run phy_1
reset_runs syn_1 -f
reset_runs phy_1 -f
launch_runs syn_1 -jobs 6
wait_run syn_1
launch_runs phy_1 -jobs 6
wait_run phy_1
save_best_bits
set fh [open [file join $root build gui_flow_status.txt] w]
puts $fh "GUI_FLOW_WAIT_COMPLETE"
close $fh
exit
