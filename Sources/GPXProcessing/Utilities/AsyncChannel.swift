import Foundation

/// Simple async channel enabling back-pressure aware producer/consumer handoff.
public struct AsyncChannel<Element: Sendable>: Sendable {
    private let continuation: AsyncStream<Element>.Continuation
    public let stream: AsyncStream<Element>

    public init(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element>(bufferingPolicy: bufferingPolicy) { continuation = $0 }
        self.stream = stream
        self.continuation = continuation
    }

    public func send(_ element: Element) {
        continuation.yield(element)
    }

    public func finish() {
        continuation.finish()
    }
}

/// Minimal async semaphore used to throttle concurrent jobs.
public actor AsyncSemaphore {
    private var value: Int
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    public init(value: Int) {
        self.value = value
    }

    public func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waitQueue.append(continuation)
        }
    }

    public func signal() {
        if !waitQueue.isEmpty {
            let continuation = waitQueue.removeFirst()
            continuation.resume()
        } else {
            value += 1
        }
    }
}
