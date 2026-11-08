import Foundation

/// Durations use seconds, surface distances are normalized, cursor distance uses points.
struct TapSettings: Codable, Equatable {
    var minDuration: Double
    var maxDuration: Double
    var maxMovement: Double
    var edgeMargin: Double
    var cursorTolerance: Double
    var clickDelay: Double

    init(minDuration: Double = 0.008, maxDuration: Double = 0.35,
         maxMovement: Double = 0.07, edgeMargin: Double = 0.02,
         cursorTolerance: Double = 8, clickDelay: Double = 0.012) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.maxMovement = maxMovement
        self.edgeMargin = edgeMargin
        self.cursorTolerance = cursorTolerance
        self.clickDelay = clickDelay
    }

    static let fast = TapSettings()
    static let balanced = TapSettings(minDuration: 0.015, maxDuration: 0.30,
                                      maxMovement: 0.05, edgeMargin: 0.02,
                                      cursorTolerance: 4, clickDelay: 0.02)
    static let careful = TapSettings(minDuration: 0.025, maxDuration: 0.24,
                                     maxMovement: 0.035, edgeMargin: 0.04,
                                     cursorTolerance: 0, clickDelay: 0.04)

    /// Clamp persisted/UI values and replace nonfinite values with safe defaults.
    var sanitized: TapSettings {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        return TapSettings(
            minDuration: clamp(minDuration, 0...0.04, fallback: Self.fast.minDuration),
            maxDuration: clamp(maxDuration, 0.1...0.6, fallback: Self.fast.maxDuration),
            maxMovement: clamp(maxMovement, 0.01...0.15, fallback: Self.fast.maxMovement),
            edgeMargin: clamp(edgeMargin, 0...0.08, fallback: Self.fast.edgeMargin),
            cursorTolerance: clamp(cursorTolerance, 0...20, fallback: Self.fast.cursorTolerance),
            clickDelay: clamp(clickDelay, 0...0.06, fallback: Self.fast.clickDelay)
        )
    }
}
