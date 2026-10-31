from pathlib import Path
r=Path(__file__).resolve().parents[1]
d=r/'TD_project/demo_Runs/native_gui_verify'
d.mkdir(exist_ok=True)
s=(r/'TD_project/demo_Runs/phy_1/demo.prj').read_text(encoding='utf-8')
s=s.replace('<effort>high</effort>', '<effort>high</effort>\n<seed>6</seed>\n<fix_hold>high</fix_hold>\n<post_clock_route_opt>on</post_clock_route_opt>')
s=s.replace('</PlaceProperty>', '</PlaceProperty>\n<RouteProperty>\n<effort>high</effort>\n<hold_fix_iteration>20</hold_fix_iteration>\n</RouteProperty>')
(d/'native_gui.prj').write_text(s,encoding='utf-8')
(d/'settings.cfg').write_text('''set area_option -packarea
set arr_filter false
set device_name eagle_s20.db
set drHoldFix on
set end_step bitgen
set package_name EG4S20BG256
set parent ../../../build
set prj_name native_gui
set run_type phy
set start_step opt_place
set top_model_name top
''')
(r/'build/native_default_flow.tcl').write_text('cd {G:/ANLU_Project/digital photo frame3.0/TD_project/demo_Runs/native_gui_verify}\nsource E:/TD_Engineer/doc/scripts/DefaultFlow.tcl\nexit\n')
