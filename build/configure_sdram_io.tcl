# Configure the real EG4 embedded-SDRAM I/O cells before placement.
# OUTDEL is physical silicon delay, not an STA exception or path override.
# Cell numbers change with synthesis: discover them from SIP_INFO every build.
write_verilog [file join $build sdram_pad_map.v] -implement
set f [open [file join $build sdram_pad_map.v] r]
set netlist [read $f]
close $f
set data_count 0
set clock_count 0
set commands [open [file join $build apply_sdram_io.tcl] w]
set audit [open [file join $build sdram_io_settings.txt] w]
set blocks {}
set collecting 0
foreach line [split $netlist "\n"] {
    if {[string first {EG_PHY_PAD #(} $line] >= 0} {set collecting 1; set block ""}
    if {$collecting} {
        append block $line "\n"
        if {[string first {);} $line] >= 0} {lappend blocks $block; set collecting 0}
    }
}
foreach block $blocks {
    if {![regexp {SIP_INFO\("([^"/]+)/S[0-9]+"\)} $block -> signal]} {continue}
    if {![regexp {\\(U3/sdram_syn_[0-9]+)[ \t]+\(} $block -> sdram_pad_instance]} {
        error "Cannot identify SDRAM pad for $signal"
    }
    if {$signal eq "clk"} {
        puts $commands [list set_inst_attr -inst $sdram_pad_instance -attr_key DRIVE -attr_value 16]
        puts $audit "$signal $sdram_pad_instance DRIVE=16"
        incr clock_count
    } elseif {$signal ne "cke" && $signal ne "cs_n"} {
        if {![string match {*DO_DFFMODE("FF")*} $block]} {
            error "SDRAM output $signal is not registered in its I/O pad"
        }
        puts $commands [list set_inst_attr -inst $sdram_pad_instance -attr_key DRIVE -attr_value 4]
        puts $commands [list set_inst_attr -inst $sdram_pad_instance -attr_key OUTDELMUX -attr_value FIXDEL]
        puts $commands [list set_inst_attr -inst $sdram_pad_instance -attr_key OUTDEL -attr_value 3]
        puts $audit "$signal $sdram_pad_instance DRIVE=4 OUTDELMUX=FIXDEL OUTDEL=3"
        incr data_count
    }
}
close $audit
close $commands
if {$data_count != 52 || $clock_count != 1} {
    error "Incomplete embedded SDRAM pad configuration: data=$data_count clock=$clock_count"
}
puts "SDRAM_IO_CONFIGURATION_PASS data=$data_count clock=$clock_count"
source [file join $build apply_sdram_io.tcl]
write_verilog [file join $build sdram_pad_configured.v] -implement
set f [open [file join $build sdram_pad_configured.v] r]
set configured [read $f]
close $f
if {[regexp -all {OUTDELMUX\("FIXDEL"\)} $configured] < 52} {
    error "TD did not apply all embedded SDRAM output delay settings"
}
