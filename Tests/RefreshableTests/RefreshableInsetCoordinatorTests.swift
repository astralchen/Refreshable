import Testing
import UIKit
@testable import Refreshable

@Suite("RefreshableInsetCoordinator")
@MainActor
struct RefreshableInsetCoordinatorTests {

    @Test("多个 owner 在同一物理边叠加并逐个移除")
    func ownersOnSameEdgeAccumulateAndRemoveIndependently() {
        let scrollView = UIScrollView()
        scrollView.contentInset.top = 10
        let coordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        let first = NSObject()
        let second = NSObject()

        coordinator.setContribution(owner: first, edge: .top, amount: 20)
        coordinator.setContribution(owner: second, edge: .top, amount: 30)
        #expect(scrollView.contentInset.top == 60)

        coordinator.removeContribution(owner: first)
        #expect(scrollView.contentInset.top == 40)
        coordinator.removeContribution(owner: second)
        #expect(scrollView.contentInset.top == 10)
    }

    @Test("活跃期间外部 inset 修改更新 baseline 而不覆盖组件贡献")
    func externalInsetChangeUpdatesBaseline() {
        let scrollView = UIScrollView()
        scrollView.contentInset = UIEdgeInsets(top: 10, left: 2, bottom: 3, right: 4)
        let coordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        let owner = NSObject()

        coordinator.setContribution(owner: owner, edge: .top, amount: 54)
        scrollView.contentInset = UIEdgeInsets(top: 84, left: 12, bottom: 13, right: 14)

        #expect(coordinator.baselineInset == UIEdgeInsets(top: 30, left: 12, bottom: 13, right: 14))
        coordinator.removeContribution(owner: owner)
        #expect(scrollView.contentInset == UIEdgeInsets(top: 30, left: 12, bottom: 13, right: 14))
    }

    @Test("owner 切换物理边时移除旧边贡献")
    func movingOwnerBetweenPhysicalEdges() {
        let scrollView = UIScrollView()
        scrollView.contentInset = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        let coordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        let owner = NSObject()

        coordinator.setContribution(owner: owner, edge: .left, amount: 40)
        coordinator.setContribution(owner: owner, edge: .right, amount: 50)

        #expect(scrollView.contentInset.left == 2)
        #expect(scrollView.contentInset.right == 54)
    }

    @Test("非法 contribution 按零处理")
    func invalidContributionIsZero() {
        let scrollView = UIScrollView()
        scrollView.contentInset.bottom = 7
        let coordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        let owner = NSObject()

        coordinator.setContribution(owner: owner, edge: .bottom, amount: .infinity)

        #expect(scrollView.contentInset.bottom == 7)
    }
}
