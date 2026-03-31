import Testing
@testable import Refreshable
import UIKit

@Suite("DefaultHeaderStyle", .tags(.ui))
@MainActor
struct DefaultHeaderStyleTests {

    @Test("初始化后 height 为 54")
    func height() {
        let style = DefaultHeaderStyle()
        #expect(style.height == 54)
    }

    @Test("view 不为 nil 且有子视图")
    func viewHasSubviews() {
        let style = DefaultHeaderStyle()
        #expect(style.view.subviews.count >= 2)
    }

    @Test("update 不 crash，各状态均可调用")
    func updateAllStates() {
        let style = DefaultHeaderStyle()
        style.update(state: .idle, progress: 0)
        style.update(state: .pulling(0.5), progress: 0.5)
        style.update(state: .triggered, progress: 1.0)
        style.update(state: .refreshing, progress: 0)
        style.update(state: .ending, progress: 0)
        style.update(state: .noMoreData, progress: 0)
    }
}

@Suite("DefaultFooterStyle", .tags(.ui))
@MainActor
struct DefaultFooterStyleTests {

    @Test("初始化后 height 为 54")
    func height() {
        let style = DefaultFooterStyle()
        #expect(style.height == 54)
    }

    @Test("update 不 crash，各状态均可调用")
    func updateAllStates() {
        let style = DefaultFooterStyle()
        style.update(state: .idle, progress: 0)
        style.update(state: .pulling(0.3), progress: 0.3)
        style.update(state: .triggered, progress: 1.0)
        style.update(state: .refreshing, progress: 0)
        style.update(state: .ending, progress: 0)
        style.update(state: .noMoreData, progress: 0)
    }
}

extension Tag {
    @Tag static var ui: Self
}
