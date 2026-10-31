import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onWindow = { window in
            guard context.coordinator.lastWindow !== window else { return }
            context.coordinator.lastWindow = window
            onWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        nsView.onWindow = { window in
            guard context.coordinator.lastWindow !== window else { return }
            context.coordinator.lastWindow = window
            onWindow(window)
        }
        // Not nsView.window: SwiftUI can update this view while its window is
        // deallocating, and the coordinator's weak store of that window aborts
        // ("Cannot form weak reference"). The tracked window reads nil then.
        if let window = nsView.trackedWindow {
            nsView.onWindow?(window)
        }
    }
}

extension WindowAccessor {
    final class Coordinator {
        weak var lastWindow: NSWindow?
    }
}

final class WindowObservingView: NSView {
    var onWindow: ((NSWindow) -> Void)?
    /// Set only from AppKit's move callback, where the window is alive.
    private(set) weak var trackedWindow: NSWindow?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let newWindow {
            onWindow?(newWindow)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        trackedWindow = window
        if let window {
            onWindow?(window)
        }
    }
}
