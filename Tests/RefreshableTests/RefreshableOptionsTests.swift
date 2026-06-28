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
    }

    @Test("可配置触发距离、动画时长、自动结束和内容不足一屏加载")
    func customValues() {
        let options = RefreshableOptions(
            triggerOffset: 80,
            animationDuration: 0.4,
            automaticallyEndRefreshing: false,
            allowsLoadMoreWhenContentFits: true
        )

        #expect(options.triggerOffset == 80)
        #expect(options.animationDuration == 0.4)
        #expect(options.automaticallyEndRefreshing == false)
        #expect(options.allowsLoadMoreWhenContentFits == true)
    }
}
