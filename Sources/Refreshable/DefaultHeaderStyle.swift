import UIKit

/// 默认的下拉刷新样式。
///
/// 此样式使用系统符号、文本标签和活动指示器展示下拉刷新状态。
@MainActor
public final class DefaultHeaderStyle: RefreshableStyle {

    /// 显示下拉刷新内容的容器视图。
    public let view: UIView = UIView()

    /// 默认 header 高度。
    public let height: CGFloat = 54

    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private let arrowView = UIImageView()

    /// 创建默认的下拉刷新样式。
    public init() {
        setupUI()
    }

    private func setupUI() {
        view.frame.size.height = height

        // Arrow
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        arrowView.image = UIImage(systemName: "arrow.down", withConfiguration: config)
        arrowView.tintColor = .secondaryLabel
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrowView)

        // Indicator
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        // Label
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            arrowView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            arrowView.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -8),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 根据下拉刷新状态更新默认界面。
    ///
    /// - Parameters:
    ///   - state: 当前下拉刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。
    public func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            label.text = "下拉刷新"
            indicator.stopAnimating()
            arrowView.isHidden = false
            arrowView.transform = .identity

        case .pulling(let p):
            label.text = "下拉刷新"
            indicator.stopAnimating()
            arrowView.isHidden = false
            let angle = min(p, 1.0) * .pi
            arrowView.transform = CGAffineTransform(rotationAngle: angle)

        case .triggered:
            label.text = "释放刷新"
            indicator.stopAnimating()
            arrowView.isHidden = false
            arrowView.transform = CGAffineTransform(rotationAngle: .pi)

        case .refreshing:
            label.text = "正在刷新..."
            indicator.startAnimating()
            arrowView.isHidden = true

        case .ending:
            label.text = "刷新完成"
            indicator.stopAnimating()
            arrowView.isHidden = true

        case .noMoreData:
            break
        }
    }
}
