set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build]
cd [file join $root TD_project]
import_device eagle_s20.db -package EG4S20BG256
import_db ../build/demo_gate.db
set_param route hold_fix_iteration 20
set_param place fix_hold high
set_param place seed 6
set_param place effort high
set_param place post_clock_route_opt on
set_param route effort high
source [file join $build configure_sdram_io.tcl]
place
route
fix_hold -clock_opt -buffer_opt -eco
route -eco
update_timing -mode final
export_db [file join $build demo_pr.db]
report_timing_path -file [file join $build critical_paths.rpt] -from [get_clocks sd_card_clk] -to [get_clocks sd_card_clk] -ep_num 30 -path_num 1 -report_type max
report_timing_summary -file [file join $build timing_summary.rpt]
report_timing_status -file [file join $build timing_status.rpt]
check_timing -file [file join $build timing_check.rpt]
report_timing_exception -file [file join $build timing_exception.rpt]
report_timing_ignored -file [file join $build timing_ignored.rpt]
set fh [open [file join $build timing_summary.rpt] r]
set timing_text [read $fh]
close $fh
# This TD release cannot query collections before optimize_rtl.
# Validate all derived clocks from the routed clock summary instead.
foreach required {clk sd_card_clk ext_mem_clk video_clk hdmi_5x_clk audio_mclk} {
    if {![regexp [format {\s%s\s} $required] $timing_text]} {
        error "Missing required routed clock: $required"
    }
}
foreach label {SWNS STNS HWNS HTNS {Period Check WNS}} {
    set pattern [format {%s:\s+([-0-9.]+)ns} $label]
    if {![regexp $pattern $timing_text match slack] || $slack < 0} {
        set progress [open [file join $build build_status.txt] a]
        puts $progress "TIMING_FAIL: $label"
        close $progress
        error "Timing acceptance failed: $label"
    }
}
set progress [open [file join $build build_status.txt] a]
puts $progress "CONSTRAINED_TIMING_PASS"
close $progress
export_db [file join $build demo_pr.db]
bitgen -bit [file join $build demo.bit]
set progress [open [file join $build build_status.txt] a]; puts $progress "PROJECT20_XGA_BUILD_PASS"; close $progress
exit


