import CoreGraphics

var checks = 0
func expect(_ condition: Bool, _ message: String) {
    guard condition else { fatalError("FAIL: \(message)") }
    checks += 1
}
let point = CGPoint(x: 123.5, y: 456.25)
let flags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
let tag: Int64 = 0x4D544150
for button in [TapButton.left, .right] {
    let pair = MouseClickEvents.make(button: button, at: point, clickCount: 2, flags: flags, tag: tag)
    expect(pair != nil, "\(button) event pair can be constructed")
    guard let pair else { fatalError("missing event pair") }
    expect(pair.down.type == (button == .right ? .rightMouseDown : .leftMouseDown), "\(button) down type")
    expect(pair.up.type == (button == .right ? .rightMouseUp : .leftMouseUp), "\(button) up type")
    for event in [pair.down, pair.up] {
        expect(event.getIntegerValueField(.mouseEventButtonNumber) == (button == .right ? 1 : 0), "\(button) mouse button number")
        expect(event.location == point, "\(button) cursor location")
        expect(event.getIntegerValueField(.mouseEventClickState) == 2, "\(button) shared double-click count")
        expect(event.getIntegerValueField(.eventSourceUserData) == tag, "\(button) self-event tag")
        expect(event.flags == flags, "\(button) modifier flags")
    }
}
expect(MouseClickEvents.make(button: .right, at: point, clickCount: 0, flags: [], tag: tag) == nil, "zero count rejected")
expect(MouseClickEvents.make(button: .left, at: point, clickCount: -1, flags: [], tag: tag) == nil, "negative count rejected")
expect(MouseClickEvents.make(button: .right, at: CGPoint(x: CGFloat.nan, y: 0), clickCount: 1, flags: [], tag: tag) == nil, "NaN x rejected")
expect(MouseClickEvents.make(button: .left, at: CGPoint(x: 0, y: CGFloat.infinity), clickCount: 1, flags: [], tag: tag) == nil, "infinite y rejected")
let single = MouseClickEvents.make(button: .right, at: .zero, clickCount: 1, flags: [], tag: -123)
expect(single?.down.getIntegerValueField(.mouseEventClickState) == 1, "single right click preserved")
expect(single?.up.getIntegerValueField(.eventSourceUserData) == -123, "signed tag preserved")
expect(single?.up.flags == [], "no modifiers remains no modifiers")
print("PASS: \(checks) click event construction checks; no events posted")
