import Testing
@testable import Refreshable
import UIKit

@Suite("RefreshableOptions")
struct RefreshableOptionsTests {

    @Test("默认值保持现有行为")
    func defaults() {
        let options = RefreshableOptions()

        #expect(options.triggerOffset == nil)
        #expect(options.animationDuration == 0.25)
        #expect(options.automaticallyEndRefreshing == true)
        #expect(options.allowsLoadMoreWhenContentFits == false)
        #expect(options.placement == RefreshablePlacement())
        #expect(options.placement.outerSpacing == 0)
        #expect(options.placement.contentSpacing == 0)
        #expect(options.placement.crossAxisInset == 0)
        #expect(options.presentation == .contentInset)
        #expect(options.overlayAnchor == .viewport)
        #expect(!storedPropertyNames(in: options).contains("keepsRefreshViewVisibleDuringAction"))
        #expect(!storedPropertyNames(in: options).contains("keepsRefreshViewVisibleAfterTrigger"))
    }

    @Test("可配置触发距离、动画时长、自动结束、内容不足一屏加载和展示方式")
    func customValues() {
        let options = RefreshableOptions(
            triggerOffset: 80,
            animationDuration: 0.4,
            automaticallyEndRefreshing: false,
            allowsLoadMoreWhenContentFits: true,
            placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20),
            presentation: .overlay(spacing: 12, locksContentOffset: true),
            overlayAnchor: .contentBoundary
        )

        #expect(options.triggerOffset == 80)
        #expect(options.animationDuration == 0.4)
        #expect(options.automaticallyEndRefreshing == false)
        #expect(options.allowsLoadMoreWhenContentFits == true)
        #expect(options.placement.contentSpacing == 12)
        #expect(options.placement.outerSpacing == 8)
        #expect(options.placement.crossAxisInset == 20)
        #expect(options.presentation == .overlay(spacing: 12, locksContentOffset: true))
        #expect(options.overlayAnchor == .contentBoundary)
    }

    @Test("overlay 默认固定到可见区域边缘")
    func overlayDefaultsToViewportAnchor() {
        let options = RefreshableOptions(presentation: .overlay(spacing: 12))

        #expect(options.presentation == .overlay(spacing: 12, locksContentOffset: false))
        #expect(options.overlayAnchor == .viewport)
    }

    @Test("placement 默认不增加额外间距")
    func placementDefaultsToNoExtraSpacing() {
        let options = RefreshableOptions()

        #expect(options.placement == RefreshablePlacement())
        #expect(options.placement.outerSpacing == 0)
        #expect(options.placement.contentSpacing == 0)
        #expect(options.placement.crossAxisInset == 0)
    }

    @Test("placement 可配置刷新轴间距、外侧间距和交叉轴 inset")
    func placementStoresContentSpacingOuterSpacingAndCrossAxisInset() {
        let options = RefreshableOptions(
            placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20)
        )

        #expect(options.placement.contentSpacing == 12)
        #expect(options.placement.outerSpacing == 8)
        #expect(options.placement.crossAxisInset == 20)
    }

    private func storedPropertyNames(in options: RefreshableOptions) -> [String] {
        Mirror(reflecting: options).children.compactMap(\.label)
    }
}
