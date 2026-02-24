import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var missionControlMonitor: MissionControlMonitor?
    private var titleOverlayManager: TitleOverlayManager?
    private var windowTitleService: WindowTitleService?
    private var overlayRetryCount = 0
    private var refreshTimer: Timer?
    private var lastThumbnails: [ThumbnailInfo] = []

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
    }

    private func handleMissionControlStateChange(_ isActive: Bool) {
        if isActive {
            overlayRetryCount = 0
            lastThumbnails = []
            showOverlaysWhenReady()
            startRefreshTimer()
        } else {
            stopRefreshTimer()
            titleOverlayManager?.removeAll()
            lastThumbnails = []
        }
    }

    private func showOverlaysWhenReady() {
        guard let windowTitleService, let titleOverlayManager else { return }
        guard let monitor = missionControlMonitor, monitor.isActive else {
            titleOverlayManager.removeAll()
            return
        }

        let windowInfos = windowTitleService.getThumbnailInfo()

        if windowInfos.isEmpty && overlayRetryCount < 6 {
            overlayRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.showOverlaysWhenReady()
            }
            return
        }

        lastThumbnails = windowInfos
        titleOverlayManager.update(with: windowInfos)
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

        let current = windowTitleService.getThumbnailInfo()
        guard !current.isEmpty else { return }

        if thumbnailsChanged(old: lastThumbnails, new: current) {
            lastThumbnails = current
            titleOverlayManager.update(with: current)
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
