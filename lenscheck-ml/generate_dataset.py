"""
generate_dataset.py

Turns a folder of clean, sharp, well-exposed photos into a labeled dataset
for training a quality-assessment model — by synthetically degrading each
photo with KNOWN amounts of blur and exposure shift, then using those known
amounts as ground-truth labels.

This is a legitimate technique (synthetic degradation for supervised quality
assessment training), not a shortcut — you don't need to find or license an
external labeled dataset.

Usage:
    python3 generate_dataset.py --input photos/ --output dataset/ --variants 8

Requires: pillow (pip install pillow)
"""

import argparse
import csv
import os
import random
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

IMAGE_SIZE = (224, 224)  # matches the input size the model will train on
MAX_BLUR_RADIUS = 6.0    # gaussian blur sigma at the blurriest synthetic sample
MAX_BRIGHTNESS_SHIFT = 0.7  # how far enhance() factor can move from 1.0


def load_source_images(input_dir: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png", ".heic"}
    return sorted(p for p in input_dir.rglob("*") if p.suffix.lower() in exts)


def degrade_image(image: Image.Image, blur_radius: float, brightness_factor: float) -> Image.Image:
    result = image
    if blur_radius > 0:
        result = result.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    if brightness_factor != 1.0:
        result = ImageEnhance.Brightness(result).enhance(brightness_factor)
    return result


def sharpness_label(blur_radius: float) -> float:
    # 0 blur -> 100 (perfectly sharp), MAX_BLUR_RADIUS -> 0 (very blurry)
    normalized = 1.0 - (blur_radius / MAX_BLUR_RADIUS)
    return max(0.0, min(100.0, normalized * 100.0))


def exposure_label(brightness_factor: float) -> float:
    # factor == 1.0 -> 100 (well exposed), further from 1.0 -> lower score
    deviation = abs(brightness_factor - 1.0) / MAX_BRIGHTNESS_SHIFT
    return max(0.0, min(100.0, (1.0 - deviation) * 100.0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Folder of clean source photos")
    parser.add_argument("--output", type=Path, required=True, help="Output folder for the dataset")
    parser.add_argument("--variants", type=int, default=8, help="Synthetic variants per source photo")
    parser.add_argument("--val-split", type=float, default=0.2, help="Fraction reserved for validation")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)

    sources = load_source_images(args.input)
    if not sources:
        raise SystemExit(f"No images found in {args.input}. Supported: .jpg .jpeg .png .heic")

    images_dir = args.output / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for source_path in sources:
        try:
            original = Image.open(source_path).convert("RGB").resize(IMAGE_SIZE)
        except Exception as e:
            print(f"Skipping {source_path.name}: {e}")
            continue

        for variant_idx in range(args.variants):
            # Always include a couple of "clean" (near-perfect) samples so the
            # model sees what a genuinely good photo looks like, not just
            # degraded ones.
            if variant_idx == 0:
                blur_radius = 0.0
                brightness_factor = 1.0
            else:
                blur_radius = random.uniform(0, MAX_BLUR_RADIUS)
                brightness_factor = 1.0 + random.uniform(-MAX_BRIGHTNESS_SHIFT, MAX_BRIGHTNESS_SHIFT)

            degraded = degrade_image(original, blur_radius, brightness_factor)

            filename = f"{source_path.stem}_{variant_idx}.jpg"
            degraded.save(images_dir / filename, quality=90)

            rows.append({
                "filename": filename,
                "sharpness_score": round(sharpness_label(blur_radius), 2),
                "exposure_score": round(exposure_label(brightness_factor), 2),
                "split": "val" if random.random() < args.val_split else "train",
            })

    manifest_path = args.output / "manifest.csv"
    with open(manifest_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["filename", "sharpness_score", "exposure_score", "split"])
        writer.writeheader()
        writer.writerows(rows)

    train_count = sum(1 for r in rows if r["split"] == "train")
    val_count = sum(1 for r in rows if r["split"] == "val")
    print(f"Generated {len(rows)} samples from {len(sources)} source photos.")
    print(f"  train: {train_count}   val: {val_count}")
    print(f"Images: {images_dir}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
