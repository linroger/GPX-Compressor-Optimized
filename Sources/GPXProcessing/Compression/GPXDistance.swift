import Foundation

/// High-precision geodesic helpers used by compression algorithms.
enum GPXDistance {
    private static let earthRadius: Double = 6_367_444.7

    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad = toRadians(lat1)
        let lon1Rad = toRadians(lon1)
        let lat2Rad = toRadians(lat2)
        let lon2Rad = toRadians(lon2)

        let deltaLat = lat2Rad - lat1Rad
        let deltaLon = lon2Rad - lon1Rad
        let sinLat = sin(deltaLat / 2.0)
        let sinLon = sin(deltaLon / 2.0)
        let a = sinLat * sinLat + cos(lat1Rad) * cos(lat2Rad) * sinLon * sinLon
        let c = 2.0 * asin(min(1.0, sqrt(a)))
        return earthRadius * c
    }

    static func approximateSquaredDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let distance = haversineDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        return distance * distance
    }

    private static func toRadians(_ value: Double) -> Double {
        value * Double.pi / 180.0
    }
}
