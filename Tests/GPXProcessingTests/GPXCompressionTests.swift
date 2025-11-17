import XCTest
@testable import GPXProcessing

final class GPXCompressionTests: XCTestCase {
    func testRamerDouglasPeuckerSimplifiesLine() throws {
        var points: [GPXPointRecord] = []
        for i in 0..<100 {
            points.append(GPXPointRecord(latitude: Double(i), longitude: Double(i), elevation: nil, timestamp: nil))
        }
        let simplified = RamerDouglasPeucker.simplify(points: points, epsilon: 10)
        XCTAssertLessThan(simplified.count, points.count)
        XCTAssertEqual(simplified.first?.latitude, 0)
        XCTAssertEqual(simplified.last?.latitude, 99)
    }

    func testSegmentCompressorDeduplicates() async throws {
        let configuration = GPXProcessingConfiguration(segmentChunkSize: 1024, compressionStrategy: .stripDuplicates, deduplicationRadius: nil)
        let compressor = SegmentCompressor(configuration: configuration)
        let points = [
            GPXPointRecord(latitude: 1, longitude: 1, elevation: nil, timestamp: nil),
            GPXPointRecord(latitude: 1, longitude: 1, elevation: nil, timestamp: nil),
            GPXPointRecord(latitude: 1.0001, longitude: 1.0001, elevation: nil, timestamp: nil)
        ]
        let payload = GPXTrackSegmentPayload(trackIndex: 0, segmentIndex: 0, attributes: [:], leadingNodes: [], trailingNodes: [], points: points)
        let compressed = try await compressor.compress(segment: payload)
        XCTAssertEqual(compressed.points.count, 2)
    }
}
