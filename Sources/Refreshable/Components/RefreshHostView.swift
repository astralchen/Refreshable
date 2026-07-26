import UIKit

@MainActor
final class RefreshHostView: UIView {
    var onEnvironmentChange: (@MainActor () -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onEnvironmentChange?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onEnvironmentChange?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        onEnvironmentChange?()
    }
}
