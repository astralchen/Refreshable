import UIKit
import Refreshable

class TableViewDemoController: UIViewController, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var items: [String] = []
    private var page = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "列表刷新"
        view.backgroundColor = .systemGroupedBackground

        setupTableView()
        loadInitialData()
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.rowHeight = 64
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 16)
        view.addSubview(tableView)

        tableView.refreshable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                self.page = 0
                self.items = (1...20).map { "刷新后 Item \($0)" }
                self.tableView.reloadData()
                self.tableView.resetNoMoreData()
            }
        }

        tableView.loadMoreable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.page += 1
                if self.page >= 3 {
                    self.tableView.noMoreData()
                    return
                }
                let start = self.items.count + 1
                let newItems = (start..<start + 15).map { "Item \($0)" }
                self.items.append(contentsOf: newItems)
                self.tableView.reloadData()
            }
        }
    }

    private func loadInitialData() {
        items = (1...20).map { "Item \($0)" }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")

        cell.textLabel?.text = items[indexPath.row]
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cell.detailTextLabel?.text = indexPath.row.isMultiple(of: 2) ? "下拉刷新后重置数据" : "滚到底部自动加载更多"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.image = UIImage(systemName: indexPath.row.isMultiple(of: 2) ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
        cell.imageView?.tintColor = indexPath.row.isMultiple(of: 2) ? .systemIndigo : .systemTeal
        cell.backgroundColor = .secondarySystemGroupedBackground
        return cell
    }
}
