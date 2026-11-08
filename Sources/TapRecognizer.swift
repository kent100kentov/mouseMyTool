import Foundation

struct Touch {
    let id: Int32
    let state: Int32
    let x: Double
    let y: Double
}

/// All methods run on the main thread. One instance per physical device.
struct TapRecognizer {
    var maxDuration = 0.24
    var maxMovement = 0.035
    private var armed = false
    private var blocked = true // Require an empty frame before accepting the first gesture.
    private var identity: Int32 = 0
    private var start = 0.0
    private var origin = (x: 0.0, y: 0.0)
    private var lastTime = -Double.infinity

    mutating func cancel() { armed = false; blocked = true }

    mutating func frame(_ touches: [Touch], time: Double, interference: Bool) -> Bool {
        guard time.isFinite, time >= lastTime else { cancel(); return false }
        if time - lastTime > 0.5 { cancel() }
        lastTime = time
        guard !interference else { cancel(); return false }
        // Hover / lingering contacts do not count; break-touch is a release frame.
        let active = touches.filter { $0.state == 3 || $0.state == 4 }
        guard active.count <= 1 else { cancel(); return false }
        if armed, let terminal = touches.first(where: { $0.id == identity && $0.state == 5 }),
           (!terminal.x.isFinite || !terminal.y.isFinite || hypot(terminal.x-origin.x, terminal.y-origin.y) > maxMovement) {
            cancel()
        }
        if active.isEmpty {
            let accepted = armed && !blocked && time - start >= 0.025 && time - start <= maxDuration
            armed = false; blocked = false
            return accepted
        }
        let t = active[0]
        guard t.x.isFinite, t.y.isFinite, (0.04...0.96).contains(t.x), (0.04...0.96).contains(t.y) else {
            cancel(); return false
        }
        guard !blocked else { return false }
        if !armed {
            // Do not accept a contact that was already down when listening started.
            guard t.state == 3 else { cancel(); return false }
            armed = true; identity = t.id; start = time; origin = (t.x,t.y)
        } else if t.id != identity || time - start > maxDuration || hypot(t.x-origin.x,t.y-origin.y) > maxMovement {
            cancel()
        }
        return false
    }
}
