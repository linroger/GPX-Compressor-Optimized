import Foundation

/// InputStream wrapper that reports progress as bytes are consumed by XMLParser.
public final class CountingInputStream: InputStream {
    private let fileHandle: FileHandle
    private let fileLength: UInt64
    private var _streamStatus: Stream.Status = .notOpen
    private var reportedBytes: UInt64 = 0
    public var onProgress: @Sendable (UInt64, UInt64) -> Void

    public init(url: URL, onProgress: @escaping @Sendable (UInt64, UInt64) -> Void) throws {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw GPXProcessingError.unreadableInput(url)
        }
        self.fileHandle = fileHandle
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        self.fileLength = attributes[.size] as? UInt64 ?? 0
        self.onProgress = onProgress
        super.init(data: Data())
    }

    deinit {
        try? fileHandle.close()
    }

    public override func open() {
        guard _streamStatus == .notOpen else { return }
        _streamStatus = .open
    }

    public override func close() {
        _streamStatus = .closed
    }

    public override var streamStatus: Stream.Status { _streamStatus }

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard _streamStatus != .closed else { return 0 }
        do {
            if let data = try fileHandle.read(upToCount: len), !data.isEmpty {
                data.copyBytes(to: buffer, count: data.count)
                reportedBytes += UInt64(data.count)
                onProgress(reportedBytes, fileLength)
                return data.count
            } else {
                _streamStatus = .atEnd
                return 0
            }
        } catch {
            _streamStatus = .error
            return -1
        }
    }

    public override var hasBytesAvailable: Bool {
        _streamStatus != .atEnd && _streamStatus != .closed
    }
}
