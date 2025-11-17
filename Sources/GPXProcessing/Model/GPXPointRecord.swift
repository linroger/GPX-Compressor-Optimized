import Foundation

/// Representation of a single GPX point optimised for concurrent processing.
public struct GPXPointRecord: Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double?
    public let timestamp: Date?
    public let attributes: [String: String]
    public let childNodes: [GPXXMLNode]

    public init(
        latitude: Double,
        longitude: Double,
        elevation: Double?,
        timestamp: Date?,
        attributes: [String: String] = [:],
        childNodes: [GPXXMLNode] = []
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.timestamp = timestamp
        self.attributes = attributes
        self.childNodes = childNodes
    }

    /// Distance squared in metres between this point and another.
    /// Computed using a fast approximation relying on the Haversine implementation in the compression utilities.
    func distanceSquared(to other: GPXPointRecord) -> Double {
        GPXDistance.approximateSquaredDistance(
            lat1: latitude,
            lon1: longitude,
            lat2: other.latitude,
            lon2: other.longitude
        )
    }
}
