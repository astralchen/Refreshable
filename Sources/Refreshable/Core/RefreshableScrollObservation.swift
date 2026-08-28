import UIKit

/// 描述一次滚动环境更新中真正发生变化的输入。
///
/// 完整快照用于保证各组件读取同一时刻的数据；变化集合用于避免把一次
/// `contentOffset` KVO 错误解释为内容尺寸、视口或 inset 同时发生变化。
@MainActor
struct RefreshableScrollChanges: OptionSet {
    let rawValue: UInt8

    static let contentOffset = Self(rawValue: 1 << 0)
    static let contentSize = Self(rawValue: 1 << 1)
    static let viewportSize = Self(rawValue: 1 << 2)
    static let contentInset = Self(rawValue: 1 << 3)
    static let environment = Self(rawValue: 1 << 4)
    static let all: Self = [
        .contentOffset,
        .contentSize,
        .viewportSize,
        .contentInset,
        .environment,
    ]
}

/// Edge runtime 使用的完整、不可变 scroll view 输入快照。
@MainActor
struct RefreshableScrollSnapshot {
    let contentOffset: CGPoint
    let contentSize: CGSize
    let bounds: CGRect
    let contentInset: UIEdgeInsets
    let adjustedInsetDelta: UIEdgeInsets
    let safeAreaInsets: UIEdgeInsets
    let layoutDirection: UIUserInterfaceLayoutDirection
    let isDragging: Bool
    let panState: UIGestureRecognizer.State

    init(scrollView: UIScrollView) {
        contentOffset = scrollView.contentOffset
        contentSize = scrollView.contentSize
        bounds = scrollView.bounds
        contentInset = scrollView.contentInset
        adjustedInsetDelta = UIEdgeInsets(
            top: scrollView.adjustedContentInset.top - scrollView.contentInset.top,
            left: scrollView.adjustedContentInset.left - scrollView.contentInset.left,
            bottom: scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom,
            right: scrollView.adjustedContentInset.right - scrollView.contentInset.right
        )
        safeAreaInsets = scrollView.safeAreaInsets
        layoutDirection = scrollView.effectiveUserInterfaceLayoutDirection
        isDragging = scrollView.isDragging
        panState = scrollView.panGestureRecognizer.state
    }
}

/// 一次滚动环境更新及其对应的完整输入快照。
@MainActor
struct RefreshableScrollUpdate {
    let snapshot: RefreshableScrollSnapshot
    let changes: RefreshableScrollChanges
}

/// 为一个 scroll view 持有唯一一组 UIKit 观察，并转发环境快照。
@MainActor
final class RefreshableScrollObservationSet: NSObject {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var observesPan = false
    private(set) var startCount = 0

    var onUpdate: (@MainActor (RefreshableScrollUpdate) -> Void)?
    var onPanEnded: (@MainActor () -> Void)?
    var onPanCancelled: (@MainActor () -> Void)?

    func start(for scrollView: UIScrollView) {
        stop()
        startCount += 1
        self.scrollView = scrollView
        observations = [
            scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit(changes: .contentOffset) }
            },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit(changes: .contentSize) }
            },
            scrollView.observe(\.bounds, options: [.old, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard change.oldValue?.size != change.newValue?.size else { return }
                    self?.emit(changes: .viewportSize)
                }
            },
            scrollView.observe(\.contentInset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit(changes: .contentInset) }
            },
            scrollView.observe(\.semanticContentAttribute, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit(changes: .environment) }
            }
        ]
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        observesPan = true
        emit(changes: .all)
    }

    func stop() {
        if observesPan {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePan(_:)))
        }
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        observesPan = false
        scrollView = nil
    }

    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .ended:
            onPanEnded?()
        case .cancelled, .failed:
            onPanCancelled?()
        default:
            break
        }
        emit(changes: .contentOffset)
    }

    private func emit(changes: RefreshableScrollChanges) {
        guard let scrollView else { return }
        MainActor.assumeIsolated {
            onUpdate?(
                RefreshableScrollUpdate(
                    snapshot: RefreshableScrollSnapshot(scrollView: scrollView),
                    changes: changes
                )
            )
        }
    }
}
