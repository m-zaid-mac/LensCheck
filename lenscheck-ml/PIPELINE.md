# LensCheck ML Pipeline

Trains and converts the Core ML v2 quality-assessment model. Run this on
your Mac (needs internet, for downloading pretrained weights and packages).

## 0. Setup

```bash
cd lenscheck-ml
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 1. Collect source photos

Gather 30-100 of your own clean, sharp, well-exposed photos into a folder,
e.g. `photos/`. More photos = a more robust model, but even ~30 is enough
to get something working for a portfolio demo. Mix of subjects/lighting
helps the model generalize a bit.

## 2. Generate the synthetic labeled dataset

```bash
python3 generate_dataset.py --input photos/ --output dataset/ --variants 8
```

This creates `dataset/images/` and `dataset/manifest.csv`. Each source
photo produces 8 variants: one clean, seven synthetically blurred/exposure-
shifted by known amounts, which become the ground-truth labels.

Sanity check afterward: open a few images from `dataset/images/` and
confirm the ones with low scores in `manifest.csv` actually look degraded,
and the `_0` variants (always clean) score ~100 on both metrics.

## 3. Train the model

```bash
python3 train_model.py --data dataset/ --epochs 15 --output quality_model_traced.pt
```

Watch the printed val_loss each epoch — it should trend down. If it's
flat or increasing after a few epochs, most likely your dataset is too
small or too repetitive (try more source photos, or more `--variants`).

This step is a real training run — expect it to take a few minutes on
Apple Silicon (MPS), longer on Intel Macs (CPU only). If `Using device: mps`
doesn't print, training will still work, just slower.

## 4. Convert to Core ML

```bash
python3 convert_to_coreml.py --model quality_model_traced.pt --output LensCheckQuality.mlpackage
```

Produces `LensCheckQuality.mlpackage`.

## 5. Bring it into Xcode

1. Drag `LensCheckQuality.mlpackage` into your Xcode project (drop it into
   the `LensCheck` group, next to `Services/`). Check "Copy items if
   needed" and the LensCheck target checkbox.
2. Build once (Cmd+B) — Xcode auto-generates a Swift class named
   `LensCheckQuality` from the model.
3. Replace `Services/CoreMLQualityAnalyzer.swift` with the updated version
   (provided separately) that actually calls this model.
4. In `ViewModels/QualityViewModel.swift`, change the default analyzer from
   `HeuristicQualityAnalyzer()` to `CoreMLQualityAnalyzer()`.
5. Build and run. Try the same test photos you used with the heuristic
   version and compare scores.

## If something looks off

- **Scores look random/nonsensical:** double-check the `scale`/`bias` in
  `convert_to_coreml.py` actually match how `train_model.py` normalizes
  (currently: raw 0-1 float input, normalization baked into the model).
  A mismatch here is the most common source of silently-wrong predictions.
- **Model always predicts near the same value regardless of input:** usually
  means the dataset lacked variety — check `manifest.csv` has a real spread
  of scores, not values clustered in one range.
- **Xcode can't find `LensCheckQuality` class:** build (Cmd+B) again after
  adding the `.mlpackage` — the generated class only appears after a build.
