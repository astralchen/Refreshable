import UIKit

/// 默认的上拉加载 UI
@MainActor
public final class DefaultFooterStyle: RefreshableStyle {

    public let view: UIView = UIView()
    public let height: CGFloat = 54

    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

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
