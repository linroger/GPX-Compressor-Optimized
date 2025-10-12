import Foundation

enum Formatting {
    static func formatBytesPerSecond(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(value)))\/s"
    }

    static func formatStage(_ stage: GPXProcessingProgress.Stage) -> String {
        switch stage {
        case .queued: return "Queued"
        case .reading: return "Reading"
        case .parsing: return "Parsing"
        case .compressing: return "Compressing"
        case .writing: return "Writing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
