import UIKit
import Refreshable

final class TaijiRefreshDemoController: UIViewController, UITableViewDataSource {

    private let backgroundView = TaijiDemoBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let themeControl = UISegmentedControl(items: TaijiDemoTheme.allCases.map(\.title))
    private let taijiStyle = TaijiRefreshStyle(extent: 88, theme: .system, accessibilityLabel: "太极刷新")

    private var selectedTheme: TaijiDemoTheme = .system
    private var items: [TaijiDemoItem] = []
    private var refreshSerial = 0
    private var didStartUITestRefresh = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "太极刷新"

        if ProcessInfo.processInfo.arguments.contains("-taiji-ui-screenshots") {
            selectedTheme = .nebula
        }

        configureThemeControl()
        configureTableView()
        loadInitialData()
        applyTheme(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        beginRefreshingForUITestIfNeeded()
    }

    private func configureThemeControl() {
        themeControl.accessibilityIdentifier = "taiji.themeControl"
        themeControl.selectedSegmentIndex = selectedTheme.rawValue
        themeControl.addTarget(self, action: #selector(themeChanged(_:)), for: .valueChanged)
        themeControl.translatesAutoresizingMaskIntoConstraints = false
        themeControl.widthAnchor.constraint(equalToConstant: 218).isActive = true
        navigationItem.titleView = themeControl
    }

    private func configureTableView() {
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.accessibilityIdentifier = "taiji.tableView"
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.rowHeight = 84
        tableView.separatorStyle = .none
        tableView.indicatorStyle = .white
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 18, right: 0)
        tableView.register(TaijiDemoCell.self, forCellReuseIdentifier: TaijiDemoCell.reuseIdentifier)
        view.addSubview(tableView)

        tableView.refreshable(
            style: taijiStyle,
            options: RefreshableOptions(triggerOffset: 88, animationDuration: 0.24)
        ) {
            try? await Task.sleep(nanoseconds: Self.refreshDelayNanoseconds)
            await MainActor.run {
                self.refreshSerial += 1
                self.items = self.makeItems(seed: self.refreshSerial)
                self.tableView.reloadData()
            }
        }
        taijiStyle.view.accessibilityIdentifier = "taiji.refreshControl"
    }

    private func beginRefreshingForUITestIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-taiji-auto-refresh") else { return }
        guard !didStartUITestRefresh else { return }
        didStartUITestRefresh = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            self.tableView.contentInset.top = Self.uiTestRefreshTopInset
            self.tableView.beginRefreshing()
        }
    }

    private static var refreshDelayNanoseconds: UInt64 {
        ProcessInfo.processInfo.arguments.contains("-taiji-auto-refresh")
            ? 6_000_000_000
            : 1_180_000_000
    }

    private static let uiTestRefreshTopInset: CGFloat = 260

    private func loadInitialData() {
        items = makeItems(seed: 0)
        tableView.reloadData()
    }

    private func applyTheme(animated: Bool) {
        overrideUserInterfaceStyle = selectedTheme.interfaceStyle
        taijiStyle.setTheme(selectedTheme.refreshTheme, animated: animated)
        backgroundView.apply(theme: selectedTheme)
        tableView.indicatorStyle = selectedTheme.indicatorStyle
        navigationController?.navigationBar.tintColor = selectedTheme.accentColor

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedTheme.segmentSelectedTextColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedTheme.segmentNormalTextColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
        ]
        themeControl.selectedSegmentTintColor = selectedTheme.segmentTintColor
        themeControl.setTitleTextAttributes(selectedAttributes, for: .selected)
        themeControl.setTitleTextAttributes(normalAttributes, for: .normal)

        tableView.reloadData()
    }

    @objc private func themeChanged(_ sender: UISegmentedControl) {
        guard let theme = TaijiDemoTheme(rawValue: sender.selectedSegmentIndex) else { return }
        selectedTheme = theme
        applyTheme(animated: true)
    }

    private func makeItems(seed: Int) -> [TaijiDemoItem] {
        let titles: [String] = [
            "星轨校准", "玻璃层折射", "紫气流场", "深空回声",
            "月白光晕", "引力纹理", "暗核呼吸", "青蓝粒子",
        ]
        let subtitles: [String] = [
            "刷新后重组列表节奏",
            "下拉时观察太极体积感",
            "主题切换会保留当前状态",
            "结束态只释放一圈涟漪",
        ]
        let colors = selectedTheme.itemColors

        return (0..<24).map { index in
            let shiftedIndex = index + seed
            let title = titles[shiftedIndex % titles.count]
            let subtitle = subtitles[shiftedIndex % subtitles.count]
            let accentColor = colors[shiftedIndex % colors.count]
            let badge = String(format: "%02d", index + 1)

            return TaijiDemoItem(
                title: title,
                subtitle: subtitle,
                accentColor: accentColor,
                badge: badge
            )
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TaijiDemoCell.reuseIdentifier,
            for: indexPath
        ) as! TaijiDemoCell
        cell.configure(with: items[indexPath.row], theme: selectedTheme)
        return cell
    }
}

private struct TaijiDemoItem {
    var title: String
    var subtitle: String
    var accentColor: UIColor
    var badge: String
}

private enum TaijiDemoTheme: Int, CaseIterable {
    case system
    case light
    case dark
    case nebula

    var title: String {
        switch self {
        case .system: "系统"
        case .light: "日"
        case .dark: "夜"
        case .nebula: "紫"
        }
    }

    var refreshTheme: TaijiRefreshTheme {
        switch self {
        case .system:
            .system
        case .light:
            .light
        case .dark:
            .dark
        case .nebula:
            .custom(Self.nebulaPalette)
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            .light
        case .dark, .nebula:
            .dark
        case .system:
            .unspecified
        }
    }

    var indicatorStyle: UIScrollView.IndicatorStyle {
        switch self {
        case .light:
            .black
        case .system, .dark, .nebula:
            .white
        }
    }

    var backgroundColors: [UIColor] {
        switch self {
        case .system:
            [
                UIColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1),
                UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1),
                UIColor(red: 0.03, green: 0.03, blue: 0.08, alpha: 1),
            ]
        case .light:
            [
                UIColor(red: 0.88, green: 0.94, blue: 1.00, alpha: 1),
                UIColor(red: 0.95, green: 0.91, blue: 1.00, alpha: 1),
                UIColor(red: 0.78, green: 0.88, blue: 0.98, alpha: 1),
            ]
        case .dark:
            [
                UIColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 1),
                UIColor(red: 0.05, green: 0.06, blue: 0.18, alpha: 1),
                UIColor(red: 0.00, green: 0.01, blue: 0.04, alpha: 1),
            ]
        case .nebula:
            [
                UIColor(red: 0.03, green: 0.02, blue: 0.11, alpha: 1),
                UIColor(red: 0.10, green: 0.05, blue: 0.23, alpha: 1),
                UIColor(red: 0.02, green: 0.04, blue: 0.12, alpha: 1),
            ]
        }
    }

    var accentColor: UIColor {
        switch self {
        case .system:
            UIColor(red: 0.40, green: 0.80, blue: 1.00, alpha: 1)
        case .light:
            UIColor(red: 0.08, green: 0.48, blue: 0.94, alpha: 1)
        case .dark:
            UIColor(red: 0.36, green: 0.78, blue: 1.00, alpha: 1)
        case .nebula:
            UIColor(red: 0.74, green: 0.42, blue: 1.00, alpha: 1)
        }
    }

    var itemColors: [UIColor] {
        [
            accentColor,
            UIColor(red: 0.44, green: 0.92, blue: 0.90, alpha: 1),
            UIColor(red: 0.88, green: 0.54, blue: 1.00, alpha: 1),
            UIColor(red: 1.00, green: 0.72, blue: 0.46, alpha: 1),
        ]
    }

    var cellFillColor: UIColor {
        switch self {
        case .light:
            UIColor.white.withAlphaComponent(0.58)
        case .system, .dark, .nebula:
            UIColor(red: 0.12, green: 0.14, blue: 0.26, alpha: 0.42)
        }
    }

    var primaryTextColor: UIColor {
        switch self {
        case .light:
            UIColor(red: 0.08, green: 0.10, blue: 0.20, alpha: 1)
        case .system, .dark, .nebula:
            .white
        }
    }

    var secondaryTextColor: UIColor {
        switch self {
        case .light:
            UIColor(red: 0.24, green: 0.30, blue: 0.44, alpha: 1)
        case .system, .dark, .nebula:
            UIColor.white.withAlphaComponent(0.62)
        }
    }

    var segmentTintColor: UIColor {
        switch self {
        case .light:
            UIColor.white.withAlphaComponent(0.94)
        case .system, .dark, .nebula:
            accentColor.withAlphaComponent(0.34)
        }
    }

    var segmentSelectedTextColor: UIColor {
        switch self {
        case .light:
            UIColor(red: 0.05, green: 0.13, blue: 0.28, alpha: 1)
        case .system, .dark, .nebula:
            .white
        }
    }

    var segmentNormalTextColor: UIColor {
        switch self {
        case .light:
            UIColor(red: 0.20, green: 0.26, blue: 0.40, alpha: 1)
        case .system, .dark, .nebula:
            UIColor.white.withAlphaComponent(0.68)
        }
    }

    private static let nebulaPalette = TaijiRefreshPalette(
        backgroundTint: UIColor(red: 0.07, green: 0.03, blue: 0.18, alpha: 0.20),
        primaryGlow: UIColor(red: 0.78, green: 0.42, blue: 1.00, alpha: 1),
        secondaryGlow: UIColor(red: 0.30, green: 0.92, blue: 1.00, alpha: 1),
        glassHighlight: UIColor(red: 0.94, green: 0.92, blue: 1.00, alpha: 0.94),
        shadowCore: UIColor(red: 0.05, green: 0.02, blue: 0.16, alpha: 0.96),
        particle: UIColor(red: 0.92, green: 0.78, blue: 1.00, alpha: 1)
    )
}

private final class TaijiDemoCell: UITableViewCell {
    static let reuseIdentifier = "TaijiDemoCell"

    private let cardView = UIView()
    private let orbView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: TaijiDemoItem, theme: TaijiDemoTheme) {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()

        cardView.backgroundColor = theme.cellFillColor
        cardView.layer.borderColor = item.accentColor.withAlphaComponent(0.18).cgColor

        orbView.backgroundColor = item.accentColor.withAlphaComponent(0.92)
        orbView.layer.shadowColor = item.accentColor.cgColor

        titleLabel.text = item.title
        titleLabel.textColor = theme.primaryTextColor
        subtitleLabel.text = item.subtitle
        subtitleLabel.textColor = theme.secondaryTextColor
        badgeLabel.text = item.badge
        badgeLabel.textColor = theme.secondaryTextColor
        badgeLabel.backgroundColor = item.accentColor.withAlphaComponent(0.16)
    }

    private func configureView() {
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 1
        cardView.layer.masksToBounds = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        orbView.layer.cornerRadius = 18
        orbView.layer.shadowRadius = 12
        orbView.layer.shadowOpacity = 0.42
        orbView.layer.shadowOffset = .zero
        orbView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(orbView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subtitleLabel)

        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 12
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            orbView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            orbView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            orbView.widthAnchor.constraint(equalToConstant: 36),
            orbView.heightAnchor.constraint(equalToConstant: 36),

            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            badgeLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 42),
            badgeLabel.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: orbView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
        ])
    }
}

private final class TaijiDemoBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()
    private let starLayer = CAShapeLayer()
    private var theme: TaijiDemoTheme = .system

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.locations = [0, 0.48, 1]
        layer.addSublayer(glowLayer)

        starLayer.fillColor = UIColor.white.withAlphaComponent(0.34).cgColor
        layer.addSublayer(starLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(theme: TaijiDemoTheme) {
        self.theme = theme
        gradientLayer.colors = theme.backgroundColors.map(\.cgColor)
        glowLayer.colors = [
            theme.accentColor.withAlphaComponent(0.30).cgColor,
            theme.accentColor.withAlphaComponent(0.10).cgColor,
            UIColor.clear.cgColor,
        ]
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        glowLayer.frame = CGRect(
            x: bounds.midX - bounds.width * 0.72,
            y: -bounds.height * 0.14,
            width: bounds.width * 1.44,
            height: bounds.height * 0.58
        )
        starLayer.frame = bounds
        starLayer.path = makeStarPath(in: bounds).cgPath
        starLayer.opacity = theme == .light ? 0.20 : 0.72
    }

    private func makeStarPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let count = max(64, Int(rect.height / 11))

        for index in 0..<count {
            let x = CGFloat((index * 47 + 11) % 101) / 100 * rect.width
            let y = CGFloat((index * 83 + 29) % 101) / 100 * rect.height
            let size = CGFloat((index % 3) + 1) * 0.55
            path.append(UIBezierPath(ovalIn: CGRect(x: x, y: y, width: size, height: size)))
        }

        return path
    }
}
