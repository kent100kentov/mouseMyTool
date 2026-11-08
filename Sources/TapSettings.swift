import Foundation

/// Durations use seconds, surface distances are normalized, cursor distance uses points.
struct TapSettings: Codable, Equatable {
    var minDuration: Double
    var maxDuration: Double
    var maxMovement: Double
    var edgeMargin: Double
    var cursorTolerance: Double
    var clickDelay: Double
    var rightTapEnabled: Bool

    init(minDuration: Double = 0.002, maxDuration: Double = 0.35,
         maxMovement: Double = 0.07, edgeMargin: Double = 0.02,
         cursorTolerance: Double = 8, clickDelay: Double = 0.008,
         rightTapEnabled: Bool = true) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.maxMovement = maxMovement
        self.edgeMargin = edgeMargin
        self.cursorTolerance = cursorTolerance
        self.clickDelay = clickDelay
        self.rightTapEnabled = rightTapEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case minDuration, maxDuration, maxMovement, edgeMargin, cursorTolerance, clickDelay, rightTapEnabled
    }

    /// Existing six-field settings retain their tuning when right-tap support is added.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            minDuration: try values.decodeIfPresent(Double.self, forKey: .minDuration) ?? Self.fast.minDuration,
            maxDuration: try values.decodeIfPresent(Double.self, forKey: .maxDuration) ?? Self.fast.maxDuration,
            maxMovement: try values.decodeIfPresent(Double.self, forKey: .maxMovement) ?? Self.fast.maxMovement,
            edgeMargin: try values.decodeIfPresent(Double.self, forKey: .edgeMargin) ?? Self.fast.edgeMargin,
            cursorTolerance: try values.decodeIfPresent(Double.self, forKey: .cursorTolerance) ?? Self.fast.cursorTolerance,
            clickDelay: try values.decodeIfPresent(Double.self, forKey: .clickDelay) ?? Self.fast.clickDelay,
            rightTapEnabled: try values.decodeIfPresent(Bool.self, forKey: .rightTapEnabled) ?? true
        )
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
            clickDelay: clamp(clickDelay, 0...0.06, fallback: Self.fast.clickDelay),
            rightTapEnabled: rightTapEnabled
        )
    }
}
