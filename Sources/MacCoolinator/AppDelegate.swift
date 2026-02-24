import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var missionControlMonitor: MissionControlMonitor?
    private var titleOverlayManager: TitleOverlayManager?
    private var windowTitleService: WindowTitleService?
    private var overlayRetryCount = 0
    private var refreshTimer: Timer?
    private var lastRawThumbnails: [ThumbnailInfo] = []
    private var sleepWakeObservers: [NSObjectProtocol] = []
    private let titleResolveQueue = DispatchQueue(label: "com.maccoolinator.titleResolve", qos: .userInitiated)

    func applicationDidFinishLaunching(_ notification: Notification) {
        titleOverlayManager = TitleOverlayManager()
        windowTitleService = WindowTitleService()

        missionControlMonitor = MissionControlMonitor { [weak self] isActive in
            self?.handleMissionControlStateChange(isActive)
        }

        statusBarController = StatusBarController(monitor: missionControlMonitor!)

        if !AccessibilityHelper.requestPermission() {
            NSLog("MacCoolinator: Accessibility permission not yet granted. Please enable in System Settings > Privacy & Security > Accessibility, then relaunch.")
        }

        missionControlMonitor?.start()
        registerSleepWakeHandlers()
    }

    // MARK: - Sleep / Wake

    private func registerSleepWakeHandlers() {
        let ws = NSWorkspace.shared.notificationCenter

        sleepWakeObservers.append(
            ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleSleep()
            }
        )

        sleepWakeObservers.append(
            ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleWake()
            }
        )
    }

    private func handleSleep() {
        NSLog("MacCoolinator: System going to sleep – cleaning up")
        stopRefreshTimer()
        titleOverlayManager?.removeAll()
        lastRawThumbnails = []
        missionControlMonitor?.prepareForSleep()
    }

    private func handleWake() {
        NSLog("MacCoolinator: System woke – restarting monitor polling")
        missionControlMonitor?.restartPolling()
    }

    private func handleMissionControlStateChange(_ isActive: Bool) {
        if isActive {
            overlayRetryCount = 0
            lastRawThumbnails = []
            showOverlaysWhenReady()
            startRefreshTimer()
        } else {
            stopRefreshTimer()
            titleOverlayManager?.removeAll()
            lastRawThumbnails = []
        }
    }

    private func showOverlaysWhenReady() {
        guard let windowTitleService, let titleOverlayManager else { return }
        guard let monitor = missionControlMonitor, monitor.isActive else {
            titleOverlayManager.removeAll()
            return
        }

        let raw = windowTitleService.getRawThumbnailInfo()

        if raw.isEmpty && overlayRetryCount < 10 {
            overlayRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.showOverlaysWhenReady()
            }
            return
        }

        guard monitor.isActive else { return }

        lastRawThumbnails = raw
        titleOverlayManager.update(with: raw)
        resolveAndUpdateTitles(for: raw)
    }

    /// Resolve truncated titles on a background thread, then update overlays.
    private func resolveAndUpdateTitles(for raw: [ThumbnailInfo]) {
        guard let windowTitleService else { return }
        titleResolveQueue.async { [weak self] in
            let resolved = windowTitleService.resolveTitles(for: raw)
            DispatchQueue.main.async {
                guard let self,
                      let monitor = self.missionControlMonitor, monitor.isActive else { return }
                self.titleOverlayManager?.update(with: resolved)
            }
        }
    }

    // MARK: - Continuous refresh while MC is active

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refreshIfChanged()
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshIfChanged() {
        guard let windowTitleService, let titleOverlayManager else { return }
        guard let monitor = missionControlMonitor, monitor.isActive else { return }

        let current = windowTitleService.getRawThumbnailInfo()
        guard !current.isEmpty else { return }

        if thumbnailsChanged(old: lastRawThumbnails, new: current) {
            lastRawThumbnails = current
            titleOverlayManager.update(with: current)
            resolveAndUpdateTitles(for: current)
        }
    }

    private func thumbnailsChanged(old: [ThumbnailInfo], new: [ThumbnailInfo]) -> Bool {
        guard old.count == new.count else { return true }
        for (a, b) in zip(old, new) {
            if a.title != b.title { return true }
            if abs(a.position.x - b.position.x) > 2 || abs(a.position.y - b.position.y) > 2 { return true }
            if abs(a.size.width - b.size.width) > 2 || abs(a.size.height - b.size.height) > 2 { return true }
        }
        return false
    }
}
