import UIKit
import Refreshable

final class HorizontalEdgeDemoController: UIViewController, UICollectionViewDataSource {

    private var collectionView: UICollectionView!
    private var items: [HorizontalDemoItem] = []
    private var page = 0
    private var layoutDirection: HorizontalLayoutDirection = .leftToRight

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "横向 Edge"
        view.backgroundColor = .systemBackground

        configureNavigationItem()
        setupCollectionView()
        loadInitialData()
    }

    private func configureNavigationItem() {
        navigationItem.rightBarButtonItem = makeLayoutDirectionItem()
    }

    private func makeLayoutDirectionItem() -> UIBarButtonItem {
        UIBarButtonItem(
            title: layoutDirection.title,
            image: nil,
            primaryAction: nil,
            menu: makeLayoutDirectionMenu()
        )
    }

    private func makeLayoutDirectionMenu() -> UIMenu {
        UIMenu(title: "显示方向", children: HorizontalLayoutDirection.allCases.map { direction in
            UIAction(
                title: direction.title,
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
        items = makeItems(start: 1, count: max(items.count, 8))
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
        scrollToCurrentDirectionStartItem()
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.alwaysBounceHorizontal = true
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(HorizontalDemoCell.self, forCellWithReuseIdentifier: HorizontalDemoCell.reuseIdentifier)
        view.addSubview(collectionView)
        applyLayoutDirection()
        installEdgeControls()
    }

    private func installEdgeControls() {
        collectionView.refreshable(edge: .leading) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.page = 0
                self.items = self.makeItems(start: 1, count: 8)
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

                let start = self.items.count + 1
                self.items.append(contentsOf: self.makeItems(start: start, count: 4))
                self.collectionView.reloadData()
            }
        }
    }

    private func applyLayoutDirection() {
        view.semanticContentAttribute = layoutDirection.semanticContentAttribute
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
            widthDimension: .fractionalWidth(0.78),
            heightDimension: .fractionalHeight(0.72)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20)

        let layout = NonMirroringHorizontalLayout(section: section)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        layout.configuration = configuration
        return layout
    }

    private func loadInitialData() {
        items = makeItems(start: 1, count: 8)
        collectionView.reloadData()
    }

    private func makeItems(start: Int, count: Int) -> [HorizontalDemoItem] {
        (start..<start + count).map { index in
            HorizontalDemoItem(
                title: "Edge \(index)",
                subtitle: layoutDirection.edgeDescription,
                color: HorizontalDemoItem.colors[index % HorizontalDemoItem.colors.count]
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
        cell.configure(with: items[indexPath.item], number: indexPath.item + 1)
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

    var title: String {
        switch self {
        case .leftToRight:
            "LTR"
        case .rightToLeft:
            "RTL"
        }
    }

    var menuImageName: String {
        switch self {
        case .leftToRight:
            "text.alignleft"
        case .rightToLeft:
            "text.alignright"
        }
    }

    var edgeDescription: String {
        switch self {
        case .leftToRight:
            "leading 左侧 · trailing 右侧"
        case .rightToLeft:
            "leading 右侧 · trailing 左侧"
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
    let title: String
    let subtitle: String
    let color: UIColor

    static let colors: [UIColor] = [
        .systemIndigo,
        .systemTeal,
        .systemOrange,
        .systemPink,
        .systemGreen,
        .systemPurple,
    ]
}

private final class HorizontalDemoCell: UICollectionViewCell {
    static let reuseIdentifier = "HorizontalDemoCell"

    private let numberLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        semanticContentAttribute = .forceLeftToRight
        contentView.semanticContentAttribute = .forceLeftToRight
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true

        numberLabel.font = .systemFont(ofSize: 58, weight: .bold)
        numberLabel.textColor = .white.withAlphaComponent(0.28)
        numberLabel.textAlignment = .right
        numberLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        subtitleLabel.textColor = .white.withAlphaComponent(0.82)
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 2
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.minimumScaleFactor = 0.82
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(numberLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            numberLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            numberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 22),
            titleLabel.rightAnchor.constraint(lessThanOrEqualTo: contentView.rightAnchor, constant: -22),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -8),

            subtitleLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
            subtitleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -22),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: HorizontalDemoItem, number: Int) {
        numberLabel.text = String(format: "%02d", number)
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        contentView.backgroundColor = item.color
    }
}
