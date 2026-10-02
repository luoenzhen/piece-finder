# PieceFinder

A native Flutter app for finding jigsaw pieces against a photographed puzzle reference. The full product scope is in [docs/PRD.md](docs/PRD.md).

## Current development build

Implemented: camera/gallery capture, four-corner perspective calibration, editable grid dimensions, SQLite puzzle library, offline CPU reference matching across four rotations, three candidate results with similarity scores, scan history, rolling 24-hour quota, and a pan/zoom board with persistent placements and undo.

The matcher is an experimental Dart reference implementation. It requires one piece on contrasting paper, viewed straight down with its body axes aligned to the camera frame. Similarity scores are not calibrated probabilities. Synthetic tests do not establish real-puzzle accuracy.

**Not yet complete:** native OpenCV/C++/FFI engine, live contour/box detection and automatic capture, arbitrary piece deskew, connector classification/pruning, tray edge sorting, corner loupe, barcode catalog lookup, real subscriptions, synchronization semantics, supported glare processing, and real-photo accuracy/performance benchmarks. The user has installed the development IPA through AltStore on an iPhone; full device acceptance testing remains pending. See [development gates](docs/DEVELOPMENT.md).

## Develop and test

Pinned toolchain: Flutter **3.47.5**, Dart **3.13.4**. The dependency lockfile is checked in.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
flutter run
```

The local Windows SDK is ignored under `.tooling/flutter`. To use it from PowerShell:

```powershell
$env:PUB_CACHE = Join-Path $PWD '.tooling\pub-cache'
.\.tooling\flutter\bin\flutter.bat test --reporter expanded
```

Tests cover known piece placement and rotations, tab/socket segmentation, low-texture ambiguity, invalid inputs, perspective calibration, SQLite reopening/deletion, quota boundaries, compact-screen layout, and candidate placement/undo. Synthetic 500/1000-piece timing output is written to `.artifacts/reference-benchmark.json`; dashboard rendering is written to `.artifacts/dashboard.png`. Both are host-test artifacts, not iPhone validation.

## iPhone builds without a Mac

Version 0.1.1 fixes artwork corner dragging: each corner has a full 48-pixel touch target inside the editor, and dragging uses stable pointer coordinates. The regression test covers all four corners, including edge touches and direction changes.

The [GitHub Actions workflow](.github/workflows/ios.yml) runs checks on a hosted Mac, builds a simulator app and an unsigned arm64 release, then packages `PieceFinder-unsigned.ipa` for personal signing. Successful Windows tests do not prove that workflow passes.

Follow [docs/IPHONE.md](docs/IPHONE.md) for the Windows/AltStore Classic personal-testing path and the separate Apple Developer/TestFlight path. An unsigned IPA is not directly installable. No Apple signing credentials belong in this repository.

## Test in your browser

On this Windows project, run:

```powershell
cd D:\projects\test\piece-finder
.\scripts\run_browser.ps1
```

Open **http://localhost:8080** in Chrome or Edge when the server says it is ready. Keep the terminal open. Press Ctrl+C to stop it. On another computer with Flutter 3.47.5 installed, run `flutter pub get` then `flutter run -d chrome --web-port 8080` from the project root.

Try **New puzzle → Choose a photo**, drag each numbered corner, enter a name, confirm rows/columns, and create the puzzle. Reload the browser and confirm the puzzle and photo are still present. **Find a piece → Import photo** lets you test matching without a webcam. Camera access requires permission and either localhost or HTTPS.

Browser photos and puzzle state live in that browser's local IndexedDB storage, separately from your iPhone. Use the same URL and port to revisit them; clearing site data removes them. The web matcher currently runs on the browser's main thread and can briefly pause the interface for larger puzzles. Use JPEG/PNG images; camera format support differs by browser.

GitHub Actions also produces a `PieceFinder-browser` artifact. Its extracted contents must be served by an HTTP server; opening `index.html` directly as a file will not work. The workflow builds this artifact but does not publish a public website.

## Project layout

- `lib/vision.dart`: CPU algorithm prototype and perspective rectification.
- `lib/repository.dart`: SQLite projects, placements, scan history and atomic quota updates.
- `lib/models.dart`: puzzle, grid, candidate and quota data.
- `lib/capture.dart`, `setup.dart`, `dashboard.dart`, `board.dart`: mobile UI.
- `ios/`, `android/`: generated native projects plus permission declarations.
- `test/`: deterministic image, persistence and UI checks; test fonts retain their license notices.

Photos are stored in app support storage and matching runs locally. No telemetry, server upload, catalog account or billing account is configured.
