import Foundation
import GPXProcessing

@main
struct GPXCompressorCLI {
    static func main() async throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            printUsage()
            return
        }

        var outputDirectory: URL?
        var strategy: GPXProcessingConfiguration.CompressionStrategy = .ramerDouglasPeucker(tolerance: 5.0)
        var dedupeRadius: Double? = 1.5
        var files: [URL] = []

        while !arguments.isEmpty {
            let argument = arguments.removeFirst()
            switch argument {
            case "--output", "-o":
                guard let value = arguments.first else {
                    throw CLIError.invalidArgument("Missing value for --output")
                }
                arguments.removeFirst()
                outputDirectory = URL(fileURLWithPath: value, isDirectory: true)
            case "--rdp":
                guard let value = arguments.first, let tolerance = Double(value) else {
                    throw CLIError.invalidArgument("Invalid tolerance for --rdp")
                }
                arguments.removeFirst()
                strategy = .ramerDouglasPeucker(tolerance: tolerance)
            case "--strip-nearby":
                guard let value = arguments.first, let radius = Double(value) else {
                    throw CLIError.invalidArgument("Invalid radius for --strip-nearby")
                }
                arguments.removeFirst()
                strategy = .stripNearby(distance: radius)
            case "--strip-duplicates":
                strategy = .stripDuplicates
            case "--no-dedupe":
                dedupeRadius = nil
            case "--help", "-h":
                printUsage()
                return
            default:
                files.append(URL(fileURLWithPath: argument))
            }
        }

        guard !files.isEmpty else {
            throw CLIError.invalidArgument("No GPX files were provided")
        }

        var configuration = GPXProcessingConfiguration.largeFileDefault
        configuration.compressionStrategy = strategy
        configuration.deduplicationRadius = dedupeRadius

        let jobs = files.map { file -> GPXProcessingJob in
            let destination = configuration.makeOutputURL(for: file, overrideDirectory: outputDirectory)
            return GPXProcessingJob(inputURL: file, outputURL: destination, configuration: configuration)
        }

        let scheduler = GPXJobScheduler()
        let stream = await scheduler.enqueue(jobs: jobs)

        for try await update in stream {
            let percent = update.fractionCompleted * 100
            let throughput = ByteCountFormatter.string(fromByteCount: Int64(update.throughputBytesPerSecond), countStyle: .file)
            print("[\(update.stage)] \(update.inputURL.lastPathComponent) - \(String(format: "%.2f", percent))% | points: \(update.processedPoints) -> \(update.writtenPoints) | speed: \(throughput)/s")
            if case .completed = update.stage {
                if let outputURL = update.outputURL {
                    print("  → Saved to \(outputURL.path)")
                }
            }
        }
    }

    private static func printUsage() {
        print("""
        GPXCompressorCLI
        Usage: gpxcompressor-cli [options] <file1.gpx> <file2.gpx> ...

        Options:
          --output <dir>         Directory for processed files (defaults to input directory)
          --rdp <tolerance>      Use Ramer-Douglas-Peucker with given tolerance in metres
          --strip-nearby <m>     Remove points within the given metre radius
          --strip-duplicates     Remove exact duplicate coordinates
          --no-dedupe            Disable post-compression deduplication
          --help                 Show this help message
        """)
    }

    private enum CLIError: Error {
        case invalidArgument(String)
    }
}
