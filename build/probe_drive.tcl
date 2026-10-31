set root [file normalize [file join [file dirname [info script]] ..]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root build demo_pr.db]
puts "CELL_QUERY=[get_cells {U3/sdram_syn_*}]"
foreach prop {NAME name SIP_INFO DO_DFFMODE} {catch {puts "$prop=[get_property $prop [get_cells {U3/sdram_syn_8}]]"}}
for {set i 0} {$i < 51} {incr i} {
 if {$i != 45} {
 set_inst_attr -inst U3/sdram_syn_$i -attr_key OUTDELMUX -attr_value FIXDEL
 set_inst_attr -inst U3/sdram_syn_$i -attr_key OUTDEL -attr_value 3
 }
}
set_inst_attr -inst U3/sdram_syn_45 -attr_key DRIVE -attr_value 16
update_timing -mode final
report_timing_summary -file [file join $root build delay_drive_probe.rpt]
exit
