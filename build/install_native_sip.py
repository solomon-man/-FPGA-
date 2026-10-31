from pathlib import Path
import re, shutil
r = Path(__file__).resolve().parents[1]
p = r/'user_source/constraints_source/pin.adc'
shutil.copy2(p, r/'build/pin_before_native_sip.adc')
s = (r/'build/native_adc_synth.v').read_text()
rows = []
for sig in re.findall(r'SIP_INFO\("([^"/]+)/S\d+"\)', s):
    if sig == 'clk':
        val = 'DRIVESTRENGTH=16;'
    elif sig not in ('cke', 'cs_n'):
        val = 'OUTDEL=3;DRIVESTRENGTH=4;'
    else:
        continue
    rows.append('set_sippin_assignment {U3/sdram.' + sig + '} {' + val + '}')
assert len(rows) == 53, len(rows)
p.write_text(p.read_text() + '\n# Embedded SDRAM physical I/O: primitive-instance.port names.\n# Native constraints persist through normal GUI synthesis and placement.\n' + '\n'.join(rows) + '\n', encoding='utf-8')
probe = (r/'build/native_adc_synth.tcl').read_text()
a = probe.index('set_sippin_assignment')
b = probe.index('optimize_rtl')
probe = probe[:a] + probe[b:]
probe = probe.replace('write_verilog ../build/native_adc_synth.v -implement', 'export_db ../build/native_gui_gate.db\nwrite_verilog ../build/native_gui_gate.v -implement')
(r/'build/native_gui_synth.tcl').write_text(probe)
print('Native SIP constraints installed: 53 pads')
