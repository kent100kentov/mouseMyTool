import Foundation
var checks = 0
func expect(_ condition: Bool, _ name: String) {
    guard condition else { fatalError("FAIL: \(name)") }
    checks += 1
}
func touch(_ state: Int32 = 3, _ x: Double = 0.5, _ y: Double = 0.5, _ id: Int32 = 1) -> Touch {
    Touch(id:id,state:state,x:x,y:y)
}
func ready() -> TapRecognizer {
    var r = TapRecognizer(); _ = r.frame([],time:0,interference:false); return r
}
func run(_ frames: [([Touch],Double,Bool)]) -> Int {
    var r = ready(); return frames.reduce(0) { n,f in n + (r.frame(f.0,time:f.1,interference:f.2) ? 1 : 0) }
}
expect(run([([touch()],0.1,false),([],0.2,false)]) == 1,"single tap")
expect(run([([touch()],0.1,false),([touch(4)],0.15,false),([touch(5)],0.2,false),([],0.21,false)]) == 1,"release emitted once")
expect(run([([touch()],0.1,false),([],0.11,false)]) == 0,"noise too short")
expect(run([([touch()],0.1,false),([],0.4,false)]) == 0,"rest too long")
expect(run([([touch()],0.1,false),([touch(4,0.6)],0.15,false),([],0.2,false)]) == 0,"scroll movement")
expect(run([([touch(),touch(3,0.7,0.5,2)],0.1,false),([touch(4)],0.15,false),([],0.2,false)]) == 0,"multi-finger contamination")
expect(run([([touch()],0.1,false),([touch(4)],0.15,true),([],0.2,false)]) == 0,"physical click cancels")
expect(run([([touch(3,0.01)],0.1,false),([],0.2,false)]) == 0,"edge rejection")
expect(run([([touch()],0.1,false),([touch(4,0.5,0.5,2)],0.15,false),([],0.2,false)]) == 0,"identity changed")
expect(run([([touch()],0.1,false),([],1.2,false)]) == 0,"missing frames")
expect(run([([touch()],0.1,false),([],0.09,false)]) == 0,"non-monotonic timestamp")
expect(run([([touch(4)],0.1,false),([],0.2,false)]) == 1,"state-4 onset after confirmed empty baseline")
expect(run([([touch()],0.1,false),([],0.2,false),([touch()],0.3,false),([],0.4,false)]) == 2,"two taps")
expect(run([([touch(3,.nan)],0.1,false),([],0.2,false)]) == 0,"invalid coordinates")
expect(run([([touch()],0.1,false),([touch(5,0.8)],0.2,false)]) == 0,"movement on final frame")
var r = ready(); _ = r.frame([touch()],time:0.1,interference:false); r.cancel()
expect(!r.frame([],time:0.2,interference:false),"disable cancels pending gesture")
// Real devices may stop callbacks entirely while idle, and their clock starts at uptime.
expect(run([([touch()],2.0,false),([],2.1,false)]) == 1,"tap after idle gap")
expect(run([([touch()],2.0,false),([],2.1,false),([touch()],4.0,false),([],4.1,false),([touch()],6.0,false),([],6.1,false)]) == 3,"repeated isolated taps")
expect(run([([touch()],0.1,false),([touch()],2.0,false),([],2.1,false)]) == 0,"stale active touch still blocked")
expect(run([([touch()],0.1,false),([],2.0,false),([touch()],4.0,false),([],4.1,false)]) == 1,"fresh tap after stale release and idle")
var movedWhileIdle = ready()
movedWhileIdle.cancelIfActive()
_ = movedWhileIdle.frame([touch()],time:2,interference:false)
expect(movedWhileIdle.frame([],time:2.1,interference:false),"pointer movement while idle preserves baseline")
var movedDuringTap = ready()
_ = movedDuringTap.frame([touch()],time:0.1,interference:false)
movedDuringTap.cancelIfActive()
expect(!movedDuringTap.frame([],time:0.2,interference:false),"pointer movement during tap cancels")
var resetWhileIdle = ready()
resetWhileIdle.cancel()
_ = resetWhileIdle.frame([touch()],time:2,interference:false)
expect(!resetWhileIdle.frame([],time:2.1,interference:false),"explicit reset still requires clean baseline")
expect(run([([touch()],0.1,true),([touch(4)],0.3,false),([],0.35,false)]) == 0,"interference on initial down remains blocked")
var firstContact = TapRecognizer()
_ = firstContact.frame([touch()],time:100,interference:false)
expect(!firstContact.frame([],time:100.1,interference:false),"startup with no baseline ignores first gesture")
var restingAtStartup = TapRecognizer()
_ = restingAtStartup.frame([touch(4)],time:100,interference:false)
expect(!restingAtStartup.frame([],time:100.1,interference:false),"resting state-4 contact at startup is ignored")
print("PASS: \(checks) recognizer checks")
