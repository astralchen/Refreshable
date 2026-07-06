import UIKit
import Refreshable

fileprivate struct GridUpdateItem {
    enum ChipStyle {
        case update
        case article
        case reminder
        case success
        case repair
        case feature
        case optimize
    }

    enum Status {
        case all
        case loading
        case complete
    }

    let title: String
    let source: String
    let time: String
    let chip: String
    let chipStyle: ChipStyle
    let symbolName: String
    let tintColor: UIColor
    let status: Status
}

fileprivate enum GridFilter: Int {
    case all
    case loading
    case complete

    var selectedIndex: Int { rawValue }

    func includes(_ item: GridUpdateItem) -> Bool {
        switch self {
        case .all:
            return true
        case .loading:
            return item.status == .loading
        case .complete:
            return item.status == .complete
        }
    }
}

final class CollectionViewDemoController: UIViewController, UICollectionViewDataSource {

    private var collectionView: UICollectionView!
    private var allItems: [GridUpdateItem] = []
    private var items: [GridUpdateItem] = []
    private var page = 0
    private var hasLoadedAllPages = false
    private var selectedFilter: GridFilter = .all
    private let totalCount = 36

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "刷新网格"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: nil,
            action: nil
        )
        view.backgroundColor = .systemGroupedBackground

        configureNavigationBar()
        setupCollectionView()
        loadInitialData()
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.shadowColor = .separator

        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInset.bottom = 116
        collectionView.verticalScrollIndicatorInsets.bottom = 116
        collectionView.register(GridUpdateCell.self, forCellWithReuseIdentifier: GridUpdateCell.reuseIdentifier)
        collectionView.register(
            GridHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: GridHeaderView.reuseIdentifier
        )
        collectionView.register(
            GridNoMoreDataFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: GridNoMoreDataFooterView.reuseIdentifier
        )
        view.addSubview(collectionView)

        collectionView.refreshable(
            style: SystemNativeRefreshStyle(
                extent: 52,
                lastUpdatedText: "刷新后重置加载状态"
            ),
            options: RefreshableOptions(
                triggerOffset: 72,
                animationDuration: 0.3,
                placement: RefreshablePlacement(contentSpacing: 0),
                presentation: .overlay(spacing: 12, locksContentOffset: true),
                overlayAnchor: .viewport
            )
        ) { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            await self?.performRefresh()
        }

        installBottomLoadMore()
    }

    private func installBottomLoadMore() {
        collectionView.loadMoreable(
            style: DefaultBottomLoadMoreStyle(
                texts: DefaultBottomLoadMoreTexts(
                    idle: "继续向上滑动",
                    pulling: "继续向上滑动",
                    triggered: "释放加载",
                    refreshing: "正在加载...",
                    ending: "加载完成",
                    noMoreData: "",
                    noMoreDataAccessibilityValue: ""
                )
            ),
            options: RefreshableOptions(
                animationDuration: 0.28,
                automaticTriggerOffset: 120,
                placement: RefreshablePlacement(contentSpacing: 0),
                presentation: .overlay(spacing: 0),
                overlayAnchor: .contentBoundary
            )
        ) { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            await self?.appendNextPage()
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, _ in
            self?.makeGridSection()
        }
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        layout.configuration = configuration
        return layout
    }

    private func makeGridSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .absolute(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(150)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 10, trailing: 18)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(214)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        var boundarySupplementaryItems = [header]
        if hasLoadedAllPages {
            let footerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(124)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            boundarySupplementaryItems.append(footer)
        }

        section.boundarySupplementaryItems = boundarySupplementaryItems
        return section
    }

    private func makeInitialItems() -> [GridUpdateItem] {
        [
            GridUpdateItem(
                title: "版本 2.1.0 发布",
                source: "刷新库",
                time: "10:34",
                chip: "更新",
                chipStyle: .update,
                symbolName: "paperplane.fill",
                tintColor: .systemPurple,
                status: .all
            ),
            GridUpdateItem(
                title: "关注：技术分享精选",
                source: "张三",
                time: "09:58",
                chip: "文章",
                chipStyle: .article,
                symbolName: "person.2.fill",
                tintColor: .systemTeal,
                status: .all
            ),
            GridUpdateItem(
                title: "系统通知",
                source: "系统",
                time: "09:12",
                chip: "提醒",
                chipStyle: .reminder,
                symbolName: "bell.fill",
                tintColor: .systemOrange,
                status: .all
            ),
            GridUpdateItem(
                title: "接口文档更新",
                source: "API 团队",
                time: "昨天 18:42",
                chip: "更新",
                chipStyle: .update,
                symbolName: "doc.text.fill",
                tintColor: .systemBlue,
                status: .loading
            ),
            GridUpdateItem(
                title: "构建任务完成",
                source: "CI 服务",
                time: "昨天 17:33",
                chip: "成功",
                chipStyle: .success,
                symbolName: "checkmark",
                tintColor: .systemGreen,
                status: .complete
            ),
            GridUpdateItem(
                title: "问题修复",
                source: "李四",
                time: "昨天 16:21",
                chip: "修复",
                chipStyle: .repair,
                symbolName: "chevron.left.forwardslash.chevron.right",
                tintColor: .systemPurple,
                status: .complete
            ),
            GridUpdateItem(
                title: "新功能：自定义刷新头",
                source: "产品团队",
                time: "昨天 15:07",
                chip: "新功能",
                chipStyle: .feature,
                symbolName: "star.fill",
                tintColor: .systemBlue,
                status: .all
            ),
            GridUpdateItem(
                title: "性能优化",
                source: "Engine 团队",
                time: "昨天 14:22",
                chip: "优化",
                chipStyle: .optimize,
                symbolName: "chart.bar.fill",
                tintColor: .systemTeal,
                status: .loading
            ),
        ]
    }

    private func makePageItems(page: Int) -> [GridUpdateItem] {
        let base = (page - 1) * 4
        var pageItems = [
            GridUpdateItem(
                title: "自动加载批次 \(base + 1)",
                source: "loadMoreable",
                time: "第 \(page) 页",
                chip: "加载",
                chipStyle: .update,
                symbolName: "arrow.down.circle.fill",
                tintColor: .systemBlue,
                status: .loading
            ),
            GridUpdateItem(
                title: "边缘触发记录 \(base + 2)",
                source: "automaticTriggerOffset",
                time: "120pt",
                chip: "触发",
                chipStyle: .article,
                symbolName: "scope",
                tintColor: .systemTeal,
                status: .loading
            ),
            GridUpdateItem(
                title: "分页合并完成 \(base + 3)",
                source: "UICollectionView",
                time: "刚刚",
                chip: "完成",
                chipStyle: .success,
                symbolName: "square.grid.2x2.fill",
                tintColor: .systemGreen,
                status: .complete
            ),
        ]

        pageItems.append(
            GridUpdateItem(
                title: "结束状态确认 \(base + 4)",
                source: "footer",
                time: "刚刚",
                chip: "完成",
                chipStyle: .success,
                symbolName: "checkmark.seal.fill",
                tintColor: .systemGreen,
                status: .complete
            )
        )
        return pageItems
    }

    private func loadInitialData() {
        allItems = makeInitialItems()
        applyCurrentFilter(animated: false)
    }

    private func selectFilter(at selectedIndex: Int) {
        guard let filter = GridFilter(rawValue: selectedIndex),
              filter != selectedFilter else { return }
        selectedFilter = filter
        applyCurrentFilter(animated: true)
    }

    private func applyCurrentFilter(animated: Bool) {
        items = allItems.filter { selectedFilter.includes($0) }
        let updates = {
            self.collectionView.reloadData()
        }

        if animated {
            UIView.transition(
                with: collectionView,
                duration: 0.18,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: updates
            )
        } else {
            updates()
        }
    }

    @MainActor
    private func performRefresh() {
        page = 0
        hasLoadedAllPages = false
        installBottomLoadMore()
        allItems = makeInitialItems()
        applyCurrentFilter(animated: false)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @MainActor
    private func appendNextPage() {
        guard !hasLoadedAllPages else { return }
        page += 1
        guard page <= 3 else {
            showNoMoreDataFooter()
            return
        }
        allItems.append(contentsOf: makePageItems(page: page))
        applyCurrentFilter(animated: false)
        if page == 3 {
            showNoMoreDataFooter()
        }
    }

    @MainActor
    private func showNoMoreDataFooter() {
        guard !hasLoadedAllPages else { return }
        hasLoadedAllPages = true
        collectionView.collectionViewLayout.invalidateLayout()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.hasLoadedAllPages else { return }
            self.collectionView.removeLoadMoreable()
        }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridUpdateCell.reuseIdentifier,
            for: indexPath
        ) as! GridUpdateCell
        cell.configure(with: items[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: GridHeaderView.reuseIdentifier,
                for: indexPath
            ) as! GridHeaderView
            header.configure(
                loadedText: "已加载 \(totalCount) 项",
                selectedIndex: selectedFilter.selectedIndex
            )
            header.onSelectedIndexChange = { [weak self] selectedIndex in
                self?.selectFilter(at: selectedIndex)
            }
            return header

        case UICollectionView.elementKindSectionFooter:
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: GridNoMoreDataFooterView.reuseIdentifier,
                for: indexPath
            ) as! GridNoMoreDataFooterView
            footer.configure(countText: "\(totalCount) 项已加载")
            return footer

        default:
            return UICollectionReusableView()
        }
    }
}

// MARK: - GridUpdateCell

private final class GridUpdateCell: UICollectionViewCell {
    static let reuseIdentifier = "GridUpdateCell"

    private let iconContainer = GridIconBadgeView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let chipView = StatusChipView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: GridUpdateItem) {
        iconContainer.configure(tintColor: item.tintColor)
        iconView.image = (
            UIImage(systemName: item.symbolName)
                ?? UIImage(systemName: "circle.fill")
        )?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .white
        titleLabel.text = item.title
        metaLabel.text = "\(item.source) · \(item.time)"
        chipView.configure(text: item.chip, style: item.chipStyle)
        accessibilityIdentifier = "GridUpdateCell.\(item.title)"
    }

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 1 / UIScreen.main.scale
        contentView.layer.borderColor = UIColor.separator.withAlphaComponent(0.45).cgColor
        contentView.clipsToBounds = true
        isAccessibilityElement = false
        contentView.isAccessibilityElement = false

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 21
        iconContainer.layer.masksToBounds = true
        contentView.addSubview(iconContainer)

        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.minimumScaleFactor = 0.9
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        metaLabel.font = .systemFont(ofSize: 13, weight: .regular)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 1
        metaLabel.adjustsFontSizeToFitWidth = true
        metaLabel.minimumScaleFactor = 0.88
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        chipView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chipView)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconContainer.widthAnchor.constraint(equalToConstant: 42),
            iconContainer.heightAnchor.constraint(equalTo: iconContainer.widthAnchor),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 9),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            chipView.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 6),
            chipView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            chipView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
        ])
    }
}

private final class GridIconBadgeView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    func configure(tintColor: UIColor) {
        backgroundColor = tintColor
        gradientLayer.colors = [
            tintColor.withAlphaComponent(0.92).cgColor,
            tintColor.cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0.15, y: 0.1)
        gradientLayer.endPoint = CGPoint(x: 0.9, y: 0.95)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
}

// MARK: - Supplementary Views

private final class GridHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "GridHeaderView"

    var onSelectedIndexChange: ((Int) -> Void)?

    private let titleLabel = UILabel()
    private let loadedLabel = UILabel()
    private let syncDot = UIView()
    private let syncLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["全部", "加载中", "完成"])

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(loadedText: String, selectedIndex: Int) {
        loadedLabel.text = loadedText
        segmentedControl.selectedSegmentIndex = selectedIndex
    }

    private func setupUI() {
        backgroundColor = .systemGroupedBackground

        titleLabel.text = "最近更新"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        loadedLabel.font = .systemFont(ofSize: 17)
        loadedLabel.textColor = .secondaryLabel
        loadedLabel.adjustsFontForContentSizeCategory = true
        loadedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadedLabel)

        syncDot.backgroundColor = .systemGreen
        syncDot.layer.cornerRadius = 4
        syncDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(syncDot)

        syncLabel.text = "刚刚同步"
        syncLabel.font = .systemFont(ofSize: 16)
        syncLabel.textColor = .secondaryLabel
        syncLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(syncLabel)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),

            loadedLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            loadedLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            syncLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            syncLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            syncDot.centerYAnchor.constraint(equalTo: syncLabel.centerYAnchor),
            syncDot.trailingAnchor.constraint(equalTo: syncLabel.leadingAnchor, constant: -8),
            syncDot.widthAnchor.constraint(equalToConstant: 8),
            syncDot.heightAnchor.constraint(equalToConstant: 8),

            segmentedControl.topAnchor.constraint(equalTo: loadedLabel.bottomAnchor, constant: 24),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            segmentedControl.heightAnchor.constraint(equalToConstant: 38),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    @objc private func segmentChanged() {
        onSelectedIndexChange?(segmentedControl.selectedSegmentIndex)
    }
}

private final class GridNoMoreDataFooterView: UICollectionReusableView {
    static let reuseIdentifier = "GridNoMoreDataFooterView"

    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(countText: String) {
        countLabel.text = countText
    }

    private func setupUI() {
        isAccessibilityElement = false
        accessibilityIdentifier = "GridNoMoreDataFooter"

        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 1 / UIScreen.main.scale
        cardView.layer.borderColor = UIColor.separator.withAlphaComponent(0.45).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        iconView.image = UIImage(systemName: "checkmark.circle", withConfiguration: symbolConfiguration)
        iconView.tintColor = .systemGreen
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconView)

        titleLabel.text = "没有更多数据"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        messageLabel.text = "下拉刷新后重新加载"
        messageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 1
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(messageLabel)

        countLabel.font = .systemFont(ofSize: 12, weight: .regular)
        countLabel.textColor = .tertiaryLabel
        countLabel.textAlignment = .center
        countLabel.numberOfLines = 1
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            iconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 22),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -24),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -24),

            countLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 24),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -24),
            countLabel.topAnchor.constraint(greaterThanOrEqualTo: messageLabel.bottomAnchor, constant: 8),
            countLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
        ])
    }
}

// MARK: - StatusChipView

private final class StatusChipView: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 12, weight: .semibold)
        textAlignment = .center
        layer.cornerRadius = 5
        clipsToBounds = true
        adjustsFontForContentSizeCategory = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 17, height: size.height + 7)
    }

    func configure(text: String, style: GridUpdateItem.ChipStyle) {
        self.text = text
        let colors = style.colors
        textColor = colors.foreground
        backgroundColor = colors.background
    }
}

private extension GridUpdateItem.ChipStyle {
    var colors: (foreground: UIColor, background: UIColor) {
        switch self {
        case .update, .feature:
            return (.systemBlue, UIColor.systemBlue.withAlphaComponent(0.12))
        case .article:
            return (.systemTeal, UIColor.systemTeal.withAlphaComponent(0.12))
        case .reminder:
            return (.systemOrange, UIColor.systemOrange.withAlphaComponent(0.12))
        case .success, .optimize:
            return (.systemGreen, UIColor.systemGreen.withAlphaComponent(0.12))
        case .repair:
            return (.systemPurple, UIColor.systemPurple.withAlphaComponent(0.12))
        }
    }
}
