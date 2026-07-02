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
            backgroundTint: UIColor(red: 0.02, green: 0.05, blue: 0.11, alpha: 0.86),
            primaryGlow: UIColor(red: 0.14, green: 0.86, blue: 1.0, alpha: 1),
            secondaryGlow: UIColor(red: 0.50, green: 0.33, blue: 1.0, alpha: 1),
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

    private let glassBaseLayer = CAShapeLayer()
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

        let mistWidth = min(bounds.width * 0.62, 236)
        let mistHeight = min(bounds.height, 84)
        mistLayer.frame = CGRect(
            x: (bounds.width - mistWidth) / 2,
            y: (bounds.height - mistHeight) / 2 + 4,
            width: mistWidth,
            height: mistHeight
        )

        let diameter: CGFloat = 56
        taijiSymbolView.frame = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        updateGlassBasePath()
        updateArcPaths()
        updateParticlePositions(progress: 1)
        updateRipplePath()
    }

    func apply(palette: TaijiRefreshPalette, animated: Bool = false) {
        currentPalette = palette
        taijiSymbolView.palette = palette

        let updates = {
            self.glassBaseLayer.fillColor = palette.primaryGlow.withAlphaComponent(0.08).cgColor
            self.glassBaseLayer.strokeColor = palette.glassHighlight.withAlphaComponent(0.10).cgColor
            self.glassBaseLayer.shadowColor = palette.primaryGlow.withAlphaComponent(0.75).cgColor
            self.mistLayer.colors = [
                palette.primaryGlow.withAlphaComponent(0.28).cgColor,
                palette.secondaryGlow.withAlphaComponent(0.20).cgColor,
                palette.backgroundTint.withAlphaComponent(0.10).cgColor,
                UIColor.clear.cgColor,
            ]
            self.mistLayer.locations = [0, 0.42, 0.72, 1]
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
        let arcAlpha: Float
        let particleAlpha: Float
        let orbitRotation: CGFloat
        let coreRotation: CGFloat

        switch state {
        case .idle:
            baseAlpha = 0
            scale = 0.86
            mistAlpha = 0
            arcEnd = 0
            arcAlpha = 0
            particleAlpha = 0
            orbitRotation = 0
            coreRotation = 0
            stopContinuousMotion()

        case .pulling:
            baseAlpha = Float(0.15 + p * 0.85)
            scale = 0.86 + p * 0.14
            mistAlpha = Float(p * (reduceTransparency ? 0.32 : 0.56))
            arcEnd = 0.10 + p * 0.58
            arcAlpha = Float(0.18 + p * 0.56)
            particleAlpha = Float(p * 0.85)
            orbitRotation = reduceMotion ? 0 : p * 0.58
            coreRotation = 0
            stopContinuousMotion()

        case .triggered:
            baseAlpha = 1
            scale = 1.04
            mistAlpha = reduceTransparency ? 0.32 : 0.62
            arcEnd = 0.76
            arcAlpha = 0.76
            particleAlpha = 1
            orbitRotation = reduceMotion ? 0 : 0.32
            coreRotation = 0
            stopContinuousMotion()

        case .refreshing:
            baseAlpha = 1
            scale = 1
            mistAlpha = reduceTransparency ? 0.34 : 0.58
            arcEnd = 0.54
            arcAlpha = 0.68
            particleAlpha = 0.92
            orbitRotation = 0
            coreRotation = 0
            if reduceMotion {
                stopContinuousMotion()
                startBreathing()
            } else {
                startContinuousSpin()
            }

        case .ending:
            baseAlpha = 0.78
            scale = 0.92
            mistAlpha = 0.10
            arcEnd = 0.28
            arcAlpha = 0.24
            particleAlpha = 0.25
            orbitRotation = 0
            coreRotation = 0
            stopContinuousMotion()
            playRipple()

        case .noMoreData:
            baseAlpha = 0.55
            scale = 0.92
            mistAlpha = 0.08
            arcEnd = 0.24
            arcAlpha = 0.20
            particleAlpha = 0
            orbitRotation = 0
            coreRotation = 0
            stopContinuousMotion()
        }

        layer.opacity = baseAlpha
        glassBaseLayer.opacity = min(mistAlpha + 0.04, 0.36)
        mistLayer.opacity = mistAlpha
        backArcLayer.opacity = min(arcAlpha * 0.66, 0.50)
        frontArcLayer.opacity = min(arcAlpha, 0.74)
        backArcLayer.strokeEnd = arcEnd * 0.72
        frontArcLayer.strokeEnd = arcEnd
        particleLayers.enumerated().forEach { index, layer in
            layer.opacity = index < Int(ceil(CGFloat(particleLayers.count) * max(p, 0.25))) ? particleAlpha : 0
        }
        updateParticlePositions(progress: max(p, 0.2))
        applyOrbitRotation(orbitRotation)
        taijiSymbolView.setPatternRotation(coreRotation)
        taijiSymbolView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    private func setupLayers() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        glassBaseLayer.opacity = 0
        glassBaseLayer.lineWidth = 0.7
        glassBaseLayer.shadowOpacity = 0.20
        glassBaseLayer.shadowRadius = 18
        glassBaseLayer.shadowOffset = .zero
        layer.addSublayer(glassBaseLayer)

        mistLayer.type = .radial
        mistLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        mistLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(mistLayer)

        [backArcLayer, frontArcLayer, rippleLayer].forEach { arcLayer in
            arcLayer.fillColor = UIColor.clear.cgColor
            arcLayer.lineCap = .round
            arcLayer.lineJoin = .round
            arcLayer.lineWidth = 1.4
        }
        backArcLayer.name = "taijiBackOrbitLayer"
        frontArcLayer.name = "taijiFrontOrbitLayer"
        rippleLayer.name = "taijiRippleLayer"

        backArcLayer.lineWidth = 1.05
        frontArcLayer.lineWidth = 1.55
        rippleLayer.lineWidth = 1.35
        rippleLayer.opacity = 0

        layer.addSublayer(backArcLayer)
        addSubview(taijiSymbolView)
        layer.addSublayer(frontArcLayer)
        layer.addSublayer(rippleLayer)

        particleLayers.enumerated().forEach { index, particle in
            let size: CGFloat = index.isMultiple(of: 3) ? 2.4 : 1.7
            particle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).cgPath
            particle.opacity = 0
            layer.addSublayer(particle)
        }
    }

    private func updateGlassBasePath() {
        let rect = CGRect(
            x: bounds.midX - 68,
            y: bounds.midY + 8,
            width: 136,
            height: 22
        )
        glassBaseLayer.path = UIBezierPath(ovalIn: rect).cgPath
        glassBaseLayer.shadowPath = glassBaseLayer.path
    }

    private func updateArcPaths() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        [backArcLayer, frontArcLayer, rippleLayer].forEach { orbitLayer in
            orbitLayer.frame = bounds
        }

        let backPath = UIBezierPath()
        backPath.move(to: CGPoint(x: center.x - 40, y: center.y - 8))
        backPath.addCurve(
            to: CGPoint(x: center.x + 40, y: center.y - 6),
            controlPoint1: CGPoint(x: center.x - 23, y: center.y - 26),
            controlPoint2: CGPoint(x: center.x + 23, y: center.y - 24)
        )

        let frontPath = UIBezierPath()
        frontPath.move(to: CGPoint(x: center.x - 40, y: center.y - 1))
        frontPath.addCurve(
            to: CGPoint(x: center.x + 40, y: center.y),
            controlPoint1: CGPoint(x: center.x - 24, y: center.y + 22),
            controlPoint2: CGPoint(x: center.x + 24, y: center.y + 22)
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
            x: bounds.midX - 48,
            y: bounds.midY - 48,
            width: 96,
            height: 96
        )
        rippleLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    private func startContinuousSpin() {
        taijiSymbolView.layer.removeAnimation(forKey: "taijiBreath")
        taijiSymbolView.startPatternSpin()
        guard frontArcLayer.animation(forKey: "taijiOrbitSpin") == nil else { return }

        let frontSpin = CABasicAnimation(keyPath: "transform.rotation.z")
        frontSpin.fromValue = 0
        frontSpin.toValue = CGFloat.pi * 2
        frontSpin.duration = 1.05
        frontSpin.repeatCount = .infinity
        frontArcLayer.add(frontSpin, forKey: "taijiOrbitSpin")

        let backSpin = CABasicAnimation(keyPath: "transform.rotation.z")
        backSpin.fromValue = CGFloat.pi * 2
        backSpin.toValue = 0
        backSpin.duration = 1.32
        backSpin.repeatCount = .infinity
        backArcLayer.add(backSpin, forKey: "taijiOrbitSpin")
    }

    private func startBreathing() {
        frontArcLayer.removeAnimation(forKey: "taijiOrbitSpin")
        backArcLayer.removeAnimation(forKey: "taijiOrbitSpin")
        taijiSymbolView.stopPatternSpin()
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
        frontArcLayer.removeAnimation(forKey: "taijiOrbitSpin")
        backArcLayer.removeAnimation(forKey: "taijiOrbitSpin")
        taijiSymbolView.stopPatternSpin()
        taijiSymbolView.layer.removeAnimation(forKey: "taijiSpin")
        taijiSymbolView.layer.removeAnimation(forKey: "taijiBreath")
    }

    private func applyOrbitRotation(_ rotation: CGFloat) {
        frontArcLayer.transform = CATransform3DMakeRotation(rotation * 0.24, 0, 0, 1)
        backArcLayer.transform = CATransform3DMakeRotation(-rotation * 0.18, 0, 0, 1)
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

    private let coreView = TaijiCoreView()
    private let patternView = TaijiPatternView()
    private let edgeDepthLayer = CAShapeLayer()
    private let rimLayer = CAShapeLayer()
    private let glossLayer = CAShapeLayer()
    private let lowerGlowLayer = CAShapeLayer()

    var palette: TaijiRefreshPalette = .dark {
        didSet {
            coreView.palette = palette
            patternView.palette = palette
            updateShellLayerColors()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupShellLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupShellLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coreView.frame = bounds
        patternView.frame = bounds
        updateShellLayerPaths()
    }

    private func setupShellLayers() {
        backgroundColor = .clear
        isOpaque = false
        layer.shadowOpacity = 0.34
        layer.shadowRadius = 12
        layer.shadowOffset = .zero

        coreView.backgroundColor = .clear
        coreView.isOpaque = false
        coreView.isUserInteractionEnabled = false
        coreView.layer.name = "taijiCoreLayer"
        addSubview(coreView)

        patternView.backgroundColor = .clear
        patternView.isOpaque = false
        patternView.isUserInteractionEnabled = false
        patternView.layer.name = "taijiPatternLayer"
        addSubview(patternView)

        [edgeDepthLayer, lowerGlowLayer, rimLayer, glossLayer].forEach { shellLayer in
            shellLayer.contentsScale = UIScreen.main.scale
            shellLayer.allowsEdgeAntialiasing = true
            shellLayer.fillColor = UIColor.clear.cgColor
            shellLayer.strokeColor = UIColor.clear.cgColor
            layer.addSublayer(shellLayer)
        }
        updateShellLayerColors()
    }

    private func updateShellLayerColors() {
        layer.shadowColor = palette.primaryGlow.cgColor

        edgeDepthLayer.fillColor = UIColor.clear.cgColor
        edgeDepthLayer.strokeColor = palette.shadowCore.withAlphaComponent(0.48).cgColor
        edgeDepthLayer.lineWidth = 3.0
        edgeDepthLayer.opacity = 0.9

        rimLayer.fillColor = UIColor.clear.cgColor
        rimLayer.strokeColor = palette.glassHighlight.withAlphaComponent(0.64).cgColor
        rimLayer.lineWidth = 1.45
        rimLayer.opacity = 0.92

        glossLayer.fillColor = palette.glassHighlight.withAlphaComponent(0.18).cgColor
        glossLayer.strokeColor = palette.glassHighlight.withAlphaComponent(0.24).cgColor
        glossLayer.lineWidth = 0.8
        glossLayer.opacity = 0.95

        lowerGlowLayer.fillColor = palette.primaryGlow.withAlphaComponent(0.12).cgColor
        lowerGlowLayer.strokeColor = UIColor.clear.cgColor
        lowerGlowLayer.lineWidth = 0
        lowerGlowLayer.opacity = 0.8
    }

    private func updateShellLayerPaths() {
        let circleRect = bounds.insetBy(dx: 3, dy: 3)
        let radius = circleRect.width / 2
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)

        [edgeDepthLayer, lowerGlowLayer, rimLayer, glossLayer].forEach { shellLayer in
            shellLayer.frame = bounds
        }

        let circlePath = UIBezierPath(ovalIn: circleRect).cgPath
        edgeDepthLayer.path = circlePath
        rimLayer.path = circlePath

        let glossRect = CGRect(
            x: circleRect.minX + radius * 0.18,
            y: circleRect.minY + radius * 0.10,
            width: radius * 1.05,
            height: radius * 0.54
        )
        glossLayer.path = UIBezierPath(ovalIn: glossRect).cgPath

        let glowRect = CGRect(
            x: center.x - radius * 0.62,
            y: center.y + radius * 0.32,
            width: radius * 1.24,
            height: radius * 0.42
        )
        lowerGlowLayer.path = UIBezierPath(ovalIn: glowRect).cgPath
    }

    func setPatternRotation(_ angle: CGFloat) {
        patternView.transform = CGAffineTransform(rotationAngle: angle)
    }

    func startPatternSpin() {
        guard patternView.layer.animation(forKey: "taijiPatternSpin") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = patternView.layer.presentation()?.value(forKeyPath: "transform.rotation.z") ?? 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 1.18
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        patternView.layer.add(animation, forKey: "taijiPatternSpin")
    }

    func stopPatternSpin() {
        patternView.layer.removeAnimation(forKey: "taijiPatternSpin")
    }
}

@MainActor
private final class TaijiCoreView: UIView {

    var palette: TaijiRefreshPalette = .dark {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let circleRect = bounds.insetBy(dx: 3, dy: 3)
        let radius = circleRect.width / 2
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)

        context.saveGState()
        UIBezierPath(ovalIn: circleRect).addClip()

        palette.shadowCore.withAlphaComponent(0.82).setFill()
        UIBezierPath(ovalIn: circleRect).fill()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let sphereGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                palette.glassHighlight.withAlphaComponent(0.22).cgColor,
                palette.secondaryGlow.withAlphaComponent(0.68).cgColor,
                palette.shadowCore.withAlphaComponent(0.78).cgColor,
            ] as CFArray,
            locations: [0, 0.44, 1]
        ) {
            context.drawRadialGradient(
                sphereGradient,
                startCenter: CGPoint(x: circleRect.minX + radius * 0.36, y: circleRect.minY + radius * 0.24),
                startRadius: 1,
                endCenter: center,
                endRadius: radius * 1.12,
                options: [.drawsAfterEndLocation]
            )
        }

        if let glassGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                palette.glassHighlight.withAlphaComponent(0.34).cgColor,
                palette.primaryGlow.withAlphaComponent(0.12).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray,
            locations: [0, 0.48, 1]
        ) {
            context.drawLinearGradient(
                glassGradient,
                start: CGPoint(x: circleRect.minX + radius * 0.22, y: circleRect.minY + radius * 0.08),
                end: CGPoint(x: circleRect.maxX, y: circleRect.maxY),
                options: []
            )
        }

        if let edgeGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                UIColor.clear.cgColor,
                palette.shadowCore.withAlphaComponent(0.16).cgColor,
                palette.shadowCore.withAlphaComponent(0.56).cgColor,
            ] as CFArray,
            locations: [0, 0.66, 1]
        ) {
            context.drawRadialGradient(
                edgeGradient,
                startCenter: center,
                startRadius: radius * 0.22,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }

        context.restoreGState()
    }
}

@MainActor
private final class TaijiPatternView: UIView {

    var palette: TaijiRefreshPalette = .dark {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let circleRect = bounds.insetBy(dx: 3, dy: 3)
        let radius = circleRect.width / 2
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)

        context.saveGState()
        UIBezierPath(ovalIn: circleRect).addClip()

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
        palette.primaryGlow.withAlphaComponent(0.86).setFill()
        primaryPath.fill()

        palette.secondaryGlow.withAlphaComponent(0.88).setFill()
        UIBezierPath(
            ovalIn: CGRect(
                x: center.x - radius / 4,
                y: center.y - radius * 0.75,
                width: radius / 2,
                height: radius / 2
            )
        ).fill()

        palette.primaryGlow.withAlphaComponent(0.88).setFill()
        UIBezierPath(
            ovalIn: CGRect(
                x: center.x - radius / 4,
                y: center.y + radius * 0.25,
                width: radius / 2,
                height: radius / 2
            )
        ).fill()

        context.restoreGState()
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
