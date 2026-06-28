import UIKit

/// 非传统边缘使用的默认刷新样式。
@MainActor
final class DefaultEdgeStyle: RefreshableStyle {

    let view: UIView = UIView()
    let extent: CGFloat = 54

    private let edge: RefreshableEdge
    private let role: RefreshableRole
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    init(edge: RefreshableEdge, role: RefreshableRole) {
        self.edge = edge
        self.role = role
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .clear

        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let compactAxis = edge.axis == .horizontal
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: compactAxis ? -14 : 0),

            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: compactAxis ? 4 : 0),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -6),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 3),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -3),
        ])
    }

    func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle, .pulling:
            label.text = role == .refresh ? idleRefreshText : idleLoadMoreText
            indicator.stopAnimating()
        case .triggered:
            label.text = role == .refresh ? "释放刷新" : "释放加载"
            indicator.stopAnimating()
        case .refreshing:
            label.text = role == .refresh ? "正在刷新..." : "正在加载..."
            indicator.startAnimating()
        case .ending:
            label.text = role == .refresh ? "刷新完成" : "加载完成"
            indicator.stopAnimating()
        case .noMoreData:
            label.text = "没有更多数据"
            indicator.stopAnimating()
        }
    }

    private var idleRefreshText: String {
        switch edge {
        case .top:
            "下拉刷新"
        case .bottom:
            "上拉刷新"
        case .leading:
            "拖动刷新"
        case .trailing:
            "拖动刷新"
        }
    }

    private var idleLoadMoreText: String {
        switch edge {
        case .top:
            "下拉加载"
        case .bottom:
            "上拉加载"
        case .leading:
            "拖动加载"
        case .trailing:
            "拖动加载"
        }
    }
}
