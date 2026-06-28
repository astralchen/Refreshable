import AVFoundation
import UIKit
import Refreshable

final class VideoFeedDemoController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private var items: [VideoFeedItem] = []
    private var page = 0
    private var refreshSeed = 0
    private let topRefreshOverlay = VideoRefreshOverlayView()
    private let bottomLoadMoreOverlay = VideoLoadMoreOverlayView()

    private let pageSize = 3
    private let maxPage = 3
    private let refreshTriggerOffset: CGFloat = 76
    private let loadMoreTriggerOffset: CGFloat = 76
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
        topRefreshOverlay.hide(animated: false)
        bottomLoadMoreOverlay.hide(animated: false)
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
        setupTopRefreshOverlay()
        setupBottomLoadMoreOverlay()

        collectionView.refreshable(
            edge: .top,
            style: VideoSilentRefreshStyle(extent: refreshTriggerOffset),
            options: RefreshableOptions(
                triggerOffset: refreshTriggerOffset,
                keepsRefreshViewVisibleDuringAction: false,
                onStateChange: { [weak self] state in
                    self?.updateTopRefreshOverlay(for: state)
                }
            )
        ) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.refreshSeed += 1
                self.page = 0
                self.items = self.makeItems(start: 1 + self.refreshSeed * 20, count: 5)
                self.collectionView.reloadData()
                self.collectionView.resetNoMoreData(edge: .bottom)
                self.playCurrentCellAfterLayout()
            }
        }

        collectionView.loadMoreable(
            edge: .bottom,
            style: VideoSilentRefreshStyle(extent: loadMoreTriggerOffset),
            options: RefreshableOptions(
                triggerOffset: loadMoreTriggerOffset,
                allowsLoadMoreWhenContentFits: true,
                keepsRefreshViewVisibleDuringAction: false
            )
        ) {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                self.page += 1
                guard self.page < self.maxPage else {
                    self.collectionView.noMoreData(edge: .bottom)
                    return
                }

                let start = self.items.count + 1 + self.refreshSeed * 20
                self.items.append(contentsOf: self.makeItems(start: start, count: self.pageSize))
                self.collectionView.reloadData()
                self.playCurrentCellAfterLayout()
            }
        }
    }

    private func setupTopRefreshOverlay() {
        topRefreshOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topRefreshOverlay)

        NSLayoutConstraint.activate([
            topRefreshOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topRefreshOverlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            topRefreshOverlay.widthAnchor.constraint(equalToConstant: 190),
            topRefreshOverlay.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupBottomLoadMoreOverlay() {
        bottomLoadMoreOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomLoadMoreOverlay)

        NSLayoutConstraint.activate([
            bottomLoadMoreOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomLoadMoreOverlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            bottomLoadMoreOverlay.widthAnchor.constraint(equalToConstant: 190),
            bottomLoadMoreOverlay.heightAnchor.constraint(equalToConstant: 44),
        ])
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTopRefreshOverlay(for: scrollView)
        updateBottomLoadMoreOverlay(for: scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hideTopRefreshOverlayIfNeeded()
        bottomLoadMoreOverlay.hide(animated: true)
        playCurrentCell()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        hideTopRefreshOverlayIfNeeded()
        bottomLoadMoreOverlay.hide(animated: true)
        if !decelerate {
            playCurrentCell()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        hideTopRefreshOverlayIfNeeded()
        bottomLoadMoreOverlay.hide(animated: true)
        playCurrentCell()
    }

    private func updateTopRefreshOverlay(for scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }

        let state = collectionView.refreshState(edge: .top)
        if state == .refreshing {
            topRefreshOverlay.showRefreshing()
            return
        }

        let distance = topPullDistance(in: scrollView)
        guard scrollView.isDragging, distance > 0, state != .ending else {
            topRefreshOverlay.hide(animated: false)
            return
        }

        topRefreshOverlay.update(
            distance: distance,
            threshold: refreshTriggerOffset
        )
    }

    private func updateTopRefreshOverlay(for state: RefreshState) {
        switch state {
        case .refreshing:
            topRefreshOverlay.showRefreshing()
        case .idle, .ending:
            topRefreshOverlay.hide(animated: true)
        case .pulling, .triggered, .noMoreData:
            break
        }
    }

    private func hideTopRefreshOverlayIfNeeded() {
        guard collectionView.refreshState(edge: .top) != .refreshing else { return }
        topRefreshOverlay.hide(animated: true)
    }

    private func updateBottomLoadMoreOverlay(for scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }

        let distance = bottomPullDistance(in: scrollView)
        let state = collectionView.loadMoreState(edge: .bottom)
        guard scrollView.isDragging, distance > 0, state != .refreshing, state != .ending else {
            bottomLoadMoreOverlay.hide(animated: false)
            return
        }

        bottomLoadMoreOverlay.update(
            distance: distance,
            threshold: loadMoreTriggerOffset,
            state: state
        )
    }

    private func topPullDistance(in scrollView: UIScrollView) -> CGFloat {
        let visibleTop = scrollView.contentOffset.y + scrollView.contentInset.top
        return max(-visibleTop, 0)
    }

    private func bottomPullDistance(in scrollView: UIScrollView) -> CGFloat {
        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height
        let contentBottom = scrollView.contentSize.height + scrollView.contentInset.bottom
        return max(visibleBottom - contentBottom, 0)
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

        releasePlayer()
        guard let url = item.videoURL else {
            fallbackView.isHidden = false
            return
        }

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
        fallbackView.isHidden = false
    }
}

private final class VideoSilentRefreshStyle: RefreshableStyle {
    let view = UIView()
    let extent: CGFloat

    init(extent: CGFloat) {
        self.extent = extent
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    func update(state: RefreshState, progress: CGFloat) {}
}

private final class VideoRefreshOverlayView: UIView {
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let iconView = UIImageView(image: UIImage(systemName: "arrow.down.circle.fill"))
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        alpha = 0
        isUserInteractionEnabled = false

        backgroundView.layer.cornerRadius = 22
        backgroundView.layer.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.contentView.addSubview(iconView)
        backgroundView.contentView.addSubview(indicator)
        backgroundView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            indicator.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(distance: CGFloat, threshold: CGFloat) {
        indicator.stopAnimating()
        iconView.isHidden = false

        if distance >= threshold {
            iconView.image = UIImage(systemName: "arrow.down.circle.fill")
            label.text = "释放刷新视频"
        } else {
            iconView.image = UIImage(systemName: "arrow.down.circle")
            label.text = "继续下拉刷新视频"
        }

        alpha = min(max(distance / 28, 0), 1)
    }

    func showRefreshing() {
        iconView.isHidden = true
        indicator.startAnimating()
        label.text = "正在刷新视频"
        alpha = 1
    }

    func hide(animated: Bool) {
        let animations = {
            self.alpha = 0
        }

        let completion: (Bool) -> Void = { _ in
            self.indicator.stopAnimating()
            self.iconView.isHidden = false
        }

        guard animated else {
            animations()
            completion(true)
            return
        }

        UIView.animate(withDuration: 0.16, animations: animations, completion: completion)
    }
}

private final class VideoLoadMoreOverlayView: UIView {
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let iconView = UIImageView(image: UIImage(systemName: "arrow.up.circle.fill"))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        alpha = 0
        isUserInteractionEnabled = false

        backgroundView.layer.cornerRadius = 22
        backgroundView.layer.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.contentView.addSubview(iconView)
        backgroundView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(distance: CGFloat, threshold: CGFloat, state: RefreshState) {
        if state == .noMoreData {
            iconView.image = UIImage(systemName: "checkmark.circle.fill")
            label.text = "没有更多视频"
        } else if distance >= threshold {
            iconView.image = UIImage(systemName: "arrow.up.circle.fill")
            label.text = "释放加载视频"
        } else {
            iconView.image = UIImage(systemName: "arrow.up.circle")
            label.text = "继续上拉加载视频"
        }

        alpha = min(max(distance / 28, 0), 1)
    }

    func hide(animated: Bool) {
        let animations = {
            self.alpha = 0
        }

        guard animated else {
            animations()
            return
        }

        UIView.animate(withDuration: 0.16, animations: animations)
    }
}
