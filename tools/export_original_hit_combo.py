"""Export original mission2 combo glyphs without changing their pixels (stdlib only)."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
import xml.etree.ElementTree as ET
import zlib


def crop_png(png, boxes, destination):
    # Original atlas is a non-interlaced RGBA PNG; undo its row filters before cropping.
    offset, compressed = 8, bytearray()
    while offset < len(png):
        length = struct.unpack_from(">I", png, offset)[0]
        kind, data = png[offset + 4:offset + 8], png[offset + 8:offset + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", data)
            assert (depth, color, interlace) == (8, 6, 0), (depth, color, interlace)
        if kind == b"IDAT":
            compressed.extend(data)
        offset += length + 12
    raw, stride = zlib.decompress(compressed), width * 4
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filtering, row = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            left, up = row[x - 4] if x >= 4 else 0, previous[x]
            upper_left = previous[x - 4] if x >= 4 else 0
            if filtering == 1:
                prediction = left
            elif filtering == 2:
                prediction = up
            elif filtering == 3:
                prediction = (left + up) // 2
            elif filtering == 4:
                p = left + up - upper_left
                distances = [abs(p - left), abs(p - up), abs(p - upper_left)]
                prediction = (left, up, upper_left)[distances.index(min(distances))]
            else:
                assert filtering == 0
                prediction = 0
            row[x] = (row[x] + prediction) & 255
        rows.append(row)
        previous = row

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    for box in boxes:
        x, y, w, h = [int(box[key]) for key in ("x", "y", "width", "height")]
        data = b"".join(b"\0" + rows[line][x * 4:(x + w) * 4] for line in range(y, y + h))
        image = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        image += chunk(b"IDAT", zlib.compress(data, 9)) + chunk(b"IEND", b"")
        (destination / (box["name"] + ".png")).write_bytes(image)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(args.reference))
    from backends.zmhj_config import _Amf3Reader, _read_one
    source = args.reference / "games/zmhj-g5/cache/assets/ui/mission2_20250707_1.swf"
    reader = _Amf3Reader(source.read_bytes())
    header = reader.read()
    entries = [_read_one(zlib.decompress(reader.read(), -15)) for _ in range(header["fn"])]
    data = {entry["extension"]: zlib.decompress(entry["data"]) for entry in entries}
    boxes = [entry.attrib for entry in ET.fromstring(data["xml"]) if entry.attrib["name"].startswith("hitCombo")]
    destination = Path(__file__).resolve().parent.parent / "assets/ui/original/hit_combo"
    destination.mkdir(parents=True, exist_ok=True)
    crop_png(data["png"], boxes, destination)
    (destination / "source_mapping.json").write_text(json.dumps({
        "source": str(source), "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "logic": ["viewers/component/HitCombox.as", "viewers/container/layers/BattleTopLayer.as"],
        "position": [640, 150], "digit_spacing": 48, "label_x": 192,
        "timeout_seconds": 1.5, "glyphs": boxes,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(boxes)} original combo glyphs to {destination}")


if __name__ == "__main__":
    main()
