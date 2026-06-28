import UIKit

/// 默认的上拉加载样式。
///
/// 此样式使用文本标签和活动指示器展示加载更多状态。
@MainActor
public final class DefaultFooterStyle: RefreshableStyle {

    /// 显示上拉加载内容的容器视图。
    public let view: UIView = UIView()

    /// 默认 footer 高度。
    public let height: CGFloat = 54

    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    /// 创建默认的上拉加载样式。
    public init() {
        setupUI()
    }

    private func setupUI() {
        view.frame.size.height = height

        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 根据上拉加载状态更新默认界面。
    ///
    /// - Parameters:
    ///   - state: 当前上拉加载状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    public func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            label.text = "上拉加载更多"
            indicator.stopAnimating()

        case .pulling:
            label.text = "上拉加载更多"
            indicator.stopAnimating()

        case .triggered:
            label.text = "释放加载"
            indicator.stopAnimating()

        case .refreshing:
            label.text = "正在加载..."
            indicator.startAnimating()

        case .ending:
            label.text = "加载完成"
            indicator.stopAnimating()

        case .noMoreData:
            label.text = "没有更多数据"
            indicator.stopAnimating()
        }
    }
}
