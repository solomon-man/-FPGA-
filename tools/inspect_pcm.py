"""Record a raw PCM file and export an unchanged prefix for RTL simulation."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
args = parser.parse_args()
data = args.source.read_bytes()
root = Path(__file__).resolve().parents[1]
assert len(data) >= 4096, 'At least 4096 bytes required for the fixture'
assert data[:4] != b'RIFF', 'This tool expects headerless PCM'
(root / 'build/bgm_prefix.hex').write_text(
    '\n'.join(f'{value:02x}' for value in data[:4096]) + '\n', encoding='ascii')
report = {
    'source': str(args.source), 'bytes': len(data),
    'sha256': hashlib.sha256(data).hexdigest(),
    'headerless': True, 'assumed_format': 's16le, 48000 Hz, mono (course default)',
    'format_autodetected': False, 'duration_if_assumed_format_seconds': len(data) / 96000,
    'rtl_fixture_bytes': 4096,
}
(root / 'build/bgm_pcm_inspection.json').write_text(
    json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
