import CoreGraphics

/// Observe button and scroll activity for tap cancellation without subscribing to motion.
struct InputEventPolicy {
    static let monitoredTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
        .scrollWheel
    ]

    static let mask: CGEventMask = monitoredTypes.reduce(CGEventMask(0)) {
        $0 | (CGEventMask(1) << $1.rawValue)
    }
}
