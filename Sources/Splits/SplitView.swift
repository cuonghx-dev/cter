import AppKit
import SwiftUI

/// A split view shows a left and right (or top and bottom) view with a divider in the middle to do resizing.
/// The terminology "left" and "right" is always used but for vertical splits "left" is "top" and "right" is "bottom".
struct SplitView<L: View, R: View>: View {
    /// Direction of the split
    let direction: SplitViewDirection

    /// Divider color
    let dividerColor: Color

    /// Minimum increment (in points) that this split can be resized by, in
    /// each direction. Both `height` and `width` should be whole numbers
    /// greater than or equal to 1.0
    let resizeIncrements: NSSize

    /// The left and right views to render.
    let left: L
    let right: R

    /// Called when the divider is double-tapped to equalize splits.
    let onEqualize: () -> Void

    /// The minimum size (in points) of a split. Large enough that a pane keeps its 28pt tab bar
    /// plus a couple of terminal rows/columns instead of collapsing to an invisible sliver.
    let minSize: CGFloat = 60

    /// Within this distance (in points) of the midpoint, dragging snaps to an even split.
    private let snapDistance: CGFloat = 6

    @State private var isDragging = false

    /// The current fractional width of the split view. 0.5 means L/R are equally sized, for example.
    @Binding var split: CGFloat

    /// The visible size of the splitter, in points. The invisible size is a transparent hitbox that can still
    /// be used for getting a resize handle. The total width/height of the splitter is the sum of both.
    private let splitterVisibleSize: CGFloat = 1
    private let splitterInvisibleSize: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let leftRect = self.leftRect(for: geo.size)
            let rightRect = self.rightRect(for: geo.size, leftRect: leftRect)
            let splitterPoint = self.splitterPoint(for: geo.size, leftRect: leftRect)

            ZStack(alignment: .topLeading) {
                left
                    .frame(width: leftRect.size.width, height: leftRect.size.height)
                    .offset(x: leftRect.origin.x, y: leftRect.origin.y)
                right
                    .frame(width: rightRect.size.width, height: rightRect.size.height)
                    .offset(x: rightRect.origin.x, y: rightRect.origin.y)
                Divider(direction: direction,
                        visibleSize: splitterVisibleSize,
                        invisibleSize: splitterInvisibleSize,
                        color: dividerColor,
                        isDragging: isDragging,
                        split: $split)
                    .position(splitterPoint)
                    .gesture(dragGesture(geo.size, splitterPoint: splitterPoint))
                    .onTapGesture(count: 2) {
                        onEqualize()
                    }
            }
        }
    }

    /// Initialize a split view that can be resized by manually dragging the divider.
    init(
        _ direction: SplitViewDirection,
        _ split: Binding<CGFloat>,
        dividerColor: Color,
        resizeIncrements: NSSize = .init(width: 1, height: 1),
        @ViewBuilder left: (() -> L),
        @ViewBuilder right: (() -> R),
        onEqualize: @escaping () -> Void
    ) {
        self.direction = direction
        self._split = split
        self.dividerColor = dividerColor
        self.resizeIncrements = resizeIncrements
        self.left = left()
        self.right = right()
        self.onEqualize = onEqualize
    }

    private func dragGesture(_ size: CGSize, splitterPoint: CGPoint) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                if !isDragging { isDragging = true }
                let total = direction == .horizontal ? size.width : size.height
                guard total > 0 else { return }
                let location = direction == .horizontal ? gesture.location.x : gesture.location.y
                // If the container is too small for both minimums, fall back to keeping it centered.
                let lower = min(minSize, total / 2)
                var new = min(max(lower, location), total - lower)
                if abs(new - total / 2) < snapDistance {
                    new = total / 2
                }
                split = new / total
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    /// Calculates the bounding rect for the left view.
    private func leftRect(for size: CGSize) -> CGRect {
        var result = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        switch direction {
        case .horizontal:
            result.size.width = result.size.width * split
            result.size.width -= splitterVisibleSize / 2
            result.size.width -= result.size.width.truncatingRemainder(dividingBy: self.resizeIncrements.width)
        case .vertical:
            result.size.height = result.size.height * split
            result.size.height -= splitterVisibleSize / 2
            result.size.height -= result.size.height.truncatingRemainder(dividingBy: self.resizeIncrements.height)
        }
        return result
    }

    /// Calculates the bounding rect for the right view.
    private func rightRect(for size: CGSize, leftRect: CGRect) -> CGRect {
        var result = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        switch direction {
        case .horizontal:
            result.origin.x += leftRect.size.width
            result.origin.x += splitterVisibleSize / 2
            result.size.width -= result.origin.x
        case .vertical:
            result.origin.y += leftRect.size.height
            result.origin.y += splitterVisibleSize / 2
            result.size.height -= result.origin.y
        }
        return result
    }

    /// Calculates the point at which the splitter should be rendered.
    private func splitterPoint(for size: CGSize, leftRect: CGRect) -> CGPoint {
        switch direction {
        case .horizontal:
            return CGPoint(x: leftRect.size.width, y: size.height / 2)
        case .vertical:
            return CGPoint(x: size.width / 2, y: leftRect.size.height)
        }
    }
}

private struct Divider: View {
    let direction: SplitViewDirection
    let visibleSize: CGFloat
    let invisibleSize: CGFloat
    let color: Color
    let isDragging: Bool
    @Binding var split: CGFloat
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Highlighted while hovered or dragged so the resize target is visible.
    private var isEmphasized: Bool { isHovering || isDragging }
    private let emphasizedSize: CGFloat = 3

    private var pointerStyle: BackportPointerStyle {
        switch direction {
        case .horizontal:
            return .resizeLeftRight
        case .vertical:
            return .resizeUpDown
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: direction == .horizontal ? invisibleSize : nil,
                       height: direction == .vertical ? invisibleSize : nil)
            Rectangle()
                .fill(color)
                .frame(width: direction == .horizontal ? visibleSize : nil,
                       height: direction == .vertical ? visibleSize : nil)
            Rectangle()
                .fill(Color.accentColor.opacity(isDragging ? 0.9 : 0.6))
                .frame(width: direction == .horizontal ? emphasizedSize : nil,
                       height: direction == .vertical ? emphasizedSize : nil)
                .opacity(isEmphasized ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEmphasized)
        }
        .frame(width: direction == .horizontal ? invisibleSize : nil,
               height: direction == .vertical ? invisibleSize : nil)
        .contentShape(Rectangle())
        .backport.pointerStyle(pointerStyle)
        .help("Drag to resize. Double-click to make splits equal.")
        .accessibilityElement()
        .accessibilityLabel("Split divider")
        .accessibilityValue("\(Int((split * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: split = min(0.9, split + 0.05)
            case .decrement: split = max(0.1, split - 0.05)
            @unknown default: break
            }
        }
        .onHover { hovering in
            guard hovering != isHovering else { return }
            isHovering = hovering
            // macOS 15+ uses the pointerStyle modifier; older systems need the cursor stack.
            if #available(macOS 15, *) {
                return
            }
            if hovering {
                switch direction {
                case .horizontal:
                    NSCursor.resizeLeftRight.push()
                case .vertical:
                    NSCursor.resizeUpDown.push()
                }
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            guard isHovering else { return }
            isHovering = false
            if #available(macOS 15, *) {
                return
            }
            NSCursor.pop()
        }
    }
}

enum SplitViewDirection: Codable {
    case horizontal, vertical
}
