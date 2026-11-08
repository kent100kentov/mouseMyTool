import CoreGraphics

/// Constructs matching button events without posting them or reading input.
struct MouseClickEvents {
    static func make(button: TapButton, at point: CGPoint, clickCount: Int64,
                     flags: CGEventFlags, tag: Int64) -> (down: CGEvent, up: CGEvent)? {
        guard point.x.isFinite, point.y.isFinite, clickCount >= 1,
              let source = CGEventSource(stateID: .hidSystemState) else { return nil }
        // Synthetic tap clicks must never suppress ordinary hardware input.
        // Configure this source explicitly rather than relying on system defaults.
        source.localEventsSuppressionInterval = 0
        let permitted: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(permitted, state: .eventSuppressionStateSuppressionInterval)
        source.setLocalEventsFilterDuringSuppressionState(permitted, state: .eventSuppressionStateRemoteMouseDrag)
        let mouseButton: CGMouseButton = button == .right ? .right : .left
        let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
        guard let down = CGEvent(mouseEventSource: source, mouseType: downType,
                                 mouseCursorPosition: point, mouseButton: mouseButton),
              let up = CGEvent(mouseEventSource: source, mouseType: upType,
                               mouseCursorPosition: point, mouseButton: mouseButton) else { return nil }
        for event in [down, up] {
            event.setIntegerValueField(.eventSourceUserData, value: tag)
            event.setIntegerValueField(.mouseEventClickState, value: clickCount)
            event.flags = flags
        }
        return (down, up)
    }
}
