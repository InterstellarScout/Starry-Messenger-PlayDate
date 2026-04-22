#!/usr/bin/env python
from __future__ import annotations

import argparse
import base64
import html
import io
import math
import os
import re
import sys
from pathlib import Path
from typing import Iterable
from urllib.parse import urlparse

import requests
from PIL import Image, ImageOps, ImageSequence


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "Source"
GIF_DIR = SOURCE_DIR / "gifs"
SOURCE_GIF_DIR = PROJECT_ROOT / "assets" / "source_gifs" / "originals"
DATA_DIR = SOURCE_DIR / "data"
CATALOG_PATH = DATA_DIR / "gifs.lua"
SCREEN_SIZE = (400, 240)
USER_AGENT = "StarryMessengerGifAdapter/1.0"
GIF_LENGTH_FOLDERS = (
    (16, "xs"),
    (32, "sm"),
    (64, "md"),
    (96, "lg"),
)
SEED_ENTRIES = []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download and convert GIF-like sources for Starry Messenger.")
    parser.add_argument("--urls-file", required=True, help="Path to a text file containing one URL per line.")
    parser.add_argument("--max-frames", type=int, default=48, help="Maximum number of frames to keep per GIF.")
    parser.add_argument("--timeout", type=int, default=30, help="HTTP timeout in seconds.")
    return parser.parse_args()


def read_urls(path: Path) -> list[dict[str, str | bool]]:
    urls: list[dict[str, str | bool]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        rotate = False
        if value.lower().startswith("rotate|"):
            rotate = True
            value = value[7:].strip()
        urls.append({
            "url": value,
            "rotate": rotate
        })
    return urls


def slugify(text: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return value or "gif"


def titleize_slug(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("-", " ").replace("_", " ")).strip().title()


def clean_title(text: str) -> str:
    title = html.unescape(re.sub(r"\s+", " ", text).strip())
    title = re.sub(r"\s*-\s*Discover\s*&\s*Share(?:\s+GIFs?)?\s*$", "", title, flags=re.IGNORECASE)
    title = re.sub(r"\s*[\-|]\s*(Tenor|Brave Search|Brave Images?)\s*$", "", title, flags=re.IGNORECASE)
    title = re.sub(r"\s*\|\s*GIFDB\.com\s*$", "", title, flags=re.IGNORECASE)
    title = re.sub(r"\s+GIFs?$", "", title, flags=re.IGNORECASE)
    title = re.sub(r"\s*[-|]\s*Animated GIF.*$", "", title, flags=re.IGNORECASE)
    title = title.strip(" -|")
    return title or "Untitled GIF"


def decode_embedded_url(url: str) -> str | None:
    parsed = urlparse(url)
    parts = [part.strip() for part in parsed.path.split("/") if part.strip()]
    for index, part in enumerate(parts):
        candidates = [part]
        if part.startswith("aHR0"):
            candidates.append("/".join(parts[index:]))
        for chunk in candidates:
            if len(chunk) < 16:
                continue
            if chunk.lower().endswith(".gif"):
                chunk = chunk[:-4]
            padded = chunk + ("=" * ((4 - (len(chunk) % 4)) % 4))
            try:
                decoded = base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8", "ignore")
            except Exception:
                continue
            if decoded.startswith("http://") or decoded.startswith("https://"):
                return decoded
    return None


def make_absolute_url(base_url: str, value: str) -> str:
    if value.startswith("http://") or value.startswith("https://"):
        return value
    if value.startswith("//"):
        return "https:" + value
    return requests.compat.urljoin(base_url, value)


def normalize_media_url(base_url: str, value: str | None) -> str | None:
    if value is None:
        return None
    media_url = value.strip()
    if media_url.startswith("hhttps://"):
        media_url = "https://" + media_url[len("hhttps://"):]
    elif media_url.startswith("hhttp://"):
        media_url = "http://" + media_url[len("hhttp://"):]
    return make_absolute_url(base_url, media_url)


def fetch_image_html_media(session: requests.Session, url: str, timeout: int) -> tuple[str, str, bytes] | None:
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    content_type = response.headers.get("content-type", "")
    if "text/html" not in content_type:
        return None

    html = response.text
    title = extract_meta(html, "og:title", "twitter:title") or derive_title_from_url(response.url)
    title = clean_title(title)

    media_url = normalize_media_url(response.url, extract_meta(html, "og:image", "twitter:image"))
    if media_url is None:
        return None

    media_response = session.get(media_url, timeout=timeout)
    media_response.raise_for_status()
    return title, media_response.url, media_response.content


def fetch_binary(session: requests.Session, url: str, timeout: int) -> tuple[str, str, bytes]:
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    title = derive_title_from_url(url)
    return title, response.url, response.content


def derive_title_from_url(url: str) -> str:
    decoded = decode_embedded_url(url)
    candidate = decoded or url
    path = urlparse(candidate).path
    name = Path(path).name
    stem = re.sub(r"\.(gif|mp4|webm)$", "", name, flags=re.IGNORECASE)
    stem = re.sub(r"-[a-z0-9]{8,}$", "", stem, flags=re.IGNORECASE)
    stem = re.sub(r"-\d+x-\d+.*$", "", stem, flags=re.IGNORECASE)
    stem = re.sub(r"-by[a-z0-9-]+$", "", stem, flags=re.IGNORECASE)
    stem = stem.strip("-_ ")
    if not stem:
        stem = "gif"
    return clean_title(titleize_slug(stem))


def extract_meta(html: str, *keys: str) -> str | None:
    patterns: list[str] = []
    for key in keys:
        escaped = re.escape(key)
        patterns.append(rf'<meta[^>]+property=["\']{escaped}["\'][^>]+content=["\']([^"\']+)')
        patterns.append(rf'<meta[^>]+name=["\']{escaped}["\'][^>]+content=["\']([^"\']+)')
    patterns.append(r"<title>(.*?)</title>")
    for pattern in patterns:
        match = re.search(pattern, html, flags=re.IGNORECASE | re.DOTALL)
        if match:
            return re.sub(r"\s+", " ", match.group(1)).strip()
    return None


def is_direct_media_url(url: str) -> bool:
    return re.search(r"\.(gif|mp4|webm)(?:$|\?)", url, flags=re.IGNORECASE) is not None


def resolve_media(session: requests.Session, url: str, timeout: int) -> tuple[str, str, bytes]:
    embedded_url = decode_embedded_url(url)
    if embedded_url is not None:
        return resolve_media(session, embedded_url, timeout)

    image_html_media = fetch_image_html_media(session, url, timeout)
    if image_html_media is not None:
        return image_html_media

    if is_direct_media_url(url):
        return fetch_binary(session, url, timeout)

    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    html = response.text

    title = extract_meta(html, "og:title", "twitter:title") or derive_title_from_url(response.url)
    title = clean_title(title)

    media_url = normalize_media_url(
        response.url,
        extract_meta(html, "og:image")
        or extract_meta(html, "twitter:image")
        or extract_meta(html, "og:video")
        or extract_meta(html, "twitter:player:stream")
    )
    if media_url is None:
        match = re.search(r"https://media[^\s\"'<>]+?\.(?:gif|mp4|webm)", html, flags=re.IGNORECASE)
        if match:
            media_url = match.group(0)
    if media_url is None:
        raise RuntimeError(f"Could not resolve media URL for {url}")

    media_response = session.get(media_url, timeout=timeout)
    media_response.raise_for_status()
    return title, media_response.url, media_response.content


def convert_frame(frame: Image.Image, rotate_to_landscape: bool = False) -> tuple[Image.Image, int, int]:
    rgba = frame.convert("RGBA")
    if rotate_to_landscape and rgba.height > rgba.width:
        rgba = rgba.rotate(90, expand=True)
    background = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    composited = Image.alpha_composite(background, rgba).convert("L")
    composited.thumbnail(SCREEN_SIZE, Image.Resampling.LANCZOS)
    bitmap = composited.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
    return bitmap, bitmap.width, bitmap.height


def sample_frames(image: Image.Image, max_frames: int) -> list[Image.Image]:
    frames = [frame.copy() for frame in ImageSequence.Iterator(image)]
    if not frames:
        frames = [image.copy()]
    if len(frames) <= max_frames:
        return frames

    sampled: list[Image.Image] = []
    step = len(frames) / max_frames
    for index in range(max_frames):
        sampled.append(frames[min(len(frames) - 1, int(math.floor(index * step)))])
    return sampled


def choose_folder_for_frame_count(frame_count: int) -> str:
    for limit, folder in GIF_LENGTH_FOLDERS:
        if frame_count <= limit:
            return folder
    return "xl"


def clear_existing_frames(prefix: str) -> None:
    for path in GIF_DIR.rglob(f"{prefix}-table-*.png"):
        path.unlink()


def write_frames(relative_prefix: str, frames: Iterable[Image.Image], rotate_to_landscape: bool = False) -> tuple[int, int, int]:
    prefix_name = Path(relative_prefix).name
    clear_existing_frames(prefix_name)
    output_prefix = GIF_DIR / relative_prefix
    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    width = 0
    height = 0
    count = 0
    for count, frame in enumerate(frames, start=1):
        bitmap, width, height = convert_frame(frame, rotate_to_landscape=rotate_to_landscape)
        bitmap.save(output_prefix.parent / f"{output_prefix.name}-table-{count}.png")
    return width, height, count


def write_catalog(entries: list[dict[str, int | str]]) -> None:
    lines = ["GIF_CATALOG = {"] 
    for entry in entries:
        lines.append("    {")
        lines.append(f'        label = "{entry["label"]}",')
        lines.append(f'        path = "gifs/{entry["path"]}",')
        lines.append(f'        width = {entry["width"]},')
        lines.append(f'        height = {entry["height"]},')
        lines.append(f'        frameCount = {entry["frameCount"]}')
        lines.append("    },")
    lines.append("}")
    CATALOG_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_source_media(prefix: str, media_url: str, payload: bytes) -> None:
    parsed = urlparse(media_url)
    suffix = Path(parsed.path).suffix or ".gif"
    SOURCE_GIF_DIR.mkdir(parents=True, exist_ok=True)
    (SOURCE_GIF_DIR / f"{prefix}{suffix.lower()}").write_bytes(payload)


def main() -> int:
    args = parse_args()
    urls = read_urls(Path(args.urls_file))
    GIF_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_GIF_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    entries: list[dict[str, int | str]] = []
    seen_media: set[str] = set()
    used_paths: set[str] = {str(entry["path"]) for entry in SEED_ENTRIES}

    entries.extend(SEED_ENTRIES)

    for item in urls:
        url = str(item["url"])
        rotate_to_landscape = item["rotate"] == True
        try:
            title, media_url, payload = resolve_media(session, url, args.timeout)
        except Exception as exc:
            print(f"FAILED resolve {url}: {exc}", file=sys.stderr)
            continue

        if media_url in seen_media:
            print(f"SKIP duplicate {media_url}")
            continue
        seen_media.add(media_url)

        prefix = slugify(title)
        suffix = 2
        while prefix in used_paths:
            prefix = f"{slugify(title)}-{suffix}"
            suffix += 1
        used_paths.add(prefix)

        write_source_media(prefix, media_url, payload)

        try:
            image = Image.open(io.BytesIO(payload))
            frames = sample_frames(image, args.max_frames)
            frame_count_hint = len(frames)
            folder = choose_folder_for_frame_count(frame_count_hint)
            relative_prefix = f"{folder}/{prefix}"
            width, height, frame_count = write_frames(relative_prefix, frames, rotate_to_landscape=rotate_to_landscape)
        except Exception as exc:
            print(f"FAILED convert {url}: {exc}", file=sys.stderr)
            continue

        entries.append({
            "label": clean_title(title).replace('"', "'"),
            "path": relative_prefix,
            "width": width,
            "height": height,
            "frameCount": frame_count
        })
        print(f"OK {title} -> {relative_prefix} ({frame_count} frames)")

    entries.sort(key=lambda item: str(item["label"]).lower())
    write_catalog(entries)
    print(f"Wrote {len(entries)} catalog entries to {CATALOG_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
