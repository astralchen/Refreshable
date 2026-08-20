import Testing
import UIKit
@testable import Refreshable

@Suite("RefreshableCoordinator")
@MainActor
struct RefreshableCoordinatorTests {
    @Test("UIScrollView returns one stable coordinator")
    func stableAssociatedCoordinator() {
        let scrollView = UIScrollView()
        #expect(scrollView.refreshableCoordinator === scrollView.refreshableCoordinator)
    }

    @Test("four edge sessions share one observation set")
    func fourEdgesShareObservationSet() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        let coordinator = scrollView.refreshableCoordinator

        for edge in RefreshableEdge.allCases {
            coordinator.install(edge: edge, operation: .refresh, style: MockStyle()) {}
        }

        #expect(coordinator.installedSessionCount == 4)
        #expect(coordinator.observationStartCount == 1)
    }

    @Test("replacing an active edge restores its inset before installing the replacement")
    func replacementRestoresInset() throws {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 20
        let firstStyle = MockStyle()
        let coordinator = scrollView.refreshableCoordinator
        let options = RefreshableOptions(animationDuration: 0, automaticallyEnds: false)

        coordinator.install(
            edge: .top,
            operation: .refresh,
            style: firstStyle,
            options: options
        ) {}
        coordinator.begin(for: .top)
        #expect(scrollView.contentInset.top == 74)

        coordinator.install(
            edge: .top,
            operation: .refresh,
            style: MockStyle(),
            options: options
        ) {}

        #expect(scrollView.contentInset.top == 20)
        #expect(firstStyle.view.superview == nil)
        #expect(coordinator.state(for: .top) == .idle)
    }

    @Test("no-more-data is ignored by refresh operations")
    func refreshIgnoresNoMoreData() {
        let scrollView = UIScrollView()
        let coordinator = scrollView.refreshableCoordinator
        coordinator.install(edge: .leading, operation: .refresh, style: MockStyle()) {}

        coordinator.markNoMoreData(for: .leading)

        #expect(coordinator.state(for: .leading) == .idle)
    }

    @Test("removing one edge leaves the other edge active")
    func removalIsEdgeIsolated() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let coordinator = scrollView.refreshableCoordinator
        let options = RefreshableOptions(animationDuration: 0, automaticallyEnds: false)
        coordinator.install(edge: .top, operation: .refresh, style: MockStyle(), options: options) {}
        coordinator.install(edge: .bottom, operation: .loadMore, style: MockStyle(), options: options) {}

        coordinator.begin(for: .top)
        coordinator.remove(for: .bottom)

        #expect(coordinator.state(for: .top) == .active)
        #expect(coordinator.state(for: .bottom) == .idle)
        #expect(coordinator.installedSessionCount == 1)
    }
}
