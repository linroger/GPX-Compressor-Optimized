import Foundation
import CoreGPX

/// High level knobs describing how a GPX file should be processed and compressed.
/// The configuration is intentionally immutable and `Sendable` so that it can be
/// shared safely across concurrent tasks.
public struct GPXProcessingConfiguration: Sendable, Hashable {
    /// Identifier used to suffix output file names.
    public var outputSuffix: String
    /// Maximum number of track points to accumulate before pushing work to the compression pipeline.
    public var segmentChunkSize: Int
    /// Strategy describing how to reduce the number of points in a segment.
    public var compressionStrategy: CompressionStrategy
    /// Optional radius (in metres) used when eliminating nearby duplicate points.
    public var deduplicationRadius: Double?
    /// Whether to preserve the original point ordering even when chunks are processed in parallel.
    public var enforceStableOrdering: Bool
    /// Whether random removal is allowed when the user selects that strategy.
    public var enableRandomRemoval: Bool
    /// Controls how aggressively metadata is preserved when rewriting the output file.
    public var preserveExtensions: Bool

    public init(
        outputSuffix: String = "-compressed",
        segmentChunkSize: Int = 16_384,
        compressionStrategy: CompressionStrategy = .ramerDouglasPeucker(tolerance: 5.0),
        deduplicationRadius: Double? = 2.5,
        enforceStableOrdering: Bool = true,
        enableRandomRemoval: Bool = false,
        preserveExtensions: Bool = true
    ) {
        precondition(segmentChunkSize > 0, "Segment chunk size must be > 0")
        self.outputSuffix = outputSuffix
        self.segmentChunkSize = segmentChunkSize
        self.compressionStrategy = compressionStrategy
        self.deduplicationRadius = deduplicationRadius
        self.enforceStableOrdering = enforceStableOrdering
        self.enableRandomRemoval = enableRandomRemoval
        self.preserveExtensions = preserveExtensions
    }

    /// Strategy options for lossy compression.
    public enum CompressionStrategy: Sendable, Hashable {
        /// Applies a Ramer-Douglas-Peucker simplification in metres.
        case ramerDouglasPeucker(tolerance: Double)
        /// Removes samples that fall within a radius of the previous retained sample.
        case stripNearby(distance: Double)
        /// Randomly removes points based on a percentage between 0 and 1.
        case random(percent: Double)
        /// Use the historic CoreGPX lossless duplicate stripping algorithm.
        case stripDuplicates

        public var description: String {
            switch self {
            case .ramerDouglasPeucker(let tolerance):
                return "RDP tolerance \(String(format: "%.2f", tolerance))m"
            case .stripNearby(let distance):
                return "Radius \(String(format: "%.2f", distance))m"
            case .random(let percent):
                return "Random \(Int(percent * 100))%"
            case .stripDuplicates:
                return "Strip duplicates"
            }
        }
    }
}

public extension GPXProcessingConfiguration {
    /// Configuration tuned for massive multi-gigabyte files.
    static var largeFileDefault: GPXProcessingConfiguration {
        GPXProcessingConfiguration(
            outputSuffix: "-tahoe",
            segmentChunkSize: 32_768,
            compressionStrategy: .ramerDouglasPeucker(tolerance: 4.0),
            deduplicationRadius: 1.5,
            enforceStableOrdering: true,
            enableRandomRemoval: false,
            preserveExtensions: true
        )
    }

    /// Create a derived configuration with a different compression strategy.
    func with(strategy: CompressionStrategy) -> GPXProcessingConfiguration {
        var copy = self
        copy.compressionStrategy = strategy
        return copy
    }

    /// Resolve the destination URL for a processed file.
    func makeOutputURL(for input: URL, overrideDirectory: URL? = nil) -> URL {
        let parent = overrideDirectory ?? input.deletingLastPathComponent()
        let baseName = input.deletingPathExtension().lastPathComponent
        let ext = input.pathExtension.isEmpty ? "gpx" : input.pathExtension
        return parent.appendingPathComponent("\(baseName)\(outputSuffix).\(ext)")
    }
}
