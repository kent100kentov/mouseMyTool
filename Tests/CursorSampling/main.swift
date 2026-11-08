import Foundation

// Replay the controller's sample-before-frame ordering using no native input.
struct Replay {
    var recognizer = TapRecognizer(settings: .fast)
    var cursor = CursorGuard()
    mutating func frame(_ touches: [Touch], time: Double, x: Double, y: Double = 100, physical: Bool = false) -> Bool {
        let point = CGPoint(x:x,y:y)
        if cursor.hasActiveContacts {
            if !cursor.movedDevices(to:point,tolerance:8).isEmpty {
                recognizer.cancelIfActive(reason:.pointerMovement)
                cursor.end(device:1)
            }
        }
        let wasActive = recognizer.isActive
        let accepted = recognizer.frame(touches,time:time,interference:physical)
        if recognizer.isActive && !wasActive { cursor.begin(device:1,at:point) }
        if !recognizer.isActive { cursor.end(device:1) }
        return accepted
    }
}
var checks = 0
func expect(_ result: Bool, _ message: String) {
    guard result else { fatalError("FAIL: \(message)") }; checks += 1
}
func touch(_ state: Int32 = 3) -> [Touch] { [Touch(id:1,state:state,x:0.25,y:0.5)] }
func ready() -> Replay { var r=Replay(); _=r.frame([],time:0,x:100); return r }
var idle = ready()
expect(!idle.cursor.hasActiveContacts,"idle needs no movement guard")
_ = idle.frame([],time:1,x:1000)
_ = idle.frame(touch(),time:2,x:1000)
expect(idle.frame([],time:2.01,x:1000),"idle travel never blocks later tap")
var jitter = ready()
_ = jitter.frame(touch(),time:0.1,x:100)
expect(jitter.cursor.hasActiveContacts,"tap installs sampled guard")
_ = jitter.frame(touch(4),time:0.11,x:104)
expect(jitter.frame([],time:0.12,x:108),"eight-point sampled drift accepted")
expect(!jitter.cursor.hasActiveContacts,"release removes sampled guard")
var endMove = ready()
_ = endMove.frame(touch(),time:0.1,x:100)
expect(!endMove.frame([],time:0.12,x:109),"movement on release cancels before tap is accepted")
expect(endMove.recognizer.lastTapX == nil,"movement rejection cannot emit a tap origin")
var movedBack = ready()
_ = movedBack.frame(touch(),time:0.1,x:100)
_ = movedBack.frame(touch(4),time:0.11,x:112)
expect(!movedBack.frame([],time:0.12,x:100),"sampled out-and-back remains cancelled")
var accumulated = ready()
_ = accumulated.frame(touch(),time:0.1,x:100)
_ = accumulated.frame(touch(4),time:0.11,x:104)
_ = accumulated.frame(touch(4),time:0.12,x:107)
expect(!accumulated.frame([],time:0.13,x:110),"small samples do not shift original baseline")
var physical = ready()
_ = physical.frame(touch(),time:0.1,x:100)
_ = physical.frame(touch(4),time:0.11,x:100,physical:true)
expect(!physical.frame([],time:0.12,x:100),"physical input still cancels sampled gesture")
var invalid = ready()
_ = invalid.frame(touch(),time:0.1,x:100)
expect(!invalid.frame([],time:0.12,x:.nan),"invalid cursor sample fails closed")
var recovery = ready()
_ = recovery.frame(touch(),time:0.1,x:100)
_ = recovery.frame([],time:0.12,x:120)
_ = recovery.frame(touch(),time:1,x:200)
expect(recovery.frame([],time:1.01,x:200),"fresh tap works after cancelled move")
print("PASS: \(checks) sampled cursor and touch integration checks; no native events used")
