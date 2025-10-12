# Architecture Overview

## Repository Layout
- `GPXCompressor/`: Legacy AppKit-based macOS document app that provides the UI for opening, compressing, and saving GPX files.
- `CoreGPX-0.9.3/`: Embedded copy of the CoreGPX library (Swift 5 era) plus sample projects, tests, and supporting files.
- `GPXCompressor.xcodeproj`: Xcode project referencing both the app target and the CoreGPX source.

## GPXCompressor App
- **AppDelegate**: Minimal NSApplication delegate that instantiates a custom `DocumentController` and opts to terminate after closing the last window.
- **Document / DocumentController**: Classic `NSDocument` subclass storing the raw GPX string and URL. Uses storyboard instantiation to hook the UI (`ViewController`) to the document lifecycle. Autosave is disabled.
- **ViewController**: Main UI logic. Uses AppKit outlets for text fields, progress indicator, radio buttons, and checkboxes. Presents `NSOpenPanel`/`NSSavePanel` synchronously on the main thread.
  - Maintains a `GPXParser?` reference for the currently opened file.
  - Compression triggered by “Process” button executes on a global `DispatchQueue` but immediately synchronously hops back to the main queue for input validation and UI updates, blocking the UI during parsing/compression.
  - Compression calls into `GPXParser.lossyParsing` which eagerly parses the entire document into memory before performing lossy operations.
  - Error reporting implemented with `NSAlert` modal sheets; no progress feedback beyond swapping button title/spinner visibility.
- **UI Storyboards** (not in repo) implied to back the outlets; no SwiftUI usage.

## CoreGPX Library Snapshot
- Provides GPX schema model types (`GPXRoot`, `GPXTrack`, `GPXWaypoint`, etc.) each inheriting from `GPXElement` for XML generation.
- `GPXParser` is a SAX-style wrapper around `XMLParser` that builds an in-memory tree of `GPXRawElement` before constructing CoreGPX model objects. Parsing is synchronous and single-threaded.
- Lossy compression helpers live in `GPXCompression`, mutating `GPXRoot` in place. Algorithms rely on iterative array removal (O(n^2) worst case) and hold transient state arrays for deduplication.
- `CoreGPX-0.9.3/Extras` includes bridging helpers to `CoreLocation`. `Example/` houses UIKit sample code and XCTest fixtures, not used by the macOS app.
- Package manifests target Swift 5.2 / 5.9 with minimum macOS 10.13.

## Coding Conventions & Patterns
- Written in Swift 5-era style: heavy use of `DispatchQueue`, completion handlers, and manual reference counting of UI state.
- Models rely on reference types (`class`) inheriting from `GPXElement`; no thread-safety or copy-on-write semantics.
- Optional properties are common; nil guarding is manual and repetitive.
- UI logic tied directly to outlets; minimal separation of concerns or test coverage for the macOS target.

## Key Observations
- Entire GPX document is parsed into memory (`GPXParser`) before compression; no streaming or incremental handling.
- Compression mutates arrays while iterating, causing repeated index lookups and potential performance regressions on large files.
- No concurrency primitives beyond GCD; no structured concurrency, cancellation, or progress reporting.
- App still targets Intel-era macOS APIs; no SwiftUI, Combine, or Swift Concurrency adoption.
- Embedded CoreGPX copy is outdated relative to modern Swift/Apple Silicon best practices.
