# LensCheck

An on-device iOS app that scores photos for sharpness and exposure, and keeps a local history of every check — no server, no upload, everything runs on-device. Includes two swappable analyzers: a fast Core Image heuristic and a trained Core ML model, both conforming to the same protocol.

## What it does

- Pick a photo from your library
- Get an instant sharpness + exposure score (0–100 each), computed entirely on-device
- Every check is saved automatically, with a history view to browse past results, tagged with which analyzer produced it
- No network calls — built entirely on first-party Apple frameworks plus one custom-trained model

## Two analyzers, one protocol

- **Heuristic (`heuristic-v1`)** — Core Image edge-detection convolution for sharpness, histogram-based brightness analysis for exposure. No trained model required.
- **Core ML (`coreml-v1`)** — a MobileNetV3-Small-based regression model, trained on a synthetically-degraded dataset generated from personal photos, converted to Core ML and run on-device via Vision.

Both conform to the same `QualityAnalyzing` protocol, so switching which one the app uses is a one-line change in `QualityViewModel`'s initializer — nothing else in the app needs to know or care.

## Architecture

```
LensCheck/
├── LensCheckApp.swift          — app entry point, sets up SwiftData
├── Models/
│   └── QualityResult.swift     — SwiftData model, one row per saved check
├── Services/
│   ├── QualityAnalyzing.swift        — protocol + QualityScore type
│   ├── HeuristicQualityAnalyzer.swift — Core Image, no ML model needed
│   └── CoreMLQualityAnalyzer.swift    — runs the trained Core ML model via Vision
├── ViewModels/
│   └── QualityViewModel.swift  — app state, calls the analyzer, saves results
└── Views/
    ├── ContentView.swift       — tab navigation
    ├── CaptureView.swift       — pick a photo, see live score
    ├── ResultCardView.swift    — reusable score display
    └── HistoryView.swift       — past results, backed by @Query

lenscheck-ml/
├── generate_dataset.py     — synthetic dataset generation from clean photos
├── train_model.py          — trains the MobileNetV3-based regression model
├── convert_to_coreml.py    — converts the trained model to .mlpackage
├── quality_model_traced.pt — the traced PyTorch model
├── LensCheckQuality.mlpackage — the converted Core ML model
└── PIPELINE.md             — step-by-step instructions for the above
```

**MVVM throughout:** views never touch the analyzer or persistence directly — they go through `QualityViewModel`, which is the only thing that talks to `QualityAnalyzing` and SwiftData.

## Tech stack

- SwiftUI, iOS 17+
- SwiftData for persistence
- Core Image for the heuristic analyzer
- PyTorch + coremltools for training and converting the Core ML model
- Vision + Core ML for on-device inference
- XCTest for unit tests

## Getting started

**Requirements:** Xcode 16+, iOS 17+ deployment target. No Apple Developer account needed to run on the simulator.

```bash
git clone https://github.com/m-zaid-mac/LensCheck.git
cd LensCheck
open LensCheck.xcodeproj
```

Pick a simulator, press ⌘R. Drag any photo from Finder onto the running simulator window to add it to the simulator's Photos app, then tap **Choose Photo** in LensCheck.

To retrain or regenerate the Core ML model yourself, see `lenscheck-ml/PIPELINE.md`.

## Testing

Run with ⌘U, or:

```bash
xcodebuild test -project LensCheck.xcodeproj -scheme LensCheck -destination 'platform=iOS Simulator,name=iPhone 17'
```

Unit tests in `LensCheckTests/HeuristicQualityAnalyzerTests.swift` cover the heuristic analyzer's scoring logic against known fixtures. Writing these caught a real bug: Core Image performs its internal math in *linear* light, not gamma-encoded sRGB, so an unmarked color-space conversion was silently making every exposure reading read darker than it should. Fixed by explicitly specifying an sRGB color space when rendering the brightness sample back out.

## Roadmap

- ~~Core ML v2~~ — **shipped.** See `lenscheck-ml/` for the full training pipeline.
- **Camera capture** — shoot photos directly instead of only picking from the library
- **Score trends over time** — Swift Charts view showing quality scores across a photo library or shooting session
- **Video support** — extend scoring to frames sampled from video, not just static photos

## Author

**Mohammad Zaid**

- GitHub: [@m-zaid-mac](https://github.com/m-zaid-mac)
- LinkedIn: [mohammad-zaid](https://www.linkedin.com/in/mohammad-zaid-6a360b276/)
- Email: zaid.m@northeastern.edu

