import UIKit

final class DemoTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        configureAppearance()
        viewControllers = [
            makeNavigationController(
                rootViewController: TableViewDemoController(),
                title: "列表",
                imageName: "list.bullet.rectangle"
            ),
            makeNavigationController(
                rootViewController: TaijiRefreshDemoController(),
                title: "太极",
                imageName: "circle.lefthalf.filled"
            ),
            makeNavigationController(
                rootViewController: CollectionViewDemoController(),
                title: "网格",
                imageName: "square.grid.2x2.fill"
            ),
            makeNavigationController(
                rootViewController: HorizontalEdgeDemoController(),
                title: "横向",
                imageName: "arrow.left.and.right.square"
            ),
            makeNavigationController(
                rootViewController: VideoFeedDemoController(),
                title: "视频",
                imageName: "play.rectangle.fill"
            ),
        ]
    }

    private func configureAppearance() {
        tabBar.tintColor = .systemIndigo
        tabBar.unselectedItemTintColor = .secondaryLabel

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemBackground

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemIndigo,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
        ]

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.selected.iconColor = .systemIndigo
            itemAppearance.selected.titleTextAttributes = selectedAttributes
            itemAppearance.normal.iconColor = .secondaryLabel
            itemAppearance.normal.titleTextAttributes = normalAttributes
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func makeNavigationController(
        rootViewController: UIViewController,
        title: String,
        imageName: String
    ) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: imageName),
            selectedImage: UIImage(systemName: imageName)
        )
        return navigationController
    }
}
