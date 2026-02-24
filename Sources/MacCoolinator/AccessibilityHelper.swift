import AppKit
import ApplicationServices

enum AccessibilityHelper {

    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}

extension AXUIElement {

    var children: [AXUIElement]? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXChildrenAttribute as CFString, &ref)
        guard err == .success, let array = ref as? [AXUIElement] else { return nil }
        return array
    }

    var title: String? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &ref)
        guard err == .success, let str = ref as? String else { return nil }
        return str
    }

    var role: String? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXRoleAttribute as CFString, &ref)
        guard err == .success, let str = ref as? String else { return nil }
        return str
    }

    var subrole: String? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXSubroleAttribute as CFString, &ref)
        guard err == .success, let str = ref as? String else { return nil }
        return str
    }

    var axPosition: CGPoint? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &ref)
        guard err == .success, let axValue = ref, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    var axSize: CGSize? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &ref)
        guard err == .success, let axValue = ref, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    var attributeNames: [String]? {
        var ref: CFArray?
        let err = AXUIElementCopyAttributeNames(self, &ref)
        guard err == .success, let names = ref as? [String] else { return nil }
        return names
    }

    func debugDump(indent: Int = 0, maxDepth: Int = 5) {
        guard maxDepth > 0 else { return }
        let pad = String(repeating: "  ", count: indent)
        let r = role ?? "?"
        let sr = subrole ?? ""
        let t = title ?? ""
        let pos = axPosition.map { "(\(Int($0.x)),\(Int($0.y)))" } ?? ""
        let sz = axSize.map { "\(Int($0.width))x\(Int($0.height))" } ?? ""
        NSLog("%@[%@%@] \"%@\" %@ %@", pad, r, sr.isEmpty ? "" : "/\(sr)", t, pos, sz)

        for child in children ?? [] {
            child.debugDump(indent: indent + 1, maxDepth: maxDepth - 1)
        }
    }
}
