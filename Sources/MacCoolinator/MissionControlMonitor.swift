import AppKit
import CoreGraphics

final class MissionControlMonitor {
    typealias StateChangeHandler = (Bool) -> Void

    private var timer: Timer?
    private let onChange: StateChangeHandler
    private(set) var isActive = false
    var isMonitoring: Bool { timer != nil }
    private var workspaceObservers: [NSObjectProtocol] = []
    /// Timestamp of last deactivation, used to suppress false re-activation
    /// during MC's close animation.
    private var lastDismissTime: CFAbsoluteTime = 0
    private let dismissCooldown: CFAbsoluteTime = 0.8

    init(onChange: @escaping StateChangeHandler) {
        self.onChange = onChange
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)

        let ws = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handlePossibleDismiss()
            }
        )

        workspaceObservers.append(
            ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handlePossibleDismiss()
            }
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        let ws = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            ws.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        if isActive {
            isActive = false
            onChange(false)
        }
    }

    /// Reset internal state before sleep so wake starts clean.
    func prepareForSleep() {
        isActive = false
        lastDismissTime = 0
        timer?.invalidate()
        timer = nil
    }

    /// Reinitializes the polling timer and runs an immediate poll.
    /// Call after system wake to guarantee the timer is alive.
    func restartPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
        poll()
    }

    private func handlePossibleDismiss() {
        guard isActive else { return }
        isActive = false
        lastDismissTime = CFAbsoluteTimeGetCurrent()
        NSLog("MacCoolinator: Mission Control DEACTIVATED (event-driven)")
        onChange(false)
    }

    private func poll() {
        let nowActive = Self.detectMissionControl()
        if nowActive != isActive {
            // After a dismiss, ignore re-activation for a cooldown period
            // to prevent the close animation's lingering Dock windows from
            // triggering a false flash of overlays.
            if nowActive && (CFAbsoluteTimeGetCurrent() - lastDismissTime) < dismissCooldown {
                return
            }
            NSLog("MacCoolinator: Mission Control %@", nowActive ? "ACTIVATED" : "DEACTIVATED")
            isActive = nowActive
            onChange(nowActive)
        }
    }

    static func detectMissionControl() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        var dockWindowCount = 0

        for info in windowList {
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner == "Dock",
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                continue
            }

            if height > 100 && width > 100 {
                dockWindowCount += 1
                if y < 0 {
                    return true
                }
            }
        }

        return dockWindowCount >= 3
    }
}
