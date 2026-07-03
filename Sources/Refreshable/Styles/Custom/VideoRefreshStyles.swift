import UIKit

/// 全屏视频流顶部下拉刷新文案。
public struct VideoTopRefreshTexts: Equatable {
    public var idle: String
    public var pulling: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
    public var accessibilityLabel: String
    public var idleAccessibilityValue: String
    public var pullingAccessibilityValue: String
    public var triggeredAccessibilityValue: String
    public var refreshingAccessibilityValue: String
    public var endingAccessibilityValue: String

    public init(
        idle: String = "继续下拉刷新视频",
        pulling: String = "继续下拉刷新视频",
        triggered: String = "释放刷新视频",
        refreshing: String = "正在刷新视频",
        ending: String = "视频已刷新",
        accessibilityLabel: String = "视频刷新",
        idleAccessibilityValue: String = "未刷新",
        pullingAccessibilityValue: String = "下拉中",
        triggeredAccessibilityValue: String = "释放刷新",
        refreshingAccessibilityValue: String = "正在刷新",
        endingAccessibilityValue: String = "刷新完成"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.refreshing = refreshing
        self.ending = ending
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.refreshingAccessibilityValue = refreshingAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
    }
}

/// 全屏视频流底部上拉加载文案。
public struct VideoBottomLoadMoreTexts: Equatable {
    public var idle: String
    public var pulling: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
    public var noMoreData: String
    public var accessibilityLabel: String
    public var idleAccessibilityValue: String
    public var pullingAccessibilityValue: String
    public var triggeredAccessibilityValue: String
    public var refreshingAccessibilityValue: String
    public var endingAccessibilityValue: String
    public var noMoreDataAccessibilityValue: String

    public init(
        idle: String = "继续上拉加载视频",
        pulling: String = "继续上拉加载视频",
        triggered: String = "释放加载视频",
        refreshing: String = "正在加载视频",
        ending: String = "加载完成",
        noMoreData: String = "没有更多视频",
        accessibilityLabel: String = "视频加载更多",
        idleAccessibilityValue: String = "未加载",
        pullingAccessibilityValue: String = "上拉中",
        triggeredAccessibilityValue: String = "释放加载",
        refreshingAccessibilityValue: String = "正在加载",
        endingAccessibilityValue: String = "加载完成",
        noMoreDataAccessibilityValue: String = "没有更多视频"
    ) {
        self.idle = idle
        self.pulling = pulling
        self.triggered = triggered
        self.refreshing = refreshing
        self.ending = ending
        self.noMoreData = noMoreData
        self.accessibilityLabel = accessibilityLabel
        self.idleAccessibilityValue = idleAccessibilityValue
        self.pullingAccessibilityValue = pullingAccessibilityValue
        self.triggeredAccessibilityValue = triggeredAccessibilityValue
        self.refreshingAccessibilityValue = refreshingAccessibilityValue
        self.endingAccessibilityValue = endingAccessibilityValue
        self.noMoreDataAccessibilityValue = noMoreDataAccessibilityValue
    }
}

/// 全屏视频流顶部 overlay 下拉刷新样式。
@MainActor
public final class VideoTopRefreshStyle: RefreshableStyle {
    public let view: UIView
    public let extent: CGFloat

    private let texts: VideoTopRefreshTexts
    private let overlayView: VideoTopRefreshView

    public init(extent: CGFloat = 44, texts: VideoTopRefreshTexts = VideoTopRefreshTexts()) {
        self.extent = extent
        self.texts = texts
        self.overlayView = VideoTopRefreshView()
        self.view = overlayView
        view.frame.size.height = extent
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel
        update(state: .idle, progress: 0)
    }

    public func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            overlayView.update(iconSystemName: "arrow.down.circle", text: texts.idle, isRefreshing: false)
            view.accessibilityValue = texts.idleAccessibilityValue
        case .pulling:
            overlayView.update(iconSystemName: "arrow.down.circle", text: texts.pulling, isRefreshing: false)
            view.accessibilityValue = texts.pullingAccessibilityValue
        case .triggered:
            overlayView.update(iconSystemName: "arrow.down.circle.fill", text: texts.triggered, isRefreshing: false)
            view.accessibilityValue = texts.triggeredAccessibilityValue
        case .refreshing:
            overlayView.update(iconSystemName: nil, text: texts.refreshing, isRefreshing: true)
            view.accessibilityValue = texts.refreshingAccessibilityValue
        case .ending:
            overlayView.update(iconSystemName: "checkmark.circle.fill", text: texts.ending, isRefreshing: false)
            view.accessibilityValue = texts.endingAccessibilityValue
        case .noMoreData:
            overlayView.update(iconSystemName: "checkmark.circle.fill", text: texts.ending, isRefreshing: false)
            view.accessibilityValue = texts.endingAccessibilityValue
        }
    }
}

/// 全屏视频流底部 overlay 上拉加载样式。
@MainActor
public final class VideoBottomLoadMoreStyle: RefreshableStyle {
    public let view: UIView
    public let extent: CGFloat

    private let texts: VideoBottomLoadMoreTexts
    private let overlayView: VideoBottomLoadMoreView

    public init(extent: CGFloat = 76, texts: VideoBottomLoadMoreTexts = VideoBottomLoadMoreTexts()) {
        self.extent = extent
        self.texts = texts
        self.overlayView = VideoBottomLoadMoreView()
        self.view = overlayView
        view.frame.size.height = extent
        view.isAccessibilityElement = true
        view.accessibilityLabel = texts.accessibilityLabel
        update(state: .idle, progress: 0)
    }

    public func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            overlayView.update(iconSystemName: "arrow.up.circle", text: texts.idle, isRefreshing: false)
            view.accessibilityValue = texts.idleAccessibilityValue
        case .pulling:
            overlayView.update(iconSystemName: "arrow.up.circle", text: texts.pulling, isRefreshing: false)
            view.accessibilityValue = texts.pullingAccessibilityValue
        case .triggered:
            overlayView.update(iconSystemName: "arrow.up.circle.fill", text: texts.triggered, isRefreshing: false)
            view.accessibilityValue = texts.triggeredAccessibilityValue
        case .refreshing:
            overlayView.update(iconSystemName: nil, text: texts.refreshing, isRefreshing: true)
            view.accessibilityValue = texts.refreshingAccessibilityValue
        case .ending:
            overlayView.update(iconSystemName: "checkmark.circle.fill", text: texts.ending, isRefreshing: false)
            view.accessibilityValue = texts.endingAccessibilityValue
        case .noMoreData:
            overlayView.update(iconSystemName: "checkmark.circle.fill", text: texts.noMoreData, isRefreshing: false)
            view.accessibilityValue = texts.noMoreDataAccessibilityValue
        }
    }
}

private final class VideoTopRefreshView: UIView {
    private let shadowView = UIView()
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let dimmingView = UIView()
    private let iconView = UIImageView()
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        shadowView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        shadowView.layer.cornerRadius = 24
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.42
        shadowView.layer.shadowRadius = 14
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 6)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shadowView)

        backgroundView.layer.cornerRadius = 22
        backgroundView.layer.masksToBounds = true
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(dimmingView)

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconView.layer.shadowColor = UIColor.black.cgColor
        iconView.layer.shadowOpacity = 0.55
        iconView.layer.shadowRadius = 4
        iconView.layer.shadowOffset = CGSize(width: 0, height: 1)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.75
        label.layer.shadowRadius = 5
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.contentView.addSubview(iconView)
        backgroundView.contentView.addSubview(indicator)
        backgroundView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            shadowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            shadowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            shadowView.widthAnchor.constraint(equalToConstant: 222),
            shadowView.heightAnchor.constraint(equalToConstant: 48),

            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 222),
            backgroundView.heightAnchor.constraint(equalToConstant: 48),

            dimmingView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            indicator.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(iconSystemName: String?, text: String, isRefreshing: Bool) {
        if isRefreshing {
            iconView.isHidden = true
            indicator.startAnimating()
        } else {
            iconView.isHidden = false
            iconView.image = iconSystemName.map { UIImage(systemName: $0) } ?? nil
            indicator.stopAnimating()
        }
        label.text = text
    }
}

private final class VideoBottomLoadMoreView: UIView {
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let iconView = UIImageView()
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
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
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 190),
            backgroundView.heightAnchor.constraint(equalToConstant: 44),

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

    func update(iconSystemName: String?, text: String, isRefreshing: Bool) {
        if isRefreshing {
            iconView.isHidden = true
            indicator.startAnimating()
        } else {
            iconView.isHidden = false
            iconView.image = iconSystemName.map { UIImage(systemName: $0) } ?? nil
            indicator.stopAnimating()
        }
        label.text = text
    }
}
