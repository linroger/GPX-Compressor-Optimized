import Foundation

public enum GPXStreamEvent: Sendable {
    case header(GPXDocumentHeader)
    case metadata(GPXMetadataContainer)
    case waypoint(GPXWaypointContainer)
    case route(GPXRouteContainer)
    case extensions(GPXXMLNode)
    case trackStart(index: Int, metadata: GPXTrackMetadata)
    case trackSegment(GPXTrackSegmentPayload)
    case trackEnd(index: Int)
    case documentEnd
}
