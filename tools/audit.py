"""Audit delivered source integrity and project references; not hardware signoff."""
from pathlib import Path
import hashlib, json, re, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'docs/source_sha256.json').read_text(encoding='utf-8'))
actual = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in sorted((root/'user_source').rglob('*')) if p.is_file()}
assert manifest == actual, 'Source manifest mismatch; review changes before regenerating manifest'
native = (root/'TD_project/timing_verified.al').read_text(encoding='utf-8')
tree = ET.fromstring(re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;', native))
files = [(root/'TD_project'/n.attrib['Path']).resolve() for n in tree.findall('.//File')]
for p in files:
    assert p.is_relative_to(root) and p.is_file(), f'Missing or external project file: {p}'
registered = {p.name for p in files}
assert {'scaled_frame_reader.v', 'reset_release.v', 'runtime_adjust.v'} <= registered
# The normal TD GUI flow must retain the SDRAM physical I/O settings.
adc = (root/'user_source/constraints_source/pin.adc').read_text(encoding='utf-8')
sip = dict(re.findall(r'set_sippin_assignment\s+\{U3/sdram\.([^}]+)\}\s+\{([^}]+)\}', adc))
expected_sdram = {f'dq[{i}]' for i in range(32)} | {f'addr[{i}]' for i in range(11)} | {f'ba[{i}]' for i in range(2)} | {'ras_n','cas_n','we_n','dm0','dm1','dm2','dm3'}
assert set(sip) == expected_sdram | {'clk'}, 'Missing/unknown native SDRAM pin constraints'
for pin in expected_sdram:
    assert 'OUTDEL=3;' in sip[pin] and 'DRIVESTRENGTH=4;' in sip[pin], pin
assert sip['clk'] == 'DRIVESTRENGTH=16;'
strategy = tree.find(".//Run[@Name='phy_1']/Strategy")
for key, value in {'PlaceProperty/effort':'high', 'PlaceProperty/seed':'7', 'PlaceProperty/fix_hold':'high', 'PlaceProperty/post_clock_route_opt':'on', 'RouteProperty/hold_fix_iteration':'20'}.items():
    assert strategy.findtext(key) == value, f'GUI strategy mismatch: {key}'
slots = [(i*307200, 307200) for i in range(4)] + [(1228800, 786432)]
for (base, length), (next_base, _) in zip(slots, slots[1:]):
    assert base + length <= next_base
assert (slots[-1][0]+slots[-1][1])*4 == 8060928 < 8*1024*1024
top = (root/'user_source/hdl_source/top_tf_hdmi_audio.v').read_text(encoding='utf-8')
removed_modules = {'status_seven_segment.v', 'seg_scan.v', 'seg_decoder.v'}
assert not (removed_modules & registered), 'Removed display module remains registered'
assert not any(p.name in removed_modules for p in (root/'user_source').rglob('*.v'))
assert not re.search(r'\b(?:seg_sel|seg_data|seg_data_0|status_digits)\b', top)
assert not re.search(r'\bseg_(?:sel|data)\[', adc), 'Stale seven-segment pin constraints'
for setting in ['.PROGRESSIVE(1)', '.CACHE_SLOTS(4)', '.MAX_PHOTOS(4)', '.WAIT_COMMIT(1)', '.SLIDESHOW_HD(1)']:
    assert setting in top, setting
# Each mode has disjoint LIVE regions, despite intentional aliases between modes.
banks={0:(0,307200),1:(307200,307200),2:(614400,307200),3:(921600,307200),4:(1228800,786432),5:(0,786432),6:(1228800,307200)}
for live in [(0,1,2,3,4),(4,5),(4,0,1),(5,3,6)]:
    regions=sorted(banks[b] for b in live)
    assert all(a+n<=b for (a,n),(b,m) in zip(regions,regions[1:])), live
    assert all((a+n)*4<=8*1024*1024 for a,n in regions), live
assert re.search(r'BUF5_ADDR\s*=\s*(?:24.d)?0\s*;',top), 'HD B must alias address zero'
assert 'reader_owned_sd' in top
print(f'SOURCE_PROJECT_CACHE_AUDIT_PASS files={len(actual)} registered={len(files)}')
print('This audit does not certify timing closure or board operation.')
