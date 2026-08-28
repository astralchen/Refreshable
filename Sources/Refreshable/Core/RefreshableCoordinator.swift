import ObjectiveC
import UIKit

/// 安装在语义边缘上的刷新操作类型。
public enum RefreshableOperation: Sendable, Equatable {
    case refresh
    case loadMore
}

/// ScrollView 内部的统一运行时，持有各边缘 session 和唯一观察集合。
@MainActor
final class RefreshableCoordinator {
    private weak var scrollView: UIScrollView?
    private var sessions: [RefreshableEdge: EdgeRefreshComponent] = [:]
    private let observations = RefreshableScrollObservationSet()
    private var insetCoordinator: RefreshableInsetCoordinator?
    private var isAttached = false
    private var isDeliveringUpdate = false
    private var pendingUpdate: RefreshableScrollUpdate?

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    /// 设置或替换指定语义边缘上的操作。
    ///
    /// 同一 edge 再次设置时，会先取消旧 session、恢复其 inset 贡献并移除 host，
    /// 然后再挂载新的 session。
    func setOperation(
        _ operation: RefreshableOperation,
        for edge: RefreshableEdge,
        style: (any RefreshableStyle)? = nil,
        options: RefreshableOptions = .init(),
        action: @escaping @Sendable () async -> Void
    ) {
        guard let scrollView else { return }
        // 观察集合只在第一个 session 安装时启动，之后由 coordinator 统一分发快照。
        attach(to: scrollView)
        let role: RefreshableRole = operation == .refresh ? .refresh : .loadMore
        let resolvedStyle = style ?? DefaultRefreshControlStyle(
            edge: edge,
            role: role,
            textConfiguration: options.textConfiguration
        )
        let component = EdgeRefreshComponent(
            edge: edge,
            role: role,
            style: resolvedStyle,
            options: options,
            usesExternalObservation: true,
            insetCoordinator: insetCoordinator,
            action: action
        )
        replace(component, at: edge)
        component.scrollView = scrollView
    }

    func state(for edge: RefreshableEdge) -> RefreshState {
        sessions[edge]?.state ?? .idle
    }

    func beginOperation(for edge: RefreshableEdge) {
        sessions[edge]?.trigger()
    }

    func endOperation(for edge: RefreshableEdge) {
        sessions[edge]?.endAction()
    }

    func setEnabled(_ enabled: Bool, for edge: RefreshableEdge) {
        sessions[edge]?.setEnabled(enabled)
    }

    func markNoMoreData(for edge: RefreshableEdge) {
        sessions[edge]?.markNoMoreData()
    }

    func resetNoMoreData(for edge: RefreshableEdge) {
        sessions[edge]?.resetNoMoreData()
    }

    func removeOperation(for edge: RefreshableEdge) {
        guard let component = sessions.removeValue(forKey: edge) else { return }
        component.prepareForRemoval()
        stopObservingIfEmpty()
    }

    func component(for edge: RefreshableEdge) -> EdgeRefreshComponent? {
        sessions[edge]
    }

    var installedSessionCount: Int { sessions.count }
    var observationStartCount: Int { observations.startCount }

    private func attach(to scrollView: UIScrollView) {
        guard !isAttached else { return }
        isAttached = true
        // inset coordinator 以 scroll view 为 owner，记录 baseline 与每个 edge 的增量。
        insetCoordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        observations.onUpdate = { [weak self] update in
            self?.receive(update)
        }
        observations.onPanEnded = { [weak self] in
            guard let self else { return }
            Array(sessions.values).forEach { $0.scrollViewDidEndDragging() }
        }
        observations.onPanCancelled = { [weak self] in
            guard let self else { return }
            Array(sessions.values).forEach { $0.scrollViewDidCancelDragging() }
        }
        observations.start(for: scrollView)
    }

    private func receive(_ update: RefreshableScrollUpdate) {
        if let pendingUpdate {
            self.pendingUpdate = RefreshableScrollUpdate(
                snapshot: update.snapshot,
                changes: pendingUpdate.changes.union(update.changes)
            )
        } else {
            pendingUpdate = update
        }

        // UIKit 的 KVO 会在 contentInset/contentOffset setter 内同步回调。嵌套更新只合并到
        // pendingUpdate，由当前分发完成后继续消费，避免递归进入所有 edge session。
        guard !isDeliveringUpdate else { return }
        isDeliveringUpdate = true
        defer { isDeliveringUpdate = false }

        while let currentUpdate = pendingUpdate {
            pendingUpdate = nil
            let currentSessions = Array(sessions.values)
            currentSessions.forEach { $0.receive(currentUpdate) }
        }
    }

    private func replace(_ component: EdgeRefreshComponent, at edge: RefreshableEdge) {
        if let old = sessions.updateValue(component, forKey: edge), old !== component {
            // 先清理旧 runtime，确保旧 action completion 不会影响新 session。
            old.prepareForRemoval()
        }
    }

    private func stopObservingIfEmpty() {
        guard sessions.isEmpty, isAttached else { return }
        // 最后一个 session 移除后释放 KVO、pan target 和 inset coordinator，避免持有 scroll view。
        observations.stop()
        observations.onUpdate = nil
        observations.onPanEnded = nil
        observations.onPanCancelled = nil
        insetCoordinator = nil
        isAttached = false
    }
}
