# Modernization & Optimization Plan

The existing three-phase draft is a great starting point. Below is an expanded, implementation-grade roadmap that layers additional modernization workstreams, instrumentation, and testing necessary to exploit Apple Silicon and macOS 26 Tahoe fully.

## Phase 0 – Project Baseline & Toolchain Upgrade
1. **Toolchain & Deployment Targets**
   - Migrate the project to Swift 6.2 and Xcode 16 build settings.
   - Raise deployment targets to macOS 26.1 (Tahoe) and remove legacy Intel-specific configuration.
   - Audit CoreGPX sources for Swift 6 concurrency-safety warnings (`Sendable`, actor isolation).
2. **Package Management Cleanup**
   - Replace the vendored CoreGPX sources with an SPM dependency pinned to our modernized fork for easier updates.
   - Introduce a root `Package.swift` (or workspace) to share models between the app and CLI tooling.
3. **Continuous Integration Bootstrap**
   - Add GitHub Actions (or Xcode Cloud) pipelines compiling for both `arm64` and Catalyst, running unit tests, and exporting metric reports.

## Phase 1 – Modern Foundation Architecture (Expanded)
1. **Concurrency Adoption**
   - Wrap GPX parsing/compression workflows in `async` functions and migrate UI invocations to Swift Concurrency (`Task`, `TaskGroup`, `AsyncStream`).
   - Introduce cooperative cancellation tokens to abort long-running jobs when the user cancels or files change mid-flight.
2. **Memory-Efficient Parsing**
   - Implement a streaming parser layer that uses `XMLParser` with incremental hand-off to an `AsyncSequence` of domain events rather than accumulating the full DOM.
   - Support optional memory-mapped IO via `DispatchData`/`Data` backed by `mmap` for extremely large files.
   - Ensure decoded model types adopt value semantics or copy-on-write buffers to prevent aliasing when processed on multiple threads.
3. **CoreGPX Refactor**
   - Split monolithic model classes into thread-safe, `Sendable` structs wherever possible.
   - Convert conversion helpers (`Convert`, `GPXDateParser`) into lightweight static utilities using `ISO8601DateFormatter` caching with actors for thread safety.
   - Provide both builder-style APIs for writing GPX and streaming readers for parsing.
4. **Diagnostics & Error Handling**
   - Normalize errors into modern `Error` enums with localized descriptions and recovery suggestions.
   - Log parse/compress metrics (duration, throughput, memory) using `os.Logger` categories for later analysis.

## Phase 2 – Parallel Processing Architecture (Expanded)
1. **Multi-Stage Pipeline**
   - Design a pipeline (`Parse → Transform → Compress → Persist`) using `AsyncChannel` buffers with back-pressure to avoid memory spikes.
   - Process GPX track segments in parallel `TaskGroup`s with adaptive chunk sizing based on point counts.
2. **SIMD & Accelerated Math**
   - Rewrite distance calculations using `simd_double2` and Accelerate (`vDSP`) to speed up Haversine/Euclidean computations.
   - Cache trigonometric results per latitude band to reduce repeated `cos`/`sin` calls.
3. **Workload Scheduler**
   - Introduce an `Actor`-based job scheduler that balances work across performance cores, respecting QoS and thermal limits.
   - Support concurrent processing of multiple GPX files with progress aggregation and failure isolation.
4. **Persistence Strategy**
   - Stream compressed output directly to disk using `FileHandle` async APIs, avoiding full in-memory reconstruction.
   - Provide optional compression codecs (gzip/zstd) when writing archives of multiple GPX outputs.

## Phase 3 – Advanced Optimizations & User Experience (Expanded)
1. **Adaptive Compression Algorithms**
   - Implement density-aware simplification (e.g., Ramer–Douglas–Peucker, sliding window filters) with tolerance selection based on map zoom level or target size.
   - Add machine-learned heuristics (e.g., classify segments as stationary vs. moving) to decide pruning strategies.
2. **SwiftUI macOS Interface**
   - Replace the storyboard-based UI with a SwiftUI `DocumentGroup` app supporting drag-and-drop, multiple selection, and resumable jobs.
   - Surface live progress, ETA, throughput graphs (using Swift Charts), and contextual metadata previews.
   - Integrate `Observation` for state updates and `@Environment(\.dismiss)` for document lifecycle.
3. **User Controls & Automation**
   - Allow queueing multiple files with per-file presets (radius, algorithm, outputs) stored in a `@Model` (SwiftData) persistence layer.
   - Provide AppleScript/Shortcuts automation hooks and a CLI companion tool for batch workflows.
4. **Robust Cancellation & Recovery**
   - Persist in-progress job metadata so the app can resume or roll back partially written outputs after crashes or power loss.

## Phase 4 – Observability, Testing & Reliability
1. **Performance Regression Harness**
   - Create synthetic multi-gigabyte GPX generators to benchmark throughput and memory consumption on Apple Silicon.
   - Automate Instruments time profiling and log exported metrics to detect regressions.
2. **Unit & Integration Tests**
   - Add async unit tests for streaming parser, compression operators, and job scheduler.
   - Include golden master tests comparing legacy and new outputs to ensure fidelity.
3. **Crash Resilience**
   - Adopt Swift 6 strict concurrency checking, `-warn-concurrency` flags, and `TSAN` runs to catch data races early.
   - Guard all file IO with structured error handling and user-friendly recovery UI.
4. **Documentation & Samples**
   - Update README with benchmarking results, supported workflows, and system requirements.
   - Provide sample automations and command-line scripts.

## Phase 5 – Deployment & Continuous Improvement
1. **Distribution**
   - Package the modernized app via notarized DMG and optional Mac App Store submission (if licensing allows).
   - Offer universal binary builds with optional Catalyst target for iPad side-loading.
2. **Telemetry & Feedback Loop**
   - Integrate optional, privacy-conscious analytics (e.g., anonymized performance metrics) with user consent to guide future optimizations.
3. **Extensibility Hooks**
   - Publish plugin APIs (SPIs) allowing custom compression strategies or export formats.
   - Expose REST/IPC endpoints for controlling batch jobs from other tools.

This roadmap ensures the app not only handles multi-gigabyte GPX datasets effortlessly but also delivers a thoroughly modern macOS experience tailored for Apple Silicon.
