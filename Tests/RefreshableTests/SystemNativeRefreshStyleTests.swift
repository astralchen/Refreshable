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
            RefreshableStyleContext(state: .active, pullProgress: 1)
        )

        #expect(renderer.view.accessibilityValue == "正在刷新")
        #expect(renderer.view.containsVisibleLabel(text: "正在刷新..."))
        let spinner = try #require(
            renderer.view.firstSubview(className: "SegmentedRefreshSpinnerView")
        )
        #expect(spinner.layer.animation(forKey: "systemNativeSpin") != nil)
    }

    @Test("pull hint 与 spinner 对齐并随拉动位置靠近")
    func pullHintTracksSpinnerPosition() throws {
        let renderer = SystemNativeRefreshStyle().makeRenderer()
        renderer.view.frame = CGRect(x: 0, y: 0, width: 320, height: 64)
        renderer.view.layoutIfNeeded()

        let hint = try #require(
            renderer.view.descendant(identifier: "Refreshable.SystemNative.PullHint")
        )
        let icon = try #require(
            renderer.view.descendant(identifier: "Refreshable.SystemNative.Icon")
        )

        #expect(abs(hint.center.x - icon.center.x) < 0.5)

        renderer.render(
            RefreshableStyleContext(state: .pulling(0.2), pullProgress: 0.2)
        )
        let earlyOffset = hint.transform.ty
        #expect(hint.isHidden == false)
        #expect(hint.alpha == 1)

        renderer.render(
            RefreshableStyleContext(state: .pulling(0.8), pullProgress: 0.8)
        )

        #expect(hint.transform.ty > earlyOffset)
        #expect(hint.alpha == 1)
    }

    @Test("pull hint 仅在阈值附近翻转并在刷新中收起")
    func pullHintFlipsNearThresholdAndHidesWhileActive() throws {
        let renderer = SystemNativeRefreshStyle().makeRenderer()
        let hint = try #require(
            renderer.view.descendant(identifier: "Refreshable.SystemNative.PullHint")
        )
        let arrow = try #require(hint.firstSubview(of: UIImageView.self))

        renderer.render(
            RefreshableStyleContext(state: .pulling(0.7), pullProgress: 0.7)
        )
        #expect(abs(arrow.transform.b) < 0.001)
        #expect(abs(arrow.transform.a - 1) < 0.001)

        renderer.render(
            RefreshableStyleContext(state: .triggered, pullProgress: 1)
        )
        #expect(abs(arrow.transform.b) < 0.001)
        #expect(abs(arrow.transform.a + 1) < 0.001)
        #expect(hint.isHidden == false)

        renderer.render(
            RefreshableStyleContext(state: .active, pullProgress: 1)
        )
        #expect(hint.isHidden)
    }
}

private extension UIView {
    func descendant(identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier { return self }
        for subview in subviews {
            if let found = subview.descendant(identifier: identifier) { return found }
        }
        return nil
    }

    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let typed = self as? T { return typed }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }

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
