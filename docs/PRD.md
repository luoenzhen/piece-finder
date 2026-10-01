# PieceFinder: Product Specification & Requirements Document (PRD)

---

## 1. Executive Summary & Vision

**PieceFinder** is an on-device computer vision (CV) mobile assistant for jigsaw puzzle enthusiasts. When a player encounters difficult sections (such as uniform skies, water, dense gradients, or foliage), they place an individual puzzle piece under their phone's camera.

The app segments the piece, analyzes its tab/blank geometry, extracts its color and texture features, and highlights its exact coordinate and orientation ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) on a digital reference image of the puzzle box.

---

## 2. Technology Stack & System Architecture

The application adopts a **hybrid on-device architecture** to eliminate cloud compute costs, enable offline play, and maintain low latency ($\le 1.2\text{s}$ per scan).

| Layer | Technology | Primary Responsibility |
| --- | --- | --- |
| **Cross-Platform UI** | **Dart / Flutter** | Camera preview, target reticle HUD, pinch-to-zoom canvas, animations, settings. |
| **Computer Vision Engine** | **C++ (OpenCV)** | Contour detection, perspective warp, edge classification (tabs/blanks), template matching. |
| **Bridge Layer** | **Dart FFI** | Zero-copy byte buffer passing between Flutter's camera stream and the C++ engine. |
| **Local Storage** | **SQLite (drift / sqflite)** | Saved puzzle projects, metadata, feature pyramid caches, and scan history. |
| **Monetization & Billing** | **StoreKit 2 / Google Play Billing** | In-app subscriptions and paywall entitlement management. |

---

## 3. Core Feature List

### 3.1. Reference Ingestion & Calibration (Setup Phase)

* **Box Cover Camera Capture:** Interactive viewfinder with real-time quadrilateral edge detection for straight-on alignment.
* **Auto-Perspective Rectification:** 4-point perspective warp in C++ to flatten skewed box photographs into standard rectangular maps.
* **Manual Corner Tuning:** 4-point pin adjustment interface with a 2x magnification loupe for sub-pixel boundary cropping.
* **Barcode / Catalog Fetch (UPC Scan):** Optional barcode scanner to query digital publisher box art, bypassing physical camera glare entirely.
* **Grid Dimension Configuration:** User-selected piece counts (e.g., 300, 500, 1000, 1500, 2000) to parameterize search resolution.

### 3.2. Piece Scanning & Geometry Extraction (Solving Phase)

* **HUD Scanner Viewfinder:** High-contrast targeting reticle optimized for one-handed operation.
* **Contour Segmentation:** Adaptive thresholding (Otsu) isolating individual pieces from neutral/contrasting backgrounds (mats, tabletops, paper).
* **Interlocking Connector Profiling:** Convexity defect and curvature analysis to classify all 4 sides into **Tabs** (male connectors), **Blanks** (female sockets), or **Flat** (puzzle borders).
* **Multi-Piece Border Filter:** Tray scan mode that outlines and tags all flat-edge border pieces simultaneously.

### 3.3. Matching Engine & Result Display

* **Hybrid Matching Algorithm:**
1. *Geometric Pruning:* Eliminates candidate grid locations that do not match the piece's connector profile.
2. *Color & Gradient Distribution:* Normalized Cross-Correlation (NCC) across regional feature pyramids.
3. *Rotation Normalization:* Matches across $0^\circ, 90^\circ, 180^\circ,$ and $270^\circ$ transformations to determine exact board orientation.


* **Match Result Overlay:** Slide-up modal displaying a cropped section of the box art with a pulsating halo over the target slot.
* **Directional Indicator:** Step-by-step rotation arrow indicating how the physical piece must be turned.
* **Confidence Rating & Multi-Candidate Handling:** Displays single pinpoint coordinate for high confidence ($\ge 80\%$); highlights top 3 candidate zones with connector hints for low-texture/solid-color pieces ($< 80\%$).
* **Interactive Full Board Minimap:** 8x pinch-to-zoom board viewer with toggles for grid lines and completed piece tags.

### 3.4. Account, Monetization & Utilities

* **Freemium Quota Engine:** Local counter tracking 5 free piece lookups per 24-hour cycle.
* **Pro Entitlements:** Unlimited scans, unlimited active puzzle projects, and offline database synchronization.
* **Camera Glare Filter:** Software-based polar-difference shader toggle to suppress ceiling light reflections on glossy puzzle pieces.
* **Haptic Feedback:** Success/failure tactile feedback on piece lock and match resolution.

---

## 4. Screen-by-Screen Specification

```
[ App Launch ] ──► [ 1. Dashboard ] ──┬──► [ 2. Box Ingestion ] ──► [ 3. Box Calibration ]
                                      │                                      │
                                      ▼                                      ▼
                             [ 4. Scanner HUD ] ◄────────────────────────────┘
                                      │
                                      ├──► [ 5. Match Result Overlay ]
                                      │
                                      └──► [ 6. Interactive Board View ]

```

### Screen 1: Dashboard ("My Puzzles")

* **Elements:** Active puzzle card (preview thumbnail, progress metric, direct "Resume Scan" CTA), past puzzle list, "+ New Puzzle" button, daily scan quota badge, Settings gear icon.
* **Interactions:** Tap active project card to launch Scanner HUD immediately; tap "+" to trigger the ingestion flow.

### Screen 2: Box Art Ingestion

* **Elements:** Full-screen camera preview, green alignment boundary overlay, torch toggle, shutter button, gallery photo import button, barcode scanner toggle.
* **Interactions:** Auto-captures when perspective stability is held for 1.5 seconds, or manual shutter press.

### Screen 3: Box Crop & Grid Calibration

* **Elements:** Rectified box preview, 4 draggable corner pins with magnification loupes, piece count selector chips (`[300]`, `[500]`, `[1000]`, `[2000]`), aspect ratio readout, "Confirm" CTA.
* **Interactions:** Drag pins to rectify border margins; tap piece count to compute search cell sizes.

### Screen 4: Scanner HUD

* **Elements:** Live camera viewport, center targeting reticle (white when empty, cyan when piece contour is locked), top mini-map preview, one-handed shutter trigger, mode toggle (Single Piece vs. Edge Sorter), flashlight toggle.
* **Interactions:** Tap shutter or hold steady inside reticle to invoke C++ feature-matching pipeline.

### Screen 5: Match Result Overlay

* **Elements:** Slide-up sheet, cropped surrounding box art region with highlighted target pin, row/column estimate, orientation badge (e.g., "Rotate 90° CW"), confidence score bar, "Next Scan" primary button, "View on Board" secondary button.
* **Interactions:** Tap "Next Scan" to dismiss modal and re-engage shutter in $< 0.2\text{s}$.

### Screen 6: Interactive Board View

* **Elements:** High-res pan/zoom canvas of the entire box art, coordinate crosshair overlay, quadrant indicator (e.g., "Sector B - Top Right"), "Mark as Placed" toggle button.
* **Interactions:** Pinch-to-zoom up to 8x; double-tap to re-center on the last-scanned coordinate.

---

## 5. Non-Functional Requirements & Performance Targets

* **Scan-to-Result Latency:** $\le 1.2$ seconds on modern mid-range devices (iPhone 12 / Samsung Galaxy S21 or newer).
* **Accuracy Benchmarks:**
* Textured / Illustrated Pieces: $\ge 92\%$ accuracy on top-1 recommendation.
* Solid / Monochrome Pieces (e.g., clear sky): $\ge 70\%$ accuracy on top-3 recommendations using geometric tab/blank constraints.


* **Memory & Storage Footprint:**
* Compiled app binary size: $\le 65\text{ MB}$.
* Cache budget per puzzle: $\le 15\text{ MB}$ (box art + pre-computed feature representations).


* **Zero Cloud Dependency:** Core image recognition and piece matching operate completely on-device without network connectivity.

---

## 6. Development Roadmap

```
Phase 1: Proof of Concept & Algorithm (Weeks 1–3)
├── Prototype Python scripts for Otsu segmentation and contour classification
├── Homography rectification and feature pyramid template matching
└── Validate against a test benchmark of 500- and 1,000-piece photo sets

Phase 2: Engine Port & FFI Integration (Weeks 4–6)
├── Transcribe CV pipeline into optimized C++ (OpenCV Mobile build)
├── Set up Dart FFI bindings to pass image buffers with zero-copy overhead
└── Benchmark latency and memory usage on physical iOS and Android devices

Phase 3: Flutter UI & Camera Pipeline (Weeks 7–9)
├── Build responsive camera HUD with real-time reticle shaders
├── Implement interactive pan/zoom canvas and Loupe adjustment widgets
└── Implement local SQLite database schema for project state

Phase 4: Monetization & Store Launch (Weeks 10–12)
├── Integrate StoreKit 2 and Google Play Billing paywalls
├── Edge case optimization (glare reduction, low-light handling)
└── TestFlight and Google Play Open Testing distribution

```

---