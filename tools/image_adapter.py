#!/usr/bin/env python3
"""
Shrink large still images into Playdate-friendly monochrome PNGs.

Default workflow:
- place source JPG/PNG/WebP/TIFF files under assets/source_images/originals/
- run: python .\\tools\\image_adapter.py
- collect processed files from Source/images/adapted/
- each source image produces both a fit-to-screen and fullscreen-cropped Playdate PNG
"""
from __future__ import annotations

import argparse
import math
import random
import re
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Pillow is required: pip install pillow") from exc


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DEFAULT_SOURCE_ROOT = PROJECT_ROOT / "assets" / "source_images" / "originals"
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "Source" / "images" / "adapted"
DEFAULT_MANIFEST_PATH = PROJECT_ROOT / "Source" / "data" / "photos.lua"
DEFAULT_LAUNCHER_PATH = PROJECT_ROOT / "Source" / "launcher.png"
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".bmp"}
PHOTOGRAPHER_OVERRIDES = {
    "Science Officers in Mission Control": "Robert Markowitz / NASA-Johnson Space Center",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert still images into Playdate-sized monochrome PNGs.")
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT, help="Folder containing original still images.")
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT, help="Folder for converted PNGs.")
    parser.add_argument("--width", type=int, default=400, help="Maximum output width.")
    parser.add_argument("--height", type=int, default=240, help="Maximum output height.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH, help="Lua manifest output path.")
    parser.add_argument("--launcher-path", type=Path, default=DEFAULT_LAUNCHER_PATH, help="Launcher image output path.")
    parser.add_argument(
        "--dither",
        choices=("floyd", "none"),
        default="floyd",
        help="Floyd uses Pillow dithering. none uses a hard threshold.",
    )
    parser.add_argument("--threshold", type=int, default=144, help="Threshold used when --dither none is selected.")
    return parser.parse_args()


def slugify(name: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "-", name.strip().lower())
    cleaned = re.sub(r"-{2,}", "-", cleaned).strip("-")
    return cleaned or "image"


def resize_image(image: Image.Image, width: int, height: int, fit: str) -> Image.Image:
    source = image.convert("L")
    if fit == "contain":
        source.thumbnail((width, height), Image.Resampling.LANCZOS)
        canvas = Image.new("L", (width, height), color=255)
        x = (width - source.width) // 2
        y = (height - source.height) // 2
        canvas.paste(source, (x, y))
        return canvas

    scale = max(width / source.width, height / source.height)
    resized = source.resize(
        (max(1, int(math.ceil(source.width * scale))), max(1, int(math.ceil(source.height * scale)))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - width) // 2)
    top = max(0, (resized.height - height) // 2)
    return resized.crop((left, top, left + width, top + height))


def to_monochrome(image: Image.Image, dither: str, threshold: int) -> Image.Image:
    if dither == "floyd":
        return image.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
    return image.point(lambda value: 255 if value > threshold else 0, mode="1")


def load_title_font(size: int) -> ImageFont.ImageFont:
    font_candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/Arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
    ]
    for candidate in font_candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def draw_launcher_stars(draw: ImageDraw.ImageDraw, width: int, height: int, rng: random.Random) -> None:
    star_count = 160
    for _ in range(star_count):
        x = rng.randint(0, width - 1)
        y = rng.randint(0, height - 1)
        size_roll = rng.random()
        if size_roll > 0.96:
            radius = 2
        elif size_roll > 0.78:
            radius = 1
        else:
            radius = 0

        if radius <= 0:
            draw.point((x, y), fill=255)
        else:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)


def generate_launcher_image(
    source_images: list[Path],
    launcher_path: Path,
    width: int,
    height: int,
    dither: str,
    threshold: int,
) -> Path | None:
    if not source_images:
        return None

    chosen_path = random.choice(source_images)
    with Image.open(chosen_path) as image:
        launcher_image = resize_image(image, width, height, "cover").convert("L")

    draw = ImageDraw.Draw(launcher_image)
    overlay_fill = 96
    draw.rectangle((0, 0, width, height), fill=overlay_fill)

    rng = random.Random(chosen_path.stem)
    draw_launcher_stars(draw, width, height, rng)

    font = load_title_font(34)
    title = "Starry Messenger"
    text_box = draw.textbbox((0, 0), title, font=font)
    text_width = text_box[2] - text_box[0]
    text_height = text_box[3] - text_box[1]
    text_x = (width - text_width) // 2
    text_y = 105
    draw.text((text_x, text_y), title, font=font, fill=255)

    launcher_path.parent.mkdir(parents=True, exist_ok=True)
    to_monochrome(launcher_image, dither, threshold).save(launcher_path, optimize=True)
    return chosen_path


def convert_one(source_root: Path, path: Path, output_root: Path, width: int, height: int, fit: str, dither: str, threshold: int) -> Path:
    with Image.open(path) as image:
        resized = resize_image(image, width, height, fit)
        mono = to_monochrome(resized, dither, threshold)

    relative_parent = path.parent.relative_to(source_root)
    target_dir = output_root / relative_parent
    target_dir.mkdir(parents=True, exist_ok=True)
    output_path = target_dir / f"{slugify(path.stem)}.png"
    mono.save(output_path, optimize=True)
    return output_path


def convert_variants(source_root: Path, path: Path, output_root: Path, width: int, height: int, dither: str, threshold: int) -> dict[str, Path]:
    relative_parent = path.parent.relative_to(source_root)
    target_dir = output_root / relative_parent
    target_dir.mkdir(parents=True, exist_ok=True)
    base_name = slugify(path.stem)

    variants = {
        "fitPath": target_dir / f"{base_name}-fit.png",
        "fillPath": target_dir / f"{base_name}-fill.png",
    }

    with Image.open(path) as image:
        fit_image = to_monochrome(resize_image(image, width, height, "contain"), dither, threshold)
        fill_image = to_monochrome(resize_image(image, width, height, "cover"), dither, threshold)

    fit_image.save(variants["fitPath"], optimize=True)
    fill_image.save(variants["fillPath"], optimize=True)
    return variants


def lua_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def read_source_metadata(path: Path) -> dict[str, str]:
    with Image.open(path) as image:
        exif = image.getexif()

    metadata: dict[str, str] = {}
    if not exif:
        return metadata

    tag_names = {
        270: "description",
        315: "artist",
        33432: "copyright",
    }
    for tag, field_name in tag_names.items():
        value = exif.get(tag)
        if value:
            metadata[field_name] = str(value)
    return metadata


def infer_photographer(label: str, metadata: dict[str, str]) -> str:
    if label in PHOTOGRAPHER_OVERRIDES:
        return PHOTOGRAPHER_OVERRIDES[label]

    artist = metadata.get("artist", "").strip()
    copyright_ = metadata.get("copyright", "").strip()
    description = metadata.get("description", "").strip()
    search_blob = " ".join(part for part in (artist, copyright_, description) if part).lower()

    if "robert markowitz" in search_blob:
        return "Robert Markowitz / NASA-Johnson Space Center"

    found_names: list[str] = []
    for needle, credit_name in (
        ("koch", "Christina Koch"),
        ("glover", "Victor Glover"),
        ("wiseman", "Reid Wiseman"),
        ("hansen", "Jeremy Hansen"),
    ):
        if needle in search_blob:
            found_names.append(credit_name)

    if len(found_names) == 1:
        return found_names[0]
    if len(found_names) > 1:
        return "Artemis II crew"
    if "pao" in search_blob:
        return "NASA"
    if "science" in search_blob or "survey" in search_blob:
        return "NASA"
    if artist:
        return artist
    if copyright_:
        return copyright_
    return "NASA"


def write_manifest(manifest_path: Path, project_root: Path, entries: list[dict[str, str]]) -> None:
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "PHOTO_CATALOG = {"
    ]
    for entry in entries:
        lines.append("    {")
        lines.append(f"        label = {lua_quote(entry['label'])},")
        lines.append(f"        photographer = {lua_quote(entry['photographer'])},")
        if "path" in entry:
            lines.append(f"        path = {lua_quote(entry['path'])},")
        lines.append(f"        fitPath = {lua_quote(entry['fitPath'])},")
        lines.append(f"        fillPath = {lua_quote(entry['fillPath'])}")
        lines.append("    },")
    lines.append("}")
    manifest_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def iter_source_images(source_root: Path) -> list[Path]:
    if not source_root.exists():
        return []
    return sorted(path for path in source_root.rglob("*") if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS)


def main() -> int:
    args = parse_args()
    images = iter_source_images(args.source_root)
    if not images:
        print(f"No source images found in {args.source_root}")
        return 0

    args.output_root.mkdir(parents=True, exist_ok=True)
    manifest_entries: list[dict[str, str]] = []
    for image_path in images:
        metadata = read_source_metadata(image_path)
        output_paths = convert_variants(
            args.source_root,
            image_path,
            args.output_root,
            args.width,
            args.height,
            args.dither,
            args.threshold,
        )
        manifest_entries.append({
            "label": image_path.stem,
            "photographer": infer_photographer(image_path.stem, metadata),
            "path": output_paths["fillPath"].relative_to(PROJECT_ROOT).with_suffix("").as_posix().replace("Source/", ""),
            "fitPath": output_paths["fitPath"].relative_to(PROJECT_ROOT).with_suffix("").as_posix().replace("Source/", ""),
            "fillPath": output_paths["fillPath"].relative_to(PROJECT_ROOT).with_suffix("").as_posix().replace("Source/", ""),
        })
        print(
            f"OK {image_path.name} -> "
            f"{output_paths['fitPath'].relative_to(PROJECT_ROOT)}, "
            f"{output_paths['fillPath'].relative_to(PROJECT_ROOT)}"
        )

    write_manifest(args.manifest, PROJECT_ROOT, manifest_entries)
    print(f"Manifest -> {args.manifest.relative_to(PROJECT_ROOT)} ({len(manifest_entries)} items)")
    chosen_launcher_source = generate_launcher_image(
        images,
        args.launcher_path,
        args.width,
        args.height,
        args.dither,
        args.threshold,
    )
    if chosen_launcher_source is not None:
        print(
            f"Launcher -> {args.launcher_path.relative_to(PROJECT_ROOT)} "
            f"from {chosen_launcher_source.relative_to(PROJECT_ROOT)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
