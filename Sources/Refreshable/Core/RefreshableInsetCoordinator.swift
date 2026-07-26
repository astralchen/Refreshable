import ObjectiveC
import UIKit

/// 协调同一滚动视图上所有刷新组件的 `contentInset` 增量。
@MainActor
final class RefreshableInsetCoordinator {
    private struct Contribution {
        let edge: RefreshablePhysicalEdge
        let amount: CGFloat
    }

    nonisolated(unsafe) private static let associationKey = malloc(1)!

    static func coordinator(for scrollView: UIScrollView) -> RefreshableInsetCoordinator {
        if let coordinator = objc_getAssociatedObject(
            scrollView,
            associationKey
        ) as? RefreshableInsetCoordinator {
            return coordinator
        }

        let coordinator = RefreshableInsetCoordinator(scrollView: scrollView)
        objc_setAssociatedObject(
            scrollView,
            associationKey,
            coordinator,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return coordinator
    }

    weak var scrollView: UIScrollView?
    private(set) var baselineInset: UIEdgeInsets
    private var contributions: [ObjectIdentifier: Contribution] = [:]
    private var insetObservation: NSKeyValueObservation?
    private var isApplyingInternalInset = false

    private init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        baselineInset = scrollView.contentInset
        insetObservation = scrollView.observe(\.contentInset, options: [.new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let self, let inset = change.newValue, !self.isApplyingInternalInset else {
                    return
                }
                self.baselineInset = self.subtractingContributions(from: inset)
            }
        }
    }

    func setContribution(owner: AnyObject, edge: RefreshablePhysicalEdge, amount: CGFloat) {
        let amount = amount.isFinite && amount > 0 ? amount : 0
        contributions[ObjectIdentifier(owner)] = Contribution(edge: edge, amount: amount)
        applyEffectiveInset()
    }

    func removeContribution(owner: AnyObject) {
        guard contributions.removeValue(forKey: ObjectIdentifier(owner)) != nil else { return }
        applyEffectiveInset()
    }

    func contribution(for owner: AnyObject) -> CGFloat {
        contributions[ObjectIdentifier(owner)]?.amount ?? 0
    }

    func adjustedBaselineInset(in scrollView: UIScrollView) -> UIEdgeInsets {
        let delta = UIEdgeInsets(
            top: scrollView.adjustedContentInset.top - scrollView.contentInset.top,
            left: scrollView.adjustedContentInset.left - scrollView.contentInset.left,
            bottom: scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom,
            right: scrollView.adjustedContentInset.right - scrollView.contentInset.right
        )
        return UIEdgeInsets(
            top: baselineInset.top + delta.top,
            left: baselineInset.left + delta.left,
            bottom: baselineInset.bottom + delta.bottom,
            right: baselineInset.right + delta.right
        )
    }

    private func applyEffectiveInset() {
        guard let scrollView else { return }
        var inset = baselineInset
        for contribution in contributions.values {
            inset.setValue(
                inset.value(for: contribution.edge) + contribution.amount,
                for: contribution.edge
            )
        }

        guard scrollView.contentInset != inset else { return }
        isApplyingInternalInset = true
        scrollView.contentInset = inset
        isApplyingInternalInset = false
    }

    private func subtractingContributions(from inset: UIEdgeInsets) -> UIEdgeInsets {
        var baseline = inset
        for contribution in contributions.values {
            baseline.setValue(
                baseline.value(for: contribution.edge) - contribution.amount,
                for: contribution.edge
            )
        }
        return baseline
    }
}
