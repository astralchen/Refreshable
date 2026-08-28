import Testing
import UIKit
@testable import Refreshable

@Suite("Refreshable 滚动观察")
@MainActor
struct RefreshableScrollObservationTests {
    @Test("contentOffset 更新不会伪装成视口或布局变化")
    func contentOffsetOnlyEmitsContentOffsetChange() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scrollView.contentSize = CGSize(width: 390, height: 1_688)
        let observations = RefreshableScrollObservationSet()
        var receivedChanges: [RefreshableScrollChanges] = []
        observations.onUpdate = { update in
            receivedChanges.append(update.changes)
        }
        observations.start(for: scrollView)
        receivedChanges.removeAll()

        scrollView.contentOffset = CGPoint(x: 0, y: 120)

        #expect(!receivedChanges.isEmpty)
        #expect(receivedChanges.allSatisfy { $0 == .contentOffset })
        observations.stop()
    }

    @Test("仅 bounds 尺寸变化才发送视口变化")
    func boundsOriginIsIgnoredButSizeIsObserved() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let observations = RefreshableScrollObservationSet()
        var receivedChanges: [RefreshableScrollChanges] = []
        observations.onUpdate = { update in
            receivedChanges.append(update.changes)
        }
        observations.start(for: scrollView)
        receivedChanges.removeAll()

        scrollView.bounds.origin.y = 80
        #expect(!receivedChanges.contains { $0.contains(.viewportSize) })

        scrollView.bounds.size.height = 700
        #expect(receivedChanges.contains { $0.contains(.viewportSize) })
        observations.stop()
    }
}
