# LensCheck

An on-device iOS app that scores photos for sharpness and exposure, and keeps a local history of every check — no server, no upload, everything runs on-device.

Built as a companion to a Python/OpenCV video-quality-assessment project: same domain (image/video quality analysis), different platform. One shows the analysis pipeline on desktop; this one shows the same problem shipped as a native, on-device mobile experience.

## What it does

- Pick a photo from your library
- Get an instant sharpness + exposure score (0–100 each), computed entirely on-device
- Every check is saved automatically, with a history view to browse past results
- No network calls, no third-party dependencies — built entirely on first-party Apple frameworks

## Why on-device heuristics instead of a cloud API

Quality assessment here runs through classic Core Image techniques — an edge-detection convolution for sharpness, histogram-based brightness analysis for exposure — rather than calling out to a server. That means results are instant, work offline, and never leave the device. See [Roadmap](#roadmap) for where a Core ML model fits in as a v2 upgrade.

## Architecture

```
LensCheck/
├── LensCheckApp.swift          — app entry point, sets up SwiftData
├── Models/
│   └── QualityResult.swift     — SwiftData model, one row per saved check
├── Services/
│   ├── QualityAnalyzing.swift        — protocol + QualityScore type
│   ├── HeuristicQualityAnalyzer.swift — v1: Core Image, no ML model needed
│   └── CoreMLQualityAnalyzer.swift    — v2 stub: where a Core ML model plugs in
├── ViewModels/
│   └── QualityViewModel.swift  — app state, calls the analyzer, saves results
└── Views/
    ├── ContentView.swift       — tab navigation
    ├── CaptureView.swift       — pick a photo, see live score
    ├── ResultCardView.swift    — reusable score display
    └── HistoryView.swift       — past results, backed by @Query
```

**MVVM throughout:** views never touch the analyzer or persistence directly — they go through `QualityViewModel`, which is the only thing that talks to `QualityAnalyzing` and SwiftData.

**Protocol-based analyzer:** `HeuristicQualityAnalyzer` and `CoreMLQualityAnalyzer` both conform to `QualityAnalyzing`. Swapping which one the app uses is a one-line change in `QualityViewModel`'s initializer — nothing else in the app needs to know or care.

## Tech stack

- SwiftUI, iOS 17+
- SwiftData for persistence
- Core Image for on-device analysis (v1)
- Vision + Core ML, planned for v2 (see [Roadmap](#roadmap))
- XCTest for unit tests

## Getting started

**Requirements:** Xcode 16+, iOS 17+ deployment target, macOS with Xcode installed. No Apple Developer account needed to run on the simulator.

```bash
git clone https://github.com/m-zaid-mac/LensCheck.git
cd LensCheck
open LensCheck.xcodeproj
```

Then in Xcode: pick a simulator from the device dropdown, and press ⌘R.

To try it out, drag any photo from Finder onto the running simulator window — that adds it to the simulator's Photos app — then tap **Choose Photo** in LensCheck.

## Testing

Run the test suite with ⌘U, or:

```bash
xcodebuild test -project LensCheck.xcodeproj -scheme LensCheck -destination 'platform=iOS Simulator,name=iPhone 17'
```

Unit tests in `LensCheckTests/HeuristicQualityAnalyzerTests.swift` cover the analyzer's scoring logic against known fixtures (flat colors, solid gray, black). Writing these actually caught a real bug: Core Image performs its internal math in *linear* light, not gamma-encoded sRGB, so an unmarked color-space conversion was silently making every exposure reading read darker than it should. Fixed by explicitly specifying an sRGB color space when rendering the brightness sample back out — see the git history for the before/after.

## Roadmap

- **Core ML v2** — convert a small, transfer-learned quality-assessment model with `coremltools`, drop it into `CoreMLQualityAnalyzer`, and swap it in via `QualityViewModel`'s initializer
- **Camera capture** — shoot photos directly instead of only picking from the library
- **Score trends over time** — Swift Charts view showing quality scores across a photo library or shooting session
- **Video support** — extend scoring to frames sampled from video, tying back into the desktop video-quality-assessment project this one pairs with

## Author

**Mohammad Zaid**

- GitHub: [@m-zaid-mac](https://github.com/m-zaid-mac)
- LinkedIn: [mohammad-zaid](https://www.linkedin.com/in/mohammad-zaid-6a360b276/)
- Email: zaid.m@northeastern.edu

