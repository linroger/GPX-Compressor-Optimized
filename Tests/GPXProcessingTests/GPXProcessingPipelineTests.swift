import XCTest
@testable import GPXProcessing

final class GPXProcessingPipelineTests: XCTestCase {
    func testPipelineProcessesSmallDocument() async throws {
        let input = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <gpx version=\"1.1\" creator=\"Test\" xmlns=\"http://www.topografix.com/GPX/1/1\">
          <trk>
            <name>Sample</name>
            <trkseg>
              <trkpt lat=\"0.0\" lon=\"0.0\"><ele>0</ele></trkpt>
              <trkpt lat=\"0.0\" lon=\"0.0\"><ele>1</ele></trkpt>
              <trkpt lat=\"1.0\" lon=\"1.0\"><ele>2</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("input.gpx")
        let outputURL = tempDir.appendingPathComponent("output.gpx")
        try input.write(to: inputURL, atomically: true, encoding: .utf8)

        let configuration = GPXProcessingConfiguration(
            outputSuffix: "-test",
            segmentChunkSize: 16,
            compressionStrategy: .stripDuplicates,
            deduplicationRadius: 0.5,
            enforceStableOrdering: true,
            enableRandomRemoval: false,
            preserveExtensions: true
        )
        let pipeline = GPXProcessingPipeline(configuration: configuration)
        let job = GPXProcessingJob(inputURL: inputURL, outputURL: outputURL, configuration: configuration)
        var completed = false
        for try await progress in pipeline.process(job: job) {
            if progress.stage == .completed {
                completed = true
            }
        }
        XCTAssertTrue(completed)
        let contents = try String(contentsOf: job.outputURL)
        XCTAssertTrue(contents.contains("trkseg"))
        XCTAssertFalse(contents.contains("<trkpt lat=\"0.0\" lon=\"0.0\"><ele>1</ele></trkpt>"))
    }
}
