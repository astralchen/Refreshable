import UIKit

/// Theme selection for `TaijiRefreshStyle`.
public enum TaijiRefreshTheme: Sendable, Equatable {
    case system
    case light
    case dark
    case custom(TaijiRefreshPalette)
}

/// Color palette used by the compact glass taiji refresh style.
public struct TaijiRefreshPalette: Equatable, @unchecked Sendable {
    public var backgroundTint: UIColor
    public var primaryGlow: UIColor
    public var secondaryGlow: UIColor
    public var glassHighlight: UIColor
    public var shadowCore: UIColor
    public var particle: UIColor

    public init(
        backgroundTint: UIColor,
        primaryGlow: UIColor,
        secondaryGlow: UIColor,
        glassHighlight: UIColor,
        shadowCore: UIColor,
        particle: UIColor
    ) {
        self.backgroundTint = backgroundTint
        self.primaryGlow = primaryGlow
        self.secondaryGlow = secondaryGlow
        self.glassHighlight = glassHighlight
        self.shadowCore = shadowCore
        self.particle = particle
    }

    public static func == (lhs: TaijiRefreshPalette, rhs: TaijiRefreshPalette) -> Bool {
        lhs.backgroundTint.isEqual(rhs.backgroundTint)
            && lhs.primaryGlow.isEqual(rhs.primaryGlow)
            && lhs.secondaryGlow.isEqual(rhs.secondaryGlow)
            && lhs.glassHighlight.isEqual(rhs.glassHighlight)
            && lhs.shadowCore.isEqual(rhs.shadowCore)
            && lhs.particle.isEqual(rhs.particle)
    }

    public static var light: TaijiRefreshPalette {
        TaijiRefreshPalette(
            backgroundTint: UIColor(red: 0.89, green: 0.86, blue: 1.0, alpha: 0.22),
            primaryGlow: UIColor(red: 0.15, green: 0.76, blue: 0.95, alpha: 1),
            secondaryGlow: UIColor(red: 0.49, green: 0.35, blue: 0.95, alpha: 1),
            glassHighlight: UIColor.white.withAlphaComponent(0.9),
            shadowCore: UIColor(red: 0.13, green: 0.16, blue: 0.28, alpha: 1),
            particle: UIColor(red: 0.12, green: 0.62, blue: 0.95, alpha: 1)
        )
    }

    public static var dark: TaijiRefreshPalette {
        TaijiRefreshPalette(
            backgroundTint: UIColor(red: 0.28, green: 0.16, blue: 0.58, alpha: 0.5),
            primaryGlow: UIColor(red: 0.18, green: 0.88, blue: 1.0, alpha: 1),
            secondaryGlow: UIColor(red: 0.67, green: 0.36, blue: 1.0, alpha: 1),
            glassHighlight: UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 1),
            shadowCore: UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1),
            particle: UIColor(red: 0.74, green: 0.95, blue: 1.0, alpha: 1)
        )
    }
}

/// A compact premium glass taiji refresh style.
@MainActor
public final class TaijiRefreshStyle: RefreshableStyle {

    /// The root view installed into the scroll view.
    public let view: UIView

    /// Header height.
    public let extent: CGFloat

    /// Current theme selection.
    public private(set) var theme: TaijiRefreshTheme

    private let taijiView: TaijiRefreshView

    /// Creates a compact taiji refresh style.
    public init(
        extent: CGFloat = 92,
        theme: TaijiRefreshTheme = .system
    ) {
        self.extent = extent
        self.theme = theme
        self.taijiView = TaijiRefreshView(frame: CGRect(x: 0, y: 0, width: 160, height: extent))
        self.view = taijiView
        self.view.frame.size.height = extent
        self.view.isAccessibilityElement = true
        self.view.accessibilityLabel = "刷新"
        self.taijiView.apply(palette: Self.palette(for: theme, traitCollection: taijiView.traitCollection))
        update(state: .idle, progress: 0)
    }

    /// Switches the palette without resetting the current refresh state.
    public func setTheme(_ theme: TaijiRefreshTheme, animated: Bool = true) {
        self.theme = theme
        let palette = Self.palette(for: theme, traitCollection: taijiView.traitCollection)
        taijiView.apply(palette: palette, animated: animated)
    }

    /// Updates the taiji refresh control for the current state.
    public func update(state: RefreshState, progress: CGFloat) {
        let palette = Self.palette(for: theme, traitCollection: taijiView.traitCollection)
        taijiView.render(
            state: state,
            progress: state.normalizedProgress(fallback: progress),
            palette: palette,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
        view.accessibilityValue = Self.accessibilityValue(for: state)
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

    private static func palette(
        for theme: TaijiRefreshTheme,
        traitCollection: UITraitCollection
    ) -> TaijiRefreshPalette {
        switch theme {
        case .system:
            traitCollection.userInterfaceStyle == .dark ? .dark : .light
        case .light:
            .light
        case .dark:
            .dark
        case .custom(let palette):
            palette
        }
    }
}

@MainActor
private final class TaijiRefreshView: UIView {

    private let mistLayer = CAGradientLayer()
    private let backArcLayer = CAShapeLayer()
    private let frontArcLayer = CAShapeLayer()
    private let rippleLayer = CAShapeLayer()
    private let taijiSymbolView = TaijiSymbolView()
    private let particleLayers: [CAShapeLayer] = (0..<14).map { _ in CAShapeLayer() }
    private var currentPalette: TaijiRefreshPalette = .dark

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
        mistLayer.frame = bounds

        let diameter: CGFloat = 52
        taijiSymbolView.frame = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        updateArcPaths()
        updateParticlePositions(progress: 1)
        updateRipplePath()
    }

    func apply(palette: TaijiRefreshPalette, animated: Bool = false) {
        currentPalette = palette
        taijiSymbolView.palette = palette

        let updates = {
            self.mistLayer.colors = [
                palette.primaryGlow.withAlphaComponent(0.36).cgColor,
                palette.secondaryGlow.withAlphaComponent(0.18).cgColor,
                UIColor.clear.cgColor,
            ]
            self.backArcLayer.strokeColor = palette.secondaryGlow.withAlphaComponent(0.45).cgColor
            self.frontArcLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.8).cgColor
            self.rippleLayer.strokeColor = palette.glassHighlight.withAlphaComponent(0.42).cgColor
            self.particleLayers.forEach { $0.fillColor = palette.particle.cgColor }
        }

        if animated {
            UIView.transition(with: self, duration: 0.22, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                updates()
            }
        } else {
            updates()
        }
    }

    func render(
        state: RefreshState,
        progress: CGFloat,
        palette: TaijiRefreshPalette,
        reduceMotion: Bool,
        reduceTransparency: Bool
    ) {
        apply(palette: palette)
        let p = min(max(progress, 0), 1)
        let baseAlpha: Float
        let scale: CGFloat
        let mistAlpha: Float
        let arcEnd: CGFloat
        let particleAlpha: Float
        let rotation: CGFloat

        switch state {
        case .idle:
            baseAlpha = 0
            scale = 0.86
            mistAlpha = 0
            arcEnd = 0
            particleAlpha = 0
            rotation = 0
            stopContinuousMotion()

        case .pulling:
            baseAlpha = Float(0.15 + p * 0.85)
            scale = 0.86 + p * 0.14
            mistAlpha = Float(p * (reduceTransparency ? 0.25 : 0.55))
            arcEnd = 0.08 + p * 0.72
            particleAlpha = Float(p * 0.85)
            rotation = reduceMotion ? 0 : p * 2.45
            stopContinuousMotion()

        case .triggered:
            baseAlpha = 1
            scale = 1.04
            mistAlpha = reduceTransparency ? 0.3 : 0.62
            arcEnd = 0.88
            particleAlpha = 1
            rotation = reduceMotion ? 0 : 0.32
            stopContinuousMotion()

        case .refreshing:
            baseAlpha = 1
            scale = 1
            mistAlpha = reduceTransparency ? 0.32 : 0.58
            arcEnd = 0.62
            particleAlpha = 0.92
            rotation = 0
            if reduceMotion {
                stopContinuousMotion()
                startBreathing()
            } else {
                startContinuousSpin()
            }

        case .ending:
            baseAlpha = 0.78
            scale = 0.92
            mistAlpha = 0.18
            arcEnd = 1
            particleAlpha = 0.25
            rotation = 0
            stopContinuousMotion()
            playRipple()

        case .noMoreData:
            baseAlpha = 0.55
            scale = 0.92
            mistAlpha = 0.08
            arcEnd = 0.24
            particleAlpha = 0
            rotation = 0
            stopContinuousMotion()
        }

        layer.opacity = baseAlpha
        mistLayer.opacity = mistAlpha
        backArcLayer.opacity = min(mistAlpha + 0.08, 0.7)
        frontArcLayer.opacity = min(baseAlpha, 1)
        backArcLayer.strokeEnd = arcEnd * 0.72
        frontArcLayer.strokeEnd = arcEnd
        particleLayers.enumerated().forEach { index, layer in
            layer.opacity = index < Int(ceil(CGFloat(particleLayers.count) * max(p, 0.25))) ? particleAlpha : 0
        }
        updateParticlePositions(progress: max(p, 0.2))
        taijiSymbolView.transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: scale, y: scale)
        taijiSymbolView.setNeedsDisplay()
    }

    private func setupLayers() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        mistLayer.type = .radial
        mistLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        mistLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(mistLayer)

        [backArcLayer, frontArcLayer, rippleLayer].forEach { arcLayer in
            arcLayer.fillColor = UIColor.clear.cgColor
            arcLayer.lineCap = .round
            arcLayer.lineWidth = 2
            layer.addSublayer(arcLayer)
        }
        backArcLayer.lineWidth = 1.5
        backArcLayer.transform = CATransform3DMakeRotation(.pi / 3.5, 1, 0, 0)
        frontArcLayer.transform = CATransform3DMakeRotation(.pi / 4.1, 1, 0, 0)
        rippleLayer.opacity = 0

        addSubview(taijiSymbolView)

        particleLayers.enumerated().forEach { index, particle in
            let size: CGFloat = index.isMultiple(of: 3) ? 2.4 : 1.7
            particle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).cgPath
            particle.opacity = 0
            layer.addSublayer(particle)
        }
    }

    private func updateArcPaths() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let frontPath = UIBezierPath(
            arcCenter: center,
            radius: 38,
            startAngle: -.pi * 0.78,
            endAngle: .pi * 1.22,
            clockwise: true
        )
        let backPath = UIBezierPath(
            arcCenter: center,
            radius: 32,
            startAngle: .pi * 0.16,
            endAngle: .pi * 1.72,
            clockwise: true
        )
        frontArcLayer.path = frontPath.cgPath
        backArcLayer.path = backPath.cgPath
    }

    private func updateParticlePositions(progress: CGFloat) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = 31 + (1 - progress) * 8
        for (index, particle) in particleLayers.enumerated() {
            let phase = CGFloat(index) / CGFloat(particleLayers.count)
            let angle = phase * .pi * 2 + progress * 0.6
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius * 0.56
            particle.frame.origin = CGPoint(x: x, y: y)
        }
    }

    private func updateRipplePath() {
        let rect = CGRect(
            x: bounds.midX - 46,
            y: bounds.midY - 46,
            width: 92,
            height: 92
        )
        rippleLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    private func startContinuousSpin() {
        taijiSymbolView.layer.removeAnimation(forKey: "taijiBreath")
        guard taijiSymbolView.layer.animation(forKey: "taijiSpin") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 1.05
        animation.repeatCount = .infinity
        taijiSymbolView.layer.add(animation, forKey: "taijiSpin")
    }

    private func startBreathing() {
        taijiSymbolView.layer.removeAnimation(forKey: "taijiSpin")
        guard taijiSymbolView.layer.animation(forKey: "taijiBreath") == nil else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.72
        animation.toValue = 1
        animation.duration = 0.9
        animation.autoreverses = true
        animation.repeatCount = .infinity
        taijiSymbolView.layer.add(animation, forKey: "taijiBreath")
    }

    private func stopContinuousMotion() {
        taijiSymbolView.layer.removeAnimation(forKey: "taijiSpin")
        taijiSymbolView.layer.removeAnimation(forKey: "taijiBreath")
    }

    private func playRipple() {
        rippleLayer.opacity = 1
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.45
        scale.toValue = 1
        scale.duration = 0.28

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.45
        fade.toValue = 0
        fade.duration = 0.28

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.28
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rippleLayer.add(group, forKey: "taijiRipple")
        rippleLayer.opacity = 0
    }
}

@MainActor
private final class TaijiSymbolView: UIView {

    var palette: TaijiRefreshPalette = .dark {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        layer.shadowOpacity = 0.34
        layer.shadowRadius = 14
        layer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let circleRect = bounds.insetBy(dx: 3, dy: 3)
        let radius = circleRect.width / 2
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
        layer.shadowColor = palette.primaryGlow.cgColor

        context.saveGState()
        UIBezierPath(ovalIn: circleRect).addClip()

        palette.shadowCore.setFill()
        UIBezierPath(ovalIn: circleRect).fill()

        palette.secondaryGlow.withAlphaComponent(0.88).setFill()
        UIBezierPath(ovalIn: circleRect).fill()

        let primaryPath = UIBezierPath()
        primaryPath.move(to: CGPoint(x: center.x, y: circleRect.minY))
        primaryPath.addArc(
            withCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: true
        )
        primaryPath.addArc(
            withCenter: CGPoint(x: center.x, y: center.y + radius / 2),
            radius: radius / 2,
            startAngle: .pi / 2,
            endAngle: -.pi / 2,
            clockwise: false
        )
        primaryPath.addArc(
            withCenter: CGPoint(x: center.x, y: center.y - radius / 2),
            radius: radius / 2,
            startAngle: .pi / 2,
            endAngle: -.pi / 2,
            clockwise: true
        )
        primaryPath.close()
        palette.primaryGlow.withAlphaComponent(0.92).setFill()
        primaryPath.fill()

        palette.secondaryGlow.withAlphaComponent(0.92).setFill()
        UIBezierPath(
            ovalIn: CGRect(
                x: center.x - radius / 4,
                y: center.y - radius * 0.75,
                width: radius / 2,
                height: radius / 2
            )
        ).fill()

        palette.primaryGlow.withAlphaComponent(0.92).setFill()
        UIBezierPath(
            ovalIn: CGRect(
                x: center.x - radius / 4,
                y: center.y + radius * 0.25,
                width: radius / 2,
                height: radius / 2
            )
        ).fill()

        context.restoreGState()

        palette.glassHighlight.withAlphaComponent(0.78).setStroke()
        let rim = UIBezierPath(ovalIn: circleRect.insetBy(dx: 0.5, dy: 0.5))
        rim.lineWidth = 1.4
        rim.stroke()

        palette.glassHighlight.withAlphaComponent(0.45).setStroke()
        let highlight = UIBezierPath(
            arcCenter: center,
            radius: radius - 5,
            startAngle: -.pi * 0.82,
            endAngle: -.pi * 0.18,
            clockwise: true
        )
        highlight.lineWidth = 2
        highlight.lineCapStyle = .round
        highlight.stroke()
    }
}

private extension RefreshState {
    func normalizedProgress(fallback: CGFloat) -> CGFloat {
        switch self {
        case .pulling(let progress):
            min(max(progress, 0), 1)
        case .triggered, .refreshing, .ending:
            1
        case .idle, .noMoreData:
            min(max(fallback, 0), 1)
        }
    }
}
