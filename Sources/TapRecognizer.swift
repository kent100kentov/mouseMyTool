import Foundation

struct Touch {
    let id: Int32
    let state: Int32
    let x: Double
    let y: Double
}

enum TapRejection: String, CaseIterable {
    case invalidTime = "Некорректное время кадра"
    case stale = "Пропущены кадры касания"
    case interference = "Прокрутка или физическое нажатие"
    case multipleFingers = "Несколько пальцев"
    case releaseMovement = "Смещение при отпускании"
    case invalidCoordinates = "Некорректные координаты"
    case edge = "Касание у края"
    case tooShort = "Слишком короткое касание"
    case tooLong = "Слишком долгое касание"
    case identity = "Смена контакта"
    case movement = "Движение пальца"
    case pointerMovement = "Движение курсора"
    case invalidFrame = "Невалидный или задержанный кадр"
}

/// All methods run on the main thread. One instance per physical device.
struct TapRecognizer {
    private(set) var settings: TapSettings
    private(set) var lastRejection: TapRejection?
    private(set) var lastTapX: Double?
    private var armed = false
    private var blocked = true // Require an empty frame before accepting the first gesture.
    private var rejectionReported = false
    private var identity: Int32 = 0
    private var start = 0.0
    private var origin = (x: 0.0, y: 0.0)
    private var lastTime = -Double.infinity

    init(settings: TapSettings = .fast) { self.settings = settings.sanitized }

    var isActive: Bool { armed }

    // Preserve the existing tuning properties for callers that configure a recognizer directly.
    var maxDuration: Double {
        get { settings.maxDuration }
        set { settings.maxDuration = newValue; settings = settings.sanitized }
    }
    var maxMovement: Double {
        get { settings.maxMovement }
        set { settings.maxMovement = newValue; settings = settings.sanitized }
    }

    mutating func cancel(reason: TapRejection? = nil) {
        lastTapX = nil
        if let reason, !rejectionReported { lastRejection = reason; rejectionReported = true }
        armed = false; blocked = true
    }

    /// Pointer events between gestures must not discard a previously clean baseline.
    /// While a touch is in progress, interference still blocks it until lift.
    mutating func cancelIfActive(reason: TapRejection? = nil) { if armed { cancel(reason: reason) } }

    mutating func frame(_ touches: [Touch], time: Double, interference: Bool) -> Bool {
        lastRejection = nil
        lastTapX = nil
        guard time.isFinite, time >= lastTime else { cancel(reason: .invalidTime); return false }
        // The framework may send no frames while the mouse surface is empty.
        // Only an interrupted active gesture is stale; an idle gap is normal.
        if armed && time - lastTime > max(0.5, maxDuration) { cancel(reason: .stale) }
        lastTime = time
        guard !interference else { cancel(reason: .interference); return false }
        // Hover / lingering contacts do not count; break-touch is a release frame.
        let active = touches.filter { $0.state == 3 || $0.state == 4 }
        guard active.count <= 1 else { cancel(reason: .multipleFingers); return false }
        if armed, let terminal = touches.first(where: { $0.id == identity && $0.state == 5 }),
           (!terminal.x.isFinite || !terminal.y.isFinite || hypot(terminal.x-origin.x, terminal.y-origin.y) > maxMovement) {
            cancel(reason: .releaseMovement)
        }
        if active.isEmpty {
            let duration = time - start
            let accepted = armed && !blocked && duration >= settings.minDuration && duration <= maxDuration
            if armed && !blocked && !accepted {
                cancel(reason: duration < settings.minDuration ? .tooShort : .tooLong)
            }
            if accepted { lastTapX = origin.x }
            armed = false; blocked = false; rejectionReported = false
            return accepted
        }
        let t = active[0]
        guard t.x.isFinite, t.y.isFinite, (0...1).contains(t.x), (0...1).contains(t.y) else {
            cancel(reason: .invalidCoordinates); return false
        }
        let allowed = settings.edgeMargin...(1-settings.edgeMargin)
        guard allowed.contains(t.x), allowed.contains(t.y) else {
            cancel(reason: .edge); return false
        }
        guard !blocked else { return false }
        if !armed {
            // A confirmed empty baseline proves this is a new contact even if
            // the device omits the transient make-touch (3) frame. Startup is
            // still blocked until a release/empty frame is observed.
            armed = true; identity = t.id; start = time; origin = (t.x,t.y)
        } else if t.id != identity {
            cancel(reason: .identity)
        } else if time - start > maxDuration {
            cancel(reason: .tooLong)
        } else if hypot(t.x-origin.x,t.y-origin.y) > maxMovement {
            cancel(reason: .movement)
        }
        return false
    }
}
