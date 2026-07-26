import UIKit

struct ResolvedRefreshableOptions {
    let extent: CGFloat
    let triggerOffset: CGFloat
    let animationDuration: TimeInterval
    let automaticallyEndRefreshing: Bool
    let allowsLoadMoreWhenContentFits: Bool
    let automaticTriggerOffset: RefreshableOptions.AutomaticTriggerOffset?
    let placement: RefreshablePlacement
    let presentation: RefreshablePresentation
    let overlayAnchor: RefreshableOverlayAnchor

    init(
        options: RefreshableOptions,
        styleExtent: CGFloat,
        styleTriggerOffset: CGFloat,
        stylePlacement: RefreshablePlacement
    ) {
        extent = Self.positiveDimension(styleExtent)
        triggerOffset = Self.positiveDimension(options.triggerOffset ?? styleTriggerOffset)
        animationDuration = Self.nonnegative(options.animationDuration)
        automaticallyEndRefreshing = options.automaticallyEndRefreshing
        allowsLoadMoreWhenContentFits = options.allowsLoadMoreWhenContentFits
        automaticTriggerOffset = Self.automaticTriggerOffset(options.automaticTriggerOffset)
        placement = Self.placement(options.placement ?? stylePlacement)
        presentation = Self.presentation(options.presentation)
        overlayAnchor = options.overlayAnchor
    }

    private static func positiveDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite && value > 0 ? value : 1
    }

    private static func nonnegative<T: BinaryFloatingPoint>(_ value: T) -> T {
        value.isFinite && value >= 0 ? value : 0
    }

    private static func placement(_ placement: RefreshablePlacement) -> RefreshablePlacement {
        RefreshablePlacement(
            contentSpacing: nonnegative(placement.contentSpacing),
            outerSpacing: nonnegative(placement.outerSpacing),
            crossAxisInset: nonnegative(placement.crossAxisInset)
        )
    }

    private static func automaticTriggerOffset(
        _ offset: RefreshableOptions.AutomaticTriggerOffset?
    ) -> RefreshableOptions.AutomaticTriggerOffset? {
        guard case .offset(let value) = offset else { return offset }
        guard value.isFinite, value >= 0 else { return nil }
        return .offset(value)
    }

    private static func presentation(_ presentation: RefreshablePresentation) -> RefreshablePresentation {
        switch presentation {
        case .contentInset:
            .contentInset
        case .overlay(let spacing, let locksContentOffset):
            .overlay(spacing: nonnegative(spacing), locksContentOffset: locksContentOffset)
        }
    }
}
