import UIKit

@MainActor
final class DefaultRefreshControlStyle: RefreshableStyle, RefreshableNoMoreDataInsetProviding {
    let extent: CGFloat
    private let edge: RefreshableEdge
    private let role: RefreshableRole
    private let textConfiguration: RefreshableTextConfiguration?
    private let accessibilityEnvironmentProvider: @MainActor () -> DefaultRefreshStyleAccessibilityEnvironment
    private let accessibilityNotificationCenter: NotificationCenter?

    var defaultTriggerOffset: CGFloat {
        edge.axis == .horizontal ? 54 : extent
    }

    var defaultPlacement: RefreshablePlacement {
        edge.axis == .horizontal
            ? RefreshablePlacement(outerSpacing: 8)
            : RefreshablePlacement()
    }

    var reservesInsetForNoMoreData: Bool {
        guard let textConfiguration else { return false }
        return textConfiguration.noMoreData != ""
    }

    init(
        edge: RefreshableEdge,
        role: RefreshableRole,
        textConfiguration: RefreshableTextConfiguration?,
        accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment? = nil,
        accessibilityEnvironmentProvider: (@MainActor () -> DefaultRefreshStyleAccessibilityEnvironment)? = nil,
        accessibilityNotificationCenter: NotificationCenter = .default
    ) {
        self.edge = edge
        self.role = role
        self.textConfiguration = textConfiguration
        self.extent = textConfiguration != nil && edge.axis == .horizontal ? 72 : 54

        if let accessibilityEnvironment {
            self.accessibilityEnvironmentProvider = { accessibilityEnvironment }
            self.accessibilityNotificationCenter = nil
        } else {
            self.accessibilityEnvironmentProvider = accessibilityEnvironmentProvider ?? { .current }
            self.accessibilityNotificationCenter = accessibilityNotificationCenter
        }
    }

    func makeRenderer() -> any RefreshableStyleRenderer {
        DefaultRefreshControlRenderer(
            edge: edge,
            role: role,
            textConfiguration: textConfiguration,
            extent: extent,
            accessibilityEnvironmentProvider: accessibilityEnvironmentProvider,
            accessibilityNotificationCenter: accessibilityNotificationCenter
        )
    }
}

@MainActor
private final class DefaultRefreshControlRenderer: RefreshableStyleRenderer {
    let view = UIView()
    private let edge: RefreshableEdge
    private let role: RefreshableRole
    private let textConfiguration: RefreshableTextConfiguration?
    private let extent: CGFloat
    private let accessibilityEnvironmentProvider: @MainActor () -> DefaultRefreshStyleAccessibilityEnvironment
    private let accessibilityNotificationCenter: NotificationCenter?
    private let spinnerView = SegmentedRefreshSpinnerView()
    private let label = UILabel()
    private let contentStack = UIStackView()
    private var reduceMotionObservation: DefaultRefreshControlNotificationObservation?
    private var currentState: RefreshState = .idle
    private var currentProgress: CGFloat = 0

    init(
        edge: RefreshableEdge,
        role: RefreshableRole,
        textConfiguration: RefreshableTextConfiguration?,
        extent: CGFloat,
        accessibilityEnvironmentProvider: @escaping @MainActor () -> DefaultRefreshStyleAccessibilityEnvironment,
        accessibilityNotificationCenter: NotificationCenter?
    ) {
        self.edge = edge
        self.role = role
        self.textConfiguration = textConfiguration
        self.extent = extent
        self.accessibilityEnvironmentProvider = accessibilityEnvironmentProvider
        self.accessibilityNotificationCenter = accessibilityNotificationCenter

        setupUI()
        observeReduceMotionChanges()
        render(RefreshableStyleContext(state: .idle, pullProgress: 0))
    }

    func render(_ context: RefreshableStyleContext) {
        currentState = context.state
        currentProgress = context.pullProgress
        updateText(for: context.state)
        updateSpinner(for: context.state, progress: context.pullProgress)
    }

    private func updateSpinner(for state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            spinnerView.setProgress(0, animated: false)
            spinnerView.stopSpinning()
        case .pulling(let stateProgress):
            spinnerView.setProgress(clamp(max(stateProgress, progress)), animated: false)
            spinnerView.stopSpinning()
        case .triggered:
            spinnerView.setProgress(1, animated: false)
            spinnerView.stopSpinning()
        case .refreshing:
            spinnerView.setProgress(1, animated: false)
            if accessibilityEnvironmentProvider().isReduceMotionEnabled {
                spinnerView.stopSpinning()
            } else {
                spinnerView.startSpinning()
            }
        case .ending:
            spinnerView.setProgress(1, animated: false)
            spinnerView.stopSpinning()
        case .noMoreData:
            spinnerView.setProgress(0, animated: false)
            spinnerView.stopSpinning()
        }
    }

    private func setupUI() {
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "Refreshable.DefaultIndicator"
        view.accessibilityLabel = textConfiguration?.accessibilityLabel
            ?? (role == .refresh ? "刷新" : "加载更多")

        spinnerView.tintColor = .systemBlue
        spinnerView.translatesAutoresizingMaskIntoConstraints = false

        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = edge.axis == .horizontal ? 0 : 1
        label.lineBreakMode = edge.axis == .horizontal ? .byWordWrapping : .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = edge.axis == .vertical ? .horizontal : .vertical
        contentStack.alignment = .center
        contentStack.spacing = edge.axis == .vertical ? 8 : 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(spinnerView)
        contentStack.addArrangedSubview(label)
        view.addSubview(contentStack)

        var constraints = [
            spinnerView.widthAnchor.constraint(equalToConstant: 24),
            spinnerView.heightAnchor.constraint(equalToConstant: 24),
            contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ]
        if edge.axis == .horizontal {
            constraints.append(label.widthAnchor.constraint(equalTo: view.widthAnchor))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func observeReduceMotionChanges() {
        guard let accessibilityNotificationCenter else { return }

        let observer = accessibilityNotificationCenter.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateSpinner(for: self.currentState, progress: self.currentProgress)
            }
        }
        reduceMotionObservation = DefaultRefreshControlNotificationObservation(
            center: accessibilityNotificationCenter,
            observer: observer
        )
    }

    private func updateText(for state: RefreshState) {
        let builtInText = builtInText(for: state)
        let override = textOverride(for: state)
        let resolvedText = override ?? builtInText

        label.text = resolvedText
        label.isHidden = textConfiguration == nil || resolvedText.isEmpty

        if let override, !override.isEmpty {
            view.accessibilityValue = override
        } else {
            view.accessibilityValue = builtInAccessibilityValue(for: state)
        }
    }

    private func textOverride(for state: RefreshState) -> String? {
        switch state {
        case .idle:
            textConfiguration?.idle
        case .pulling:
            textConfiguration?.pulling
        case .triggered:
            textConfiguration?.triggered
        case .refreshing:
            textConfiguration?.refreshing
        case .ending:
            textConfiguration?.ending
        case .noMoreData:
            textConfiguration?.noMoreData
        }
    }

    private func builtInText(for state: RefreshState) -> String {
        switch state {
        case .idle, .pulling:
            switch (role, edge) {
            case (.refresh, .top):
                "下拉刷新"
            case (.refresh, .bottom):
                "上拉刷新"
            case (.refresh, .leading), (.refresh, .trailing):
                "拖动刷新"
            case (.loadMore, .top):
                "下拉加载"
            case (.loadMore, .bottom):
                "上拉加载更多"
            case (.loadMore, .leading), (.loadMore, .trailing):
                "拖动加载"
            }
        case .triggered:
            role == .refresh ? "释放刷新" : "释放加载"
        case .refreshing:
            role == .refresh ? "正在刷新..." : "正在加载..."
        case .ending:
            role == .refresh ? "刷新完成" : "加载完成"
        case .noMoreData:
            role == .refresh ? "刷新完成" : "没有更多数据"
        }
    }

    private func builtInAccessibilityValue(for state: RefreshState) -> String {
        switch state {
        case .refreshing:
            role == .refresh ? "正在刷新" : "正在加载"
        default:
            builtInText(for: state)
        }
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

private final class DefaultRefreshControlNotificationObservation: @unchecked Sendable {
    private let center: NotificationCenter
    private let observer: NSObjectProtocol

    init(center: NotificationCenter, observer: NSObjectProtocol) {
        self.center = center
        self.observer = observer
    }

    deinit {
        center.removeObserver(observer)
    }
}
