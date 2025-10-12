import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

typealias GPXProgressHandler = @Sendable (Int64, Int64) -> Void

final class GPXStreamingParser: NSObject {
    private let configuration: GPXProcessingConfiguration
    private var continuation: AsyncThrowingStream<GPXStreamEvent, Error>.Continuation?
    private var progressHandler: GPXProgressHandler?

    private var currentTrackIndex: Int = -1
    private var trackState: TrackState?
    private var segmentState: SegmentState?
    private var pointState: PointState?

    private var metadataStack: [GPXXMLNode.Builder] = []
    private var waypointStack: [GPXXMLNode.Builder] = []
    private var routeStack: [GPXXMLNode.Builder] = []

    private var headerEmitted = false
    private var documentHeader: GPXDocumentHeader?

    private let iso8601Parser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(configuration: GPXProcessingConfiguration) {
        self.configuration = configuration
    }

    func parse(url: URL, progress: GPXProgressHandler? = nil) -> AsyncThrowingStream<GPXStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    self.continuation = continuation
                    self.progressHandler = progress
                    let stream = try CountingInputStream(url: url) { consumed, total in
                        progress?(Int64(consumed), Int64(total))
                    }
                    let parser = XMLParser(stream: stream)
                    parser.delegate = self
                    parser.shouldProcessNamespaces = false
                    if !parser.parse() {
                        if let error = parser.parserError as NSError? {
                            throw GPXProcessingError.parsingFailure(
                                line: parser.lineNumber,
                                column: parser.columnNumber,
                                message: error.localizedDescription
                            )
                        }
                        throw GPXProcessingError.internalInconsistency("Unknown parser failure")
                    }
                    continuation.yield(.documentEnd)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: GPXProcessingError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - XMLParserDelegate

extension GPXStreamingParser: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "gpx":
            documentHeader = GPXDocumentHeader(attributes: attributeDict)
            emitHeaderIfNeeded()
        case "metadata":
            metadataStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
        case "wpt":
            waypointStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
        case "rte":
            routeStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
        case "trk":
            emitHeaderIfNeeded()
            currentTrackIndex += 1
            trackState = TrackState(index: currentTrackIndex, attributes: attributeDict)
        case "trkseg":
            guard var trackState else { return }
            ensureTrackStartEmitted()
            let segmentIndex = trackState.consumeSegmentIndex()
            segmentState = SegmentState(trackIndex: trackState.index, segmentIndex: segmentIndex, attributes: attributeDict)
            self.trackState = trackState
        case "trkpt":
            pointState = PointState(attributes: attributeDict)
        default:
            if pointState != nil {
                pointState?.childBuilderStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            } else if segmentState != nil {
                segmentState?.builderStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            } else if trackState != nil {
                trackState?.builderStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            } else if !metadataStack.isEmpty {
                metadataStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            } else if !waypointStack.isEmpty {
                waypointStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            } else if !routeStack.isEmpty {
                routeStack.append(GPXXMLNode.Builder(name: elementName, attributes: attributeDict))
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !string.isEmpty else { return }
        if let builder = pointState?.childBuilderStack.popLast() {
            builder.append(text: string)
            pointState?.childBuilderStack.append(builder)
        } else if let builder = segmentState?.builderStack.popLast() {
            builder.append(text: string)
            segmentState?.builderStack.append(builder)
        } else if let builder = trackState?.builderStack.popLast() {
            builder.append(text: string)
            trackState?.builderStack.append(builder)
        } else if let builder = metadataStack.popLast() {
            builder.append(text: string)
            metadataStack.append(builder)
        } else if let builder = waypointStack.popLast() {
            builder.append(text: string)
            waypointStack.append(builder)
        } else if let builder = routeStack.popLast() {
            builder.append(text: string)
            routeStack.append(builder)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "metadata":
            if let node = popNode(from: &metadataStack) {
                continuation?.yield(.metadata(GPXMetadataContainer(node: node)))
            }
        case "wpt":
            if let node = popNode(from: &waypointStack) {
                continuation?.yield(.waypoint(GPXWaypointContainer(node: node)))
            }
        case "rte":
            if let node = popNode(from: &routeStack) {
                continuation?.yield(.route(GPXRouteContainer(node: node)))
            }
        case "trk":
            if let trackState {
                ensureTrackStartEmitted()
                continuation?.yield(.trackEnd(index: trackState.index))
            }
            trackState = nil
        case "trkseg":
            guard var segmentState else { return }
            while let builder = segmentState.builderStack.popLast() {
                append(segmentNode: builder.build(), to: &segmentState)
            }
            let payload = segmentState.makePayload()
            continuation?.yield(.trackSegment(payload))
            self.segmentState = nil
        case "trkpt":
            guard var segmentState, var pointState else { return }
            while let builder = pointState.childBuilderStack.popLast() {
                pointState.append(node: builder.build(), using: iso8601Parser)
            }
            if let record = pointState.build(using: iso8601Parser) {
                segmentState.points.append(record)
                segmentState.seenPoint = true
            }
            self.segmentState = segmentState
            self.pointState = nil
        default:
            if var pointState {
                if let builder = pointState.childBuilderStack.popLast() {
                    let node = builder.build()
                    pointState.append(node: node, using: iso8601Parser)
                }
                self.pointState = pointState
            } else if var segmentState {
                if let builder = segmentState.builderStack.popLast() {
                    append(segmentNode: builder.build(), to: &segmentState)
                }
                self.segmentState = segmentState
            } else if var trackState {
                if let builder = trackState.builderStack.popLast() {
                    trackState.childNodes.append(builder.build())
                }
                self.trackState = trackState
            } else if metadataStack.count > 1 {
                mergeTopNode(into: &metadataStack)
            } else if waypointStack.count > 1 {
                mergeTopNode(into: &waypointStack)
            } else if routeStack.count > 1 {
                mergeTopNode(into: &routeStack)
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        continuation?.finish(throwing: parseError)
    }
}

// MARK: - Private helpers

private extension GPXStreamingParser {
    func emitHeaderIfNeeded() {
        guard !headerEmitted, let header = documentHeader else { return }
        continuation?.yield(.header(header))
        headerEmitted = true
    }

    func ensureTrackStartEmitted() {
        guard var trackState else { return }
        if !trackState.didEmitStart {
            continuation?.yield(.trackStart(index: trackState.index, metadata: GPXTrackMetadata(attributes: trackState.attributes, childNodes: trackState.childNodes)))
            trackState.didEmitStart = true
            self.trackState = trackState
        }
    }

    func append(segmentNode node: GPXXMLNode, to segment: inout SegmentState) {
        if segment.seenPoint {
            segment.trailingNodes.append(node)
        } else {
            segment.leadingNodes.append(node)
        }
    }

    func popNode(from stack: inout [GPXXMLNode.Builder]) -> GPXXMLNode? {
        guard let builder = stack.popLast() else { return nil }
        if var parent = stack.popLast() {
            parent.append(child: builder.build())
            stack.append(parent)
            return nil
        }
        return builder.build()
    }

    func mergeTopNode(into stack: inout [GPXXMLNode.Builder]) {
        guard let child = stack.popLast() else { return }
        if var parent = stack.popLast() {
            parent.append(child: child.build())
            stack.append(parent)
        }
    }
}

// MARK: - State containers

private struct TrackState {
    let index: Int
    var attributes: [String: String]
    var childNodes: [GPXXMLNode] = []
    var builderStack: [GPXXMLNode.Builder] = []
    var didEmitStart = false
    private var nextSegmentIndex: Int = 0

    init(index: Int, attributes: [String: String]) {
        self.index = index
        self.attributes = attributes
    }

    mutating func consumeSegmentIndex() -> Int {
        defer { nextSegmentIndex += 1 }
        return nextSegmentIndex
    }
}

private struct SegmentState {
    let trackIndex: Int
    let segmentIndex: Int
    var attributes: [String: String]
    var leadingNodes: [GPXXMLNode] = []
    var trailingNodes: [GPXXMLNode] = []
    var builderStack: [GPXXMLNode.Builder] = []
    var points: [GPXPointRecord] = []
    var seenPoint = false

    func makePayload() -> GPXTrackSegmentPayload {
        GPXTrackSegmentPayload(
            trackIndex: trackIndex,
            segmentIndex: segmentIndex,
            attributes: attributes,
            leadingNodes: leadingNodes,
            trailingNodes: trailingNodes,
            points: points
        )
    }
}

private struct PointState {
    var attributes: [String: String]
    var childBuilderStack: [GPXXMLNode.Builder] = []
    var childNodes: [GPXXMLNode] = []
    var elevation: Double?
    var timestamp: Date?

    mutating func append(node: GPXXMLNode, using formatter: ISO8601DateFormatter) {
        switch node.name {
        case "ele":
            elevation = Double(node.text ?? "")
        case "time":
            if let text = node.text { timestamp = formatter.date(from: text) }
        default:
            childNodes.append(node)
        }
    }

    mutating func build(using formatter: ISO8601DateFormatter) -> GPXPointRecord? {
        guard let latString = attributes["lat"], let lonString = attributes["lon"],
              let latitude = Double(latString), let longitude = Double(lonString) else { return nil }
        return GPXPointRecord(
            latitude: latitude,
            longitude: longitude,
            elevation: elevation,
            timestamp: timestamp,
            attributes: attributes.filter { $0.key != "lat" && $0.key != "lon" },
            childNodes: childNodes
        )
    }
}
