// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GPXCompressorSuite",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GPXProcessing",
            targets: ["GPXProcessing"]
        ),
        .executable(
            name: "gpxcompressor-cli",
            targets: ["GPXCompressorCLI"]
        )
    ],
    dependencies: [
        .package(name: "CoreGPX", path: "CoreGPX-0.9.3")
    ],
    targets: [
        .target(
            name: "GPXProcessing",
            dependencies: [
                .product(name: "CoreGPX", package: "CoreGPX")
            ],
            path: "Sources/GPXProcessing",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warn-concurrency", "-enable-library-evolution"], .when(configuration: .release)),
                .unsafeFlags(["-warn-concurrency"], .when(configuration: .debug))
            ]
        ),
        .executableTarget(
            name: "GPXCompressorCLI",
            dependencies: ["GPXProcessing"],
            path: "Sources/GPXCompressorCLI"
        ),
        .testTarget(
            name: "GPXProcessingTests",
            dependencies: ["GPXProcessing"],
            path: "Tests/GPXProcessingTests"
        )
    ]
)
