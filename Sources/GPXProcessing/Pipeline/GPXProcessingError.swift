import Foundation

/// Errors thrown by the processing pipeline.
public enum GPXProcessingError: LocalizedError, Sendable {
    case unsupportedInput(URL)
    case unreadableInput(URL)
    case outputWriteFailure(URL, underlying: Error)
    case parsingFailure(line: Int, column: Int, message: String)
    case cancelled
    case internalInconsistency(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedInput(let url):
            return "Unsupported input file: \(url.lastPathComponent)"
        case .unreadableInput(let url):
            return "Unable to read GPX input at \(url.path)"
        case .outputWriteFailure(let url, let underlying):
            return "Failed to write output to \(url.path): \(underlying.localizedDescription)"
        case .parsingFailure(let line, let column, let message):
            return "Parser error at line \(line), column \(column): \(message)"
        case .cancelled:
            return "Processing cancelled"
        case .internalInconsistency(let message):
            return "Internal pipeline inconsistency: \(message)"
        }
    }
}
