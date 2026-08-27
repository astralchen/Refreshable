import Testing
import UIKit
@testable import Refreshable

@Suite("Refreshable lifecycle")
@MainActor
struct RefreshableLifecycleTests {

    @Test("移除组件会释放 component、renderer 并移除 renderer view")
    func removalReleasesComponentAndRenderer() throws {
        let scrollView = UIScrollView()
        var style: LifecycleStyle? = LifecycleStyle()
        scrollView.refreshable(
            .refresh,
            for: .top,
            style: try #require(style)
        ) {}

        let component = WeakReference(scrollView.refreshableCoordinator.component(for: .top))
        let renderer = WeakReference(style?.latestRenderer)
        let rendererView = WeakReference(style?.latestRenderer?.view)

        scrollView.removeRefreshable(for: .top)
        style = nil

        #expect(component.value == nil)
        #expect(renderer.value == nil)
        #expect(rendererView.value?.superview == nil)
    }

    @Test("scroll view 销毁时关联组件和 renderer 不形成观察循环")
    func scrollViewDeallocationReleasesAssociatedObjects() throws {
        weak var scrollViewReference: UIScrollView?
        weak var componentReference: EdgeRefreshComponent?
        weak var rendererReference: LifecycleRenderer?

        autoreleasepool {
            var scrollView: UIScrollView? = UIScrollView()
            var style: LifecycleStyle? = LifecycleStyle()
            scrollView?.refreshable(
                .refresh,
                for: .top,
                style: try! #require(style)
            ) {}

            scrollViewReference = scrollView
            componentReference = scrollView?.refreshableCoordinator.component(for: .top)
            rendererReference = style?.latestRenderer
            style = nil
            scrollView = nil
        }

        #expect(scrollViewReference == nil)
        #expect(componentReference == nil)
        #expect(rendererReference == nil)
    }

    @Test("Demo 推荐的弱捕获方式不会保留 controller")
    func weakActionCaptureDoesNotRetainController() {
        weak var controllerReference: LifecycleViewController?

        autoreleasepool {
            var controller: LifecycleViewController? = LifecycleViewController()
            controller?.loadViewIfNeeded()
            controllerReference = controller
            controller = nil
        }

        #expect(controllerReference == nil)
    }

    @Test("未安装的 renderer 可独立释放")
    func standaloneRendererCanDeallocate() {
        let style = LifecycleStyle()
        weak var rendererReference: LifecycleRenderer?
        weak var viewReference: UIView?

        autoreleasepool {
            let renderer = style.makeRenderer() as! LifecycleRenderer
            rendererReference = renderer
            viewReference = renderer.view
        }

        #expect(rendererReference == nil)
        #expect(viewReference == nil)
    }
}

@MainActor
private final class LifecycleStyle: RefreshableStyle {
    let extent: CGFloat = 54
    weak var latestRenderer: LifecycleRenderer?

    func makeRenderer() -> any RefreshableStyleRenderer {
        let renderer = LifecycleRenderer()
        latestRenderer = renderer
        return renderer
    }
}

@MainActor
private final class LifecycleRenderer: RefreshableStyleRenderer {
    let view = UIView()

    func render(_ context: RefreshableStyleContext) {
        view.accessibilityValue = String(describing: context.state)
    }
}

@MainActor
private final class LifecycleViewController: UIViewController {
    private let scrollView = UIScrollView()

    override func loadView() {
        view = scrollView
        scrollView.refreshable(
            .refresh,
            for: .top
        ) { [weak self] in
            await self?.didRefresh()
        }
    }

    private func didRefresh() {}
}

private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
