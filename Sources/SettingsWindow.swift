import AppKit

final class TapSettingsWindow: NSWindowController {
    private var settings: TapSettings
    private let onChange: (TapSettings) -> Void
    private let profiles = NSPopUpButton()
    private let rightTap = NSButton(checkboxWithTitle: "Правый клик касанием правой половины", target: nil, action: nil)
    private var sliders: [NSSlider] = []
    private var values: [NSTextField] = []

    init(settings: TapSettings, onChange: @escaping (TapSettings) -> Void) {
        self.settings = settings.sanitized
        self.onChange = onChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MagicTap — чувствительность"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        buildInterface()
        reloadControls()
    }
    required init?(coder: NSCoder) { fatalError("Not implemented") }

    private func buildInterface() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window!.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window!.contentView!.topAnchor, constant: 24)
        ])
        let title = NSTextField(labelWithString: "Подстройте касание под свою руку")
        title.font = .boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(title)
        let help = NSTextField(wrappingLabelWithString: "Если быстрое касание пропускается, уменьшите минимальную длительность. Настройки применяются сразу и сохраняются.")
        help.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(help)
        help.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        profiles.addItems(withTitles: ["Быстрые касания", "Обычный", "Осторожный", "Свои настройки"])
        profiles.target = self; profiles.action = #selector(profileChanged)
        stack.addArrangedSubview(profiles)
        rightTap.target = self; rightTap.action = #selector(rightTapChanged)
        stack.addArrangedSubview(rightTap)
        let sharedHelp = NSTextField(wrappingLabelWithString: "При включённом правом клике: слева — левый клик, справа — контекстное меню. Регулировки ниже общие для обеих сторон.")
        sharedHelp.font = .systemFont(ofSize: 12); sharedHelp.textColor = .secondaryLabelColor
        stack.addArrangedSubview(sharedHelp)
        sharedHelp.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let rows: [(String, Double, Double, String)] = [
            ("Минимальная длительность касания", 0, 40, "Меньше → принимаются более быстрые касания"),
            ("Максимальная длительность касания", 100, 600, "Больше → принимаются более медленные касания"),
            ("Допуск движения пальца", 1, 15, "Больше → меньше пропусков при небольшом сдвиге пальца"),
            ("Допуск смещения курсора", 0, 20, "Небольшое дрожание мыши не отменяет клик"),
            ("Защитная задержка клика", 0, 60, "Меньше → быстрее отклик после отпускания")
        ]
        for (index, row) in rows.enumerated() {
            let group = NSStackView(); group.orientation = .vertical; group.alignment = .leading; group.spacing = 3
            let heading = NSStackView(); heading.orientation = .horizontal
            let label = NSTextField(labelWithString: row.0)
            let value = NSTextField(labelWithString: "")
            value.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            heading.addArrangedSubview(label); heading.addArrangedSubview(value)
            group.addArrangedSubview(heading)
            let slider = NSSlider(value: 0, minValue: row.1, maxValue: row.2, target: self, action: #selector(sliderChanged(_:)))
            slider.tag = index; slider.isContinuous = true
            slider.setAccessibilityLabel(row.0)
            group.addArrangedSubview(slider)
            let hint = NSTextField(labelWithString: row.3)
            hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
            group.addArrangedSubview(hint)
            stack.addArrangedSubview(group)
            group.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            slider.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
            sliders.append(slider); values.append(value)
        }
        let footer = NSTextField(wrappingLabelWithString: "Начните с «Быстрые касания» (минимум 2 мс). Если появляются случайные клики — увеличьте минимум или выберите «Осторожный». После изменения уберите палец с мыши и попробуйте снова.")
        footer.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    private func reloadControls() {
        let numbers = [settings.minDuration * 1000, settings.maxDuration * 1000,
                       settings.maxMovement * 100, settings.cursorTolerance, settings.clickDelay * 1000]
        for index in sliders.indices { sliders[index].doubleValue = numbers[index] }
        updateLabels()
        rightTap.state = settings.rightTapEnabled ? .on : .off
        var tuning = settings
        tuning.rightTapEnabled = true
        let selected = tuning == .fast ? 0 : tuning == .balanced ? 1 : tuning == .careful ? 2 : 3
        profiles.selectItem(at: selected)
    }
    private func updateLabels() {
        let units = ["мс", "мс", "%", "пт", "мс"]
        for index in sliders.indices {
            values[index].stringValue = String(format: "%.0f %@", sliders[index].doubleValue, units[index])
        }
    }
    @objc private func rightTapChanged() {
        settings.rightTapEnabled = rightTap.state == .on
        onChange(settings)
    }
    @objc private func profileChanged() {
        let enabled = settings.rightTapEnabled
        switch profiles.indexOfSelectedItem {
        case 0: settings = .fast
        case 1: settings = .balanced
        case 2: settings = .careful
        default: return
        }
        settings.rightTapEnabled = enabled
        reloadControls(); onChange(settings)
    }
    @objc private func sliderChanged(_ slider: NSSlider) {
        let value = slider.doubleValue.rounded()
        slider.doubleValue = value
        switch slider.tag {
        case 0: settings.minDuration = value / 1000
        case 1: settings.maxDuration = value / 1000
        case 2: settings.maxMovement = value / 100
        case 3: settings.cursorTolerance = value
        case 4: settings.clickDelay = value / 1000
        default: return
        }
        settings = settings.sanitized
        profiles.selectItem(at: 3); updateLabels(); onChange(settings)
    }
}
