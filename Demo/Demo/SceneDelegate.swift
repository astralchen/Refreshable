import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        let tableNav = UINavigationController(rootViewController: TableViewDemoController())
        tableNav.tabBarItem = UITabBarItem(title: "TableView", image: UIImage(systemName: "list.bullet"), tag: 0)

        let collectionNav = UINavigationController(rootViewController: CollectionViewDemoController())
        collectionNav.tabBarItem = UITabBarItem(title: "CollectionView", image: UIImage(systemName: "square.grid.2x2"), tag: 1)

        let tabBar = UITabBarController()
        tabBar.viewControllers = [tableNav, collectionNav]

        window.rootViewController = tabBar
        window.makeKeyAndVisible()
        self.window = window
    }
}

