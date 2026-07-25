import UIKit

/// 一种包含箭头、进度环、活动指示器和状态文案的紧凑系统风格刷新样式。
@MainActor
public final class SystemNativeRefreshStyle: RefreshableStyle {

    /// 安装到滚动视图中的根视图。
    public let view: UIView = UIView()

    /// 刷新视图沿滚动轴占用的尺寸。
    public let extent: CGFloat

    private let texts: DefaultTopRefreshTexts
    private let configuration: DefaultRefreshStyleConfiguration
    private let lastUpdatedText: String
    private let hintContainer = UIView()
    private let hintArrowView = UIImageView()
    private let hintDotView = UIView()
    private let iconContainer = UIView()
    private let spinnerView = SegmentedRefreshSpinnerView()
    private let arrowView = UIImageView()
    private let textStack = UIStackView()
    private let label = UILabel()
    private let subtitleLabel = UILabel()

    /// 创建系统风格刷新样式。
    ///
    /// - Parameters:
    ///   - extent: 刷新视图沿滚动轴占用的尺寸。
    ///   - texts: 顶部下拉刷新使用的可见文案和 VoiceOver 文案。
    ///   - configuration: 字体、颜色和无障碍行为配置。
    ///   - lastUpdatedText: 刷新中和结束状态显示的最近更新时间文案。
    public init(
        extent: CGFloat = 64,
        texts: DefaultTopRefreshTexts = DefaultTopRefreshTexts(),
        configuration: DefaultRefreshStyleConfiguration = DefaultRefreshStyleConfiguration(
            font: .systemFont(ofSize: 15, weight: .semibold),
            textColor: .label
        ),
        lastUpdatedText: String = "上次更新：刚刚"
    ) {
        self.extent = extent
        self.texts = texts
        self.configuration = configuration
        self.lastUpdatedText = lastUpdatedText
        setupUI()
        update(state: .idle, progress: 0)
    }

    /// 根据当前状态更新系统风格刷新控件。
    ///
    /// - Parameters:
    ///   - state: 当前刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    public func update(state: RefreshState, progress: CGFloat) {
        label.textColor = currentTextColor()
        subtitleLabel.textColor = currentSecondaryTextColor()
        spinnerView.tintColor = currentAccentColor()

        switch state {
        case .idle:
            label.text = texts.idle
            updateAccessibilityValue(texts.idleAccessibilityValue)
            spinnerView.setProgress(0, animated: false)
            spinnerView.stopSpinning()
            arrowView.isHidden = false
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            hintContainer.alpha = 0
            hintArrowView.transform = .identity

        case .pulling(let p):
            label.text = texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            spinnerView.setProgress(min(max(p, progress), 1), animated: false)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            hintContainer.alpha = min(max(p, 0), 1) * 0.72
            hintArrowView.transform = hintArrowTransform(progress: p)

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            spinnerView.setProgress(progress > 0 ? progress : 1, animated: true)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            hintContainer.alpha = 0.82
            hintArrowView.transform = hintArrowTransform(progress: 1)

        case .refreshing:
            label.text = texts.refreshing
            updateAccessibilityValue(texts.refreshingAccessibilityValue)
            arrowView.isHidden = true
            spinnerView.setProgress(1, animated: true)
            if honorsReduceMotion {
                spinnerView.stopSpinning()
            } else {
                spinnerView.startSpinning()
            }
            subtitleLabel.text = lastUpdatedText
            subtitleLabel.isHidden = false
            hintContainer.alpha = 0.62
            hintArrowView.transform = hintArrowTransform(progress: 1)

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(1, animated: true)
            arrowView.isHidden = true
            subtitleLabel.text = lastUpdatedText
            subtitleLabel.isHidden = false
            hintContainer.alpha = 0.35
            hintArrowView.transform = hintArrowTransform(progress: 1)

        case .noMoreData:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(0, animated: true)
            arrowView.isHidden = true
            subtitleLabel.isHidden = true
            hintContainer.alpha = 0
            hintArrowView.transform = .identity
        }
    }

    private func setupUI() {
        view.frame.size.height = extent
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel

        hintContainer.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.alpha = 0
        view.addSubview(hintContainer)

        let hintImageConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        hintArrowView.image = UIImage(systemName: "arrow.down", withConfiguration: hintImageConfiguration)
        hintArrowView.tintColor = .tertiaryLabel
        hintArrowView.contentMode = .center
        hintArrowView.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintArrowView)

        hintDotView.backgroundColor = .tertiaryLabel
        hintDotView.layer.cornerRadius = 1.5
        hintDotView.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintDotView)

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
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
            hintContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 3),
            hintContainer.widthAnchor.constraint(equalToConstant: 24),
            hintContainer.heightAnchor.constraint(equalToConstant: 20),

            hintArrowView.centerXAnchor.constraint(equalTo: hintContainer.centerXAnchor),
            hintArrowView.topAnchor.constraint(equalTo: hintContainer.topAnchor),
            hintArrowView.widthAnchor.constraint(equalTo: hintContainer.widthAnchor),
            hintArrowView.heightAnchor.constraint(equalToConstant: 14),

            hintDotView.centerXAnchor.constraint(equalTo: hintContainer.centerXAnchor),
            hintDotView.topAnchor.constraint(equalTo: hintArrowView.bottomAnchor, constant: 1),
            hintDotView.widthAnchor.constraint(equalToConstant: 3),
            hintDotView.heightAnchor.constraint(equalToConstant: 3),

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

    private func hintArrowTransform(progress: CGFloat) -> CGAffineTransform {
        guard !honorsReduceMotion else { return .identity }
        return CGAffineTransform(rotationAngle: min(max(progress, 0), 1) * .pi)
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
