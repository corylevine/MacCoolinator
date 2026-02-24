import AppKit

enum LabelPosition: Int, CaseIterable {
    case bottom = 0
    case center = 1
    case top = 2

    var label: String {
        switch self {
        case .bottom: "Bottom"
        case .center: "Center"
        case .top: "Top"
        }
    }
}

final class OverlaySettings {
    static let shared = OverlaySettings()

    static let didChangeNotification = Notification.Name("OverlaySettingsDidChange")

    private let defaults = UserDefaults.standard

    var fontSize: CGFloat {
        get { val(forKey: "fontSize", fallback: 11) }
        set { defaults.set(Double(newValue), forKey: "fontSize"); notify() }
    }

    var maxLabelWidth: CGFloat {
        get { val(forKey: "maxLabelWidth", fallback: 10000) }
        set { defaults.set(Double(newValue), forKey: "maxLabelWidth"); notify() }
    }

    var labelPosition: LabelPosition {
        get { LabelPosition(rawValue: defaults.integer(forKey: "labelPosition")) ?? .bottom }
        set { defaults.set(newValue.rawValue, forKey: "labelPosition"); notify() }
    }

    var verticalOffset: CGFloat {
        get { val(forKey: "verticalOffset", fallback: 0) }
        set { defaults.set(Double(newValue), forKey: "verticalOffset"); notify() }
    }

    var backgroundOpacity: CGFloat {
        get { val(forKey: "backgroundOpacity", fallback: 0.70) }
        set { defaults.set(Double(newValue), forKey: "backgroundOpacity"); notify() }
    }

    var cornerRadius: CGFloat {
        get { val(forKey: "cornerRadius", fallback: 4) }
        set { defaults.set(Double(newValue), forKey: "cornerRadius"); notify() }
    }

    var fontWeight: NSFont.Weight {
        get {
            let raw = defaults.object(forKey: "fontWeight") as? CGFloat ?? NSFont.Weight.medium.rawValue
            return NSFont.Weight(rawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: "fontWeight"); notify() }
    }

    private func val(forKey key: String, fallback: CGFloat) -> CGFloat {
        defaults.object(forKey: key) != nil ? CGFloat(defaults.double(forKey: key)) : fallback
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    func resetToDefaults() {
        let keys = ["fontSize", "maxLabelWidth", "labelPosition", "verticalOffset",
                     "backgroundOpacity", "cornerRadius", "fontWeight"]
        keys.forEach { defaults.removeObject(forKey: $0) }
        notify()
    }
}
