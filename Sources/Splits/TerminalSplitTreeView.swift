import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct TerminalSplitTreeView: View {
    @ObservedObject var tab: Tab
    let isTabActive: Bool
    @State private var config = GhosttyConfig.load()
    @EnvironmentObject var notificationStore: TerminalNotificationStore

    var body: some View {
        let appearance = SplitAppearance(
            dividerColor: Color(nsColor: config.resolvedSplitDividerColor),
            unfocusedOverlayColor: Color(nsColor: config.unfocusedSplitOverlayFill),
            unfocusedOverlayOpacity: config.unfocusedSplitOverlayOpacity
        )
        Group {
            if let node = tab.splitTree.zoomed ?? tab.splitTree.root {
                TerminalSplitSubtreeView(
                    tab: tab,
                    node: node,
                    isRoot: node == tab.splitTree.root,
                    isSplit: tab.splitTree.isSplit,
                    isTabActive: isTabActive,
                    focusedSurfaceId: tab.focusedSurfaceId,
                    appearance: appearance,
                    tabId: tab.id,
                    notificationStore: notificationStore,
                    onFocus: { tab.focusSurface($0) },
                    onTriggerFlash: { tab.triggerDebugFlash(surfaceId: $0) },
                    onResize: { tab.updateSplitRatio(node: $0, ratio: $1) },
                    onEqualize: { tab.equalizeSplits() }
                )
                .id(node.structuralIdentity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { tab.updateSplitViewSize(proxy.size) }
                .onChange(of: proxy.size) { tab.updateSplitViewSize($0) }
        })
        .onReceive(NotificationCenter.default.publisher(for: .ghosttyConfigDidReload)) { _ in
            config = GhosttyConfig.load()
        }
    }
}

fileprivate struct TerminalSplitSubtreeView: View {
    let tab: Tab
    let node: SplitTree<TerminalPane>.Node
    let isRoot: Bool
    let isSplit: Bool
    let isTabActive: Bool
    let focusedSurfaceId: UUID?
    let appearance: SplitAppearance
    let tabId: UUID
    let notificationStore: TerminalNotificationStore
    let onFocus: (UUID) -> Void
    let onTriggerFlash: (UUID) -> Void
    let onResize: (SplitTree<TerminalPane>.Node, Double) -> Void
    let onEqualize: () -> Void

    var body: some View {
        switch node {
        case .leaf(let pane):
            TerminalPaneView(
                pane: pane,
                tab: tab,
                isTabActive: isTabActive,
                isSplit: isSplit,
                appearance: appearance,
                notificationStore: notificationStore,
                onFocus: onFocus,
                onTriggerFlash: onTriggerFlash
            )
        case .split(let split):
            let splitViewDirection: SplitViewDirection = switch split.direction {
            case .horizontal: .horizontal
            case .vertical: .vertical
            }

            SplitView(
                splitViewDirection,
                .init(get: {
                    CGFloat(split.ratio)
                }, set: {
                    onResize(node, Double($0))
                }),
                dividerColor: appearance.dividerColor,
                resizeIncrements: .init(width: 1, height: 1),
                left: {
                    TerminalSplitSubtreeView(
                        tab: tab,
                        node: split.left,
                        isRoot: false,
                        isSplit: isSplit,
                        isTabActive: isTabActive,
                        focusedSurfaceId: focusedSurfaceId,
                        appearance: appearance,
                        tabId: tabId,
                        notificationStore: notificationStore,
                        onFocus: onFocus,
                        onTriggerFlash: onTriggerFlash,
                        onResize: onResize,
                        onEqualize: onEqualize
                    )
                },
                right: {
                    TerminalSplitSubtreeView(
                        tab: tab,
                        node: split.right,
                        isRoot: false,
                        isSplit: isSplit,
                        isTabActive: isTabActive,
                        focusedSurfaceId: focusedSurfaceId,
                        appearance: appearance,
                        tabId: tabId,
                        notificationStore: notificationStore,
                        onFocus: onFocus,
                        onTriggerFlash: onTriggerFlash,
                        onResize: onResize,
                        onEqualize: onEqualize
                    )
                },
                onEqualize: {
                    onEqualize()
                }
            )
        }
    }
}

private struct SplitAppearance {
    let dividerColor: Color
    let unfocusedOverlayColor: Color
    let unfocusedOverlayOpacity: Double
}

/// A split leaf: a tab bar of terminals on top, the selected terminal below.
/// Unselected terminals stay mounted (hidden) so their views and scrollback survive.
private struct TerminalPaneView: View {
    @ObservedObject var pane: TerminalPane
    @ObservedObject var tab: Tab
    let isTabActive: Bool
    let isSplit: Bool
    let appearance: SplitAppearance
    let notificationStore: TerminalNotificationStore
    let onFocus: (UUID) -> Void
    let onTriggerFlash: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaneTabBar(
                pane: pane,
                tab: tab,
                isPaneFocused: isTabActive && tab.focusedSurfaceId.map(pane.contains(surfaceId:)) == true,
                notificationStore: notificationStore
            )
            ZStack {
                ForEach(pane.surfaces) { surface in
                    let isSelected = surface.id == pane.selectedSurfaceId
                    TerminalSurfaceView(
                        surface: surface,
                        isFocused: isTabActive && tab.focusedSurfaceId == surface.id,
                        isSplit: isSplit,
                        appearance: appearance,
                        tabId: tab.id,
                        notificationStore: notificationStore,
                        onFocus: { onFocus(surface.id) },
                        onTriggerFlash: { onTriggerFlash(surface.id) }
                    )
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                }
            }
        }
    }
}

private struct PaneTabBar: View {
    @ObservedObject var pane: TerminalPane
    @ObservedObject var tab: Tab
    let isPaneFocused: Bool
    let notificationStore: TerminalNotificationStore

    static let height: CGFloat = 28

    var body: some View {
        let background = Color(nsColor: GhosttyApp.shared.defaultBackgroundColor)
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(pane.surfaces) { surface in
                        PaneTabItem(
                            title: title(for: surface),
                            isSelected: surface.id == pane.selectedSurfaceId,
                            isPaneFocused: isPaneFocused,
                            hasUnread: notificationStore.hasUnreadNotification(forTabId: tab.id, surfaceId: surface.id),
                            selectedBackground: background,
                            onSelect: { tab.selectSurface(surface.id) },
                            onClose: { closeSurface(surface.id) }
                        )
                        .onDrag { NSItemProvider(object: surface.id.uuidString as NSString) }
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            reorder(providers: providers, onto: surface.id)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                PaneBarButton(systemImage: "plus", help: "New Terminal") {
                    newSurface()
                }
                PaneBarButton(systemImage: "square.split.2x1", help: "Split Right") {
                    split(.right)
                }
                PaneBarButton(systemImage: "square.split.1x2", help: "Split Down") {
                    split(.down)
                }
            }
            .padding(.trailing, 6)
        }
        .frame(height: Self.height)
        .background(background)
        .background(Color.primary.opacity(0.06))
        .compositingGroup()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func title(for surface: TerminalSurface) -> String {
        let title = tab.surfaceTitles[surface.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Terminal" : title
    }

    private var anchorSurfaceId: UUID {
        pane.selectedSurface?.id ?? pane.selectedSurfaceId
    }

    private func newSurface() {
        let previous = tab.focusedSurface
        guard let surface = tab.newSurface(inPaneOf: anchorSurfaceId) else { return }
        DispatchQueue.main.async {
            surface.hostedView.moveFocus(from: previous?.hostedView)
        }
    }

    private func split(_ direction: SplitTree<TerminalPane>.NewDirection) {
        let previous = tab.focusedSurface
        guard let surface = tab.newSplit(from: anchorSurfaceId, direction: direction) else { return }
        DispatchQueue.main.async {
            surface.hostedView.moveFocus(from: previous?.hostedView)
        }
    }

    private func closeSurface(_ surfaceId: UUID) {
        AppDelegate.shared?.tabManager?.closePanelWithConfirmation(tabId: tab.id, surfaceId: surfaceId)
    }

    private func reorder(providers: [NSItemProvider], onto targetId: UUID) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, let draggedId = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                guard draggedId != targetId,
                      pane.contains(surfaceId: draggedId),
                      let destination = pane.surfaces.firstIndex(where: { $0.id == targetId }) else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    pane.move(surfaceId: draggedId, to: destination)
                }
            }
        }
        return true
    }
}

private struct PaneTabItem: View {
    let title: String
    let isSelected: Bool
    let isPaneFocused: Bool
    let hasUnread: Bool
    let selectedBackground: Color
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer(minLength: 0)
            ZStack {
                if hasUnread && !isHovering {
                    Circle()
                        .fill(Color(nsColor: .systemBlue))
                        .frame(width: 6, height: 6)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isSelected ? 1 : 0)
                .help("Close Terminal")
            }
            .frame(width: 16, height: 16)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(minWidth: 90, idealWidth: 180, maxWidth: 220, maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(isSelected ? selectedBackground : Color.clear)
        .overlay(alignment: .top) {
            if isSelected && isPaneFocused {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Close Terminal", action: onClose)
        }
    }
}

private struct PaneBarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovering ? .primary : .secondary)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(isHovering ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

private struct TerminalSurfaceView: View {
    @ObservedObject var surface: TerminalSurface
    let isFocused: Bool
    let isSplit: Bool
    let appearance: SplitAppearance
    let tabId: UUID
    let notificationStore: TerminalNotificationStore
    let onFocus: () -> Void
    let onTriggerFlash: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            GhosttyTerminalView(
                terminalSurface: surface,
                isActive: isFocused,
                onFocus: { _ in onFocus() },
                onTriggerFlash: onTriggerFlash
            )
            .background(Color.clear)

            if isSplit && !isFocused && appearance.unfocusedOverlayOpacity > 0 {
                Rectangle()
                    .fill(appearance.unfocusedOverlayColor)
                    .opacity(appearance.unfocusedOverlayOpacity)
                    .allowsHitTesting(false)
            }

            if notificationStore.hasUnreadNotification(forTabId: tabId, surfaceId: surface.id) {
                Rectangle()
                    .stroke(Color(nsColor: .systemBlue), lineWidth: 2.5)
                    .shadow(color: Color(nsColor: .systemBlue).opacity(0.35), radius: 3)
                    .padding(2)
                    .allowsHitTesting(false)
            }

            if let searchState = surface.searchState {
                SurfaceSearchOverlay(
                    surface: surface,
                    searchState: searchState,
                    onClose: {
                        surface.searchState = nil
                        surface.hostedView.moveFocus()
                    }
                )
            }
        }
    }
}
