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
expect(run([([touch(4)],0.1,false),([],0.2,false)]) == 0,"already resting on startup")
expect(run([([touch()],0.1,false),([],0.2,false),([touch()],0.3,false),([],0.4,false)]) == 2,"two taps")
expect(run([([touch(3,.nan)],0.1,false),([],0.2,false)]) == 0,"invalid coordinates")
expect(run([([touch()],0.1,false),([touch(5,0.8)],0.2,false)]) == 0,"movement on final frame")
var r = ready(); _ = r.frame([touch()],time:0.1,interference:false); r.cancel()
expect(!r.frame([],time:0.2,interference:false),"disable cancels pending gesture")
print("PASS: \(checks) recognizer checks")
