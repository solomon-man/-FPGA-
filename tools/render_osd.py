"""Prepare an existing BMP for RTL pixel rendering; convert RTL output to PNG."""
import argparse
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--input", type=Path)
args = parser.parse_args()
if args.input:
    im = Image.open(args.input).convert("RGB")
    assert im.size == (640, 480)
    with (root / "build/osd_pixels.hex").open("w", encoding="ascii") as stream:
        for r, g, b in im.getdata():
            stream.write(f"{r:02x}{g:02x}{b:02x}\n")
else:
    for name in ("osd_brightness", "osd_overview", "osd_audio", "osd_fast", "osd_medium", "osd_slow"):
        im = Image.open(root / "build" / f"{name}.ppm")
        assert im.size == (640, 480)
        im.save(root / "docs" / f"{name}.png")
    print("RTL_OSD_PREVIEW_PNG_PASS")
