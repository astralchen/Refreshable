import Testing
@testable import Refreshable
import UIKit

@Suite("RefreshComponent 基类")
@MainActor
struct RefreshComponentTests {

    // MARK: - originalInset

    @Test("设置 scrollView 时记录 originalInset")
    func capturesOriginalInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}
        component.scrollView = scrollView
        #expect(component.originalInset == UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
    }

    // MARK: - setState 去重

    @Test("相同状态不触发 style.update")
    func deduplicateState() {
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        component.scrollView = scrollView

        style.reset()
        component.setState(.idle) // 已经是 idle
        #expect(style.records.isEmpty)
    }

    @Test("不同状态触发 style.update")
    func differentStateTriggersUpdate() {
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        component.scrollView = scrollView

        style.reset()
        component.setState(.pulling(0.5))
        #expect(style.records.count == 1)
        #expect(style.lastState == .pulling(0.5))
    }

    // MARK: - scrollView 替换

    @Test("替换 scrollView 时移除旧观察并重新安装")
    func replaceScrollView() {
        let sv1 = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let sv2 = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}

        component.scrollView = sv1
        #expect(style.view.superview === sv1)

        component.scrollView = sv2
        #expect(style.view.superview === sv2)
    }

    @Test("设置相同 scrollView 不重复安装")
    func sameScrollViewNoReinstall() {
        let sv = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}

        component.scrollView = sv
        let initialRecordCount = style.records.count

        component.scrollView = sv // 相同实例
        #expect(style.records.count == initialRecordCount)
    }

    // MARK: - State 完整流转

    @Test("完整状态流转: idle → pulling → triggered → refreshing → ending → idle")
    func fullStateFlow() {
        let style = MockStyle()
        let component = HeaderRefreshComponent(style: style) {}
        component.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        style.reset()

        component.setState(.pulling(0.3))
        #expect(component.state == .pulling(0.3))

        component.setState(.pulling(0.8))
        #expect(component.state == .pulling(0.8))

        component.setState(.triggered)
        #expect(component.state == .triggered)

        component.setState(.refreshing)
        #expect(component.state == .refreshing)

        component.setState(.ending)
        #expect(component.state == .ending)

        component.setState(.idle)
        #expect(component.state == .idle)

        // 验证所有状态更新都被记录
        #expect(style.records.count == 6)
    }
}
