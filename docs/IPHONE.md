# iPhone installation from Windows

The owner has a Windows PC, an iPhone and GitHub, but no Mac or Apple Developer Program membership. This project is a native Flutter app. Windows cannot run Xcode. The checked-in GitHub Actions workflow uses a hosted Mac for verification and compilation.

## Personal device testing

1. Put this project in a GitHub repository, excluding `.tooling`, build outputs and credentials. The root `.gitignore` already excludes these. The user selected `https://github.com/luoenzhen/piece-finder` for the cloud build. Check its current workflow run before downloading an artifact.
2. Open Actions → **Verify and build iPhone app** → Run workflow. It runs tests, builds for the simulator, and builds an unsigned arm64 iOS release. Inspect the actual run before claiming an iOS build succeeded.
3. Download the `PieceFinder-personal-signing` artifact and extract `PieceFinder-unsigned.ipa`. An unsigned IPA does **not** install directly on an iPhone.
4. Install AltStore **Classic** using the official [Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). Follow its current iTunes/iCloud, device trust and Developer Mode instructions. Enter Apple account credentials only in that local signing tool; never in source, CI variables, or this chat.
5. Use AltStore's IPA import to sign and install the downloaded app with your own Apple account. Keep AltServer available for refreshes. Free-account apps [expire after seven days](https://faq.altstore.io/altstore-classic/your-altstore) unless refreshed. This personal-signing path is prepared but has not been tested with this app or the user's device.

GitHub Actions availability and hosted macOS minutes depend on your account/repository. This document does not authorize purchasing a service or enrolling in a paid plan.

## TestFlight / distribution

TestFlight is an alternative once Apple Developer Program enrollment is available. Register an owned bundle ID, select a signing team, create the App Store Connect app record, and configure signing credentials in a trusted build service. The generated `com.piecefinder.pieceFinder` ID is a development placeholder, not a claim of registration or ownership. See [Flutter's iOS release guide](https://docs.flutter.dev/deployment/ios).

No signing identity, profile, subscription product, developer team or TestFlight build exists in this project yet. Do not commit Apple private keys or passwords. App Store distribution requires the remaining PRD work and validation, not just successful packaging.

## Physical-device acceptance (not yet run)

- Install and launch on the actual iPhone; record device model, iOS version, build identifier and installation method.
- Grant/deny camera and photo access. Recover after denial, app backgrounding, phone lock, and gallery cancellation without a crash or camera lock.
- Capture/import artwork, tune all corners, confirm real rows and columns, restart the app and reopen the saved puzzle.
- Scan actual textured and solid-color pieces in all four quarter-turn orientations. Verify coordinates against labeled ground truth. Record errors rather than accepting visual similarity as calibrated confidence.
- Compare all candidates on the board, pan/zoom, mark/undo placement, reopen and confirm persistence.
- Turn off networking and repeat reference import, matching and persistence.
- Test the 24-hour quota boundary, storage failures and corrupted/unsupported images.
- Run the PRD's accuracy, latency, memory, cache and app-size benchmarks on its specified device class before declaring those targets met.

Additional feature acceptance is tracked in [DEVELOPMENT.md](DEVELOPMENT.md) against the [PRD](PRD.md).
