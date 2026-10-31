import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct TerminalSplitTreeView: View {
    @ObservedObject var tab: Tab
    let isTabActive: Bool
    @State private var config = GhosttyConfig.shared
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
            config = GhosttyConfig.shared
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

    @ObservedObject private var dragState = SurfaceDragState.shared
    @State private var contentSize: CGSize = .zero
    @State private var dropZone: PaneDropZone?

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
                        isVisible: isTabActive && isSelected,
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
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { contentSize = proxy.size }
                    .onChange(of: proxy.size) { contentSize = $0 }
            })
            .overlay {
                if let dropZone {
                    PaneDropOverlay(zone: dropZone)
                }
            }
            .animation(.easeOut(duration: 0.12), value: dropZone)
            .onDrop(
                of: [.cterPaneSurface],
                delegate: PaneSurfaceDropDelegate(
                    tabId: tab.id,
                    paneId: pane.id,
                    size: contentSize,
                    zone: $dropZone
                )
            )
        }
        .onChange(of: dragState.surfaceId) { if $0 == nil { dropZone = nil } }
    }
}

// MARK: - Pane tab drag and drop

/// Tracks the pane tab (terminal surface) being dragged so drop targets can preview and
/// validate synchronously; item providers only load asynchronously. SwiftUI reports no drag
/// cancellation, so the state clears itself once the mouse button has been released.
final class SurfaceDragState: ObservableObject {
    static let shared = SurfaceDragState()

    @Published private(set) var surfaceId: UUID?
    private var timer: Timer?
    private var releasedTicks = 0

    func begin(_ surfaceId: UUID) {
        self.surfaceId = surfaceId
        releasedTicks = 0
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Wait a couple of ticks after release so an in-flight drop can still read the id.
            if NSEvent.pressedMouseButtons == 0 {
                self.releasedTicks += 1
                if self.releasedTicks >= 2 { self.end() }
            } else {
                self.releasedTicks = 0
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func end() {
        timer?.invalidate()
        timer = nil
        if surfaceId != nil { surfaceId = nil }
    }

    /// The dragged surface id: from the live drag state, else loaded from the drop's item provider.
    func resolve(_ info: DropInfo, completion: @escaping (UUID) -> Void) {
        if let surfaceId {
            completion(surfaceId)
            return
        }
        info.itemProviders(for: [.cterPaneSurface]).first?
            .loadCterDragItem(type: .cterPaneSurface, completion: completion)
    }

    /// Whether a drop is meaningful; optimistic when the dragged id isn't known yet.
    func allows(_ destination: SurfaceDropDestination) -> Bool {
        guard let surfaceId else { return true }
        return AppDelegate.shared?.tabManager?.canMoveSurface(surfaceId, to: destination) ?? false
    }

    func perform(_ info: DropInfo, destination: SurfaceDropDestination) {
        resolve(info) { surfaceId in
            AppDelegate.shared?.tabManager?.moveSurface(surfaceId, to: destination)
        }
        end()
    }
}

/// Where over a terminal a dragged pane tab will land: an edge splits, the center joins the pane.
enum PaneDropZone: Equatable {
    case center, left, right, top, bottom

    /// Edges claim the outer quarter of each side; whichever edge is nearest wins.
    init(location: CGPoint, size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            self = .center
            return
        }
        let x = location.x / size.width
        let y = location.y / size.height
        let distances: [(PaneDropZone, CGFloat)] = [(.left, x), (.right, 1 - x), (.top, y), (.bottom, 1 - y)]
        let nearest = distances.min(by: { $0.1 < $1.1 })!
        self = nearest.1 < 0.25 ? nearest.0 : .center
    }

    func destination(tabId: UUID, paneId: UUID) -> SurfaceDropDestination {
        switch self {
        case .center: .pane(tabId: tabId, paneId: paneId, index: nil)
        case .left: .split(tabId: tabId, paneId: paneId, direction: .left)
        case .right: .split(tabId: tabId, paneId: paneId, direction: .right)
        case .top: .split(tabId: tabId, paneId: paneId, direction: .up)
        case .bottom: .split(tabId: tabId, paneId: paneId, direction: .down)
        }
    }
}

private struct PaneSurfaceDropDelegate: DropDelegate {
    let tabId: UUID
    let paneId: UUID
    let size: CGSize
    @Binding var zone: PaneDropZone?

    private var dragState: SurfaceDragState { .shared }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.cterPaneSurface])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let candidate = PaneDropZone(location: info.location, size: size)
        let allowed = dragState.allows(candidate.destination(tabId: tabId, paneId: paneId))
        let newZone = allowed ? candidate : nil
        if zone != newZone { zone = newZone }
        return DropProposal(operation: allowed ? .move : .forbidden)
    }

    func dropExited(info: DropInfo) {
        zone = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let candidate = PaneDropZone(location: info.location, size: size)
        zone = nil
        let destination = candidate.destination(tabId: tabId, paneId: paneId)
        guard dragState.allows(destination) else {
            dragState.end()
            return false
        }
        dragState.perform(info, destination: destination)
        return true
    }
}

/// Translucent preview of the region a dropped pane tab will occupy.
private struct PaneDropOverlay: View {
    let zone: PaneDropZone

    var body: some View {
        GeometryReader { proxy in
            let rect = previewRect(in: proxy.size)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor.opacity(0.85), lineWidth: 2)
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .padding(4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func previewRect(in size: CGSize) -> CGRect {
        let halfW = size.width / 2
        let halfH = size.height / 2
        switch zone {
        case .center: return CGRect(origin: .zero, size: size)
        case .left: return CGRect(x: 0, y: 0, width: halfW, height: size.height)
        case .right: return CGRect(x: halfW, y: 0, width: halfW, height: size.height)
        case .top: return CGRect(x: 0, y: 0, width: size.width, height: halfH)
        case .bottom: return CGRect(x: 0, y: halfH, width: size.width, height: halfH)
        }
    }
}

/// Drop target for one pane tab: the left half inserts before it, the right half after it.
private struct PaneTabDropDelegate: DropDelegate {
    let tabId: UUID
    let paneId: UUID
    let index: Int
    let width: CGFloat
    @Binding var insertionIndex: Int?

    private var dragState: SurfaceDragState { .shared }

    private func target(_ info: DropInfo) -> Int {
        info.location.x > width / 2 ? index + 1 : index
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.cterPaneSurface])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let target = target(info)
        let allowed = dragState.allows(.pane(tabId: tabId, paneId: paneId, index: target))
        let newValue = allowed ? target : nil
        if insertionIndex != newValue { insertionIndex = newValue }
        return DropProposal(operation: allowed ? .move : .forbidden)
    }

    func dropExited(info: DropInfo) {
        insertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let destination = SurfaceDropDestination.pane(tabId: tabId, paneId: paneId, index: target(info))
        insertionIndex = nil
        guard dragState.allows(destination) else {
            dragState.end()
            return false
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            dragState.perform(info, destination: destination)
        }
        return true
    }
}

private struct PaneTabBar: View {
    @ObservedObject var pane: TerminalPane
    @ObservedObject var tab: Tab
    let isPaneFocused: Bool
    let notificationStore: TerminalNotificationStore

    @ObservedObject private var dragState = SurfaceDragState.shared
    /// Where a hovering pane-tab drag would be inserted; drives the insertion marker.
    @State private var insertionIndex: Int?
    @State private var itemWidths: [UUID: CGFloat] = [:]

    static let height: CGFloat = 28

    var body: some View {
        let background = Color(nsColor: GhosttyApp.shared.defaultBackgroundColor)
        HStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(pane.surfaces.enumerated()), id: \.element.id) { index, surface in
                            tabItem(surface: surface, index: index, background: background)
                        }
                        trailingDropArea
                    }
                    .frame(minWidth: proxy.size.width, maxHeight: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 2) {
                PaneBarButton(systemImage: "plus", help: "New Terminal (⌘T)") {
                    newSurface()
                }
                PaneBarButton(systemImage: "square.split.2x1", help: "Split Right") {
                    split(.right)
                }
                PaneBarButton(systemImage: "square.split.1x2", help: "Split Down") {
                    split(.down)
                }
            }
            .padding(.leading, 4)
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
        .onChange(of: dragState.surfaceId) { if $0 == nil { insertionIndex = nil } }
    }

    @ViewBuilder
    private func tabItem(surface: TerminalSurface, index: Int, background: Color) -> some View {
        PaneTabItem(
            title: title(for: surface),
            isSelected: surface.id == pane.selectedSurfaceId,
            isPaneFocused: isPaneFocused,
            hasUnread: notificationStore.hasUnreadNotification(forTabId: tab.id, surfaceId: surface.id),
            selectedBackground: background,
            onSelect: { tab.selectSurface(surface.id) },
            onClose: { closeSurface(surface.id) },
            moveTargets: moveTargets,
            canMoveToNewTab: tab.allSurfaces.count > 1,
            onMove: { destination in
                AppDelegate.shared?.tabManager?.moveSurface(surface.id, to: destination)
            }
        )
        .opacity(dragState.surfaceId == surface.id ? 0.45 : 1)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { itemWidths[surface.id] = proxy.size.width }
                .onChange(of: proxy.size.width) { itemWidths[surface.id] = $0 }
        })
        .overlay(alignment: .leading) {
            if insertionIndex == index { InsertionMarker() }
        }
        .overlay(alignment: .trailing) {
            if insertionIndex == index + 1 && index == pane.surfaces.count - 1 { InsertionMarker() }
        }
        .onDrag {
            SurfaceDragState.shared.begin(surface.id)
            return NSItemProvider.cterDragItem(surface.id, type: .cterPaneSurface)
        }
        .onDrop(
            of: [.cterPaneSurface],
            delegate: PaneTabDropDelegate(
                tabId: tab.id,
                paneId: pane.id,
                index: index,
                width: itemWidths[surface.id] ?? 0,
                insertionIndex: $insertionIndex
            )
        )
    }

    /// Empty bar space after the last tab: drops append, double-click opens a terminal.
    private var trailingDropArea: some View {
        Color.clear
            .frame(minWidth: 24, maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { newSurface() }
            .onDrop(
                of: [.cterPaneSurface],
                delegate: PaneTabDropDelegate(
                    tabId: tab.id,
                    paneId: pane.id,
                    index: pane.surfaces.count,
                    width: .infinity,
                    insertionIndex: $insertionIndex
                )
            )
    }

    /// Other sidebar tabs a pane tab can be sent to from its context menu.
    private var moveTargets: [(id: UUID, title: String)] {
        guard let tabManager = AppDelegate.shared?.tabManager else { return [] }
        return tabManager.tabs
            .filter { $0.id != tab.id }
            .map { (id: $0.id, title: $0.title) }
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
}

/// Accent bar marking where a dragged pane tab will be inserted.
private struct InsertionMarker: View {
    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 2)
            .padding(.vertical, 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    let moveTargets: [(id: UUID, title: String)]
    let canMoveToNewTab: Bool
    let onMove: (SurfaceDropDestination) -> Void

    @State private var isHovering = false
    @State private var isHoveringClose = false

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
                        .foregroundColor(isHoveringClose ? .primary : .secondary)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(isHoveringClose ? 0.12 : 0))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringClose = $0 }
                .opacity(isHovering || isSelected ? 1 : 0)
                .help("Close Terminal")
                .accessibilityLabel("Close Terminal")
            }
            .frame(width: 16, height: 16)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(minWidth: 90, idealWidth: 180, maxWidth: 220, maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(isSelected ? selectedBackground : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
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
        .onHover { hovering in
            isHovering = hovering
            if !hovering { isHoveringClose = false }
        }
        .contextMenu {
            Button("Move to New Tab") { onMove(.newTab) }
                .disabled(!canMoveToNewTab)
            if !moveTargets.isEmpty {
                Menu("Move to Tab") {
                    ForEach(moveTargets, id: \.id) { target in
                        Button(target.title) { onMove(.tab(target.id)) }
                    }
                }
            }
            Divider()
            Button("Close Terminal", action: onClose)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasUnread ? "\(title), unread" : title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .accessibilityAction(named: "Close Terminal") { onClose() }
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
        .accessibilityLabel(help)
    }
}

private struct TerminalSurfaceView: View {
    @ObservedObject var surface: TerminalSurface
    let isFocused: Bool
    let isVisible: Bool
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
                isVisible: isVisible,
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
