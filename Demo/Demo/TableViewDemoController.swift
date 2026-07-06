import UIKit
import Refreshable

fileprivate struct UpdateItem {
    enum ChipStyle {
        case blue
        case teal
        case green
        case gray
        case purple
    }

    enum Category {
        case updates
        case following
        case system
    }

    let title: String
    let summary: String
    let source: String
    let time: String
    let chip: String
    let chipStyle: ChipStyle
    let symbolName: String
    let tintColor: UIColor
    let isUnread: Bool
    let category: Category
}

fileprivate enum UpdateFilter: Int {
    case all
    case following
    case system

    var selectedIndex: Int { rawValue }

    func includes(_ item: UpdateItem) -> Bool {
        switch self {
        case .all:
            return true
        case .following:
            return item.category == .following
        case .system:
            return item.category == .system
        }
    }
}

final class TableViewDemoController: UIViewController, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerView = UpdateListHeaderView()

    private var allItems: [UpdateItem] = []
    private var items: [UpdateItem] = []
    private var selectedFilter: UpdateFilter = .all
    private var page = 0
    private var refreshCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "列表刷新"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "演示",
            style: .plain,
            target: nil,
            action: nil
        )

        setupTableView()
        loadInitialData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizeTableHeaderIfNeeded()
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 104
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.register(UpdateItemCell.self, forCellReuseIdentifier: UpdateItemCell.reuseIdentifier)
        view.addSubview(tableView)

        installTableHeader()
        installRefreshControls()
    }

    private func installTableHeader() {
        headerView.configure(
            title: "今日更新",
            status: "刚刚同步 · 24 项缓存",
            selectedIndex: selectedFilter.selectedIndex
        )
        headerView.onSelectedIndexChange = { [weak self] selectedIndex in
            self?.selectFilter(at: selectedIndex)
        }
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 138)
        tableView.tableHeaderView = headerView
    }

    private func resizeTableHeaderIfNeeded() {
        guard let header = tableView.tableHeaderView else { return }

        let fittingSize = CGSize(
            width: tableView.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let height = header.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        if abs(header.frame.height - height) > 0.5 {
            header.frame.size.height = height
            tableView.tableHeaderView = header
        }
    }

    private func installRefreshControls() {
        let refreshOptions = RefreshableOptions(
            triggerOffset: 86,
            animationDuration: 0.32,
            placement: RefreshablePlacement(contentSpacing: 4)
        )

        tableView.refreshable(
            style: SystemNativeRefreshStyle(
                extent: 72,
                lastUpdatedText: "松手即可查看最新内容"
            ),
            options: refreshOptions
        ) { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            await self?.performRefresh()
        }

        let loadMoreOptions = RefreshableOptions(
            animationDuration: 0.28,
            automaticTriggerOffset: 120,
            placement: RefreshablePlacement(contentSpacing: 6)
        )

        tableView.loadMoreable(options: loadMoreOptions) { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            await self?.appendNextPage()
        }
    }

    private func loadInitialData() {
        allItems = makeInitialItems()
        applyCurrentFilter(animated: false, scrollToTop: false)
    }

    private func performRefresh() {
        page = 0
        var refreshed = makeInitialItems()
        refreshed.insert(makeRefreshedItem(), at: 0)
        allItems = refreshed
        headerView.configure(
            title: "今日更新",
            status: "刚刚同步 · 24 项缓存",
            selectedIndex: selectedFilter.selectedIndex
        )
        applyCurrentFilter(animated: false, scrollToTop: false)
        tableView.resetNoMoreData()
    }

    private func appendNextPage() {
        page += 1
        guard page <= 3 else {
            tableView.noMoreData()
            return
        }
        allItems.append(contentsOf: makePageItems(page: page))
        applyCurrentFilter(animated: false, scrollToTop: false)
    }

    private func selectFilter(at selectedIndex: Int) {
        guard let filter = UpdateFilter(rawValue: selectedIndex),
              filter != selectedFilter else { return }

        selectedFilter = filter
        applyCurrentFilter(animated: true, scrollToTop: true)
    }

    private func applyCurrentFilter(animated: Bool, scrollToTop: Bool) {
        items = allItems.filter { selectedFilter.includes($0) }

        let reload = {
            self.tableView.reloadData()
        }

        if animated {
            UIView.transition(
                with: tableView,
                duration: 0.18,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: reload
            )
        } else {
            reload()
        }

        if scrollToTop {
            let topOffset = CGPoint(x: 0, y: -tableView.adjustedContentInset.top)
            tableView.setContentOffset(topOffset, animated: true)
        }
    }

    private func makeInitialItems() -> [UpdateItem] {
        [
            UpdateItem(
                title: "版本 2.1.0 发布",
                summary: "新增下拉刷新动画效果，优化自动加载逻辑，修复列表边界问题。",
                source: "刷新库",
                time: "10:34",
                chip: "更新",
                chipStyle: .blue,
                symbolName: "paperplane.fill",
                tintColor: .systemPurple,
                isUnread: true,
                category: .updates
            ),
            UpdateItem(
                title: "关注：技术分享精选",
                summary: "iOS 列表性能优化实践：从数据源到渲染的全链路优化方案。",
                source: "张三",
                time: "09:58",
                chip: "文章",
                chipStyle: .teal,
                symbolName: "person.2.fill",
                tintColor: .systemTeal,
                isUnread: true,
                category: .following
            ),
            UpdateItem(
                title: "系统通知",
                summary: "你的缓存将在 7 天后过期，请及时清理以释放存储空间。",
                source: "系统",
                time: "09:12",
                chip: "提醒",
                chipStyle: .gray,
                symbolName: "bell.fill",
                tintColor: .systemOrange,
                isUnread: false,
                category: .system
            ),
            UpdateItem(
                title: "接口文档更新",
                summary: "刷新接口新增字段说明与示例代码，支持更多自定义配置。",
                source: "API 团队",
                time: "昨天 18:42",
                chip: "更新",
                chipStyle: .blue,
                symbolName: "doc.text.fill",
                tintColor: .systemBlue,
                isUnread: false,
                category: .updates
            ),
            UpdateItem(
                title: "构建任务完成",
                summary: "Refreshable iOS Demo 2.1.0 (45) 构建成功，可用于测试。",
                source: "CI 服务",
                time: "昨天 17:33",
                chip: "成功",
                chipStyle: .green,
                symbolName: "checkmark.circle.fill",
                tintColor: .systemGreen,
                isUnread: false,
                category: .system
            ),
            UpdateItem(
                title: "问题修复",
                summary: "修复快速连续下拉时刷新状态异常的问题，提升稳定性。",
                source: "李四",
                time: "昨天 16:21",
                chip: "修复",
                chipStyle: .purple,
                symbolName: "chevron.left.forwardslash.chevron.right",
                tintColor: .systemPurple,
                isUnread: false,
                category: .following
            ),
            UpdateItem(
                title: "新功能：自定义刷新头",
                summary: "支持开发者自定义刷新头视图与交互，灵活适配业务需求。",
                source: "产品团队",
                time: "昨天 15:07",
                chip: "新功能",
                chipStyle: .blue,
                symbolName: "star.fill",
                tintColor: .systemBlue,
                isUnread: false,
                category: .updates
            ),
        ]
    }

    private func makeRefreshedItem() -> UpdateItem {
        refreshCount += 1
        return UpdateItem(
            title: "刚刚刷新完成",
            summary: "已同步最新更新流，并重置底部自动加载状态。",
            source: "刷新库",
            time: "刚刚",
            chip: "刚刚",
            chipStyle: .green,
            symbolName: "arrow.clockwise.circle.fill",
            tintColor: .systemGreen,
            isUnread: true,
            category: .updates
        )
    }

    private func makePageItems(page: Int) -> [UpdateItem] {
        let base = page * 3
        return [
            UpdateItem(
                title: "分页记录 \(base + 1)",
                summary: "滚动到底部后自动加载的生产列表内容，用于验证自动触发距离。",
                source: "自动加载",
                time: "今天",
                chip: "分页",
                chipStyle: .blue,
                symbolName: "tray.and.arrow.down.fill",
                tintColor: .systemBlue,
                isUnread: false,
                category: .updates
            ),
            UpdateItem(
                title: "缓存同步 \(base + 2)",
                summary: "新增的分页数据保持与主列表一致的排版、图标和状态标签。",
                source: "同步队列",
                time: "今天",
                chip: "同步",
                chipStyle: .teal,
                symbolName: "externaldrive.connected.to.line.below.fill",
                tintColor: .systemTeal,
                isUnread: false,
                category: .system
            ),
            UpdateItem(
                title: "后台任务 \(base + 3)",
                summary: "确认加载更多、没有更多数据和下拉刷新重置逻辑可以共存。",
                source: "系统",
                time: "今天",
                chip: "任务",
                chipStyle: .gray,
                symbolName: "gearshape.2.fill",
                tintColor: .systemGray,
                isUnread: false,
                category: .system
            ),
        ]
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UpdateItemCell.reuseIdentifier,
            for: indexPath
        ) as! UpdateItemCell
        cell.configure(with: items[indexPath.row])
        return cell
    }
}

private final class UpdateListHeaderView: UIView {

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusDot = UIView()
    private let segmentedControl = UISegmentedControl(items: ["全部", "关注", "系统"])

    var onSelectedIndexChange: ((Int) -> Void)?
    var selectedIndex: Int { segmentedControl.selectedSegmentIndex }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, status: String, selectedIndex: Int) {
        titleLabel.text = title
        statusLabel.text = status
        segmentedControl.selectedSegmentIndex = selectedIndex
    }

    private func configureUI() {
        backgroundColor = .systemGroupedBackground

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textColor = .secondaryLabel
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        statusDot.backgroundColor = .systemGreen
        statusDot.layer.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(statusDot)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),

            statusDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            statusDot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.trailingAnchor.constraint(equalTo: statusDot.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),

            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            segmentedControl.heightAnchor.constraint(equalToConstant: 38),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
        ])
    }

    @objc private func segmentedControlChanged() {
        onSelectedIndexChange?(segmentedControl.selectedSegmentIndex)
    }
}

private final class StatusChipView: UILabel {

    private var horizontalPadding: CGFloat = 7
    private var verticalPadding: CGFloat = 1.5

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + horizontalPadding * 2,
            height: size.height + verticalPadding * 2
        )
    }

    func configure(text: String, style: UpdateItem.ChipStyle) {
        self.text = text
        font = .systemFont(ofSize: 11.5, weight: .semibold)
        textAlignment = .center
        layer.cornerRadius = 5
        layer.cornerCurve = .continuous
        clipsToBounds = true

        switch style {
        case .blue:
            textColor = .systemBlue
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        case .teal:
            textColor = .systemTeal
            backgroundColor = UIColor.systemTeal.withAlphaComponent(0.12)
        case .green:
            textColor = .systemGreen
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.14)
        case .gray:
            textColor = .secondaryLabel
            backgroundColor = UIColor.systemGray5
        case .purple:
            textColor = .systemPurple
            backgroundColor = UIColor.systemPurple.withAlphaComponent(0.12)
        }

        invalidateIntrinsicContentSize()
    }
}

private final class IconBadgeView: UIView {

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.cornerCurve = .continuous
        gradientLayer.startPoint = CGPoint(x: 0.18, y: 0.1)
        gradientLayer.endPoint = CGPoint(x: 0.86, y: 0.94)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func configure(tintColor: UIColor) {
        let resolvedColor = tintColor.resolvedColor(with: traitCollection)
        gradientLayer.colors = [
            resolvedColor.mixed(with: .white, amount: 0.16).cgColor,
            resolvedColor.mixed(with: .black, amount: 0.06).cgColor,
        ]
    }
}

private final class UpdateItemCell: UITableViewCell {

    static let reuseIdentifier = "UpdateItemCell"

    private let unreadDot = UIView()
    private let avatarView = IconBadgeView()
    private let avatarImageView = UIImageView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let metaLabel = UILabel()
    private let chipLabel = StatusChipView()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separatorView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: UpdateItem) {
        unreadDot.isHidden = !item.isUnread
        avatarView.configure(tintColor: item.tintColor)
        avatarImageView.image = UIImage(systemName: item.symbolName) ?? UIImage(systemName: "circle.fill")
        avatarImageView.tintColor = .white
        titleLabel.text = item.title
        summaryLabel.text = item.summary
        metaLabel.text = "\(item.source) · \(item.time)"
        chipLabel.configure(text: item.chip, style: item.chipStyle)
        accessibilityLabel = "\(item.title)，\(item.summary)，\(item.source)，\(item.time)，\(item.chip)"
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground

        unreadDot.backgroundColor = .systemBlue
        unreadDot.layer.cornerRadius = 4
        unreadDot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(unreadDot)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .semibold)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarImageView)

        titleLabel.font = .systemFont(ofSize: 16.5, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        summaryLabel.font = .systemFont(ofSize: 13.8)
        summaryLabel.textColor = .label
        summaryLabel.numberOfLines = 2
        summaryLabel.lineBreakMode = .byTruncatingTail

        metaLabel.font = .systemFont(ofSize: 12.5)
        metaLabel.textColor = .secondaryLabel
        metaLabel.setContentHuggingPriority(.required, for: .horizontal)
        metaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chipLabel.setContentHuggingPriority(.required, for: .horizontal)
        chipLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let metaSpacer = UIView()
        metaSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let metaRow = UIStackView(arrangedSubviews: [metaLabel, chipLabel, metaSpacer])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 10

        let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, metaRow])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        chevronView.tintColor = .tertiaryLabel
        chevronView.contentMode = .center
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chevronView)

        separatorView.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            unreadDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            unreadDot.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8),

            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 32),
            avatarImageView.heightAnchor.constraint(equalToConstant: 32),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            chevronView.widthAnchor.constraint(equalToConstant: 18),

            separatorView.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}

private extension UIColor {

    func mixed(with color: UIColor, amount: CGFloat) -> UIColor {
        let amount = max(0, min(1, amount))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              color.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &targetAlpha) else {
            return self
        }

        return UIColor(
            red: red + (targetRed - red) * amount,
            green: green + (targetGreen - green) * amount,
            blue: blue + (targetBlue - blue) * amount,
            alpha: alpha + (targetAlpha - alpha) * amount
        )
    }
}
