foreach cmd {set_pin_assignment set_instance_assignment set_property set_attribute get_cells export_verilog} {
 puts "HELP FOR $cmd"
 catch {help $cmd}
}
exit
