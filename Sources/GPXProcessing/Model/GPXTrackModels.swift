import Foundation

public struct GPXDocumentHeader: Sendable, Hashable {
    public var attributes: [String: String]
    public init(attributes: [String: String]) {
        self.attributes = attributes
    }
}

public struct GPXMetadataContainer: Sendable, Hashable {
    public var node: GPXXMLNode
    public init(node: GPXXMLNode) { self.node = node }
}

public struct GPXWaypointContainer: Sendable, Hashable {
    public var node: GPXXMLNode
    public init(node: GPXXMLNode) { self.node = node }
}

public struct GPXRouteContainer: Sendable, Hashable {
    public var node: GPXXMLNode
    public init(node: GPXXMLNode) { self.node = node }
}

public struct GPXTrackMetadata: Sendable, Hashable {
    public var attributes: [String: String]
    public var childNodes: [GPXXMLNode]
    public init(attributes: [String: String] = [:], childNodes: [GPXXMLNode] = []) {
        self.attributes = attributes
        self.childNodes = childNodes
    }
}

public struct GPXTrackSegmentPayload: Sendable, Hashable {
    public let trackIndex: Int
    public let segmentIndex: Int
    public let attributes: [String: String]
    public let leadingNodes: [GPXXMLNode]
    public let trailingNodes: [GPXXMLNode]
    public let points: [GPXPointRecord]

    public init(
        trackIndex: Int,
        segmentIndex: Int,
        attributes: [String: String],
        leadingNodes: [GPXXMLNode],
        trailingNodes: [GPXXMLNode],
        points: [GPXPointRecord]
    ) {
        self.trackIndex = trackIndex
        self.segmentIndex = segmentIndex
        self.attributes = attributes
        self.leadingNodes = leadingNodes
        self.trailingNodes = trailingNodes
        self.points = points
    }
}
