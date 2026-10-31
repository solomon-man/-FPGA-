"""Accept this native GUI-flow build only after checking its actual reports."""
from pathlib import Path
import re, json, hashlib, shutil, datetime

r=Path(__file__).resolve().parents[1]
b=r/'build'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
report=(b/'native_main_timing.rpt').read_text()
timing={}
for label in ('SWNS','STNS','HWNS','HTNS','Period Check WNS'):
    m=re.search(re.escape(label)+r':\s+([-\d.]+)ns',report)
    assert m and float(m[1])>=0, f'Timing did not pass: {label}'
    timing[label]=float(m[1])
for clock in ('clk','sd_card_clk','ext_mem_clk','video_clk','hdmi_5x_clk','audio_mclk'):
    assert re.search(r'\s'+clock+r'\s',report), clock
assert 'Routed' in report and 'Both (Slow and Fast)' in report and '99.98%' in report
log=(r/'main_native_default.log').read_text()
assert ' ERROR:' not in log and 'start command "bitgen' in log
assert 'source' not in log or 'configure_sdram_io' not in log
net=(b/'native_main_implemented.v').read_text()
blocks=re.findall(r'EG_PHY_PAD #\(.*?\);',net,re.S)
data=0
clock_count=0
for block in blocks:
    m=re.search(r'SIP_INFO\("([^"/]+)/S\d+"\)',block)
    if not m: continue
    if m[1]=='clk':
        assert '.DRIVE("16")' in block
        clock_count+=1
    elif m[1] not in ('cke','cs_n'):
        assert '.OUTDELMUX("FIXDEL")' in block and re.search(r'\.OUTDEL\(3\)',block) and '.DRIVE("4")' in block, m[1]
        data+=1
assert data==52 and clock_count==1, (data,clock_count)
old=json.loads((r/'docs/source_sha256.json').read_text(encoding='utf-8'))
actual={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((r/'user_source').rglob('*')) if p.is_file()}
assert old.keys()==actual.keys()
assert all(old[k]==v for k,v in actual.items() if k!='user_source/constraints_source/pin.adc'), 'Unexpected RTL change invalidates prior regression'
backup=b/'before_native_gui_signoff'
backup.mkdir(exist_ok=True)
copies={'demo.bit':r/'TD_project/demo.bit','demo_pr.db':r/'TD_project/demo_pr.db','demo_gate.db':r/'TD_project/demo_gate.db','timing_summary.rpt':b/'native_main_timing.rpt','timing_status.rpt':b/'native_main_status.rpt','timing_check.rpt':b/'native_main_check.rpt','timing_exception.rpt':b/'native_main_exception.rpt','timing_ignored.rpt':b/'native_main_ignored.rpt'}
for name,p in copies.items():
    target=b/name
    assert p.is_file()
    if target.exists() and not (backup/name).exists(): shutil.copy2(target,backup/name)
    shutil.copy2(p,target)
for p in (b/'bitstream_build.json',b/'timing_signoff.json',r/'docs/source_sha256.json'):
    if not (backup/p.name).exists(): shutil.copy2(p,backup/p.name)
(r/'docs/source_sha256.json').write_text(json.dumps(actual,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now().astimezone().isoformat()
bit_sha=sha(b/'demo.bit')
metadata={'built_at':now,'log':str(r/'main_native_default.log'),'bit_sha256':bit_sha,'timing_report':'build/timing_summary.rpt','flow':'TD exported GUI default flow using TD_project/demo.al; native pin.adc; no configure_sdram_io hook'}
(b/'bitstream_build.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tests=json.loads((b/'verified_tests20.json').read_text(encoding='utf-8-sig'))
assert len(tests)==24
for test in tests: assert sha(b/test['log'])==test['log_sha256']
signoff={'checked_at':now,'timing_ns':timing,'regression_count':len(tests),'regression_note':'Existing 24 RTL regressions reused: only physical ADC constraints and project/build settings changed. Log hashes rechecked.','source_files':len(actual),'source_manifest_sha256':sha(r/'docs/source_sha256.json'),'project_sha256':sha(r/'TD_project/demo.al'),'bit_sha256':bit_sha,'build_log':str(r/'main_native_default.log'),'build_log_sha256':sha(r/'main_native_default.log'),'timing_report':'build/timing_summary.rpt','timing_report_sha256':sha(b/'timing_summary.rpt'),'regression_record':'build/verified_tests20.json','native_sdram_io':{'data_address_command':data,'clock':clock_count},'board_tested':False}
(b/'timing_signoff.json').write_text(json.dumps(signoff,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(b/'build_status.txt').write_text('NATIVE_GUI_DEFAULT_FLOW_PASS\nSDRAM_NATIVE_ADC_52_PLUS_CLOCK_PASS\nCONSTRAINED_TIMING_PASS\nPROJECT20_XGA_BUILD_PASS\n',encoding='utf-8')
print(json.dumps({'timing_ns':timing,'bit_sha256':bit_sha,'native_sdram_io':data,'regressions':len(tests)},indent=2))
