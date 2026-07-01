import UIKit
import Refreshable

final class HorizontalEdgeDemoController: UIViewController, UICollectionViewDataSource {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let segmentedControl = UISegmentedControl(items: ["精选", "最近"])
    private var collectionView: UICollectionView!
    private var items: [HorizontalDemoItem] = []
    private var page = 0
    private var layoutDirection: HorizontalLayoutDirection = .leftToRight
    private var safeAreaMarginContainers: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "横向刷新"
        view.backgroundColor = .systemGroupedBackground

        configureNavigationItem()
        setupPageLayout()
        setupHeader()
        setupCollectionView()
        setupStatusSection()
        loadInitialData()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSafeAreaSectionMargins()
    }

    private func configureNavigationItem() {
        navigationItem.rightBarButtonItem = makeLayoutDirectionItem()
    }

    private func makeLayoutDirectionItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(
            title: nil,
            image: UIImage(systemName: "slider.horizontal.3"),
            primaryAction: nil,
            menu: makeLayoutDirectionMenu()
        )
        item.accessibilityLabel = "切换横向布局方向"
        return item
    }

    private func makeLayoutDirectionMenu() -> UIMenu {
        UIMenu(title: "布局方向", children: HorizontalLayoutDirection.allCases.map { direction in
            UIAction(
                title: direction.menuTitle,
                image: UIImage(systemName: direction.menuImageName),
                state: direction == layoutDirection ? .on : .off
            ) { [weak self] _ in
                self?.setLayoutDirection(direction)
            }
        })
    }

    private func setLayoutDirection(_ direction: HorizontalLayoutDirection) {
        guard direction != layoutDirection else { return }

        collectionView.removeRefreshable(edge: .leading)
        collectionView.removeLoadMoreable(edge: .trailing)

        layoutDirection = direction
        applyLayoutDirection()
        installEdgeControls()

        page = 0
        items = makeItems(start: currentContentStartIndex, count: max(items.count, 8))
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
        scrollToCurrentDirectionStartItem()
    }

    private func setupPageLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 22
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 0),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: 0),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func setupHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 16

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = "今日更新"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = "横向拖动刷新内容"
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)

        let directionBadge = PaddedLabel()
        directionBadge.text = "双向"
        directionBadge.font = .systemFont(ofSize: 13, weight: .semibold)
        directionBadge.textColor = .systemBlue
        directionBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.11)
        directionBadge.layer.cornerRadius = 8
        directionBadge.layer.masksToBounds = true
        directionBadge.contentInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        directionBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        topRow.addArrangedSubview(titleStack)
        topRow.addArrangedSubview(UIView())
        topRow.addArrangedSubview(directionBadge)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = .label
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        headerStack.addArrangedSubview(topRow)
        headerStack.addArrangedSubview(segmentedControl)
        contentStack.addArrangedSubview(makeSafeAreaMarginContainer(containing: headerStack))
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(HorizontalDemoCell.self, forCellWithReuseIdentifier: HorizontalDemoCell.reuseIdentifier)
        contentStack.addArrangedSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: 374),
        ])

        applyLayoutDirection()
        installEdgeControls()
    }

    private func setupStatusSection() {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.alignment = .fill
        sectionStack.spacing = 12

        let titleLabel = UILabel()
        titleLabel.text = "同步状态"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true

        let rowsStack = UIStackView()
        rowsStack.axis = .horizontal
        rowsStack.alignment = .fill
        rowsStack.distribution = .fillEqually
        rowsStack.spacing = 10

        [
            StatusMetric(title: "刚刚刷新", value: "完成", symbolName: "checkmark.circle.fill", color: .systemGreen),
            StatusMetric(title: "缓存 24 项", value: "可离线", symbolName: "tray.full.fill", color: .systemIndigo),
            StatusMetric(title: "网络良好", value: "低延迟", symbolName: "wifi", color: .systemBlue),
        ].forEach { metric in
            rowsStack.addArrangedSubview(StatusMetricView(metric: metric))
        }

        sectionStack.addArrangedSubview(titleLabel)
        sectionStack.addArrangedSubview(rowsStack)
        contentStack.addArrangedSubview(makeSafeAreaMarginContainer(containing: sectionStack))
    }

    private func makeSafeAreaMarginContainer(containing contentView: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)
        safeAreaMarginContainers.append(container)
        updateSafeAreaSectionMargins()

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: container.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func updateSafeAreaSectionMargins() {
        let baseInset: CGFloat = 20
        let margins = NSDirectionalEdgeInsets(
            top: 0,
            leading: baseInset + view.safeAreaInsets.left,
            bottom: 0,
            trailing: baseInset + view.safeAreaInsets.right
        )
        safeAreaMarginContainers.forEach { container in
            container.directionalLayoutMargins = margins
        }
    }

    @objc private func segmentChanged() {
        page = 0
        items = makeItems(start: currentContentStartIndex, count: 8)
        collectionView.reloadData()
        collectionView.resetNoMoreData(edge: .trailing)
        scrollToCurrentDirectionStartItem()
    }

    private func installEdgeControls() {
        collectionView.refreshable(edge: .leading) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.page = 0
                self.items = self.makeItems(start: self.currentContentStartIndex, count: 8)
                self.collectionView.reloadData()
                self.collectionView.resetNoMoreData(edge: .trailing)
            }
        }

        collectionView.loadMoreable(
            edge: .trailing,
            options: RefreshableOptions(allowsLoadMoreWhenContentFits: true)
        ) {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                self.page += 1
                guard self.page < 3 else {
                    self.collectionView.noMoreData(edge: .trailing)
                    return
                }

                let start = self.currentContentStartIndex + self.items.count
                self.items.append(contentsOf: self.makeItems(start: start, count: 4))
                self.collectionView.reloadData()
            }
        }
    }

    private func applyLayoutDirection() {
        collectionView?.semanticContentAttribute = layoutDirection.semanticContentAttribute
        navigationItem.rightBarButtonItem = makeLayoutDirectionItem()
    }

    private func scrollToCurrentDirectionStartItem() {
        guard !items.isEmpty else { return }

        collectionView.layoutIfNeeded()

        let itemIndex = layoutDirection.startItemIndex(itemCount: items.count)
        collectionView.scrollToItem(
            at: IndexPath(item: itemIndex, section: 0),
            at: .centeredHorizontally,
            animated: false
        )
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.82),
            heightDimension: .fractionalHeight(0.94)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 14
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)

        let layout = NonMirroringHorizontalLayout(section: section)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        layout.configuration = configuration
        return layout
    }

    private func loadInitialData() {
        items = makeItems(start: currentContentStartIndex, count: 8)
        collectionView.reloadData()
    }

    private var currentContentStartIndex: Int {
        segmentedControl.selectedSegmentIndex == 0 ? 1 : 9
    }

    private func makeItems(start: Int, count: Int) -> [HorizontalDemoItem] {
        let templates = HorizontalDemoItem.templates
        return (start..<start + count).map { index in
            let template = templates[(index - 1) % templates.count]
            let cycle = (index - 1) / templates.count
            return HorizontalDemoItem(
                eyebrow: template.eyebrow,
                title: cycle == 0 ? template.title : "\(template.title) \(cycle + 1)",
                summary: template.summary,
                metadata: template.metadata,
                status: template.status,
                symbolName: template.symbolName,
                tintColor: template.tintColor
            )
        }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HorizontalDemoCell.reuseIdentifier,
            for: indexPath
        ) as! HorizontalDemoCell
        cell.configure(with: items[indexPath.item])
        return cell
    }
}

private final class NonMirroringHorizontalLayout: UICollectionViewCompositionalLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        false
    }
}

private enum HorizontalLayoutDirection: CaseIterable {
    case leftToRight
    case rightToLeft

    var semanticContentAttribute: UISemanticContentAttribute {
        switch self {
        case .leftToRight:
            .forceLeftToRight
        case .rightToLeft:
            .forceRightToLeft
        }
    }

    var menuTitle: String {
        switch self {
        case .leftToRight:
            "从左向右"
        case .rightToLeft:
            "从右向左"
        }
    }

    var menuImageName: String {
        switch self {
        case .leftToRight:
            "arrow.right"
        case .rightToLeft:
            "arrow.left"
        }
    }

    func startItemIndex(itemCount: Int) -> Int {
        switch self {
        case .leftToRight:
            0
        case .rightToLeft:
            max(itemCount - 1, 0)
        }
    }
}

private struct HorizontalDemoItem {
    let eyebrow: String
    let title: String
    let summary: String
    let metadata: String
    let status: String
    let symbolName: String
    let tintColor: UIColor

    static let templates: [HorizontalDemoItem] = [
        HorizontalDemoItem(
            eyebrow: "工作流",
            title: "产品脉冲",
            summary: "需求、设计、版本节奏集中整理，适合横向快速浏览。",
            metadata: "更新于 09:30",
            status: "已同步",
            symbolName: "rectangle.stack.badge.plus",
            tintColor: .systemBlue
        ),
        HorizontalDemoItem(
            eyebrow: "数据",
            title: "增长指标",
            summary: "关键漏斗、留存变化和异常点按优先级合并展示。",
            metadata: "24 项数据",
            status: "稳定",
            symbolName: "chart.line.uptrend.xyaxis",
            tintColor: .systemTeal
        ),
        HorizontalDemoItem(
            eyebrow: "协作",
            title: "设计评审",
            summary: "最新稿件、待确认反馈和上线风险保持同屏可见。",
            metadata: "5 条待看",
            status: "进行中",
            symbolName: "person.2.wave.2.fill",
            tintColor: .systemIndigo
        ),
        HorizontalDemoItem(
            eyebrow: "发布",
            title: "版本节奏",
            summary: "灰度、监控、回滚预案在一个轻量看板中串联。",
            metadata: "今天 18:00",
            status: "待发布",
            symbolName: "paperplane.fill",
            tintColor: .systemOrange
        ),
        HorizontalDemoItem(
            eyebrow: "体验",
            title: "用户反馈",
            summary: "高频问题和正向评价自动归类，便于刷新后复盘。",
            metadata: "12 条新增",
            status: "可处理",
            symbolName: "bubble.left.and.text.bubble.right.fill",
            tintColor: .systemPink
        ),
        HorizontalDemoItem(
            eyebrow: "质量",
            title: "稳定性",
            summary: "崩溃、卡顿和网络错误按影响范围给出行动线索。",
            metadata: "99.98%",
            status: "健康",
            symbolName: "shield.lefthalf.filled",
            tintColor: .systemGreen
        ),
    ]
}

private struct StatusMetric {
    let title: String
    let value: String
    let symbolName: String
    let color: UIColor
}

private final class HorizontalDemoCell: UICollectionViewCell {
    static let reuseIdentifier = "HorizontalDemoCell"

    private let coverView = UIView()
    private let symbolBackgroundView = UIView()
    private let symbolImageView = UIImageView()
    private let eyebrowLabel = UILabel()
    private let statusLabel = PaddedLabel()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let metadataIconView = UIImageView()
    private let metadataLabel = UILabel()
    private let actionImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        semanticContentAttribute = .forceLeftToRight
        contentView.semanticContentAttribute = .forceLeftToRight
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1 / UIScreen.main.scale
        contentView.layer.borderColor = UIColor.separator.withAlphaComponent(0.24).cgColor

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        setupCover()
        setupLabels()
        setupMetadataRow()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        symbolImageView.image = nil
    }

    func configure(with item: HorizontalDemoItem) {
        coverView.backgroundColor = item.tintColor.withAlphaComponent(0.12)
        symbolBackgroundView.backgroundColor = item.tintColor.withAlphaComponent(0.14)
        symbolImageView.image = UIImage(systemName: item.symbolName)
        symbolImageView.tintColor = item.tintColor

        eyebrowLabel.text = item.eyebrow
        statusLabel.text = item.status
        statusLabel.textColor = item.tintColor
        statusLabel.backgroundColor = item.tintColor.withAlphaComponent(0.12)

        titleLabel.text = item.title
        summaryLabel.text = item.summary
        metadataLabel.text = item.metadata
        metadataIconView.tintColor = item.tintColor
        actionImageView.tintColor = item.tintColor
    }

    private func setupCover() {
        coverView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coverView)

        symbolBackgroundView.layer.cornerRadius = 8
        symbolBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(symbolBackgroundView)

        symbolImageView.contentMode = .scaleAspectFit
        symbolImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false
        symbolBackgroundView.addSubview(symbolImageView)

        eyebrowLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        eyebrowLabel.textColor = .secondaryLabel
        eyebrowLabel.adjustsFontForContentSizeCategory = true
        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(eyebrowLabel)

        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.contentInsets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(statusLabel)
    }

    private func setupLabels() {
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 3
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(summaryLabel)
    }

    private func setupMetadataRow() {
        metadataIconView.image = UIImage(systemName: "clock.fill")
        metadataIconView.contentMode = .scaleAspectFit
        metadataIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        metadataIconView.translatesAutoresizingMaskIntoConstraints = false

        metadataLabel.font = .systemFont(ofSize: 13, weight: .medium)
        metadataLabel.textColor = .secondaryLabel
        metadataLabel.adjustsFontSizeToFitWidth = true
        metadataLabel.minimumScaleFactor = 0.85
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false

        actionImageView.image = UIImage(systemName: "arrow.up.right")
        actionImageView.contentMode = .scaleAspectFit
        actionImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        actionImageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(metadataIconView)
        contentView.addSubview(metadataLabel)
        contentView.addSubview(actionImageView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalToConstant: 116),

            symbolBackgroundView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: 18),
            symbolBackgroundView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor, constant: -18),
            symbolBackgroundView.widthAnchor.constraint(equalToConstant: 48),
            symbolBackgroundView.heightAnchor.constraint(equalTo: symbolBackgroundView.widthAnchor),

            symbolImageView.centerXAnchor.constraint(equalTo: symbolBackgroundView.centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: symbolBackgroundView.centerYAnchor),
            symbolImageView.widthAnchor.constraint(equalToConstant: 26),
            symbolImageView.heightAnchor.constraint(equalTo: symbolImageView.widthAnchor),

            eyebrowLabel.leadingAnchor.constraint(equalTo: symbolBackgroundView.trailingAnchor, constant: 12),
            eyebrowLabel.centerYAnchor.constraint(equalTo: symbolBackgroundView.centerYAnchor),
            eyebrowLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -10),

            statusLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -18),

            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            metadataIconView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metadataIconView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            metadataIconView.widthAnchor.constraint(equalToConstant: 14),
            metadataIconView.heightAnchor.constraint(equalTo: metadataIconView.widthAnchor),

            metadataLabel.leadingAnchor.constraint(equalTo: metadataIconView.trailingAnchor, constant: 6),
            metadataLabel.centerYAnchor.constraint(equalTo: metadataIconView.centerYAnchor),
            metadataLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionImageView.leadingAnchor, constant: -12),

            actionImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            actionImageView.centerYAnchor.constraint(equalTo: metadataIconView.centerYAnchor),
            actionImageView.widthAnchor.constraint(equalToConstant: 18),
            actionImageView.heightAnchor.constraint(equalTo: actionImageView.widthAnchor),
        ])
    }
}

private final class StatusMetricView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(metric: StatusMetric) {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 8
        layer.masksToBounds = true
        layer.borderWidth = 1 / UIScreen.main.scale
        layer.borderColor = UIColor.separator.withAlphaComponent(0.24).cgColor

        iconView.image = UIImage(systemName: metric.symbolName)
        iconView.tintColor = metric.color
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        titleLabel.text = metric.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        valueLabel.text = metric.value
        valueLabel.font = .systemFont(ofSize: 15, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.8

        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let stack = UIStackView(arrangedSubviews: [iconView, textStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PaddedLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
