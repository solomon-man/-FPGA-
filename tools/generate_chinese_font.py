"""Generate the 24x24 SimSun OSD font (BRAM init files plus SD resource copies).

Glyphs are rasterised once at their display size with hinted monochrome
rendering, so the OSD shows them 1:1 at XGA resolution with no resampling or
thresholding.  Indices 0..55 are the CJK labels (text_layers.v code 128+i);
56..69 are half-width ASCII characters centred in the 24-pixel cell.
"""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont


OUT = Path("I:/")
PROJECT_OUT = Path(r"G:/ANLU_Project/digital photo frame3.0/user_source/hdl_source")
FONT = Path(r"C:/Windows/Fonts/simsun.ttc")
LABELS = [
    "总览", "全部复位", "亮度", "对比度", "缩放", "特效", "速度", "图像",
    "自动", "错误", "静音", "音乐", "按键音", "频谱", "温度", "柱状",
    "径向", "波形", "开启", "关闭", "快速", "中速", "慢速", "淡入",
    "擦除", "直切", "载入", "结束", "测试", "曲目", "播放",
]
CJK = sorted(set("".join(LABELS)))
ASCII = "0123456789+-%:"  # Order must match the ascii_glyph map in text_layers.v.
CHARS = CJK + list(ASCII)
SIZE = 24
ROW_BYTES = SIZE // 8
GLYPH_BYTES = SIZE * ROW_BYTES


def glyph_rows(font: ImageFont.FreeTypeFont, char: str) -> list[int]:
    image = Image.new("1", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(image)
    draw.fontmode = "1"  # hinted 1-bit rasterisation, no antialias threshold
    # One baseline for every glyph keeps digits aligned with the CJK labels.
    draw.text(((SIZE - int(font.getlength(char))) // 2, 0), char, font=font, fill=1)
    return [
        sum(1 << (SIZE - 1 - x) for x in range(SIZE) if image.getpixel((x, y)))
        for y in range(SIZE)
    ]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT)
    output = parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    assert len(CJK) == 56, "text_layers.v hard-codes 56 CJK glyph codes"
    font = ImageFont.truetype(str(FONT), SIZE, index=0)
    rows = [row for char in CHARS for row in glyph_rows(font, char)]
    data = b"".join(row.to_bytes(ROW_BYTES, "big") for row in rows)

    # ModelSim reads the .mem; TD initialises the BRAM32K primitive from the .mif.
    (PROJECT_OUT / "font24_rows.mem").write_text(
        "".join(f"{row:06X}\n" for row in rows), encoding="ascii")
    (PROJECT_OUT / "font24_rows.mif").write_text(
        f"WIDTH={SIZE};\nDEPTH={len(rows)};\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n"
        + "".join(f"\t{i}\t:\t{row:06X};\n" for i, row in enumerate(rows))
        + "END;\n", encoding="ascii")

    for stale in ("FONT16.BIN", "FONT16.MEM"):
        (output / stale).unlink(missing_ok=True)
    (output / "FONT24.BIN").write_bytes(data)
    (output / "FONT24.MEM").write_text("".join(f"{byte:02X}\n" for byte in data), encoding="ascii")
    (output / "FONTMAP.TXT").write_text(
        "Glyph index, UTF-8 character, byte offset\n"
        + "".join(f"{i:02d}\t{char}\t{i * GLYPH_BYTES}\n" for i, char in enumerate(CHARS)),
        encoding="utf-8",
    )
    (output / "FONTINFO.TXT").write_text(
        "FPGA Chinese font resource (SimSun, 24x24)\n"
        f"FONT24.BIN: packed {SIZE}x{SIZE} monochrome glyphs, {ROW_BYTES} bytes per row, row-major, MSB is left pixel.\n"
        "FONT24.MEM: one hexadecimal byte per line, suitable as a BRAM init source.\n"
        "FONTMAP.TXT: glyph index and UTF-8 character mapping.\n"
        f"Glyphs: {len(CHARS)} ({len(CJK)} CJK + {len(ASCII)} half-width ASCII); "
        f"bytes per glyph: {GLYPH_BYTES}; total bytes: {len(data)}.\n"
        "The FPGA initializes its BRAM font during configuration from font24_rows.mif. SD files are resource copies, not loaded at runtime.\n",
        encoding="ascii",
    )
    print(f"Wrote {len(CHARS)} glyphs ({len(data)} bytes) to {output}")


if __name__ == "__main__":
    main()
