import UIKit

/// 经典的顶部下拉刷新样式。
///
/// 此样式使用系统符号、文本标签和活动指示器展示下拉刷新状态。
@MainActor
public final class ClassicTopRefreshStyle: RefreshableStyle {
    /// 经典顶部刷新样式的轴向尺寸。
    public let extent: CGFloat = 54
    private let texts: TopRefreshTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let accessibilityEnvironment: RefreshStyleAccessibilityEnvironment

    /// 创建经典的顶部下拉刷新样式。
    ///
    /// - Parameters:
    ///   - texts: 顶部下拉刷新样式使用的可见文案和 VoiceOver 文案。
    ///   - configuration: 字体、颜色和无障碍行为配置。
    public init(
        texts: TopRefreshTexts = TopRefreshTexts(),
        configuration: RefreshLabelStyleConfiguration = RefreshLabelStyleConfiguration()
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = .current
    }

    init(
        texts: TopRefreshTexts = TopRefreshTexts(),
        configuration: RefreshLabelStyleConfiguration = RefreshLabelStyleConfiguration(),
        accessibilityEnvironment: RefreshStyleAccessibilityEnvironment
    ) {
        self.texts = texts
        self.configuration = configuration
        self.accessibilityEnvironment = accessibilityEnvironment
    }

    public func makeRenderer() -> any RefreshableStyleRenderer {
        ClassicTopRefreshRenderer(
            extent: extent,
            texts: texts,
            configuration: configuration,
            accessibilityEnvironment: accessibilityEnvironment
        )
    }
}

@MainActor
private final class ClassicTopRefreshRenderer: RefreshableStyleRenderer {
    let view = UIView()

    private let extent: CGFloat
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let arrowView = UIImageView()
    private let texts: TopRefreshTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let accessibilityEnvironment: RefreshStyleAccessibilityEnvironment

    init(
        extent: CGFloat,
        texts: TopRefreshTexts,
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

        // 下拉方向提示箭头。
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        arrowView.image = UIImage(systemName: "arrow.down", withConfiguration: config)
        arrowView.tintColor = .secondaryLabel
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrowView)

        // 刷新执行中的系统活动指示器。
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        // 状态文案标签。
        label.font = UIFontMetrics(forTextStyle: configuration.fontTextStyle)
            .scaledFont(for: configuration.font)
        label.adjustsFontForContentSizeCategory = configuration.adjustsFontForContentSizeCategory
        label.textColor = currentTextColor()
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            arrowView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            arrowView.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 根据下拉刷新状态更新经典界面。
    ///
    /// - Parameters:
    ///   - state: 当前下拉刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    func render(_ context: RefreshableStyleContext) {
        label.textColor = currentTextColor()

        switch context.state {
        case .idle:
            label.text = texts.idle
            updateAccessibilityValue(texts.idleAccessibilityValue)
            indicator.stopAnimating()
            arrowView.isHidden = false
            arrowView.transform = .identity

        case .pulling(let p):
            label.text = texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            indicator.stopAnimating()
            arrowView.isHidden = false
            if honorsReduceMotion {
                arrowView.transform = .identity
            } else {
                let angle = min(p, 1.0) * .pi
                arrowView.transform = CGAffineTransform(rotationAngle: angle)
            }

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            indicator.stopAnimating()
            arrowView.isHidden = false
            arrowView.transform = CGAffineTransform(rotationAngle: .pi)

        case .active:
            label.text = texts.active
            updateAccessibilityValue(texts.activeAccessibilityValue)
            indicator.startAnimating()
            arrowView.isHidden = true

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            indicator.stopAnimating()
            arrowView.isHidden = true

        case .noMoreData:
            break
        }
    }

    private var honorsReduceMotion: Bool {
        configuration.honorsReduceMotion && accessibilityEnvironment.isReduceMotionEnabled
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
