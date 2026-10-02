# PieceFinder development record

## Goal

Implement the complete [PRD](PRD.md), test it, and verify the native app on an iPhone. The user has an iPhone but no Mac. A hosted macOS build and Apple signing path are needed; a Windows test run or an unsigned archive does not prove iPhone operation.

## Implementation sequence and verification gates

1. Flutter mobile project, SQLite persistence, reference calibration, capture, results and board. Verify with analyzer, unit tests and widget tests.
2. On-device matching prototype with known-position/rotation image fixtures, ambiguous-image handling and segmentation. Verify coordinate and rotation recovery; do not present correlation as calibrated probability.
3. OpenCV/C++ engine through Dart FFI, connector profiling, reference feature cache and camera buffer integration. Compare output with prototype fixtures and measure latency/memory on devices.
4. Full PRD interaction and utility coverage: live quadrilateral detection, stable auto-capture, loupe, barcode/catalog ingestion, tray edge sorting, history and quota. Test failure, lifecycle and recovery paths.
5. Real billing and entitlement restoration, supported glare handling, performance/accuracy evaluation and signed iOS distribution. Test purchases in the sandbox and install/run through TestFlight on the user's iPhone.

The sequence is incremental; no intermediate gate redefines completion.

## Engineering assumptions requiring validation

- Box artwork contains no internal cut topology. Connector pruning at arbitrary slots needs a cut map or known neighboring pieces. Border constraints can be applied without one.
- Piece counts and image aspect ratio only estimate grid dimensions. Let users confirm actual rows/columns; nonrectangular/irregular cuts need separate support.
- Matching score is not a calibrated accuracy percentage. Until evaluated against labeled photographs, show candidate similarity and ambiguity explicitly.
- Software cannot reconstruct clipped glare detail or polarization from an ordinary single camera image. Evaluate available exposures/hardware before claiming polar-difference filtering.
- Catalog provider, synchronization semantics, Apple developer enrollment, app identity, and subscription products are not configured.

## Source of truth

Use current source and test output for implementation status. The PRD is the scope authority. Device acceptance requires real photographs from 500/1000-piece puzzles, labels, measured timing and memory, and physical iPhone testing. The user confirmed installation through AltStore and reported artwork corner dragging failed. Version 0.1.1 addresses that report with a regression test; confirmation on the physical iPhone is still needed. Labeled photographs and device benchmarks have not been supplied.

## Updated product decision (2026-10-02)

The user explicitly removed the five-scan allowance: scanning is unlimited, without a subscription gate. This supersedes quota and monetization requirements in the original PRD and earlier sequence above. Existing quota records are ignored; puzzle and scan history data remain intact.
