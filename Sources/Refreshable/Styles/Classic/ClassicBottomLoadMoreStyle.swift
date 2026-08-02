import UIKit

/// 经典的底部上拉加载更多样式。
///
/// 此样式使用文本标签和活动指示器展示加载更多状态。
@MainActor
public final class ClassicBottomLoadMoreStyle: RefreshableStyle {
    /// 经典底部加载更多样式的轴向尺寸。
    public let extent: CGFloat = 54
    private let texts: BottomLoadMoreTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let accessibilityEnvironment: RefreshStyleAccessibilityEnvironment

    /// 创建经典的底部上拉加载更多样式。
    ///
    /// - Parameters:
    ///   - texts: 底部上拉加载更多样式使用的可见文案和 VoiceOver 文案。
    ///   - configuration: 字体、颜色和无障碍行为配置。
    public init(
        texts: BottomLoadMoreTexts = BottomLoadMoreTexts(),
        configuration: RefreshLabelStyleConfiguration = RefreshLabelStyleConfiguration()
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = .current
    }

    init(
        texts: BottomLoadMoreTexts = BottomLoadMoreTexts(),
        configuration: RefreshLabelStyleConfiguration = RefreshLabelStyleConfiguration(),
        accessibilityEnvironment: RefreshStyleAccessibilityEnvironment
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = accessibilityEnvironment
    }

    public func makeRenderer() -> any RefreshableStyleRenderer {
        ClassicBottomLoadMoreRenderer(
            extent: extent,
            texts: texts,
            configuration: configuration,
            accessibilityEnvironment: accessibilityEnvironment
        )
    }
}

@MainActor
private final class ClassicBottomLoadMoreRenderer: RefreshableStyleRenderer {
    let view = UIView()

    private let extent: CGFloat
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let texts: BottomLoadMoreTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let accessibilityEnvironment: RefreshStyleAccessibilityEnvironment

    init(
        extent: CGFloat,
        texts: BottomLoadMoreTexts,
        configuration: RefreshLabelStyleConfiguration,
        accessibilityEnvironment: RefreshStyleAccessibilityEnvironment
    ) {
        self.extent = extent
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

    /// 根据上拉加载状态更新经典界面。
    ///
    /// - Parameters:
    ///   - state: 当前上拉加载状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    func render(_ context: RefreshableStyleContext) {
        label.textColor = currentTextColor()

        switch context.state {
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

        case .active:
            label.text = texts.active
            updateAccessibilityValue(texts.activeAccessibilityValue)
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
