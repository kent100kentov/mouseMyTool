import AppKit
import ApplicationServices
import ServiceManagement

private let eventTag: Int64 = 0x4D544150
private var controller: AppController!

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let bridge = MTBridge()
    var status: NSStatusItem!
    let menu = NSMenu()
    var recognizers: [UInt64: TapRecognizer] = [:]
    var cursorGuard = CursorGuard()
    var pendingPoints = [UInt64: CGPoint]()
    var nextPendingID: UInt64 = 0
    var settings: TapSettings = {
        guard let data = UserDefaults.standard.data(forKey: "tapSettings"),
              let decoded = try? JSONDecoder().decode(TapSettings.self, from: data) else { return .fast }
        return decoded.sanitized
    }()
    var settingsWindow: TapSettingsWindow?
    var rejectionCounts = [TapRejection: Int]()
    var cancelledClicks = 0
    var enabled = !CommandLine.arguments.contains("--smoke-test") && UserDefaults.standard.bool(forKey: "enabled")
    var message = "Выключено"
    var eventTap: CFMachPort?
    var eventSource: CFRunLoopSource?
    var lastInterference = -Double.infinity
    var pendingGeneration: UInt64 = 0
    var reconnect: DispatchWorkItem?
    var sleeping = false
    var lastClick = -Double.infinity
    var lastPoint = CGPoint.zero
    var clickCount: Int64 = 0
    var frames = 0
    var clicks = 0
    var recognizedTaps = 0
    var invalidFrames = 0
    var emptyFrames = 0
    var stateCounts = [Int32: Int]()
    var interferenceFrames = 0
    var window: NSWindow?
    var info: NSTextView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Avoid two copies injecting duplicate clicks.
        if !CommandLine.arguments.contains("--smoke-test"), NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.MagicTap").count > 1 {
            NSApp.terminate(nil); return
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MagicTap")
        status.menu = menu; menu.delegate = self
        bridge.handler = { [weak self] device, contacts, count, time in
            guard let self, self.enabled, !self.sleeping else { return }
            if count < 0 { self.invalidFrames += 1; self.cancelGestures(reason: .invalidFrame); return }
            self.frames += 1
            let values = (0..<Int(count)).map { index -> Touch in
                let c = contacts![index]
                return Touch(id: c.identity, state: c.state, x: Double(c.x), y: Double(c.y))
            }
            if values.isEmpty { self.emptyFrames += 1 }
            for contact in values { self.stateCounts[contact.state, default: 0] += 1 }
            var recognizer = self.recognizers[device] ?? TapRecognizer(settings: self.settings)
            let wasActive = recognizer.isActive
            let interfered = ProcessInfo.processInfo.systemUptime - self.lastInterference < 0.15 || self.anyButtonDown()
            if interfered { self.interferenceFrames += 1 }
            let tap = recognizer.frame(values, time: time, interference: interfered)
            self.recordRejection(recognizer.lastRejection)
            if recognizer.isActive && !wasActive {
                if let point = CGEvent(source: nil)?.location { self.cursorGuard.begin(device: device, at: point) }
                else { recognizer.cancel(reason: .invalidFrame) }
            }
            if !recognizer.isActive { self.cursorGuard.end(device: device) }
            self.recognizers[device] = recognizer
            if tap { self.recognizedTaps += 1; self.scheduleClick() }
        }
        MTWatchDevices { [weak self] in self?.scheduleReconnect() }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(sleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(wake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        refresh()
        if CommandLine.arguments.contains("--smoke-test") {
            showInfo()
            showSettings()
            // Smoke mode forces enabled=false: exercise pending-tap ordering without posting input.
            let before = cancelledClicks
            scheduleClick(); scheduleClick()
            precondition(pendingPoints.count == 2, "Rapid taps must remain separate")
            cancelPendingClick()
            precondition(pendingPoints.isEmpty && cancelledClicks == before + 2, "Cancel must clear all pending taps")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("PASS: AppKit launch, status menu, diagnostics and sensitivity windows, device notifications, disabled startup; no listeners or clicks")
                NSApp.terminate(nil)
            }
        }
    }

    func anyButtonDown() -> Bool {
        (0..<5).contains { CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!) }
    }
    func recordRejection(_ reason: TapRejection?) {
        if let reason { rejectionCounts[reason, default: 0] += 1 }
    }
    func cancelPendingClick() {
        cancelledClicks += pendingPoints.count
        pendingPoints.removeAll()
        pendingGeneration &+= 1
    }
    func cancelGestures(preserveIdle: Bool = false, reason: TapRejection? = nil) {
        cancelPendingClick()
        for key in Array(recognizers.keys) {
            let wasActive = recognizers[key]?.isActive == true
            if preserveIdle { recognizers[key]?.cancelIfActive(reason: reason) }
            else { recognizers[key]?.cancel(reason: reason) }
            if wasActive && reason != nil { recordRejection(recognizers[key]?.lastRejection) }
        }
        cursorGuard.reset()
    }
    func cursorMoved(to point: CGPoint) {
        for device in cursorGuard.movedDevices(to: point, tolerance: settings.cursorTolerance) {
            recognizers[device]?.cancelIfActive(reason: .pointerMovement)
            recordRejection(recognizers[device]?.lastRejection)
            cursorGuard.end(device: device)
        }
        for (id, origin) in pendingPoints {
            if !point.x.isFinite || !point.y.isFinite || hypot(point.x-origin.x,point.y-origin.y) > settings.cursorTolerance {
                pendingPoints.removeValue(forKey: id); cancelledClicks += 1
            }
        }
    }
    func stop() {
        cancelGestures(); recognizers.removeAll(); bridge.stop()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventSource = nil; eventTap = nil; lastClick = -.infinity; clickCount = 0
    }
    func startEventMonitor() -> Bool {
        let types: [CGEventType] = [.leftMouseDown,.leftMouseUp,.rightMouseDown,.rightMouseUp,.otherMouseDown,.otherMouseUp,.scrollWheel,.mouseMoved,.leftMouseDragged,.rightMouseDragged,.otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, _ in
            guard let c = controller else { return Unmanaged.passUnretained(event) }
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                c.cancelGestures()
                if c.enabled, let tap = c.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else if event.getIntegerValueField(.eventSourceUserData) != eventTag {
                if type == .mouseMoved {
                    c.cursorMoved(to: event.location)
                } else {
                    c.lastInterference = ProcessInfo.processInfo.systemUptime
                    c.lastClick = -.infinity
                    c.cancelGestures(preserveIdle: true, reason: .interference)
                }
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: nil)
        guard let tap = eventTap, let source = CFMachPortCreateRunLoopSource(nil,tap,0) else { return false }
        eventSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    func refresh() {
        stop()
        if !enabled { message = "Выключено" }
        else if sleeping { message = "Приостановлено" }
        else if !AXIsProcessTrusted() { message = "Нужен Универсальный доступ" }
        else if !CGPreflightListenEventAccess() { message = "Нужен Мониторинг ввода" }
        else if !startEventMonitor() { message = "Не удалось запустить мониторинг ввода"; stop() }
        else {
            let n = bridge.start()
            message = n < 0 ? "Приватный API недоступен" : n == 0 ? "Совместимая Magic Mouse не обнаружена" : "Ожидание касаний • мышей: \(n)"
            if n < 0 { stop() }
        }
        status?.button?.appearsDisabled = !enabled
        updateInfo()
    }
    func scheduleClick() {
        let token = pendingGeneration
        nextPendingID &+= 1
        let id = nextPendingID
        guard let point = CGEvent(source: nil)?.location else { return }
        pendingPoints[id] = point
        // A configurable short window lets native physical clicks/scroll cancel a tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.clickDelay) { [weak self] in
            guard let self, self.pendingGeneration == token, self.pendingPoints[id] != nil else { return }
            defer { self.pendingPoints.removeValue(forKey: id) }
            guard self.enabled, !self.sleeping,
                  AXIsProcessTrusted(), CGPreflightListenEventAccess(), !self.anyButtonDown(),
                  ProcessInfo.processInfo.systemUptime - self.lastInterference > 0.15,
                  let current = CGEvent(source: nil)?.location,
                  hypot(current.x-point.x,current.y-point.y) <= self.settings.cursorTolerance else {
                self.cancelledClicks += 1; return
            }
            self.postClick(at: current)
        }
    }
    func postClick(at point: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        if now-lastClick <= NSEvent.doubleClickInterval && hypot(point.x-lastPoint.x,point.y-lastPoint.y) < 4 {
            clickCount += 1
        } else { clickCount = 1 }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        for event in [down,up] {
            event.setIntegerValueField(.eventSourceUserData,value: eventTag)
            event.setIntegerValueField(.mouseEventClickState,value: clickCount)
            event.flags = flags
        }
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        lastClick = now; lastPoint = point; clicks += 1
        message = "Работает • кликов: \(clicks)"
    }
    func scheduleReconnect() {
        cancelGestures(); reconnect?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.refresh() }
        reconnect = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6,execute: task)
    }
    @objc func sleep() { sleeping = true; reconnect?.cancel(); stop(); message = "Приостановлено" }
    @objc func wake() { sleeping = false; scheduleReconnect() }
    @objc func toggle() { enabled.toggle(); UserDefaults.standard.set(enabled,forKey: "enabled"); refresh() }
    @objc func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openPrivacy("Privacy_Accessibility")
    }
    @objc func requestInput() { _ = CGRequestListenEventAccess(); openPrivacy("Privacy_ListenEvent") }
    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
    @objc func retry() { refresh() }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            let alert = NSAlert(); alert.messageText = "Не удалось изменить автозапуск"
            alert.informativeText = error.localizedDescription + "\nПереместите приложение в папку Программы и повторите."
            alert.runModal()
        }
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        func item(_ title: String,_ action: Selector?,_ on: Bool = false) {
            let i = NSMenuItem(title: title,action: action,keyEquivalent: ""); i.target = self
            i.state = on ? .on : .off; menu.addItem(i)
        }
        item("MagicTap — \(message)",nil)
        item("Клик касанием",#selector(toggle),enabled)
        item("Чувствительность…",#selector(showSettings))
        menu.addItem(.separator())
        item("1. Разрешить Универсальный доступ…",#selector(requestAccessibility),AXIsProcessTrusted())
        item("2. Разрешить Мониторинг ввода…",#selector(requestInput),CGPreflightListenEventAccess())
        item("Проверить подключение и разрешения",#selector(retry))
        item("Запускать при входе",#selector(toggleLogin),SMAppService.mainApp.status == .enabled)
        if SMAppService.mainApp.status == .requiresApproval { item("Автозапуск ожидает одобрения в настройках",nil) }
        item("Диагностика и инструкция…",#selector(showInfo))
        menu.addItem(.separator()); item("Завершить MagicTap",#selector(quit))
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = TapSettingsWindow(settings: settings) { [weak self] value in
                self?.applySettings(value)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }
    func applySettings(_ value: TapSettings) {
        settings = value.sanitized
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "tapSettings") }
        cancelGestures()
        recognizers.removeAll()
        updateInfo()
    }
    func updateInfo() {
        info?.string = """
        MagicTap 0.1.2 — экспериментальная сборка для Apple Silicon

        Состояние: \(message)
        Получено кадров: \(frames). Отправлено кликов: \(clicks).
        Распознано tap: \(recognizedTaps). Пустых кадров: \(emptyFrames).
        Кадров с вмешательством: \(interferenceFrames). Невалидных/задержанных: \(invalidFrames).
        Состояния контактов (код: количество): \(stateCounts.keys.sorted().map { "\($0): \(stateCounts[$0]!)" }.joined(separator: ", "))
        Отменено перед отправкой клика: \(cancelledClicks).
        Причины отклонения: \(rejectionCounts.keys.sorted { $0.rawValue < $1.rawValue }.map { "\($0.rawValue): \(rejectionCounts[$0]!)" }.joined(separator: "; "))
        Настройки: минимум \(Int((settings.minDuration * 1000).rounded())) мс, максимум \(Int((settings.maxDuration * 1000).rounded())) мс, движение пальца \(Int((settings.maxMovement * 100).rounded()))%, курсор \(Int(settings.cursorTolerance)) пт, задержка \(Int((settings.clickDelay * 1000).rounded())) мс.
        Счётчики обновляются при повторном открытии этого окна.
        Универсальный доступ: \(AXIsProcessTrusted() ? "да" : "нет")
        Мониторинг ввода: \(CGPreflightListenEventAccess() ? "да" : "нет")

        Как включить
        1. Переместите приложение в Программы.
        2. Разрешите Универсальный доступ и Мониторинг ввода через меню мыши.
        3. При необходимости перезапустите приложение, затем включите «Клик касанием».
        4. Уберите пальцы с поверхности и легко коснитесь одним пальцем.

        Длительность и чувствительность меняются через меню «Чувствительность…». Для быстрых лёгких касаний начните с режима «Быстрые касания» (минимум 8 мс). Небольшое дрожание мыши допускается в пределах настройки; прокрутка, несколько пальцев и физическое нажатие отменяют жест. Для двойного клика коснитесь дважды. Долгое касание не перетаскивает.

        Требуются касания без другого пальца, лежащего на мыши. Пороги консервативные и требуют проверки на вашей мыши. Выключение останавливает чтение касаний и мониторинг событий.

        Используется приватный API Apple: обновление macOS может нарушить работу. Незнакомые модели пропускаются. Трекпады не включаются. Нет сети, записи клавиш или журнала касаний.

        \(bridge.diagnostics())
        """
    }
    @objc func showInfo() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x:0,y:0,width:660,height:600),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
            w.title = "MagicTap — диагностика"; w.isReleasedWhenClosed = false; w.center()
            let scroll = NSScrollView(frame:w.contentView!.bounds); scroll.autoresizingMask = [.width,.height]; scroll.hasVerticalScroller = true
            let text = NSTextView(frame:scroll.bounds); text.isEditable = false; text.isSelectable = true
            text.font = .systemFont(ofSize:14); text.textContainerInset = NSSize(width:18,height:18)
            text.autoresizingMask = [.width]; text.isVerticallyResizable = true
            text.textContainer?.widthTracksTextView = true; scroll.documentView = text
            w.contentView?.addSubview(scroll); window = w; info = text
        }
        updateInfo(); NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { reconnect?.cancel(); stop(); MTUnwatchDevices() }
}

if CommandLine.arguments.contains("--diagnose") {
    print(MTBridge().diagnostics())
    print("Accessibility: \(AXIsProcessTrusted()); Input Monitoring: \(CGPreflightListenEventAccess())")
    print("No touch listeners started; no clicks posted.")
} else {
    let app = NSApplication.shared
    controller = AppController(); app.delegate = controller
    app.setActivationPolicy(.accessory); app.run()
}
