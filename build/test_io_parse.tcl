set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build]
proc write_verilog {args} {}
proc set_inst_attr {args} {}
proc export_adc {args} {}
source [file join $build configure_sdram_io.tcl]
exit
