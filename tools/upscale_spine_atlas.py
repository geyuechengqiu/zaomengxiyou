"""Extract isolated Spine regions and assemble results from a user supplied 4x upscaler.

This is an offline asset tool. It preserves rotated packing, aliases, offsets
and premultiplied alpha; the neural inference is performed by the supplied EXE.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading

from PIL import Image, ImageChops, ImageMath


def regions(text):
    entries, current = [], None
    for line in text.splitlines()[1:]:
        if not line.strip():
            continue
        if ":" not in line:
            current = {"name": line.strip()}
            entries.append(current)
        elif current is not None:
            key, value = line.strip().split(":", 1)
            current[key] = value.strip()
    for entry in entries:
        entry["rect"] = [int(n) for n in entry["bounds"].split(",")]
        entry["rotation"] = int(entry.get("rotate", "0"))
        if entry["rotation"] not in (0, 90):
            raise ValueError("Only standard 0/90-degree packing is supported")
    return entries


def straight_alpha(image):
    r, g, b, alpha = image.split()
    def divide(channel):
        return ImageMath.lambda_eval(lambda args: args["convert"](
            args["c"] * 255 / (args["a"] + (args["a"] == 0)), "L"), c=channel, a=alpha)
    return Image.merge("RGBA", (divide(r), divide(g), divide(b), alpha))


def premultiply(image):
    r, g, b, a = image.split()
    return Image.merge("RGBA", (ImageChops.multiply(r, a), ImageChops.multiply(g, a), ImageChops.multiply(b, a), a))


def editable_skeleton(work):
    """Change only the nonessential image folder in the separate editor copy."""
    binary = (work/"result/wukong.skel").read_bytes()
    position = 8
    def read_varint():
        nonlocal position
        value, shift = 0, 0
        while True:
            byte = binary[position]
            position += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value
            shift += 7
    version_bytes = read_varint()-1
    position += version_bytes+20
    if binary[position] != 1:
        raise ValueError("Editor export needs nonessential data")
    position += 5  # Nonessential flag and FPS.
    start = position
    length = read_varint()-1
    end = position+length
    images = b"./images/"
    output = binary[:start]+bytes([len(images)+1])+images+binary[end:]
    folder = work/"editable"
    folder.mkdir(exist_ok=True)
    (folder/"wukong_hd4x.skel").write_bytes(output)
    print("Created editor import: editable/wukong_hd4x.skel + named images/", flush=True)


def extract(source, work):
    backup, pieces = work/"original", work/"source-pieces"
    backup.mkdir(parents=True, exist_ok=False)
    pieces.mkdir(exist_ok=False)
    for name in ("wukong.atlas", "wukong.png", "wukong.skel"):
        shutil.copy2(source/name, backup/name)
    text = (backup/"wukong.atlas").read_text(encoding="utf-8-sig")
    if text.splitlines()[0] != "wukong.png":
        raise ValueError("Expected the current single-page wukong atlas")
    with Image.open(backup/"wukong.png") as image:
        image = image.convert("RGBA")
        entries, unique = regions(text), {}
        for entry in entries:
            x, y, width, height = entry["rect"]
            packed_w, packed_h = (height, width) if entry["rotation"] else (width, height)
            if min(width, height) <= 0 or x < 0 or y < 0 or x+packed_w > image.width or y+packed_h > image.height:
                raise ValueError("Region exceeds source atlas: " + entry["name"])
            identity = (*entry["rect"], entry["rotation"])
            if identity not in unique:
                name = f"piece_{len(unique):04d}.png"
                part = image.crop((x, y, x+packed_w, y+packed_h))
                if entry["rotation"]:
                    part = part.transpose(Image.Transpose.ROTATE_90)
                if "pma:true" in text:
                    part = straight_alpha(part)
                part.save(pieces/name)
                unique[identity] = name
            entry["piece"] = unique[identity]
        manifest = {"factor": 4, "source_size": list(image.size), "pma": "pma:true" in text,
                    "regions": entries, "unique_pieces": len(unique),
                    "source_hashes": {name: hashlib.sha256((backup/name).read_bytes()).hexdigest()
                                      for name in ("wukong.atlas", "wukong.png", "wukong.skel")}}
    (work/"manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Extracted {len(entries)} regions into {len(unique)} isolated pieces", flush=True)


def assemble(work):
    manifest = json.loads((work/"manifest.json").read_text(encoding="utf-8"))
    factor = manifest["factor"]
    width, height = manifest["source_size"]
    # One packed rectangle can be shared by several skins. Resolve hand-fixed
    # fragments by piece ID so both the atlas and every editable alias agree.
    patch_root = Path(__file__).resolve().parent/"asset_patches"
    patch_names = {"base/zb/yf_20": "sunwukong_base_belt.png"}
    overrides = {entry["piece"]: patch_root/patch_names[entry["name"]]
                 for entry in manifest["regions"] if entry["name"] in patch_names
                 and (patch_root/patch_names[entry["name"]]).exists()}
    def piece_path(entry):
        return overrides.get(entry["piece"], work/"upscaled-pieces"/entry["piece"])
    # Preserve the source packer's duplicated-edge gutters between regions.
    with Image.open(work/"original/wukong.png") as packed:
        target = packed.convert("RGBA").resize((width*factor, height*factor), Image.Resampling.NEAREST)
    used = set()
    for entry in manifest["regions"]:
        if entry["piece"] in used:
            continue
        used.add(entry["piece"])
        x, y, w, h = entry["rect"]
        with Image.open(piece_path(entry)) as image:
            image = image.convert("RGBA")
            if image.size != (w*factor, h*factor):
                raise ValueError("Upscaled piece has unexpected dimensions: " + entry["name"])
            if manifest["pma"]:
                image = premultiply(image)
            if entry["rotation"]:
                image = image.transpose(Image.Transpose.ROTATE_270)
            target.paste(image, (x*factor, y*factor))
    # No masking on paste: applying alpha twice would darken sprite outlines.
    result = work/"result"
    result.mkdir(exist_ok=True)
    target.save(result/"wukong.png", compress_level=6)
    text = (work/"original/wukong.atlas").read_text(encoding="utf-8-sig")
    output = []
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            if key.strip() in ("size", "bounds", "offsets", "split", "pad"):
                line = key+":"+",".join(str(int(v.strip())*factor) for v in value.split(","))
        output.append(line)
    (result/"wukong.atlas").write_text("\n".join(output)+"\n", encoding="utf-8")
    # An editable Spine import uses named, unrotated, untrimmed, straight-alpha
    # images. Keep these outside game imports to avoid duplicate texture loads.
    editable = work/"editable/images"
    editable.mkdir(parents=True, exist_ok=True)
    for entry in manifest["regions"]:
        target_path = editable/(entry["name"]+".png")
        if not target_path.resolve().is_relative_to(editable.resolve()):
            raise ValueError("Attachment name leaves the editable image folder")
        image = Image.open(piece_path(entry)).convert("RGBA")
        if "offsets" in entry:
            ox, oy, original_w, original_h = map(int, entry["offsets"].split(","))
            canvas = Image.new("RGBA", (original_w*factor, original_h*factor))
            canvas.paste(image, (ox*factor, (original_h-oy-entry["rect"][3])*factor))
            image = canvas
        target_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(target_path)
    # Keep representative before/after images for visual inspection.
    sample = sorted(manifest["regions"], key=lambda e: e["rect"][2]*e["rect"][3], reverse=True)[:4]
    comparison = Image.new("RGBA", (1600, 1000), (42, 45, 50, 255))
    for i, entry in enumerate(sample):
        original = Image.open(work/"source-pieces"/entry["piece"]).convert("RGBA")
        hd = Image.open(work/"upscaled-pieces"/entry["piece"]).convert("RGBA")
        original = original.resize(hd.size, Image.Resampling.NEAREST)
        for j, image in enumerate((original, hd)):
            image.thumbnail((380, 470), Image.Resampling.LANCZOS)
            comparison.alpha_composite(image, (j*800+(i%2)*400, (i//2)*500))
    comparison.save(work/"comparison.png")
    print(f"Assembled {target.width} x {target.height}; {len(used)} upscaled pieces", flush=True)
    if (result/"wukong.skel").exists():
        editable_skeleton(work)


def infer(work, tool):
    """Reuse the provided tool's color padding/model in one native batch."""
    sys.path.insert(0, str(work/"python-deps"))
    import numpy as np
    spec = importlib.util.spec_from_file_location("provided_sprite_upscaler", tool/"图片高清化.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    padded, raw, output = work/"padded-pieces", work/"inferred-pieces", work/"upscaled-pieces"
    for directory in (padded, raw, output):
        directory.mkdir(exist_ok=False)
    files = sorted((work/"source-pieces").glob("*.png"))
    cancelled = threading.Event()
    for index, path in enumerate(files, 1):
        image = Image.open(path).convert("RGBA")
        if image.size == (1, 1) or image.getchannel("A").getextrema()[1] == 0:
            image.resize((image.width*4, image.height*4), Image.Resampling.NEAREST).save(output/path.name)
        else:
            Image.fromarray(helper.extend_colors(np.array(image), cancelled)).save(padded/path.name)
        if index % 100 == 0:
            print(f"Prepared {index}/{len(files)} pieces", flush=True)
    engine = tool/"engine/realesrgan-ncnn-vulkan.exe"
    command = [str(engine), "-i", str(padded.resolve()), "-o", str(raw.resolve()),
               "-m", str((tool/"engine/models").resolve()), "-n", "realesrgan-x4plus-anime",
               "-s", "4", "-t", "128", "-j", "2:1:2", "-f", "png"]
    print(f"Starting Real-ESRGAN anime 4x batch ({len(files)} pieces)", flush=True)
    with (work/"engine.log").open("wb") as log:
        subprocess.run(command, cwd=engine.parent, stdout=log, stderr=log, check=True,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    pad = helper.PAD*4
    for path in files:
        if (output/path.name).exists():
            continue
        original = Image.open(path).convert("RGBA")
        width, height = original.width*4, original.height*4
        image = Image.open(raw/path.name).convert("RGBA")
        if image.size != (width+pad*2, height+pad*2):
            raise ValueError("Unexpected native inference size: " + path.name)
        image = image.crop((pad, pad, pad+width, pad+height))
        image.putalpha(original.getchannel("A").resize((width, height), Image.Resampling.BICUBIC))
        values = np.array(image)
        values[values[:, :, 3] == 0, :3] = 0
        Image.fromarray(values).save(output/path.name)
    print(f"Finished {len(files)} isolated 4x pieces", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "infer", "assemble"))
    parser.add_argument("--upscaler", type=Path, help="Folder containing the provided 图片高清化.py and engine/")
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1]/"assets/characters/sunwukong/animation")
    parser.add_argument("--work", type=Path, default=Path(__file__).resolve().parents[1]/".cleanup-backup/spine-hd4x")
    args = parser.parse_args()
    if args.action == "extract":
        extract(args.source, args.work)
    elif args.action == "infer":
        if not args.upscaler:
            parser.error("infer requires --upscaler")
        infer(args.work, args.upscaler)
    else:
        assemble(args.work)
