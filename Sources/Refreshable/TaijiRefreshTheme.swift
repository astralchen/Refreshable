import UIKit

/// Theme selection for the Taiji refresh control.
public enum TaijiRefreshTheme: Equatable, Sendable {
    case system
    case light
    case dark
    case custom(TaijiRefreshPalette)
}

extension TaijiRefreshTheme {
    func resolvedPalette(for traitCollection: UITraitCollection) -> TaijiRefreshPalette {
        switch self {
        case .system:
            traitCollection.userInterfaceStyle == .dark ? .dark : .light
        case .light:
            .light
        case .dark:
            .dark
        case .custom(let palette):
            palette
        }
    }
}

/// Color palette for the Taiji refresh control.
public struct TaijiRefreshPalette: Equatable, @unchecked Sendable {
    public var backgroundTint: UIColor
    public var primaryGlow: UIColor
    public var secondaryGlow: UIColor
    public var glassHighlight: UIColor
    public var shadowCore: UIColor
    public var particle: UIColor

    public init(
        backgroundTint: UIColor,
        primaryGlow: UIColor,
        secondaryGlow: UIColor,
        glassHighlight: UIColor,
        shadowCore: UIColor,
        particle: UIColor
    ) {
        self.backgroundTint = backgroundTint
        self.primaryGlow = primaryGlow
        self.secondaryGlow = secondaryGlow
        self.glassHighlight = glassHighlight
        self.shadowCore = shadowCore
        self.particle = particle
    }

    public static let dark = TaijiRefreshPalette(
        backgroundTint: UIColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.18),
        primaryGlow: UIColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1.0),
        secondaryGlow: UIColor(red: 0.62, green: 0.36, blue: 1.0, alpha: 1.0),
        glassHighlight: UIColor(white: 1.0, alpha: 0.92),
        shadowCore: UIColor(red: 0.04, green: 0.03, blue: 0.18, alpha: 0.96),
        particle: UIColor(red: 0.82, green: 0.92, blue: 1.0, alpha: 1.0)
    )

    public static let light = TaijiRefreshPalette(
        backgroundTint: UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 0.14),
        primaryGlow: UIColor(red: 0.0, green: 0.62, blue: 0.95, alpha: 1.0),
        secondaryGlow: UIColor(red: 0.52, green: 0.34, blue: 0.92, alpha: 1.0),
        glassHighlight: UIColor(white: 1.0, alpha: 0.96),
        shadowCore: UIColor(red: 0.20, green: 0.20, blue: 0.48, alpha: 0.88),
        particle: UIColor(red: 0.28, green: 0.42, blue: 0.78, alpha: 1.0)
    )

    public static func == (lhs: TaijiRefreshPalette, rhs: TaijiRefreshPalette) -> Bool {
        lhs.backgroundTint.isEqual(rhs.backgroundTint)
            && lhs.primaryGlow.isEqual(rhs.primaryGlow)
            && lhs.secondaryGlow.isEqual(rhs.secondaryGlow)
            && lhs.glassHighlight.isEqual(rhs.glassHighlight)
            && lhs.shadowCore.isEqual(rhs.shadowCore)
            && lhs.particle.isEqual(rhs.particle)
    }
}
