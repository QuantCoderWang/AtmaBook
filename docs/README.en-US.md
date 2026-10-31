# AtmaBook — Offline Travel Guide Mapbook & Geo Photo Collection

> An offline-first Flutter travel guide application with the map as its primary canvas: mark places to visit with photos and text, automatically cluster "must-visit" points into touring areas with recommended routes, lay GPS-tagged photos and videos into a geo album, and package any guide into a single file to share with others or keep as a permanent backup.
> **All data resides exclusively on the local machine — no servers, no accounts.**

![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Android-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.47%20stable-02569B?logo=flutter) ![Tests](https://img.shields.io/badge/flutter_test-114%20tests%20passed-brightgreen) ![i18n](https://img.shields.io/badge/languages-%E4%B8%AD%E6%96%87%20%2F%20English-green)

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Design Philosophy](#2-design-philosophy)
- [3. Feature Set](#3-feature-set)
- [4. Architecture](#4-architecture)
- [5. Key Technical Points](#5-key-technical-points)
- [6. Development Challenges and Resolutions](#6-development-challenges-and-resolutions)
- [7. Data and Privacy Constraints](#7-data-and-privacy-constraints)
- [8. Build and Run](#8-build-and-run)
- [9. Repository Layout](#9-repository-layout)
- [10. Quality Baseline and Testing](#10-quality-baseline-and-testing)
- [11. Internationalization](#11-internationalization)
- [12. AI-Assisted Development](#12-ai-assisted-development)
- [13. License](#13-license)

---

## 1. Overview

AtmaBook addresses three real-world scenarios:

| Scenario | Description |
| --- | --- |
| **Trip planning** | Places you want to visit (sights / dining / shopping / lodging / transit) are marked on a map canvas. The system automatically clusters "must-visit" points into touring areas and generates recommended touring routes, decomposing the sights of a target city into several "touring areas". |
| **Itinerary organization** | "Guide Notes" re-renders a guide on the fly into a readable itinerary document: lodging as the starting point, areas ordered by distance, photos and coordinates all clickable for navigation — a purely derived view with zero extra storage. |
| **Post-trip archiving and sharing** | After the trip, GPS-tagged photos and videos (note: turn on GPS when taking photos; items without coordinates can also be annotated manually later) are automatically filed into the geo album and pinned back onto the map. Any guide can be packaged into a single `.tgshare` file to send to friends (one-tap import on the receiving side) or kept as a permanent backup. |

The application is a **serverless (offline-first) Flutter application**: all business data (guide JSON, images, videos, offline tiles) lives inside the application data directory, and the data can be backed up and migrated as a whole.

**Delivered platforms**: the Windows desktop version and the Android version are the packaged applications delivered so far; iOS / Linux / Web are pre-wired scaffolding (iOS / Linux builds must be performed on their respective operating systems — I have not built them; build them yourself if needed; the Web version serves as a preview during development).

## 2. Design Philosophy

1. **Data sovereignty first.** Guides, photos, and videos belong to the user. The application sets up no cloud services: a write lands immediately on local disk, an export produces standard formats (JSON plus ordinary image/video files), and uninstalling leaves no residual dependencies.
2. **Offline is the primary path, not a fallback.** From the offline tile download wizard and the offline tile provider, through pure-Dart EXIF parsing, clustering and route algorithms, the core capabilities work fully without connectivity; online capabilities (online basemaps, geocoding, road-network routing) are pluggable enhancements.
3. **Natural fusion of photos and geography.** Photo EXIF (GPS + capture time) and marker coordinates turn "where I went" into queryable, visualizable data; videos are registered via first-frame thumbnail and capture time, sharing the same logic as photos.
4. **Strict separation of sharing and copy semantics.** Shared artifacts are downgraded, watermarked copies (sharing a degraded copy is optional); local originals are never affected. Everything imported is an independent copy with fully remapped identifiers and zero conflicts with existing data.
5. **The interface is a notebook.** List / grid / map / album / itinerary-notes views present the information mass of a single trip in its most intuitive form, rather than a single database-centric view.

## 3. Feature Set

### 3.1 Guide Management

- Notebook-style home page: guide cards (cover / title / marker count / update time) with list and grid layouts and title/summary search;
- AppBar quick actions: search / **geo album** (its own icon entry) / ☰ menu drawer;
- Guide creation wizard (basics → area lookup): keyword search for cities and places (Nominatim, keyless / optional AMap key), automatic domestic/abroad detection with a basemap recommendation, lookup results cross-referenced with existing offline tile packs (use directly, or one-tap download when missing);
- Guide info editing (title / summary / cover image) and full deletion (with image-file cleanup).

### 3.2 Map and Markers

- Rendered with `flutter_map`; multiple switchable basemap sources: AMap vector / AMap satellite / Esri streets / terrain / light-gray / satellite (all keyless), OSM, Tianditu, and offline tile packs;
- Long-press the map to add markers (six preset categories — sights / dining / shopping / lodging / transit / other — with customizable colors and icons); tapping a marker opens a photo/text detail sheet with navigation hand-off;
- Dual marker-style system: icon Pins (default) and colored pushpins, switched globally; both styles support must-visit stars, zone color rings, and custom icons;
- Marker list drawer: filter and sort by category / zone, one-tap locate.

### 3.3 Touring Areas and Routes

- **DBSCAN** clusters "must-visit" markers into areas (radius 1–20 km and minimum points adjustable on the settings page); isolated markers form their own areas; overlapping areas are **automatically resolved** (the primary area keeps its extent, secondary areas shrink their radius, minimum floor 400 m);
- Intra-area routes: an open-path TSP heuristic of nearest-neighbor construction plus **2-opt** iterative improvement; online, routes are snapped to the real road network via **OSRM** (keyless demo service); offline / on failure, dashed straight lines are shown instead;
- Area colors are sampled evenly on the HSV hue ring and stay in sync across the legend, pin rings, and route lines.

### 3.4 Offline Maps

- Three-stage download wizard: corner-to-corner rectangle on the map → zoom-level range → count estimate (double-confirm above threshold) → concurrent download (4 workers, 2 retries, UA header, throttling, resume via skip-existing on any interruption, immediately effective cancel token);
- A pre-download **connectivity probe** (a single-tile measurement) validates source reachability and latency;
- Offline management page: measured pack sizes, local tile counts, one-tap deletion (with files);
- The `OfflineTileProvider` renderer: local hit first → online fallback → plain gray block in pure-offline mode, with `ImageCache` reuse to avoid duplicate decoding.

### 3.5 Geo Album (Photos + Videos)

- Dual-source aggregation: photos inside guides (`g:` entries) and the global ledger (`w:` entries) merged and deduplicated, with a sampling cap by capture time (default 200; 20–500 configurable);
- **Whiteboard geo wall**: located photos are greedily clustered (≤150 m) and stacked around cluster centers with deterministic pseudo-random offsets and 0–45° tilts; a year slider spans all years (the layout is reproducible on the same seed, used for per-year export);
- **Album library**: a ledger of all entries (newest first, video entries show duration), supporting per-entry geo write/rewrite (pick on a map), guide reassignment, **display removal (the original file is kept and can be restored at any time)**, and deletion;
- Import chain: EXIF whitelist parsing → content-hash deduplication → original-file storage → thumbnail generation → nearest-guide assignment (≤5 km) → ledger commit; three entry points: batch picker / curated selection (per-photo multi-select) / folder auto-scan;
- **Video insertion** (via the geo album entry only): streaming hash (FNV-1a sampling) and streaming copy handle large files; ffprobe reads the duration and ffmpeg extracts a first frame for the thumbnail (note: third-party plugins are required); after registration, the location is written manually in the viewer, after which videos behave identically to photos.

### 3.6 Guide Notes (auto-generated)

- A purely derived view: no new storage, no manual entry; everything is extracted live from the guide's existing data on open;
- Composition logic: multi-stay selection of the tour origin → a "This stay · tour start" card → areas ordered by distance to the origin → a per-area range badge (configured radius + actual covered area) → a list of sights with must-visits first → in-area dining / shopping recommendations → remaining recommendations laid flat;
- Guides without "must-visit" markers fall back to a category-flat view (stays on top) with an onboarding hint;
- Every coordinate is clickable for navigation (desktop map hand-off defaults to AMap · transit).

### 3.7 Share and Import (.tgshare)

- A single-file ZIP container: `manifest.json` / `guide.json` / `cover.*` / `photos/` / `thumbs/` / `images/`, plus `videos/` and `videos.json`; readers accept packs from older format revisions;
- Two packaging modes (branch selector in the export sheet):
  - **Watermarked copy** (default): optional photo inclusion with a live size estimate; all exported images (including covers) are scaled to low-quality JPEGs with a **tiled burned-in watermark**; videos are transcoded to ≤720p H.264 with a diagonal watermark;
  - **Original quality**: photos, marker images, cover, and videos are packed as **original bytes** (no resizing, no transcoding, no watermark) — works **without FFmpeg**; the package is capped at **1 GB**, and over the cap the UI prompts "remove some photos or lower the photo quality", with item filtering and two degrade tiers (long side 2048·q85 / 1080·q80; the copies exist only inside the package, originals stay read-only, and temp copies are deleted once packing completes); **geo-album photos/videos are included too** (media attached to a guide via `guideId` is injected into the share chain, saved through guide.json, deduplicated by id); the item picker shows custom names or, when empty, the capture time (same convention as the photo viewer);
- Output: desktop writes to the Downloads folder; Web triggers a browser download (original mode is desktop/mobile only);
- Import: manifest validation → FNV-1a64 fingerprint deduplication (duplicates can be re-imported as independent copies) → **full ID remapping** (guide, markers, photos, and zone memberships all rewritten) → entry whitelist with path-traversal protection (rejecting `../`, absolute paths, drive letters) → commit flagged `shared` with a cover badge and "(Shared)" suffix;
- **Isolation policy**: photos and videos of `shared` guides never enter the user's own geo album; local edits are copy-semantics only. Guides imported from original packages carry `sharedOriginal` and **may be re-exported as originals** (the backup chain continues); watermarked guides can also be re-packed via the export sheet (the product remains a watermarked copy);
- **Full-export bundle**: the ☰ menu "Export all" packs **every guide one by one in original mode** (cover + marker images + guide photos + geo-album photos/videos, all passed through at full quality) into **a single `.tgbundle` package** (outer ZIP container with numbered inner `.tgshare` entries), with **no size cap** (the 1 GB cap applies to single original share packs only); import rides the same "Load share" entry, branch by file extension, streaming each inner pack (only one inner package in memory at a time); already-imported guides are **skipped automatically** by in-pack fingerprints, and the result is summarized as "imported n · duplicates m · failed z"; built for file migration and multi-device sharing (`docs/补充功能-全量导出包.md`).

### 3.8 Settings and i18n

- Global settings: marker style, clustering parameters, service keys (AMap Web key / Tianditu tk, optional), share watermark text, album folder, and sampling cap;
- **Category management**: the "Place Categories" card in settings — the six built-in categories support color and icon overrides; **custom categories** can be added, renamed, and deleted (markers referencing a deleted category fall back to "Other"); each category can carry a **1:1 image icon** (long side clamped to 512, square-only validation) integrated into the Pin icon system; individual markers can still override their own pin color and icon;
- **Interface language**: Chinese (default) / English / follow-system with instant switching; follow-system falls back to Chinese when the system locale is neither; 587 bilingual entries with the Material built-in strings mounted via the three delegates.

## 4. Architecture

```
lib/
├── main.dart / app.dart            entry, MaterialApp, localeResolution (I18nService sync point)
├── core/
│   ├── constants.dart              categories / basemap sources / path constants
│   ├── coord.dart  geo.dart        WGS-84↔GCJ-02, Haversine, tile x/y/z
│   ├── tile_math.dart              Mercator projection / area enumeration with GCJ
│   ├── wall_layout.dart            deterministic album-wall layout (pure functions, seeded)
│   ├── i18n_service.dart           service-layer string channel (static, context-free)
│   ├── i18n_names.dart             data-layer labels → display-name mapping helpers
│   └── io/                         StorageAdapter: desktop files / web fallback
├── data/
│   ├── models/                     Guide (Place, PhotoItem, ClusterZone, TilePack)
│   └── repos/                      guide / wall-photo / tile repositories (atomic write queue)
├── services/                       clustering / routes / palette / EXIF / tile downloader
│                                    share export-import / album import / video materialization / ffmpeg
├── state/                          GuidesProvider / editor state / AppSettings
├── ui/                             home / guide map / marker edit / tiles / album / settings / notes / share
└── l10n/                           app_zh.arb (template) / app_en.arb + gen_l10n output
```

On-disk layout (application data directory)

```
Application data directory/
├── guides/<guideId>.json           one JSON per guide (markers/photos/clusters)
├── guides_index.json               home index (avoids directory scans)
├── wall_photos.json                album ledger + yearly snapshots
├── pics/                           guide media / album originals & thumbs / videos/<hash>.mp4 / icons/
└── tiles/<packId>/{z}/{x}/{y}/     offline tiles + pack.json
```

## 5. Key Technical Points

1. **Three-layer coordinate discipline.** All persisted data (markers, photo EXIF, clusters, tile-pack extents) is stored in **WGS-84** decimal degrees. AMap tiles (GCJ-02) and Tianditu (CGCS-2000) are shifted at render time; the one-direction WGS84→GCJ02 offset has a round-trip error below 1 m, preventing point drift across basemaps. OSM/Esri tile math follows spherical Mercator directly; GCJ sources are converted before tile numbering.
2. **Deterministic layout algorithms.** Album-wall clustering, anchor grids, and member offsets are pure functions with a fixed seed: identical inputs reproduce identical outputs — guaranteeing preview/render consistency and enabling exportable yearly snapshots.
3. **Pure-Dart EXIF whitelist parsing** (`exif_gps.dart`): APP1 → TIFF (both byte orders) → GPS sub-IFD (DMS→decimal, S/W negation, range guards) plus DateTimeOriginal; malformed data safely returns empty with no native dependencies.
4. **Content-hash deduplication.** Photo originals and videos are stored under content-hash names (`pics/videos/v_<hash>.<ext>`); duplicate imports create no redundant files and are counted separately.
5. **Atomicity and consistency.** All JSON writes go through a write queue performing **atomic replacement** (temp file then rename); failed share imports roll back by deleting the half-written directory; ledger and yearly snapshots are committed in one transaction.
6. **Dual-channel i18n.** UI strings via `AppLocalizations.of(context)`; context-free service-layer strings (export progress, scan reports, download statistics) via `I18nService.t`, a static getter synchronized from the same locale by `localeResolutionCallback`. ARB placeholders are positional throughout.
7. **Dynamic viewport loading.** Album maps and photo walls compute the visible set per zoom bucket and viewport (with a 15% margin), merging clusters with a 64 px grid into count bubbles; the ledger refreshes once after its asynchronous load so initial frames are complete.
8. **Cross-platform degradation matrix.** Desktop uses the real file system; the Web build degrades to `shared_preferences` plus base64 (≤1 MB blobs, covers persist across sessions). Folder scanning ships in three conditional-import variants (IO / stub / registry). Video transcoding and first-frame extraction use the local ffmpeg runtime (Windows; see Build and Run) and degrade to gradient placeholder thumbnails without blocking business flows.

## 6. Development Challenges and Resolutions

| # | Challenge | Resolution |
| --- | --- | --- |
| 1 | The official `video_player` has no native Windows implementation | Playback moved to **media_kit** (mpv core): mature hardware decoding on Windows and Android, with subtitles, playback speed, and seek built in; iOS/Linux are covered by `media_kit_libs_ios_video` / `media_kit_libs_linux`. |
| 2 | FFmpeg filter text cannot render Chinese and its syntax is fragile | Photo watermarks are composited inside the **Flutter engine** (`PictureRecorder`/`Canvas` + `TextPainter` with system fonts for translucent white-on-black-stroke text); video watermarks use the ffmpeg `drawtext` tiling scheme. Four field lessons were captured: escaping commas inside filter expressions, requiring the GPL build (with libx264), `-hwaccel auto` for a 6× decode speedup, and `-aac_coder fast` to avoid an AAC/libx264 concurrency deadlock. |
| 3 | Consumer cameras and gallery exports frequently strip EXIF, leaving photos without GPS unlocatable | A "no abandonment, no misattribution" policy: photos without GPS still enter the album under an "unlocated" section, support manual geo-write via pick-on-map in the viewer, and are reassigned to the nearest guide after writing — with explicit counts throughout. |
| 4 | The Web build has no file system | A `StorageAdapter` abstraction with two implementations: JSON text into `shared_preferences` keys, bytes ≤1 MB as base64 (covers persist across sessions), larger objects in session memory only. The custom UA header is adapted on Web to avoid CORS preflight interception, and a pre-download connectivity probe validates tile sources. |
| 5 | Correctness of offline-tile projection | The initial y-axis formula carried a 2π factor error; a hand-computed 16-tile baseline anchors the `tile_math` unit tests (degenerate extents, out-of-range latitudes, GCJ same-tile comparisons), preventing regression. |
| 6 | User-visible strings in context-free code paths | A service-layer string channel (`I18nService`) fetches strings inside getters such as `WallScanReport.banner` and the tile-report `toString`, leaving caller signatures untouched; only user-visible messages are translated — internal exceptions and debug output are not. |
| 7 | Watermarked export blocking the UI thread | Per-image processing (decode → scale → Canvas composite → JPEG encode) with progress and cancellation, scheduled between events. |
| 8 | Path traversal and size risks in imports | ZIP entry whitelist with character validation; absolute rejection of `../`, absolute paths, and drive letters; 500 MB per-file limit and cumulative extraction quota. |
| 9 | Overlapping touring areas confusing the legend | `ZoneLayout`, a pure-geometry post-pass: the area with more members keeps its extent while secondary areas shrink toward a new center (400 m floor), resolved pairwise with baselines recomputed. |
| 10 | AMap mobile gallery channel compatibility | Photo import on mobile uses the `image_picker` Photo Picker (no Android 13+ storage permissions); desktop uses `file_selector`; iOS share-file selection adds `uniformTypeIdentifiers`. |
| 11 | Anti-leak sharing | Watermarks are **burned into pixels** and irreversible (the watermarked mode always burns them; the original-quality branch serves full-quality sharing / backup); the geo album filters `shared` photos to keep shared copies out of the user's library. |

- Note: some of these resolutions were provided by an AI agent, and better solutions may exist; some blockers were resolved by the developer, who wrote detailed plans that the AI then executed or applied with manual modifications.

## 7. Data and Privacy Constraints

- No telemetry, no uploads, and no embedded analytics; network access is limited to basemap tiles, external lookup, and URL opening, in compliance with the respective service terms, with tile provenance labeled in the UI;
- All persisted data resides in the application data directory, and JSON data files always store relative paths; copying the directory completes backup and migration;
- Upgrades preserve backward compatibility strictly: models only add fields, and no destructive migration has ever been required;
- Destructive in-app actions (such as clearing all data) require explicit confirmation; demo data is recoverable afterward.

## 8. Build and Run

**Requirements**: a current Flutter stable release (Dart SDK ^3.13.5; development environment: Flutter 3.47 stable) or newer, with the platform toolchains.

> Windows desktop tip: if Developer Mode is off, `flutter run` may fail — enable it under `ms-settings:developers` and retry.

```bash
# 1) Fetch dependencies (first run)
flutter pub get

# 2) Generate i18n code (triggered by pub get; manual refresh)
flutter gen-l10n

# 3) Static analysis and tests (quality gate: 0 issues / all green)
flutter analyze --no-pub
flutter test

# 4) Run / package per platform
flutter run -d windows                 # Windows desktop
flutter build windows                  # Windows release (note: ANGLE.7z and mpv-dev-x86_64-*.7z downloads may break mid-fetch; it is recommended to download them and manually move them into the build/windows/x64 folder so they take part in the build)
flutter build apk                      # Android (requires command-line tools and accepted licenses)
flutter build ios                      # requires macOS + Xcode
flutter build linux                    # requires GTK dev packages, clang, cmake, ninja, pkg-config
flutter run -d chrome                  # Web preview (degraded persistence)
```

### Large files and third-party runtimes NOT included in the repository (read before building)

This repository contains source code and project configuration only. The following are **not committed** and must be provided as described:

| Item | Status | How to handle |
| --- | --- | --- |
| **`ffmpeg_runtime/`** (`ffmpeg.exe` + `ffprobe.exe`, ~160 MB each) | ❌ not in the repository (each file exceeds GitHub's 100 MB limit) | **Required before building for Windows**: the post-build deployment step copies this folder into the output directory, and the **build fails if the folder is missing**. Download a **GPL build** of FFmpeg (must include libx264, used for video watermarking and transcoding) — e.g. gyan.dev `release-full` or BtbN `win64-gpl` — and place `ffmpeg.exe` and `ffprobe.exe` under `ffmpeg_runtime/` at the repository root. Without them: original-quality export and the full-export bundle are unaffected (they do not use FFmpeg); watermarked video transcoding and first-frame thumbnails are unavailable (thumbnails degrade to gradient placeholders without blocking business flows). |
| **media_kit codec components** (mpv / ANGLE, fetched on first Windows build) | ✅ fetched automatically during the build | No manual action is needed with normal connectivity; for fully offline machines, the `ANGLE.7z` and `mpv-dev` (win64) archives can be pre-placed in the optional `build_cache/` directory. |
| **`release/`** (APK / Windows installer and other packaged artifacts) | ❌ not in the repository | Build them yourself with the commands above; the Windows installer can be produced from the root `installer.iss` (Inno Setup); artifacts may also be available on this repository's Releases page. |
| `build/`, `.dart_tool/`, `.flutter-plugins-dependencies`, etc. | local generated files | Produced automatically by the build tooling; not committed. |

Platform-specific components and prerequisites:

| Platform | Components | Prerequisites |
| --- | --- | --- |
| Windows | `media_kit_libs_windows_video` + local `ffmpeg_runtime/` (first frames, transcoding; provide your own — see above) | Visual Studio 2022 desktop C++ workload |
| Android | `media_kit_libs_android_video`; manifest includes INTERNET and location permissions | Android SDK 34+, cmdline-tools, accepted licenses |
| iOS | `media_kit_libs_ios_video`; Info.plist includes location and photo-library usage strings | macOS + Xcode (build must occur on a Mac) |
| Linux | `media_kit_libs_linux`; standard `linux/CMakeLists.txt` template | libgtk-3-dev, clang, cmake, ninja, pkg-config |
| Web | no additional native libraries; storage uses the fallback implementation | any modern browser |

> Android license audit: `flutter doctor --android-licenses`. iOS and Linux compilation must be performed on their respective operating systems; the project files are included in this repository, but the author has not carried out actual builds, and any issues that arise are unknown.

## 9. Repository Layout

The layered source tree appears in section 4. Additional notes:

- `test/` contains **114 tests** covering coordinate conversion / tile math / clustering / routes / EXIF / layout determinism / data-layer round-trips / the share chain (original-quality packs and the full-export bundle) / the thumbnail-binding lock / category management / widget smoke tests;

## 10. Quality Baseline and Testing

- `flutter analyze --no-pub`: **0 issues** (a hard gate, regression-required on every change);
- `flutter test`: **all 114 tests pass**, covering GCJ-02 offsets and round-trip error, Haversine and tile coordinates, DBSCAN cluster counts and isolates, 2-opt non-degradation, hand-built EXIF samples, seeded album-wall determinism, cap truncation direction and uid deduplication, export/import round-trips (original-quality packs and full-export bundles included), the thumbnail-binding lock (per-entry "file↔thumbnail" pairing immune to insertion, zoom regrouping and re-sorting), category management (color and icon overrides, custom-category round-trips, image-icon tri-state semantics, malformed-data immunity), and cross-platform widget smoke tests;
- Every feature batch additionally requires manual acceptance on the Windows desktop build (in both languages) with clean runtime logs.

## 11. Internationalization

- **Scope**: Chinese and English bilingual, with the ARB architecture extending naturally to more languages;
- **Channels**: UI strings directly via `AppLocalizations.of(context)`; service-layer strings (no BuildContext) via `I18nService.t`; both are driven by the same locale through the same callback; entries live in the two ARB files and are generated via gen-l10n;
- **Locked glossary**: Guide = 攻略, Zone = 片区, Touring Area = 游览区域, Must-visit = 必去, Geo Album = 地理相册, Map Photos = 地图照片, AMap / Tianditu = 高德 / 天地图;
- **Excluded from translation**: user data itself (titles / descriptions / custom watermark text), internal data-layer identifiers, and share-file JSON.

## 12. AI-Assisted Development

This project is **AI-assisted**: programmed throughout with **OpenCode** using the **GLM-5.3 Flash** model. Code, tests, and documentation were produced in a workflow in which the user proposed the design prototype, requirements, and feature points, had development project documents generated, revised those documents by hand, and then requested development and acceptance item by item — the AI completed the implementations from front end to back end. All feature changes were merged only after manual runtime acceptance, and a few hard problems were resolved by the developer manually patching the AI-generated project code. The data and privacy constraints in section 7 are unaffected by AI assistance: while running, this project collects nothing over the network, uploads no data, and embeds no telemetry.

## 13. License

The project's own code is released under the **Apache License, Version 2.0** (see the root `LICENSE` file). Third-party dependencies remain under their original licenses; the per-component inventory and obligations live in the root `THIRD-PARTY-NOTICES.md` (the GPL variant of FFmpeg is invoked as a separate process; the native binaries bundled by media_kit belong to the GPL family — see the notices for redistribution terms). Map tiles are for personal offline use only and are attributed in the UI (OSM data: © OpenStreetMap contributors).

**Copyright & attribution**: the project's own code is Copyright © 2026 WangYuwen (the AtmaBook project); distributed derivatives must carry the Apache-2.0 license text and retain the attribution notices (Apache-2.0 §4).

**Third-party obligations at a glance** (per-component detail in the root `THIRD-PARTY-NOTICES.md`):

| Category | License | Obligations |
| --- | --- | --- |
| Flutter SDK & platform templates | BSD-3-Clause | Retain notices; surface the engine's aggregated third-party works via Flutter's built-in LicensePage in distributed builds |
| Direct Dart dependencies (flutter_map, provider, image, archive, geolocator, etc.) | BSD-3 / MIT / Apache-2.0 | Retain each component's notices; commercial use and redistribution permitted |
| media_kit packages (Dart layer) | MIT | Same as above |
| Native decode components bundled by media_kit (mpv / FFmpeg) | GPLv2+ / LGPL/GPL | When distributing, attach the license texts and provide pointers to the corresponding source; libmpv is loaded via dart:ffi — a debated gray zone; obtain formal legal advice before closed-source commercial distribution |
| `ffmpeg_runtime/` (user-provided, not committed) | GPL build (with libx264) | When users fetch it themselves, redistribution obligations rest with them; distributors who ship the executables must follow GPL terms (license text + source offer) |
| Map data & external services | ODbL + provider terms | "© OpenStreetMap contributors" must be displayable in the UI; Nominatim/OSRM public services carry rate-limit and testing-only terms; personal AMap/Tianditu keys are not commercial licenses — commercial use requires provider agreements |
| Build-time tools (Gradle, Inno Setup, etc.) | Apache-2.0 and others | Not shipped in artifacts; no bundled obligations |
| `assets/` artwork | original to this project | — |

This section and `THIRD-PARTY-NOTICES.md` are an informational inventory, not legal advice; consult the license texts (and counsel, for commercial distribution) as authoritative.
