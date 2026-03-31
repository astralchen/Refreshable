import UIKit
@testable import Refreshable

/// 用于测试的 mock style，记录所有状态更新
@MainActor
final class MockStyle: RefreshableStyle {
    let view: UIView = UIView()
    let height: CGFloat = 54

    struct StateRecord: Equatable {
        let state: RefreshState
        let progress: CGFloat
    }

    private(set) var records: [StateRecord] = []

    var lastState: RefreshState? { records.last?.state }
    var lastProgress: CGFloat? { records.last?.progress }

    func update(state: RefreshState, progress: CGFloat) {
        records.append(StateRecord(state: state, progress: progress))
    }

    func reset() {
        records.removeAll()
    }
}
