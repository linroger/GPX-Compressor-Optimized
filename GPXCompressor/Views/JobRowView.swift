import SwiftUI
import GPXProcessing

struct JobRowView: View {
    let job: JobState
    let cancelAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(job.inputURL.lastPathComponent)
                        .font(.headline)
                    if let output = job.outputURL {
                        Text("→ \(output.lastPathComponent)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(Formatting.formatStage(job.stage))
                    .font(.subheadline)
                    .foregroundStyle(stageColor)
            }
            ProgressView(value: job.fractionCompleted)
            HStack {
                Text("Points: \(job.processedPoints) → \(job.writtenPoints)")
                Spacer()
                Text(Formatting.formatBytesPerSecond(job.throughput))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let cancelAction, job.stage == .compressing || job.stage == .parsing || job.stage == .writing {
                    Button("Cancel", action: cancelAction)
                        .buttonStyle(.borderless)
                }
            }
            if let message = job.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(job.stage == .failed ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var stageColor: Color {
        switch job.stage {
        case .completed: return .green
        case .failed: return .red
        default: return .primary
        }
    }
}

struct JobRowView_Previews: PreviewProvider {
    static var previews: some View {
        JobRowView(
            job: JobState(job: GPXProcessingJob(inputURL: URL(fileURLWithPath: "/tmp/demo.gpx"), outputURL: URL(fileURLWithPath: "/tmp/demo-tahoe.gpx"), configuration: .largeFileDefault)),
            cancelAction: {}
        )
        .padding()
        .frame(width: 400)
    }
}
