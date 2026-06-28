import UIKit
import QuartzCore

final class TaijiRefreshView: UIView {
    var onTraitCollectionChange: ((UITraitCollection) -> Void)?
    private(set) var lastRenderState: TaijiRefreshRenderState?
    private(set) var lastPalette: TaijiRefreshPalette?
    private(set) var isContinuousAnimationActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        onTraitCollectionChange?(traitCollection)
    }

    func apply(
        renderState: TaijiRefreshRenderState,
        palette: TaijiRefreshPalette,
        animated: Bool,
        reduceTransparency: Bool
    ) {
        lastRenderState = renderState
        lastPalette = palette
        isContinuousAnimationActive = renderState.continuousRotationSpeed > 0
    }
}
