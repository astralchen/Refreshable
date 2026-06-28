import UIKit
import QuartzCore

final class TaijiRefreshView: UIView {
    var onTraitCollectionChange: ((UITraitCollection) -> Void)?
    private(set) var lastRenderState: TaijiRefreshRenderState?
    private(set) var lastPalette: TaijiRefreshPalette?
    private(set) var isContinuousAnimationActive = false

    private let mistLayer = CAGradientLayer()
    private let orbitContainerLayer = CALayer()
    private let backArcLayer = CAShapeLayer()
    private let frontArcLayer = CAShapeLayer()
    private let bodyContainerLayer = CALayer()
    private let glowLayer = CAGradientLayer()
    private let bodyLayer = TaijiBodyLayer()
    private let highlightLayer = CAShapeLayer()
    private let rippleLayer = CAShapeLayer()
    private let particleLayers: [CALayer] = (0..<18).map { _ in CALayer() }

    var debugLayerNames: [String] {
        [mistLayer, backArcLayer, frontArcLayer, bodyLayer, rippleLayer].compactMap(\.name)
    }

    var debugParticleCount: Int {
        particleLayers.count
    }

    var debugBodyFrame: CGRect {
        bodyContainerLayer.frame
    }

    var debugAnimationKeys: [String] {
        [
            bodyContainerLayer.animationKeys() ?? [],
            glowLayer.animationKeys() ?? [],
            rippleLayer.animationKeys() ?? [],
            backArcLayer.animationKeys() ?? [],
            frontArcLayer.animationKeys() ?? [],
            mistLayer.animationKeys() ?? [],
        ].flatMap { $0 }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        onTraitCollectionChange?(traitCollection)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let diameter = min(56, max(44, bounds.height * 0.58))
        let bodyFrame = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        ).integral
        let mistInset = -diameter * 0.92
        let mistFrame = bodyFrame.insetBy(dx: mistInset, dy: mistInset * 0.62)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        mistLayer.frame = mistFrame
        orbitContainerLayer.frame = bounds
        bodyContainerLayer.frame = bodyFrame
        glowLayer.frame = bodyContainerLayer.bounds.insetBy(dx: -diameter * 0.32, dy: -diameter * 0.32)
        glowLayer.position = CGPoint(x: bodyContainerLayer.bounds.midX, y: bodyContainerLayer.bounds.midY)
        bodyLayer.frame = bodyContainerLayer.bounds
        highlightLayer.frame = bodyContainerLayer.bounds
        rippleLayer.frame = bounds

        updateArcPaths(in: bodyFrame)
        updateHighlightPath()
        updateRipplePath(progress: lastRenderState?.rippleProgress ?? 0)
        updateParticleFrames()

        CATransaction.commit()
    }

    func apply(
        renderState: TaijiRefreshRenderState,
        palette: TaijiRefreshPalette,
        animated: Bool,
        reduceTransparency: Bool
    ) {
        let previousPalette = lastPalette
        lastRenderState = renderState
        lastPalette = palette
        bodyLayer.palette = palette
        bodyLayer.glassOpacity = renderState.glassOpacity
        bodyLayer.setNeedsDisplay()

        let updates = {
            self.mistLayer.opacity = Float(renderState.mistAlpha)
            self.backArcLayer.opacity = Float(renderState.arcAlpha * 0.42)
            self.frontArcLayer.opacity = Float(renderState.arcAlpha)
            self.bodyContainerLayer.opacity = Float(renderState.bodyAlpha)
            self.bodyContainerLayer.transform = self.bodyTransform(for: renderState)
            self.glowLayer.opacity = Float(renderState.glowIntensity)
            self.rippleLayer.opacity = Float(1 - renderState.rippleProgress)
            self.updateArcStroke(renderState: renderState, palette: palette)
            self.updateRipplePath(progress: renderState.rippleProgress)
            self.updateParticles(renderState: renderState, palette: palette)
        }

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.22)
        } else {
            CATransaction.setDisableActions(true)
        }
        updates()
        CATransaction.commit()

        if animated, let previousPalette, previousPalette != palette {
            animatePaletteChange(from: previousPalette, to: palette)
        }
        updateRefreshingAnimations(for: renderState)
    }

    private func configureLayers() {
        mistLayer.name = "mist"
        mistLayer.type = .radial
        mistLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        mistLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        mistLayer.locations = [0, 0.38, 1]

        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 460
        orbitContainerLayer.sublayerTransform = perspective

        backArcLayer.name = "backArc"
        backArcLayer.fillColor = UIColor.clear.cgColor
        backArcLayer.lineCap = .round
        backArcLayer.lineWidth = 1.2

        frontArcLayer.name = "frontArc"
        frontArcLayer.fillColor = UIColor.clear.cgColor
        frontArcLayer.lineCap = .round
        frontArcLayer.lineWidth = 1.4

        bodyLayer.name = "body"
        bodyLayer.contentsScale = UIScreen.main.scale
        bodyLayer.needsDisplayOnBoundsChange = true

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.locations = [0, 0.48, 1]

        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.strokeColor = UIColor.white.withAlphaComponent(0.72).cgColor
        highlightLayer.lineWidth = 1

        rippleLayer.name = "ripple"
        rippleLayer.fillColor = UIColor.clear.cgColor
        rippleLayer.lineWidth = 1

        layer.addSublayer(mistLayer)
        layer.addSublayer(orbitContainerLayer)
        orbitContainerLayer.addSublayer(backArcLayer)
        orbitContainerLayer.addSublayer(frontArcLayer)
        layer.addSublayer(bodyContainerLayer)
        bodyContainerLayer.addSublayer(glowLayer)
        bodyContainerLayer.addSublayer(bodyLayer)
        bodyContainerLayer.addSublayer(highlightLayer)
        layer.addSublayer(rippleLayer)

        for (index, particle) in particleLayers.enumerated() {
            particle.name = "particle-\(index)"
            particle.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
            particle.cornerRadius = 1
            particle.opacity = 0
            layer.addSublayer(particle)
        }
    }

    private func bodyTransform(for state: TaijiRefreshRenderState) -> CATransform3D {
        var transform = CATransform3DMakeScale(state.bodyScale, state.bodyScale, 1)
        if !state.preservesCurrentRotation {
            transform = CATransform3DRotate(transform, state.rotation, 0, 0, 1)
        }
        return transform
    }

    private func updateArcPaths(in bodyFrame: CGRect) {
        let radius = bodyFrame.width * 0.74
        let center = CGPoint(x: bodyFrame.midX, y: bodyFrame.midY)
        let backRect = CGRect(
            x: center.x - radius,
            y: center.y - radius * 0.46,
            width: radius * 2,
            height: radius * 0.92
        )
        let frontRect = CGRect(
            x: center.x - radius * 0.86,
            y: center.y - radius * 0.40,
            width: radius * 1.72,
            height: radius * 0.80
        )

        backArcLayer.path = UIBezierPath(ovalIn: backRect).cgPath
        frontArcLayer.path = UIBezierPath(ovalIn: frontRect).cgPath
        backArcLayer.transform = CATransform3DMakeRotation(.pi * 0.34, 1, 0, 0)
        frontArcLayer.transform = CATransform3DMakeRotation(.pi * -0.20, 1, 0, 0)
    }

    private func updateArcStroke(renderState: TaijiRefreshRenderState, palette: TaijiRefreshPalette) {
        backArcLayer.strokeColor = palette.secondaryGlow.withAlphaComponent(0.58).cgColor
        frontArcLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.86).cgColor
        backArcLayer.strokeStart = 0.08
        backArcLayer.strokeEnd = min(0.08 + renderState.arcSweep / (2 * .pi), 0.86)
        frontArcLayer.strokeStart = 0.52
        frontArcLayer.strokeEnd = min(0.52 + renderState.arcSweep / (2 * .pi) * 0.72, 0.98)

        mistLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.30).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.22).cgColor,
            palette.backgroundTint.withAlphaComponent(0.0).cgColor,
        ]
        glowLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.46).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor,
        ]
        rippleLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.38).cgColor
    }

    private func updateHighlightPath() {
        let rect = bodyLayer.bounds.insetBy(
            dx: bodyLayer.bounds.width * 0.18,
            dy: bodyLayer.bounds.height * 0.14
        )
        highlightLayer.path = UIBezierPath(
            arcCenter: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width * 0.42,
            startAngle: .pi * 1.06,
            endAngle: .pi * 1.74,
            clockwise: true
        ).cgPath
    }

    private func updateRipplePath(progress: CGFloat) {
        let diameter = bodyContainerLayer.bounds.width
        let radius = diameter * (0.52 + progress * 0.90)
        let rect = CGRect(
            x: bodyContainerLayer.frame.midX - radius,
            y: bodyContainerLayer.frame.midY - radius,
            width: radius * 2,
            height: radius * 2
        )
        rippleLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    private func updateParticleFrames() {
        for particle in particleLayers {
            particle.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
            particle.cornerRadius = 1
        }
        if let state = lastRenderState, let palette = lastPalette {
            updateParticles(renderState: state, palette: palette)
        }
    }

    private func updateParticles(renderState: TaijiRefreshRenderState, palette: TaijiRefreshPalette) {
        let center = CGPoint(x: bodyContainerLayer.frame.midX, y: bodyContainerLayer.frame.midY)
        let baseRadius = max(bodyContainerLayer.bounds.width * 0.62, 1)
        let visibleCount = min(renderState.particleCount, particleLayers.count)

        for (index, particle) in particleLayers.enumerated() {
            let isVisible = index < visibleCount
            let phase = CGFloat(index) / CGFloat(max(particleLayers.count, 1)) * 2 * .pi
            let radius = baseRadius + CGFloat(index % 5) * 2.1
            particle.position = CGPoint(
                x: center.x + cos(phase + renderState.rotation * 0.28) * radius,
                y: center.y + sin(phase + renderState.rotation * 0.28) * radius * 0.52
            )
            particle.backgroundColor = palette.particle.cgColor
            particle.opacity = isVisible ? Float(renderState.particleIntensity) : 0
        }
    }

    private func updateRefreshingAnimations(for state: TaijiRefreshRenderState) {
        if state.continuousRotationSpeed > 0 {
            isContinuousAnimationActive = true
            if bodyContainerLayer.animation(forKey: "taiji.rotation") == nil {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.fromValue = 0
                animation.toValue = 2 * CGFloat.pi
                animation.duration = 1 / TimeInterval(state.continuousRotationSpeed)
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .linear)
                bodyContainerLayer.add(animation, forKey: "taiji.rotation")
            }
        } else {
            isContinuousAnimationActive = false
            if let presentation = bodyContainerLayer.presentation() {
                bodyContainerLayer.transform = presentation.transform
            }
            bodyContainerLayer.removeAnimation(forKey: "taiji.rotation")
        }

        if state.usesGlowPulse {
            if glowLayer.animation(forKey: "taiji.glowPulse") == nil {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = max(0.35, state.glowIntensity * 0.62)
                animation.toValue = min(1.0, state.glowIntensity)
                animation.duration = 1.08
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                glowLayer.add(animation, forKey: "taiji.glowPulse")
            }
        } else {
            glowLayer.removeAnimation(forKey: "taiji.glowPulse")
        }

        if state.rippleProgress > 0 {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.72
            animation.toValue = 0
            animation.duration = 0.26
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            rippleLayer.add(animation, forKey: "taiji.ripple")
        } else {
            rippleLayer.removeAnimation(forKey: "taiji.ripple")
        }
    }

    private func animatePaletteChange(from previousPalette: TaijiRefreshPalette, to palette: TaijiRefreshPalette) {
        addColorAnimation(
            to: frontArcLayer,
            keyPath: "strokeColor",
            from: previousPalette.primaryGlow.withAlphaComponent(0.86).cgColor,
            to: palette.primaryGlow.withAlphaComponent(0.86).cgColor
        )
        addColorAnimation(
            to: backArcLayer,
            keyPath: "strokeColor",
            from: previousPalette.secondaryGlow.withAlphaComponent(0.58).cgColor,
            to: palette.secondaryGlow.withAlphaComponent(0.58).cgColor
        )
        addColorAnimation(
            to: rippleLayer,
            keyPath: "strokeColor",
            from: previousPalette.primaryGlow.withAlphaComponent(0.38).cgColor,
            to: palette.primaryGlow.withAlphaComponent(0.38).cgColor
        )
    }

    private func addColorAnimation(
        to layer: CALayer,
        keyPath: String,
        from previousColor: CGColor,
        to color: CGColor
    ) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = previousColor
        animation.toValue = color
        animation.duration = 0.22
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "taiji.palette.\(keyPath)")
    }
}

private final class TaijiBodyLayer: CALayer {
    var palette: TaijiRefreshPalette = .dark
    var glassOpacity: CGFloat = 0.62

    override func draw(in context: CGContext) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        guard rect.width > 1, rect.height > 1 else { return }

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 2),
            blur: 8,
            color: palette.primaryGlow.withAlphaComponent(0.35).cgColor
        )

        let circlePath = UIBezierPath(ovalIn: rect)
        context.addPath(circlePath.cgPath)
        context.clip()

        context.setFillColor(palette.glassHighlight.withAlphaComponent(glassOpacity).cgColor)
        context.fill(rect)

        let lowerPath = UIBezierPath()
        lowerPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
        lowerPath.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.25),
            radius: rect.width * 0.25,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: true
        )
        lowerPath.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.25),
            radius: rect.width * 0.25,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: false
        )
        lowerPath.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width * 0.5,
            startAngle: .pi / 2,
            endAngle: -.pi / 2,
            clockwise: false
        )
        lowerPath.close()

        context.addPath(lowerPath.cgPath)
        context.setFillColor(palette.shadowCore.withAlphaComponent(0.88).cgColor)
        context.fillPath()

        let topCore = CGRect(
            x: rect.midX - rect.width * 0.10,
            y: rect.minY + rect.height * 0.24,
            width: rect.width * 0.20,
            height: rect.height * 0.20
        )
        let bottomCore = CGRect(
            x: rect.midX - rect.width * 0.10,
            y: rect.maxY - rect.height * 0.44,
            width: rect.width * 0.20,
            height: rect.height * 0.20
        )
        context.setFillColor(palette.shadowCore.withAlphaComponent(0.88).cgColor)
        context.fillEllipse(in: topCore)
        context.setFillColor(palette.glassHighlight.withAlphaComponent(0.82).cgColor)
        context.fillEllipse(in: bottomCore)

        context.restoreGState()

        context.setStrokeColor(palette.glassHighlight.withAlphaComponent(0.86).cgColor)
        context.setLineWidth(1.2)
        context.strokeEllipse(in: rect)
    }
}
