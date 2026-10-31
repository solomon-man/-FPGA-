set root [file normalize [file join [file dirname [info script]] ..]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root build demo_pr.db]
set_inst_attr -help
write_verilog -help
report_cells [get_cells {U3/sdram_syn_8}] -attributes
write_verilog [file join $root build routed_inspect.v] -implement
exit
