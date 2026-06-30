import UIKit

/// A compact native-feeling refresh style with an arrow, progress ring, spinner, and status text.
@MainActor
public final class SystemNativeRefreshStyle: RefreshableStyle {

    /// The root view installed into the scroll view.
    public let view: UIView = UIView()

    /// The default header height.
    public let extent: CGFloat

    private let texts: DefaultHeaderRefreshTexts
    private let configuration: DefaultRefreshStyleConfiguration
    private let iconContainer = UIView()
    private let progressView = SystemNativeProgressView()
    private let arrowView = UIImageView()
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    /// Creates a native-style refresh control.
    public init(
        extent: CGFloat = 64,
        texts: DefaultHeaderRefreshTexts = DefaultHeaderRefreshTexts(pulling: "继续下拉"),
        configuration: DefaultRefreshStyleConfiguration = DefaultRefreshStyleConfiguration()
    ) {
        self.extent = extent
        self.texts = texts
        self.configuration = configuration
        setupUI()
        update(state: .idle, progress: 0)
    }

    /// Updates the native refresh control for the current state.
    public func update(state: RefreshState, progress: CGFloat) {
        label.textColor = currentTextColor()
        progressView.tintColor = currentAccentColor()

        switch state {
        case .idle:
            label.text = texts.idle
            updateAccessibilityValue(texts.idleAccessibilityValue)
            indicator.stopAnimating()
            progressView.setProgress(0, animated: false)
            progressView.stopSpinning()
            arrowView.isHidden = false
            arrowView.transform = .identity

        case .pulling(let p):
            label.text = p >= 1 ? texts.triggered : texts.pulling
            updateAccessibilityValue(texts.pullingAccessibilityValue)
            indicator.stopAnimating()
            progressView.setProgress(min(max(p, progress), 1), animated: false)
            progressView.stopSpinning()
            arrowView.isHidden = false
            arrowView.transform = honorsReduceMotion ? .identity : CGAffineTransform(rotationAngle: min(p, 1) * .pi)

        case .triggered:
            label.text = texts.triggered
            updateAccessibilityValue(texts.triggeredAccessibilityValue)
            indicator.stopAnimating()
            progressView.setProgress(1, animated: true)
            progressView.stopSpinning()
            arrowView.isHidden = false
            arrowView.transform = honorsReduceMotion ? .identity : CGAffineTransform(rotationAngle: .pi)

        case .refreshing:
            label.text = texts.refreshing
            updateAccessibilityValue(texts.refreshingAccessibilityValue)
            arrowView.isHidden = true
            indicator.startAnimating()
            progressView.setProgress(0.82, animated: true)
            if honorsReduceMotion {
                progressView.stopSpinning()
            } else {
                progressView.startSpinning()
            }

        case .ending:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            indicator.stopAnimating()
            progressView.stopSpinning()
            progressView.setProgress(1, animated: true)
            arrowView.isHidden = true

        case .noMoreData:
            label.text = texts.ending
            updateAccessibilityValue(texts.endingAccessibilityValue)
            indicator.stopAnimating()
            progressView.stopSpinning()
            arrowView.isHidden = true
        }
    }

    private func setupUI() {
        view.frame.size.height = extent
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconContainer)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(progressView)

        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        arrowView.image = UIImage(systemName: "arrow.down", withConfiguration: imageConfiguration)
        arrowView.tintColor = currentTextColor()
        arrowView.contentMode = .center
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(arrowView)

        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(indicator)

        label.font = UIFontMetrics(forTextStyle: configuration.fontTextStyle)
            .scaledFont(for: configuration.font)
        label.adjustsFontForContentSizeCategory = configuration.adjustsFontForContentSizeCategory
        label.textColor = currentTextColor()
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            iconContainer.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -10),
            iconContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 24),
            iconContainer.heightAnchor.constraint(equalToConstant: 24),

            progressView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 22),
            progressView.heightAnchor.constraint(equalToConstant: 22),

            arrowView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            arrowView.widthAnchor.constraint(equalTo: iconContainer.widthAnchor),
            arrowView.heightAnchor.constraint(equalTo: iconContainer.heightAnchor),

            indicator.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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
private final class SystemNativeProgressView: UIView {

    override var tintColor: UIColor! {
        didSet {
            trackLayer.strokeColor = UIColor.separator.cgColor
            progressLayer.strokeColor = tintColor.cgColor
        }
    }

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

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
        let diameter = min(bounds.width, bounds.height) - 2
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        let path = UIBezierPath(
            arcCenter: CGPoint(x: rect.midX, y: rect.midY),
            radius: diameter / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ progress: CGFloat, animated: Bool) {
        let clamped = min(max(progress, 0), 1)
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
            animation.toValue = clamped
            animation.duration = 0.18
            progressLayer.add(animation, forKey: "strokeEnd")
        }
        progressLayer.strokeEnd = clamped
    }

    func startSpinning() {
        guard layer.animation(forKey: "systemNativeSpin") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.85
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "systemNativeSpin")
    }

    func stopSpinning() {
        layer.removeAnimation(forKey: "systemNativeSpin")
    }

    private func setupLayers() {
        isUserInteractionEnabled = false

        [trackLayer, progressLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            layer.lineWidth = 2
            self.layer.addSublayer(layer)
        }

        trackLayer.strokeColor = UIColor.separator.cgColor
        trackLayer.opacity = 0.7
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.strokeEnd = 0
    }
}
