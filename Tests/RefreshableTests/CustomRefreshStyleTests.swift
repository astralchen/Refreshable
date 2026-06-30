import Testing
@testable import Refreshable
import UIKit

@Suite("Custom Refresh Styles", .tags(.ui))
@MainActor
struct CustomRefreshStyleTests {

    @Test("SystemNativeRefreshStyle exposes compact native state text")
    func systemNativeStateText() {
        let style = SystemNativeRefreshStyle()

        #expect(style.extent == 64)
        #expect(style.view.isAccessibilityElement)

        style.update(state: .idle, progress: 0)
        #expect(style.view.accessibilityValue == "未刷新")

        style.update(state: .triggered, progress: 1)
        #expect(style.view.accessibilityValue == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在刷新")
    }

    @Test("TaijiRefreshStyle maps refresh states without visible text")
    func taijiStateMapping() {
        let style = TaijiRefreshStyle()

        #expect(style.extent == 92)
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.subviews.isEmpty == false)

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(style.view.accessibilityValue == "下拉中")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在刷新")

        style.update(state: .ending, progress: 0)
        #expect(style.view.accessibilityValue == "刷新完成")
    }

    @Test("TaijiRefreshStyle supports runtime theme switching")
    func taijiThemeSwitching() {
        let style = TaijiRefreshStyle(theme: .dark)

        style.setTheme(.light, animated: false)

        #expect(style.theme == .light)
    }

    @Test("KineticRefreshStyle exposes playful state text")
    func kineticStateText() {
        let style = KineticRefreshStyle()

        #expect(style.extent == 112)
        #expect(style.view.isAccessibilityElement)

        style.update(state: .triggered, progress: 1)
        #expect(style.view.accessibilityValue == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在更新")
    }
}
