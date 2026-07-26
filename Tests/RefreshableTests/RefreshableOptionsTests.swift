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
        #expect(options.automaticTriggerOffset == .default)
        #expect(options.placement == nil)
        #expect(options.presentation == .contentInset)
        #expect(options.overlayAnchor == .viewport)
        #expect(options.textConfiguration == nil)
        #expect(!storedPropertyNames(in: options).contains("keepsRefreshViewVisibleDuringAction"))
        #expect(!storedPropertyNames(in: options).contains("keepsRefreshViewVisibleAfterTrigger"))
    }

    @Test("可配置触发距离、动画时长、自动结束、内容不足一屏加载和展示方式")
    func customValues() throws {
        let options = RefreshableOptions(
            triggerOffset: 80,
            animationDuration: 0.4,
            automaticallyEndRefreshing: false,
            allowsLoadMoreWhenContentFits: true,
            automaticTriggerOffset: 120,
            placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20),
            presentation: .overlay(spacing: 12, locksContentOffset: true),
            overlayAnchor: .contentBoundary
        )

        #expect(options.triggerOffset == 80)
        #expect(options.animationDuration == 0.4)
        #expect(options.automaticallyEndRefreshing == false)
        #expect(options.allowsLoadMoreWhenContentFits == true)
        #expect(options.automaticTriggerOffset == .offset(120))
        let placement = try #require(options.placement)
        #expect(placement.contentSpacing == 12)
        #expect(placement.outerSpacing == 8)
        #expect(placement.crossAxisInset == 20)
        #expect(options.presentation == .overlay(spacing: 12, locksContentOffset: true))
        #expect(options.overlayAnchor == .contentBoundary)
    }

    @Test("overlay 默认固定到可见区域边缘")
    func overlayDefaultsToViewportAnchor() {
        let options = RefreshableOptions(presentation: .overlay(spacing: 12))

        #expect(options.presentation == .overlay(spacing: 12, locksContentOffset: false))
        #expect(options.overlayAnchor == .viewport)
    }

    @Test("placement 默认为 nil 以使用 style 默认值")
    func placementDefaultsToStyleConfiguration() {
        let options = RefreshableOptions()

        #expect(options.placement == nil)
    }

    @Test("placement 可配置刷新轴间距、外侧间距和交叉轴 inset")
    func placementStoresContentSpacingOuterSpacingAndCrossAxisInset() throws {
        let options = RefreshableOptions(
            placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20)
        )

        let placement = try #require(options.placement)
        #expect(placement.contentSpacing == 12)
        #expect(placement.outerSpacing == 8)
        #expect(placement.crossAxisInset == 20)
    }

    @Test("统一解析清理非法尺寸、间距、动画和自动触发距离")
    func resolvedOptionsSanitizeInvalidValues() {
        let resolved = ResolvedRefreshableOptions(
            options: RefreshableOptions(
                triggerOffset: .infinity,
                animationDuration: -.infinity,
                automaticTriggerOffset: .offset(-1),
                placement: RefreshablePlacement(
                    contentSpacing: -2,
                    outerSpacing: .nan,
                    crossAxisInset: .infinity
                ),
                presentation: .overlay(spacing: -.infinity, locksContentOffset: true)
            ),
            styleExtent: -.infinity,
            styleTriggerOffset: 0,
            stylePlacement: RefreshablePlacement(contentSpacing: 5, outerSpacing: 6, crossAxisInset: 7)
        )

        #expect(resolved.extent == 1)
        #expect(resolved.triggerOffset == 1)
        #expect(resolved.placement == RefreshablePlacement())
        #expect(resolved.animationDuration == 0)
        #expect(resolved.automaticTriggerOffset == nil)
        #expect(resolved.presentation == .overlay(spacing: 0, locksContentOffset: true))
    }

    @Test("未指定 placement 时采用并清理 style placement")
    func resolvedOptionsUseStylePlacement() {
        let resolved = ResolvedRefreshableOptions(
            options: RefreshableOptions(),
            styleExtent: 54,
            styleTriggerOffset: 44,
            stylePlacement: RefreshablePlacement(contentSpacing: 3, outerSpacing: 8, crossAxisInset: 4)
        )

        #expect(resolved.extent == 54)
        #expect(resolved.triggerOffset == 44)
        #expect(
            resolved.placement
                == RefreshablePlacement(contentSpacing: 3, outerSpacing: 8, crossAxisInset: 4)
        )
    }

    @Test("文本配置可完整保存")
    func textConfigurationStoresAllValues() {
        let configuration = RefreshableTextConfiguration(
            idle: "Idle",
            pulling: "Pulling",
            triggered: "Triggered",
            refreshing: "Refreshing",
            ending: "Ending",
            noMoreData: "No more data",
            accessibilityLabel: "Refresh control"
        )
        let options = RefreshableOptions(textConfiguration: configuration)

        #expect(options.textConfiguration?.idle == "Idle")
        #expect(options.textConfiguration?.pulling == "Pulling")
        #expect(options.textConfiguration?.triggered == "Triggered")
        #expect(options.textConfiguration?.refreshing == "Refreshing")
        #expect(options.textConfiguration?.ending == "Ending")
        #expect(options.textConfiguration?.noMoreData == "No more data")
        #expect(options.textConfiguration?.accessibilityLabel == "Refresh control")
    }

    @Test("空文本配置所有值均为 nil 且相等")
    func emptyTextConfigurationDefaultsToNilAndIsEquatable() {
        let configuration = RefreshableTextConfiguration()

        #expect(configuration.idle == nil)
        #expect(configuration.pulling == nil)
        #expect(configuration.triggered == nil)
        #expect(configuration.refreshing == nil)
        #expect(configuration.ending == nil)
        #expect(configuration.noMoreData == nil)
        #expect(configuration.accessibilityLabel == nil)
        #expect(configuration == RefreshableTextConfiguration())
    }

    private func storedPropertyNames(in options: RefreshableOptions) -> [String] {
        Mirror(reflecting: options).children.compactMap(\.label)
    }
}
