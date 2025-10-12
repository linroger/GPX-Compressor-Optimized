import Foundation

struct RamerDouglasPeucker {
    static func simplify(points: [GPXPointRecord], epsilon: Double) -> [GPXPointRecord] {
        guard points.count > 2 else { return points }
        var result: [GPXPointRecord] = []
        simplify(points: points, epsilonSquared: epsilon * epsilon, result: &result)
        return result
    }

    private static func simplify(points: [GPXPointRecord], epsilonSquared: Double, result: inout [GPXPointRecord]) {
        guard let first = points.first, let last = points.last else { return }
        var index = 0
        var maxDistance = 0.0

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistanceSquared(point: points[i], lineStart: first, lineEnd: last)
            if distance > maxDistance {
                index = i
                maxDistance = distance
            }
        }

        if maxDistance > epsilonSquared {
            let prefix = Array(points[0...index])
            let suffix = Array(points[index...])
            simplify(points: prefix, epsilonSquared: epsilonSquared, result: &result)
            result.removeLast() // avoid duplicating the pivot point
            simplify(points: suffix, epsilonSquared: epsilonSquared, result: &result)
        } else {
            result.append(first)
            result.append(last)
        }
    }

    private static func perpendicularDistanceSquared(point: GPXPointRecord, lineStart: GPXPointRecord, lineEnd: GPXPointRecord) -> Double {
        if lineStart.latitude == lineEnd.latitude && lineStart.longitude == lineEnd.longitude {
            return point.distanceSquared(to: lineStart)
        }

        let startLat = lineStart.latitude
        let startLon = lineStart.longitude
        let endLat = lineEnd.latitude
        let endLon = lineEnd.longitude
        let pointLat = point.latitude
        let pointLon = point.longitude

        let lineLat = endLat - startLat
        let lineLon = endLon - startLon
        let lineLengthSquared = lineLat * lineLat + lineLon * lineLon
        if lineLengthSquared == 0 { return point.distanceSquared(to: lineStart) }

        let projectionFactor = max(0.0, min(1.0, ((pointLat - startLat) * lineLat + (pointLon - startLon) * lineLon) / lineLengthSquared))
        let projectionLat = startLat + projectionFactor * lineLat
        let projectionLon = startLon + projectionFactor * lineLon
        let approxDistance = GPXDistance.approximateSquaredDistance(lat1: pointLat, lon1: pointLon, lat2: projectionLat, lon2: projectionLon)
        let dLat = projectionLat - pointLat
        let dLon = projectionLon - pointLon
        return approxDistance + dLat * dLat + dLon * dLon
    }
}
