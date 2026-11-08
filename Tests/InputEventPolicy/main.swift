import CoreGraphics

var checks = 0
func expect(_ result: Bool, _ message: String) {
    guard result else { fatalError("FAIL: \(message)") }
    checks += 1
}
func observes(_ type: CGEventType) -> Bool {
    let bit = type.rawValue
    return bit < 64 && (InputEventPolicy.mask & (CGEventMask(1) << bit)) != 0
}

// Quartz event numbers: down/up for left 1/2, right 3/4, other 25/26; scroll 22.
let expectedMask: CGEventMask = 0x0640001E
expect(InputEventPolicy.mask == expectedMask, "mask contains only physical buttons and scroll")
expect(InputEventPolicy.monitoredTypes.count == 7, "seven monitored event types")
expect(Set(InputEventPolicy.monitoredTypes.map(\.rawValue)).count == 7, "no duplicate subscriptions")
for type in [CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp, .scrollWheel] {
    expect(observes(type), "button/scroll cancellation includes \(type.rawValue)")
}
for type in [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
    expect(!observes(type), "cursor motion is not subscribed: \(type.rawValue)")
}
for type in [CGEventType.keyDown, .keyUp, .flagsChanged, .null,
             .tapDisabledByTimeout, .tapDisabledByUserInput] {
    expect(!observes(type), "unrelated or administrative events excluded: \(type.rawValue)")
}
print("PASS: \(checks) input event policy checks; no taps installed or input read")
