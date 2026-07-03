import AVFoundation
import UIKit
import Refreshable

final class VideoFeedDemoController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private var items: [VideoFeedItem] = []
    private var page = 0
    private var refreshSeed = 0

    private let pageSize = 3
    private let maxPage = 3
    private let refreshTriggerOffset: CGFloat = 76
    private let loadMoreTriggerOffset: CGFloat = 76
    private let refreshOverlayTopSpacing: CGFloat = 14
    private let loadMoreContentBoundarySpacing: CGFloat = 8
    private let videoResourceNames = [
        "refreshable-video-1",
        "refreshable-video-2",
        "refreshable-video-3",
        "refreshable-video-4",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCollectionView()
        loadInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        playCurrentCell()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        pauseVisibleCells()
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .black
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(VideoFeedCell.self, forCellWithReuseIdentifier: VideoFeedCell.reuseIdentifier)
        view.addSubview(collectionView)

        collectionView.refreshable(
            edge: .top,
            style: VideoTopRefreshStyle(),
            options: RefreshableOptions(
                triggerOffset: refreshTriggerOffset,
                presentation: .overlay(spacing: refreshOverlayTopSpacing, locksContentOffset: true)
            )
        ) {
            try? await Task.sleep(nanoseconds: 1_000_000)
            await MainActor.run {
                self.refreshSeed += 1
                self.page = 0
                let previousCount = self.items.count
                self.items = self.makeItems(start: 1 + self.refreshSeed * 20, count: 5)
                self.reconfigureRefreshItems(previousCount: previousCount)
                self.collectionView.resetNoMoreData(edge: .bottom)
                self.playCurrentCellAfterLayout()
            }
        }

        collectionView.loadMoreable(
            edge: .bottom,
            style: VideoBottomLoadMoreStyle(extent: loadMoreTriggerOffset),
            options: RefreshableOptions(
                triggerOffset: loadMoreTriggerOffset,
                animationDuration: 0.24,
                allowsLoadMoreWhenContentFits: true,
                presentation: .overlay(spacing: loadMoreContentBoundarySpacing),
                overlayAnchor: .contentBoundary
            )
        ) {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                let nextPage = self.page + 1
                guard nextPage < self.maxPage else {
                    self.collectionView.noMoreData(edge: .bottom)
                    return
                }

                self.page = nextPage
                let start = self.items.count + 1 + self.refreshSeed * 20
                self.items.append(contentsOf: self.makeItems(start: start, count: self.pageSize))
                self.collectionView.reloadData()
                self.playCurrentCellAfterLayout()
            }
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0

        let layout = UICollectionViewCompositionalLayout(section: section)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        layout.configuration = configuration
        return layout
    }

    private func loadInitialData() {
        items = makeItems(start: 1, count: 5)
        collectionView.reloadData()
    }

    private func reconfigureRefreshItems(previousCount: Int) {
        guard previousCount == items.count else {
            collectionView.reloadData()
            return
        }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
            .filter { $0.item < items.count }
        guard !visibleIndexPaths.isEmpty else {
            collectionView.reloadData()
            return
        }

        UIView.performWithoutAnimation {
            collectionView.reconfigureItems(at: visibleIndexPaths)
            collectionView.layoutIfNeeded()
        }
    }

    private func makeItems(start: Int, count: Int) -> [VideoFeedItem] {
        (start..<start + count).map { serial in
            let resourceName = videoResourceNames[(serial - 1) % videoResourceNames.count]
            return VideoFeedItem(
                title: "Refreshable Edge \(serial)",
                author: "@refreshable.demo",
                likes: "\(12 + serial * 3).\(serial % 10)K",
                caption: serial.isMultiple(of: 2) ? "下拉刷新这一组视频" : "上拉加载更多视频",
                videoURL: videoURL(resourceName: resourceName)
            )
        }
    }

    private func videoURL(resourceName: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4", subdirectory: "Videos")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    private func playCurrentCellAfterLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.layoutIfNeeded()
            self?.playCurrentCell()
        }
    }

    private func playCurrentCell() {
        guard isViewLoaded, view.window != nil else { return }

        let visibleCenter = CGPoint(
            x: collectionView.bounds.midX + collectionView.contentOffset.x,
            y: collectionView.bounds.midY + collectionView.contentOffset.y
        )
        guard let currentIndexPath = collectionView.indexPathForItem(at: visibleCenter) else { return }

        for cell in collectionView.visibleCells {
            guard let videoCell = cell as? VideoFeedCell else { continue }
            if collectionView.indexPath(for: videoCell) == currentIndexPath {
                videoCell.play()
            } else {
                videoCell.pause()
            }
        }
    }

    private func pauseVisibleCells() {
        collectionView.visibleCells
            .compactMap { $0 as? VideoFeedCell }
            .forEach { $0.pause() }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: VideoFeedCell.reuseIdentifier,
            for: indexPath
        ) as! VideoFeedCell
        cell.configure(with: items[indexPath.item])
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? VideoFeedCell)?.pause()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        playCurrentCell()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            playCurrentCell()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        playCurrentCell()
    }
}

private struct VideoFeedItem {
    let title: String
    let author: String
    let likes: String
    let caption: String
    let videoURL: URL?
}

private final class VideoFeedCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoFeedCell"

    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentVideoURL: URL?

    private let fallbackView = UIView()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let captionLabel = UILabel()
    private let likesLabel = UILabel()
    private let playImageView = UIImageView(image: UIImage(systemName: "play.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        contentView.layer.addSublayer(playerLayer)

        fallbackView.backgroundColor = .systemIndigo
        fallbackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fallbackView)

        playImageView.tintColor = .white
        playImageView.contentMode = .center
        playImageView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        playImageView.layer.cornerRadius = 8
        playImageView.layer.masksToBounds = true
        playImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.55
        titleLabel.layer.shadowRadius = 8
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        authorLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        authorLabel.textColor = .white.withAlphaComponent(0.9)
        authorLabel.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.font = .systemFont(ofSize: 15, weight: .regular)
        captionLabel.textColor = .white.withAlphaComponent(0.86)
        captionLabel.numberOfLines = 2
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        likesLabel.font = .systemFont(ofSize: 13, weight: .bold)
        likesLabel.textColor = .white
        likesLabel.textAlignment = .center
        likesLabel.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        likesLabel.layer.cornerRadius = 8
        likesLabel.layer.masksToBounds = true
        likesLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(captionLabel)
        contentView.addSubview(likesLabel)
        contentView.addSubview(playImageView)

        NSLayoutConstraint.activate([
            fallbackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            fallbackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fallbackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fallbackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            playImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 14),
            playImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            playImageView.widthAnchor.constraint(equalToConstant: 42),
            playImageView.heightAnchor.constraint(equalToConstant: 32),

            likesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            likesLabel.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -92),
            likesLabel.widthAnchor.constraint(equalToConstant: 68),
            likesLabel.heightAnchor.constraint(equalToConstant: 42),

            captionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: likesLabel.leadingAnchor, constant: -18),
            captionLabel.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -34),

            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            authorLabel.trailingAnchor.constraint(lessThanOrEqualTo: likesLabel.leadingAnchor, constant: -18),
            authorLabel.bottomAnchor.constraint(equalTo: captionLabel.topAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: likesLabel.leadingAnchor, constant: -18),
            titleLabel.bottomAnchor.constraint(equalTo: authorLabel.topAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        releasePlayer()
    }

    func configure(with item: VideoFeedItem) {
        titleLabel.text = item.title
        authorLabel.text = item.author
        likesLabel.text = item.likes
        captionLabel.text = item.caption

        guard let url = item.videoURL else {
            releasePlayer()
            fallbackView.isHidden = false
            return
        }
        guard currentVideoURL != url || player == nil else {
            fallbackView.isHidden = true
            return
        }

        releasePlayer()
        currentVideoURL = url

        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none

        let playerItem = AVPlayerItem(url: url)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        player = queuePlayer
        playerLayer.player = queuePlayer
        fallbackView.isHidden = true
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    private func releasePlayer() {
        player?.pause()
        playerLayer.player = nil
        playerLooper = nil
        player = nil
        currentVideoURL = nil
        fallbackView.isHidden = false
    }
}
