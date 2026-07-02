import UIKit

/// Visible and accessibility text used by `KineticRefreshStyle`.
public struct KineticRefreshTexts {
    public var idle: String
    public var pulling: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
    public var noMoreData: String
    public var accessibilityLabel: String
    public var idleAccessibilityValue: String
    public var pullingAccessibilityValue: String
    public var triggeredAccessibilityValue: String
    public var refreshingAccessibilityValue: String
    public var endingAccessibilityValue: String
    public var noMoreDataAccessibilityValue: String

    /// Creates text for the kinetic refresh style.
    public init(
        idle: String = "下拉刷新",
        pulling: String = "继续下拉",
        triggered: String = "松手刷新",
        refreshing: String = "正在更新",
        ending: String = "刷新完成",
        noMoreData: String = "没有更多数据",
        accessibilityLabel: String = "刷新",
        idleAccessibilityValue: String = "未刷新",
        pullingAccessibilityValue: String = "下拉中",
        triggeredAccessibilityValue: String = "释放刷新",
        refreshingAccessibilityValue: String = "正在更新",
        endingAccessibilityValue: String = "刷新完成",
        noMoreDataAccessibilityValue: String = "没有更多数据"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.refreshing = refreshing
        self.ending = ending
        self.noMoreData = noMoreData
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.refreshingAccessibilityValue = refreshingAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
        self.noMoreDataAccessibilityValue = noMoreDataAccessibilityValue
    }
}

/// Color palette used by `KineticRefreshStyle`.
public struct KineticRefreshPalette {
    public var teal: UIColor
    public var coral: UIColor
    public var indigo: UIColor
    public var lime: UIColor
    public var ink: UIColor
    public var surface: UIColor

    /// Creates a playful kinetic palette.
    public init(
        teal: UIColor = .systemTeal,
        coral: UIColor = .systemPink,
        indigo: UIColor = .systemIndigo,
        lime: UIColor = UIColor(red: 0.58, green: 0.84, blue: 0.16, alpha: 1),
        ink: UIColor = .label,
        surface: UIColor = .white
    ) {
        self.teal = teal
        self.coral = coral
        self.indigo = indigo
        self.lime = lime
        self.ink = ink
        self.surface = surface
    }
}

/// A playful refresh style with an elastic path, rotating glyph, ticks, and status label.
@MainActor
public final class KineticRefreshStyle: RefreshableStyle {

    /// The root view installed into the scroll view.
    public let view: UIView

    /// Header height.
    public let extent: CGFloat

    private let texts: KineticRefreshTexts
    private let palette: KineticRefreshPalette
    private let kineticView: KineticRefreshView

    /// Creates a kinetic refresh style.
    public init(
        extent: CGFloat = 82,
        texts: KineticRefreshTexts = KineticRefreshTexts(),
        palette: KineticRefreshPalette = KineticRefreshPalette()
    ) {
        self.extent = extent
        self.texts = texts
        self.palette = palette
        self.kineticView = KineticRefreshView(frame: CGRect(x: 0, y: 0, width: 320, height: extent))
        self.view = kineticView
        self.view.frame.size.height = extent
        self.view.isAccessibilityElement = true
        self.view.accessibilityLabel = texts.accessibilityLabel
        kineticView.apply(palette: palette)
        update(state: .idle, progress: 0)
    }

    /// Updates the kinetic refresh control for the current state.
    public func update(state: RefreshState, progress: CGFloat) {
        let normalizedProgress = state.normalizedKineticProgress(fallback: progress)
        kineticView.render(
            state: state,
            progress: normalizedProgress,
            text: visibleText(for: state, progress: normalizedProgress),
            palette: palette,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
        view.accessibilityValue = accessibilityValue(for: state)
    }

    private func visibleText(for state: RefreshState, progress: CGFloat) -> String {
        switch state {
        case .idle:
            texts.idle
        case .pulling:
            progress >= 1 ? texts.triggered : texts.pulling
        case .triggered:
            texts.triggered
        case .refreshing:
            texts.refreshing
        case .ending:
            texts.ending
        case .noMoreData:
            texts.noMoreData
        }
    }

    private func accessibilityValue(for state: RefreshState) -> String {
        switch state {
        case .idle:
            texts.idleAccessibilityValue
        case .pulling:
            texts.pullingAccessibilityValue
        case .triggered:
            texts.triggeredAccessibilityValue
        case .refreshing:
            texts.refreshingAccessibilityValue
        case .ending:
            texts.endingAccessibilityValue
        case .noMoreData:
            texts.noMoreDataAccessibilityValue
        }
    }
}

@MainActor
private final class KineticRefreshView: UIView {

    private let pathLayer = CAShapeLayer()
    private let ribbonGradientLayer = CAGradientLayer()
    private let progressLayer = CAShapeLayer()
    private let glyphContainer = UIView()
    private let glyphView = UIImageView()
    private let pillView = UIView()
    private let statusDot = UIView()
    private let label = UILabel()
    private let tickLayers: [CAShapeLayer] = (0..<11).map { _ in CAShapeLayer() }
    private var currentPalette = KineticRefreshPalette()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ribbonGradientLayer.frame = bounds
        progressLayer.frame = bounds
        let centerY = glyphContainer.center.y
        let pathRect = ribbonPathRect(centerY: centerY)
        pathLayer.path = elasticPath(in: pathRect, progress: 1).cgPath
        progressLayer.path = pathLayer.path
        layoutTickLayers(progress: 1)
    }

    func apply(palette: KineticRefreshPalette) {
        currentPalette = palette
        pathLayer.strokeColor = palette.teal.withAlphaComponent(0.16).cgColor
        progressLayer.strokeColor = UIColor.black.cgColor
        ribbonGradientLayer.colors = [
            palette.coral.withAlphaComponent(0).cgColor,
            palette.coral.withAlphaComponent(0.75).cgColor,
            palette.indigo.withAlphaComponent(0.95).cgColor,
            palette.teal.withAlphaComponent(0.95).cgColor,
            UIColor(red: 0.08, green: 0.68, blue: 0.92, alpha: 0.95).cgColor,
            palette.lime.withAlphaComponent(0.9).cgColor,
            palette.lime.withAlphaComponent(0).cgColor,
        ]
        ribbonGradientLayer.locations = [0, 0.12, 0.34, 0.5, 0.66, 0.86, 1]
        ribbonGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        ribbonGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        glyphContainer.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        glyphView.tintColor = palette.teal
        pillView.backgroundColor = palette.surface.withAlphaComponent(0.94)
        label.textColor = palette.ink
        statusDot.backgroundColor = palette.teal

        let colors = [
            palette.coral,
            palette.coral,
            UIColor(red: 1.0, green: 0.62, blue: 0.16, alpha: 1),
            UIColor(red: 1.0, green: 0.62, blue: 0.16, alpha: 1),
            palette.indigo,
            UIColor(red: 0.56, green: 0.39, blue: 0.96, alpha: 1),
            palette.teal,
            UIColor(red: 0.12, green: 0.68, blue: 0.92, alpha: 1),
            palette.lime,
            UIColor(red: 0.42, green: 0.78, blue: 0.22, alpha: 1),
            UIColor(red: 0.50, green: 0.82, blue: 0.16, alpha: 1),
        ]
        for (index, layer) in tickLayers.enumerated() {
            layer.fillColor = colors[index % colors.count].cgColor
        }
    }

    func render(
        state: RefreshState,
        progress: CGFloat,
        text: String,
        palette: KineticRefreshPalette,
        reduceMotion: Bool
    ) {
        apply(palette: palette)
        let p = min(max(progress, 0), 1)
        label.text = text
        progressLayer.strokeEnd = p
        let pathCenterY = glyphContainer.center.y
        pathLayer.path = elasticPath(in: ribbonPathRect(centerY: pathCenterY), progress: max(p, 0.08)).cgPath
        progressLayer.path = pathLayer.path
        layoutTickLayers(progress: p)
        tickLayers.enumerated().forEach { index, layer in
            layer.opacity = Float(p >= CGFloat(index + 1) / CGFloat(tickLayers.count) ? 1 : 0.28)
        }

        switch state {
        case .idle:
            stopMotion()
            layer.opacity = 0
            glyphContainer.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
            pillView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        case .pulling:
            stopMotion()
            layer.opacity = Float(0.25 + p * 0.75)
            glyphContainer.transform = CGAffineTransform(rotationAngle: reduceMotion ? 0 : p * .pi)
                .scaledBy(x: 0.88 + p * 0.12, y: 0.88 + p * 0.12)
            pillView.transform = .identity

        case .triggered:
            stopMotion()
            layer.opacity = 1
            glyphContainer.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            pillView.transform = .identity

        case .refreshing:
            layer.opacity = 1
            glyphContainer.transform = .identity
            pillView.transform = .identity
            reduceMotion ? startPulse() : startSpin()
            startTickDance()

        case .ending:
            stopMotion()
            layer.opacity = 0.82
            glyphContainer.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            pillView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            progressLayer.strokeEnd = 1

        case .noMoreData:
            stopMotion()
            layer.opacity = 0.7
            glyphContainer.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            pillView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            progressLayer.strokeEnd = 0.25
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        pathLayer.fillColor = nil
        pathLayer.lineCap = .round
        pathLayer.lineJoin = .round
        pathLayer.lineWidth = 3.5
        pathLayer.zPosition = 0
        layer.addSublayer(pathLayer)

        progressLayer.fillColor = nil
        progressLayer.lineCap = .round
        progressLayer.lineJoin = .round
        progressLayer.lineWidth = 3.5
        progressLayer.strokeEnd = 0

        ribbonGradientLayer.mask = progressLayer
        ribbonGradientLayer.zPosition = 1
        layer.addSublayer(ribbonGradientLayer)

        tickLayers.enumerated().forEach { index, tick in
            let size = tickSize(at: index)
            tick.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: min(size.width, size.height) / 2).cgPath
            tick.bounds = CGRect(origin: .zero, size: size)
            tick.opacity = 0.25
            tick.zPosition = 2
            layer.addSublayer(tick)
        }

        glyphContainer.translatesAutoresizingMaskIntoConstraints = false
        glyphContainer.layer.cornerRadius = 22
        glyphContainer.layer.cornerCurve = .continuous
        glyphContainer.layer.shadowColor = UIColor.black.cgColor
        glyphContainer.layer.shadowOpacity = 0.11
        glyphContainer.layer.shadowRadius = 12
        glyphContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        glyphContainer.layer.zPosition = 4
        addSubview(glyphContainer)

        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        glyphView.image = UIImage(systemName: "arrow.clockwise", withConfiguration: imageConfiguration)
        glyphView.contentMode = .center
        glyphView.translatesAutoresizingMaskIntoConstraints = false
        glyphContainer.addSubview(glyphView)

        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.layer.cornerRadius = 15
        pillView.layer.cornerCurve = .continuous
        pillView.layer.borderWidth = 0
        pillView.layer.borderColor = UIColor.clear.cgColor
        pillView.layer.shadowColor = UIColor.black.cgColor
        pillView.layer.shadowOpacity = 0.1
        pillView.layer.shadowRadius = 12
        pillView.layer.shadowOffset = CGSize(width: 0, height: 5)
        pillView.layer.zPosition = 4
        addSubview(pillView)

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.layer.cornerRadius = 4
        pillView.addSubview(statusDot)

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        pillView.addSubview(label)

        NSLayoutConstraint.activate([
            glyphContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyphContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7),
            glyphContainer.widthAnchor.constraint(equalToConstant: 44),
            glyphContainer.heightAnchor.constraint(equalToConstant: 44),

            glyphView.centerXAnchor.constraint(equalTo: glyphContainer.centerXAnchor),
            glyphView.centerYAnchor.constraint(equalTo: glyphContainer.centerYAnchor),
            glyphView.widthAnchor.constraint(equalTo: glyphContainer.widthAnchor),
            glyphView.heightAnchor.constraint(equalTo: glyphContainer.heightAnchor),

            pillView.topAnchor.constraint(equalTo: glyphContainer.bottomAnchor, constant: 5),
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillView.heightAnchor.constraint(equalToConstant: 30),

            statusDot.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
        ])
    }

    private func ribbonPathRect(centerY: CGFloat) -> CGRect {
        CGRect(x: bounds.minX + 22, y: centerY - 14, width: max(bounds.width - 44, 120), height: 32)
    }

    private func elasticPath(in rect: CGRect, progress: CGFloat) -> UIBezierPath {
        let stretch = min(max(progress, 0), 1) * 11
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.midY + stretch * 0.55),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY + stretch)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY - stretch),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.midY - stretch * 0.45)
        )
        return path
    }

    private func layoutTickLayers(progress: CGFloat) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let centerY = glyphContainer.center.y
        let availableWidth = max(bounds.width - 70, 180)
        let startX = bounds.midX - availableWidth / 2
        for (index, layer) in tickLayers.enumerated() {
            let size = tickSize(at: index)
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: min(size.width, size.height) / 2).cgPath
            let layout = tickLayout(at: index)
            let x = startX + availableWidth * layout.fraction
            layer.position = CGPoint(x: x, y: centerY - 2 + layout.yOffset)
        }
    }

    private func tickSize(at index: Int) -> CGSize {
        switch index {
        case 0, 6, 10:
            CGSize(width: 4, height: 4)
        case 1:
            CGSize(width: 8, height: 8)
        case 2, 4, 9:
            CGSize(width: 5, height: 5)
        case 3:
            CGSize(width: 8, height: 22)
        case 5:
            CGSize(width: 9, height: 34)
        case 7:
            CGSize(width: 9, height: 32)
        case 8:
            CGSize(width: 9, height: 28)
        default:
            CGSize(width: 6, height: 6)
        }
    }

    private func tickLayout(at index: Int) -> (fraction: CGFloat, yOffset: CGFloat) {
        let layouts: [(CGFloat, CGFloat)] = [
            (0.03, 7),
            (0.12, 10),
            (0.21, -23),
            (0.22, 0),
            (0.32, -25),
            (0.35, -8),
            (0.59, -24),
            (0.63, 0),
            (0.75, -16),
            (0.84, 19),
            (0.96, -21),
        ]
        return layouts[index % layouts.count]
    }

    private func startSpin() {
        glyphContainer.layer.removeAnimation(forKey: "kineticPulse")
        guard glyphContainer.layer.animation(forKey: "kineticSpin") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.72
        animation.repeatCount = .infinity
        glyphContainer.layer.add(animation, forKey: "kineticSpin")
    }

    private func startPulse() {
        glyphContainer.layer.removeAnimation(forKey: "kineticSpin")
        guard glyphContainer.layer.animation(forKey: "kineticPulse") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.94
        animation.toValue = 1.05
        animation.duration = 0.62
        animation.autoreverses = true
        animation.repeatCount = .infinity
        glyphContainer.layer.add(animation, forKey: "kineticPulse")
    }

    private func startTickDance() {
        for (index, tick) in tickLayers.enumerated() where tick.animation(forKey: "kineticTick") == nil {
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = index.isMultiple(of: 2) ? -5 : 5
            animation.duration = 0.34
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.06
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            tick.add(animation, forKey: "kineticTick")
        }
    }

    private func stopMotion() {
        glyphContainer.layer.removeAnimation(forKey: "kineticSpin")
        glyphContainer.layer.removeAnimation(forKey: "kineticPulse")
        tickLayers.forEach { $0.removeAnimation(forKey: "kineticTick") }
    }
}

private extension RefreshState {
    func normalizedKineticProgress(fallback: CGFloat) -> CGFloat {
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
