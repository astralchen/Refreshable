import Testing
import UIKit
@testable import Refreshable

@Suite("RefreshableStyle renderer factory")
@MainActor
struct RefreshableStyleContractTests {

    @Test("同一 style 每次创建独立 renderer 和 view")
    func styleCreatesIndependentRenderers() {
        let style = FactoryStyle()

        let first = style.makeRenderer()
        let second = style.makeRenderer()
        first.render(RefreshableStyleContext(state: .pulling(0.4), pullProgress: 0.4))

        #expect(first !== second)
        #expect(first.view !== second.view)
        #expect(first.view.accessibilityValue == "pulling:0.4")
        #expect(second.view.accessibilityValue == nil)
    }

    @Test("style 默认触发距离和 placement 来自 extent 与零值")
    func styleDefaultsFollowExtent() {
        let style = FactoryStyle()

        #expect(style.defaultTriggerOffset == 64)
        #expect(style.defaultPlacement == RefreshablePlacement())
    }

    @Test("Options 默认 placement 未指定并保存显式零值")
    func optionsDistinguishAutomaticAndExplicitZeroPlacement() {
        let automatic = RefreshableOptions()
        let explicit = RefreshableOptions(placement: RefreshablePlacement())

        #expect(automatic.placement == nil)
        #expect(explicit.placement == RefreshablePlacement())
    }
}

@MainActor
private final class FactoryStyle: RefreshableStyle {
    let extent: CGFloat = 64

    func makeRenderer() -> any RefreshableStyleRenderer {
        FactoryRenderer()
    }
}

@MainActor
private final class FactoryRenderer: RefreshableStyleRenderer {
    let view = UIView()

    func render(_ context: RefreshableStyleContext) {
        switch context.state {
        case .pulling:
            view.accessibilityValue = "pulling:\(context.pullProgress)"
        default:
            view.accessibilityValue = String(describing: context.state)
        }
    }
}
