import Foundation
import SwiftUI
import GPXProcessing

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var jobs: [UUID: JobState] = [:]
    @Published var configuration: GPXProcessingConfiguration = .largeFileDefault

    private let scheduler = GPXJobScheduler()
    private var jobTasks: [UUID: Task<Void, Never>] = [:]

    var sortedJobs: [JobState] {
        jobs.values.sorted { $0.created < $1.created }
    }

    func enqueue(urls: [URL]) {
        for url in urls {
            let output = configuration.makeOutputURL(for: url)
            let job = GPXProcessingJob(inputURL: url, outputURL: output, configuration: configuration)
            jobs[job.id] = JobState(job: job)
            let task = Task { [weak self] in
                guard let self else { return }
                let stream = await scheduler.enqueue(jobs: [job])
                do {
                    for try await update in stream {
                        await MainActor.run {
                            self.handle(progress: update)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.present(error: error, for: job.id)
                    }
                }
            }
            jobTasks[job.id] = task
        }
    }

    func cancel(jobID: UUID) {
        jobTasks[jobID]?.cancel()
        jobTasks[jobID] = nil
        if var job = jobs[jobID] {
            job.stage = .failed
            job.message = "Cancelled"
            jobs[jobID] = job
        }
    }

    private func handle(progress: GPXProcessingProgress) {
        guard var job = jobs[progress.id] else { return }
        job.update(with: progress)
        jobs[progress.id] = job
        if progress.stage == .completed || progress.stage == .failed {
            jobTasks[progress.id]?.cancel()
            jobTasks[progress.id] = nil
        }
    }

    private func present(error: Error, for id: UUID) {
        if var job = jobs[id] {
            job.stage = .failed
            job.message = error.localizedDescription
            job.error = error
            jobs[id] = job
        }
    }
}

struct JobState: Identifiable, Hashable {
    let id: UUID
    let inputURL: URL
    var outputURL: URL?
    var stage: GPXProcessingProgress.Stage
    var fractionCompleted: Double
    var processedPoints: Int
    var writtenPoints: Int
    var message: String?
    var error: Error?
    var throughput: Double
    let created: Date

    init(job: GPXProcessingJob) {
        self.id = job.id
        self.inputURL = job.inputURL
        self.outputURL = job.outputURL
        self.stage = .queued
        self.fractionCompleted = 0
        self.processedPoints = 0
        self.writtenPoints = 0
        self.message = "Queued"
        self.error = nil
        self.throughput = 0
        self.created = Date()
    }

    mutating func update(with progress: GPXProcessingProgress) {
        outputURL = progress.outputURL ?? outputURL
        stage = progress.stage
        fractionCompleted = progress.fractionCompleted
        processedPoints = progress.processedPoints
        writtenPoints = progress.writtenPoints
        message = progress.message
        error = progress.error
        throughput = progress.throughputBytesPerSecond
    }
}
