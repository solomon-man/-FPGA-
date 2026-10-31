from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont


OUT = Path("I:/")
PROJECT_OUT = Path(r"G:\ANLU_Project\digital photo frame3.0\user_source\hdl_source")
FONT = Path(r"C:\Windows\Fonts\msyh.ttc")
LABELS = [
    "总览", "全部复位", "亮度", "对比度", "缩放", "特效", "速度", "图像",
    "自动", "错误", "静音", "音乐", "按键音", "频谱", "温度", "柱状",
    "径向", "波形", "开启", "关闭", "快速", "中速", "慢速", "淡入",
    "擦除", "直切", "载入", "结束", "测试", "曲目", "播放",
]
CHARS = sorted(set("".join(LABELS)))
GLYPH_BYTES = 32


def glyph_bitmap(font: ImageFont.FreeTypeFont, char: str) -> bytes:
    image = Image.new("L", (16, 16), 0)
    draw = ImageDraw.Draw(image)
    # Font metrics include an ascender offset; fit the complete ink bounds.
    bounds = font.getbbox(char)
    glyph = Image.new("L", (bounds[2]-bounds[0], bounds[3]-bounds[1]), 0)
    ImageDraw.Draw(glyph).text((-bounds[0], -bounds[1]), char, font=font, fill=255)
    glyph.thumbnail((14, 14), Image.Resampling.LANCZOS)
    image.paste(glyph, ((16-glyph.width)//2, (16-glyph.height)//2))
    rows = []
    for y in range(16):
        bits = 0
        for x in range(16):
            if image.getpixel((x, y)) >= 96:
                bits |= 1 << (15 - x)
        rows.append(bits.to_bytes(2, "big"))
    return b"".join(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUT)
    output = parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(FONT), 16, index=0)
    data = b"".join(glyph_bitmap(font, char) for char in CHARS)
    (output / "FONT16.BIN").write_bytes(data)
    (output / "FONT16.MEM").write_text(
        "".join(f"{byte:02X}\n" for byte in data), encoding="ascii"
    )
    rows = [data[i:i + 2] for i in range(0, len(data), 2)]
    (PROJECT_OUT / "font16_rows.mem").write_text(
        "".join(f"{int.from_bytes(row, 'big'):04X}\n" for row in rows),
        encoding="ascii",
    )
    (output / "FONTMAP.TXT").write_text(
        "Glyph index, UTF-8 character, byte offset\n"
        + "".join(f"{i:02d}\t{char}\t{i * GLYPH_BYTES}\n" for i, char in enumerate(CHARS)),
        encoding="utf-8",
    )
    (output / "FONTINFO.TXT").write_text(
        "FPGA Chinese font resource\n"
        "FONT16.BIN: packed 16x16 monochrome glyphs, row-major, MSB is left pixel.\n"
        "FONT16.MEM: one hexadecimal byte per line, suitable as a BRAM init source.\n"
        "FONTMAP.TXT: glyph index and UTF-8 character mapping.\n"
        f"Glyphs: {len(CHARS)}; bytes per glyph: {GLYPH_BYTES}; total bytes: {len(data)}.\n"
        "The FPGA initializes its BRAM font during configuration from font16_rows.mem. SD files are resource copies, not loaded at runtime.\n",
        encoding="ascii",
    )
    print(f"Wrote {len(CHARS)} glyphs ({len(data)} bytes) to {output}")


if __name__ == "__main__":
    main()
