import AppKit

final class TitleOverlayManager {

    private var overlayWindows: [NSWindow] = []
    private let settings = OverlaySettings.shared

    func update(with thumbnails: [ThumbnailInfo]) {
        removeAll()

        NSLog("MacCoolinator: Creating %d overlay(s)", thumbnails.count)
        for info in thumbnails {
            let overlay = makeOverlayWindow(for: info)
            overlay.orderFrontRegardless()
            overlayWindows.append(overlay)
        }
    }

    func removeAll() {
        if !overlayWindows.isEmpty {
            NSLog("MacCoolinator: Removing %d overlay(s)", overlayWindows.count)
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func makeOverlayWindow(for info: ThumbnailInfo) -> NSWindow {
        let fontSize = settings.fontSize
        let maxWidth = settings.maxLabelWidth
        let position = settings.labelPosition
        let vOffset = settings.verticalOffset
        let bgOpacity = settings.backgroundOpacity
        let radius = settings.cornerRadius
        let weight = settings.fontWeight
        let hPadding: CGFloat = 8
        let labelHeight = fontSize + 10
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)

        // Create the label and let AppKit compute the actual needed width
        // via sizeToFit(). This accounts for font metrics, cell insets, etc.
        let label = NSTextField(labelWithString: info.title)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        label.sizeToFit()
        let textFitWidth = ceil(label.frame.width)

        label.lineBreakMode = .byTruncatingTail

        let fittingWidth = min(textFitWidth + hPadding * 2, maxWidth)

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        let thumbnailCenterX = info.position.x + info.size.width / 2

        let overlayX = thumbnailCenterX - fittingWidth / 2
        let overlayY_NS: CGFloat

        switch position {
        case .bottom:
            let thumbnailBottomY_CG = info.position.y + info.size.height
            overlayY_NS = primaryHeight - thumbnailBottomY_CG + vOffset
        case .top:
            let thumbnailTopY_CG = info.position.y
            overlayY_NS = primaryHeight - thumbnailTopY_CG - labelHeight + vOffset
        case .center:
            let thumbnailCenterY_CG = info.position.y + info.size.height / 2
            overlayY_NS = primaryHeight - thumbnailCenterY_CG - labelHeight / 2 + vOffset
        }

        let frame = NSRect(x: overlayX, y: overlayY_NS, width: fittingWidth, height: labelHeight)

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear

        let container = NSView(frame: NSRect(x: 0, y: 0, width: fittingWidth, height: labelHeight))

        let bgView = NSView(frame: container.bounds)
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor(white: 0, alpha: bgOpacity).cgColor
        bgView.layer?.cornerRadius = radius
        bgView.autoresizingMask = [.width, .height]
        container.addSubview(bgView)

        label.frame = NSRect(
            x: hPadding,
            y: 1,
            width: fittingWidth - hPadding * 2,
            height: labelHeight - 2
        )
        label.autoresizingMask = [.width]
        container.addSubview(label)

        window.contentView = container
        return window
    }
}
