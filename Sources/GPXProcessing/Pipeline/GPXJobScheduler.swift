import Foundation

public final class GPXJobScheduler {
    private let semaphore: AsyncSemaphore

    public init(maxConcurrentJobs: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.semaphore = AsyncSemaphore(value: maxConcurrentJobs)
    }

    public func enqueue(jobs: [GPXProcessingJob]) -> AsyncThrowingStream<GPXProcessingProgress, Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for job in jobs {
                            group.addTask { [self, job] in
                                await self.semaphore.wait()
                                defer { Task { await self.semaphore.signal() } }
                                let pipeline = GPXProcessingPipeline(configuration: job.configuration)
                                let stream = await pipeline.process(job: job)
                                for try await update in stream {
                                    continuation.yield(update)
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
