import UIKit

final class CAShapeLayerHostView: UIView {
    let trackLayer = CAShapeLayer()
    let progressLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        setupLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCirclePath()
    }

    private func setupLayers() {
        [trackLayer, progressLayer].forEach { shapeLayer in
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineCap = .round
            shapeLayer.lineWidth = 3
            shapeLayer.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
            layer.addSublayer(shapeLayer)
        }

        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.strokeEnd = 0
    }

    private func updateCirclePath() {
        let inset = max(trackLayer.lineWidth, progressLayer.lineWidth) / 2
        let side = min(bounds.width, bounds.height) - inset * 2
        let origin = CGPoint(
            x: bounds.midX - side / 2,
            y: bounds.midY - side / 2
        )
        let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let path = UIBezierPath(ovalIn: rect).cgPath
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path
        progressLayer.path = path
    }
}

private final class DefaultEdgeStyleRootView: UIView {
    weak var horizontalContentView: UIView?
    var horizontalContentWidth: CGFloat = 72 {
        didSet { setNeedsLayout() }
    }
    var horizontalContentPhysicalEdge: RefreshablePhysicalEdge = .left {
        didSet { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let horizontalContentView else { return }

        let width = min(horizontalContentWidth, bounds.width)
        let x: CGFloat
        switch horizontalContentPhysicalEdge {
        case .right:
            x = max(bounds.width - width, 0)
        case .top, .bottom, .left:
            x = 0
        }

        horizontalContentView.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
    }
}

/// 非传统边缘使用的默认刷新样式。
@MainActor
final class DefaultEdgeStyle: RefreshableStyle {

    struct RenderState: Equatable {
        var progress: CGFloat
        var labelText: String
        var arrowSystemName: String
        var showsArrow: Bool
        var progressAlpha: CGFloat
        var shouldRotateProgress: Bool

        @MainActor
        init(
            edge: RefreshableEdge,
            role: RefreshableRole,
            state: RefreshState,
            progress: CGFloat,
            in view: UIView
        ) {
            self.progress = Self.resolvedProgress(for: state, progress: progress)
            self.labelText = Self.resolvedLabelText(for: state, role: role, edge: edge)
            self.arrowSystemName = Self.resolvedArrowSystemName(for: edge.physicalEdge(in: view))
            self.showsArrow = state != .refreshing && state != .noMoreData
            self.progressAlpha = state == .noMoreData ? 0.35 : 1
            self.shouldRotateProgress = state == .refreshing && !UIAccessibility.isReduceMotionEnabled
        }

        private static func resolvedProgress(for state: RefreshState, progress: CGFloat) -> CGFloat {
            switch state {
            case .idle:
                return 0
            case .pulling(let stateProgress):
                return clamp(max(progress, stateProgress))
            case .triggered:
                return 1
            case .refreshing:
                return 0.78
            case .ending:
                return 0.35
            case .noMoreData:
                return 1
            }
        }

        private static func resolvedLabelText(
            for state: RefreshState,
            role: RefreshableRole,
            edge: RefreshableEdge
        ) -> String {
            switch state {
            case .idle, .pulling:
                guard edge.axis == .horizontal else {
                    return role == .refresh ? idleRefreshText(for: edge) : idleLoadMoreText(for: edge)
                }
                return "拖动刷新"
            case .triggered:
                return role == .refresh ? "释放刷新" : "释放加载"
            case .refreshing:
                return role == .refresh ? "正在刷新..." : "正在加载..."
            case .ending:
                return role == .refresh ? "刷新完成" : "加载完成"
            case .noMoreData:
                return "没有更多数据"
            }
        }

        private static func resolvedArrowSystemName(for edge: RefreshablePhysicalEdge) -> String {
            switch edge {
            case .top:
                return "arrow.down"
            case .bottom:
                return "arrow.up"
            case .left:
                return "arrow.right"
            case .right:
                return "arrow.left"
            }
        }

        private static func idleRefreshText(for edge: RefreshableEdge) -> String {
            switch edge {
            case .top:
                return "下拉刷新"
            case .bottom:
                return "上拉刷新"
            case .leading, .trailing:
                return "拖动刷新"
            }
        }

        private static func idleLoadMoreText(for edge: RefreshableEdge) -> String {
            switch edge {
            case .top:
                return "下拉加载"
            case .bottom:
                return "上拉加载"
            case .leading, .trailing:
                return "拖动刷新"
            }
        }

        private static func clamp(_ value: CGFloat) -> CGFloat {
            min(max(value, 0), 1)
        }
    }

    var view: UIView { rootView }
    var extent: CGFloat {
        edge.axis == .horizontal ? horizontalLabelMinimumWidth : 54
    }

    private let rootView = DefaultEdgeStyleRootView()
    private let edge: RefreshableEdge
    private let role: RefreshableRole
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let horizontalContentView = UIView()
    private let progressHost = CAShapeLayerHostView()
    private let arrowView = UIImageView()
    private let horizontalLabelMinimumWidth: CGFloat = 72

    init(edge: RefreshableEdge, role: RefreshableRole) {
        self.edge = edge
        self.role = role
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        view.isAccessibilityElement = true
        view.accessibilityLabel = role == .refresh ? "刷新" : "加载更多"

        if edge.axis == .horizontal {
            setupHorizontalUI()
        } else {
            setupVerticalUI()
        }
    }

    private func setupVerticalUI() {
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        setupLabel(numberOfLines: 2)

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            label.topAnchor.constraint(equalTo: indicator.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -6),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 3),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -3),
        ])
    }

    private func setupHorizontalUI() {
        rootView.horizontalContentView = horizontalContentView
        rootView.horizontalContentWidth = horizontalLabelMinimumWidth
        horizontalContentView.autoresizingMask = []
        horizontalContentView.isUserInteractionEnabled = false
        view.addSubview(horizontalContentView)

        progressHost.translatesAutoresizingMaskIntoConstraints = false
        horizontalContentView.addSubview(progressHost)

        let arrowConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        arrowView.preferredSymbolConfiguration = arrowConfiguration
        arrowView.tintColor = .secondaryLabel
        arrowView.contentMode = .center
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        horizontalContentView.addSubview(arrowView)

        setupLabel(numberOfLines: 1, in: horizontalContentView)
        let minimumLabelWidth = label.widthAnchor.constraint(greaterThanOrEqualToConstant: horizontalLabelMinimumWidth)
        minimumLabelWidth.priority = .defaultHigh

        let constraints: [NSLayoutConstraint] = [
            progressHost.centerXAnchor.constraint(equalTo: horizontalContentView.centerXAnchor),
            progressHost.centerYAnchor.constraint(equalTo: horizontalContentView.centerYAnchor, constant: -13),
            progressHost.widthAnchor.constraint(equalToConstant: 48),
            progressHost.heightAnchor.constraint(equalTo: progressHost.widthAnchor),

            arrowView.centerXAnchor.constraint(equalTo: progressHost.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: progressHost.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 24),
            arrowView.heightAnchor.constraint(equalTo: arrowView.widthAnchor),

            label.topAnchor.constraint(equalTo: progressHost.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: horizontalContentView.centerXAnchor),
            minimumLabelWidth,
            label.widthAnchor.constraint(lessThanOrEqualTo: horizontalContentView.widthAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: horizontalContentView.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: horizontalContentView.trailingAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
        updateHorizontalContentAlignment()
    }

    private func setupLabel(numberOfLines: Int, in containerView: UIView? = nil) {
        label.font = .systemFont(ofSize: edge.axis == .horizontal ? 12 : 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = numberOfLines
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        (containerView ?? view).addSubview(label)
    }

    func update(state: RefreshState, progress: CGFloat) {
        if edge.axis == .horizontal {
            updateHorizontal(state: state, progress: progress)
            return
        }

        switch state {
        case .idle, .pulling:
            label.text = role == .refresh ? idleRefreshText : idleLoadMoreText
            indicator.stopAnimating()
            updateAccessibilityValue(label.text)
        case .triggered:
            label.text = role == .refresh ? "释放刷新" : "释放加载"
            indicator.stopAnimating()
            updateAccessibilityValue(label.text)
        case .refreshing:
            label.text = role == .refresh ? "正在刷新..." : "正在加载..."
            indicator.startAnimating()
            updateAccessibilityValue(role == .refresh ? "正在刷新" : "正在加载")
        case .ending:
            label.text = role == .refresh ? "刷新完成" : "加载完成"
            indicator.stopAnimating()
            updateAccessibilityValue(label.text)
        case .noMoreData:
            label.text = "没有更多数据"
            indicator.stopAnimating()
            updateAccessibilityValue(label.text)
        }
    }

    private func updateHorizontal(state: RefreshState, progress: CGFloat) {
        updateHorizontalContentAlignment()

        let renderState = RenderState(
            edge: edge,
            role: role,
            state: state,
            progress: progress,
            in: view
        )

        label.text = renderState.labelText
        updateAccessibilityValue(accessibilityValue(for: renderState, state: state))

        progressHost.progressLayer.strokeEnd = renderState.progress
        progressHost.progressLayer.opacity = Float(renderState.progressAlpha)
        progressHost.trackLayer.opacity = Float(renderState.progressAlpha)

        let arrowConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        arrowView.image = UIImage(systemName: renderState.arrowSystemName, withConfiguration: arrowConfiguration)
        arrowView.isHidden = !renderState.showsArrow

        let scale = state == .triggered ? 1.06 : 1
        arrowView.transform = CGAffineTransform(scaleX: scale, y: scale)
        updateProgressRotation(shouldRotate: renderState.shouldRotateProgress)
    }

    private func updateHorizontalContentAlignment() {
        guard edge.axis == .horizontal else { return }

        rootView.horizontalContentPhysicalEdge = edge.physicalEdge(in: view)
    }

    private func updateProgressRotation(shouldRotate: Bool) {
        let animationKey = "DefaultEdgeStyle.progressRotation"
        if shouldRotate {
            guard progressHost.layer.animation(forKey: animationKey) == nil else { return }

            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.duration = 1.0
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            progressHost.layer.add(animation, forKey: animationKey)
        } else {
            progressHost.layer.removeAnimation(forKey: animationKey)
        }
    }

    private func accessibilityValue(for renderState: RenderState, state: RefreshState) -> String {
        switch state {
        case .refreshing:
            return role == .refresh ? "正在刷新" : "正在加载"
        default:
            return renderState.labelText
        }
    }

    private func updateAccessibilityValue(_ value: String?) {
        view.accessibilityValue = value
    }

    private var idleRefreshText: String {
        switch edge {
        case .top:
            "下拉刷新"
        case .bottom:
            "上拉刷新"
        case .leading:
            "拖动刷新"
        case .trailing:
            "拖动刷新"
        }
    }

    private var idleLoadMoreText: String {
        switch edge {
        case .top:
            "下拉加载"
        case .bottom:
            "上拉加载"
        case .leading:
            "拖动加载"
        case .trailing:
            "拖动加载"
        }
    }
}
