import UIKit

/// 默认的底部上拉加载更多样式。
///
/// 此样式使用文本标签和活动指示器展示加载更多状态。
@MainActor
public final class DefaultBottomLoadMoreStyle: RefreshableStyle {

    /// 显示上拉加载内容的容器视图。
    public let view: UIView = UIView()

    /// 默认底部加载更多轴向尺寸。
    public let extent: CGFloat = 54

    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let texts: DefaultBottomLoadMoreTexts
    private let configuration: DefaultRefreshStyleConfiguration
    private let accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment

    /// 创建默认的底部上拉加载更多样式。
    ///
    /// - Parameters:
    ///   - texts: 底部上拉加载更多样式使用的可见文案和 VoiceOver 文案。
    ///   - configuration: 字体、颜色和无障碍行为配置。
    public init(
        texts: DefaultBottomLoadMoreTexts = DefaultBottomLoadMoreTexts(),
        configuration: DefaultRefreshStyleConfiguration = DefaultRefreshStyleConfiguration()
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = .current
        setupUI()
    }

    init(
        texts: DefaultBottomLoadMoreTexts = DefaultBottomLoadMoreTexts(),
        configuration: DefaultRefreshStyleConfiguration = DefaultRefreshStyleConfiguration(),
        accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = accessibilityEnvironment
        setupUI()
    }

    private func setupUI() {
        view.frame.size.height = extent
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel

        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        label.font = UIFontMetrics(forTextStyle: configuration.fontTextStyle)
            .scaledFont(for: configuration.font)
        label.adjustsFontForContentSizeCategory = configuration.adjustsFontForContentSizeCategory
        label.textColor = currentTextColor()
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 根据上拉加载状态更新默认界面。
    ///
    /// - Parameters:
    ///   - state: 当前上拉加载状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    public func update(state: RefreshState, progress: CGFloat) {
        label.textColor = currentTextColor()

        switch state {
        case .idle:
            label.text = texts.idle
            updateAccessibilityValue(texts.idleAccessibilityValue)
            indicator.stopAnimating()

        case .pulling:
            label.text = texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            indicator.stopAnimating()

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            indicator.stopAnimating()

        case .refreshing:
            label.text = texts.refreshing
            updateAccessibilityValue(texts.refreshingAccessibilityValue)
            indicator.startAnimating()

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            indicator.stopAnimating()

        case .noMoreData:
            label.text = texts.noMoreData
            updateAccessibilityValue(texts.noMoreDataAccessibilityValue)
            indicator.stopAnimating()
        }
    }

    private func currentTextColor() -> UIColor {
        if configuration.honorsReduceTransparency && accessibilityEnvironment.isReduceTransparencyEnabled {
            return configuration.reducedTransparencyTextColor
        }
        return configuration.textColor
    }

    private func updateAccessibilityValue(_ value: String) {
        view.accessibilityValue = value
    }
}
