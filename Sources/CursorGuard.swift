import Foundation

/// Tracks total cursor displacement from the beginning of each active contact.
/// Small individual movements never shift the baseline, so a slow drag still cancels.
struct CursorGuard {
    private var origins: [UInt64: CGPoint] = [:]
    var hasActiveContacts: Bool { !origins.isEmpty }

    mutating func begin(device: UInt64, at point: CGPoint) {
        guard origins[device] == nil else { return }
        origins[device] = point
    }

    func movedDevices(to point: CGPoint, tolerance: Double) -> [UInt64] {
        // Invalid data cancels all active contacts rather than allowing a click.
        guard point.x.isFinite, point.y.isFinite, tolerance.isFinite, tolerance >= 0,
              origins.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return origins.keys.sorted()
        }
        return origins.compactMap { device, origin in
            let distance = hypot(Double(point.x - origin.x), Double(point.y - origin.y))
            return distance > tolerance ? device : nil
        }.sorted()
    }

    mutating func end(device: UInt64) {
        origins.removeValue(forKey: device)
    }

    mutating func reset() {
        origins.removeAll()
    }
}
