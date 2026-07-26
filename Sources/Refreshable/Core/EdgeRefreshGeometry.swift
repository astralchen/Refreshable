import UIKit

/// 与 UIKit 生命周期无关的四方向刷新几何计算。
struct EdgeRefreshGeometry {
    let physicalEdge: RefreshablePhysicalEdge
    let bounds: CGRect
    let contentSize: CGSize
    let contentOffset: CGPoint
    let baselineInset: UIEdgeInsets
    let boundaryAdjustment: UIEdgeInsets
    let automaticAdjustment: UIEdgeInsets
    let safeAreaInsets: UIEdgeInsets
    let displayExtent: CGFloat
    let placement: RefreshablePlacement

    var reservedExtent: CGFloat {
        placement.outerSpacing + displayExtent + placement.contentSpacing
    }

    var adjustedBaselineInset: UIEdgeInsets {
        UIEdgeInsets(
            top: baselineInset.top + boundaryAdjustment.top,
            left: baselineInset.left + boundaryAdjustment.left,
            bottom: baselineInset.bottom + boundaryAdjustment.bottom,
            right: baselineInset.right + boundaryAdjustment.right
        )
    }

    var pullDistance: CGFloat {
        switch physicalEdge {
        case .top:
            max(-(contentOffset.y + adjustedBaselineInset.top), 0)
        case .bottom:
            max(
                contentOffset.y
                    + bounds.height
                    - contentSize.height
                    - adjustedBaselineInset.bottom,
                0
            )
        case .left:
            max(-(contentOffset.x + adjustedBaselineInset.left), 0)
        case .right:
            max(
                contentOffset.x
                    + bounds.width
                    - contentSize.width
                    - adjustedBaselineInset.right,
                0
            )
        }
    }

    var distanceToBoundary: CGFloat {
        switch physicalEdge {
        case .top:
            max(contentOffset.y + adjustedBaselineInset.top, 0)
        case .bottom:
            max(
                contentSize.height
                    + adjustedBaselineInset.bottom
                    - contentOffset.y
                    - bounds.height,
                0
            )
        case .left:
            max(contentOffset.x + adjustedBaselineInset.left, 0)
        case .right:
            max(
                contentSize.width
                    + adjustedBaselineInset.right
                    - contentOffset.x
                    - bounds.width,
                0
            )
        }
    }

    var revealContentOffset: CGPoint {
        var offset = contentOffset
        switch physicalEdge {
        case .top:
            offset.y = -adjustedBaselineInset.top - reservedExtent
        case .bottom:
            offset.y = max(
                contentSize.height
                    - bounds.height
                    + adjustedBaselineInset.bottom
                    + reservedExtent,
                -adjustedBaselineInset.top
            )
        case .left:
            offset.x = -adjustedBaselineInset.left - reservedExtent
        case .right:
            offset.x = max(
                contentSize.width
                    - bounds.width
                    + adjustedBaselineInset.right
                    + reservedExtent,
                -adjustedBaselineInset.left
            )
        }
        return offset
    }

    func rendererFrame(in hostBounds: CGRect) -> CGRect {
        switch physicalEdge {
        case .top:
            let inset = clampedCrossAxisInset(for: hostBounds.width)
            return CGRect(
                x: inset,
                y: clampedOuterSpacing(for: hostBounds.height),
                width: max(hostBounds.width - inset * 2, 0),
                height: displayExtent
            )
        case .bottom:
            let inset = clampedCrossAxisInset(for: hostBounds.width)
            let outerSpacing = clampedOuterSpacing(for: hostBounds.height)
            return CGRect(
                x: inset,
                y: max(hostBounds.height - outerSpacing - displayExtent, 0),
                width: max(hostBounds.width - inset * 2, 0),
                height: displayExtent
            )
        case .left:
            let inset = clampedCrossAxisInset(for: hostBounds.height)
            return CGRect(
                x: clampedOuterSpacing(for: hostBounds.width),
                y: inset,
                width: displayExtent,
                height: max(hostBounds.height - inset * 2, 0)
            )
        case .right:
            let inset = clampedCrossAxisInset(for: hostBounds.height)
            let outerSpacing = clampedOuterSpacing(for: hostBounds.width)
            return CGRect(
                x: max(hostBounds.width - outerSpacing - displayExtent, 0),
                y: inset,
                width: displayExtent,
                height: max(hostBounds.height - inset * 2, 0)
            )
        }
    }

    func hostFrame(
        presentation: RefreshablePresentation,
        overlayAnchor: RefreshableOverlayAnchor
    ) -> CGRect {
        switch presentation {
        case .contentInset:
            contentInsetHostFrame
        case .overlay(let spacing, _):
            switch overlayAnchor {
            case .viewport:
                viewportOverlayHostFrame(spacing: spacing)
            case .contentBoundary:
                contentBoundaryOverlayHostFrame(spacing: spacing)
            }
        }
    }

    private var contentInsetHostFrame: CGRect {
        switch physicalEdge {
        case .top:
            CGRect(x: bounds.minX, y: -reservedExtent, width: bounds.width, height: reservedExtent)
        case .bottom:
            CGRect(
                x: bounds.minX,
                y: contentSize.height,
                width: bounds.width,
                height: reservedExtent
            )
        case .left:
            CGRect(
                x: -baselineInset.left - reservedExtent,
                y: bounds.minY,
                width: horizontalViewportWidth,
                height: bounds.height
            )
        case .right:
            CGRect(
                x: contentSize.width
                    - bounds.width
                    + baselineInset.right
                    + automaticAdjustment.left
                    + automaticAdjustment.right
                    + reservedExtent,
                y: bounds.minY,
                width: horizontalViewportWidth,
                height: bounds.height
            )
        }
    }

    private func viewportOverlayHostFrame(spacing: CGFloat) -> CGRect {
        let visibleBounds = CGRect(origin: contentOffset, size: bounds.size)
        return switch physicalEdge {
        case .top:
            CGRect(
                x: visibleBounds.minX,
                y: visibleBounds.minY + safeAreaInsets.top + spacing,
                width: visibleBounds.width,
                height: reservedExtent
            )
        case .bottom:
            CGRect(
                x: visibleBounds.minX,
                y: visibleBounds.maxY - safeAreaInsets.bottom - spacing - reservedExtent,
                width: visibleBounds.width,
                height: reservedExtent
            )
        case .left:
            CGRect(
                x: visibleBounds.minX + safeAreaInsets.left + spacing,
                y: visibleBounds.minY,
                width: reservedExtent,
                height: visibleBounds.height
            )
        case .right:
            CGRect(
                x: visibleBounds.maxX - safeAreaInsets.right - spacing - reservedExtent,
                y: visibleBounds.minY,
                width: reservedExtent,
                height: visibleBounds.height
            )
        }
    }

    private func contentBoundaryOverlayHostFrame(spacing: CGFloat) -> CGRect {
        switch physicalEdge {
        case .top:
            CGRect(
                x: bounds.minX,
                y: -spacing - reservedExtent,
                width: bounds.width,
                height: reservedExtent
            )
        case .bottom:
            CGRect(
                x: bounds.minX,
                y: contentSize.height + spacing,
                width: bounds.width,
                height: reservedExtent
            )
        case .left:
            CGRect(
                x: -spacing - reservedExtent,
                y: bounds.minY,
                width: reservedExtent,
                height: bounds.height
            )
        case .right:
            CGRect(
                x: contentSize.width + spacing,
                y: bounds.minY,
                width: reservedExtent,
                height: bounds.height
            )
        }
    }

    private var horizontalViewportWidth: CGFloat {
        max(
            bounds.width - automaticAdjustment.left - automaticAdjustment.right,
            reservedExtent
        )
    }

    private func clampedOuterSpacing(for length: CGFloat) -> CGFloat {
        min(placement.outerSpacing, max(length - displayExtent, 0))
    }

    private func clampedCrossAxisInset(for length: CGFloat) -> CGFloat {
        min(placement.crossAxisInset, max(length, 0) / 2)
    }
}
