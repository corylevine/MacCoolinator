import AppKit

final class StatusBarController {

    private let statusItem: NSStatusItem
    private let monitor: MissionControlMonitor
    private var enabledItem: NSMenuItem!
    private var prefsWindowController: PreferencesWindowController?

    init(monitor: MissionControlMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "macwindow.on.rectangle",
            accessibilityDescription: "MacCoolinator"
        )
    }

    private func configureMenu() {
        let menu = NSMenu()

        enabledItem = NSMenuItem(
            title: "Monitoring Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MacCoolinator",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        if monitor.isMonitoring {
            monitor.stop()
            enabledItem.state = .off
        } else {
            monitor.start()
            enabledItem.state = .on
        }
    }

    @objc private func openPreferences() {
        if prefsWindowController == nil {
            prefsWindowController = PreferencesWindowController()
        }
        prefsWindowController?.showWindow(nil)
        prefsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
