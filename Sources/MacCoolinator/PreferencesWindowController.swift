import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController {

    private let settings = OverlaySettings.shared

    private var launchAtLoginCheckbox: NSButton!
    private var fontSizeSlider: NSSlider!
    private var fontSizeLabel: NSTextField!
    private var maxWidthSlider: NSSlider!
    private var maxWidthLabel: NSTextField!
    private var positionPopup: NSPopUpButton!
    private var offsetSlider: NSSlider!
    private var offsetLabel: NSTextField!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var radiusSlider: NSSlider!
    private var radiusLabel: NSTextField!
    private var weightPopup: NSPopUpButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacCoolinator Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
        loadValues()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 200
        grid.column(at: 2).xPlacement = .leading
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        // Launch at Login
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(launchAtLoginChanged))
        let loginRow = grid.addRow(with: [NSView(), launchAtLoginCheckbox, NSView()])
        loginRow.bottomPadding = 6

        grid.addRow(with: [makeSeparator(), makeSeparator(), makeSeparator()])

        // Font size
        fontSizeSlider = makeSlider(min: 8, max: 24, target: self, action: #selector(fontSizeChanged))
        fontSizeLabel = makeValueLabel()
        grid.addRow(with: [makeLabel("Font Size:"), fontSizeSlider, fontSizeLabel])

        // Font weight
        weightPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        weightPopup.addItems(withTitles: ["Light", "Regular", "Medium", "Semibold", "Bold"])
        weightPopup.target = self
        weightPopup.action = #selector(weightChanged)
        grid.addRow(with: [makeLabel("Font Weight:"), weightPopup, NSView()])

        // Max label width (0 = unlimited)
        maxWidthSlider = makeSlider(min: 100, max: 2000, target: self, action: #selector(maxWidthChanged))
        maxWidthLabel = makeValueLabel()
        grid.addRow(with: [makeLabel("Max Width:"), maxWidthSlider, maxWidthLabel])

        // Position
        positionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for pos in LabelPosition.allCases { positionPopup.addItem(withTitle: pos.label) }
        positionPopup.target = self
        positionPopup.action = #selector(positionChanged)
        grid.addRow(with: [makeLabel("Position:"), positionPopup, NSView()])

        // Vertical offset
        offsetSlider = makeSlider(min: -40, max: 40, target: self, action: #selector(offsetChanged))
        offsetLabel = makeValueLabel()
        grid.addRow(with: [makeLabel("Vertical Offset:"), offsetSlider, offsetLabel])

        // Background opacity
        opacitySlider = makeSlider(min: 0, max: 100, target: self, action: #selector(opacityChanged))
        opacityLabel = makeValueLabel()
        grid.addRow(with: [makeLabel("BG Opacity:"), opacitySlider, opacityLabel])

        // Corner radius
        radiusSlider = makeSlider(min: 0, max: 16, target: self, action: #selector(radiusChanged))
        radiusLabel = makeValueLabel()
        grid.addRow(with: [makeLabel("Corner Radius:"), radiusSlider, radiusLabel])

        // Reset button
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        let resetRow = grid.addRow(with: [NSView(), resetButton, NSView()])
        resetRow.topPadding = 12
    }

    private func loadValues() {
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off

        fontSizeSlider.doubleValue = Double(settings.fontSize)
        fontSizeLabel.stringValue = String(format: "%.0fpt", settings.fontSize)

        let mw = min(settings.maxLabelWidth, 2000)
        maxWidthSlider.doubleValue = Double(mw)
        maxWidthLabel.stringValue = mw >= 2000 ? "No limit" : String(format: "%.0fpx", mw)

        positionPopup.selectItem(at: settings.labelPosition.rawValue)

        offsetSlider.doubleValue = Double(settings.verticalOffset)
        offsetLabel.stringValue = String(format: "%.0fpx", settings.verticalOffset)

        opacitySlider.doubleValue = Double(settings.backgroundOpacity * 100)
        opacityLabel.stringValue = String(format: "%.0f%%", settings.backgroundOpacity * 100)

        radiusSlider.doubleValue = Double(settings.cornerRadius)
        radiusLabel.stringValue = String(format: "%.0fpx", settings.cornerRadius)

        let weightIndex: Int
        switch settings.fontWeight {
        case .light: weightIndex = 0
        case .regular: weightIndex = 1
        case .medium: weightIndex = 2
        case .semibold: weightIndex = 3
        case .bold: weightIndex = 4
        default: weightIndex = 2
        }
        weightPopup.selectItem(at: weightIndex)
    }

    // MARK: - Actions

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MacCoolinator: Launch at login failed: %@", error.localizedDescription)
            sender.state = sender.state == .on ? .off : .on
        }
    }

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        let val = sender.doubleValue.rounded()
        settings.fontSize = CGFloat(val)
        fontSizeLabel.stringValue = String(format: "%.0fpt", val)
    }

    @objc private func maxWidthChanged(_ sender: NSSlider) {
        let val = sender.doubleValue.rounded()
        if val >= 2000 {
            settings.maxLabelWidth = 10000
            maxWidthLabel.stringValue = "No limit"
        } else {
            settings.maxLabelWidth = CGFloat(val)
            maxWidthLabel.stringValue = String(format: "%.0fpx", val)
        }
    }

    @objc private func positionChanged(_ sender: NSPopUpButton) {
        settings.labelPosition = LabelPosition(rawValue: sender.indexOfSelectedItem) ?? .bottom
    }

    @objc private func offsetChanged(_ sender: NSSlider) {
        let val = sender.doubleValue.rounded()
        settings.verticalOffset = CGFloat(val)
        offsetLabel.stringValue = String(format: "%.0fpx", val)
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        let val = sender.doubleValue.rounded()
        settings.backgroundOpacity = CGFloat(val / 100)
        opacityLabel.stringValue = String(format: "%.0f%%", val)
    }

    @objc private func radiusChanged(_ sender: NSSlider) {
        let val = sender.doubleValue.rounded()
        settings.cornerRadius = CGFloat(val)
        radiusLabel.stringValue = String(format: "%.0fpx", val)
    }

    @objc private func weightChanged(_ sender: NSPopUpButton) {
        let weights: [NSFont.Weight] = [.light, .regular, .medium, .semibold, .bold]
        settings.fontWeight = weights[sender.indexOfSelectedItem]
    }

    @objc private func resetDefaults() {
        settings.resetToDefaults()
        loadValues()
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = NSFont.systemFont(ofSize: 13)
        tf.alignment = .right
        return tf
    }

    private func makeValueLabel() -> NSTextField {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        tf.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return tf
    }

    private func makeSlider(min: Double, max: Double, target: AnyObject, action: Selector) -> NSSlider {
        let slider = NSSlider(value: min, minValue: min, maxValue: max, target: target, action: action)
        slider.isContinuous = true
        return slider
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }
}
