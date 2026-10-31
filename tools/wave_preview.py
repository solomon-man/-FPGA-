"""Preview VISUAL=WAVE: bit-level model of audio_wave_levels/audio_wave_overlay.

Reads headerless s16le 48 kHz PCM (mono, or --stereo), simulates the per-frame
history snapshot at 60 Hz and draws the band on a photo, at 640x480 and at the
1024x768 output size (nearest-neighbour, as display_enhance maps coordinates).

  python tools/wave_preview.py BGM.PCM photo.bmp --seconds 12.5 --out docs/preview/wave
"""
import argparse
import math
import struct
from pathlib import Path

from PIL import Image

BAR_COUNT, BAND_Y, WASH_LEVEL = 40, 448, 2
WEIGHT = [round(2 + 14 * math.cos(math.pi * e / 80) ** 2) for e in range(40)]


def level(peak, log_scale):
    if not log_scale:
        return min(28, peak >> 9)
    if peak == 0:
        return 0
    msb = peak.bit_length() - 1
    mantissa = ((peak << 2) >> msb) & 3 if msb >= 2 else (peak << (2 - msb)) & 3
    code = msb * 4 + mantissa
    return 28 if code >= 59 else max(0, code - 31)


def history(samples, log_scale):
    out = []
    for i in range(0, len(samples) - 31, 32):
        out.append(level(max(samples[i:i + 32]), log_scale))
    return out


def snapshot(hist, frame, heights):
    end = int(frame * 48000 / 60) // 32
    newest = hist[max(0, end - BAR_COUNT):end]
    newest = [0] * (BAR_COUNT - len(newest)) + newest
    result = []
    for old, new in zip(heights, newest):
        if new >= old or (old > 3 and new > old - 3):
            result.append(new)
        else:
            result.append(old - 3 if old > 3 else new)
    return result


def draw(photo, heights):
    image = photo.copy()
    pixels = image.load()
    for y in range(BAND_Y, BAND_Y + 32):
        band = y - BAND_Y
        row = band & 15 if band & 16 else 15 - (band & 15)
        k = WASH_LEVEL + 2 + (band >> 2) + (band >> 3)
        for x in range(640):
            slot = x >> 3
            index, edge = (slot, 39 - slot) if slot < 40 else (79 - slot, slot - 40)
            half = (min(heights[index], 28) * WEIGHT[edge]) // 32 + 1
            col = x & 7
            cap = row == half - 1
            if row < half and (3 <= col < 5 if cap else 2 <= col < 6):
                pixels[x, y] = (255, 255, 255)
            else:
                pixels[x, y] = tuple(c - (c * k >> 4) + (b * k >> 4)
                                     for c, b in zip(pixels[x, y], (0x3c, 0x82, 0xf0)))
    return image


parser = argparse.ArgumentParser()
parser.add_argument('pcm', type=Path)
parser.add_argument('photo', type=Path)
parser.add_argument('--seconds', type=float, default=10.0)
parser.add_argument('--stereo', action='store_true')
parser.add_argument('--out', type=Path, default=Path('wave_preview'))
args = parser.parse_args()

raw = args.pcm.read_bytes()
values = struct.unpack(f'<{len(raw) // 2}h', raw[:len(raw) // 2 * 2])
if args.stereo:
    values = [max(abs(values[i]), abs(values[i + 1])) for i in range(0, len(values) - 1, 2)]
else:
    values = [abs(v) for v in values]
start = int(args.seconds * 48000)
samples = values[max(0, start - 48000):start]
photo = Image.open(args.photo).convert('RGB').resize((640, 480))
args.out.parent.mkdir(parents=True, exist_ok=True)
for log_scale, tag in ((True, 'log'), (False, 'linear')):
    hist = history(samples, log_scale)
    heights = [0] * BAR_COUNT
    for frame in range(60):
        heights = snapshot(hist, frame, heights)
    image = draw(photo, heights)
    image.save(f'{args.out}_{tag}_640.png')
    image.resize((1024, 768), Image.NEAREST).crop((0, 640, 1024, 768)).save(f'{args.out}_{tag}_xga_bottom.png')
    print(tag, 'heights', heights)
