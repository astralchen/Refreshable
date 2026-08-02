import UIKit
import Refreshable

@MainActor
final class DefaultRefreshControlPreviewController: UIViewController {

    private static let componentAnimationDuration: TimeInterval = 0.25

    private enum PreviewRole: Int {
        case refresh
        case loadMore
    }

    private let edgeSelector = UISegmentedControl(items: ["上", "下", "左", "右"])
    private let roleSelector = UISegmentedControl(items: ["刷新", "加载更多"])
    private let textSwitch = UISwitch()
    private let triggerButton = UIButton(type: .system)
    private let noMoreDataButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let canvas = UIScrollView()
    private let canvasContent = BoundaryGridCanvasView()
    private lazy var canvasContentWidthConstraint = canvasContent.widthAnchor.constraint(
        equalToConstant: 900
    )
    private lazy var canvasContentHeightConstraint = canvasContent.heightAnchor.constraint(
        equalToConstant: 900
    )

    private var selectedState: RefreshState = .idle
    private var needsBoundaryPosition = true
    private var boundaryPositionGeneration = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "默认刷新控件"
        view.backgroundColor = .systemGroupedBackground
        view.semanticContentAttribute = .forceLeftToRight

        configureControls()
        configureCanvas()
        installSelectedComponent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCanvasContentGeometry()
        positionCanvasAtSelectedBoundaryIfNeeded()
    }

    private var selectedEdge: RefreshableEdge {
        switch edgeSelector.selectedSegmentIndex {
        case 1:
            .bottom
        case 2:
            .leading
        case 3:
            .trailing
        default:
            .top
        }
    }

    private var selectedRole: PreviewRole {
        PreviewRole(rawValue: roleSelector.selectedSegmentIndex) ?? .refresh
    }

    private func configureControls() {
        edgeSelector.selectedSegmentIndex = 0
        edgeSelector.accessibilityIdentifier = "DefaultRefreshPreview.EdgeSelector"
        edgeSelector.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        roleSelector.selectedSegmentIndex = 0
        roleSelector.accessibilityIdentifier = "DefaultRefreshPreview.RoleSelector"
        roleSelector.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        textSwitch.isOn = false
        textSwitch.accessibilityIdentifier = "DefaultRefreshPreview.TextSwitch"
        textSwitch.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        configure(
            triggerButton,
            title: "手动触发",
            identifier: "DefaultRefreshPreview.Trigger",
            action: #selector(triggerSelectedComponent)
        )
        configure(
            noMoreDataButton,
            title: "没有更多数据",
            identifier: "DefaultRefreshPreview.NoMoreData",
            action: #selector(markNoMoreData)
        )
        configure(
            resetButton,
            title: "重置",
            identifier: "DefaultRefreshPreview.Reset",
            action: #selector(resetNoMoreData)
        )

        statusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 1
        statusLabel.accessibilityIdentifier = "DefaultRefreshPreview.Status"

        let textTitle = UILabel()
        textTitle.text = "显示文案"
        textTitle.font = UIFont.preferredFont(forTextStyle: .body)
        textTitle.adjustsFontForContentSizeCategory = true

        let textRow = UIStackView(arrangedSubviews: [textTitle, textSwitch, triggerButton])
        textRow.axis = .horizontal
        textRow.alignment = .center
        textRow.spacing = 12
        textTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let loadMoreRow = UIStackView(arrangedSubviews: [noMoreDataButton, resetButton])
        loadMoreRow.axis = .horizontal
        loadMoreRow.alignment = .fill
        loadMoreRow.distribution = .fillEqually
        loadMoreRow.spacing = 12

        let controls = UIStackView(arrangedSubviews: [
            edgeSelector,
            roleSelector,
            textRow,
            loadMoreRow,
            statusLabel,
        ])
        controls.axis = .vertical
        controls.spacing = 10
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            controls.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    private func configureCanvas() {
        canvas.accessibilityIdentifier = "DefaultRefreshPreview.Canvas"
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = true
        canvas.isDirectionalLockEnabled = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.backgroundColor = .secondarySystemGroupedBackground
        canvas.layer.cornerRadius = 16
        canvas.layer.cornerCurve = .continuous
        canvas.layer.borderColor = UIColor.separator.cgColor
        canvas.layer.borderWidth = 1
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        canvasContent.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(canvasContent)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            canvas.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            canvas.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            canvas.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            canvasContent.leadingAnchor.constraint(equalTo: canvas.contentLayoutGuide.leadingAnchor),
            canvasContent.trailingAnchor.constraint(equalTo: canvas.contentLayoutGuide.trailingAnchor),
            canvasContent.topAnchor.constraint(equalTo: canvas.contentLayoutGuide.topAnchor),
            canvasContent.bottomAnchor.constraint(equalTo: canvas.contentLayoutGuide.bottomAnchor),
            canvasContentWidthConstraint,
            canvasContentHeightConstraint,
        ])
    }

    private func updateCanvasContentGeometry() {
        let minimumLength: CGFloat = 900
        let viewportOverflow: CGFloat = 240
        canvasContentWidthConstraint.constant = max(
            minimumLength,
            canvas.bounds.width + viewportOverflow
        )
        canvasContentHeightConstraint.constant = max(
            minimumLength,
            canvas.bounds.height + viewportOverflow
        )
        canvas.layoutIfNeeded()

        canvas.accessibilityValue = [
            "contentWidth=\(Int(canvas.contentSize.width.rounded()))",
            "contentHeight=\(Int(canvas.contentSize.height.rounded()))",
        ].joined(separator: ";")
    }

    private func configure(
        _ button: UIButton,
        title: String,
        identifier: String,
        action: Selector
    ) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func selectionChanged() {
        installSelectedComponent()
    }

    private func installSelectedComponent() {
        boundaryPositionGeneration += 1
        for edge in RefreshableEdge.allCases {
            canvas.removeRefreshable(edge: edge)
            canvas.removeLoadMore(edge: edge)
        }

        selectedState = .idle
        let options = RefreshableOptions(
            animationDuration: Self.componentAnimationDuration,
            allowsLoadMoreWhenContentFits: true,
            automaticTriggerDistance: nil,
            textConfiguration: textSwitch.isOn ? RefreshableTextConfiguration() : nil,
            onStateChange: { [weak self] state in
                self?.selectedState = state
                self?.updateStatus()
            }
        )
        let actionDuration = previewActionDurationNanoseconds

        switch selectedRole {
        case .refresh:
            canvas.refreshable(edge: selectedEdge, options: options) {
                try? await Task.sleep(nanoseconds: actionDuration)
            }
        case .loadMore:
            canvas.onLoadMore(edge: selectedEdge, options: options) {
                try? await Task.sleep(nanoseconds: actionDuration)
            }
        }

        noMoreDataButton.isEnabled = selectedRole == .loadMore
        resetButton.isEnabled = selectedRole == .loadMore
        updateStatus()

        needsBoundaryPosition = true
        view.setNeedsLayout()
    }

    private var previewActionDurationNanoseconds: UInt64 {
        let environmentValue = ProcessInfo.processInfo.environment[
            "DefaultRefreshPreview.UITestActionDuration"
        ]
        let seconds = environmentValue.flatMap(Double.init) ?? 1.2
        return UInt64(max(seconds, 0) * 1_000_000_000)
    }

    private func updateStatus() {
        statusLabel.text = "\(edgeTitle) · \(roleTitle) · \(stateTitle)"
        statusLabel.accessibilityValue = visibleDefaultIndicatorText
    }

    private var visibleDefaultIndicatorText: String? {
        guard let indicator = firstDescendant(
            in: canvas,
            matching: { $0.accessibilityIdentifier == "Refreshable.DefaultIndicator" }
        ), indicator.alpha > 0.01,
           indicator.convert(indicator.bounds, to: canvas).intersects(canvas.bounds) else {
            return nil
        }

        let label = firstDescendant(in: indicator) { view in
            guard let label = view as? UILabel else { return false }
            return !label.isHidden
                && label.alpha > 0.01
                && !(label.text ?? "").isEmpty
        } as? UILabel
        return label?.text
    }

    private func firstDescendant(
        in view: UIView,
        matching predicate: (UIView) -> Bool
    ) -> UIView? {
        if predicate(view) {
            return view
        }

        for subview in view.subviews {
            if let match = firstDescendant(in: subview, matching: predicate) {
                return match
            }
        }
        return nil
    }

    private var edgeTitle: String {
        switch selectedEdge {
        case .top:
            "上"
        case .bottom:
            "下"
        case .leading:
            "左"
        case .trailing:
            "右"
        }
    }

    private var roleTitle: String {
        selectedRole == .refresh ? "刷新" : "加载更多"
    }

    private var stateTitle: String {
        switch selectedState {
        case .idle:
            "空闲"
        case .pulling:
            "拖动中"
        case .triggered:
            "可释放"
        case .active:
            "刷新中"
        case .ending:
            "收起中"
        case .noMoreData:
            "没有更多数据"
        }
    }

    @objc private func triggerSelectedComponent() {
        switch selectedRole {
        case .refresh:
            canvas.beginRefreshing(edge: selectedEdge)
        case .loadMore:
            canvas.beginLoadingMore(edge: selectedEdge)
        }
        updateStatus()
    }

    @objc private func markNoMoreData() {
        guard selectedRole == .loadMore else { return }
        canvas.markNoMoreData(edge: selectedEdge)
        repositionCanvasAtSelectedBoundary(expectedState: .noMoreData)
    }

    @objc private func resetNoMoreData() {
        guard selectedRole == .loadMore else { return }
        canvas.resetNoMoreData(edge: selectedEdge)
        repositionCanvasAtSelectedBoundary(expectedState: .idle)
    }

    private func repositionCanvasAtSelectedBoundary(expectedState: RefreshState) {
        boundaryPositionGeneration += 1
        let generation = boundaryPositionGeneration
        let edge = selectedEdge
        let role = selectedRole

        needsBoundaryPosition = true
        positionCanvasAtSelectedBoundaryIfNeeded()
        updateStatus()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.componentAnimationDuration) {
            [weak self] in
            guard let self,
                  self.boundaryPositionGeneration == generation,
                  self.selectedEdge == edge,
                  self.selectedRole == role,
                  self.selectedState == expectedState else {
                return
            }

            self.view.layoutIfNeeded()
            self.needsBoundaryPosition = true
            self.positionCanvasAtSelectedBoundaryIfNeeded()
            self.updateStatus()
        }
    }

    private func positionCanvasAtSelectedBoundaryIfNeeded() {
        guard needsBoundaryPosition, canvas.bounds.width > 0, canvas.bounds.height > 0 else {
            return
        }
        needsBoundaryPosition = false

        let insets = canvas.adjustedContentInset
        let minimumX = -insets.left
        let minimumY = -insets.top
        let maximumX = max(minimumX, canvas.contentSize.width - canvas.bounds.width + insets.right)
        let maximumY = max(minimumY, canvas.contentSize.height - canvas.bounds.height + insets.bottom)

        var offset = canvas.contentOffset
        offset.x = min(max(offset.x, minimumX), maximumX)
        offset.y = min(max(offset.y, minimumY), maximumY)

        switch selectedEdge {
        case .top:
            offset.y = minimumY
        case .bottom:
            offset.y = maximumY
        case .leading:
            offset.x = minimumX
        case .trailing:
            offset.x = maximumX
        }

        canvas.setContentOffset(offset, animated: false)
    }
}

private final class BoundaryGridCanvasView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        backgroundColor = .systemBackground
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        UIColor.systemIndigo.withAlphaComponent(0.10).setFill()
        UIRectFill(bounds)

        let cardSize = CGSize(width: 128, height: 104)
        let spacing = CGSize(width: 32, height: 32)
        let origin = CGPoint(x: 44, y: 56)
        let columnCount = max(
            Int(ceil((bounds.width - origin.x) / (cardSize.width + spacing.width))),
            1
        )
        let rowCount = max(
            Int(ceil((bounds.height - origin.y) / (cardSize.height + spacing.height))),
            1
        )

        for row in 0..<rowCount {
            for column in 0..<columnCount {
                let cardRect = CGRect(
                    x: origin.x + CGFloat(column) * (cardSize.width + spacing.width),
                    y: origin.y + CGFloat(row) * (cardSize.height + spacing.height),
                    width: cardSize.width,
                    height: cardSize.height
                )
                let color: UIColor = (row + column).isMultiple(of: 2) ? .systemTeal : .systemIndigo
                color.withAlphaComponent(0.18).setFill()
                UIBezierPath(roundedRect: cardRect, cornerRadius: 16).fill()

                color.withAlphaComponent(0.75).setStroke()
                let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 16)
                border.lineWidth = 2
                border.stroke()
            }
        }

        UIColor.systemIndigo.setStroke()
        let boundary = UIBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), cornerRadius: 20)
        boundary.lineWidth = 6
        boundary.stroke()

        drawBoundaryTitle("顶部边界", at: CGPoint(x: bounds.midX, y: 18))
        drawBoundaryTitle("底部边界", at: CGPoint(x: bounds.midX, y: bounds.maxY - 38))
        drawBoundaryTitle("左侧边界", at: CGPoint(x: 20, y: bounds.midY))
        drawBoundaryTitle("右侧边界", at: CGPoint(x: bounds.maxX - 100, y: bounds.midY))
    }

    private func drawBoundaryTitle(_ title: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.systemIndigo,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: CGPoint(x: point.x - size.width / 2, y: point.y),
            withAttributes: attributes
        )
    }
}
