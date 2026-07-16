import AppKit
import SwiftUI

/// Restores native title-bar behavior to the custom toolbar strip: dragging
/// moves the window, and double-click zooms/minimizes according to the
/// user's "double-click a window's title bar to…" System Settings choice.
/// Needed because the window uses `.hiddenTitleBar` — without a real title
/// bar, AppKit has nowhere to apply these behaviors itself.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}

    final class DragHandleView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount >= 2 {
                performTitleBarDoubleClickAction(on: window)
            } else {
                window.performDrag(with: event)
            }
        }

        private func performTitleBarDoubleClickAction(on window: NSWindow) {
            let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            switch action {
            case "Minimize":
                window.performMiniaturize(nil)
            case "None":
                break
            default: // "Maximize" / "Fill"
                window.performZoom(nil)
            }
        }
    }
}
