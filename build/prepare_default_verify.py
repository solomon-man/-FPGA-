from pathlib import Path
import shutil
r=Path(__file__).resolve().parents[1]
syn=r/'TD_project/demo_Runs/native_gui_syn'
phy=r/'TD_project/demo_Runs/native_gui_phy'
syn.mkdir(exist_ok=True)
phy.mkdir(exist_ok=True)
for name in ('demo.prj','settings.cfg'):
    shutil.copy2(r/'TD_project/demo_Runs/syn_1'/name,syn/name)
s=(r/'TD_project/demo_Runs/phy_1/demo.prj').read_text(encoding='utf-8')
s=s.replace('<effort>high</effort>', '<effort>high</effort>\n<seed>6</seed>\n<fix_hold>high</fix_hold>\n<post_clock_route_opt>on</post_clock_route_opt>')
s=s.replace('</PlaceProperty>', '</PlaceProperty>\n<RouteProperty>\n<effort>high</effort>\n<hold_fix_iteration>20</hold_fix_iteration>\n</RouteProperty>')
(phy/'demo.prj').write_text(s,encoding='utf-8')
s=(r/'TD_project/demo_Runs/phy_1/settings.cfg').read_text().replace('set parent ../syn_1','set parent ../native_gui_syn')
(phy/'settings.cfg').write_text(s)
(r/'build/default_gui_verify.tcl').write_text('''cd {G:/ANLU_Project/digital photo frame3.0/TD_project/demo_Runs/native_gui_syn}
source E:/TD_Engineer/doc/scripts/DefaultFlow.tcl
close_project
cd ../native_gui_phy
source ./settings.cfg
source E:/TD_Engineer/doc/scripts/DefaultFlow.tcl
exit
''')
print('Prepared unmodified TD DefaultFlow synthesis and physical verification')
