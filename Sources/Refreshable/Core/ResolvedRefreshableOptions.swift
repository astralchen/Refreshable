import UIKit

struct ResolvedRefreshableOptions {
    let extent: CGFloat
    let triggerDistance: CGFloat
    let animationDuration: TimeInterval
    let automaticallyEnds: Bool
    let allowsLoadMoreWhenContentFits: Bool
    let automaticTriggerDistance: RefreshableOptions.AutomaticTriggerDistance?
    let placement: RefreshablePlacement
    let presentation: RefreshablePresentation
    let overlayAnchor: RefreshableOverlayAnchor

    init(
        options: RefreshableOptions,
        styleExtent: CGFloat,
        styleTriggerDistance: CGFloat,
        stylePlacement: RefreshablePlacement
    ) {
        extent = Self.positiveDimension(styleExtent)
        triggerDistance = Self.positiveDimension(options.triggerDistance ?? styleTriggerDistance)
        animationDuration = Self.nonnegative(options.animationDuration)
        automaticallyEnds = options.automaticallyEnds
        allowsLoadMoreWhenContentFits = options.allowsLoadMoreWhenContentFits
        automaticTriggerDistance = Self.automaticTriggerDistance(options.automaticTriggerDistance)
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

    private static func automaticTriggerDistance(
        _ offset: RefreshableOptions.AutomaticTriggerDistance?
    ) -> RefreshableOptions.AutomaticTriggerDistance? {
        guard case .distance(let value) = offset else { return offset }
        guard value.isFinite, value >= 0 else { return nil }
        return .distance(value)
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
