import UIKit

/// Compact cosmic glass Taiji refresh style.
@MainActor
public final class TaijiRefreshStyle: RefreshableStyle {
    public let view: UIView
    public let extent: CGFloat
    public private(set) var theme: TaijiRefreshTheme

    private let taijiView: TaijiRefreshView
    private var currentState: RefreshState = .idle
    private var currentProgress: CGFloat = 0

    public init(
        extent: CGFloat = 92,
        theme: TaijiRefreshTheme = .system,
        accessibilityLabel: String = "刷新"
    ) {
        self.extent = extent
        self.theme = theme

        let taijiView = TaijiRefreshView(frame: CGRect(x: 0, y: 0, width: 0, height: extent))
        taijiView.isAccessibilityElement = true
        taijiView.accessibilityLabel = accessibilityLabel
        taijiView.accessibilityTraits = [.updatesFrequently]
        self.taijiView = taijiView
        self.view = taijiView

        taijiView.onTraitCollectionChange = { [weak self] _ in
            guard let self else { return }
            self.applyCurrentState(animated: true)
        }
    }

    public func setTheme(_ theme: TaijiRefreshTheme, animated: Bool = true) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyCurrentState(animated: animated)
    }

    public func update(state: RefreshState, progress: CGFloat) {
        currentState = state
        currentProgress = progress
        view.accessibilityValue = Self.accessibilityValue(for: state)
        applyCurrentState(animated: false)
    }

    private func applyCurrentState(animated: Bool) {
        let renderState = TaijiRefreshRenderState.make(
            state: currentState,
            progress: currentProgress,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
        let palette = theme.resolvedPalette(for: view.traitCollection)
        taijiView.apply(
            renderState: renderState,
            palette: palette,
            animated: animated,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
    }

    private static func accessibilityValue(for state: RefreshState) -> String {
        switch state {
        case .idle:
            "未刷新"
        case .pulling:
            "下拉中"
        case .triggered:
            "释放刷新"
        case .refreshing:
            "正在刷新"
        case .ending:
            "刷新完成"
        case .noMoreData:
            "没有更多数据"
        }
    }
}
