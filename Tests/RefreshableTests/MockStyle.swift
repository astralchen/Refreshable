import UIKit
@testable import Refreshable

/// 用于测试的 mock style，记录所有状态更新
@MainActor
final class MockStyle: RefreshableStyle {
    let extent: CGFloat
    private let placeholderView = UIView()
    private var latestRenderer: MockRenderer?
    var rendererLayoutMargins: UIEdgeInsets = .zero

    init(extent: CGFloat = 54) {
        self.extent = extent
    }

    struct StateRecord: Equatable {
        let state: RefreshState
        let progress: CGFloat
        let viewAlpha: CGFloat
    }

    var view: UIView { latestRenderer?.view ?? placeholderView }
    var records: [StateRecord] { latestRenderer?.records ?? [] }

    var lastState: RefreshState? { records.last?.state }
    var lastProgress: CGFloat? { records.last?.progress }

    func makeRenderer() -> any RefreshableStyleRenderer {
        let renderer = MockRenderer()
        renderer.view.layoutMargins = rendererLayoutMargins
        latestRenderer = renderer
        return renderer
    }

    func reset() {
        latestRenderer?.reset()
    }
}

@MainActor
private final class MockRenderer: RefreshableStyleRenderer {
    let view = UIView()
    private(set) var records: [MockStyle.StateRecord] = []

    func render(_ context: RefreshableStyleContext) {
        records.append(
            MockStyle.StateRecord(
                state: context.state,
                progress: context.pullProgress,
                viewAlpha: view.alpha
            )
        )
    }

    func reset() {
        records.removeAll()
    }
}
