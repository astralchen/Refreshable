import Testing
import UIKit
@testable import Refreshable

@Suite("System native style renderer", .tags(.ui))
@MainActor
struct SystemNativeRefreshStyleTests {
    @Test("system native renderer 保留刷新状态和自定义 spinner")
    func systemNativeRenderer() throws {
        let renderer = SystemNativeRefreshStyle().makeRenderer()

        renderer.render(
            RefreshableStyleContext(state: .refreshing, pullProgress: 1)
        )

        #expect(renderer.view.accessibilityValue == "正在刷新")
        #expect(renderer.view.containsVisibleLabel(text: "正在刷新..."))
        let spinner = try #require(
            renderer.view.firstSubview(className: "SegmentedRefreshSpinnerView")
        )
        #expect(spinner.layer.animation(forKey: "systemNativeSpin") != nil)
    }
}

private extension UIView {
    func firstSubview(className: String) -> UIView? {
        if String(describing: type(of: self)) == className { return self }
        for subview in subviews {
            if let found = subview.firstSubview(className: className) { return found }
        }
        return nil
    }

    func containsVisibleLabel(text: String) -> Bool {
        if let label = self as? UILabel, label.text == text, !label.isHidden {
            return true
        }
        return subviews.contains { $0.containsVisibleLabel(text: text) }
    }
}
