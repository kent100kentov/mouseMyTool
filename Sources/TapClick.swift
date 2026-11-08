import Foundation

/// The physical side of the surface chooses a button; both share one recognizer/settings.
enum TapButton: String, Codable {
    case left
    case right

    static func forTouch(x: Double, rightTapEnabled: Bool) -> TapButton? {
        guard x.isFinite, (0...1).contains(x) else { return nil }
        return rightTapEnabled && x >= 0.5 ? .right : .left
    }
}

/// A sequence belongs to consecutive clicks of the same button, never alternating buttons.
struct ClickSequenceTracker {
    private var button: TapButton?
    private var point = CGPoint(x: 0, y: 0)
    private var time = -Double.infinity
    private var count: Int64 = 0

    mutating func reset() {
        button = nil
        point = CGPoint(x: 0, y: 0)
        time = -.infinity
        count = 0
    }

    mutating func next(button newButton: TapButton, at newPoint: CGPoint,
                       time newTime: Double, interval: Double) -> Int64 {
        guard newPoint.x.isFinite, newPoint.y.isFinite,
              newTime.isFinite, newTime >= 0, interval.isFinite, interval > 0 else {
            reset()
            return 1
        }
        let elapsed = newTime - time
        let distance = hypot(Double(newPoint.x - point.x), Double(newPoint.y - point.y))
        if newButton == button && elapsed >= 0 && elapsed <= interval && distance < 4 {
            // A pathological injected input stream must not overflow the event field.
            count = count == Int64.max ? Int64.max : count + 1
        } else {
            count = 1
        }
        button = newButton
        point = newPoint
        time = newTime
        return count
    }
}
