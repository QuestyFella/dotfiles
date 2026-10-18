#!/usr/bin/env python3
"""Generate a gradient wallpaper PNG for a theme palette.

Usage: make-wallpaper.py <palette.sh> <out.png> [width height]
Dependency-free (no PIL): writes the PNG by hand.
"""
import random
import re
import struct
import sys
import zlib


def palette(path):
    colors = {}
    for key, val in re.findall(r"\b([A-Z0-9]+)=([0-9a-fA-F]{6})\b", open(path).read()):
        colors[key] = tuple(int(val[i:i + 2], 16) for i in (0, 2, 4))
    return colors


def png(path, w, h, rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    raw = b"".join(b"\x00" + r for r in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))


def main():
    pal_path, out = sys.argv[1], sys.argv[2]
    w, h = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (2560, 1600)
    c = palette(pal_path)
    top, bottom = c["BASE"], c["CRUST"]
    glows = [(c["MAUVE"], 0.78, 0.22, 0.55, 0.22), (c["BLUE"], 0.15, 0.85, 0.5, 0.16)]
    rnd = random.Random(1)
    rows = []
    for y in range(h):
        t = y / (h - 1)
        base = [top[i] + (bottom[i] - top[i]) * t for i in range(3)]
        row = bytearray(w * 3)
        for x in range(w):
            px = list(base)
            for col, gx, gy, radius, strength in glows:
                dx, dy = x / w - gx, (y / h - gy) * h / w
                d2 = (dx * dx + dy * dy) / (radius * radius)
                if d2 < 1:
                    a = strength * (1 - d2) ** 2
                    for i in range(3):
                        px[i] += (col[i] - px[i]) * a
            n = rnd.random() - 0.5  # dither to avoid banding
            j = x * 3
            row[j] = min(255, max(0, int(px[0] + n)))
            row[j + 1] = min(255, max(0, int(px[1] + n)))
            row[j + 2] = min(255, max(0, int(px[2] + n)))
        rows.append(bytes(row))
    png(out, w, h, rows)


if __name__ == "__main__":
    main()
