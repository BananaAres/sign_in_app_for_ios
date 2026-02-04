import SwiftUI
import UIKit

struct TimelineScrollView<Content: View>: UIViewRepresentable {
    @Binding var isSelecting: Bool
    let onLongPressBegan: (CGPoint) -> Void
    let onLongPressChanged: (CGPoint) -> Void
    let onLongPressEnded: (CGPoint) -> Void
    let isTouchOnPlanBlock: (CGPoint) -> Bool
    let content: Content

    init(
        isSelecting: Binding<Bool>,
        onLongPressBegan: @escaping (CGPoint) -> Void,
        onLongPressChanged: @escaping (CGPoint) -> Void,
        onLongPressEnded: @escaping (CGPoint) -> Void,
        isTouchOnPlanBlock: @escaping (CGPoint) -> Bool = { _ in false },
        @ViewBuilder content: () -> Content
    ) {
        _isSelecting = isSelecting
        self.onLongPressBegan = onLongPressBegan
        self.onLongPressChanged = onLongPressChanged
        self.onLongPressEnded = onLongPressEnded
        self.isTouchOnPlanBlock = isTouchOnPlanBlock
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .clear
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.delegate = context.coordinator

        let host = UIHostingController(rootView: content)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = true

        scrollView.addSubview(host.view)
        context.coordinator.hostingController = host

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.35
        longPress.allowableMovement = 12
        longPress.delaysTouchesBegan = false
        longPress.delaysTouchesEnded = false
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        scrollView.addGestureRecognizer(longPress)
        context.coordinator.longPress = longPress
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostingController?.rootView = content
        context.coordinator.updateSelectionState(isSelecting)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        var parent: TimelineScrollView
        var hostingController: UIHostingController<Content>?
        weak var longPress: UILongPressGestureRecognizer?
        weak var scrollView: UIScrollView?
        private var autoScrollDisplayLink: CADisplayLink?
        private var autoScrollDirection: CGFloat = 0
        private var lastTouchLocationInScrollView: CGPoint = .zero
        private let autoScrollThreshold: CGFloat = 50
        private let autoScrollSpeed: CGFloat = 8
        private var isAutoScrolling = false
        private var isSelectionActive = false
        private let initialAllowableMovement: CGFloat = 12

        init(parent: TimelineScrollView) {
            self.parent = parent
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            let locationInScrollView = recognizer.location(in: scrollView)
            lastTouchLocationInScrollView = locationInScrollView
            let location = contentLocation(from: locationInScrollView, in: scrollView)

            switch recognizer.state {
            case .began:
                isSelectionActive = true
                longPress?.allowableMovement = .greatestFiniteMagnitude
                // 关键：禁用滚动，让手指移动直接更新框选
                scrollView.isScrollEnabled = false
                parent.onLongPressBegan(location)
            case .changed:
                guard isSelectionActive else { return }
                parent.onLongPressChanged(location)
                updateAutoScrollDirection(for: locationInScrollView, in: scrollView)
            case .ended, .cancelled, .failed:
                if isSelectionActive {
                    parent.onLongPressEnded(location)
                }
                endSelection()
            default:
                break
            }
        }

        private func endSelection() {
            isSelectionActive = false
            longPress?.allowableMovement = initialAllowableMovement
            scrollView?.isScrollEnabled = true
            stopAutoScroll()
        }

        func updateSelectionState(_ isSelecting: Bool) {
            if !isSelecting && isSelectionActive {
                endSelection()
            }
        }

        private func updateAutoScrollDirection(for locationInScrollView: CGPoint, in scrollView: UIScrollView) {
            let visibleY = locationInScrollView.y - scrollView.contentOffset.y
            let height = scrollView.bounds.height
            if visibleY < autoScrollThreshold {
                autoScrollDirection = -1
                startAutoScroll()
            } else if visibleY > height - autoScrollThreshold {
                autoScrollDirection = 1
                startAutoScroll()
            } else {
                stopAutoScroll()
            }
        }

        private func startAutoScroll() {
            guard autoScrollDisplayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(handleAutoScroll))
            link.add(to: .main, forMode: .common)
            autoScrollDisplayLink = link
        }

        private func stopAutoScroll() {
            autoScrollDirection = 0
            autoScrollDisplayLink?.invalidate()
            autoScrollDisplayLink = nil
        }

        @objc private func handleAutoScroll() {
            guard let scrollView = scrollView, autoScrollDirection != 0, isSelectionActive else { return }
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            if maxOffset <= 0 {
                stopAutoScroll()
                return
            }

            isAutoScrolling = true
            let delta = autoScrollSpeed * autoScrollDirection
            let nextOffset = min(max(scrollView.contentOffset.y + delta, 0), maxOffset)
            if nextOffset == scrollView.contentOffset.y {
                isAutoScrolling = false
                stopAutoScroll()
                return
            }
            
            scrollView.contentOffset.y = nextOffset
            lastTouchLocationInScrollView.y += delta
            
            let location = contentLocation(from: lastTouchLocationInScrollView, in: scrollView)
            parent.onLongPressChanged(location)
            isAutoScrolling = false
        }

        private func contentLocation(from locationInScrollView: CGPoint, in scrollView: UIScrollView) -> CGPoint {
            // 直接使用 scrollView 中的位置，这与 SwiftUI 内容的坐标系一致
            // 因为 hostView 是 scrollView 的直接子视图，位置相同
            return locationInScrollView
        }

        deinit {
            autoScrollDisplayLink?.invalidate()
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if isSelectionActive {
                return false
            }
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === longPress, let scrollView = scrollView else { return true }
            let locationInScrollView = gestureRecognizer.location(in: scrollView)
            let location = contentLocation(from: locationInScrollView, in: scrollView)
            // 如果触摸在任务块上，不开始框选手势
            let onPlanBlock = parent.isTouchOnPlanBlock(location)
            return !onPlanBlock
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === longPress, let scrollView = scrollView else { return true }
            let locationInScrollView = touch.location(in: scrollView)
            let location = contentLocation(from: locationInScrollView, in: scrollView)
            // 如果触摸在任务块上，不接收这个触摸
            let onPlanBlock = parent.isTouchOnPlanBlock(location)
            return !onPlanBlock
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }
    }
}
