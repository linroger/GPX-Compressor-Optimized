import Foundation

public final class GPXProcessingPipeline {
    private let configuration: GPXProcessingConfiguration

    public init(configuration: GPXProcessingConfiguration = .largeFileDefault) {
        self.configuration = configuration
    }

    public func process(job: GPXProcessingJob) -> AsyncThrowingStream<GPXProcessingProgress, Error> {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: job.inputURL.path)[.size] as? Int64) ?? 0
        return AsyncThrowingStream { continuation in
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                var progress = GPXProcessingProgress(
                    id: job.id,
                    stage: .reading,
                    inputURL: job.inputURL,
                    outputURL: job.outputURL,
                    processedBytes: 0,
                    totalBytes: fileSize,
                    processedSegments: 0,
                    totalSegments: nil,
                    processedPoints: 0,
                    writtenPoints: 0,
                    throughputBytesPerSecond: 0,
                    message: "Preparing",
                    error: nil
                )
                continuation.yield(progress)

                do {
                    let writer = try GPXStreamWriter(outputURL: job.outputURL)
                    let parser = GPXStreamingParser(configuration: self.configuration)
                    let compressor = SegmentCompressor(configuration: job.configuration)
                    var coordinators: [Int: TrackSegmentCoordinator] = [:]
                    var processedPoints = 0
                    var writtenPoints = 0
                    var processedSegments = 0
                    let startTime = Date()

                    let stream = parser.parse(url: job.inputURL)

                    for try await event in stream {
                        try Task.checkCancellation()
                        switch event {
                        case .header(let header):
                            try await writer.writeHeader(header)
                            progress = progress.updating(stage: .parsing, message: "Writing header")
                            continuation.yield(progress)
                        case .metadata(let metadata):
                            try await writer.writeMetadata(metadata)
                        case .waypoint(let waypoint):
                            try await writer.writeWaypoint(waypoint)
                        case .route(let route):
                            try await writer.writeRoute(route)
                        case .extensions(let node):
                            try await writer.writeExtensions(node)
                        case .trackStart(let index, let metadata):
                            coordinators[index] = TrackSegmentCoordinator(
                                writer: writer,
                                compressor: compressor
                            )
                            try await writer.beginTrack(metadata)
                        case .trackSegment(let payload):
                            guard let coordinator = coordinators[payload.trackIndex] else { continue }
                            let stats = try await coordinator.enqueue(segment: payload)
                            processedPoints += stats.originalPoints
                            writtenPoints += stats.writtenPoints
                            processedSegments += stats.segments
                            let currentThroughput = self.throughput(from: startTime, bytes: progress.processedBytes)
                            progress = progress.updating(
                                stage: .compressing,
                                processedBytes: progress.processedBytes,
                                processedSegments: processedSegments,
                                processedPoints: processedPoints,
                                writtenPoints: writtenPoints,
                                throughput: currentThroughput,
                                message: "Compressing track \(payload.trackIndex + 1)"
                            )
                            continuation.yield(progress)
                        case .trackEnd(let index):
                            if let coordinator = coordinators[index] {
                                let stats = try await coordinator.finish()
                                processedPoints += stats.originalPoints
                                writtenPoints += stats.writtenPoints
                                processedSegments += stats.segments
                                coordinators.removeValue(forKey: index)
                            }
                            try await writer.endTrack()
                            progress = progress.updating(
                                stage: .writing,
                                processedSegments: processedSegments,
                                processedPoints: processedPoints,
                                writtenPoints: writtenPoints,
                                message: "Finalising track \(index + 1)"
                            )
                            continuation.yield(progress)
                        case .documentEnd:
                            break
                        }
                    }

                    try await writer.finish()
                    let totalBytes = fileSize > 0 ? fileSize : progress.processedBytes
                    let elapsed = Date().timeIntervalSince(startTime)
                    let finalThroughput = self.throughput(from: startTime, bytes: totalBytes)
                    progress = progress.updating(
                        stage: .completed,
                        processedBytes: totalBytes,
                        processedSegments: processedSegments,
                        processedPoints: processedPoints,
                        writtenPoints: writtenPoints,
                        throughput: finalThroughput,
                        message: String(format: "Completed in %.2fs", elapsed),
                        error: nil
                    )
                    continuation.yield(progress)
                    continuation.finish()
                } catch {
                    progress = progress.updating(
                        stage: .failed,
                        message: .some("Failed: \(error.localizedDescription)"),
                        error: .some(error)
                    )
                    continuation.yield(progress)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func throughput(from start: Date, bytes: Int64) -> Double {
        let elapsed = Date().timeIntervalSince(start)
        return elapsed > 0 ? Double(bytes) / elapsed : 0
    }
}

private struct SegmentStats {
    var originalPoints: Int = 0
    var writtenPoints: Int = 0
    var segments: Int = 0
}

private final class TrackSegmentCoordinator {
    private let writer: GPXStreamWriter
    private let compressor: SegmentCompressor

    init(writer: GPXStreamWriter, compressor: SegmentCompressor) {
        self.writer = writer
        self.compressor = compressor
    }

    func enqueue(segment: GPXTrackSegmentPayload) async throws -> SegmentStats {
        let compressed = try await compressor.compress(segment: segment)
        try await writer.writeSegment(compressed)
        return SegmentStats(
            originalPoints: segment.points.count,
            writtenPoints: compressed.points.count,
            segments: 1
        )
    }

    func finish() async throws -> SegmentStats {
        SegmentStats()
    }
}
