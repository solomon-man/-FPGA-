"""Check the actual project-manager run, retaining the previous accepted build."""
from pathlib import Path
import hashlib, json, re, datetime
r = Path(__file__).resolve().parents[1]
p = r/'TD_project/timing_verified_Runs/phy_1'
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest().upper()
report = (r/'build/project_manager_timing.rpt').read_text()
metrics = {}
for label in ('SWNS', 'STNS', 'HWNS', 'HTNS', 'Period Check WNS'):
    m = re.search(re.escape(label)+r':\s+([-\d.]+)ns', report)
    assert m and float(m[1]) >= 0, f'Failed timing: {label}'
    metrics[label] = float(m[1])
assert 'Routed' in report and 'Both (Slow and Fast)' in report
log = (p/'run.log').read_text()
for command in ('place effort high', 'place fix_hold high', 'place post_clock_route_opt on', 'place seed 7', 'route hold_fix_iteration 20'):
    assert f'set_param {command}' in log, command
assert ' ERROR:' not in log and (p/'timing_verified.bit').is_file()
net = (r/'build/project_manager_implemented.v').read_text()
count = 0
for block in re.findall(r'EG_PHY_PAD #\(.*?\);', net, re.S):
    m = re.search(r'SIP_INFO\("([^"/]+)/S\d+"\)', block)
    if m and m[1] not in ('clk', 'cke', 'cs_n'):
        assert '.OUTDELMUX("FIXDEL")' in block and '.OUTDEL(3)' in block and '.DRIVE("4")' in block, m[1]
        count += 1
assert count == 52, count
manifest = json.loads((r/'docs/source_sha256.json').read_text())
for name, digest in manifest.items():
    assert sha(r/name).lower() == digest.lower(), name
tests = json.loads((r/'build/verified_tests20.json').read_text(encoding='utf-8-sig'))
for test in tests:
    assert sha(r/'build'/test['log']) == test['log_sha256']
audio_checks = {'build/chime_g5_b5.log':'G5_B5_SIMULTANEOUS_FREQUENCY_SAMPLE_GATING_DURATION_PASS', 'build/audio_g5_b5.log':'AUDIO_INDEPENDENT_FLAGS_MUTE_STEREO_MIX_SATURATION_COMMIT_DURATION_PASS', 'build/photo_settings_no_seg.log':'SIX_BANK_4_TO_5_SETTINGS_ATOMIC_FADE_RESET_PASS'}
for name, marker in audio_checks.items():
    log_text = (r/name).read_text()
    assert marker in log_text and '# Errors: 0' in log_text and '** Fatal:' not in log_text, name
record = {'checked_at':datetime.datetime.now().astimezone().isoformat(), 'flow':'TD native project manager launch_runs syn_1 then phy_1; installed DefaultFlow.tcl', 'timing_ns':metrics, 'source_files':len(manifest), 'regressions_rechecked':len(tests), 'native_sdram_io':count, 'board_tested':False}
record['regression_note'] = 'After SEG removal, progressive, xga_write, frame_ui, temperature, slideshow, slideshow_fault and per-photo settings/atomic commit re-simulated; all 24 regression log hashes checked. Audio logs retained from the unchanged G5+B5 mixer verification.'
record['removed_modules'] = ['status_seven_segment', 'seg_scan', 'seg_decoder']
assert not re.search(r'\b(?:seg_sel|seg_data|status_digits)\b', net), 'Removed SEG signals remain in implemented netlist'
record['audio_checks'] = {name:sha(r/name) for name in audio_checks}
paths = ['docs/source_sha256.json', 'user_source/hdl_source/audio_mix122.v', 'TD_project/timing_verified.al', 'TD_project/timing_verified_Runs/phy_1/timing_verified.prj', 'TD_project/timing_verified_Runs/phy_1/timing_verified.bit', 'TD_project/timing_verified_Runs/phy_1/run.log', 'build/project_manager_timing.rpt', 'project_manager_verify.log', 'no_seg_retry.log']
record['sha256'] = {name:sha(r/name) for name in paths}
(r/'build/project_manager_signoff.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record, indent=2))
