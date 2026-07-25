import UIKit

@MainActor
final class SegmentedRefreshSpinnerView: UIView {

    private let segmentLayers: [CAShapeLayer] = (0..<12).map { _ in CAShapeLayer() }

    private(set) var currentProgress: CGFloat = 0

    var isSpinAnimationActive: Bool {
        layer.animation(forKey: Self.spinAnimationKey) != nil
    }

    private static let spinAnimationKey = "systemNativeSpin"

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

    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateSegmentColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSegmentColors()
    }

    func setProgress(_ progress: CGFloat, animated: Bool) {
        currentProgress = min(max(progress, 0), 2)
        if animated {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
            animation.toValue = currentProgress > 0 ? 1 : 0
            animation.duration = 0.18
            layer.add(animation, forKey: "opacity")
        }
        layer.opacity = currentProgress > 0 ? 1 : 0
        updateSegmentLayout()
        updateSegmentColors()
    }

    func startSpinning() {
        guard !isSpinAnimationActive else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.85
        animation.repeatCount = .infinity
        layer.add(animation, forKey: Self.spinAnimationKey)
        updateSegmentColors()
    }

    func stopSpinning() {
        layer.removeAnimation(forKey: Self.spinAnimationKey)
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

        let pullProgress = min(max(currentProgress, 0), 1)
        let continuedPullProgress = min(max(currentProgress - 1, 0), 1)
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
        let pullProgress = min(max(currentProgress, 0), 1)
        let continuedPullProgress = min(max(currentProgress - 1, 0), 1)
        let revealLead = pullProgress * CGFloat(segmentLayers.count)
        let baseColor = tintColor ?? .systemBlue

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
            let alpha = isSpinAnimationActive ? refreshingAlpha : pullingAlpha
            segment.fillColor = baseColor.withAlphaComponent(alpha).cgColor
        }
    }
}
