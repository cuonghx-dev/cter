import AppKit
import SwiftUI

final class NonDraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}

enum TitlebarControlsStyle: Int, CaseIterable, Identifiable {
    case classic
    case compact
    case roomy
    case pillGroup
    case softButtons

    var id: Int { rawValue }

    var menuTitle: String {
        switch self {
        case .classic:
            return "Classic"
        case .compact:
            return "Compact"
        case .roomy:
            return "Roomy"
        case .pillGroup:
            return "Pill Group"
        case .softButtons:
            return "Soft Buttons"
        }
    }

    var config: TitlebarControlsStyleConfig {
        switch self {
        case .classic:
            return TitlebarControlsStyleConfig(
                spacing: 10,
                iconSize: 15,
                buttonSize: 24,
                badgeSize: 14,
                badgeOffset: CGSize(width: 2, height: -2),
                groupBackground: false,
                groupPadding: EdgeInsets(),
                buttonBackground: false,
                buttonCornerRadius: 8,
                hoverBackground: false
            )
        case .compact:
            return TitlebarControlsStyleConfig(
                spacing: 6,
                iconSize: 13,
                buttonSize: 20,
                badgeSize: 12,
                badgeOffset: CGSize(width: 1, height: -1),
                groupBackground: false,
                groupPadding: EdgeInsets(),
                buttonBackground: false,
                buttonCornerRadius: 6,
                hoverBackground: false
            )
        case .roomy:
            return TitlebarControlsStyleConfig(
                spacing: 14,
                iconSize: 16,
                buttonSize: 28,
                badgeSize: 16,
                badgeOffset: CGSize(width: 3, height: -3),
                groupBackground: false,
                groupPadding: EdgeInsets(),
                buttonBackground: false,
                buttonCornerRadius: 10,
                hoverBackground: false
            )
        case .pillGroup:
            return TitlebarControlsStyleConfig(
                spacing: 8,
                iconSize: 14,
                buttonSize: 24,
                badgeSize: 14,
                badgeOffset: CGSize(width: 2, height: -2),
                groupBackground: false,
                groupPadding: EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4),
                buttonBackground: false,
                buttonCornerRadius: 8,
                hoverBackground: true
            )
        case .softButtons:
            return TitlebarControlsStyleConfig(
                spacing: 8,
                iconSize: 15,
                buttonSize: 26,
                badgeSize: 14,
                badgeOffset: CGSize(width: 2, height: -2),
                groupBackground: false,
                groupPadding: EdgeInsets(),
                buttonBackground: true,
                buttonCornerRadius: 8,
                hoverBackground: false
            )
        }
    }
}

struct TitlebarControlsStyleConfig {
    let spacing: CGFloat
    let iconSize: CGFloat
    let buttonSize: CGFloat
    let badgeSize: CGFloat
    let badgeOffset: CGSize
    let groupBackground: Bool
    let groupPadding: EdgeInsets
    let buttonBackground: Bool
    let buttonCornerRadius: CGFloat
    let hoverBackground: Bool
}

final class TitlebarControlsViewModel: ObservableObject {
    weak var notificationsAnchorView: NSView?
}

private struct NotificationsAnchorView: NSViewRepresentable {
    let onResolve: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = AnchorNSView()
        view.onLayout = { [weak view] in
            guard let view else { return }
            onResolve(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class AnchorNSView: NSView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}

private struct TitlebarControlButton<Content: View>: View {
    let config: TitlebarControlsStyleConfig
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: config.buttonSize, height: config.buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: config.buttonSize, height: config.buttonSize)
        .contentShape(Rectangle())
        .background(hoverBackground)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var hoverBackground: some View {
        if config.hoverBackground && isHovering {
            RoundedRectangle(cornerRadius: config.buttonCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        }
    }
}

private struct TitlebarControlsView: View {
    @ObservedObject var notificationStore: TerminalNotificationStore
    @ObservedObject var viewModel: TitlebarControlsViewModel
    let onToggleSidebar: () -> Void
    let onToggleNotifications: () -> Void
    let onNewTab: () -> Void
    @AppStorage("titlebarControlsStyle") private var styleRawValue = TitlebarControlsStyle.classic.rawValue

    var body: some View {
        let style = TitlebarControlsStyle(rawValue: styleRawValue) ?? .classic
        let config = style.config
        controlsGroup(config: config)
            .padding(.leading, 4)
    }

    private var notificationsAccessibilityLabel: String {
        let unread = notificationStore.unreadCount
        switch unread {
        case 0: return "Notifications"
        case 1: return "Notifications, 1 unread"
        default: return "Notifications, \(unread) unread"
        }
    }

    @ViewBuilder
    private func controlsGroup(config: TitlebarControlsStyleConfig) -> some View {
        let content = HStack(spacing: config.spacing) {
            TitlebarControlButton(config: config, action: onToggleSidebar) {
                iconLabel(systemName: "sidebar.left", config: config)
            }
            .accessibilityLabel("Toggle Sidebar")
            .help("Show or hide the sidebar (⌘B)")

            TitlebarControlButton(config: config, action: onToggleNotifications) {
                ZStack(alignment: .topTrailing) {
                    iconLabel(systemName: "bell", config: config)

                    if notificationStore.unreadCount > 0 {
                        // Capsule widens for multi-digit counts instead of clipping them.
                        Text(notificationStore.unreadCount > 99 ? "99+" : "\(notificationStore.unreadCount)")
                            .font(.system(size: max(8, config.badgeSize - 5), weight: .semibold).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: config.badgeSize, minHeight: config.badgeSize)
                            .background(
                                Capsule().fill(Color.accentColor)
                            )
                            .fixedSize()
                            .offset(x: config.badgeOffset.width, y: config.badgeOffset.height)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: config.buttonSize, height: config.buttonSize)
            }
            .overlay(NotificationsAnchorView { viewModel.notificationsAnchorView = $0 }.allowsHitTesting(false))
            .accessibilityLabel(notificationsAccessibilityLabel)
            .help("Show notifications (\(KeyboardShortcutSettings.showNotificationsShortcut().displayString))")

            TitlebarControlButton(config: config, action: onNewTab) {
                iconLabel(systemName: "plus", config: config)
            }
            .accessibilityLabel("New Tab")
            .help("Open a new tab (⌘N)")
        }

        let paddedContent = content.padding(config.groupPadding)

        if config.groupBackground {
            paddedContent
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                )
        } else {
            paddedContent
        }
    }

    @ViewBuilder
    private func iconLabel(systemName: String, config: TitlebarControlsStyleConfig) -> some View {
        let icon = Image(systemName: systemName)
            .font(.system(size: config.iconSize, weight: .semibold))
            .frame(width: config.buttonSize, height: config.buttonSize)

        if config.buttonBackground {
            icon
                .background(
                    RoundedRectangle(cornerRadius: config.buttonCornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                )
        } else {
            icon
        }
    }
}

final class TitlebarControlsAccessoryViewController: NSTitlebarAccessoryViewController, NSPopoverDelegate {
    private let hostingView: NonDraggableHostingView<TitlebarControlsView>
    private let containerView = NSView()
    private let notificationStore: TerminalNotificationStore
    private lazy var notificationsPopover: NSPopover = makeNotificationsPopover()
    private var pendingSizeUpdate = false
    private let viewModel = TitlebarControlsViewModel()
    private var userDefaultsObserver: NSObjectProtocol?

    init(notificationStore: TerminalNotificationStore) {
        self.notificationStore = notificationStore
        let toggleSidebar = { _ = AppDelegate.shared?.sidebarState?.toggle() }
        let toggleNotifications: () -> Void = { _ = AppDelegate.shared?.toggleNotificationsPopover(animated: true) }
        let newTab = { _ = AppDelegate.shared?.tabManager?.addTab() }

        hostingView = NonDraggableHostingView(
            rootView: TitlebarControlsView(
                notificationStore: notificationStore,
                viewModel: viewModel,
                onToggleSidebar: toggleSidebar,
                onToggleNotifications: toggleNotifications,
                onNewTab: newTab
            )
        )

        super.init(nibName: nil, bundle: nil)

        view = containerView
        containerView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)

        // macOS 14 (Sonoma) changed clipsToBounds default to NO, which can cause
        // titlebar accessory views to render incorrectly or disappear during layout.
        if #available(macOS 14, *) {
            containerView.clipsToBounds = true
            hostingView.clipsToBounds = true
        }

        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleSizeUpdate()
        }

        scheduleSizeUpdate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ensureVisible()
        scheduleSizeUpdate()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        ensureVisible()
        scheduleSizeUpdate()
    }

    /// Sonoma can hide titlebar accessory views during layout transitions.
    /// Force visibility on every layout pass.
    private func ensureVisible() {
        view.isHidden = false
        containerView.isHidden = false
        hostingView.isHidden = false
    }

    private func scheduleSizeUpdate() {
        guard !pendingSizeUpdate else { return }
        pendingSizeUpdate = true
        DispatchQueue.main.async { [weak self] in
            self?.pendingSizeUpdate = false
            self?.updateSize()
        }
    }

    private func updateSize() {
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        let contentSize = hostingView.fittingSize
        // Guard against zero-size frames during layout transitions (Sonoma)
        guard contentSize.width > 1 && contentSize.height > 1 else { return }
        let titlebarHeight = view.window.map { window in
            window.frame.height - window.contentLayoutRect.height
        } ?? contentSize.height
        let containerHeight = max(contentSize.height, titlebarHeight)
        let yOffset = max(0, (containerHeight - contentSize.height) / 2.0)
        preferredContentSize = NSSize(width: contentSize.width, height: containerHeight)
        containerView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: containerHeight)
        hostingView.frame = NSRect(x: 0, y: yOffset, width: contentSize.width, height: contentSize.height)
    }

    func toggleNotificationsPopover(animated: Bool = true) {
        if notificationsPopover.isShown {
            notificationsPopover.performClose(nil)
            return
        }
        // Recreate content view each time to avoid stale observers when popover is hidden
        let hostingController = NSHostingController(
            rootView: NotificationsPopoverView(
                notificationStore: notificationStore,
                onDismiss: { [weak notificationsPopover] in
                    notificationsPopover?.performClose(nil)
                }
            )
        )
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear
        notificationsPopover.contentViewController = hostingController

        guard let window = view.window ?? hostingView.window ?? NSApp.keyWindow,
              let contentView = window.contentView else {
            return
        }

        // Force layout to ensure geometry is current.
        contentView.layoutSubtreeIfNeeded()

        if let anchorView = viewModel.notificationsAnchorView, anchorView.window != nil {
            anchorView.superview?.layoutSubtreeIfNeeded()
            let anchorRect = anchorView.convert(anchorView.bounds, to: contentView)
            if !anchorRect.isEmpty {
                notificationsPopover.animates = animated
                notificationsPopover.show(relativeTo: anchorRect, of: contentView, preferredEdge: .maxY)
                return
            }
        }

        // Fallback: position near top-left of the window content.
        let bounds = contentView.bounds
        let anchorRect = NSRect(x: 12, y: bounds.maxY - 8, width: 1, height: 1)
        notificationsPopover.animates = animated
        notificationsPopover.show(relativeTo: anchorRect, of: contentView, preferredEdge: .maxY)
    }

    private func makeNotificationsPopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        // Content view controller is set dynamically in toggleNotificationsPopover
        return popover
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        // Clear the content view controller to stop SwiftUI observers when popover is hidden
        notificationsPopover.contentViewController = nil
    }
}

private struct NotificationsPopoverView: View {
    @ObservedObject var notificationStore: TerminalNotificationStore
    let onDismiss: () -> Void
    @FocusState private var focusedNotificationId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notifications")
                    .font(.headline)
                Spacer()
                if !notificationStore.notifications.isEmpty {
                    Button("Clear All") {
                        notificationStore.clearAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if notificationStore.notifications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No notifications yet")
                        .font(.headline)
                    Text("Desktop notifications will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 420, idealWidth: 520, maxWidth: 640, minHeight: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notificationStore.notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                tabTitle: tabTitle(for: notification.tabId),
                                onOpen: { open(notification) },
                                onClear: { notificationStore.remove(id: notification.id) },
                                focusedNotificationId: $focusedNotificationId,
                                compact: true
                            )
                        }
                    }
                    .padding(12)
                }
                .frame(minWidth: 420, idealWidth: 520, maxWidth: 640, minHeight: 320, maxHeight: 480)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: setInitialFocus)
        .onChange(of: notificationStore.notifications.first?.id) { _ in
            setInitialFocus()
        }
    }

    private func setInitialFocus() {
        guard let firstId = notificationStore.notifications.first?.id else {
            focusedNotificationId = nil
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedNotificationId = firstId
        }
    }

    private func tabTitle(for tabId: UUID) -> String? {
        AppDelegate.shared?.tabManager?.tabs.first(where: { $0.id == tabId })?.title
    }

    private func open(_ notification: TerminalNotification) {
        AppDelegate.shared?.tabManager?.focusTabFromNotification(notification.tabId, surfaceId: notification.surfaceId)
        markReadIfFocused(notification)
        onDismiss()
    }

    private func markReadIfFocused(_ notification: TerminalNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let tabManager = AppDelegate.shared?.tabManager else { return }
            guard tabManager.selectedTabId == notification.tabId else { return }
            if let surfaceId = notification.surfaceId {
                guard tabManager.focusedSurfaceId(for: notification.tabId) == surfaceId else { return }
            }
            notificationStore.markRead(id: notification.id)
        }
    }
}

final class TitlebarAccessoryController {
    private var didStart = false
    private let attachedWindows = NSHashTable<NSWindow>.weakObjects()
    private var observers: [NSObjectProtocol] = []
    private let controlsIdentifier = NSUserInterfaceItemIdentifier("cter.titlebarControls")
    private let controlsControllers = NSHashTable<TitlebarControlsAccessoryViewController>.weakObjects()

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        attachToExistingWindows()
        installObservers()
        installSidebarToggleObserver()
    }

    func attach(to window: NSWindow) {
        attachIfNeeded(to: window)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.attachIfNeeded(to: window)
        })

        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.attachIfNeeded(to: window)
        })
    }

    private func attachToExistingWindows() {
        for window in NSApp.windows {
            attachIfNeeded(to: window)
        }
    }

    private func attachIfNeeded(to window: NSWindow) {
        guard !attachedWindows.contains(window) else { return }
        guard window.styleMask.contains(.titled) else { return }
        guard isMainTerminalWindow(window) else { return }
        guard !isSettingsWindow(window) else { return }

        addControlsIfMissing(to: window)
        attachedWindows.add(window)
    }

    private func addControlsIfMissing(to window: NSWindow) {
        guard !window.titlebarAccessoryViewControllers.contains(where: { $0.view.identifier == controlsIdentifier }) else { return }
        let controls = TitlebarControlsAccessoryViewController(
            notificationStore: TerminalNotificationStore.shared
        )
        controls.layoutAttribute = .left
        controls.view.identifier = controlsIdentifier
        window.addTitlebarAccessoryViewController(controls)
        controlsControllers.add(controls)
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == "cter.settings" {
            return true
        }
        return window.title == "Settings"
    }

    private func isMainTerminalWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == "cter.main"
    }

    /// After sidebar toggle on Sonoma, titlebar accessories can disappear. Re-add if needed.
    private func installSidebarToggleObserver() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: SidebarState.didToggleNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay slightly to let SwiftUI layout settle before revalidating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.revalidateAllAccessories()
            }
        })
    }

    private func revalidateAllAccessories() {
        for window in attachedWindows.allObjects {
            // Re-add controls if they were removed during layout
            addControlsIfMissing(to: window)

            // Ensure all accessories are visible and properly sized
            for controller in window.titlebarAccessoryViewControllers {
                controller.view.isHidden = false
                controller.view.needsLayout = true
            }
        }
    }

    func toggleNotificationsPopover(animated: Bool = true) {
        for controller in controlsControllers.allObjects {
            controller.toggleNotificationsPopover(animated: animated)
        }
    }
}
