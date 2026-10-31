cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project timing_verified.al
set_param place effort high -run phy_1 -projmngr
set_param place fix_hold high -run phy_1 -projmngr
set_param place post_clock_route_opt on -run phy_1 -projmngr
set_param place seed 7 -run phy_1 -projmngr
set_param route hold_fix_iteration 20 -run phy_1 -projmngr
reset_runs phy_1 -f
reset_runs syn_1 -f
launch_runs syn_1
wait_run syn_1
launch_runs phy_1
wait_run phy_1
close_project
exit
