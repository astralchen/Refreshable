import UIKit
@testable import Refreshable

/// 用于测试的 mock style，记录所有状态更新
@MainActor
final class MockStyle: RefreshableStyle {
    let view: UIView = UIView()
    let extent: CGFloat

    init(extent: CGFloat = 54) {
        self.extent = extent
    }

    struct StateRecord: Equatable {
        let state: RefreshState
        let progress: CGFloat
        let viewAlpha: CGFloat
    }

    private(set) var records: [StateRecord] = []

    var lastState: RefreshState? { records.last?.state }
    var lastProgress: CGFloat? { records.last?.progress }

    func update(state: RefreshState, progress: CGFloat) {
        records.append(StateRecord(state: state, progress: progress, viewAlpha: view.alpha))
    }

    func reset() {
        records.removeAll()
    }
}
