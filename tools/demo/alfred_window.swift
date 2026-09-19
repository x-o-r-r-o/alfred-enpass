// Prints the window ID of Alfred's search window: owned by "Alfred" itself (not
// "Alfred Preferences") and floating above normal windows (layer > 0).
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let alfred = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "Alfred" && ($0[kCGWindowLayer as String] as? Int ?? 0) > 0 }
    .max { a, b in
        let area = { (w: [String: Any]) -> Double in
            let r = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
            return (r["Width"] ?? 0) * (r["Height"] ?? 0)
        }
        return area(a) < area(b)
    }
if let id = alfred?[kCGWindowNumber as String] as? Int { print(id) } else { exit(1) }
