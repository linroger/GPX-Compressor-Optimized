import Foundation
import CoreGPX

struct SegmentCompressor {
    let configuration: GPXProcessingConfiguration

    func compress(segment: GPXTrackSegmentPayload) async throws -> GPXTrackSegmentPayload {
        try Task.checkCancellation()
        let processedPoints: [GPXPointRecord]

        switch configuration.compressionStrategy {
        case .ramerDouglasPeucker(let tolerance):
            processedPoints = RamerDouglasPeucker.simplify(points: segment.points, epsilon: tolerance)
        case .stripNearby(let distance):
            processedPoints = stripNearby(points: segment.points, radius: distance)
        case .random(let percent):
            guard configuration.enableRandomRemoval else {
                processedPoints = segment.points
                break
            }
            processedPoints = randomRemoval(points: segment.points, percent: percent)
        case .stripDuplicates:
            processedPoints = stripDuplicates(points: segment.points)
        }

        let deduped: [GPXPointRecord]
        if let radius = configuration.deduplicationRadius {
            deduped = stripNearby(points: processedPoints, radius: radius)
        } else {
            deduped = processedPoints
        }

        return GPXTrackSegmentPayload(
            trackIndex: segment.trackIndex,
            segmentIndex: segment.segmentIndex,
            attributes: segment.attributes,
            leadingNodes: segment.leadingNodes,
            trailingNodes: segment.trailingNodes,
            points: deduped
        )
    }

    private func stripNearby(points: [GPXPointRecord], radius: Double) -> [GPXPointRecord] {
        guard points.count > 1 else { return points }
        var filtered: [GPXPointRecord] = []
        filtered.reserveCapacity(points.count)
        var lastPoint: GPXPointRecord?

        for point in points {
            guard let lp = lastPoint else {
                filtered.append(point)
                lastPoint = point
                continue
            }
            let distance = GPXDistance.haversineDistance(lat1: lp.latitude, lon1: lp.longitude, lat2: point.latitude, lon2: point.longitude)
            if distance >= radius {
                filtered.append(point)
                lastPoint = point
            }
        }
        if let last = points.last, filtered.last != last {
            filtered.append(last)
        }
        return filtered
    }

    private func randomRemoval(points: [GPXPointRecord], percent: Double) -> [GPXPointRecord] {
        guard percent > 0, percent < 1 else { return points }
        let keepProbability = max(0.0, min(1.0, 1.0 - percent))
        return points.filter { _ in Double.random(in: 0...1) <= keepProbability }
    }

    private func stripDuplicates(points: [GPXPointRecord]) -> [GPXPointRecord] {
        guard points.count > 1 else { return points }
        var filtered: [GPXPointRecord] = []
        filtered.reserveCapacity(points.count)
        var lastPoint: GPXPointRecord?
        for point in points {
            if let lastPoint, lastPoint.latitude == point.latitude && lastPoint.longitude == point.longitude {
                continue
            }
            filtered.append(point)
            lastPoint = point
        }
        return filtered
    }
}
