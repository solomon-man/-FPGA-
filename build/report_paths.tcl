set root [file normalize [file join [file dirname [info script]] ..]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root build demo_pr.db]
update_timing -mode final
report_timing_path -file [file join $root build critical_paths.rpt] -from [get_clocks sd_card_clk] -to [get_clocks sd_card_clk] -ep_num 30 -path_num 1 -report_type max
exit
