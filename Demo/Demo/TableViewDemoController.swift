import UIKit
import Refreshable

class TableViewDemoController: UIViewController, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var items: [String] = []
    private var page = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TableView Demo"
        view.backgroundColor = .systemBackground

        setupTableView()
        loadInitialData()
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        tableView.refreshable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.page = 0
            self.items = (1...20).map { "刷新后 Item \($0)" }
            self.tableView.reloadData()
            self.tableView.resetNoMoreData()
        }

        tableView.loadMoreable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
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

    private func loadInitialData() {
        items = (1...20).map { "Item \($0)" }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        return cell
    }
}
