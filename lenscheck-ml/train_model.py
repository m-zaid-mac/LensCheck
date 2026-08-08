"""
train_model.py

Trains a small quality-assessment model on the dataset produced by
generate_dataset.py: a MobileNetV3-Small backbone (pretrained on ImageNet)
with a small regression head outputting [sharpness, exposure] scores.

Normalization is baked INSIDE the model (see QualityModel.forward) rather
than done in the data pipeline. This matters for the later Core ML
conversion step: it means the exported model can accept a raw 0-1 image
tensor directly, which lines up cleanly with how Core ML's ImageType
input works.

Usage:
    python3 train_model.py --data dataset/ --epochs 15 --output quality_model_traced.pt

Requires: torch, torchvision, pillow
    pip install torch torchvision pillow
"""

import argparse
import csv
import os
from pathlib import Path

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from PIL import Image


class QualityDataset(Dataset):
    def __init__(self, manifest_path: Path, images_dir: Path, split: str):
        self.images_dir = images_dir
        self.rows = []
        with open(manifest_path) as f:
            for row in csv.DictReader(f):
                if row["split"] == split:
                    self.rows.append(row)

        # ToTensor() alone scales pixels to [0,1] and does NOT apply
        # ImageNet mean/std normalization — that happens inside the model.
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
        ])

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, idx):
        row = self.rows[idx]
        image = Image.open(self.images_dir / row["filename"]).convert("RGB")
        image = self.transform(image)
        target = torch.tensor(
            [float(row["sharpness_score"]), float(row["exposure_score"])],
            dtype=torch.float32,
        )
        return image, target


class QualityModel(nn.Module):
    """Wraps MobileNetV3-Small with normalization baked into forward(),
    so the exported/traced model accepts raw [0,1] images directly."""

    def __init__(self):
        super().__init__()
        backbone = models.mobilenet_v3_small(weights=models.MobileNet_V3_Small_Weights.DEFAULT)
        in_features = backbone.classifier[0].in_features
        backbone.classifier = nn.Sequential(
            nn.Linear(in_features, 64),
            nn.ReLU(),
            nn.Linear(64, 2),
        )
        self.backbone = backbone
        self.register_buffer("mean", torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1))

    def forward(self, x):
        # x is expected in [0, 1], shape (N, 3, 224, 224)
        x = (x - self.mean) / self.std
        raw = self.backbone(x)
        return torch.sigmoid(raw) * 100.0  # bound outputs to a sane 0-100 range


def pick_device() -> torch.device:
    if torch.backends.mps.is_available():
        return torch.device("mps")  # Apple Silicon GPU
    if torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


def run_epoch(model, loader, criterion, optimizer, device, train: bool) -> float:
    model.train() if train else model.eval()
    total_loss = 0.0
    context = torch.enable_grad() if train else torch.no_grad()
    with context:
        for images, targets in loader:
            images, targets = images.to(device), targets.to(device)
            if train:
                optimizer.zero_grad()
            predictions = model(images)
            loss = criterion(predictions, targets)
            if train:
                loss.backward()
                optimizer.step()
            total_loss += loss.item() * images.size(0)
    return total_loss / len(loader.dataset)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True, help="Dataset folder from generate_dataset.py")
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--output", type=Path, default=Path("quality_model_traced.pt"))
    args = parser.parse_args()

    device = pick_device()
    print(f"Using device: {device}")

    manifest = args.data / "manifest.csv"
    images_dir = args.data / "images"

    train_ds = QualityDataset(manifest, images_dir, split="train")
    val_ds = QualityDataset(manifest, images_dir, split="val")
    print(f"Train samples: {len(train_ds)}   Val samples: {len(val_ds)}")

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)

    model = QualityModel().to(device)
    criterion = nn.MSELoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)

    best_val_loss = float("inf")
    for epoch in range(1, args.epochs + 1):
        train_loss = run_epoch(model, train_loader, criterion, optimizer, device, train=True)
        val_loss = run_epoch(model, val_loader, criterion, optimizer, device, train=False)
        marker = ""
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            marker = "  <- best so far"
        print(f"Epoch {epoch:2d}/{args.epochs}  train_loss={train_loss:.2f}  val_loss={val_loss:.2f}{marker}")

    # Export for Core ML conversion: trace with a fixed input shape.
    model.eval()
    model_cpu = model.to("cpu")
    example_input = torch.rand(1, 3, 224, 224)
    traced = torch.jit.trace(model_cpu, example_input)
    traced.save(str(args.output))
    print(f"Saved traced model to {args.output}")
    print("Next step: python3 convert_to_coreml.py --model", args.output)


if __name__ == "__main__":
    main()
