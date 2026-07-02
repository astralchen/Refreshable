import UIKit

/// A compact native-feeling refresh style with an arrow, progress ring, spinner, and status text.
@MainActor
public final class SystemNativeRefreshStyle: RefreshableStyle {

    /// The root view installed into the scroll view.
    public let view: UIView = UIView()

    /// The default header height.
    public let extent: CGFloat

    private let texts: DefaultTopRefreshTexts
    private let configuration: DefaultRefreshStyleConfiguration
    private let lastUpdatedText: String
    private let hintContainer = UIView()
    private let hintArrowView = UIImageView()
    private let hintDotView = UIView()
    private let iconContainer = UIView()
    private let spinnerView = SystemNativeSpinnerView()
    private let arrowView = UIImageView()
    private let textStack = UIStackView()
    private let label = UILabel()
    private let subtitleLabel = UILabel()

    /// Creates a native-style refresh control.
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

    /// Updates the native refresh control for the current state.
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

        case .pulling(let p):
            label.text = texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            spinnerView.setProgress(min(max(p, progress), 1), animated: false)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            hintContainer.alpha = min(max(p, 0), 1) * 0.72

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            spinnerView.setProgress(progress > 0 ? progress : 1, animated: true)
            spinnerView.stopSpinning()
            arrowView.isHidden = true
            arrowView.transform = .identity
            subtitleLabel.isHidden = true
            hintContainer.alpha = 0.82

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

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(1, animated: true)
            arrowView.isHidden = true
            subtitleLabel.text = lastUpdatedText
            subtitleLabel.isHidden = false
            hintContainer.alpha = 0.35

        case .noMoreData:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            spinnerView.stopSpinning()
            spinnerView.setProgress(0, animated: true)
            arrowView.isHidden = true
            subtitleLabel.isHidden = true
            hintContainer.alpha = 0
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
        hintArrowView.image = UIImage(systemName: "arrow.up", withConfiguration: hintImageConfiguration)
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

@MainActor
private final class SystemNativeSpinnerView: UIView {

    override var tintColor: UIColor! {
        didSet {
            updateSegmentColors()
        }
    }

    private let segmentLayers: [CAShapeLayer] = (0..<12).map { _ in CAShapeLayer() }
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSegmentLayout()
    }

    func setProgress(_ progress: CGFloat, animated: Bool) {
        self.progress = min(max(progress, 0), 2)
        if animated {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
            animation.toValue = self.progress > 0 ? 1 : 0
            animation.duration = 0.18
            layer.add(animation, forKey: "opacity")
        }
        layer.opacity = self.progress > 0 ? 1 : 0
        updateSegmentLayout()
        updateSegmentColors()
    }

    func startSpinning() {
        guard layer.animation(forKey: "systemNativeSpin") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.85
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "systemNativeSpin")
        updateSegmentColors()
    }

    func stopSpinning() {
        layer.removeAnimation(forKey: "systemNativeSpin")
        updateSegmentColors()
    }

    private func setupLayers() {
        isUserInteractionEnabled = false

        for segment in segmentLayers {
            segment.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.addSublayer(segment)
        }

        layer.opacity = 0
        updateSegmentColors()
    }

    private func updateSegmentLayout() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return }

        let pullProgress = min(max(progress, 0), 1)
        let continuedPullProgress = min(max(progress - 1, 0), 1)
        let radius = max(side * (0.12 + 0.26 * pullProgress + 0.08 * continuedPullProgress), 1)
        let baseWidth = 0.85 + pullProgress * 1.75 + continuedPullProgress * 0.45
        let baseHeight = 1.2 + pullProgress * 6.8 + continuedPullProgress * 2
        let revealLead = pullProgress * CGFloat(segmentLayers.count)

        for (index, segment) in segmentLayers.enumerated() {
            let angle = CGFloat(index) / CGFloat(segmentLayers.count) * .pi * 2
            let reveal = min(max(revealLead - CGFloat(index), 0), 1)
            let segmentScale = 0.55 + reveal * 0.45
            let segmentSize = CGSize(width: baseWidth * segmentScale, height: baseHeight * segmentScale)

            segment.bounds = CGRect(origin: .zero, size: segmentSize)
            segment.path = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: segmentSize),
                cornerRadius: segmentSize.width / 2
            ).cgPath
            segment.position = CGPoint(
                x: center.x + cos(angle - .pi / 2) * radius,
                y: center.y + sin(angle - .pi / 2) * radius
            )
            segment.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        }
    }

    private func updateSegmentColors() {
        let pullProgress = min(max(progress, 0), 1)
        let continuedPullProgress = min(max(progress - 1, 0), 1)
        let revealLead = pullProgress * CGFloat(segmentLayers.count)
        let baseColor = tintColor ?? .systemBlue
        let isRefreshing = layer.animation(forKey: "systemNativeSpin") != nil

        for (index, segment) in segmentLayers.enumerated() {
            let distanceFromLead = CGFloat((segmentLayers.count - index) % segmentLayers.count)
            let trailingStrength = distanceFromLead / CGFloat(segmentLayers.count - 1)
            let refreshingAlpha = 0.18 + trailingStrength * 0.82
            let reveal = min(max(revealLead - CGFloat(index), 0), 1)
            let pullingAlpha = reveal > 0
                ? min(
                    0.1
                    + reveal * 0.42
                    + pullProgress * 0.16
                    + continuedPullProgress * 0.08
                    + trailingStrength * 0.24,
                    1
                )
                : 0
            let alpha = isRefreshing ? refreshingAlpha : pullingAlpha
            segment.fillColor = baseColor.withAlphaComponent(alpha).cgColor
        }
    }
}
