cd {G:/ANLU_Project/digital photo frame3.0/TD_project}
import_device eagle_s20.db -package EG4S20BG256
open_project timing_verified.al
set_param place seed 7 -run phy_1 -projmngr
reset_runs phy_1 -f
launch_runs phy_1
wait_run phy_1
close_project
exit
