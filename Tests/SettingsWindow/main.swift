import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var received: TapSettings?
let settingsWindow = TapSettingsWindow(settings: .fast) { received = $0 }
let content = settingsWindow.window!.contentView!
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
let allViews = descendants(content)
let sliders = allViews.compactMap { $0 as? NSSlider }.sorted { $0.tag < $1.tag }
let profiles = allViews.compactMap { $0 as? NSPopUpButton }.first!
var checks = 0
func expect(_ result: Bool, _ message: String) {
    guard result else { fatalError("FAIL: \(message)") }
    checks += 1
}
expect(sliders.count == 5,"five sensitivity sliders")
expect(sliders[0].doubleValue == 8,"fast default shows 8ms minimum")
expect(sliders[4].doubleValue == 12,"fast default shows 12ms delay")
sliders[0].doubleValue = 2
_ = sliders[0].sendAction(sliders[0].action!, to: sliders[0].target)
expect(received?.minDuration == 0.002,"slider applies 2ms immediately")
expect(profiles.indexOfSelectedItem == 3,"manual change marks custom profile")
profiles.selectItem(at: 2)
_ = profiles.sendAction(profiles.action!, to: profiles.target)
expect(received == .careful,"careful preset applies all settings")
expect(sliders[0].doubleValue == 25 && sliders[3].doubleValue == 0,"preset refreshes sliders")
profiles.selectItem(at: 0)
_ = profiles.sendAction(profiles.action!, to: profiles.target)
expect(received == .fast,"fast preset restores responsive defaults")
content.layoutSubtreeIfNeeded()
let labels = allViews.compactMap { $0 as? NSTextField }
expect(labels.allSatisfy { content.bounds.insetBy(dx:-1,dy:-1).contains($0.convert($0.bounds,to:content)) },"all setting labels fit inside window")
print("PASS: \(checks) native sensitivity window checks; no clicks posted")
