import UIKit
import QuartzCore
import CoreImage

final class TaijiRefreshView: UIView {
    var onTraitCollectionChange: ((UITraitCollection) -> Void)?
    private(set) var lastRenderState: TaijiRefreshRenderState?
    private(set) var lastPalette: TaijiRefreshPalette?
    private(set) var isContinuousAnimationActive = false

    private let mistLayer = CAGradientLayer()
    private let mistMaskLayer = CAShapeLayer()
    private let orbitContainerLayer = CALayer()
    private let backArcLayer = CAShapeLayer()
    private let frontArcLayer = CAShapeLayer()
    private let bodyContainerLayer = CALayer()
    private let glowLayer = CAGradientLayer()
    private let bodyLayer = TaijiBodyLayer()
    private let refractionLayer = TaijiRefractionLayer()
    private let highlightLayer = CAShapeLayer()
    private let rippleLayer = CAShapeLayer()
    private let particleEmitterLayer = CAEmitterLayer()

    var debugLayerNames: [String] {
        [
            mistLayer,
            backArcLayer,
            frontArcLayer,
            bodyLayer,
            refractionLayer,
            particleEmitterLayer,
            rippleLayer,
        ].compactMap(\.name)
    }

    var debugParticleCount: Int {
        particleEmitterLayer.emitterCells?.count ?? 0
    }

    var debugBodyFrame: CGRect {
        bodyContainerLayer.frame
    }

    var debugBodyBounds: CGRect {
        bodyContainerLayer.bounds
    }

    var debugOrbitFrame: CGRect {
        let frames = [backArcLayer.path?.boundingBox, frontArcLayer.path?.boundingBox].compactMap { $0 }
        return frames.reduce(CGRect.null) { $0.union($1) }
    }

    var debugRippleFrame: CGRect {
        rippleLayer.path?.boundingBox ?? .zero
    }

    var debugAnimationKeys: [String] {
        var keys: [String] = []
        keys.append(contentsOf: orbitContainerLayer.animationKeys() ?? [])
        keys.append(contentsOf: bodyContainerLayer.animationKeys() ?? [])
        keys.append(contentsOf: glowLayer.animationKeys() ?? [])
        keys.append(contentsOf: rippleLayer.animationKeys() ?? [])
        keys.append(contentsOf: backArcLayer.animationKeys() ?? [])
        keys.append(contentsOf: frontArcLayer.animationKeys() ?? [])
        keys.append(contentsOf: mistLayer.animationKeys() ?? [])
        keys.append(contentsOf: particleEmitterLayer.animationKeys() ?? [])
        return keys
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

        let diameter = min(52, max(42, bounds.height * 0.54))
        let bodyCenterY = bounds.midY + bodyVerticalOffset(diameter: diameter)
        let bodyFrame = CGRect(
            x: bounds.midX - diameter / 2,
            y: bodyCenterY - diameter / 2,
            width: diameter,
            height: diameter
        ).integral
        let mistFrame = bodyFrame.insetBy(dx: -diameter * 0.36, dy: -diameter * 0.22)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        mistLayer.frame = mistFrame
        mistMaskLayer.frame = mistLayer.bounds
        mistMaskLayer.path = UIBezierPath(ovalIn: mistLayer.bounds).cgPath
        orbitContainerLayer.frame = bounds
        bodyContainerLayer.frame = bodyFrame
        glowLayer.frame = bodyContainerLayer.bounds.insetBy(dx: -diameter * 0.32, dy: -diameter * 0.32)
        glowLayer.position = CGPoint(x: bodyContainerLayer.bounds.midX, y: bodyContainerLayer.bounds.midY)
        bodyLayer.frame = bodyContainerLayer.bounds
        refractionLayer.frame = bodyContainerLayer.bounds
        highlightLayer.frame = bodyContainerLayer.bounds
        rippleLayer.frame = bounds

        updateArcPaths(in: bodyFrame)
        updateHighlightPath()
        updateRipplePath(progress: lastRenderState?.rippleProgress ?? 0)
        updateParticleEmitterFrame()

        CATransaction.commit()
    }

    func apply(
        renderState: TaijiRefreshRenderState,
        palette: TaijiRefreshPalette,
        animated: Bool,
        reduceTransparency: Bool
    ) {
        let previousPalette = lastPalette
        let previousRenderState = lastRenderState
        lastRenderState = renderState
        lastPalette = palette
        if previousRenderState?.bodyVerticalOffsetRatio != renderState.bodyVerticalOffsetRatio {
            setNeedsLayout()
            layoutIfNeeded()
        }
        bodyLayer.palette = palette
        bodyLayer.glassOpacity = renderState.glassOpacity
        bodyLayer.setNeedsDisplay()
        refractionLayer.palette = palette
        refractionLayer.intensity = renderState.usesTransparentGlass
            ? min(1.0, max(0.24, renderState.glowIntensity))
            : 0.32
        refractionLayer.glassOpacity = renderState.glassOpacity
        refractionLayer.setNeedsDisplay()

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
            self.updateParticleEmitter(renderState: renderState, palette: palette)
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

    private func bodyVerticalOffset(diameter: CGFloat) -> CGFloat {
        let ratio = lastRenderState?.bodyVerticalOffsetRatio ?? 0
        guard ratio != 0, bounds.height > 0 else { return 0 }

        let requestedOffset = bounds.height * ratio
        let bottomLimit = bounds.maxY - diameter / 2 - bounds.midY - 2
        let topLimit = bounds.minY + diameter / 2 - bounds.midY + 2
        return min(max(requestedOffset, topLimit), bottomLimit)
    }

    private func configureLayers() {
        mistLayer.name = "mist"
        mistLayer.type = .radial
        mistLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        mistLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        mistLayer.locations = [0, 0.38, 1]
        mistLayer.mask = mistMaskLayer

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

        refractionLayer.name = "coreImageRefraction"
        refractionLayer.contentsScale = UIScreen.main.scale
        refractionLayer.needsDisplayOnBoundsChange = true

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

        particleEmitterLayer.name = "particleEmitter"
        particleEmitterLayer.emitterShape = .circle
        particleEmitterLayer.emitterMode = .outline
        particleEmitterLayer.renderMode = .additive
        particleEmitterLayer.birthRate = 0

        layer.addSublayer(mistLayer)
        layer.addSublayer(orbitContainerLayer)
        orbitContainerLayer.addSublayer(backArcLayer)
        orbitContainerLayer.addSublayer(frontArcLayer)
        layer.addSublayer(bodyContainerLayer)
        bodyContainerLayer.addSublayer(glowLayer)
        bodyContainerLayer.addSublayer(bodyLayer)
        bodyContainerLayer.addSublayer(refractionLayer)
        bodyContainerLayer.addSublayer(highlightLayer)
        layer.addSublayer(particleEmitterLayer)
        layer.addSublayer(rippleLayer)
    }

    private func bodyTransform(for state: TaijiRefreshRenderState) -> CATransform3D {
        var transform = CATransform3DMakeScale(state.bodyScale, state.bodyScale, 1)
        if !state.preservesCurrentRotation {
            transform = CATransform3DRotate(transform, state.rotation, 0, 0, 1)
        }
        return transform
    }

    private func updateArcPaths(in bodyFrame: CGRect) {
        let radius = bodyFrame.width * 0.66
        let center = CGPoint(x: bodyFrame.midX, y: bodyFrame.midY)
        let backRect = CGRect(
            x: center.x - radius,
            y: center.y - radius * 0.59,
            width: radius * 2,
            height: radius * 1.18
        )
        let frontRect = CGRect(
            x: center.x - radius * 0.82,
            y: center.y - radius * 0.50,
            width: radius * 1.64,
            height: radius * 1.00
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
        frontArcLayer.strokeEnd = min(0.52 + renderState.arcSweep / (2 * .pi) * 0.64, 0.94)

        mistLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.42).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.30).cgColor,
            palette.backgroundTint.withAlphaComponent(0.0).cgColor,
        ]
        glowLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.56).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.28).cgColor,
            UIColor.clear.cgColor,
        ]
        rippleLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.30).cgColor
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
        let radius = diameter * (0.44 + progress * 0.34)
        let rect = CGRect(
            x: bodyContainerLayer.frame.midX - radius,
            y: bodyContainerLayer.frame.midY - radius,
            width: radius * 2,
            height: radius * 2
        )
        rippleLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    private func updateParticleEmitterFrame() {
        particleEmitterLayer.frame = bounds
        particleEmitterLayer.emitterPosition = CGPoint(
            x: bodyContainerLayer.frame.midX,
            y: bodyContainerLayer.frame.midY
        )
        particleEmitterLayer.emitterSize = CGSize(
            width: max(bodyContainerLayer.bounds.width * 1.36, 1),
            height: max(bodyContainerLayer.bounds.height * 0.82, 1)
        )
    }

    private func updateParticleEmitter(renderState: TaijiRefreshRenderState, palette: TaijiRefreshPalette) {
        updateParticleEmitterFrame()

        let visibleCount = min(max(renderState.particleCount, 0), 18)
        guard visibleCount > 0, renderState.particleIntensity > 0 else {
            particleEmitterLayer.birthRate = 0
            return
        }

        particleEmitterLayer.birthRate = Float(renderState.particleIntensity)
        particleEmitterLayer.emitterCells = Self.particleEmitterCells(
            visibleCount: visibleCount,
            palette: palette
        )
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
            if orbitContainerLayer.animation(forKey: "taiji.refreshOrbit") == nil {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.fromValue = 0
                animation.toValue = 2 * CGFloat.pi
                animation.duration = 1 / TimeInterval(state.continuousRotationSpeed)
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .linear)
                orbitContainerLayer.add(animation, forKey: "taiji.refreshOrbit")
            }
        } else {
            isContinuousAnimationActive = false
            if bodyContainerLayer.animation(forKey: "taiji.rotation") != nil,
               let presentation = bodyContainerLayer.presentation() {
                bodyContainerLayer.transform = presentation.transform
            }
            bodyContainerLayer.removeAnimation(forKey: "taiji.rotation")
            orbitContainerLayer.removeAnimation(forKey: "taiji.refreshOrbit")
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

        let usesPullMotion = state.particleCount > 0
            && state.rippleProgress == 0
            && state.continuousRotationSpeed == 0
            && !state.usesGlowPulse
        updatePullMotion(isActive: usesPullMotion)

        if state.rippleProgress > 0 {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.72
            animation.toValue = 0
            animation.duration = 0.26
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            rippleLayer.add(animation, forKey: "taiji.ripple")
            addVanishAnimation(for: state)
        } else {
            rippleLayer.removeAnimation(forKey: "taiji.ripple")
            bodyContainerLayer.removeAnimation(forKey: "taiji.vanish")
            mistLayer.removeAnimation(forKey: "taiji.vanishMist")
            glowLayer.removeAnimation(forKey: "taiji.vanishGlow")
        }
    }

    private func updatePullMotion(isActive: Bool) {
        guard isActive else {
            orbitContainerLayer.removeAnimation(forKey: "taiji.pullOrbit")
            return
        }

        if orbitContainerLayer.animation(forKey: "taiji.pullOrbit") == nil {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -CGFloat.pi * 0.035
            animation.toValue = CGFloat.pi * 0.035
            animation.duration = 1.25
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            orbitContainerLayer.add(animation, forKey: "taiji.pullOrbit")
        }
    }

    private func addVanishAnimation(for state: TaijiRefreshRenderState) {
        if bodyContainerLayer.animation(forKey: "taiji.vanish") == nil {
            let sourceTransform = bodyContainerLayer.presentation()?.transform ?? bodyContainerLayer.transform
            let liftedTransform = CATransform3DTranslate(sourceTransform, 0, -bodyContainerLayer.bounds.height * 0.22, 0)
            let softenedTransform = CATransform3DScale(liftedTransform, 0.82, 0.82, 1)

            let transform = CABasicAnimation(keyPath: "transform")
            transform.fromValue = NSValue(caTransform3D: sourceTransform)
            transform.toValue = NSValue(caTransform3D: softenedTransform)

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = max(0.36, state.bodyAlpha)
            opacity.toValue = 0

            let animation = CAAnimationGroup()
            animation.animations = [transform, opacity]
            animation.duration = 0.30
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bodyContainerLayer.add(animation, forKey: "taiji.vanish")
        }

        if mistLayer.animation(forKey: "taiji.vanishMist") == nil {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = max(0.10, state.glowIntensity * 0.72)
            animation.toValue = 0
            animation.duration = 0.34
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            mistLayer.add(animation, forKey: "taiji.vanishMist")
        }

        if glowLayer.animation(forKey: "taiji.vanishGlow") == nil {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 1
            animation.toValue = 1.12
            animation.duration = 0.28
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            glowLayer.add(animation, forKey: "taiji.vanishGlow")
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

    private static func particleEmitterCells(
        visibleCount: Int,
        palette: TaijiRefreshPalette
    ) -> [CAEmitterCell] {
        let spark = CAEmitterCell()
        spark.name = "spark"
        spark.contents = particleImage
        spark.birthRate = Float(visibleCount) * 1.12
        spark.lifetime = 1.12
        spark.lifetimeRange = 0.42
        spark.velocity = 13
        spark.velocityRange = 9
        spark.emissionRange = .pi * 2
        spark.scale = 0.058
        spark.scaleRange = 0.032
        spark.scaleSpeed = -0.014
        spark.alphaSpeed = -0.50
        spark.spin = 0.8
        spark.spinRange = 1.6
        spark.color = palette.particle.withAlphaComponent(0.96).cgColor

        let dust = CAEmitterCell()
        dust.name = "dust"
        dust.contents = particleImage
        dust.birthRate = Float(visibleCount) * 0.72
        dust.lifetime = 1.80
        dust.lifetimeRange = 0.56
        dust.velocity = 5
        dust.velocityRange = 5
        dust.emissionRange = .pi * 2
        dust.scale = 0.044
        dust.scaleRange = 0.024
        dust.scaleSpeed = -0.008
        dust.alphaSpeed = -0.28
        dust.spin = 0.3
        dust.spinRange = 1.1
        dust.color = palette.primaryGlow.withAlphaComponent(0.58).cgColor

        return [spark, dust]
    }

    private static let particleImage: CGImage? = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            let rect = CGRect(x: 1, y: 1, width: 8, height: 8)
            let colors = [
                UIColor.white.withAlphaComponent(0.95).cgColor,
                UIColor.white.withAlphaComponent(0.18).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.42, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }

            cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endCenter: CGPoint(x: rect.midX, y: rect.midY),
                endRadius: rect.width / 2,
                options: []
            )
        }.cgImage
    }()
}

private final class TaijiRefractionLayer: CALayer {
    private static let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
        .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
    ])

    var palette: TaijiRefreshPalette = .dark
    var intensity: CGFloat = 0.24
    var glassOpacity: CGFloat = 0.62

    override func draw(in context: CGContext) {
        let rect = bounds.insetBy(dx: 1.6, dy: 1.6)
        guard rect.width > 1, rect.height > 1, intensity > 0.01 else { return }
        guard let image = makeRefractionImage(size: rect.size) else { return }

        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        context.setBlendMode(.screen)
        context.setAlpha(min(0.50, 0.16 + intensity * 0.34))
        context.draw(image, in: rect)
        context.restoreGState()
    }

    private func makeRefractionImage(size: CGSize) -> CGImage? {
        let scale = max(contentsScale, 1)
        let pixelSize = CGSize(
            width: max(size.width * scale, 1),
            height: max(size.height * scale, 1)
        )
        let extent = CGRect(origin: .zero, size: pixelSize)

        guard let highlight = radialImage(
            extent: extent,
            center: CGPoint(x: extent.width * 0.34, y: extent.height * 0.70),
            innerColor: palette.glassHighlight.withAlphaComponent(glassOpacity * 0.74),
            outerColor: palette.primaryGlow.withAlphaComponent(0.0),
            radius: extent.width * 0.68
        ),
        let glow = radialImage(
            extent: extent,
            center: CGPoint(x: extent.width * 0.70, y: extent.height * 0.28),
            innerColor: palette.secondaryGlow.withAlphaComponent(0.34 * intensity),
            outerColor: palette.shadowCore.withAlphaComponent(0.0),
            radius: extent.width * 0.58
        ) else {
            return nil
        }

        let composited = highlight.applyingFilter(
            "CIScreenBlendMode",
            parameters: ["inputBackgroundImage": glow]
        )
        let bumped = composited.applyingFilter(
            "CIBumpDistortion",
            parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: extent.width * 0.62,
                kCIInputScaleKey: 0.24 + intensity * 0.36,
            ]
        )
        let softened = bumped
            .cropped(to: extent)
            .applyingFilter(
                "CIGaussianBlur",
                parameters: [kCIInputRadiusKey: max(0.4, extent.width * 0.010)]
            )
            .cropped(to: extent)

        return Self.ciContext.createCGImage(softened, from: extent)
    }

    private func radialImage(
        extent: CGRect,
        center: CGPoint,
        innerColor: UIColor,
        outerColor: UIColor,
        radius: CGFloat
    ) -> CIImage? {
        let filter = CIFilter(name: "CIRadialGradient")
        filter?.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
        filter?.setValue(radius * 0.04, forKey: "inputRadius0")
        filter?.setValue(radius, forKey: "inputRadius1")
        filter?.setValue(CIColor(color: innerColor), forKey: "inputColor0")
        filter?.setValue(CIColor(color: outerColor), forKey: "inputColor1")
        return filter?.outputImage?.cropped(to: extent)
    }
}

private final class TaijiBodyLayer: CALayer {
    var palette: TaijiRefreshPalette = .dark
    var glassOpacity: CGFloat = 0.62

    override func draw(in context: CGContext) {
        let rect = bounds.insetBy(dx: 1.2, dy: 1.2)
        guard rect.width > 1, rect.height > 1 else { return }

        let circlePath = UIBezierPath(ovalIn: rect)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 2.4),
            blur: 10,
            color: palette.primaryGlow.withAlphaComponent(0.42).cgColor
        )
        context.addPath(circlePath.cgPath)
        context.setFillColor(palette.shadowCore.withAlphaComponent(0.18).cgColor)
        context.fillPath()
        context.restoreGState()

        drawClippedRadialGradient(
            in: context,
            path: circlePath,
            colors: [
                palette.glassHighlight.withAlphaComponent(glassOpacity * 0.86),
                palette.primaryGlow.withAlphaComponent(0.34),
                palette.shadowCore.withAlphaComponent(0.64),
            ],
            locations: [0, 0.48, 1],
            startCenter: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.28),
            endCenter: CGPoint(x: rect.midX, y: rect.midY),
            endRadius: rect.width * 0.78
        )

        drawClippedRadialGradient(
            in: context,
            path: circlePath,
            colors: [
                palette.primaryGlow.withAlphaComponent(0.34),
                UIColor.clear,
            ],
            locations: [0, 1],
            startCenter: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.32),
            endCenter: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.32),
            endRadius: rect.width * 0.54
        )

        drawClippedRadialGradient(
            in: context,
            path: circlePath,
            colors: [
                palette.secondaryGlow.withAlphaComponent(0.40),
                UIColor.clear,
            ],
            locations: [0, 1],
            startCenter: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.22),
            endCenter: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.22),
            endRadius: rect.width * 0.58
        )

        let shadowPath = makeShadowLobePath(in: rect)
        drawClippedLinearGradient(
            in: context,
            path: shadowPath,
            colors: [
                palette.shadowCore.withAlphaComponent(0.96),
                palette.secondaryGlow.withAlphaComponent(0.58),
                palette.shadowCore.withAlphaComponent(0.84),
            ],
            locations: [0, 0.54, 1],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        let topCore = CGRect(
            x: rect.midX - rect.width * 0.105,
            y: rect.minY + rect.height * 0.24,
            width: rect.width * 0.21,
            height: rect.height * 0.21
        )
        let bottomCore = CGRect(
            x: rect.midX - rect.width * 0.105,
            y: rect.maxY - rect.height * 0.44,
            width: rect.width * 0.21,
            height: rect.height * 0.21
        )

        drawClippedRadialGradient(
            in: context,
            path: UIBezierPath(ovalIn: topCore),
            colors: [
                palette.secondaryGlow.withAlphaComponent(0.58),
                palette.shadowCore.withAlphaComponent(0.96),
            ],
            locations: [0, 1],
            startCenter: CGPoint(x: topCore.midX - topCore.width * 0.18, y: topCore.midY - topCore.height * 0.18),
            endCenter: CGPoint(x: topCore.midX, y: topCore.midY),
            endRadius: topCore.width * 0.72
        )

        drawClippedRadialGradient(
            in: context,
            path: UIBezierPath(ovalIn: bottomCore),
            colors: [
                palette.glassHighlight.withAlphaComponent(0.98),
                palette.primaryGlow.withAlphaComponent(0.54),
            ],
            locations: [0, 1],
            startCenter: CGPoint(x: bottomCore.midX - bottomCore.width * 0.18, y: bottomCore.midY - bottomCore.height * 0.20),
            endCenter: CGPoint(x: bottomCore.midX, y: bottomCore.midY),
            endRadius: bottomCore.width * 0.72
        )

        let sheenRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.10)
        let sheenPath = UIBezierPath()
        sheenPath.move(to: CGPoint(x: sheenRect.minX + sheenRect.width * 0.08, y: sheenRect.minY + sheenRect.height * 0.24))
        sheenPath.addCurve(
            to: CGPoint(x: sheenRect.maxX - sheenRect.width * 0.10, y: sheenRect.minY + sheenRect.height * 0.38),
            controlPoint1: CGPoint(x: sheenRect.midX - sheenRect.width * 0.10, y: sheenRect.minY - sheenRect.height * 0.02),
            controlPoint2: CGPoint(x: sheenRect.midX + sheenRect.width * 0.22, y: sheenRect.minY + sheenRect.height * 0.16)
        )
        context.addPath(sheenPath.cgPath)
        context.setStrokeColor(palette.glassHighlight.withAlphaComponent(0.62).cgColor)
        context.setLineWidth(3.2)
        context.setLineCap(.round)
        context.strokePath()

        context.setStrokeColor(palette.shadowCore.withAlphaComponent(0.46).cgColor)
        context.setLineWidth(4.6)
        context.strokeEllipse(in: rect.insetBy(dx: 0.4, dy: 0.4))
        context.setStrokeColor(palette.primaryGlow.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(2.1)
        context.strokeEllipse(in: rect.insetBy(dx: 1.0, dy: 1.0))
        context.setStrokeColor(palette.glassHighlight.withAlphaComponent(0.86).cgColor)
        context.setLineWidth(1.1)
        context.strokeEllipse(in: rect.insetBy(dx: 2.1, dy: 2.1))
    }

    private func makeShadowLobePath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.25),
            radius: rect.width * 0.25,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.25),
            radius: rect.width * 0.25,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: false
        )
        path.addArc(
            withCenter: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width * 0.5,
            startAngle: .pi / 2,
            endAngle: -.pi / 2,
            clockwise: false
        )
        path.close()
        return path
    }

    private func drawClippedLinearGradient(
        in context: CGContext,
        path: UIBezierPath,
        colors: [UIColor],
        locations: [CGFloat],
        start: CGPoint,
        end: CGPoint
    ) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: locations
        ) else { return }

        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }

    private func drawClippedRadialGradient(
        in context: CGContext,
        path: UIBezierPath,
        colors: [UIColor],
        locations: [CGFloat],
        startCenter: CGPoint,
        endCenter: CGPoint,
        endRadius: CGFloat
    ) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: locations
        ) else { return }

        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        context.drawRadialGradient(
            gradient,
            startCenter: startCenter,
            startRadius: 0,
            endCenter: endCenter,
            endRadius: endRadius,
            options: []
        )
        context.restoreGState()
    }
}
