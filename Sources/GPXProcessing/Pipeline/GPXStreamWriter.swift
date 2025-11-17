import Foundation

/// Serialises GPX structures back into XML while preserving indentation and ordering.
final class GPXStreamWriter {
    private let fileWriter: AsyncFileWriter
    private var indentationLevel: Int = 0

    init(outputURL: URL) throws {
        self.fileWriter = try AsyncFileWriter(url: outputURL)
    }

    func writeHeader(_ header: GPXDocumentHeader) async throws {
        try await fileWriter.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        let attributes = header.attributes.sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\($0.value.xmlEscaped())\"" }
            .joined()
        try await fileWriter.write("<gpx\(attributes)>\n")
        indentationLevel = 1
    }

    func writeMetadata(_ metadata: GPXMetadataContainer) async throws {
        try await write(node: metadata.node)
    }

    func writeWaypoint(_ waypoint: GPXWaypointContainer) async throws {
        try await write(node: waypoint.node)
    }

    func writeRoute(_ route: GPXRouteContainer) async throws {
        try await write(node: route.node)
    }

    func beginTrack(_ metadata: GPXTrackMetadata) async throws {
        let indent = currentIndent
        let attributes = metadata.attributes.sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\($0.value.xmlEscaped())\"" }
            .joined()
        try await fileWriter.write("\(indent)<trk\(attributes)>\n")
        indentationLevel += 1
        for node in metadata.childNodes {
            try await write(node: node)
        }
    }

    func writeSegment(_ segment: GPXTrackSegmentPayload) async throws {
        let indent = currentIndent
        let attributes = segment.attributes.sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\($0.value.xmlEscaped())\"" }
            .joined()
        try await fileWriter.write("\(indent)<trkseg\(attributes)>\n")
        indentationLevel += 1
        for node in segment.leadingNodes {
            try await write(node: node)
        }
        for point in segment.points {
            try await write(point: point)
        }
        for node in segment.trailingNodes {
            try await write(node: node)
        }
        indentationLevel -= 1
        try await fileWriter.write("\(indent)</trkseg>\n")
    }

    func endTrack() async throws {
        indentationLevel -= 1
        let indent = currentIndent
        try await fileWriter.write("\(indent)</trk>\n")
    }

    func writeExtensions(_ node: GPXXMLNode) async throws {
        try await write(node: node)
    }

    func finish() async throws {
        try await fileWriter.write("</gpx>\n")
        try await fileWriter.close()
    }

    private func write(point: GPXPointRecord) async throws {
        let indent = currentIndent
        var attributes = " lat=\"\(point.latitude)\" lon=\"\(point.longitude)\""
        for (key, value) in point.attributes.sorted(by: { $0.key < $1.key }) {
            attributes.append(" \(key)=\"\(value.xmlEscaped())\"")
        }
        try await fileWriter.write("\(indent)<trkpt\(attributes)>\n")
        indentationLevel += 1
        if let elevation = point.elevation {
            try await fileWriter.write("\(currentIndent)<ele>\(elevation)</ele>\n")
        }
        if let timestamp = point.timestamp {
            try await fileWriter.write("\(currentIndent)<time>\(iso8601Formatter.string(from: timestamp))</time>\n")
        }
        for node in point.childNodes {
            try await write(node: node)
        }
        indentationLevel -= 1
        try await fileWriter.write("\(indent)</trkpt>\n")
    }

    private func write(node: GPXXMLNode) async throws {
        var rendered = node.render(indentation: indentationLevel)
        if !rendered.hasSuffix("\n") {
            rendered.append("\n")
        }
        try await fileWriter.write(rendered)
    }

    private var currentIndent: String { String(repeating: "\t", count: indentationLevel) }

    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

/// Ensures writes happen serially on an actor to avoid file handle races.
actor AsyncFileWriter {
    private let handle: FileHandle

    init(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        self.handle = try FileHandle(forWritingTo: url)
    }

    func write(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else { return }
        try await write(data)
    }

    func write(_ data: Data) async throws {
        try Task.checkCancellation()
        try handle.write(contentsOf: data)
    }

    func close() async throws {
        try handle.close()
    }
}

private extension String {
    func xmlEscaped() -> String {
        var output = self
        output = output.replacingOccurrences(of: "&", with: "&amp;")
        output = output.replacingOccurrences(of: "\"", with: "&quot;")
        output = output.replacingOccurrences(of: "'", with: "&apos;")
        output = output.replacingOccurrences(of: "<", with: "&lt;")
        output = output.replacingOccurrences(of: ">", with: "&gt;")
        return output
    }
}
