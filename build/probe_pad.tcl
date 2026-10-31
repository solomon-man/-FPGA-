set root [file normalize [file join [file dirname [info script]] ..]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root build demo_pr.db]
set_inst_attr -inst {U3/sdram_syn_8} -attr_key OUTDELMUX -attr_value FIXDEL
set_inst_attr -inst {U3/sdram_syn_8} -attr_key OUTDEL -attr_value 3
report_cells [get_cells {U3/sdram_syn_8}] -attributes
update_timing -mode final
report_timing_path -file [file join $root build pad_delay_probe.rpt] -to [get_pins {U3/sdram.cas_n}] -report_type min
exit
