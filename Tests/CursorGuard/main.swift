import Foundation

var checks = 0
func expect(_ condition: Bool, _ name: String) {
    guard condition else { fatalError("FAIL: \(name)") }
    checks += 1
}

var guardState = CursorGuard()
guardState.begin(device: 1, at: CGPoint(x: 100, y: 100))
expect(guardState.movedDevices(to: CGPoint(x: 100.1, y: 99.9), tolerance: 8).isEmpty, "subpoint jitter")
expect(guardState.movedDevices(to: CGPoint(x: 104, y: 103), tolerance: 8).isEmpty, "small cursor movement")
expect(guardState.movedDevices(to: CGPoint(x: 108, y: 100), tolerance: 8).isEmpty, "exact boundary allowed")
expect(guardState.movedDevices(to: CGPoint(x: 108.1, y: 100), tolerance: 8) == [1], "over boundary cancelled")
expect(guardState.movedDevices(to: CGPoint(x: 106, y: 106), tolerance: 8) == [1], "diagonal displacement")
// Repeated begin calls and small movements must not shift the original baseline.
guardState.begin(device: 1, at: CGPoint(x: 107, y: 100))
expect(guardState.movedDevices(to: CGPoint(x: 109, y: 100), tolerance: 8) == [1], "accumulated displacement from original start")
expect(guardState.movedDevices(to: CGPoint(x: 100, y: 100), tolerance: 0).isEmpty, "zero tolerance exact origin")
expect(guardState.movedDevices(to: CGPoint(x: 100.001, y: 100), tolerance: 0) == [1], "zero tolerance any motion")

guardState.begin(device: 2, at: CGPoint(x: 109, y: 100))
expect(guardState.movedDevices(to: CGPoint(x: 109, y: 100), tolerance: 8) == [1], "independent device origins")
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 8) == [1, 2], "both devices moved")
guardState.end(device: 1)
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 8) == [2], "end removes only matching device")
guardState.end(device: 999)
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 8) == [2], "ending unknown device is safe")
guardState.reset()
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 8).isEmpty, "reset removes all baselines")
guardState.begin(device: 2, at: CGPoint(x: 130, y: 100))
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 0).isEmpty, "new contact gets a fresh baseline")

expect(guardState.movedDevices(to: CGPoint(x: CGFloat.nan, y: 100), tolerance: 8) == [2], "NaN cursor cancels")
expect(guardState.movedDevices(to: CGPoint(x: 130, y: CGFloat.infinity), tolerance: 8) == [2], "infinite cursor cancels")
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: .nan) == [2], "NaN tolerance cancels")
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: .infinity) == [2], "infinite tolerance cancels")
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: -1) == [2], "negative tolerance cancels")
guardState.begin(device: 3, at: CGPoint(x: CGFloat.nan, y: 100))
expect(guardState.movedDevices(to: CGPoint(x: 130, y: 100), tolerance: 8) == [2, 3], "invalid origin cancels every active device")
guardState.reset()
expect(guardState.movedDevices(to: CGPoint(x: CGFloat.nan, y: 100), tolerance: .nan).isEmpty, "invalid data with no active devices")
print("PASS: \(checks) cursor movement checks")
