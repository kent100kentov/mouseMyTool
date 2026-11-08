import Foundation

var checks = 0
func expect(_ condition: Bool, _ name: String) {
    guard condition else { fatalError("FAIL: \(name)") }
    checks += 1
}

expect(TapButton.forTouch(x: 0, rightTapEnabled: true) == .left, "left boundary")
expect(TapButton.forTouch(x: 0.499999, rightTapEnabled: true) == .left, "just left of midpoint")
expect(TapButton.forTouch(x: 0.5, rightTapEnabled: true) == .right, "midpoint starts right half")
expect(TapButton.forTouch(x: 1, rightTapEnabled: true) == .right, "right boundary")
expect(TapButton.forTouch(x: 0.2, rightTapEnabled: false) == .left, "disabled right tap keeps left side left")
expect(TapButton.forTouch(x: 0.8, rightTapEnabled: false) == .left, "disabled right tap makes whole surface left")
for x in [Double.nan, Double.infinity, -Double.infinity, -0.001, 1.001] {
    expect(TapButton.forTouch(x: x, rightTapEnabled: true) == nil, "invalid touch coordinate rejected: \(x)")
}

var tracker = ClickSequenceTracker()
let origin = CGPoint(x: 100, y: 100)
func next(_ button: TapButton, _ time: Double, point: CGPoint = origin, interval: Double = 0.5) -> Int64 {
    tracker.next(button: button, at: point, time: time, interval: interval)
}
expect(next(.left, 1) == 1, "first left click")
expect(next(.left, 1.2) == 2, "left double click")
expect(next(.left, 1.3) == 3, "left triple click")
expect(next(.right, 1.4) == 1, "switching to right starts a new sequence")
expect(next(.right, 1.5) == 2, "right double click shares same timing")
expect(next(.left, 1.6) == 1, "right to left never doubles left")
expect(next(.right, 1.7) == 1, "alternating left right left stays single")
expect(next(.left, 1.8) == 1, "alternating right left right stays single")
expect(next(.left, 2.3) == 2, "exact system interval boundary accepted")
expect(next(.left, 2.801) == 1, "click beyond interval starts new sequence")
expect(next(.left, 3, point: CGPoint(x: 103.999, y: 100)) == 2, "movement just below 4 points accepted")
expect(next(.left, 3.1, point: CGPoint(x: 107.999, y: 100)) == 1, "4 point movement resets sequence")
expect(next(.left, 3.2, point: CGPoint(x: 110.999, y: 103)) == 1, "diagonal movement uses total distance")
tracker.reset()
expect(next(.right, 4) == 1, "explicit reset clears prior sequence")
expect(next(.right, 4.1) == 2, "right sequence after reset")
expect(next(.right, 3.5) == 1, "reversed clock resets sequence")
expect(next(.right, 3.6) == 2, "clock can establish a new monotonic sequence")

for invalidTime in [Double.nan, Double.infinity, -Double.infinity, -1] {
    expect(next(.left, invalidTime) == 1, "invalid time does not aggregate")
    expect(next(.left, 5) == 1, "invalid time clears prior sequence")
}
for invalidPoint in [CGPoint(x: CGFloat.nan, y: 100), CGPoint(x: 100, y: CGFloat.infinity)] {
    expect(next(.left, 5.1, point: invalidPoint) == 1, "invalid position does not aggregate")
    expect(next(.left, 5.2) == 1, "invalid position clears prior sequence")
}
for invalidInterval in [Double.nan, Double.infinity, -1, 0] {
    expect(next(.left, 5.3, interval: invalidInterval) == 1, "invalid interval does not aggregate")
    expect(next(.left, 5.4) == 1, "invalid interval clears prior sequence")
}
let encoded = try! JSONEncoder().encode(TapButton.right)
expect(try! JSONDecoder().decode(TapButton.self, from: encoded) == .right, "button Codable roundtrip")
print("PASS: \(checks) button routing and click sequence checks")
