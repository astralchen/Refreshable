import UIKit
import Refreshable

class CollectionViewDemoController: UIViewController, UICollectionViewDataSource {

    private var collectionView: UICollectionView!
    private var items: [Int] = []
    private var page = 0

    private let colors: [UIColor] = [
        .systemRed, .systemBlue, .systemGreen, .systemOrange,
        .systemPurple, .systemTeal, .systemPink, .systemIndigo,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "网格分页"
        view.backgroundColor = .systemGroupedBackground
        
        setupCollectionView()
        loadInitialData()
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.dataSource = self
        collectionView.register(ColorCell.self, forCellWithReuseIdentifier: "ColorCell")
        view.addSubview(collectionView)

        collectionView.refreshable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                self.page = 0
                self.items = Array(1...18)
                self.collectionView.reloadData()
                self.collectionView.resetNoMoreData()
            }
        }

        collectionView.loadMoreable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.page += 1
                if self.page >= 3 {
                    self.collectionView.noMoreData()
                    return
                }
                let start = self.items.count + 1
                self.items.append(contentsOf: Array(start..<start + 12))
                self.collectionView.reloadData()
            }
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let spacing: CGFloat = 6
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 3.0),
            heightDimension: .fractionalWidth(1.0 / 3.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / 3.0)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)

        let layout = UICollectionViewCompositionalLayout(section: section)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        layout.configuration = configuration
        return layout
    }

    private func loadInitialData() {
        items = Array(1...18)
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
        let item = items[indexPath.item]
        cell.configure(number: item, color: colors[item % colors.count])
        return cell
    }
}

// MARK: - ColorCell

private class ColorCell: UICollectionViewCell {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(number: Int, color: UIColor) {
        label.text = "\(number)"
        contentView.backgroundColor = color
    }
}
