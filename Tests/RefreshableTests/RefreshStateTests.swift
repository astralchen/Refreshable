import Testing
@testable import Refreshable
import UIKit

@Suite("RefreshState")
struct RefreshStateTests {

    @Test("isActive 仅在 .active 时为 true")
    func isActive() {
        #expect(RefreshState.active.isActive == true)
        #expect(RefreshState.idle.isActive == false)
        #expect(RefreshState.pulling(0.5).isActive == false)
        #expect(RefreshState.triggered.isActive == false)
        #expect(RefreshState.ending.isActive == false)
        #expect(RefreshState.noMoreData.isActive == false)
    }

    @Test("Equatable")
    func equatable() {
        #expect(RefreshState.idle == .idle)
        #expect(RefreshState.pulling(0.5) == .pulling(0.5))
        #expect(RefreshState.pulling(0.3) != .pulling(0.7))
        #expect(RefreshState.triggered == .triggered)
        #expect(RefreshState.active == .active)
        #expect(RefreshState.ending == .ending)
        #expect(RefreshState.noMoreData == .noMoreData)
        #expect(RefreshState.idle != .active)
    }
}
