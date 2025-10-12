import Foundation

/// Fine grained progress reporting emitted by the pipeline.
public struct GPXProcessingProgress: Sendable, Identifiable {
    public enum Stage: Sendable, Hashable {
        case queued
        case reading
        case parsing
        case compressing
        case writing
        case completed
        case failed
    }

    public let id: UUID
    public let stage: Stage
    public let inputURL: URL
    public let outputURL: URL?
    public let processedBytes: Int64
    public let totalBytes: Int64
    public let processedSegments: Int
    public let totalSegments: Int?
    public let processedPoints: Int
    public let writtenPoints: Int
    public let throughputBytesPerSecond: Double
    public let message: String?
    public let error: Error?
    public let timestamp: Date

    public init(
        id: UUID,
        stage: Stage,
        inputURL: URL,
        outputURL: URL?,
        processedBytes: Int64,
        totalBytes: Int64,
        processedSegments: Int,
        totalSegments: Int?,
        processedPoints: Int,
        writtenPoints: Int,
        throughputBytesPerSecond: Double,
        message: String? = nil,
        error: Error? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stage = stage
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.processedBytes = processedBytes
        self.totalBytes = totalBytes
        self.processedSegments = processedSegments
        self.totalSegments = totalSegments
        self.processedPoints = processedPoints
        self.writtenPoints = writtenPoints
        self.throughputBytesPerSecond = throughputBytesPerSecond
        self.message = message
        self.error = error
        self.timestamp = timestamp
    }

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(processedBytes) / Double(totalBytes))
    }

    public func updating(
        stage: Stage? = nil,
        processedBytes: Int64? = nil,
        processedSegments: Int? = nil,
        totalSegments: Int?? = nil,
        processedPoints: Int? = nil,
        writtenPoints: Int? = nil,
        throughput: Double? = nil,
        message: String?? = nil,
        error: Error?? = nil
    ) -> GPXProcessingProgress {
        GPXProcessingProgress(
            id: id,
            stage: stage ?? self.stage,
            inputURL: inputURL,
            outputURL: outputURL,
            processedBytes: processedBytes ?? self.processedBytes,
            totalBytes: totalBytes,
            processedSegments: processedSegments ?? self.processedSegments,
            totalSegments: (totalSegments ?? self.totalSegments),
            processedPoints: processedPoints ?? self.processedPoints,
            writtenPoints: writtenPoints ?? self.writtenPoints,
            throughputBytesPerSecond: throughput ?? throughputBytesPerSecond,
            message: (message ?? self.message),
            error: (error ?? self.error),
            timestamp: Date()
        )
    }
}
