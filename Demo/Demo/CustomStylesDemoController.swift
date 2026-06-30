import UIKit
import Refreshable

final class CustomStylesDemoController: UIViewController, UITableViewDataSource {

    private enum StyleChoice: Int, CaseIterable {
        case system
        case taiji
        case kinetic

        var title: String {
            switch self {
            case .system: "系统"
            case .taiji: "太极"
            case .kinetic: "动感"
            }
        }
    }

    fileprivate struct FeedItem {
        let author: String
        let time: String
        let body: String
        let symbolName: String
        let avatarColor: UIColor
        let mediaColors: [UIColor]
        let likes: Int
        let comments: Int
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let segmentedControl = UISegmentedControl(items: StyleChoice.allCases.map(\.title))

    private var selectedStyle: StyleChoice = .kinetic
    private var refreshCount = 0
    private var page = 0
    private var items: [FeedItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "刷新样式"
        view.backgroundColor = .systemBackground

        configureNavigation()
        configureTableView()
        loadInitialData()
        installSelectedStyle()
    }

    private func configureNavigation() {
        segmentedControl.selectedSegmentIndex = selectedStyle.rawValue
        segmentedControl.addTarget(self, action: #selector(styleChanged), for: .valueChanged)
        segmentedControl.selectedSegmentTintColor = .white
        navigationItem.titleView = segmentedControl
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: nil,
            action: nil
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemTeal
    }

    private func configureTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 286
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.register(StyleFeedCell.self, forCellReuseIdentifier: StyleFeedCell.reuseIdentifier)
        view.addSubview(tableView)
    }

    private func loadInitialData() {
        items = [
            FeedItem(
                author: "海边的风",
                time: "2 小时前",
                body: "吹着海风，心情也变得自由了。",
                symbolName: "water.waves",
                avatarColor: .systemTeal,
                mediaColors: [
                    UIColor(red: 0.14, green: 0.62, blue: 0.95, alpha: 1),
                    UIColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 1),
                    UIColor(red: 0.05, green: 0.36, blue: 0.62, alpha: 1),
                ],
                likes: 128,
                comments: 36
            ),
            FeedItem(
                author: "晚安小熊",
                time: "3 小时前",
                body: "今天的咖啡拉花还不错。",
                symbolName: "cup.and.saucer.fill",
                avatarColor: .systemBrown,
                mediaColors: [
                    UIColor(red: 0.73, green: 0.46, blue: 0.20, alpha: 1),
                    UIColor(red: 0.94, green: 0.78, blue: 0.50, alpha: 1),
                    UIColor(red: 0.08, green: 0.62, blue: 0.58, alpha: 1),
                ],
                likes: 96,
                comments: 18
            ),
            FeedItem(
                author: "山野行记",
                time: "5 小时前",
                body: "徒步是一种与自己对话的方式。",
                symbolName: "mountain.2.fill",
                avatarColor: .systemGreen,
                mediaColors: [
                    UIColor(red: 0.28, green: 0.56, blue: 0.30, alpha: 1),
                    UIColor(red: 0.70, green: 0.86, blue: 0.62, alpha: 1),
                    UIColor(red: 0.18, green: 0.34, blue: 0.18, alpha: 1),
                ],
                likes: 84,
                comments: 12
            ),
        ]
        tableView.reloadData()
    }

    private func installSelectedStyle() {
        tableView.removeRefreshable()
        tableView.removeLoadMoreable()

        let options = RefreshableOptions(
            triggerOffset: triggerOffset,
            animationDuration: 0.32
        )

        switch selectedStyle {
        case .system:
            tableView.refreshable(style: SystemNativeRefreshStyle(), options: options) { [weak self] in
                await self?.performRefresh()
            }

        case .taiji:
            tableView.refreshable(
                style: TaijiRefreshStyle(theme: traitCollection.userInterfaceStyle == .dark ? .dark : .system),
                options: options
            ) { [weak self] in
                await self?.performRefresh()
            }

        case .kinetic:
            tableView.refreshable(style: KineticRefreshStyle(), options: options) { [weak self] in
                await self?.performRefresh()
            }
        }

        tableView.loadMoreable {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                self.appendMoreRows()
            }
        }
    }

    private var triggerOffset: CGFloat {
        switch selectedStyle {
        case .system: 64
        case .taiji: 92
        case .kinetic: 112
        }
    }

    private func performRefresh() async {
        try? await Task.sleep(nanoseconds: 900_000_000)
        await MainActor.run {
            refreshCount += 1
            page = 0
            let item = FeedItem(
                author: "刷新完成 #\(refreshCount)",
                time: "刚刚",
                body: "\(selectedStyle.title)样式刚完成一次真实下拉刷新。",
                symbolName: "checkmark.circle.fill",
                avatarColor: .systemGreen,
                mediaColors: [
                    UIColor(red: 0.14, green: 0.76, blue: 0.42, alpha: 1),
                    UIColor(red: 0.72, green: 0.96, blue: 0.78, alpha: 1),
                    UIColor(red: 0.10, green: 0.52, blue: 0.30, alpha: 1),
                ],
                likes: 20 + refreshCount,
                comments: 6
            )
            items.insert(item, at: 0)
            tableView.reloadData()
            tableView.resetNoMoreData()
        }
    }

    private func appendMoreRows() {
        page += 1
        guard page <= 2 else {
            tableView.noMoreData()
            return
        }

        let startIndex = items.count + 1
        let newRows = (startIndex..<startIndex + 3).map { index in
            FeedItem(
                author: "灵感片段 \(index)",
                time: "今天",
                body: "用于确认刷新控件和加载更多可以共存在同一个列表里。",
                symbolName: index.isMultiple(of: 2) ? "sparkles" : "paperplane.fill",
                avatarColor: index.isMultiple(of: 2) ? .systemPurple : .systemOrange,
                mediaColors: index.isMultiple(of: 2)
                    ? [.systemPurple, .systemPink, .systemIndigo]
                    : [.systemOrange, .systemYellow, .systemRed],
                likes: 40 + index,
                comments: 8 + index
            )
        }
        items.append(contentsOf: newRows)
        tableView.reloadData()
    }

    @objc private func styleChanged() {
        guard let choice = StyleChoice(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        selectedStyle = choice
        page = 0
        installSelectedStyle()
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: StyleFeedCell.reuseIdentifier,
            for: indexPath
        ) as! StyleFeedCell
        cell.configure(with: items[indexPath.row])
        return cell
    }
}

private final class StyleFeedCell: UITableViewCell {

    static let reuseIdentifier = "StyleFeedCell"

    private let avatarView = UIView()
    private let avatarImageView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let bodyLabel = UILabel()
    private let mediaView = GradientMediaView()
    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let bookmarkButton = UIButton(type: .system)
    private let separatorView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: CustomStylesDemoController.FeedItem) {
        titleLabel.text = item.author
        timeLabel.text = item.time
        bodyLabel.text = item.body
        avatarView.backgroundColor = item.avatarColor.withAlphaComponent(0.18)
        avatarImageView.image = UIImage(systemName: item.symbolName)
        avatarImageView.tintColor = item.avatarColor
        mediaView.colors = item.mediaColors
        likeButton.setTitle(" \(item.likes)", for: .normal)
        commentButton.setTitle(" \(item.comments)", for: .normal)
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground

        avatarView.layer.cornerRadius = 22
        avatarView.layer.cornerCurve = .continuous
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        avatarImageView.contentMode = .center
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarImageView)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        timeLabel.font = .systemFont(ofSize: 14, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = .label
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bodyLabel)

        mediaView.layer.cornerRadius = 12
        mediaView.layer.cornerCurve = .continuous
        mediaView.clipsToBounds = true
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mediaView)

        [likeButton, commentButton, shareButton, bookmarkButton].forEach { button in
            button.tintColor = .secondaryLabel
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button)
        }

        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        commentButton.setImage(UIImage(systemName: "bubble.left"), for: .normal)
        shareButton.setImage(UIImage(systemName: "arrowshape.turn.up.right"), for: .normal)
        shareButton.setTitle(" 分享", for: .normal)
        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)

        separatorView.backgroundColor = .separator.withAlphaComponent(0.55)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 1),

            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            bodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bodyLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 18),

            mediaView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mediaView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mediaView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 14),
            mediaView.heightAnchor.constraint(equalToConstant: 162),

            likeButton.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor, constant: 10),
            likeButton.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 14),

            commentButton.leadingAnchor.constraint(equalTo: likeButton.trailingAnchor, constant: 32),
            commentButton.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),

            shareButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shareButton.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),

            bookmarkButton.trailingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: -10),
            bookmarkButton.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),

            separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.topAnchor.constraint(equalTo: likeButton.bottomAnchor, constant: 16),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

private final class GradientMediaView: UIView {

    var colors: [UIColor] = [.systemTeal, .systemBlue] {
        didSet {
            updateGradient()
        }
    }

    private let gradientLayer = CAGradientLayer()
    private let symbolView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func setup() {
        layer.addSublayer(gradientLayer)
        symbolView.image = UIImage(systemName: "photo")
        symbolView.tintColor = UIColor.white.withAlphaComponent(0.72)
        symbolView.contentMode = .center
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolView)

        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateGradient()
    }

    private func updateGradient() {
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
    }
}
