"""Read-only checker for aspect-fit RGB24 BMP compatibility (1..4096 per axis, bottom-up).

Usage: python validate_bmp.py file.bmp [another.bmp ...]
Does not modify images or format/write a TF card.
"""
import argparse
import struct
from pathlib import Path

def inspect(path):
    size = path.stat().st_size
    with path.open('rb') as stream:
        header = stream.read(54)
    if len(header) < 54 or header[:2] != b'BM':
        raise ValueError('Not a Windows BMP file')
    declared, offset = struct.unpack_from('<I', header, 2)[0], struct.unpack_from('<I', header, 10)[0]
    dib, width, height, planes, bpp, compression = struct.unpack_from('<IiiHHI', header, 14)
    payload = ((width * 3 + 3) // 4) * 4 * height
    checks = {'width': 1 <= width <= 4096, 'height': 1 <= height <= 4096, 'planes': planes == 1,
              'bpp': bpp == 24, 'compression': compression == 0, 'DIB': dib >= 40,
              'offset': 54 <= offset <= 4096, 'declared_pixels': declared >= offset + payload,
              'actual_pixels': size == declared and size >= offset + payload}
    failed = [name for name, okay in checks.items() if not okay]
    if failed:
        raise ValueError('Unsupported or incomplete BMP: ' + ', '.join(failed))
    fw, fh = (640, max(1, height*640//width)) if width*480 >= height*640 else (max(1, width*480//height),480)
    return f'PASS {path.name}: {width}x{height} RGB24 -> {fw}x{fh} centered in 640x480, offset={offset}, bytes={size}'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('images', type=Path, nargs='+')
    args = parser.parse_args()
    errors = 0
    for path in args.images:
        try:
            print(inspect(path))
        except (OSError, ValueError) as exc:
            print(f'FAIL {path}: {exc}')
            errors += 1
    raise SystemExit(1 if errors else 0)

if __name__ == '__main__':
    main()
