import UIKit

/// 一种包含箭头、进度环、活动指示器和状态文案的紧凑系统风格刷新样式。
@MainActor
public final class SystemNativeRefreshStyle: RefreshableStyle {
    /// 刷新视图沿滚动轴占用的尺寸。
    public let extent: CGFloat
    private let texts: TopRefreshTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let lastUpdatedText: String

    /// 创建系统风格刷新样式。
    ///
    /// - Parameters:
    ///   - extent: 刷新视图沿滚动轴占用的尺寸。
    ///   - texts: 顶部下拉刷新使用的可见文案和 VoiceOver 文案。
    ///   - configuration: 字体、颜色和无障碍行为配置。
    ///   - lastUpdatedText: 刷新中和结束状态显示的最近更新时间文案。
    public init(
        extent: CGFloat = 64,
        texts: TopRefreshTexts = TopRefreshTexts(),
        configuration: RefreshLabelStyleConfiguration = RefreshLabelStyleConfiguration(
            font: .systemFont(ofSize: 15, weight: .semibold),
            textColor: .label
        ),
        lastUpdatedText: String = "上次更新：刚刚"
    ) {
        self.extent = extent
        self.texts = texts
        self.configuration = configuration
        self.lastUpdatedText = lastUpdatedText
    }

    public func makeRenderer() -> any RefreshableStyleRenderer {
        SystemNativeRefreshRenderer(
            extent: extent,
            texts: texts,
            configuration: configuration,
            lastUpdatedText: lastUpdatedText
        )
    }
}

@MainActor
private final class SystemNativeRefreshRenderer: RefreshableStyleRenderer {
    let view = UIView()

    private let extent: CGFloat
    private let texts: TopRefreshTexts
    private let configuration: RefreshLabelStyleConfiguration
    private let lastUpdatedText: String
    private let hintContainer = UIView()
    private let hintArrowView = UIImageView()
    private let iconContainer = UIView()
    private let spinnerView = SegmentedRefreshSpinnerView()
    private let arrowView = UIImageView()
    private let textStack = UIStackView()
    private let label = UILabel()
    private let subtitleLabel = UILabel()

    init(
        extent: CGFloat,
        texts: TopRefreshTexts,
        configuration: RefreshLabelStyleConfiguration,
        lastUpdatedText: String
    ) {
        self.extent = extent
        self.texts = texts
        self.configuration = configuration
        self.lastUpdatedText = lastUpdatedText
        setupUI()
        render(RefreshableStyleContext(state: .idle, pullProgress: 0))
    }

    /// 根据当前状态更新系统风格刷新控件。
    ///
    /// - Parameters:
    ///   - state: 当前刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    func render(_ context: RefreshableStyleContext) {
        label.textColor = currentTextColor()
        subtitleLabel.textColor = currentSecondaryTextColor()
        spinnerView.tintColor = currentAccentColor()

        switch context.state {
        case .idle:
            label.text = texts.idle
            updateAccessibilityValue(texts.idleAccessibilityValue)
            spinnerView.setProgress(0, animated: false)
            spinnerView.stopSpinning()
            arrowView.isHidden = false
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            updatePullHint(progress: 0, isVisible: false)

        case .pulling(let p):
            let pullProgress = normalizedProgress(max(p, context.pullProgress))
            label.text = texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            spinnerView.setProgress(pullProgress, animated: false)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            updatePullHint(progress: pullProgress, isVisible: true)

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            spinnerView.setProgress(context.pullProgress > 0 ? context.pullProgress : 1, animated: true)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            updatePullHint(progress: 1, isVisible: true)

        case .active:
            label.text = texts.active
            updateAccessibilityValue(texts.activeAccessibilityValue)
            arrowView.isHidden = true
            spinnerView.setProgress(1, animated: true)
            if honorsReduceMotion {
                spinnerView.stopSpinning()
            } else {
                spinnerView.startSpinning()
            }
            subtitleLabel.text = lastUpdatedText
            subtitleLabel.isHidden = false
            updatePullHint(progress: 1, isVisible: false)

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(1, animated: true)
            arrowView.isHidden = true
            subtitleLabel.text = lastUpdatedText
            subtitleLabel.isHidden = false
            updatePullHint(progress: 1, isVisible: false)

        case .noMoreData:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(0, animated: true)
            arrowView.isHidden = true
            subtitleLabel.isHidden = true
            updatePullHint(progress: 0, isVisible: false)
        }
    }

    private func setupUI() {
        view.frame.size.height = extent
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel

        hintContainer.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.isHidden = true
        hintContainer.accessibilityIdentifier = "Refreshable.SystemNative.PullHint"
        view.addSubview(hintContainer)

        let hintImageConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        hintArrowView.image = UIImage(systemName: "arrow.down", withConfiguration: hintImageConfiguration)
        hintArrowView.tintColor = .secondaryLabel
        hintArrowView.contentMode = .center
        hintArrowView.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintArrowView)

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.accessibilityIdentifier = "Refreshable.SystemNative.Icon"
        view.addSubview(iconContainer)

        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(spinnerView)

        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        arrowView.image = UIImage(systemName: "arrow.down", withConfiguration: imageConfiguration)
        arrowView.tintColor = currentTextColor()
        arrowView.contentMode = .center
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(arrowView)

        label.font = UIFontMetrics(forTextStyle: configuration.fontTextStyle)
            .scaledFont(for: configuration.font)
        label.adjustsFontForContentSizeCategory = configuration.adjustsFontForContentSizeCategory
        label.textColor = currentTextColor()
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        subtitleLabel.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .systemFont(ofSize: 12, weight: .regular))
        subtitleLabel.adjustsFontForContentSizeCategory = configuration.adjustsFontForContentSizeCategory
        subtitleLabel.textColor = currentSecondaryTextColor()
        subtitleLabel.text = lastUpdatedText
        subtitleLabel.isHidden = true
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(label)
        textStack.addArrangedSubview(subtitleLabel)
        view.addSubview(textStack)

        NSLayoutConstraint.activate([
            hintContainer.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            hintContainer.bottomAnchor.constraint(equalTo: iconContainer.topAnchor, constant: -4),
            hintContainer.widthAnchor.constraint(equalToConstant: 20),
            hintContainer.heightAnchor.constraint(equalToConstant: 20),

            hintArrowView.centerXAnchor.constraint(equalTo: hintContainer.centerXAnchor),
            hintArrowView.centerYAnchor.constraint(equalTo: hintContainer.centerYAnchor),
            hintArrowView.widthAnchor.constraint(equalTo: hintContainer.widthAnchor),
            hintArrowView.heightAnchor.constraint(equalTo: hintContainer.heightAnchor),

            iconContainer.trailingAnchor.constraint(equalTo: textStack.leadingAnchor, constant: -10),
            iconContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 8),
            iconContainer.widthAnchor.constraint(equalToConstant: 24),
            iconContainer.heightAnchor.constraint(equalToConstant: 24),

            spinnerView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            spinnerView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            spinnerView.widthAnchor.constraint(equalToConstant: 24),
            spinnerView.heightAnchor.constraint(equalToConstant: 24),

            arrowView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            arrowView.widthAnchor.constraint(equalTo: iconContainer.widthAnchor),
            arrowView.heightAnchor.constraint(equalTo: iconContainer.heightAnchor),

            textStack.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 28),
            textStack.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
    }

    private var honorsReduceMotion: Bool {
        configuration.honorsReduceMotion && UIAccessibility.isReduceMotionEnabled
    }

    private func updatePullHint(progress: CGFloat, isVisible: Bool) {
        let progress = normalizedProgress(progress)
        let easedProgress = smoothStep(progress)

        hintContainer.isHidden = !isVisible

        guard !honorsReduceMotion else {
            hintContainer.transform = .identity
            hintArrowView.transform = progress >= 1
                ? CGAffineTransform(rotationAngle: .pi)
                : .identity
            return
        }

        // 箭头从 spinner 上方向下靠近，拉动越接近阈值，两者的位置关系越紧密。
        hintContainer.transform = CGAffineTransform(
            translationX: 0,
            y: -3 + easedProgress * 6
        )

        // 保持方向稳定到阈值附近，再快速翻转为“松手刷新”，避免全程侧向旋转。
        let flipProgress = smoothStep(normalizedProgress((progress - 0.82) / 0.18))
        hintArrowView.transform = CGAffineTransform(rotationAngle: flipProgress * .pi)
    }

    private func normalizedProgress(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }

    private func smoothStep(_ progress: CGFloat) -> CGFloat {
        progress * progress * (3 - 2 * progress)
    }

    private func currentTextColor() -> UIColor {
        if configuration.honorsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled {
            return configuration.reducedTransparencyTextColor
        }
        return configuration.textColor
    }

    private func currentSecondaryTextColor() -> UIColor {
        if configuration.honorsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled {
            return configuration.reducedTransparencyTextColor
        }
        return .secondaryLabel
    }

    private func currentAccentColor() -> UIColor {
        if configuration.honorsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled {
            return .label
        }
        return .systemBlue
    }

    private func updateAccessibilityValue(_ value: String) {
        view.accessibilityValue = value
    }
}
