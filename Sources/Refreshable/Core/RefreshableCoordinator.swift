import ObjectiveC
import UIKit

/// The operation installed at a semantic edge.
public enum RefreshableOperation: Sendable, Equatable {
    case refresh
    case loadMore
}

/// A scroll-view-level runtime that owns edge sessions and one observation set.
@MainActor
public final class RefreshableCoordinator {
    private weak var scrollView: UIScrollView?
    private var sessions: [RefreshableEdge: EdgeRefreshComponent] = [:]
    private let observations = RefreshableScrollObservationSet()
    private var insetCoordinator: RefreshableInsetCoordinator?
    private var isAttached = false

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    /// Installs or replaces one edge session.
    public func install(
        edge: RefreshableEdge,
        operation: RefreshableOperation,
        style: (any RefreshableStyle)? = nil,
        options: RefreshableOptions = .init(),
        action: @escaping @Sendable () async -> Void
    ) {
        guard let scrollView else { return }
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

    public func state(for edge: RefreshableEdge) -> RefreshState {
        sessions[edge]?.state ?? .idle
    }

    public func begin(for edge: RefreshableEdge) {
        sessions[edge]?.trigger()
    }

    public func end(for edge: RefreshableEdge) {
        sessions[edge]?.endAction()
    }

    public func setEnabled(_ enabled: Bool, for edge: RefreshableEdge) {
        sessions[edge]?.setEnabled(enabled)
    }

    public func markNoMoreData(for edge: RefreshableEdge) {
        sessions[edge]?.markNoMoreData()
    }

    public func resetNoMoreData(for edge: RefreshableEdge) {
        sessions[edge]?.resetNoMoreData()
    }

    public func remove(for edge: RefreshableEdge) {
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
        insetCoordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        observations.onSnapshot = { [weak self] snapshot in
            self?.receive(snapshot)
        }
        observations.onPanEnded = { [weak self] in
            self?.sessions.values.forEach { $0.scrollViewDidEndDragging() }
        }
        observations.onPanCancelled = { [weak self] in
            self?.sessions.values.forEach { $0.scrollViewDidCancelDragging() }
        }
        observations.start(for: scrollView)
    }

    private func receive(_ snapshot: RefreshableScrollSnapshot) {
        sessions.values.forEach { $0.receive(snapshot) }
    }

    func setComponent(_ component: EdgeRefreshComponent?, at edge: RefreshableEdge) {
        if let component {
            if let scrollView {
                attach(to: scrollView)
            }
            replace(component, at: edge)
            component.scrollView = scrollView
        } else if let old = sessions.removeValue(forKey: edge) {
            old.prepareForRemoval()
            stopObservingIfEmpty()
        }
    }

    private func replace(_ component: EdgeRefreshComponent, at edge: RefreshableEdge) {
        if let old = sessions.updateValue(component, forKey: edge), old !== component {
            old.prepareForRemoval()
        }
    }

    private func stopObservingIfEmpty() {
        guard sessions.isEmpty, isAttached else { return }
        observations.stop()
        observations.onSnapshot = nil
        observations.onPanEnded = nil
        observations.onPanCancelled = nil
        insetCoordinator = nil
        isAttached = false
    }
}
