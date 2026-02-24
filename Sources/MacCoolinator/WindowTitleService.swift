import AppKit
import ApplicationServices

struct ThumbnailInfo {
    let title: String
    let position: CGPoint
    let size: CGSize
}

final class WindowTitleService {

    /// Fast path: traverse only the Dock's AX tree. No cross-app queries.
    func getRawThumbnailInfo() -> [ThumbnailInfo] {
        guard let dockPID = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .first?.processIdentifier else {
            NSLog("MacCoolinator: Dock process not found")
            return []
        }

        let dockApp = AXUIElementCreateApplication(dockPID)
        var results: [ThumbnailInfo] = []
        collectThumbnails(from: dockApp, into: &results, depth: 0)

        if results.isEmpty {
            collectThumbnailsAlternate(from: dockApp, into: &results, depth: 0)
        }

        return results
    }

    /// Resolve truncated Dock titles ("…") against full window titles from
    /// every running application. Expensive — call from a background thread.
    func resolveTitles(for thumbnails: [ThumbnailInfo]) -> [ThumbnailInfo] {
        let hasTruncated = thumbnails.contains {
            $0.title.hasSuffix("\u{2026}") || $0.title.hasSuffix("...")
        }
        guard hasTruncated else { return thumbnails }

        let fullTitles = collectAllWindowTitles()
        return thumbnails.map { info in
            let resolved = resolveFullTitle(dockTitle: info.title, fullTitles: fullTitles)
            return ThumbnailInfo(title: resolved, position: info.position, size: info.size)
        }
    }

    func getThumbnailInfo() -> [ThumbnailInfo] {
        let results = resolveTitles(for: getRawThumbnailInfo())

        NSLog("MacCoolinator: Found %d thumbnail(s)", results.count)
        for info in results {
            NSLog("MacCoolinator:   \"%@\" at (%.0f, %.0f) size %.0fx%.0f",
                  info.title, info.position.x, info.position.y,
                  info.size.width, info.size.height)
        }

        return results
    }

    // MARK: - Dock AX tree traversal

    private func collectThumbnails(
        from element: AXUIElement,
        into results: inout [ThumbnailInfo],
        depth: Int
    ) {
        guard depth < 10 else { return }
        guard let children = element.children else { return }

        for child in children {
            let role = child.role ?? ""
            let title = child.title

            if role == "AXButton",
               let title, !title.isEmpty,
               let pos = child.axPosition,
               let size = child.axSize,
               size.width > 30, size.height > 30 {
                results.append(ThumbnailInfo(title: title, position: pos, size: size))
            } else {
                collectThumbnails(from: child, into: &results, depth: depth + 1)
            }
        }
    }

    private func collectThumbnailsAlternate(
        from element: AXUIElement,
        into results: inout [ThumbnailInfo],
        depth: Int
    ) {
        guard depth < 10 else { return }
        guard let children = element.children else { return }

        for child in children {
            let role = child.role ?? ""
            let title = child.title

            let interactiveRoles: Set<String> = [
                "AXButton", "AXImage", "AXGroup", "AXRadioButton",
                "AXDockItem", "AXUnknown"
            ]

            if interactiveRoles.contains(role),
               let title, !title.isEmpty,
               let pos = child.axPosition,
               let size = child.axSize,
               size.width > 40, size.height > 30 {
                let isDuplicate = results.contains {
                    $0.title == title &&
                    abs($0.position.x - pos.x) < 5 &&
                    abs($0.position.y - pos.y) < 5
                }
                if !isDuplicate {
                    results.append(ThumbnailInfo(title: title, position: pos, size: size))
                }
            } else if role == "AXGroup" || role == "AXList" || role == "AXScrollArea" {
                collectThumbnailsAlternate(from: child, into: &results, depth: depth + 1)
            }
        }
    }

    // MARK: - Full title resolution

    /// Query every running application's AX tree for its window titles.
    private func collectAllWindowTitles() -> [String] {
        var titles: [String] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else {
                continue
            }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var ref: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &ref)
            guard err == .success, let windows = ref as? [AXUIElement] else { continue }

            for window in windows {
                if let title = window.title, !title.isEmpty {
                    titles.append(title)
                }
            }
        }

        return titles
    }

    /// If the Dock title looks truncated (ends with "…" or "..."), find the
    /// matching full title from the list. Falls back to the original title.
    private func resolveFullTitle(dockTitle: String, fullTitles: [String]) -> String {
        let ellipsis = "\u{2026}"   // …
        let dotdotdot = "..."

        let truncated: Bool
        let prefix: String

        if dockTitle.hasSuffix(ellipsis) {
            truncated = true
            prefix = String(dockTitle.dropLast(1))
        } else if dockTitle.hasSuffix(dotdotdot) {
            truncated = true
            prefix = String(dockTitle.dropLast(3))
        } else {
            truncated = false
            prefix = dockTitle
        }

        guard truncated, !prefix.isEmpty else {
            return dockTitle
        }

        // Find the full title that starts with this prefix.
        // If multiple match, prefer the shortest (most specific).
        let match = fullTitles
            .filter { $0.hasPrefix(prefix) }
            .min(by: { $0.count < $1.count })

        return match ?? dockTitle
    }

    // MARK: - Debug

    func dumpDockTree() {
        guard let dockPID = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .first?.processIdentifier else {
            NSLog("MacCoolinator: Dock process not found")
            return
        }
        let dockApp = AXUIElementCreateApplication(dockPID)
        NSLog("MacCoolinator: === Dock AX Tree Dump ===")
        dockApp.debugDump(indent: 0, maxDepth: 7)
        NSLog("MacCoolinator: === End Dock AX Tree ===")
    }
}
