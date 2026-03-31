import Testing
@testable import Refreshable
import UIKit

@Suite("RefreshState")
struct RefreshStateTests {

    @Test("isRefreshing 仅在 .refreshing 时为 true")
    func isRefreshing() {
        #expect(RefreshState.refreshing.isRefreshing == true)
        #expect(RefreshState.idle.isRefreshing == false)
        #expect(RefreshState.pulling(0.5).isRefreshing == false)
        #expect(RefreshState.triggered.isRefreshing == false)
        #expect(RefreshState.ending.isRefreshing == false)
        #expect(RefreshState.noMoreData.isRefreshing == false)
    }

    @Test("Equatable")
    func equatable() {
        #expect(RefreshState.idle == .idle)
        #expect(RefreshState.pulling(0.5) == .pulling(0.5))
        #expect(RefreshState.pulling(0.3) != .pulling(0.7))
        #expect(RefreshState.triggered == .triggered)
        #expect(RefreshState.refreshing == .refreshing)
        #expect(RefreshState.ending == .ending)
        #expect(RefreshState.noMoreData == .noMoreData)
        #expect(RefreshState.idle != .refreshing)
    }
}
