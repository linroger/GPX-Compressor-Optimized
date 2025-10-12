# TODO

- [x] Inventory Swift files
- [x] Read GPXCompressor Swift files
- [x] Read CoreGPX Swift files
- [x] Document architecture in architecture.md
- [x] Identify issues and optimization opportunities
- [x] Formulate comprehensive optimization plan
- [x] Implement optimizations
  - [x] Introduce root Swift Package with modern module graph
  - [x] Author streaming GPX processing pipeline with async/await
  - [x] Implement SIMD-accelerated compression strategies
  - [x] Replace AppKit UI with SwiftUI job dashboard and progress reporting
  - [x] Update Xcode project settings for Swift 6 / macOS 26
- [ ] Add tests and run builds
  - [ ] Add focused unit tests covering pipeline concurrency and compression fidelity
  - [ ] Run `swift test`
  - [ ] Build via swift package and ensure xcodebuild settings compile (environment permitting)
- [ ] Prepare PR
